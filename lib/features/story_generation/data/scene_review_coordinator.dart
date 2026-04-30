import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';

import 'story_generation_pass_retry.dart';
import '../domain/scene_models.dart';
import '../domain/memory_models.dart';
import '../domain/story_pipeline_interfaces.dart';
import 'scene_roleplay_session_models.dart';
import 'story_generation_formatter_trace.dart';

class SceneReviewCoordinator implements SceneReviewService {
  SceneReviewCoordinator({
    required AppSettingsStore settingsStore,
    StoryGenerationFormatterTraceSink? formatterTraceSink,
  }) : _settingsStore = settingsStore,
       _formatterTraceSink = formatterTraceSink;

  final AppSettingsStore _settingsStore;
  final StoryGenerationFormatterTraceSink? _formatterTraceSink;

  static const List<SceneReviewCategory> _baseCombinedCategories = [
    SceneReviewCategory.prose,
    SceneReviewCategory.scenePlan,
    SceneReviewCategory.chapterPlan,
    SceneReviewCategory.continuity,
    SceneReviewCategory.characterState,
    SceneReviewCategory.worldState,
  ];

  static const List<SceneReviewCategory> _consistencyCategories = [
    SceneReviewCategory.chapterPlan,
    SceneReviewCategory.continuity,
    SceneReviewCategory.characterState,
    SceneReviewCategory.worldState,
  ];

  @override
  Future<SceneReviewResult> review({
    required SceneBrief brief,
    required SceneDirectorOutput director,
    required List<DynamicRoleAgentOutput> roleOutputs,
    required SceneProseDraft prose,
    SceneRoleplaySession? roleplaySession,
    StoryRetrievalPack? retrievalPack,
    bool enableReaderFlowReview = false,
    bool enableLexiconReview = false,
    void Function(String message)? onStatus,
  }) async {
    if (brief.metadata['localReviewOnly'] == true) {
      return _localReviewResult(brief: brief, prose: prose, onStatus: onStatus);
    }

    final combinedCategories = [
      ..._baseCombinedCategories,
      if (roleplaySession != null && !roleplaySession.isEmpty)
        SceneReviewCategory.roleplayFidelity,
    ];
    final combined = await _runReviewPass(
      passName:
          'scene combined review (scene judge review / scene consistency review / scene roleplay fidelity review)',
      taskType: 'scene_combined_review',
      passLabel: 'combined',
      categories: combinedCategories,
      brief: brief,
      director: director,
      roleOutputs: roleOutputs,
      prose: prose,
      roleplaySession: roleplaySession,
      retrievalPack: retrievalPack,
      onStatus: onStatus,
    );
    final consistency = _coveredReviewPass(
      source: combined,
      categories: _consistencyCategories,
      passReason: '合并审查已覆盖一致性检查。',
    );
    final readerFlow = enableReaderFlowReview
        ? _coveredReviewPass(
            source: combined,
            categories: const [SceneReviewCategory.prose],
            passReason: '合并审查已覆盖读者流畅度检查。',
          )
        : null;
    final lexicon = enableLexiconReview
        ? _coveredReviewPass(
            source: combined,
            categories: const [SceneReviewCategory.prose],
            passReason: '合并审查已覆盖词汇检查。',
          )
        : null;
    final reviewResult = SceneReviewResult(
      judge: combined,
      consistency: consistency,
      readerFlow: readerFlow,
      lexicon: lexicon,
      decision: _deriveDecision(
        judge: combined,
        consistency: consistency,
        readerFlow: readerFlow,
        lexicon: lexicon,
      ),
    );
    return SceneReviewResult(
      judge: reviewResult.judge,
      consistency: reviewResult.consistency,
      readerFlow: reviewResult.readerFlow,
      lexicon: reviewResult.lexicon,
      decision: reviewResult.decision,
      refinementGuidance: reviewResult.synthesizeGuidance(),
    );
  }

