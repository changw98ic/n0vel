import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/di/app_providers.dart';
import 'package:novel_writer/app/state/projection/run_commands.dart';
import 'package:novel_writer/app/state/story_generation_run_store.dart';
import 'package:novel_writer/features/story_generation/data/pipeline_definition.dart';

import 'test_support/test_registry.dart' show createTestProviderOverrides;

void main() {
  group('runCommandsProvider', () {
    test('resolves without serviceRegistryProvider using native providers', () {
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

      final commands = container.read(runCommandsProvider);
      expect(commands, isA<StoryGenerationRunCommands>());
    });

    test(
      'cancelCurrentRun uses the native run store without registry',
      () async {
        final container = ProviderContainer(
          overrides: createTestProviderOverrides(),
        );
        addTearDown(container.dispose);

        final runStore = container.read(storyGenerationRunStoreProvider);
        await runStore.waitUntilReady();

        final commands = container.read(runCommandsProvider);

        expect(await commands.cancelCurrentRun(), isFalse);
      },
    );

    test(
      'discardRecoveredRun clears active scene scope while preserving other scopes',
      () async {
        final container = ProviderContainer(
          overrides: createTestProviderOverrides(),
        );
        addTearDown(container.dispose);

        final workspaceStore = container.read(appWorkspaceStoreProvider);
        var runStore = container.read(storyGenerationRunStoreProvider);
        await runStore.waitUntilReady();

        final preservedScopeId = runStore.activeSceneScopeId;
        workspaceStore.updateCurrentScene(
          sceneId: 'test-other-scene',
          recentLocation: '第 1 章 / Other Scene',
        );
        await Future<void>.delayed(Duration.zero);
        runStore = container.read(storyGenerationRunStoreProvider);
        await runStore.waitUntilReady();

        final activeScopeId = runStore.activeSceneScopeId;
        expect(activeScopeId, isNot(preservedScopeId));

        await runStore.importProjectJson({
          'projectId': workspaceStore.currentProjectId,
          'sceneRunsByScope': {
            preservedScopeId: _createTestSnapshot(
              sceneId: _sceneIdFromScope(preservedScopeId),
              sceneLabel: 'Preserved Scene',
            ).toJson(),
            activeScopeId: _createTestSnapshot(
              sceneId: _sceneIdFromScope(activeScopeId),
              sceneLabel: 'Active Scene',
            ).toJson(),
          },
        });
        await runStore.waitUntilReady();

        final commands = container.read(runCommandsProvider);
        await commands.discardRecoveredRun();
        await runStore.waitUntilReady();

        final exportedAfterDiscard = await runStore.exportProjectJson();
        final sceneRunsAfter =
            (exportedAfterDiscard['sceneRunsByScope'] as Map?) ?? {};
        expect(sceneRunsAfter.containsKey(activeScopeId), isFalse);
        expect(sceneRunsAfter.containsKey(preservedScopeId), isTrue);
      },
    );
  });

  group('StoryGenerationRunCommands', () {
    test('delegates run, retry, and cancel to the target', () async {
      final target = _FakeRunCommandTarget(cancelResult: true);
      final commands = StoryGenerationRunCommands(target);

      await commands.runCurrentScene();
      await commands.retryRecoveredRun();

      expect(await commands.cancelCurrentRun(), isTrue);
      expect(target.runCurrentSceneCallCount, 2);
      expect(target.cancelCurrentRunCallCount, 1);
      expect(target.exportProjectJsonCallCount, 0);
      expect(target.importProjectJsonCallCount, 0);
    });

    test('discardRecoveredRun filters only the active scene scope', () async {
      final target = _FakeRunCommandTarget(
        activeSceneScopeId: 'project::active',
        exported: {
          'projectId': 'project',
          'sceneRunsByScope': {
            'project::active': {'status': 'completed'},
            'project::other': {'status': 'failed'},
            7: {'status': 'cancelled'},
          },
        },
      );
      final commands = StoryGenerationRunCommands(target);

      await commands.discardRecoveredRun();

      expect(target.exportProjectJsonCallCount, 1);
      expect(target.importProjectJsonCallCount, 1);
      expect(
        target.importedProjectJson,
        equals({
          'projectId': 'project',
          'sceneRunsByScope': {
            'project::other': {'status': 'failed'},
            '7': {'status': 'cancelled'},
          },
        }),
      );
    });

    test(
      'discardRecoveredRun imports an empty map when no runs are exported',
      () async {
        final target = _FakeRunCommandTarget(
          exported: {'projectId': 'project'},
        );
        final commands = StoryGenerationRunCommands(target);

        await commands.discardRecoveredRun();

        expect(
          target.importedProjectJson,
          equals({'projectId': 'project', 'sceneRunsByScope': {}}),
        );
      },
    );
  });
}

String _sceneIdFromScope(String sceneScopeId) {
  final parts = sceneScopeId.split('::');
  return parts.isEmpty ? sceneScopeId : parts.last;
}

StoryGenerationRunSnapshot _createTestSnapshot({
  required String sceneId,
  required String sceneLabel,
}) {
  return StoryGenerationRunSnapshot(
    status: StoryGenerationRunStatus.completed,
    phase: StoryGenerationRunPhase.candidate,
    sceneId: sceneId,
    sceneLabel: sceneLabel,
    headline: 'Test Run',
    summary: 'Test summary',
    stageSummary: 'Test stage',
    stageTimeline: const [
      StoryGenerationRunStageSnapshot(
        stageId: PipelineStageId.scenePlanning,
        label: 'Planning',
        status: StoryGenerationRunStageStatus.completed,
        attempt: 1,
      ),
    ],
    messages: const [
      StoryGenerationRunMessage(
        title: 'Test',
        body: 'Test message',
        kind: StoryGenerationRunMessageKind.status,
      ),
    ],
    participants: const [],
  );
}

class _FakeRunCommandTarget implements RunCommandTarget {
  _FakeRunCommandTarget({
    this.activeSceneScopeId = 'project::active',
    this.cancelResult = false,
    Map<String, Object?>? exported,
  }) : exportedProjectJson =
           exported ??
           {'projectId': 'project', 'sceneRunsByScope': <String, Object?>{}};

  @override
  String activeSceneScopeId;

  bool cancelResult;
  Map<String, Object?> exportedProjectJson;
  Map<String, Object?>? importedProjectJson;
  int runCurrentSceneCallCount = 0;
  int exportProjectJsonCallCount = 0;
  int importProjectJsonCallCount = 0;
  int cancelCurrentRunCallCount = 0;

  @override
  Future<void> runCurrentScene() async {
    runCurrentSceneCallCount += 1;
  }

  @override
  Future<Map<String, Object?>> exportProjectJson() async {
    exportProjectJsonCallCount += 1;
    return exportedProjectJson;
  }

  @override
  Future<void> importProjectJson(Map<String, Object?> data) async {
    importProjectJsonCallCount += 1;
    importedProjectJson = data;
  }

  @override
  Future<bool> cancelCurrentRun() async {
    cancelCurrentRunCallCount += 1;
    return cancelResult;
  }
}
