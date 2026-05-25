import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:novel_writer/app/di/app_providers.dart';
import 'package:novel_writer/app/di/service_registry.dart';
import 'package:novel_writer/app/events/app_event_bus.dart';
import 'package:novel_writer/app/logging/app_event_log.dart';
import 'package:novel_writer/app/navigation/app_navigator.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/app/state/app_workspace_storage.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';
import 'package:novel_writer/app/theme/app_theme.dart';
import 'package:novel_writer/features/projects/presentation/project_wizard_page.dart';

void main() {
  late ServiceRegistry registry;
  late AppWorkspaceStore workspaceStore;

  List<Override> registryOverrides() => appProviderOverridesForRegistry(registry);

  tearDown(() {
    registry.disposeAll();
  });

  group('ProjectWizardPage', () {
    setUp(() {
      registry = ServiceRegistry();
      final eventBus = AppEventBus();
      final eventLog = AppEventLog();
      workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
        eventBus: eventBus,
      );
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
      );

      registry
        ..registerSingleton<AppEventBus>(eventBus)
        ..registerSingleton<AppEventLog>(eventLog)
        ..registerSingleton<AppWorkspaceStore>(workspaceStore)
        ..registerSingleton<AppSettingsStore>(settingsStore);

      AppNavigator.register(
        AppRoutes.projectHome,
        (context, _) => const SizedBox.shrink(),
      );
    });

    testWidgets('create button is disabled when name is empty', (tester) async {
      tester.view.physicalSize = const Size(1280, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: registryOverrides(),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: ProjectWizardPage()),
          ),
        ),
      );
      await tester.pump();

      final createButton = find.byKey(ProjectWizardPage.createButtonKey);
      expect(createButton, findsOneWidget);

      final filledButton = tester.widget<FilledButton>(createButton);
      expect(filledButton.enabled, isFalse);
    });

    testWidgets('create button is enabled when name is entered', (tester) async {
      tester.view.physicalSize = const Size(1280, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: registryOverrides(),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: ProjectWizardPage()),
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(ProjectWizardPage.nameFieldKey),
        '测试作品',
      );
      await tester.pump();

      final createButton = find.byKey(ProjectWizardPage.createButtonKey);
      final filledButton = tester.widget<FilledButton>(createButton);
      expect(filledButton.enabled, isTrue);
    });

    testWidgets('cancel button closes the dialog', (tester) async {
      tester.view.physicalSize = const Size(1280, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: registryOverrides(),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: ProjectWizardPage()),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(ProjectWizardPage.cancelButtonKey));
      await tester.pumpAndSettle();

      expect(find.byType(ProjectWizardPage), findsNothing);
    });

    testWidgets('valid submission creates a project', (tester) async {
      tester.view.physicalSize = const Size(1280, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final initialProjectCount = workspaceStore.projects.length;

      await tester.pumpWidget(
        ProviderScope(
          overrides: registryOverrides(),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: ProjectWizardPage()),
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(ProjectWizardPage.nameFieldKey),
        '新作品测试',
      );
      await tester.pump();

      await tester.tap(find.byKey(ProjectWizardPage.createButtonKey));
      await tester.pumpAndSettle();

      expect(workspaceStore.projects.length, initialProjectCount + 1);
      expect(
        workspaceStore.projects.any((p) => p.title == '新作品测试'),
        isTrue,
      );
    });

    testWidgets('creates protagonist character seed when provided',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: registryOverrides(),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: ProjectWizardPage()),
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(ProjectWizardPage.nameFieldKey),
        '主角测试作品',
      );
      await tester.enterText(
        find.byKey(ProjectWizardPage.protagonistFieldKey),
        '李明',
      );
      await tester.pump();

      await tester.tap(find.byKey(ProjectWizardPage.createButtonKey));
      await tester.pumpAndSettle();

      final createdProject = workspaceStore.projects
          .firstWhere((p) => p.title == '主角测试作品');

      final ref = ProviderContainer(
        overrides: registryOverrides(),
      );
      addTearDown(ref.dispose);

      ref.read(appWorkspaceStoreProvider).openProject(createdProject.id);
      final characters = ref.read(appWorkspaceStoreProvider).characters;

      expect(
        characters.any((c) => c.name == '李明' && c.role == '主角'),
        isTrue,
      );
    });

    testWidgets('creates world node seed when provided', (tester) async {
      tester.view.physicalSize = const Size(1280, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: registryOverrides(),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: ProjectWizardPage()),
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(ProjectWizardPage.nameFieldKey),
        '世界观测试作品',
      );
      await tester.enterText(
        find.byKey(ProjectWizardPage.worldNodeFieldKey),
        '青云门',
      );
      await tester.pump();

      await tester.tap(find.byKey(ProjectWizardPage.createButtonKey));
      await tester.pumpAndSettle();

      final createdProject = workspaceStore.projects
          .firstWhere((p) => p.title == '世界观测试作品');

      final ref = ProviderContainer(
        overrides: registryOverrides(),
      );
      addTearDown(ref.dispose);

      ref.read(appWorkspaceStoreProvider).openProject(createdProject.id);
      final worldNodes = ref.read(appWorkspaceStoreProvider).worldNodes;

      expect(
        worldNodes.any((n) => n.title == '青云门' && n.type == '地点'),
        isTrue,
      );
    });

    testWidgets('all field keys are present for testing', (tester) async {
      tester.view.physicalSize = const Size(1280, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: registryOverrides(),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: ProjectWizardPage()),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(ProjectWizardPage.nameFieldKey), findsOneWidget);
      expect(find.byKey(ProjectWizardPage.genreFieldKey), findsOneWidget);
      expect(
        find.byKey(ProjectWizardPage.protagonistFieldKey),
        findsOneWidget,
      );
      expect(find.byKey(ProjectWizardPage.worldNodeFieldKey), findsOneWidget);
      expect(find.byKey(ProjectWizardPage.createButtonKey), findsOneWidget);
      expect(find.byKey(ProjectWizardPage.cancelButtonKey), findsOneWidget);
    });
  });
}
