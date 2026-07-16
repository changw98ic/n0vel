import '../character_consistency_verifier.dart';
import '../scene_hard_gates.dart';
import '../scene_review_models.dart';
import '../scene_runtime_models.dart';
import '../../domain/contracts/event_log.dart';
import '../../domain/contracts/memory_policy.dart';
import '../../domain/contracts/stage_runner.dart';
import '../../domain/memory_models.dart';
import '../../domain/story_pipeline_interfaces.dart';
import '../step_io.dart';
import '../../domain/contracts/pipeline_role_contract.dart';
import '../../domain/contracts/typed_artifact.dart';

class ReviewStep implements PipelineStage<ReviewInput, ReviewOutput> {
  ReviewStep({
    required SceneReviewService reviewCoordinator,
    CharacterConsistencyVerifier? consistencyVerifier,
    required this.maxProseRetries,
    required PipelineEventLog eventLog,
    this.hardGatesEnabled = true,
  }) : _reviewCoordinator = reviewCoordinator,
       _consistencyVerifier = consistencyVerifier,
       _eventLog = eventLog;

  final SceneReviewService _reviewCoordinator;
  final CharacterConsistencyVerifier? _consistencyVerifier;
  final PipelineEventLog _eventLog;
  final int maxProseRetries;
  final bool hardGatesEnabled;

  @override
  String get roleId => 'review';
  @override
  ArtifactType get outputType => ArtifactType.reviewResult;
  @override
  int get maxRetries => 2;

