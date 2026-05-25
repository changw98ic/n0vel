import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/di/app_providers.dart';
import 'package:novel_writer/app/state/projection/run_projection.dart';
import 'package:novel_writer/app/state/story_generation_run_store.dart';
import 'package:novel_writer/features/story_generation/data/pipeline_definition.dart';

import 'test_support/test_registry.dart';

void main() {
  group('RunProjection.fromSnapshot', () {
    test('maps idle snapshots without recovery or candidate indicators', () {
      const snapshot = StoryGenerationRunSnapshot(
        status: StoryGenerationRunStatus.idle,
        sceneId: 'scene-1',
        sceneLabel: 'Project / Scene',
        headline: 'No run',
        summary: 'Idle',
        stageSummary: 'Not started',
      );

      final projection = RunProjection.fromSnapshot(
        sceneScopeId: 'project::scene-1',
        snapshot: snapshot,
      );

      expect(projection.sceneScopeId, 'project::scene-1');
      expect(projection.status, StoryGenerationRunStatus.idle);
      expect(projection.phase, StoryGenerationRunPhase.draft);
      expect(projection.hasRun, isFalse);
      expect(projection.isRunning, isFalse);
      expect(projection.shouldPromptForRecovery, isFalse);
      expect(projection.canRetry, isFalse);
      expect(projection.canDiscard, isFalse);
      expect(projection.hasCandidate, isFalse);
      expect(projection.candidateCount, 0);
      expect(projection.stages, isEmpty);
      expect(projection.failureSummary, isEmpty);
    });

    test('maps running snapshots with active stage and recovery prompt', () {
      const snapshot = StoryGenerationRunSnapshot(
        status: StoryGenerationRunStatus.running,
        phase: StoryGenerationRunPhase.draft,
        sceneId: 'scene-1',
        sceneLabel: 'Project / Scene',
        headline: 'Running',
        summary: 'Working',
        stageSummary: 'Planning',
        stageTimeline: [
          StoryGenerationRunStageSnapshot(
            stageId: PipelineStageId.contextEnrichment,
            label: 'Context',
            status: StoryGenerationRunStageStatus.completed,
          ),
          StoryGenerationRunStageSnapshot(
            stageId: PipelineStageId.scenePlanning,
            label: 'Planning',
            status: StoryGenerationRunStageStatus.running,
          ),
        ],
        messages: [
          StoryGenerationRunMessage(
            title: 'Running',
            body: 'Started',
            kind: StoryGenerationRunMessageKind.status,
          ),
        ],
      );

      final projection = RunProjection.fromSnapshot(
        sceneScopeId: 'project::scene-1',
        snapshot: snapshot,
      );

      expect(projection.hasRun, isTrue);
      expect(projection.isRunning, isTrue);
      expect(projection.shouldPromptForRecovery, isTrue);
      expect(projection.canRetry, isTrue);
      expect(projection.canDiscard, isTrue);
      expect(projection.messageCount, 1);
      expect(projection.stages.length, 2);
      expect(
        projection.activeStage?.stageId,
        PipelineStageId.scenePlanning.name,
      );
      expect(
        projection.activeStage?.status,
        StoryGenerationRunStageStatus.running,
      );
    });

    test('maps completed snapshots with candidate indicators', () {
      const snapshot = StoryGenerationRunSnapshot(
        status: StoryGenerationRunStatus.completed,
        phase: StoryGenerationRunPhase.feedback,
        sceneId: 'scene-1',
        sceneLabel: 'Project / Scene',
        headline: 'Done',
        summary: 'Candidate ready',
        stageSummary: 'Waiting for author',
        messages: [
          StoryGenerationRunMessage(
            title: 'Draft',
            body: 'Candidate prose',
            kind: StoryGenerationRunMessageKind.editorial,
          ),
          StoryGenerationRunMessage(
            title: 'Review',
            body: 'Pass',
            kind: StoryGenerationRunMessageKind.review,
          ),
        ],
      );

      final projection = RunProjection.fromSnapshot(
        sceneScopeId: 'project::scene-1',
        snapshot: snapshot,
      );

      expect(projection.hasRun, isTrue);
      expect(projection.isRunning, isFalse);
      expect(projection.shouldPromptForRecovery, isFalse);
      expect(projection.canRetry, isFalse);
      expect(projection.canDiscard, isTrue);
      expect(projection.hasCandidate, isTrue);
      expect(projection.candidateCount, 2);
    });

    test('maps failed snapshots with failure summaries and retry', () {
      const snapshot = StoryGenerationRunSnapshot(
        status: StoryGenerationRunStatus.failed,
        phase: StoryGenerationRunPhase.fail,
        sceneId: 'scene-1',
        sceneLabel: 'Project / Scene',
        headline: 'Failed',
        summary: 'Run failed',
        stageSummary: 'Failure',
        errorDetail: 'network timeout',
        stageTimeline: [
          StoryGenerationRunStageSnapshot(
            stageId: PipelineStageId.scenePlanning,
            label: 'Planning',
            status: StoryGenerationRunStageStatus.failed,
            failureCode: 'network',
            summary: 'timeout',
          ),
        ],
      );

      final projection = RunProjection.fromSnapshot(
        sceneScopeId: 'project::scene-1',
        snapshot: snapshot,
      );

      expect(projection.hasRun, isTrue);
      expect(projection.isRunning, isFalse);
      expect(projection.shouldPromptForRecovery, isFalse);
      expect(projection.canRetry, isTrue);
      expect(projection.canDiscard, isTrue);
      expect(
        projection.activeStage?.status,
        StoryGenerationRunStageStatus.failed,
      );
      expect(projection.failureSummary, 'network timeout');
    });
  });

  group('runProjectionProvider', () {
    test(
      'reads native run provider without registry and updates on changes',
      () async {
        final container = ProviderContainer(
          overrides: createTestProviderOverrides(),
        );
        addTearDown(container.dispose);

        Object? registryReadError;
        try {
          container.read(serviceRegistryProvider);
        } catch (error) {
          registryReadError = error;
        }
        expect(registryReadError, isNotNull);
        expect(
          registryReadError.toString(),
          contains('serviceRegistryProvider not overridden'),
        );

        final runStore = container.read(storyGenerationRunStoreProvider);
        await runStore.waitUntilReady();

        final initial = container.read(runProjectionProvider);
        expect(initial.sceneScopeId, runStore.activeSceneScopeId);
        expect(initial.status, StoryGenerationRunStatus.idle);

        final updates = <RunProjection>[];
        final subscription = container.listen<RunProjection>(
          runProjectionProvider,
          (_, next) => updates.add(next),
        );
        addTearDown(subscription.close);

        final transition = await runStore.transitionCurrentPhase(
          StoryGenerationRunPhase.candidate,
        );

        expect(transition.accepted, isTrue);
        expect(updates, isNotEmpty);
        expect(
          container.read(runProjectionProvider).phase,
          StoryGenerationRunPhase.candidate,
        );
      },
    );
  });
}