  SceneReviewResult _localReviewResult({
    required SceneBrief brief,
    required SceneProseDraft prose,
    void Function(String message)? onStatus,
  }) {
    onStatus?.call('场景 ${brief.chapterId}/${brief.sceneId} · local review');
    final hasDraft = prose.text.trim().isNotEmpty;
    final status = hasDraft
        ? SceneReviewStatus.pass
        : SceneReviewStatus.rewriteProse;
    final decision = hasDraft
        ? SceneReviewDecision.pass
        : SceneReviewDecision.rewriteProse;
    final reason = hasDraft ? '本地结构化审查通过。' : '正文为空，需要补写。';
    final judge = SceneReviewPassResult(
      status: status,
      reason: reason,
      rawText: '决定：${hasDraft ? 'PASS' : 'REWRITE_PROSE'}\n原因：$reason',
      categories: const [
        SceneReviewCategory.prose,
        SceneReviewCategory.scenePlan,
      ],
    );
    final consistency = SceneReviewPassResult(
      status: status,
      reason: reason,
      rawText: '决定：${hasDraft ? 'PASS' : 'REWRITE_PROSE'}\n原因：$reason',
      categories: const [
        SceneReviewCategory.chapterPlan,
        SceneReviewCategory.continuity,
        SceneReviewCategory.characterState,
        SceneReviewCategory.worldState,
      ],
    );
    final result = SceneReviewResult(
      judge: judge,
      consistency: consistency,
      decision: decision,
    );
    return SceneReviewResult(
      judge: result.judge,
      consistency: result.consistency,
      decision: result.decision,
      refinementGuidance: result.synthesizeGuidance(),
    );
  }

  SceneReviewPassResult _coveredReviewPass({
    required SceneReviewPassResult source,
    required List<SceneReviewCategory> categories,
    required String passReason,
  }) {
    final reason = source.status == SceneReviewStatus.pass ? passReason : '';
    return SceneReviewPassResult(
      status: source.status,
      reason: reason,
      rawText: reason.isEmpty ? source.rawText : '决定：PASS\n原因：$reason',
      categories: categories,
    );
  }

  Future<SceneReviewPassResult> _runReviewPass({
    required String passName,
    required String taskType,
    required String passLabel,
    required List<SceneReviewCategory> categories,
    required SceneBrief brief,
    required SceneDirectorOutput director,
    required List<DynamicRoleAgentOutput> roleOutputs,
    required SceneProseDraft prose,
    SceneRoleplaySession? roleplaySession,
    StoryRetrievalPack? retrievalPack,
    void Function(String message)? onStatus,
  }) async {
    onStatus?.call('场景 ${brief.chapterId}/${brief.sceneId} · $passName');
    final evidenceSection = _buildEvidenceSection(retrievalPack);
    final result = await requestStoryGenerationPassWithRetry(
      settingsStore: _settingsStore,
      messages: [
        AppLlmChatMessage(
          role: 'system',
          content:
              'You are a $passName for a Chinese novel. '
              'Use a 2-line review format. Choose the first line from:\n'
              '决定：PASS\n'
              '决定：REWRITE_PROSE\n'
              '决定：REPLAN_SCENE\n'
              'For uncertainty, choose 决定：REWRITE_PROSE.\n'
              'Use 原因： for the second line and keep it brief. Focus on blocking issues.',
        ),
        AppLlmChatMessage(
          role: 'user',
          content: [
            '任务：$taskType',
            '评审：$passLabel',
            '评审类别：${_categoryList(categories)}',
            '规则：聚焦阻塞问题，正文改写交给后续步骤',
            '场：${_compact(brief.sceneTitle, maxChars: 40)}',
            '导演：${_compact(director.text, maxChars: 120)}',
            '角色输入：${_roleSummary(roleOutputs)}',
            if (roleplaySession != null && !roleplaySession.isEmpty)
              '角色扮演过程：${roleplaySession.toPromptText()}',
            if (roleplaySession != null && !roleplaySession.isEmpty)
              '忠实性指引：正文围绕角色扮演过程中的可见动作、对白、裁决事实和局面推进展开；关键互动、裁决事实、角色可见信息共同决定评审结果。',
            '正文：${prose.text}',
            if (evidenceSection.isNotEmpty) evidenceSection,
          ].join('\n'),
        ),
      ],
      traceName: taskType,
      traceMetadata: {
        'chapterId': brief.chapterId,
        'sceneId': brief.sceneId,
        'sceneTitle': brief.sceneTitle,
        'passLabel': passLabel,
        'reviewCategories': _categoryList(categories),
      },
    );
    if (!result.succeeded) {
      throw StateError(result.detail ?? 'Scene $passLabel review failed.');
    }

    final originalRawText = result.text!.trim();
    var rawText = originalRawText;
    var parsed = _parseReviewOutput(rawText, passLabel: passLabel);
    var repairAttempted = false;
    String? repairedRawText;
    if (parsed.usedFallback) {
      repairAttempted = true;
      onStatus?.call(
        '场景 ${brief.chapterId}/${brief.sceneId} · $passName format retry',
      );
      final repaired = await _repairReviewFormat(
        passName: passName,
        passLabel: passLabel,
        rawText: rawText,
      );
      if (repaired != null && !repaired.parsed.usedFallback) {
        repairedRawText = repaired.rawText;
        rawText = repaired.rawText;
        parsed = repaired.parsed;
      } else if (repaired != null) {
        repairedRawText = repaired.rawText;
      }
    }
    if (parsed.usedFallback) {
      onStatus?.call(
        '场景 ${brief.chapterId}/${brief.sceneId} · $passName format fallback',
      );
    }
    await _recordFormatterTrace(
      brief: brief,
      passName: passName,
      passLabel: passLabel,
      rawText: originalRawText,
      repairedText: repairedRawText,
      finalText: rawText,
      repairAttempted: repairAttempted,
      usedFallback: parsed.usedFallback,
    );
    return SceneReviewPassResult(
      status: parsed.status,
      reason: parsed.reason,
      rawText: rawText,
      categories: categories,
    );
  }

