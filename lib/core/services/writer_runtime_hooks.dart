import 'writer_guidance_loader.dart';

/// Hook 问题严重级别
enum HookSeverity {
  /// 警告：记录但不阻断
  warn,

  /// 阻断：拒绝写库
  block,
}

/// Hook 规则类型
enum HookRuleType {
  /// 通用检查（空响应、占位内容等）
  general,

  /// 章节正文检查（长度、完整性）
  chapterBody,

  /// 实体简介检查（角色 bio、地点描述、物品描述）
  entityBio,

  /// 世界观素材检查（设定完整性）
  worldbuilding,

  /// 对话片段检查
  dialogueSnippet,
}

/// 单条 Hook 问题
class HookIssue {
  final String message;
  final HookSeverity severity;
  final HookRuleType ruleType;

  /// 恢复建议：告诉 agent 如何修正此问题
  final String? recoveryHint;

  const HookIssue({
    required this.message,
    required this.severity,
    required this.ruleType,
    this.recoveryHint,
  });

  @override
  String toString() => message;
}

/// 恢复动作类型
enum HookRecoveryType {
  /// 带修正指令重试（agent 自行修正后再次调用工具）
  retryWithHints,

  /// 内容需要完全重新生成
  regenerate,
}

/// 单条恢复动作
class HookRecoveryAction {
  final HookRecoveryType type;
  final String description;
  final String retryHint;

  const HookRecoveryAction({
    required this.type,
    required this.description,
    required this.retryHint,
  });
}

class WriterPreflightChecks {
  final String guidance;
  final List<String> issues;

  const WriterPreflightChecks({required this.guidance, required this.issues});

  String toPromptSection() {
    final parts = <String>[];
    if (guidance.trim().isNotEmpty) {
      parts.add('## Pre Request Hook\n${guidance.trim()}');
    }
    if (issues.isNotEmpty) {
      parts.add(
        '## Preflight Checks\n${issues.map((issue) => "- $issue").join('\n')}',
      );
    }
    return parts.join('\n\n').trim();
  }
}

class WriterPostflightChecks {
  final String guidance;
  final List<HookIssue> issues;

  const WriterPostflightChecks({required this.guidance, required this.issues});

  /// 是否存在阻断级问题
  bool get shouldBlock => issues.any((i) => i.severity == HookSeverity.block);

  /// 阻断级问题消息
  List<String> get blockMessages =>
      issues.where((i) => i.severity == HookSeverity.block).map((i) => i.message).toList();

  /// 警告级问题消息
  List<String> get warnMessages =>
      issues.where((i) => i.severity == HookSeverity.warn).map((i) => i.message).toList();

  /// 兼容旧接口：所有问题的消息文本
  List<String> get messages => issues.map((i) => i.message).toList();

  Map<String, dynamic>? toMetadata() {
    if (issues.isEmpty) {
      return null;
    }
    return {
      'writer_postflight_guidance': guidance,
      'writer_postflight_issues': issues
          .map((i) => {'message': i.message, 'severity': i.severity.name, 'ruleType': i.ruleType.name})
          .toList(),
    };
  }

  /// 从阻断/警告问题生成恢复动作列表
  List<HookRecoveryAction> get recoveryActions {
    final actions = <HookRecoveryAction>[];
    for (final issue in issues) {
      if (issue.recoveryHint == null) continue;
      actions.add(HookRecoveryAction(
        type: issue.severity == HookSeverity.block
            ? HookRecoveryType.retryWithHints
            : HookRecoveryType.regenerate,
        description: issue.message,
        retryHint: issue.recoveryHint!,
      ));
    }
    return actions;
  }

  /// 生成可供 agent 直接消费的恢复提示
  /// 附加在 ToolResult.fail 消息中，引导 agent 自行修正
  String toRecoveryPrompt() {
    final actions = recoveryActions;
    if (actions.isEmpty) return '';
    final buffer = StringBuffer();
    buffer.writeln();
    buffer.writeln('【修正建议】');
    for (final action in actions) {
      buffer.writeln('- ${action.retryHint}');
    }
    buffer.writeln('请根据以上建议修正后重新调用工具。');
    return buffer.toString();
  }
}

class WriterRuntimeHooks {
  final WriterGuidanceLoader _guidanceLoader;

  WriterRuntimeHooks({WriterGuidanceLoader? guidanceLoader})
    : _guidanceLoader = guidanceLoader ?? WriterGuidanceLoader();

