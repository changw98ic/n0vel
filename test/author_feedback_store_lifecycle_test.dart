import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/state/app_workspace_storage.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';
import 'package:novel_writer/features/author_feedback/data/author_feedback_storage.dart';
import 'package:novel_writer/features/author_feedback/data/author_feedback_store.dart';
import 'package:novel_writer/features/author_feedback/domain/author_feedback_models.dart';

void main() {
  late AuthorFeedbackStore store;
  late InMemoryAuthorFeedbackStorage storage;
  late AppWorkspaceStore workspaceStore;

  setUp(() async {
    storage = InMemoryAuthorFeedbackStorage();
    workspaceStore = AppWorkspaceStore(storage: InMemoryAppWorkspaceStorage());
    var tick = DateTime.utc(2026, 4, 1, 12);
    store = AuthorFeedbackStore(
      storage: storage,
      workspaceStore: workspaceStore,
      clock: () {
        final value = tick;
        tick = tick.add(const Duration(minutes: 1));
        return value;
      },
    );
    await store.waitUntilReady();
  });

  tearDown(() {
    store.dispose();
    workspaceStore.dispose();
  });

  // =========================================================================
  // Status transitions
  // =========================================================================

  group('status transitions', () {
    test('accept transitions item to accepted with decision', () {
      final item = _createItem(store);

      store.accept(item.id, note: 'Good revision');

      expect(store.items.first.status, AuthorFeedbackStatus.accepted);
      expect(store.items.first.decisions.first.note, 'Good revision');
      expect(
        store.items.first.decisions.first.status,
        AuthorFeedbackStatus.accepted,
      );
      expect(
        store.items.first.decisions.length,
        greaterThan(item.decisions.length),
      );
    });

    test('reject transitions item to rejected', () {
      final item = _createItem(store);

      store.reject(item.id, note: 'Not useful');

      expect(store.items.first.status, AuthorFeedbackStatus.rejected);
      expect(store.items.first.decisions.first.note, 'Not useful');
    });

    test('resolve transitions item to resolved', () {
      final item = _createItem(store);

      store.resolve(item.id, note: 'Fixed in latest run');

      expect(store.items.first.status, AuthorFeedbackStatus.resolved);
      expect(store.items.first.decisions.first.note, 'Fixed in latest run');
    });

    test('updateStatus adds decision history entry', () {
      final item = _createItem(store);
      final initialDecisionCount = item.decisions.length;

      store.requestRevision(item.id);
      store.accept(item.id);

      expect(store.items.first.decisions.length, initialDecisionCount + 2);
    });

    test('updateStatus for non-existent id is a no-op', () {
      final item = _createItem(store);

      store.updateStatus('nonexistent-id', AuthorFeedbackStatus.accepted);

      expect(store.items, hasLength(1));
      expect(store.items.first.id, item.id);
      expect(store.items.first.status, AuthorFeedbackStatus.open);
    });
  });

  // =========================================================================
  // remove
  // =========================================================================

  group('remove', () {
    test('removes an existing item by id', () {
      final item1 = _createItem(store, note: 'First');
      final item2 = _createItem(store, note: 'Second');

      store.remove(item1.id);

      expect(store.items, hasLength(1));
      expect(store.items.single.id, item2.id);
    });

    test('is a no-op for non-existent id', () {
      _createItem(store);

      store.remove('nonexistent-id');

      expect(store.items, hasLength(1));
    });
  });

  // =========================================================================
  // itemsForScene and activeCountForScene
  // =========================================================================

  group('scene filtering', () {
    test('itemsForScene returns only items matching scene id', () {
      final scene = workspaceStore.currentScene;
      _createItem(store, sceneId: scene.id, note: 'Matching');
      _createItem(store, sceneId: 'other-scene', note: 'Not matching');

      final result = store.itemsForScene(scene.id);

      expect(result, hasLength(1));
      expect(result.single.note, 'Matching');
    });

    test('activeCountForScene counts only active items', () {
      final scene = workspaceStore.currentScene;
      final item1 = _createItem(store, sceneId: scene.id, note: 'Active');
      _createItem(store, sceneId: scene.id, note: 'Also active');

      expect(store.activeCountForScene(scene.id), 2);

      store.reject(item1.id);

      expect(store.activeCountForScene(scene.id), 1);
    });

    test('activeCountForScene is zero when no items for scene', () {
      expect(store.activeCountForScene('nonexistent-scene'), 0);
    });
  });

  // =========================================================================
  // activeRevisionRequestsForScene
  // =========================================================================

  group('activeRevisionRequestsForScene', () {
    test('returns only revision-requested items for the specified scene', () {
      final scene = workspaceStore.currentScene;
      final item1 = _createItem(
        store,
        sceneId: scene.id,
        chapterId: scene.chapterLabel,
        note: 'Rev',
      );
      _createItem(
        store,
        sceneId: scene.id,
        chapterId: scene.chapterLabel,
        note: 'Open',
      );

      store.requestRevision(item1.id);

      final result = store.activeRevisionRequestsForScene(
        chapterId: scene.chapterLabel,
        sceneId: scene.id,
      );

      expect(result, hasLength(1));
      expect(result.single.status, AuthorFeedbackStatus.revisionRequested);
      expect(result.single.note, 'Rev');
    });

    test('excludes items from other scenes', () {
      final scene = workspaceStore.currentScene;
      final item = _createItem(
        store,
        sceneId: 'other-scene',
        chapterId: 'other',
        note: 'Other',
      );
      store.requestRevision(item.id);

      final result = store.activeRevisionRequestsForScene(
        chapterId: scene.chapterLabel,
        sceneId: scene.id,
      );

      expect(result, isEmpty);
    });
  });

  // =========================================================================
  // markRevisionRequestsInProgress
  // =========================================================================

  group('markRevisionRequestsInProgress', () {
    test('transitions revision-requested items to in-progress', () {
      final scene = workspaceStore.currentScene;
      final item = _createItem(
        store,
        sceneId: scene.id,
        chapterId: scene.chapterLabel,
        note: 'Needs revision',
      );
      store.requestRevision(item.id);

      store.markRevisionRequestsInProgress(
        store.activeRevisionRequestsForScene(
          chapterId: scene.chapterLabel,
          sceneId: scene.id,
        ),
        sourceRunId: 'run-2',
      );

      final updated = store.items.first;
      expect(updated.status, AuthorFeedbackStatus.inProgress);
      expect(updated.decisions.first.status, AuthorFeedbackStatus.inProgress);
      expect(updated.decisions.first.sourceRunId, 'run-2');
    });

    test('is a no-op for empty list', () {
      _createItem(store);

      store.markRevisionRequestsInProgress([], sourceRunId: 'run-x');

      expect(store.items.first.status, AuthorFeedbackStatus.open);
    });

    test('skips items that are not revision-requested', () {
      final item1 = _createItem(store, note: 'Still open');
      final item2 = _createItem(store, note: 'Revision');
      store.requestRevision(item2.id);

      // Fetch updated items from the store so item2 reflects revisionRequested status.
      final updatedItem2 = store.items.firstWhere((i) => i.id == item2.id);

      store.markRevisionRequestsInProgress([item1, updatedItem2]);

      final results = {for (final i in store.items) i.note: i.status};
      expect(results['Still open'], AuthorFeedbackStatus.open);
      expect(results['Revision'], AuthorFeedbackStatus.inProgress);
    });
  });

  // =========================================================================
  // exportJson / importJson round-trip
  // =========================================================================

  group('export/import round-trip', () {
    test('exportJson and importJson preserve all items and statuses', () {
      final item1 = _createItem(store, note: 'First');
      final item2 = _createItem(store, note: 'Second');
      store.requestRevision(item1.id);
      store.accept(item2.id);

      final exported = store.exportJson();

      final restored = AuthorFeedbackStore(
        storage: InMemoryAuthorFeedbackStorage(),
        workspaceStore: workspaceStore,
      );
      addTearDown(restored.dispose);
      restored.importJson(exported);

      expect(restored.items, hasLength(2));
      final restoredRevision = restored.items.firstWhere(
        (i) => i.note == 'First',
      );
      final restoredAccepted = restored.items.firstWhere(
        (i) => i.note == 'Second',
      );
      expect(restoredRevision.status, AuthorFeedbackStatus.revisionRequested);
      expect(restoredAccepted.status, AuthorFeedbackStatus.accepted);
    });

    test('importJson ignores data without items list', () {
      _createItem(store);

      store.importJson({'tasks': []});

      expect(store.items, hasLength(1));
    });

    test(
      'storage-based round-trip preserves items across store instances',
      () async {
        final sharedStorage = InMemoryAuthorFeedbackStorage();
        var tick = DateTime.utc(2026, 5, 1);
        DateTime clock() {
          final value = tick;
          tick = tick.add(const Duration(minutes: 1));
          return value;
        }

        final source = AuthorFeedbackStore(
          storage: sharedStorage,
          workspaceStore: workspaceStore,
          clock: clock,
        );
        addTearDown(source.dispose);
        await source.waitUntilReady();

        final item = source.createFeedback(
          chapterId: 'ch-1',
          sceneId: 'sc-1',
          sceneLabel: 'Scene 1',
          note: 'Persisted feedback',
          priority: AuthorFeedbackPriority.high,
        );
        source.resolve(item.id, note: 'Resolved via storage');

        final target = AuthorFeedbackStore(
          storage: sharedStorage,
          workspaceStore: workspaceStore,
        );
        addTearDown(target.dispose);
        await target.waitUntilReady();

        expect(target.items, hasLength(1));
        expect(target.items.single.note, 'Persisted feedback');
        expect(target.items.single.status, AuthorFeedbackStatus.resolved);
        expect(target.items.single.priority, AuthorFeedbackPriority.high);
      },
    );
  });

  // =========================================================================
  // createFeedback validation
  // =========================================================================

  group('createFeedback validation', () {
    test('rejects empty note', () {
      expect(
        () => store.createFeedback(
          chapterId: 'ch-1',
          sceneId: 'sc-1',
          sceneLabel: 'Label',
          note: '   ',
        ),
        throwsArgumentError,
      );
    });

    test('trims whitespace from note', () {
      final item = store.createFeedback(
        chapterId: 'ch-1',
        sceneId: 'sc-1',
        sceneLabel: 'Label',
        note: '  trimmed note  ',
      );

      expect(item.note, 'trimmed note');
    });
  });
}

AuthorFeedbackItem _createItem(
  AuthorFeedbackStore store, {
  String note = 'Test feedback',
  String? sceneId,
  String? chapterId,
}) {
  return store.createFeedback(
    chapterId: chapterId ?? 'ch-1',
    sceneId: sceneId ?? 'sc-1',
    sceneLabel: 'Scene',
    note: note,
  );
}
