import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/app_workspace_storage.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';
import 'package:novel_writer/features/author_feedback/data/author_feedback_storage.dart';
import 'package:novel_writer/features/author_feedback/data/author_feedback_store.dart';
import 'package:novel_writer/features/author_feedback/domain/author_feedback_models.dart';

void main() {
  test('stores feedback items with revision decisions per project', () async {
    final storage = InMemoryAuthorFeedbackStorage();
    final workspaceStore = AppWorkspaceStore(
      storage: InMemoryAppWorkspaceStorage(),
    );
    addTearDown(workspaceStore.dispose);

    var tick = DateTime.utc(2026, 1, 1, 12);
    final store = AuthorFeedbackStore(
      storage: storage,
      workspaceStore: workspaceStore,
      clock: () {
        final value = tick;
        tick = tick.add(const Duration(minutes: 1));
        return value;
      },
    );
    addTearDown(store.dispose);
    await store.waitUntilReady();

    final scene = workspaceStore.currentScene;
    final item = store.createFeedback(
      chapterId: scene.chapterLabel,
      sceneId: scene.id,
      sceneLabel: scene.displayLocation,
      note: 'Add a stronger emotional beat before the reveal.',
      priority: AuthorFeedbackPriority.high,
      sourceRunId: 'run-1',
      sourceRunLabel: 'Run completed',
    );
    store.requestRevision(item.id, note: 'Ask the model for a tighter pass.');

    expect(store.items, hasLength(1));
    expect(store.items.single.status, AuthorFeedbackStatus.revisionRequested);
    expect(store.items.single.priority, AuthorFeedbackPriority.high);
    expect(store.items.single.decisions, hasLength(2));
    expect(store.activeCountForScene(scene.id), 1);

    final restored = AuthorFeedbackStore(
      storage: storage,
      workspaceStore: workspaceStore,
    );
    addTearDown(restored.dispose);
    await restored.waitUntilReady();

    expect(restored.items.single.note, contains('emotional beat'));
    expect(restored.items.single.sourceRunId, 'run-1');
    expect(
      restored.items.single.status,
      AuthorFeedbackStatus.revisionRequested,
    );
  });
}
