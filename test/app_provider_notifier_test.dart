import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/di/app_providers.dart';
import 'package:novel_writer/app/di/service_registry.dart';
import 'package:novel_writer/app/state/app_workspace_storage.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';

void main() {
  test('workspace store provider is backed by a Riverpod notifier', () async {
    final registry = ServiceRegistry();
    final store = AppWorkspaceStore(storage: InMemoryAppWorkspaceStorage());
    registry.registerSingleton<AppWorkspaceStore>(store);
    final container = ProviderContainer(
      overrides: [serviceRegistryProvider.overrideWithValue(registry)],
    );
    addTearDown(() {
      container.dispose();
      registry.disposeAll();
    });

    expect(
      container.read(appWorkspaceStoreProvider.notifier),
      isA<AppWorkspaceStoreNotifier>(),
    );

    var updateCount = 0;
    final subscription = container.listen<AppWorkspaceStore>(
      appWorkspaceStoreProvider,
      (_, __) => updateCount++,
    );
    addTearDown(subscription.close);

    store.createProject(projectName: 'Riverpod Notifier');
    await Future<void>.delayed(Duration.zero);

    expect(updateCount, greaterThan(0));
  });
}
