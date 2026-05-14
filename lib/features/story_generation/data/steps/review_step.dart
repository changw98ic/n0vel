import '../character_consistency_verifier.dart';
import '../prose_style_analyzer.dart';
import '../scene_review_models.dart';
import '../scene_runtime_models.dart';
import '../../domain/story_pipeline_interfaces.dart';
import '../step_io.dart';

class ReviewStep {
  ReviewStep({
    required SceneReviewService reviewCoordinator,
    CharacterConsistencyVerifier? consistencyVerifier,
    required this.maxProseRetries,
  })  : _reviewCoordinator = reviewCoordinator,
        _consistencyVerifier = consistencyVerifier;

  final SceneReviewService _reviewCoordinator;
  final CharacterConsistencyVerifier? _consistencyVerifier;
  final int maxProseRetries;

  Future<ReviewOutput> execute(
    ReviewInput input, {
    void Function(String)? onStatus,
  }) async {
    final brief = input.brief;
    final prose = input.editorial.prose;

    // 1. Check length first.
    final lengthReview = _reviewOverlongProse(
      brief: brief,
      prose: prose,
    );
    if (lengthReview != null) {
      if (input.softFailureCount + 1 <= maxProseRetries) {
        return ReviewOutput(
          review: lengthReview,
          wasLengthRetry: true,
          action: SceneReviewDecision.rewriteProse,
        );
      }
      // Exhausted length retries — fall through to quality review using
      // the length review result.
    }

    // 1b. Style gate: dialogue ratio check.
    final styleReview = _reviewStyleDeficit(
      brief: brief,
      prose: prose,
    );
    if (styleReview != null) {
      if (input.softFailureCount + 1 <= maxProseRetries) {
        onStatus?.call(
          '场景 ${brief.sceneId} · dialogue ratio low -> rewrite',
        );
        return ReviewOutput(
          review: styleReview,
          wasLengthRetry: false,
          action: SceneReviewDecision.rewriteProse,
        );
      }
    }

    // 2. Quality review (or reuse length/style review when retries exhausted).
    final review = lengthReview ?? styleReview ??
        await _reviewCoordinator.review(
          brief: brief,
          director: input.plan.director,
          roleOutputs: input.roleplay.roleOutputs,
          prose: prose,
          roleplaySession: input.roleplay.session,
          retrievalPack: input.context.retrievalPack,
          onStatus: onStatus,
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
        onStatus?.call(
          '场景 ${brief.sceneId} · consistency check failed -> replan',
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

  // ---------------------------------------------------------------------------
  // Helpers (ported from ChapterGenerationOrchestrator)
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
    final judge = SceneReviewPassResult(
      status: SceneReviewStatus.rewriteProse,
      reason: reason,
      rawText: '决定：REWRITE_PROSE\n原因：$reason',
      categories: const [SceneReviewCategory.prose],
    );
    const consistency = SceneReviewPassResult(
      status: SceneReviewStatus.pass,
      reason: '',
      rawText: '决定：PASS\n原因：长度检查前未进入一致性审查。',
      categories: [
        SceneReviewCategory.chapterPlan,
        SceneReviewCategory.continuity,
        SceneReviewCategory.characterState,
        SceneReviewCategory.worldState,
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
    final fingerprint = ProseStyleAnalyzer().analyze(prose.text);
    if (fingerprint.dialogueRatio >= 0.20) return null;

    final percentage = (fingerprint.dialogueRatio * 100).toStringAsFixed(1);
    final reason =
        '对话占比$percentage%低于最低要求20%。'
        '请在重写时：1）将连续纯叙述段落改为角色对白；'
        '2）每隔2段叙述插入对话；'
        '3）用「」包裹对白，确保至少6个独立对话回合。';
    final judge = SceneReviewPassResult(
      status: SceneReviewStatus.rewriteProse,
      reason: reason,
      rawText: '决定：REWRITE_PROSE\n原因：$reason',
      categories: const [SceneReviewCategory.prose],
    );
    const consistency = SceneReviewPassResult(
      status: SceneReviewStatus.pass,
      reason: '',
      rawText: '决定：PASS\n原因：style gate 未进入一致性审查。',
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