  Future<void> _recordFormatterTrace({
    required SceneBrief brief,
    required String passName,
    required String passLabel,
    required String rawText,
    required String? repairedText,
    required String finalText,
    required bool repairAttempted,
    required bool usedFallback,
  }) async {
    final sink = _formatterTraceSink;
    if (sink == null) return;
    try {
      await sink.record(
        StoryGenerationFormatterTraceEntry(
          timestampMs: DateTime.now().millisecondsSinceEpoch,
          chapterId: brief.chapterId,
          sceneId: brief.sceneId,
          sceneTitle: brief.sceneTitle,
          formatter: 'scene_review',
          passName: passName,
          passLabel: passLabel,
          rawText: rawText,
          repairedText: repairedText,
          finalText: finalText,
          repairAttempted: repairAttempted,
          usedFallback: usedFallback,
        ),
      );
    } on Object {
      // Formatter tracing should never block review completion.
    }
  }

  Future<_RepairedReviewOutput?> _repairReviewFormat({
    required String passName,
    required String passLabel,
    required String rawText,
  }) async {
    final result = await requestStoryGenerationPassWithRetry(
      settingsStore: _settingsStore,
      messages: [
        AppLlmChatMessage(
          role: 'system',
          content:
              'You are a $passName format repair pass. '
              'Normalize malformed review output into a 2-line format. '
              'Choose the first line from:\n'
              '决定：PASS\n'
              '决定：REWRITE_PROSE\n'
              '决定：REPLAN_SCENE\n'
              'For missing or ambiguous decisions, choose 决定：REWRITE_PROSE.\n'
              'Use 原因： for the second line and briefly preserve the '
              'original reason.',
        ),
        AppLlmChatMessage(
          role: 'user',
          content: ['原始评审输出：', rawText].join('\n'),
        ),
      ],
      maxTransientRetries: 1,
      traceName: 'scene_review_format_repair',
      traceMetadata: {'passLabel': passLabel, 'passName': passName},
    );
    if (!result.succeeded || result.text == null) {
      return null;
    }

    final repairedRaw = result.text!.trim();
    return _RepairedReviewOutput(
      rawText: repairedRaw,
      parsed: _parseReviewOutput(repairedRaw, passLabel: passLabel),
    );
  }

