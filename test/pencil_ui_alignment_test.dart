import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/state/app_ai_history_storage.dart';
import 'package:novel_writer/app/state/app_draft_storage.dart';
import 'package:novel_writer/app/state/app_draft_store.dart';
import 'package:novel_writer/app/state/app_scene_context_store.dart';
import 'package:novel_writer/app/state/app_scene_context_storage.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/app/state/app_simulation_storage.dart';
import 'package:novel_writer/app/state/app_simulation_store.dart';
import 'package:novel_writer/app/state/app_version_storage.dart';
import 'package:novel_writer/app/state/app_version_store.dart';
import 'package:novel_writer/app/state/app_workspace_storage.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';
import 'package:novel_writer/app/widgets/desktop_shell.dart';
import 'package:novel_writer/main.dart';

void main() {
  const desktopSize = Size(1280, 800);

  setUp(() {
    AppAiHistoryStore.debugStorageOverride = InMemoryAppAiHistoryStorage();
    AppDraftStore.debugStorageOverride = InMemoryAppDraftStorage();
    AppSceneContextStore.debugStorageOverride =
        InMemoryAppSceneContextStorage();
    AppSettingsStore.debugStorageOverride = InMemoryAppSettingsStorage();
    AppSimulationStore.debugStorageOverride = InMemoryAppSimulationStorage();
    AppVersionStore.debugStorageOverride = InMemoryAppVersionStorage();
    AppWorkspaceStore.debugStorageOverride = InMemoryAppWorkspaceStorage();
  });

  tearDown(() {
    AppAiHistoryStore.debugStorageOverride = null;
    AppDraftStore.debugStorageOverride = null;
    AppSceneContextStore.debugStorageOverride = null;
    AppSettingsStore.debugStorageOverride = null;
    AppSimulationStore.debugStorageOverride = null;
    AppVersionStore.debugStorageOverride = null;
    AppWorkspaceStore.debugStorageOverride = null;
  });

  Future<void> setDesktopSize(WidgetTester tester) async {
    tester.view.physicalSize = desktopSize;
    tester.view.devicePixelRatio = 1.0;
  }

  // --- Shared shell and navigation ---

  group('shared shell and navigation', () {
    testWidgets(
      'Project List renders header actions, handle region, filter pane, shelf, detail, and footer strip',
      (tester) async {
        await setDesktopSize(tester);
        await tester.pumpWidget(const NovelWriterApp());
        await tester.pump();

        expect(find.byType(DesktopShellFrame), findsOneWidget);

        // Top header actions: new project, import, search
        expect(
          find.byKey(ProjectListPage.newProjectButtonKey),
          findsOneWidget,
        );
        expect(find.text('导入工程'), findsWidgets);
        expect(find.byKey(ProjectListPage.searchFieldKey), findsOneWidget);

        // Left menu/handle region
        expect(find.byType(DesktopHandleBar), findsOneWidget);

        // Filter pane
        expect(find.text('全部项目'), findsOneWidget);
        expect(find.text('最近打开'), findsOneWidget);
        expect(find.text('进行中'), findsOneWidget);

        // Shelf region
        expect(find.byKey(ProjectListPage.shelfKey), findsOneWidget);

        // Detail panel
        expect(find.byKey(ProjectListPage.detailKey), findsOneWidget);

        // Footer status strip
        expect(find.byKey(ProjectListPage.footerKey), findsOneWidget);
        expect(find.byType(DesktopStatusStrip), findsOneWidget);
      },
    );

    testWidgets(
      'Writing Workbench renders left handle, breadcrumb, editor surface, tool rail, and status strip',
      (tester) async {
        await setDesktopSize(tester);
        await tester.pumpWidget(
          const NovelWriterApp(home: WorkbenchShellPage()),
        );

        expect(find.byType(DesktopShellFrame), findsOneWidget);

        // Left handle
        expect(
          find.byKey(WorkbenchShellPage.menuDrawerHandleKey),
          findsOneWidget,
        );

        // Breadcrumb/header
        expect(find.byKey(WorkbenchShellPage.breadcrumbKey), findsOneWidget);
        expect(find.byType(DesktopBreadcrumbBar), findsOneWidget);

        // Primary editor surface
        expect(find.byKey(WorkbenchShellPage.editorPaneKey), findsOneWidget);

        // Right tool rail
        expect(find.byKey(WorkbenchShellPage.toolRailKey), findsOneWidget);

        // Bottom status strip
        expect(find.byKey(WorkbenchShellPage.statusBarKey), findsOneWidget);
        expect(find.byType(DesktopStatusStrip), findsOneWidget);
      },
    );

    testWidgets(
      'Writing Workbench drawer toggle opens and closes a real menu drawer panel',
      (tester) async {
        await setDesktopSize(tester);
        await tester.pumpWidget(
          const NovelWriterApp(home: WorkbenchShellPage()),
        );

        expect(
          find.byKey(WorkbenchShellPage.menuDrawerPanelKey),
          findsNothing,
        );

        await tester.tap(find.byKey(WorkbenchShellPage.menuDrawerHandleKey));
        await tester.pump();

        expect(
          find.byKey(WorkbenchShellPage.menuDrawerPanelKey),
          findsOneWidget,
        );

        await tester.tap(find.byKey(WorkbenchShellPage.menuDrawerHandleKey));
        await tester.pump();

        expect(
          find.byKey(WorkbenchShellPage.menuDrawerPanelKey),
          findsNothing,
        );
      },
    );
  });

  // --- Workbench behavior preservation ---

  group('workbench behavior preservation', () {
    testWidgets(
      'running simulation still updates the summary banner',
      (tester) async {
        await setDesktopSize(tester);
        await tester.pumpWidget(
          const NovelWriterApp(home: WorkbenchShellPage()),
        );

        await tester.tap(find.byKey(WorkbenchShellPage.runSimulationButtonKey));
        await tester.pump();

        expect(find.text('模拟进行中'), findsWidgets);

        await tester.pump(const Duration(milliseconds: 800));
        await tester.pump();

        expect(find.text('模拟已完成'), findsWidgets);
      },
    );

    testWidgets(
      'opening versions still navigates to chapter history',
      (tester) async {
        await setDesktopSize(tester);
        await tester.pumpWidget(
          const NovelWriterApp(home: WorkbenchShellPage()),
        );

        await tester.tap(find.byKey(WorkbenchShellPage.openVersionsButtonKey));
        await tester.pumpAndSettle();

        expect(find.text('章节版本'), findsOneWidget);
        expect(find.byKey(VersionHistoryPage.versionListKey), findsOneWidget);
      },
    );

    testWidgets('reading mode remains reachable', (tester) async {
      await setDesktopSize(tester);
      await tester.pumpWidget(
        const NovelWriterApp(home: WorkbenchShellPage()),
      );

      await tester.tap(find.byKey(WorkbenchShellPage.readingToolButtonKey));
      await tester.pumpAndSettle();

      expect(find.byKey(ReadingModePage.pageBodyKey), findsOneWidget);
    });

    testWidgets('settings remains reachable from the workbench shell', (
      tester,
    ) async {
      await setDesktopSize(tester);
      await tester.pumpWidget(
        const NovelWriterApp(home: WorkbenchShellPage()),
      );

      await tester.tap(find.byKey(WorkbenchShellPage.settingsToolButtonKey));
      await tester.pump();
      await tester.tap(find.text('打开完整设置'));
      await tester.pumpAndSettle();

      expect(find.text('设置与模型密钥'), findsOneWidget);
      expect(find.byKey(SettingsShellPage.providerConfigKey), findsOneWidget);
    });
  });

  // --- Pencil-aligned page structure ---

  group('Pencil-aligned page structure', () {
    testWidgets(
      'Style Panel renders three distinct content columns under the shared shell',
      (tester) async {
        await setDesktopSize(tester);
        await tester.pumpWidget(
          const NovelWriterApp(home: StylePanelPage()),
        );

        expect(find.byType(DesktopShellFrame), findsOneWidget);
        expect(find.text('风格输入'), findsOneWidget);
        expect(find.text('风格摘要'), findsOneWidget);
        expect(find.text('绑定与强度'), findsOneWidget);
        expect(find.byType(DesktopMenuDrawerRegion), findsOneWidget);
        expect(find.byType(DesktopStatusStrip), findsOneWidget);
      },
    );

    testWidgets(
      'Settings & BYOK renders provider fields, connection/config area, and explanation panel under the shared shell',
      (tester) async {
        await setDesktopSize(tester);
        await tester.pumpWidget(
          const NovelWriterApp(home: SettingsShellPage()),
        );

        expect(find.byType(DesktopShellFrame), findsOneWidget);

        // Provider fields
        expect(find.text('模型提供方'), findsOneWidget);
        expect(find.byKey(SettingsShellPage.providerConfigKey), findsOneWidget);

        // Connection/config area
        expect(find.text('连接测试'), findsOneWidget);

        // Explanation panel
        expect(find.text('说明'), findsOneWidget);

        // Shared shell elements
        expect(find.byType(DesktopMenuDrawerRegion), findsOneWidget);
        expect(find.byType(DesktopStatusStrip), findsOneWidget);
      },
    );

    testWidgets(
      'Project List retains import/export navigation after shell changes',
      (tester) async {
        await setDesktopSize(tester);
        await tester.pumpWidget(const NovelWriterApp());
        await tester.pump();

        if (find
            .byKey(ProjectListPage.menuDrawerPanelKey)
            .evaluate()
            .isEmpty) {
          await tester.tap(find.byKey(ProjectListPage.menuDrawerHandleKey));
          await tester.pump();
        }
        await tester.tap(find.byKey(ProjectListPage.importButtonKey));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byKey(ProjectImportExportPage.titleKey), findsOneWidget);
      },
    );

    testWidgets(
      'Project List retains workbench entry after shell changes',
      (tester) async {
        await setDesktopSize(tester);
        await tester.pumpWidget(const NovelWriterApp());
        await tester.pump();

        await tester.tap(find.byKey(ProjectListPage.openProjectButtonKey));
        await tester.pumpAndSettle();

        expect(find.byKey(WorkbenchShellPage.editorPaneKey), findsOneWidget);
      },
    );
  });
}
