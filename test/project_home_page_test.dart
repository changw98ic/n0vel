import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:novel_writer/app/di/app_providers.dart';
import 'package:novel_writer/app/di/service_registry.dart';
import 'package:novel_writer/app/events/app_event_bus.dart';
import 'package:novel_writer/app/logging/app_event_log.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/app/state/app_workspace_storage.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';
import 'package:novel_writer/app/theme/app_theme.dart';
import 'package:novel_writer/app/navigation/app_navigator.dart';
import 'package:novel_writer/features/projects/presentation/project_home_page.dart';

void main() {
  late ServiceRegistry registry;
  late AppWorkspaceStore workspaceStore;

  List<Override> registryOverrides() =>
      appProviderOverridesForRegistry(registry);

  tearDown(() {
    registry.disposeAll();
  });

  group('ProjectHomePage', () {
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

      // Register routes
      AppNavigator.register(
        AppRoutes.projectHome,
        (context, _) => const ProjectHomePage(),
      );
      AppNavigator.register(
        AppRoutes.shelf,
        (context, _) => const SizedBox.shrink(),
      );
      AppNavigator.register(
        AppRoutes.workbench,
        (context, _) => const SizedBox.shrink(),
      );
      AppNavigator.register(
        AppRoutes.bible,
        (context, _) => const SizedBox.shrink(),
      );
      AppNavigator.register(
        AppRoutes.productionBoard,
        (context, _) => const SizedBox.shrink(),
      );
    });

    testWidgets('renders project title when project is open', (tester) async {
      tester.view.physicalSize = const Size(1280, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      workspaceStore.createProject(projectName: '测试作品');

      await tester.pumpWidget(
        ProviderScope(
          overrides: registryOverrides(),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ProjectHomePage(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('测试作品'), findsWidgets);
      // Default project genre is '悬疑 / 草稿'
      expect(find.text('悬疑 / 草稿'), findsOneWidget);
    });

    testWidgets('shows no project state when no project is open', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Delete all projects to simulate "no project" state
      final allProjects = List<ProjectRecord>.from(workspaceStore.projects);
      for (final project in allProjects) {
        workspaceStore.deleteProject(project);
      }

      await tester.pumpWidget(
        ProviderScope(
          overrides: registryOverrides(),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ProjectHomePage(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('未选择作品'), findsOneWidget);
      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('exposes four navigation entry tiles', (tester) async {
      tester.view.physicalSize = const Size(1280, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      workspaceStore.createProject(projectName: '导航测试');

      await tester.pumpWidget(
        ProviderScope(
          overrides: registryOverrides(),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ProjectHomePage(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(ProjectHomePage.shelfEntryKey), findsOneWidget);
      expect(find.byKey(ProjectHomePage.studioEntryKey), findsOneWidget);
      expect(find.byKey(ProjectHomePage.bibleEntryKey), findsOneWidget);
      expect(find.byKey(ProjectHomePage.productionEntryKey), findsOneWidget);

      expect(find.text('书架'), findsOneWidget);
      expect(find.text('切换作品'), findsOneWidget);
      expect(find.text('创作台'), findsOneWidget);
      expect(find.text('写作工作台'), findsOneWidget);
      expect(find.text('设定集'), findsOneWidget);
      expect(find.text('作品资料'), findsOneWidget);
      expect(find.text('进度'), findsOneWidget);
      expect(find.text('统计与发布'), findsOneWidget);
    });

    testWidgets('shelf entry navigates to shelf', (tester) async {
      tester.view.physicalSize = const Size(1280, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      workspaceStore.createProject(projectName: '书架导航测试');

      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: registryOverrides(),
          child: MaterialApp(
            theme: AppTheme.light(),
            navigatorKey: navigatorKey,
            home: const ProjectHomePage(),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(ProjectHomePage.shelfEntryKey));
      await tester.pumpAndSettle();

      // Navigation pops to root, so we should be back at root
      expect(navigatorKey.currentState?.canPop(), false);
    });

    testWidgets('studio entry navigates to workbench', (tester) async {
      tester.view.physicalSize = const Size(1280, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      workspaceStore.createProject(projectName: '创作台导航测试');

      bool workbenchNavigated = false;
      AppNavigator.register(AppRoutes.workbench, (context, _) {
        workbenchNavigated = true;
        return const SizedBox.shrink();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: registryOverrides(),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ProjectHomePage(),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(ProjectHomePage.studioEntryKey));
      await tester.pumpAndSettle();

      expect(workbenchNavigated, true);
    });

    testWidgets('bible entry navigates to bible route', (tester) async {
      tester.view.physicalSize = const Size(1280, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      workspaceStore.createProject(projectName: '设定集导航测试');

      bool bibleNavigated = false;
      AppNavigator.register(AppRoutes.bible, (context, _) {
        bibleNavigated = true;
        return const SizedBox.shrink();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: registryOverrides(),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ProjectHomePage(),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(ProjectHomePage.bibleEntryKey));
      await tester.pumpAndSettle();

      expect(bibleNavigated, true);
    });

    testWidgets('production entry navigates to production board', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      workspaceStore.createProject(projectName: '进度导航测试');

      bool productionNavigated = false;
      AppNavigator.register(AppRoutes.productionBoard, (context, _) {
        productionNavigated = true;
        return const SizedBox.shrink();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: registryOverrides(),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ProjectHomePage(),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(ProjectHomePage.productionEntryKey));
      await tester.pumpAndSettle();

      expect(productionNavigated, true);
    });

    testWidgets('displays scene location when available', (tester) async {
      tester.view.physicalSize = const Size(1280, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      workspaceStore.createProject(projectName: '场景显示测试');
      // The default scene created with a project should have chapterLabel '第 1 章 / 场景 01'
      final scene = workspaceStore.currentSceneOrNull;
      expect(scene?.chapterLabel, contains('章'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: registryOverrides(),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ProjectHomePage(),
          ),
        ),
      );
      await tester.pump();

      // Should display the chapter label from the default scene
      expect(find.textContaining('章'), findsWidgets);
    });
  });
}