  /// Builds an evidence section from the retrieval pack for grounded review.
  String _buildEvidenceSection(StoryRetrievalPack? pack) {
    if (pack == null || pack.hits.isEmpty) return '';

    final acceptedFacts = pack.hits
        .where(
          (h) =>
              h.chunk.kind == MemorySourceKind.acceptedState ||
              h.chunk.kind == MemorySourceKind.worldFact,
        )
        .take(5)
        .map((h) => '- ${_compact(h.chunk.content, maxChars: 80)}')
        .toList();

    final sourceIds = <String>{
      for (final hit in pack.hits) ...hit.chunk.rootSourceIds,
    };

    final parts = <String>[];
    if (acceptedFacts.isNotEmpty) {
      parts.add('已知事实：');
      parts.addAll(acceptedFacts);
    }
    if (sourceIds.isNotEmpty) {
      parts.add('来源：${sourceIds.take(10).join(", ")}');
    }
    if (pack.deferredHitCount > 0) {
      parts.add('注意：${pack.deferredHitCount}条相关记录未包含在审查中');
    }

    return parts.isEmpty ? '' : '\n证据：\n${parts.join('\n')}';
  }

  /// Creates a repair query from a consistency failure for re-retrieval.
  StoryMemoryQuery createRepairQuery(SceneBrief brief, String failureReason) {
    return StoryMemoryQuery(
      projectId: brief.chapterId,
      queryType: StoryMemoryQueryType.concreteFact,
      text: failureReason,
      tags: [
        ...brief.worldNodeIds,
        for (final c in brief.cast) 'char-${c.characterId}',
      ],
      scopeId: '${brief.chapterId}:${brief.sceneId}',
      maxResults: 5,
      tokenBudget: 300,
    );
  }

  SceneReviewDecision _deriveDecision({
    required SceneReviewPassResult judge,
    required SceneReviewPassResult consistency,
    SceneReviewPassResult? readerFlow,
    SceneReviewPassResult? lexicon,
    SceneReviewPassResult? roleplayFidelity,
  }) {
    final allPasses = [
      judge,
      consistency,
      readerFlow,
      lexicon,
      roleplayFidelity,
    ];
    for (final pass in allPasses) {
      if (pass != null && pass.status == SceneReviewStatus.replanScene) {
        return SceneReviewDecision.replanScene;
      }
    }
    for (final pass in allPasses) {
      if (pass != null && pass.status == SceneReviewStatus.rewriteProse) {
        return SceneReviewDecision.rewriteProse;
      }
    }
    return SceneReviewDecision.pass;
  }

  _ParsedReviewOutput _parseReviewOutput(
    String rawText, {
    required String passLabel,
  }) {
    final lines = rawText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    if (lines.isEmpty) {
      return _malformedReviewFallback(rawText, passLabel: passLabel);
    }

    if (lines.length != 2) {
      return _malformedReviewFallback(rawText, passLabel: passLabel);
    }

    final status = _statusFromDecisionLine(lines.first);
    final reason = _reasonFromReasonLine(lines.last);
    if (status != null && reason != null) {
      return _ParsedReviewOutput(status: status, reason: reason);
    }

    return _malformedReviewFallback(rawText, passLabel: passLabel);
  }

