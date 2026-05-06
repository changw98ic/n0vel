import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/app/state/app_workspace_storage.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';
import 'package:novel_writer/app/state/story_generation_run_storage.dart';
import 'package:novel_writer/app/state/story_generation_run_store.dart';
import 'package:novel_writer/app/state/story_generation_storage.dart';
import 'package:novel_writer/app/state/story_generation_store.dart';

void main() {
  group('StoryGenerationRunStore empty workspace', () {
    late AppSettingsStore settingsStore;
    late AppWorkspaceStore workspaceStore;
    late StoryGenerationStore generationStore;
    late StoryGenerationRunStore runStore;

    setUp(() {
      StoryGenerationRunStore.debugStorageOverride =
          InMemoryStoryGenerationRunStorage();
      settingsStore = AppSettingsStore(storage: InMemoryAppSettingsStorage());
      workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      generationStore = StoryGenerationStore(
        storage: InMemoryStoryGenerationStorage(),
        workspaceStore: workspaceStore,
      );
    });

    tearDown(() {
      runStore.dispose();
      generationStore.dispose();
      workspaceStore.dispose();
      settingsStore.dispose();
      StoryGenerationRunStore.debugStorageOverride = null;
    });

    test('can be constructed with default seeded workspace scene', () async {
      expect(workspaceStore.currentSceneOrNull, isNotNull);

      runStore = StoryGenerationRunStore(
        settingsStore: settingsStore,
        workspaceStore: workspaceStore,
        generationStore: generationStore,
      );

      expect(runStore.snapshot.status, StoryGenerationRunStatus.idle);
      expect(runStore.snapshot.sceneId, isNotEmpty);
      expect(runStore.snapshot.headline, isNotEmpty);
      await runStore.ready;
    });

    test('snapshot stays idle after ready completes on empty workspace', () async {
      runStore = StoryGenerationRunStore(
        settingsStore: settingsStore,
        workspaceStore: workspaceStore,
        generationStore: generationStore,
      );

      await runStore.ready;
      expect(runStore.snapshot.status, StoryGenerationRunStatus.idle);
    });

    test('handles workspace change from empty to populated gracefully', () async {
      runStore = StoryGenerationRunStore(
        settingsStore: settingsStore,
        workspaceStore: workspaceStore,
        generationStore: generationStore,
      );

      await runStore.ready;
      workspaceStore.createProject();
      await runStore.ready;

      expect(runStore.snapshot.status, StoryGenerationRunStatus.idle);
      expect(runStore.snapshot.sceneId, isNotEmpty);
    });
  });
}