  @override
  Future<ReviewOutput> execute(ReviewInput input, Object context) async {
    final brief = input.brief;
    final prose = input.editorial.prose;

    SceneReviewResult? lengthReview;
    SceneReviewResult? minimumLengthReview;
    SceneReviewResult? truncationReview;
    SceneReviewResult? styleReview;
    SceneReviewResult? hookReview;
    SceneReviewResult? propReview;
    SceneReviewResult? physicalReview;

    // 1. Check length first (always runs — mechanical check).
    lengthReview = _reviewOverlongProse(brief: brief, prose: prose);
    if (lengthReview != null) {
      if (input.softFailureCount + 1 <= maxProseRetries) {
        return ReviewOutput(
          review: lengthReview,
          wasLengthRetry: true,
          action: SceneReviewDecision.rewriteProse,
        );
      }
    }

    if (hardGatesEnabled) {
      final minimumLengthReason = sceneMinimumLengthViolationText(
        brief: brief,
        proseText: prose.text,
      );
      if (minimumLengthReason != null) {
        minimumLengthReview = _buildRewriteReview(
          reason: minimumLengthReason,
          judgeCategories: const [SceneReviewCategory.prose],
          consistencyPassReason: 'minimum-length gate 未进入一致性审查。',
          consistencyCategories: const [
            SceneReviewCategory.chapterPlan,
            SceneReviewCategory.continuity,
          ],
        );
        if (input.softFailureCount + 1 <= maxProseRetries) {
          _emitGateEvent(
            brief: brief,
            code: FailureCode.qualityFail,
            message: 'prose below minimum length -> rewrite',
          );
          return ReviewOutput(
            review: minimumLengthReview,
            wasLengthRetry: true,
            action: SceneReviewDecision.rewriteProse,
          );
        }
      }

      final truncationReason = sceneProseTruncationViolationText(prose.text);
      if (truncationReason != null) {
        truncationReview = _buildRewriteReview(
          reason: truncationReason,
          judgeCategories: const [SceneReviewCategory.prose],
          consistencyPassReason: 'truncation gate 未进入一致性审查。',
          consistencyCategories: const [
            SceneReviewCategory.chapterPlan,
            SceneReviewCategory.continuity,
          ],
        );
        if (input.softFailureCount + 1 <= maxProseRetries) {
          _emitGateEvent(
            brief: brief,
            code: FailureCode.qualityFail,
            message: 'prose truncation -> rewrite',
          );
          return ReviewOutput(
            review: truncationReview,
            wasLengthRetry: false,
            action: SceneReviewDecision.rewriteProse,
          );
        }
      }
    }

    if (hardGatesEnabled) {
      // 1b. Style gate: dialogue ratio check.
      styleReview = _reviewStyleDeficit(brief: brief, prose: prose);
      if (styleReview != null) {
        if (input.softFailureCount + 1 <= maxProseRetries) {
          _emitGateEvent(
            brief: brief,
            code: FailureCode.qualityFail,
            message: 'dialogue ratio low -> rewrite',
          );
          return ReviewOutput(
            review: styleReview,
            wasLengthRetry: false,
            action: SceneReviewDecision.rewriteProse,
          );
        }
      }

      // 1c. Opening hook gate: first scene must open with suspense.
      hookReview =
          _reviewOpeningHookDeficit(brief: brief, prose: prose) ??
          _reviewClosingHookDeficit(brief: brief, prose: prose);
      if (hookReview != null) {
        if (input.softFailureCount + 1 <= maxProseRetries) {
          _emitGateEvent(
            brief: brief,
            code: FailureCode.qualityFail,
            message: 'hook deficit -> rewrite',
          );
          return ReviewOutput(
            review: hookReview,
            wasLengthRetry: false,
            action: SceneReviewDecision.rewriteProse,
          );
        }
      }

      // 1d. Prop consistency gate: detect scene-setting contradictions.
      propReview = _reviewPropConsistency(brief: brief, prose: prose);
      if (propReview != null) {
        if (input.softFailureCount + 1 <= maxProseRetries) {
          _emitGateEvent(
            brief: brief,
            code: FailureCode.qualityFail,
            message: 'prop consistency violation -> rewrite',
          );
          return ReviewOutput(
            review: propReview,
            wasLengthRetry: false,
            action: SceneReviewDecision.rewriteProse,
          );
        }
      }

      final physicalReason = scenePhysicalContinuityViolationText(prose.text);
      if (physicalReason != null) {
        physicalReview = _buildRewriteReview(
          reason: physicalReason,
          judgeCategories: const [SceneReviewCategory.prose],
          consistencyPassReason: 'physical continuity gate 未进入一致性审查。',
          consistencyCategories: const [
            SceneReviewCategory.chapterPlan,
            SceneReviewCategory.continuity,
          ],
        );
        if (input.softFailureCount + 1 <= maxProseRetries) {
          _emitGateEvent(
            brief: brief,
            code: FailureCode.qualityFail,
            message: 'physical continuity violation -> rewrite',
          );
          return ReviewOutput(
            review: physicalReview,
            wasLengthRetry: false,
            action: SceneReviewDecision.rewriteProse,
          );
        }
      }
    }

    // 2. Quality review (or reuse length/style/hook/prop review when retries exhausted).
    final review =
        lengthReview ??
        minimumLengthReview ??
        truncationReview ??
        styleReview ??
        hookReview ??
        propReview ??
        physicalReview ??
        await _reviewCoordinator.review(
          brief: brief,
          director: input.plan.director,
          roleOutputs: input.roleplay.roleOutputs,
          prose: prose,
          roleplaySession: input.roleplay.session,
          retrievalPack: input.context.retrievalPack,
          canonFacts: _canonFactsFrom(input.context),
          enableReaderFlowReview: brief.formalExecution,
          enableLexiconReview: brief.formalExecution,
        );

    // 3. Post-generation consistency check (only when review passed).
    if (_consistencyVerifier != null &&
        review.decision == SceneReviewDecision.pass) {
      final consistencyReport = await _consistencyVerifier.postGenerationCheck(
        brief: brief,
        director: input.plan.director,
        roleOutputs: input.roleplay.roleOutputs,
        prose: prose,
        cast: input.plan.resolvedCast,
      );
      if (consistencyReport.hasBlockingIssues) {
        _emitGateEvent(
          brief: brief,
          code: FailureCode.soulViolation,
          message: 'consistency check failed -> replan',
        );
        return ReviewOutput(
          review: review,
          wasLengthRetry: false,
          action: SceneReviewDecision.replanScene,
        );
      }
    }

    return ReviewOutput(
      review: review,
      wasLengthRetry: false,
      action: review.decision,
    );
  }

