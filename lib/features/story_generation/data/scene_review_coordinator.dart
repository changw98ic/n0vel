import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';

import 'story_generation_pass_retry.dart';
import '../domain/scene_models.dart';
import '../domain/memory_models.dart';
import '../domain/story_pipeline_interfaces.dart';
import 'scene_roleplay_session_models.dart';

class SceneReviewCoordinator implements SceneReviewService {
  SceneReviewCoordinator({required AppSettingsStore settingsStore})
    : _settingsStore = settingsStore;

  final AppSettingsStore _settingsStore;

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

    final judgeFuture = _runReviewPass(
      passName: 'scene judge review',
      taskType: 'scene_judge_review',
      passLabel: 'judge',
      categories: const [
        SceneReviewCategory.prose,
        SceneReviewCategory.scenePlan,
      ],
      brief: brief,
      director: director,
      roleOutputs: roleOutputs,
      prose: prose,
      onStatus: onStatus,
    );
    final consistencyFuture = _runReviewPass(
      passName: 'scene consistency review',
      taskType: 'scene_consistency_review',
      passLabel: 'consistency',
      categories: const [
        SceneReviewCategory.chapterPlan,
        SceneReviewCategory.continuity,
        SceneReviewCategory.characterState,
        SceneReviewCategory.worldState,
      ],
      brief: brief,
      director: director,
      roleOutputs: roleOutputs,
      prose: prose,
      retrievalPack: retrievalPack,
      onStatus: onStatus,
    );
    final Future<SceneReviewPassResult?> readerFlowFuture =
        enableReaderFlowReview
        ? _runReviewPass(
            passName: 'scene reader-flow review',
            taskType: 'scene_reader_flow_review',
            passLabel: 'reader_flow',
            categories: const [SceneReviewCategory.prose],
            brief: brief,
            director: director,
            roleOutputs: roleOutputs,
            prose: prose,
            onStatus: onStatus,
          )
        : Future<SceneReviewPassResult?>.value(null);
    final Future<SceneReviewPassResult?> lexiconFuture = enableLexiconReview
        ? _runReviewPass(
            passName: 'scene lexicon review',
            taskType: 'scene_lexicon_review',
            passLabel: 'lexicon',
            categories: const [SceneReviewCategory.prose],
            brief: brief,
            director: director,
            roleOutputs: roleOutputs,
            prose: prose,
            onStatus: onStatus,
          )
        : Future<SceneReviewPassResult?>.value(null);
    final Future<SceneReviewPassResult?> roleplayFidelityFuture =
        roleplaySession != null && !roleplaySession.isEmpty
        ? _runReviewPass(
            passName: 'scene roleplay fidelity review',
            taskType: 'scene_roleplay_fidelity_review',
            passLabel: 'roleplay_fidelity',
            categories: const [SceneReviewCategory.roleplayFidelity],
            brief: brief,
            director: director,
            roleOutputs: roleOutputs,
            prose: prose,
            roleplaySession: roleplaySession,
            onStatus: onStatus,
          )
        : Future<SceneReviewPassResult?>.value(null);

    final results = await Future.wait<SceneReviewPassResult?>([
      judgeFuture,
      consistencyFuture,
      readerFlowFuture,
      lexiconFuture,
      roleplayFidelityFuture,
    ]);