  Future<WriterPreflightChecks> runPreRequestChecks({
    required String prompt,
    required String workId,
    String? contextContent,
    int historyCount = 0,
  }) async {
    final issues = <String>[];
    final trimmedPrompt = prompt.trim();

    if (trimmedPrompt.isEmpty) {
      issues.add('当前请求为空，不能直接发起模型调用。');
    }
    if (_looksLikeWorkScopedAction(trimmedPrompt) && workId.trim().isEmpty) {
      issues.add('该请求看起来需要作品范围，但当前未提供 workId。');
    }
    if (historyCount > 30) {
      issues.add('当前历史消息较长，建议优先压缩上下文。');
    }
    if ((contextContent?.trim().length ?? 0) > 6000) {
      issues.add('额外参考资料过长，建议裁剪后再发送。');
    }

    final guidance = await _guidanceLoader.loadHookGuidance(
      'pre-request-validate',
    );
    return WriterPreflightChecks(guidance: guidance, issues: issues);
  }

  Future<WriterPostflightChecks> runPostResponseChecks({
    required String request,
    required String response,
    bool usedTools = false,
    HookRuleType ruleType = HookRuleType.general,
  }) async {
    final issues = <HookIssue>[];
    final trimmedResponse = response.trim();

    // ── 通用检查 ──
    if (trimmedResponse.isEmpty) {
      issues.add(const HookIssue(
        message: '模型返回了空响应。',
        severity: HookSeverity.block,
        ruleType: HookRuleType.general,
        recoveryHint: '模型未返回有效内容，请换一种表述重新请求。',
      ));
    }
    if (trimmedResponse.contains('TODO') ||
        trimmedResponse.contains('待补充') ||
        trimmedResponse.contains('待填写')) {
      issues.add(const HookIssue(
        message: '响应包含未完成占位内容（TODO/待补充/待填写）。',
        severity: HookSeverity.block,
        ruleType: HookRuleType.general,
        recoveryHint: '移除所有 TODO、待补充、待填写等占位符，用完整内容替换。',
      ));
    }

    // ── 按规则类型的专项检查 ──
    switch (ruleType) {
      case HookRuleType.chapterBody:
        _checkChapterBody(trimmedResponse, request, usedTools, issues);
      case HookRuleType.entityBio:
        _checkEntityBio(trimmedResponse, issues);
      case HookRuleType.worldbuilding:
        _checkWorldbuilding(trimmedResponse, issues);
      case HookRuleType.dialogueSnippet:
        _checkDialogueSnippet(trimmedResponse, issues);
      case HookRuleType.general:
        // 通用已处理
        break;
    }

    final guidance = await _guidanceLoader.loadHookGuidance(
      'post-response-check',
    );
    return WriterPostflightChecks(guidance: guidance, issues: issues);
  }

  // ── 章节正文检查 ──

  void _checkChapterBody(
    String response,
    String request,
    bool usedTools,
    List<HookIssue> issues,
  ) {
    if (response.length < 80 && !usedTools) {
      issues.add(const HookIssue(
        message: '章节正文过短（不足 80 字），可能不是完整正文。',
        severity: HookSeverity.block,
        ruleType: HookRuleType.chapterBody,
        recoveryHint: '章节正文不足 80 字，请撰写至少 200 字以上的完整段落，包含环境描写、人物动作和对话。',
      ));
    }
    if (response.length < 200) {
      issues.add(const HookIssue(
        message: '章节正文偏短，建议扩展到 200 字以上。',
        severity: HookSeverity.warn,
        ruleType: HookRuleType.chapterBody,
        recoveryHint: '当前正文偏短，建议补充细节描写、环境烘托或角色内心活动，扩展到 200 字以上。',
      ));
    }
    // 检测明显不完整的结尾
    if (response.endsWith('……') || response.endsWith('……」')) {
      issues.add(const HookIssue(
        message: '章节可能未写完，结尾为省略号。',
        severity: HookSeverity.warn,
        ruleType: HookRuleType.chapterBody,
        recoveryHint: '章节以省略号结尾，可能未写完。请续写至一个完整的场景断点。',
      ));
    }
  }

  // ── 实体简介检查 ──