  void _emitGateEvent({
    required SceneBrief brief,
    required FailureCode code,
    required String message,
  }) {
    _eventLog.emit(
      PipelineEvent(
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        stageId: 'review',
        eventType: 'hard_gate',
        failureCode: code,
        metadata: {'sceneId': brief.sceneId, 'message': message},
      ),
    );
  }

  List<StoryMemoryChunk> _canonFactsFrom(ContextEnrichmentOutput context) {
    final byId = <String, StoryMemoryChunk>{};
    for (final chunk in context.cachedAssembly?.memoryChunks ?? const []) {
      if (chunk.tier == MemoryTier.canon) {
        byId[chunk.id] = chunk;
      }
    }
    for (final hit in context.retrievalPack?.hits ?? const []) {
      final chunk = hit.chunk;
      if (chunk.tier == MemoryTier.canon) {
        byId[chunk.id] = chunk;
      }
    }
    return byId.values.toList(growable: false);
  }

  // ---------------------------------------------------------------------------
  // Helpers (ported from PipelineStageRunnerImpl)
  // ---------------------------------------------------------------------------

  SceneReviewResult? _reviewOverlongProse({
    required SceneBrief brief,
    required SceneProseDraft prose,
  }) {
    final hardLimit = _sceneProseHardLimit(brief.targetLength);
    final actualLength = prose.text.trim().length;
    if (actualLength <= hardLimit) {
      return null;
    }

    final reason =
        '正文长度$actualLength字超过场景硬上限$hardLimit字（目标${brief.targetLength}字），'
        '需要压缩到目标附近，聚焦既有情节。';
    return _buildRewriteReview(
      reason: reason,
      judgeCategories: const [SceneReviewCategory.prose],
      consistencyPassReason: '长度检查前未进入一致性审查。',
      consistencyCategories: const [
        SceneReviewCategory.chapterPlan,
        SceneReviewCategory.continuity,
        SceneReviewCategory.characterState,
        SceneReviewCategory.worldState,
      ],
    );
  }

  int _sceneProseHardLimit(int targetLength) {
    final normalizedTarget = targetLength < 1 ? 400 : targetLength;
    final doubled = normalizedTarget * 2;
    final floor = normalizedTarget + 400;
    return doubled > floor ? doubled : floor;
  }

