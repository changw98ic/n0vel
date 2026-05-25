import 'scene_review_models.dart' show SceneReviewDecision;

enum PipelineRunLoopAction { replanScene, retryEditorial, finish }

class PipelineRunLoopDecision {
  const PipelineRunLoopDecision({
    required this.action,
    required this.nextAttempt,
    required this.nextSoftFailureCount,
    required this.nextSceneReplanCount,
    this.statusMessage,
    this.shouldPolishBeforeFinalization = false,
    this.shouldNotifySpeculationReady = false,
  });

  final PipelineRunLoopAction action;
  final int nextAttempt;
  final int nextSoftFailureCount;
  final int nextSceneReplanCount;
  final String? statusMessage;
  final bool shouldPolishBeforeFinalization;
  final bool shouldNotifySpeculationReady;
}

/// Pure loop-control policy for the scene replan and editorial retry loops.
class PipelineRunLoopPolicy {
  const PipelineRunLoopPolicy({
    required this.maxProseRetries,
    required this.maxSceneReplanRetries,
  });

  final int maxProseRetries;
  final int maxSceneReplanRetries;

  PipelineRunLoopDecision decideAfterReview({
    required SceneReviewDecision action,
    required bool wasLengthRetry,
    required int attempt,
    required int softFailureCount,
    required int sceneReplanCount,
  }) {
    if (!wasLengthRetry &&
        action == SceneReviewDecision.replanScene &&
        sceneReplanCount < maxSceneReplanRetries) {
      final nextSceneReplanCount = sceneReplanCount + 1;
      return PipelineRunLoopDecision(
        action: PipelineRunLoopAction.replanScene,
        nextAttempt: attempt,
        nextSoftFailureCount: softFailureCount,
        nextSceneReplanCount: nextSceneReplanCount,
        statusMessage:
            'review issue -> scene replan '
            '$nextSceneReplanCount/$maxSceneReplanRetries',
      );
    }

    if (action == SceneReviewDecision.rewriteProse) {
      final nextSoftFailureCount = softFailureCount + 1;
      if (nextSoftFailureCount <= maxProseRetries) {
        return PipelineRunLoopDecision(
          action: PipelineRunLoopAction.retryEditorial,
          nextAttempt: attempt + 1,
          nextSoftFailureCount: nextSoftFailureCount,
          nextSceneReplanCount: sceneReplanCount,
          statusMessage: wasLengthRetry
              ? 'prose length issue -> editorial retry'
              : 'review issue -> editorial retry',
        );
      }
      return PipelineRunLoopDecision(
        action: PipelineRunLoopAction.finish,
        nextAttempt: attempt,
        nextSoftFailureCount: nextSoftFailureCount,
        nextSceneReplanCount: sceneReplanCount,
        shouldPolishBeforeFinalization: !wasLengthRetry,
      );
    }

    if (action == SceneReviewDecision.pass) {
      return PipelineRunLoopDecision(
        action: PipelineRunLoopAction.finish,
        nextAttempt: attempt,
        nextSoftFailureCount: softFailureCount,
        nextSceneReplanCount: sceneReplanCount,
        shouldPolishBeforeFinalization: true,
        shouldNotifySpeculationReady: true,
      );
    }

    return PipelineRunLoopDecision(
      action: PipelineRunLoopAction.finish,
      nextAttempt: attempt,
      nextSoftFailureCount: softFailureCount,
      nextSceneReplanCount: sceneReplanCount,
    );
  }
}