  SceneReviewStatus? _statusFromDecisionLine(String line) {
    final normalizedLine = line.replaceFirst('：', ':').trim();
    final colonIndex = normalizedLine.indexOf(':');
    if (colonIndex < 0) return null;

    final label = normalizedLine.substring(0, colonIndex).trim().toLowerCase();
    if (label != '决定') return null;

    final value = normalizedLine
        .substring(colonIndex + 1)
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), '_');

    if (value == 'PASS') {
      return SceneReviewStatus.pass;
    }
    if (value == 'REWRITE_PROSE') {
      return SceneReviewStatus.rewriteProse;
    }
    if (value == 'REPLAN_SCENE') {
      return SceneReviewStatus.replanScene;
    }

    return null;
  }

  String? _reasonFromReasonLine(String line) {
    final normalizedLine = line.replaceFirst('：', ':').trim();
    const label = '原因:';
    if (!normalizedLine.startsWith(label)) return null;
    return normalizedLine.substring(label.length).trim();
  }

  _ParsedReviewOutput _malformedReviewFallback(
    String rawText, {
    required String passLabel,
  }) {
    final parsedReason = _parseReason(rawText).trim();
    final reason = parsedReason.isNotEmpty
        ? '$passLabel评审决定格式异常，已降级为正文复核：$parsedReason'
        : '$passLabel评审决定格式异常，已降级为正文复核。原始输出：'
              '${_compact(rawText, maxChars: 120)}';
    return _ParsedReviewOutput(
      status: SceneReviewStatus.rewriteProse,
      reason: reason,
      usedFallback: true,
    );
  }

  String _parseReason(String rawText) {
    final lines = rawText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    final reasonIndex = lines.indexWhere((line) => line.startsWith('原因：'));
    if (reasonIndex < 0) return '';
    return lines
        .skip(reasonIndex)
        .map((line) => line.replaceFirst(RegExp(r'^原因：\s*'), ''))
        .join('\n');
  }

  String _roleSummary(List<DynamicRoleAgentOutput> roleOutputs) {
    if (roleOutputs.isEmpty) {
      return '无';
    }
    return roleOutputs
        .map(
          (output) => '${output.name}：${_compact(output.text, maxChars: 80)}',
        )
        .join('；');
  }

  String _categoryList(List<SceneReviewCategory> categories) {
    return categories.map(_categoryKey).join(', ');
  }

  String _categoryKey(SceneReviewCategory category) {
    return switch (category) {
      SceneReviewCategory.prose => 'prose',
      SceneReviewCategory.scenePlan => 'scene_plan',
      SceneReviewCategory.chapterPlan => 'chapter_plan',
      SceneReviewCategory.continuity => 'continuity',
      SceneReviewCategory.characterState => 'character_state',
      SceneReviewCategory.worldState => 'world_state',
      SceneReviewCategory.roleplayFidelity => 'roleplay_fidelity',
    };
  }

  String _compact(String value, {required int maxChars}) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxChars) {
      return normalized;
    }
    return '${normalized.substring(0, maxChars - 3)}...';
  }
}

class _ParsedReviewOutput {
  const _ParsedReviewOutput({
    required this.status,
    required this.reason,
    this.usedFallback = false,
  });

  final SceneReviewStatus status;
  final String reason;
  final bool usedFallback;
}

class _RepairedReviewOutput {
  const _RepairedReviewOutput({required this.rawText, required this.parsed});

  final String rawText;
  final _ParsedReviewOutput parsed;
}

/// Maps changed-aspect strings to their corresponding [SceneReviewCategory].
///
/// Aspect strings are matched against known prefixes. Unknown aspects are
/// ignored and produce no categories.
const _aspectToCategory = <String, SceneReviewCategory>{
  'prose': SceneReviewCategory.prose,
  'dialogue': SceneReviewCategory.prose,
  'narration': SceneReviewCategory.prose,
  'style': SceneReviewCategory.prose,
  'scene_plan': SceneReviewCategory.scenePlan,
  'beat': SceneReviewCategory.scenePlan,
  'pacing': SceneReviewCategory.scenePlan,
  'chapter_plan': SceneReviewCategory.chapterPlan,
  'chapter': SceneReviewCategory.chapterPlan,
  'arc': SceneReviewCategory.chapterPlan,
  'continuity': SceneReviewCategory.continuity,
  'timeline': SceneReviewCategory.continuity,
  'transition': SceneReviewCategory.continuity,
  'character_state': SceneReviewCategory.characterState,
  'character': SceneReviewCategory.characterState,
  'cognition': SceneReviewCategory.characterState,
  'role': SceneReviewCategory.characterState,
  'world_state': SceneReviewCategory.worldState,
  'world': SceneReviewCategory.worldState,
  'setting': SceneReviewCategory.worldState,
};

/// Categorize what needs review based on what changed.
///
/// Returns a deduplicated list of [SceneReviewCategory] values derived from
/// the provided [changedAspects]. Unknown aspects are handled gracefully:
/// they are simply ignored.
List<SceneReviewCategory> categorizeChanges(Set<String> changedAspects) {
  final categories = <SceneReviewCategory>{};
  for (final aspect in changedAspects) {
    final normalized = aspect.trim().toLowerCase();
    final category = _aspectToCategory[normalized];
    if (category != null) {
      categories.add(category);
    }
  }
  return categories.toList();
}