  SceneReviewResult? _reviewStyleDeficit({
    required SceneBrief brief,
    required SceneProseDraft prose,
  }) {
    final reason = sceneDialogueRatioViolationText(prose.text);
    if (reason == null) return null;

    return _buildRewriteReview(
      reason: reason,
      judgeCategories: const [SceneReviewCategory.prose],
      consistencyPassReason: 'style gate 未进入一致性审查。',
      consistencyCategories: const [
        SceneReviewCategory.chapterPlan,
        SceneReviewCategory.continuity,
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Hook gates
  // ---------------------------------------------------------------------------

  // Aligned with _computeHookStrength in the benchmark scorer.
  static const _hookActionVerbs = [
    '冲',
    '跑',
    '跳',
    '抓',
    '摔',
    '撞',
    '翻',
    '拽',
    '喊',
    '叫',
    // Common decisive Chinese actions. The hook gate is meant to reject
    // atmospheric openings, not a concrete action such as "拍上门禁终端".
    '拍',
    '按',
    '推',
    '拉',
    '挥',
    '砸',
    '踢',
    '扑',
    '扯',
    '扣',
    '拔',
    '压',
  ];

  static const _hookSuspenseWords = ['突然', '竟然', '意外', '发现', '秘密', '失踪'];

  static const _forbiddenEnvironmentOpenings = [
    '清晨',
    '夜色',
    '阴影',
    '街道',
    '空气中',
    '天幕',
    '远处',
    '楼道',
    '窗外',
  ];

  /// Scene-type to forbidden-prop mapping.
  static const _scenePropConflicts = {
    'abandoned': [
      '咖啡杯',
      '咖啡',
      '热茶',
      '茶杯',
      '桌面',
      '纸币',
      '电脑',
      '空调',
      '冰箱',
      '收银',
      '电视',
      'WiFi',
      '手机充电',
    ],
    'outdoor': ['桌子', '椅子', '电脑', '文件柜', '茶杯', '沙发', '床', '衣柜'],
    'dock': ['办公桌', '电脑', '文件柜', '空调', '沙发'],
    'warehouse': ['咖啡杯', '热茶', '沙发', '电视'],
  };

  static const _sceneTypeKeywords = {
    'abandoned': ['废弃', '荒废', '破旧', '坍塌', '残破', '无人', '废弃磨坊'],
    'outdoor': ['户外', '码头', '巷子', '街道', '江边', '山坡', '树林'],
    'dock': ['码头', '栈桥', '货轮', '集装箱', '港口'],
    'warehouse': ['仓库', '厂房', '工棚'],
  };

  SceneReviewResult? _reviewPropConsistency({
    required SceneBrief brief,
    required SceneProseDraft prose,
  }) {
    final text = prose.text.trim();
    if (text.isEmpty) return null;

    // Determine scene type from scene summary and title.
    final sceneContext = '${brief.sceneSummary} ${brief.sceneTitle}';
    String? matchedType;
    for (final entry in _sceneTypeKeywords.entries) {
      if (entry.value.any((kw) => sceneContext.contains(kw))) {
        matchedType = entry.key;
        break;
      }
    }
    if (matchedType == null) return null;

    final forbidden = _scenePropConflicts[matchedType]!;
    final violations = forbidden.where((p) => text.contains(p)).toList();
    if (violations.isEmpty) return null;

    final reason =
        '场景类型「$matchedType」中出现了不合理的道具：${violations.join('、')}。'
        '请在重写时移除这些与场景设定矛盾的物品。';

    return _buildRewriteReview(
      reason: reason,
      judgeCategories: const [SceneReviewCategory.worldState],
      consistencyPassReason: 'prop consistency gate 未进入一致性审查。',
      consistencyCategories: const [
        SceneReviewCategory.chapterPlan,
        SceneReviewCategory.continuity,
      ],
    );
  }

  /// Compute opening hook strength using the same criteria as the benchmark
  /// scorer. Returns null when the scene passes the threshold (>= 0.30).
  SceneReviewResult? _reviewOpeningHookDeficit({
    required SceneBrief brief,
    required SceneProseDraft prose,
  }) {
    final isFirstScene = brief.sceneIndex == 0;
    if (!isFirstScene) return null;

    final text = prose.text.trim();
    if (text.isEmpty) return null;

    final first100 = text.length > 100 ? text.substring(0, 100) : text;
    final first20 = text.length > 20 ? text.substring(0, 20) : text;
    final first50 = text.length > 50 ? text.substring(0, 50) : text;

    // Compute hook strength aligned with benchmark _computeHookStrength.
    var score = 0.0;
    final List<String> hits = [];
    final List<String> missing = [];

    // Action verbs (+0.2)
    if (_hookActionVerbs.any((v) => first100.contains(v))) {
      score += 0.2;
      hits.add('动作动词');
    } else {
      missing.add('动作动词(冲/跑/抓/摔/撞/翻/喊/拍/推/拉/砸/踢)');
    }

    // Question mark (+0.2)
    if (first100.contains('？') || first100.contains('?')) {
      score += 0.2;
      hits.add('疑问句');
    } else {
      missing.add('疑问句(？)');
    }

    // Exclamation mark (+0.15)
    if (first100.contains('！') || first100.contains('!')) {
      score += 0.15;
      hits.add('感叹句');
    }

    // Direct dialogue within the opening beat (+0.15). A decisive action
    // followed immediately by speech is as much of a hook as speech at byte 0.
    if (first50.contains('「') || first50.contains('"')) {
      score += 0.15;
      hits.add('前50字内对话');
    }

    // Short sentence opening (+0.15)
    if (first20.contains('。') || first20.contains('…')) {
      score += 0.15;
      hits.add('短句开头');
    }

    // Suspense words (+0.15)
    if (_hookSuspenseWords.any((w) => first100.contains(w))) {
      score += 0.15;
      hits.add('悬念词');
    } else {
      missing.add('悬念词(突然/竟然/意外/发现/秘密/失踪)');
    }

    if (score >= 0.30) return null;

    // Build diagnostic feedback.
    final forbidden = _forbiddenEnvironmentOpenings
        .where((p) => text.startsWith(p))
        .toList();
    final forbiddenNote = forbidden.isNotEmpty
        ? ' 命中禁止环境白描开头「${forbidden.first}」。'
        : '';
    final opening = text.length > 50 ? text.substring(0, 50) : text;
    final pct = (score * 100).toStringAsFixed(0);
    final missingNote = missing.isEmpty ? '' : '缺少：${missing.join("、")}。';
    final hitsNote = hits.isEmpty ? '' : '已有：${hits.join("、")}。';

    final reason =
        '开头钩子强度$pct%低于30%阈值。'
        '前50字「$opening」$forbiddenNote$hitsNote$missingNote'
        '这是机械门：仅有动作动词只能得到20%，不得原样保留开头。'
        '请在重写时：1）用动作动词或角色对话开场，禁止环境白描；'
        '2）前100字内必须加入悬念词(突然/竟然/意外/发现/秘密/失踪)或疑问句；'
        '3）用短句开头增加冲击力（前20字内出现句号或省略号）；'
        '4）参考好开头：角色直接行动+悬念，如「苏薇冲进办公室，手里攥着一份失踪报告」。';
    return _buildHookGateReview(reason: reason);
  }

  SceneReviewResult? _reviewClosingHookDeficit({
    required SceneBrief brief,
    required SceneProseDraft prose,
  }) {
    final isLastScene =
        brief.totalScenesInChapter > 0 &&
        brief.sceneIndex == brief.totalScenesInChapter - 1;
    if (!isLastScene) return null;

    final text = prose.text.trim();
    if (text.isEmpty) return null;

    final violation = sceneChapterEndingHookViolationText(text);
    if (violation == null) return null;
    return _buildHookGateReview(
      reason:
          '$violation。请在最后一段留下未回答问题、未完成动作或具体威胁，'
          '并删除“恢复平静/已经解决”式收口。',
    );
  }

  SceneReviewResult _buildRewriteReview({
    required String reason,
    required List<SceneReviewCategory> judgeCategories,
    required String consistencyPassReason,
    required List<SceneReviewCategory> consistencyCategories,
  }) {
    final judge = SceneReviewPassResult(
      status: SceneReviewStatus.rewriteProse,
      reason: reason,
      rawText: '决定：REWRITE_PROSE\n原因：$reason',
      categories: judgeCategories,
    );
    final consistency = SceneReviewPassResult(
      status: SceneReviewStatus.pass,
      reason: '',
      rawText: '决定：PASS\n原因：$consistencyPassReason',
      categories: consistencyCategories,
    );
    final review = SceneReviewResult(
      judge: judge,
      consistency: consistency,
      decision: SceneReviewDecision.rewriteProse,
    );
    return SceneReviewResult(
      judge: review.judge,
      consistency: review.consistency,
      decision: review.decision,
      refinementGuidance: review.synthesizeGuidance(),
    );
  }

  SceneReviewResult _buildHookGateReview({required String reason}) {
    final judge = SceneReviewPassResult(
      status: SceneReviewStatus.rewriteProse,
      reason: reason,
      rawText: '决定：REWRITE_PROSE\n原因：$reason',
      categories: const [SceneReviewCategory.prose],
    );
    const consistency = SceneReviewPassResult(
      status: SceneReviewStatus.pass,
      reason: '',
      rawText: '决定：PASS\n原因：hook gate 未进入一致性审查。',
      categories: [
        SceneReviewCategory.chapterPlan,
        SceneReviewCategory.continuity,
      ],
    );
    final review = SceneReviewResult(
      judge: judge,
      consistency: consistency,
      decision: SceneReviewDecision.rewriteProse,
    );
    return SceneReviewResult(
      judge: review.judge,
      consistency: review.consistency,
      decision: review.decision,
      refinementGuidance: review.synthesizeGuidance(),
    );
  }
}
