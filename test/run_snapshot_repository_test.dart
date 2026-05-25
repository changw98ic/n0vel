import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/story_generation_run_storage.dart';
import 'package:novel_writer/app/state/story_generation_run_store.dart';

void main() {
  group('StoryGenerationRunSnapshotRepository', () {
    test('save then restore snapshot by scene scope', () async {
      final storage = InMemoryStoryGenerationRunStorage();
      final repository = StoryGenerationRunSnapshotRepository(storage);

      const sceneScopeId = 'project-1::scene-1';
      const snapshot = StoryGenerationRunSnapshot(
        status: StoryGenerationRunStatus.completed,
        phase: StoryGenerationRunPhase.feedback,
        sceneId: 'scene-1',
        sceneLabel: 'Project / Scene 1',
        headline: 'headline',
        summary: 'summary',
        stageSummary: 'stage',
      );

      await repository.persist(snapshot, sceneScopeId);
      final restored = await repository.restore(sceneScopeId);

      expect(restored, isNotNull);
      expect(restored!.status, StoryGenerationRunStatus.completed);
      expect(restored.phase, StoryGenerationRunPhase.feedback);
      expect(restored.sceneId, 'scene-1');
      expect(restored.headline, 'headline');

      // Verify the snapshot was also cached
      final cached = repository.getCached(sceneScopeId);
      expect(cached, isNotNull);
      expect(cached!.sceneId, 'scene-1');
    });

    test(
      'exported project JSON includes only cached snapshots with hasRun',
      () async {
        final storage = InMemoryStoryGenerationRunStorage();
        final repository = StoryGenerationRunSnapshotRepository(storage);

        const sceneScopeId1 = 'project-1::scene-1';
        const snapshotWithRun = StoryGenerationRunSnapshot(
          status: StoryGenerationRunStatus.completed,
          sceneId: 'scene-1',
          sceneLabel: 'Scene 1',
          headline: 'completed',
          summary: 'summary',
          stageSummary: 'stage',
        );

        const sceneScopeId2 = 'project-1::scene-2';
        const snapshotWithoutRun = StoryGenerationRunSnapshot(
          status: StoryGenerationRunStatus.idle,
          sceneId: 'scene-2',
          sceneLabel: 'Scene 2',
          headline: 'idle',
          summary: 'summary',
          stageSummary: 'stage',
        );

        await repository.persist(snapshotWithRun, sceneScopeId1);
        await repository.persist(snapshotWithoutRun, sceneScopeId2);

        final exported = repository.exportProjectSnapshots([
          sceneScopeId1,
          sceneScopeId2,
        ]);

        expect(exported.length, 1);
        expect(exported.containsKey(sceneScopeId1), isTrue);
        expect(exported.containsKey(sceneScopeId2), isFalse);
        expect(
          (exported[sceneScopeId1] as Map<String, Object?>?)?['status'],
          StoryGenerationRunStatus.completed.name,
        );
      },
    );

    test(
      'exported stored snapshots includes only snapshots with hasRun',
      () async {
        final storage = InMemoryStoryGenerationRunStorage();
        final repository = StoryGenerationRunSnapshotRepository(storage);

        const sceneScopeId1 = 'project-1::scene-1';
        const sceneScopeId2 = 'project-1::scene-2';

        // Persist a completed snapshot to storage (simulating a previous session)
        await storage.save({
          'status': StoryGenerationRunStatus.completed.name,
          'phase': StoryGenerationRunPhase.feedback.name,
          'sceneId': 'scene-1',
          'sceneLabel': 'Scene 1',
          'headline': 'completed',
          'summary': 'summary',
          'stageSummary': 'stage',
          'turnLabel': '',
          'errorDetail': '',
          'participants': <Object?>[],
          'messages': <Object?>[],
          'stageTimeline': <Object?>[],
        }, sceneScopeId: sceneScopeId1);

        // Persist an idle snapshot to storage
        await storage.save({
          'status': StoryGenerationRunStatus.idle.name,
          'phase': StoryGenerationRunPhase.draft.name,
          'sceneId': 'scene-2',
          'sceneLabel': 'Scene 2',
          'headline': 'idle',
          'summary': 'summary',
          'stageSummary': 'stage',
          'turnLabel': '',
          'errorDetail': '',
          'participants': <Object?>[],
          'messages': <Object?>[],
          'stageTimeline': <Object?>[],
        }, sceneScopeId: sceneScopeId2);

        final exported = await repository.exportStoredSnapshots([
          sceneScopeId1,
          sceneScopeId2,
        ]);

        expect(exported.length, 1);
        expect(exported.containsKey(sceneScopeId1), isTrue);
        expect(exported.containsKey(sceneScopeId2), isFalse);
        expect(
          (exported[sceneScopeId1] as Map<String, Object?>?)?['status'],
          StoryGenerationRunStatus.completed.name,
        );
      },
    );

    test(
      'import clears known scene scopes and preserves imported non-known scope entries',
      () async {
        final storage = InMemoryStoryGenerationRunStorage();
        final repository = StoryGenerationRunSnapshotRepository(storage);

        const knownScopeId1 = 'project-1::scene-1';
        const knownScopeId2 = 'project-1::scene-2';
        const unknownScopeId = 'project-2::scene-3';

        // Pre-populate cache with a known scope
        await repository.persist(
          const StoryGenerationRunSnapshot(
            status: StoryGenerationRunStatus.completed,
            sceneId: 'scene-1',
            sceneLabel: 'Scene 1',
            headline: 'to be cleared',
            summary: 'summary',
            stageSummary: 'stage',
          ),
          knownScopeId1,
        );

        // Import data that includes known and unknown scopes
        await repository.importProjectSnapshots(
          {
            knownScopeId1: {
              'status': StoryGenerationRunStatus.completed.name,
              'phase': StoryGenerationRunPhase.feedback.name,
              'sceneId': 'scene-1',
              'sceneLabel': 'Scene 1',
              'headline': 'imported known',
              'summary': 'summary',
              'stageSummary': 'stage',
              'turnLabel': '',
              'errorDetail': '',
              'participants': <Object?>[],
              'messages': <Object?>[],
              'stageTimeline': <Object?>[],
            },
            unknownScopeId: {
              'status': StoryGenerationRunStatus.completed.name,
              'phase': StoryGenerationRunPhase.feedback.name,
              'sceneId': 'scene-3',
              'sceneLabel': 'Scene 3',
              'headline': 'imported unknown',
              'summary': 'summary',
              'stageSummary': 'stage',
              'turnLabel': '',
              'errorDetail': '',
              'participants': <Object?>[],
              'messages': <Object?>[],
              'stageTimeline': <Object?>[],
            },
          },
          [knownScopeId1, knownScopeId2],
        );

        // Known scope should be updated with imported data
        final knownRestored = await repository.restore(knownScopeId1);
        expect(knownRestored, isNotNull);
        expect(knownRestored!.headline, 'imported known');

        // Unknown scope should be preserved
        final unknownRestored = await repository.restore(unknownScopeId);
        expect(unknownRestored, isNotNull);
        expect(unknownRestored!.headline, 'imported unknown');

        // Storage should also have the unknown scope
        final unknownStored = await storage.load(sceneScopeId: unknownScopeId);
        expect(unknownStored, isNotNull);
      },
    );

    test(
      'returned/exported JSON cannot be mutated to affect repository cache',
      () async {
        final storage = InMemoryStoryGenerationRunStorage();
        final repository = StoryGenerationRunSnapshotRepository(storage);

        const sceneScopeId = 'project-1::scene-1';
        const originalSnapshot = StoryGenerationRunSnapshot(
          status: StoryGenerationRunStatus.completed,
          phase: StoryGenerationRunPhase.feedback,
          sceneId: 'scene-1',
          sceneLabel: 'Scene 1',
          headline: 'original headline',
          summary: 'summary',
          stageSummary: 'stage',
        );

        await repository.persist(originalSnapshot, sceneScopeId);

        // Export and try to mutate the returned map
        final exported = repository.exportProjectSnapshots([sceneScopeId]);
        expect(
          (exported[sceneScopeId] as Map<String, Object?>?)?['headline'],
          'original headline',
        );

        // Try to mutate the exported map
        if (exported[sceneScopeId] is Map) {
          (exported[sceneScopeId] as Map)['headline'] = 'mutated headline';
        }

        // The repository cache should be unchanged
        final cached = repository.getCached(sceneScopeId);
        expect(cached, isNotNull);
        expect(cached!.headline, 'original headline');

        // Also test that exported snapshots from storage cannot be mutated
        final exportedStored = await repository.exportStoredSnapshots([
          sceneScopeId,
        ]);
        expect(
          (exportedStored[sceneScopeId] as Map<String, Object?>?)?['headline'],
          'original headline',
        );

        if (exportedStored[sceneScopeId] is Map) {
          (exportedStored[sceneScopeId] as Map)['headline'] =
              'mutated headline 2';
        }

        final restored = await repository.restore(sceneScopeId);
        expect(restored, isNotNull);
        expect(restored!.headline, 'original headline');
      },
    );

    test('clearCached removes snapshot from cache', () async {
      final storage = InMemoryStoryGenerationRunStorage();
      final repository = StoryGenerationRunSnapshotRepository(storage);

      const sceneScopeId = 'project-1::scene-1';
      const snapshot = StoryGenerationRunSnapshot(
        status: StoryGenerationRunStatus.completed,
        sceneId: 'scene-1',
        sceneLabel: 'Scene 1',
        headline: 'headline',
        summary: 'summary',
        stageSummary: 'stage',
      );

      await repository.persist(snapshot, sceneScopeId);
      expect(repository.getCached(sceneScopeId), isNotNull);

      repository.clearCached(sceneScopeId);
      expect(repository.getCached(sceneScopeId), isNull);

      // Storage should still have the snapshot
      final stored = await storage.load(sceneScopeId: sceneScopeId);
      expect(stored, isNotNull);
    });

    test(
      'clearCachedByProject removes matching snapshots from cache',
      () async {
        final storage = InMemoryStoryGenerationRunStorage();
        final repository = StoryGenerationRunSnapshotRepository(storage);

        const projectId = 'project-1';
        const sceneScopeId1 = 'project-1::scene-1';
        const sceneScopeId2 = 'project-1::scene-2';
        const otherProjectScopeId = 'project-2::scene-1';

        await repository.persist(
          const StoryGenerationRunSnapshot(
            status: StoryGenerationRunStatus.completed,
            sceneId: 'scene-1',
            sceneLabel: 'Scene 1',
            headline: 'headline',
            summary: 'summary',
            stageSummary: 'stage',
          ),
          sceneScopeId1,
        );
        await repository.persist(
          const StoryGenerationRunSnapshot(
            status: StoryGenerationRunStatus.completed,
            sceneId: 'scene-2',
            sceneLabel: 'Scene 2',
            headline: 'headline',
            summary: 'summary',
            stageSummary: 'stage',
          ),
          sceneScopeId2,
        );
        await repository.persist(
          const StoryGenerationRunSnapshot(
            status: StoryGenerationRunStatus.completed,
            sceneId: 'scene-1',
            sceneLabel: 'Scene 1',
            headline: 'headline',
            summary: 'summary',
            stageSummary: 'stage',
          ),
          otherProjectScopeId,
        );

        repository.clearCachedProject(projectId);

        expect(repository.getCached(sceneScopeId1), isNull);
        expect(repository.getCached(sceneScopeId2), isNull);
        expect(repository.getCached(otherProjectScopeId), isNotNull);
      },
    );

    test('clearAllCached removes all snapshots from cache', () async {
      final storage = InMemoryStoryGenerationRunStorage();
      final repository = StoryGenerationRunSnapshotRepository(storage);

      const sceneScopeId1 = 'project-1::scene-1';
      const sceneScopeId2 = 'project-1::scene-2';

      await repository.persist(
        const StoryGenerationRunSnapshot(
          status: StoryGenerationRunStatus.completed,
          sceneId: 'scene-1',
          sceneLabel: 'Scene 1',
          headline: 'headline',
          summary: 'summary',
          stageSummary: 'stage',
        ),
        sceneScopeId1,
      );
      await repository.persist(
        const StoryGenerationRunSnapshot(
          status: StoryGenerationRunStatus.completed,
          sceneId: 'scene-2',
          sceneLabel: 'Scene 2',
          headline: 'headline',
          summary: 'summary',
          stageSummary: 'stage',
        ),
        sceneScopeId2,
      );

      repository.clearAllCached();

      expect(repository.getCached(sceneScopeId1), isNull);
      expect(repository.getCached(sceneScopeId2), isNull);
    });

    test('restore returns null when no snapshot exists', () async {
      final storage = InMemoryStoryGenerationRunStorage();
      final repository = StoryGenerationRunSnapshotRepository(storage);

      const sceneScopeId = 'project-1::scene-1';

      final restored = await repository.restore(sceneScopeId);
      expect(restored, isNull);
    });

    test(
      'persisted snapshot includes sceneScopeId in storage payload',
      () async {
        final storage = InMemoryStoryGenerationRunStorage();
        final repository = StoryGenerationRunSnapshotRepository(storage);

        const sceneScopeId = 'project-1::scene-1';
        const snapshot = StoryGenerationRunSnapshot(
          status: StoryGenerationRunStatus.completed,
          sceneId: 'scene-1',
          sceneLabel: 'Scene 1',
          headline: 'headline',
          summary: 'summary',
          stageSummary: 'stage',
        );

        await repository.persist(snapshot, sceneScopeId);

        final stored = await storage.load(sceneScopeId: sceneScopeId);
        expect(stored, isNotNull);
        expect(stored!['sceneScopeId'], sceneScopeId);
      },
    );
  });
}
