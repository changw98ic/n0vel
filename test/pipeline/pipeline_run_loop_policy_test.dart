import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/pipeline_run_loop_policy.dart';
import 'package:novel_writer/features/story_generation/data/scene_review_models.dart';

void main() {
  group('PipelineRunLoopPolicy', () {
    test('replans non-length review failures while scene budget remains', () {
      const policy = PipelineRunLoopPolicy(
        maxProseRetries: 2,
        maxSceneReplanRetries: 1,
      );

      final decision = policy.decideAfterReview(
        action: SceneReviewDecision.replanScene,
        wasLengthRetry: false,
        attempt: 1,
        softFailureCount: 0,
        sceneReplanCount: 0,
      );

      expect(decision.action, PipelineRunLoopAction.replanScene);
      expect(decision.nextSceneReplanCount, 1);
      expect(decision.statusMessage, 'review issue -> scene replan 1/1');
    });

    test('does not replan length retries or exhausted scene budgets', () {
      const policy = PipelineRunLoopPolicy(
        maxProseRetries: 2,
        maxSceneReplanRetries: 1,
      );

      expect(
        policy
            .decideAfterReview(
              action: SceneReviewDecision.replanScene,
              wasLengthRetry: true,
              attempt: 1,
              softFailureCount: 0,
              sceneReplanCount: 0,
            )
            .action,
        PipelineRunLoopAction.finish,
      );
      expect(
        policy
            .decideAfterReview(
              action: SceneReviewDecision.replanScene,
              wasLengthRetry: false,
              attempt: 1,
              softFailureCount: 0,
              sceneReplanCount: 1,
            )
            .action,
        PipelineRunLoopAction.finish,
      );
    });

    test('retries rewrite decisions until prose retry budget is exhausted', () {
      const policy = PipelineRunLoopPolicy(
        maxProseRetries: 2,
        maxSceneReplanRetries: 1,
      );

      final retry = policy.decideAfterReview(
        action: SceneReviewDecision.rewriteProse,
        wasLengthRetry: false,
        attempt: 1,
        softFailureCount: 0,
        sceneReplanCount: 0,
      );
      expect(retry.action, PipelineRunLoopAction.retryEditorial);
      expect(retry.nextAttempt, 2);
      expect(retry.nextSoftFailureCount, 1);
      expect(retry.statusMessage, 'review issue -> editorial retry');

      final exhausted = policy.decideAfterReview(
        action: SceneReviewDecision.rewriteProse,
        wasLengthRetry: false,
        attempt: 3,
        softFailureCount: 2,
        sceneReplanCount: 0,
      );
      expect(exhausted.action, PipelineRunLoopAction.finish);
      expect(exhausted.nextSoftFailureCount, 3);
      expect(exhausted.shouldPolishBeforeFinalization, isTrue);
    });

    test(
      'preserves length retry messaging and skips polish when exhausted',
      () {
        const policy = PipelineRunLoopPolicy(
          maxProseRetries: 1,
          maxSceneReplanRetries: 1,
        );

        final retry = policy.decideAfterReview(
          action: SceneReviewDecision.rewriteProse,
          wasLengthRetry: true,
          attempt: 1,
          softFailureCount: 0,
          sceneReplanCount: 0,
        );
        expect(retry.action, PipelineRunLoopAction.retryEditorial);
        expect(retry.statusMessage, 'prose length issue -> editorial retry');

        final exhausted = policy.decideAfterReview(
          action: SceneReviewDecision.rewriteProse,
          wasLengthRetry: true,
          attempt: 2,
          softFailureCount: 1,
          sceneReplanCount: 0,
        );

        expect(exhausted.action, PipelineRunLoopAction.finish);
        expect(exhausted.nextSoftFailureCount, 2);
        expect(exhausted.shouldPolishBeforeFinalization, isFalse);
        expect(exhausted.shouldNotifySpeculationReady, isFalse);
      },
    );

    test('passes with polish and speculation readiness', () {
      const policy = PipelineRunLoopPolicy(
        maxProseRetries: 2,
        maxSceneReplanRetries: 1,
      );

      final decision = policy.decideAfterReview(
        action: SceneReviewDecision.pass,
        wasLengthRetry: false,
        attempt: 1,
        softFailureCount: 0,
        sceneReplanCount: 0,
      );

      expect(decision.action, PipelineRunLoopAction.finish);
      expect(decision.shouldPolishBeforeFinalization, isTrue);
      expect(decision.shouldNotifySpeculationReady, isTrue);
    });
  });
}