    final reviewResult = SceneReviewResult(
      judge: results[0]!,
      consistency: results[1]!,
      readerFlow: results[2],
      lexicon: results[3],
      roleplayFidelity: results[4],
      decision: _deriveDecision(
        judge: results[0]!,
        consistency: results[1]!,
        readerFlow: results[2],
        lexicon: results[3],
        roleplayFidelity: results[4],
      ),
    );
    return SceneReviewResult(
      judge: reviewResult.judge,
      consistency: reviewResult.consistency,
      readerFlow: reviewResult.readerFlow,
      lexicon: reviewResult.lexicon,
      roleplayFidelity: reviewResult.roleplayFidelity,
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
              'Output exactly 2 lines. The first line MUST be exactly one of:\n'
              '决定：PASS\n'
              '决定：REWRITE_PROSE\n'
              '决定：REPLAN_SCENE\n'
              'If uncertain, choose 决定：REWRITE_PROSE. Never output X, FAIL, '
              'MAYBE, or explanatory text before the decision.\n'
              'The second line MUST start with 原因：. Only flag blocking issues. '
              'Keep the second line brief.',
        ),
        AppLlmChatMessage(
          role: 'user',
          content: [
            '任务：$taskType',
            '评审：$passLabel',
            '评审类别：${_categoryList(categories)}',
            '规则：只找阻塞问题，不改写正文',
            '场：${_compact(brief.sceneTitle, maxChars: 40)}',
            '导演：${_compact(director.text, maxChars: 120)}',
            '角色输入：${_roleSummary(roleOutputs)}',
            if (roleplaySession != null && !roleplaySession.isEmpty)
              '角色扮演过程：${roleplaySession.toPromptText()}',
            if (roleplaySession != null && !roleplaySession.isEmpty)
              '忠实性规则：正文必须忠于角色扮演过程中的可见动作、对白、裁决事实和局面推进；若正文跳过关键互动、违背裁决事实、让角色越权知道隐藏信息，判为REWRITE_PROSE或REPLAN_SCENE。',
            '正文：${prose.text}',
            if (evidenceSection.isNotEmpty) evidenceSection,
          ].join('\n'),
        ),
      ],
    );
    if (!result.succeeded) {
      throw StateError(result.detail ?? 'Scene $passLabel review failed.');
    }

    var rawText = result.text!.trim();
    var parsed = _parseReviewOutput(rawText, passLabel: passLabel);
    if (parsed.usedFallback) {
      onStatus?.call(
        '场景 ${brief.chapterId}/${brief.sceneId} · $passName format retry',
      );
      final repaired = await _repairReviewFormat(
        passName: passName,
        passLabel: passLabel,
        rawText: rawText,
      );
      if (repaired != null && !repaired.parsed.usedFallback) {
        rawText = repaired.rawText;
        parsed = repaired.parsed;
      }
    }
    if (parsed.usedFallback) {
      onStatus?.call(
        '场景 ${brief.chapterId}/${brief.sceneId} · $passName format fallback',
      );
    }
    return SceneReviewPassResult(
      status: parsed.status,
      reason: parsed.reason,
      rawText: rawText,
      categories: categories,
    );
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
              'Normalize malformed review output into exactly 2 lines. '
              'The first line MUST be exactly one of:\n'
              '决定：PASS\n'
              '决定：REWRITE_PROSE\n'
              '决定：REPLAN_SCENE\n'
              'If the original decision is missing, invalid, ambiguous, or X, '
              'choose 决定：REWRITE_PROSE.\n'
              'The second line MUST start with 原因： and briefly preserve the '
              'original reason.',
        ),
        AppLlmChatMessage(
          role: 'user',
          content: ['原始评审输出：', rawText].join('\n'),
        ),
      ],
      maxTransientRetries: 1,
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

    for (final line in lines) {
      final status = _statusFromDecisionLine(line);
      if (status == null) continue;
      return _ParsedReviewOutput(status: status, reason: _parseReason(rawText));
    }

    return _malformedReviewFallback(rawText, passLabel: passLabel);
  }

  SceneReviewStatus? _statusFromDecisionLine(String line) {
    final normalizedLine = line
        .replaceFirst(RegExp(r'^[\s\-\*\d.、)）]+'), '')
        .replaceFirst('：', ':')
        .trim();
    final colonIndex = normalizedLine.indexOf(':');
    if (colonIndex < 0) return null;

    final label = normalizedLine.substring(0, colonIndex).trim().toLowerCase();
    if (label != '决定' && label != 'decision') return null;

    final value = normalizedLine
        .substring(colonIndex + 1)
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[`*。；;，,.!！?？]'), '')
        .replaceAll(RegExp(r'\s+'), '_');

    if (value == 'PASS' || value == 'OK' || value == '通过' || value == '合格') {
      return SceneReviewStatus.pass;
    }
    if (value == 'REWRITE_PROSE' ||
        value == 'REWRITE' ||
        value == 'REFINE' ||
        value == '修改正文' ||
        value == '重写正文' ||
        value == '需重写' ||
        value == '不通过') {
      return SceneReviewStatus.rewriteProse;
    }
    if (value == 'REPLAN_SCENE' ||
        value == 'REPLAN' ||
        value == '重新规划' ||
        value == '重规划' ||
        value == '结构重做') {
      return SceneReviewStatus.replanScene;
    }

    return null;
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
