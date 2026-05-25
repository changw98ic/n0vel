import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/di/app_providers.dart';
import 'package:novel_writer/app/state/app_workspace_storage.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';

void main() {
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
