import '../scene_pipeline_models.dart' as pipeline;
import '../scene_polish_pass.dart';
import '../scene_review_models.dart';
import '../scene_runtime_models.dart';
import '../step_io.dart';

class PolishStep {
  PolishStep({required ScenePolishPass polishPass}) : _polishPass = polishPass;

  final ScenePolishPass _polishPass;

  Future<PolishOutput> execute(
    PolishInput input, {
    void Function(String)? onStatus,
  }) async {
    final brief = input.brief;
    final editorial = input.editorial;
    final review = input.review.review;
    var outputProse = editorial.prose;

    // 1. Refinement when rewriteProse and retries exhausted.
    if (!input.review.wasLengthRetry &&
        review.decision == SceneReviewDecision.rewriteProse) {
      final refinedDraft = await _refineDraftIfNeeded(
        brief: brief,
        draft: pipeline.SceneEditorialDraft(
          text: editorial.draft.text,
          beatCount: editorial.draft.beatCount,
          attempt: editorial.draft.attempt,
        ),
        resolvedBeats: input.beats.runtimeBeats,
        review: review,
      );
      outputProse = SceneProseDraft(
        text: refinedDraft.text,
        attempt: refinedDraft.attempt,
      );
    }

    // 2. Final polish pass (only on passed reviews with metadata opt-in).
    if (!input.review.wasLengthRetry &&
        review.decision == SceneReviewDecision.pass &&
        _shouldRunFinalPolish(brief)) {
      onStatus?.call(
        '场景 ${brief.chapterId}/${brief.sceneId} · reader polish',
      );
      final polishResult = await _polishPass.polish(
        brief: brief,
        editorialDraft: pipeline.SceneEditorialDraft(
          text: outputProse.text,
          beatCount: editorial.draft.beatCount,
          attempt: outputProse.attempt,
        ),
        resolvedBeats: input.beats.runtimeBeats,
        reviewFeedback: review.editorialFeedback,
        refinementGuidance: review.refinementGuidance,
      );
      final polishedText = polishResult.text.trim();
      if (!polishResult.usedLocalFallback && polishedText.isNotEmpty) {
        outputProse = SceneProseDraft(
          text: polishedText,
          attempt: outputProse.attempt,
        );
      }
    }

    return PolishOutput(prose: outputProse);
  }

  // ---------------------------------------------------------------------------
  // Helpers (ported from ChapterGenerationOrchestrator)
  // ---------------------------------------------------------------------------

  Future<pipeline.SceneEditorialDraft> _refineDraftIfNeeded({
    required SceneBrief brief,
    required pipeline.SceneEditorialDraft draft,
    required List<ResolvedBeat> resolvedBeats,
    required SceneReviewResult review,
  }) async {
    if (review.decision != SceneReviewDecision.rewriteProse) {
      return draft;
    }
    final polishResult = await _polishPass.polish(
      brief: brief,
      editorialDraft: draft,
      resolvedBeats: resolvedBeats,
      reviewFeedback: review.editorialFeedback,
      refinementGuidance:
          review.refinementGuidance ?? review.synthesizeGuidance(),
    );
    if (polishResult.text.trim().isEmpty) {
      return draft;
    }
    return pipeline.SceneEditorialDraft(
      text: polishResult.text,
      beatCount: draft.beatCount,
      attempt: draft.attempt,
    );
  }

  bool _shouldRunFinalPolish(SceneBrief brief) {
    final value =
        brief.metadata['enableFinalPolish'] ??
        brief.metadata['readerPolish'] ??
        brief.metadata['finalPolish'];
    if (value is bool) {
      return value;
    }
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return const {
      'true',
      '1',
      'yes',
      'on',
      'always',
      'reader',
    }.contains(normalized);
  }
}