  void _checkEntityBio(String response, List<HookIssue> issues) {
    if (response.length < 10) {
      issues.add(const HookIssue(
        message: '实体简介过短（不足 10 字），缺少有效描述。',
        severity: HookSeverity.block,
        ruleType: HookRuleType.entityBio,
        recoveryHint: '简介过短，请补充该实体的外观、性格、背景等核心特征，至少 30 字。',
      ));
    }
    if (response.length < 30) {
      issues.add(const HookIssue(
        message: '实体简介偏短，建议补充更多细节。',
        severity: HookSeverity.warn,
        ruleType: HookRuleType.entityBio,
        recoveryHint: '简介偏短，建议添加更多背景、特征或动机描述。',
      ));
    }
    // 检测占位性质的简介
    final placeholderPatterns = ['暂无', '无', '未知', '待定', '—'];
    if (placeholderPatterns.any((p) => response == p)) {
      issues.add(HookIssue(
        message: '实体简介为占位内容（"$response"）。',
        severity: HookSeverity.block,
        ruleType: HookRuleType.entityBio,
        recoveryHint: '请为该实体撰写真实描述，不要使用"$response"等占位词。',
      ));
    }
  }

  // ── 世界观素材检查 ──

  void _checkWorldbuilding(String response, List<HookIssue> issues) {
    if (response.length < 50) {
      issues.add(const HookIssue(
        message: '世界观设定过短（不足 50 字），缺少具体内容。',
        severity: HookSeverity.block,
        ruleType: HookRuleType.worldbuilding,
        recoveryHint: '世界观设定过短，请补充核心设定（如力量体系、历史背景、社会结构），至少 150 字。',
      ));
    }
    if (response.length < 150) {
      issues.add(const HookIssue(
        message: '世界观设定偏短，建议补充核心设定、力量体系、历史背景等。',
        severity: HookSeverity.warn,
        ruleType: HookRuleType.worldbuilding,
        recoveryHint: '建议补充力量体系、地理环境、种族分布等细节，使设定更加丰满。',
      ));
    }
  }

  // ── 对话片段检查 ──

  void _checkDialogueSnippet(String response, List<HookIssue> issues) {
    // 对话片段至少应该包含引号
    if (!response.contains('"') &&
        !response.contains('「') &&
        !response.contains('『')) {
      issues.add(const HookIssue(
        message: '对话片段缺少对话标记（引号），可能不是有效的对话。',
        severity: HookSeverity.warn,
        ruleType: HookRuleType.dialogueSnippet,
        recoveryHint: '对话内容缺少引号标记。请使用「」或""包裹角色台词。',
      ));
    }
  }

  bool _looksLikeWorkScopedAction(String prompt) {
    const keywords = [
      '作品',
      '章节',
      '角色',
      '地点',
      '物品',
      '势力',
      '关系',
      'worldbuilding',
      'chapter',
      'character',
      'create',
    ];
    final lower = prompt.toLowerCase();
    return keywords.any(lower.contains);
  }

  /// 根据请求上下文推导合适的规则类型
  static HookRuleType inferRuleType(String request) {
    final lower = request.toLowerCase();
    if (lower.contains('章节') ||
        lower.contains('正文') ||
        lower.contains('chapter') ||
        lower.contains('续写')) {
      return HookRuleType.chapterBody;
    }
    if (lower.contains('世界观') || lower.contains('worldbuilding') || lower.contains('设定')) {
      return HookRuleType.worldbuilding;
    }
    if (lower.contains('对话') || lower.contains('dialogue') || lower.contains('台词')) {
      return HookRuleType.dialogueSnippet;
    }
    if (lower.contains('简介') ||
        lower.contains('bio') ||
        lower.contains('描述') ||
        lower.contains('角色设定') ||
        lower.contains('地点') ||
        lower.contains('物品') ||
        lower.contains('势力')) {
      return HookRuleType.entityBio;
    }
    return HookRuleType.general;
  }

  /// 根据当前操作上下文推导运行时路径
  static List<String> deriveRuntimePaths({
    String? operationHint,
    bool hasWorkContext = false,
    bool isEditorContext = false,
  }) {
    final paths = <String>['lib/core/services/ai/'];
    if (isEditorContext || (operationHint != null && (operationHint.contains('编辑') || operationHint.contains('续写')))) {
      paths.add('lib/modules/editor/');
    }
    if (operationHint != null && operationHint.contains('工作流')) {
      paths.add('lib/features/workflow/');
    }
    return paths;
  }
}
