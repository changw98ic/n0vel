import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/di/app_providers.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/app/state/app_workspace_storage.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';
import 'package:novel_writer/app/state/story_generation_run_store.dart';

import 'test_support/test_registry.dart';

void main() {
  test('mutable store notifiers ignore identical store replacements', () {
    final registry = createTestRegistry();
    addTearDown(registry.disposeAll);

    final workspaceStore = registry.resolve<AppWorkspaceStore>();
    final settingsStore = registry.resolve<AppSettingsStore>();
    final runStore = registry.resolve<StoryGenerationRunStore>();

    expect(
      AppWorkspaceStoreNotifier().updateShouldNotify(
        workspaceStore,
        workspaceStore,
      ),
      isFalse,
    );
    expect(
      AppSettingsStoreNotifier().updateShouldNotify(
        settingsStore,
        settingsStore,
      ),
      isFalse,
    );
    expect(
      StoryGenerationRunStoreNotifier().updateShouldNotify(runStore, runStore),
      isFalse,
    );
  });

  test('workspace store provider is backed by a Riverpod notifier', () async {
    final container = ProviderContainer(
      overrides: [
        appWorkspaceStorageProvider.overrideWithValue(
          InMemoryAppWorkspaceStorage(),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(appWorkspaceStoreProvider.notifier),
      isA<AppWorkspaceStoreNotifier>(),
    );

    var updateCount = 0;
    final subscription = container.listen<AppWorkspaceStore>(
      appWorkspaceStoreProvider,
      (_, _) => updateCount++,
    );
    addTearDown(subscription.close);

    final store = container.read(appWorkspaceStoreProvider);
    store.createProject(projectName: 'Riverpod Notifier');
    await Future<void>.delayed(Duration.zero);

    expect(updateCount, greaterThan(0));
  });
}
