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

  Future<void> openProjectDrawer(WidgetTester tester) async {
    if (find.byKey(ProjectListPage.menuDrawerPanelKey).evaluate().isNotEmpty) {
      return;
    }
    await tester.tap(find.byKey(ProjectListPage.menuDrawerHandleKey));
    await tester.pump();
  }

  Future<void> tapHandleBar(WidgetTester tester) async {
    await tester.tap(find.descendant(
      of: find.byType(DesktopHandleBar),
      matching: find.byType(InkWell),
    ));
    await tester.pump();
  }

  // --- Shared Desktop Shell ---

  group('shared desktop shell on all pages', () {
    testWidgets(
      'project list renders inside DesktopShellFrame with status strip',
      (tester) async {
        await setDesktopSize(tester);
        await tester.pumpWidget(const NovelWriterApp());
        await tester.pump();

        expect(find.byType(DesktopShellFrame), findsOneWidget);
        expect(find.byKey(ProjectListPage.pageTitleKey), findsOneWidget);
        expect(find.byKey(ProjectListPage.shelfKey), findsOneWidget);
        expect(find.byKey(ProjectListPage.footerKey), findsOneWidget);
        expect(find.byType(DesktopStatusStrip), findsOneWidget);
        expect(find.byType(DesktopHandleBar), findsOneWidget);
      },
    );

    testWidgets(
      'workbench renders inside DesktopShellFrame with breadcrumb and status strip',
      (tester) async {
        await setDesktopSize(tester);
        await tester.pumpWidget(
          const NovelWriterApp(home: WorkbenchShellPage()),
        );

        expect(find.byType(DesktopShellFrame), findsOneWidget);
        expect(find.byKey(WorkbenchShellPage.breadcrumbKey), findsOneWidget);
        expect(find.byKey(WorkbenchShellPage.editorPaneKey), findsOneWidget);
        expect(find.byKey(WorkbenchShellPage.statusBarKey), findsOneWidget);
        expect(find.byType(DesktopBreadcrumbBar), findsOneWidget);
        expect(find.byType(DesktopMenuDrawerRegion), findsOneWidget);
      },
    );

    testWidgets(
      'style panel renders inside DesktopShellFrame with header and status strip',
      (tester) async {
        await setDesktopSize(tester);
        await tester.pumpWidget(
          const NovelWriterApp(home: StylePanelPage()),
        );

        expect(find.byType(DesktopShellFrame), findsOneWidget);
        expect(find.byType(DesktopHeaderBar), findsOneWidget);
        expect(find.text('风格面板'), findsOneWidget);
        expect(find.byType(DesktopMenuDrawerRegion), findsOneWidget);
        expect(find.byType(DesktopStatusStrip), findsOneWidget);
      },
    );

    testWidgets(
      'settings renders inside DesktopShellFrame with header and status strip',
      (tester) async {
        await setDesktopSize(tester);
        await tester.pumpWidget(
          const NovelWriterApp(home: SettingsShellPage()),
        );

        expect(find.byType(DesktopShellFrame), findsOneWidget);
        expect(find.byType(DesktopHeaderBar), findsOneWidget);
        expect(find.text('设置与模型密钥'), findsOneWidget);
        expect(find.byType(DesktopMenuDrawerRegion), findsOneWidget);
        expect(find.byType(DesktopStatusStrip), findsOneWidget);
      },
    );
  });

  // --- User 1: Author navigating between project home and writing tools ---

  group('author navigating between project home and writing tools', () {
    testWidgets('navigates from project list to workbench', (tester) async {
        await setDesktopSize(tester);
      await tester.pumpWidget(const NovelWriterApp());
      await tester.pump();

      await tester.tap(find.byKey(ProjectListPage.openProjectButtonKey));
      await tester.pumpAndSettle();

      expect(find.byKey(WorkbenchShellPage.editorPaneKey), findsOneWidget);
      expect(find.byKey(WorkbenchShellPage.breadcrumbKey), findsOneWidget);
    });

    testWidgets('navigates back from workbench to project list', (tester) async {
        await setDesktopSize(tester);
      await tester.pumpWidget(const NovelWriterApp());
      await tester.pump();

      await tester.tap(find.byKey(ProjectListPage.openProjectButtonKey));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(WorkbenchShellPage.menuDrawerHandleKey));
      await tester.pump();

      await tester.tap(find.descendant(
        of: find.byKey(WorkbenchShellPage.menuDrawerPanelKey),
        matching: find.text('书架'),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(ProjectListPage.pageTitleKey), findsOneWidget);
      expect(find.byKey(ProjectListPage.shelfKey), findsOneWidget);
    });

    testWidgets(
      'navigates to style panel from project list drawer and back',
      (tester) async {
        await setDesktopSize(tester);
        await tester.pumpWidget(const NovelWriterApp());
        await tester.pump();

        await openProjectDrawer(tester);
        await tester.tap(find.byKey(ProjectListPage.styleShortcutKey));
        await tester.pumpAndSettle();

        expect(find.text('风格面板'), findsOneWidget);
        expect(find.byType(DesktopShellFrame), findsOneWidget);

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.byKey(ProjectListPage.pageTitleKey), findsOneWidget);
      },
    );

    testWidgets(
      'navigates to settings from project list drawer',
      (tester) async {
        await setDesktopSize(tester);
        await tester.pumpWidget(const NovelWriterApp());
        await tester.pump();

        await openProjectDrawer(tester);
        await tester.tap(find.descendant(
          of: find.byKey(ProjectListPage.menuDrawerPanelKey),
          matching: find.text('设置'),
        ));
        await tester.pumpAndSettle();

        expect(find.text('设置与模型密钥'), findsOneWidget);
        expect(find.byType(DesktopShellFrame), findsOneWidget);

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.byKey(ProjectListPage.pageTitleKey), findsOneWidget);
      },
    );
  });

  // --- User 2: Author editing a scene in the workbench with a stable global shell ---

  group('author editing a scene with stable global shell', () {
    testWidgets(
      'editor is the primary focus area with separate tool rail',
      (tester) async {
        await setDesktopSize(tester);
        await tester.pumpWidget(
          const NovelWriterApp(home: WorkbenchShellPage()),
        );

        expect(find.byKey(WorkbenchShellPage.editorPaneKey), findsOneWidget);
        expect(find.byKey(WorkbenchShellPage.toolRailKey), findsOneWidget);
        expect(find.byKey(WorkbenchShellPage.toolWindowKey), findsNothing);
      },
    );

    testWidgets(
      'menu drawer open shows real panel with navigation items',
      (tester) async {
        await setDesktopSize(tester);
        await tester.pumpWidget(
          const NovelWriterApp(
            home: WorkbenchShellPage(uiState: WorkbenchUiState.menuDrawerOpen),
          ),
        );

        expect(
          find.byKey(WorkbenchShellPage.menuDrawerPanelKey),
          findsOneWidget,
        );
        expect(find.text('书架'), findsWidgets);
        expect(find.text('编辑工作台'), findsWidgets);
        expect(find.text('设置'), findsWidgets);
      },
    );

    testWidgets(
      'toggling drawer open then closed preserves editor content',
      (tester) async {
        await setDesktopSize(tester);
        await tester.pumpWidget(
          const NovelWriterApp(home: WorkbenchShellPage()),
        );

        await tester.enterText(
          find.byKey(WorkbenchShellPage.editorTextFieldKey),
          '正文内容在切换抽屉后保持不变',
        );
        await tester.pump();

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
        expect(find.text('正文内容在切换抽屉后保持不变'), findsOneWidget);
      },
    );

    testWidgets(
      'tool window opens alongside editor without collapsing editor pane',
      (tester) async {
        await setDesktopSize(tester);
        await tester.pumpWidget(
          const NovelWriterApp(home: WorkbenchShellPage()),
        );

        await tester.tap(
          find.byKey(WorkbenchShellPage.resourcesToolButtonKey),
        );
        await tester.pump();

        expect(find.byKey(WorkbenchShellPage.editorPaneKey), findsOneWidget);
        expect(find.byKey(WorkbenchShellPage.toolWindowKey), findsOneWidget);
      },
    );

    testWidgets(
      'workbench drawer navigates to settings and back preserves return context',
      (tester) async {
        await setDesktopSize(tester);
        await tester.pumpWidget(
          const NovelWriterApp(home: WorkbenchShellPage()),
        );

        await tester.tap(find.byKey(WorkbenchShellPage.menuDrawerHandleKey));
        await tester.pump();

        await tester.tap(find.descendant(
          of: find.byKey(WorkbenchShellPage.menuDrawerPanelKey),
          matching: find.text('设置'),
        ));
        await tester.pumpAndSettle();

        expect(find.text('设置与模型密钥'), findsOneWidget);

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.byKey(WorkbenchShellPage.editorPaneKey), findsOneWidget);
      },
    );

    testWidgets(
      'status bar shows current editing state',
      (tester) async {
        await setDesktopSize(tester);
        await tester.pumpWidget(
          const NovelWriterApp(home: WorkbenchShellPage()),
        );

        expect(find.byKey(WorkbenchShellPage.statusBarKey), findsOneWidget);
        expect(find.textContaining('写作模式'), findsOneWidget);
      },
    );
  });

  // --- User 3: Author configuring style and provider settings ---

  group('author configuring style and provider settings', () {
    testWidgets(
      'style panel shows three-column layout: input, summary, binding',
      (tester) async {
        await setDesktopSize(tester);
        await tester.pumpWidget(
          const NovelWriterApp(home: StylePanelPage()),
        );

        expect(find.text('风格输入'), findsOneWidget);
        expect(find.text('风格摘要'), findsOneWidget);
        expect(find.text('绑定与强度'), findsOneWidget);
      },
    );

    testWidgets(
      'settings shows provider fields, connection panel, and help panel',
      (tester) async {
        await setDesktopSize(tester);
        await tester.pumpWidget(
          const NovelWriterApp(home: SettingsShellPage()),
        );

        expect(find.text('模型提供方'), findsOneWidget);
        expect(find.text('说明'), findsOneWidget);
      },
    );

    testWidgets(
      'style panel drawer navigates to workbench',
      (tester) async {
        await setDesktopSize(tester);
        await tester.pumpWidget(
          const NovelWriterApp(home: StylePanelPage()),
        );

        await tapHandleBar(tester);
        await tester.tap(find.text('编辑工作台'));
        await tester.pumpAndSettle();

        expect(find.byKey(WorkbenchShellPage.editorPaneKey), findsOneWidget);
      },
    );

    testWidgets(
      'style panel drawer navigates back to project list via project list drawer',
      (tester) async {
        await setDesktopSize(tester);
        await tester.pumpWidget(const NovelWriterApp());
        await tester.pump();

        await openProjectDrawer(tester);
        await tester.tap(find.byKey(ProjectListPage.styleShortcutKey));
        await tester.pumpAndSettle();

        expect(find.text('风格面板'), findsOneWidget);

        await tapHandleBar(tester);
        await tester.tap(find.text('书架'));
        await tester.pumpAndSettle();

        expect(find.byKey(ProjectListPage.pageTitleKey), findsOneWidget);
      },
    );

    testWidgets(
      'settings drawer navigates to workbench',
      (tester) async {
        await setDesktopSize(tester);
        await tester.pumpWidget(
          const NovelWriterApp(home: SettingsShellPage()),
        );

        await tapHandleBar(tester);
        await tester.tap(find.text('编辑工作台'));
        await tester.pumpAndSettle();

        expect(find.byKey(WorkbenchShellPage.editorPaneKey), findsOneWidget);
      },
    );

    testWidgets(
      'settings drawer navigates back to project list via project list drawer',
      (tester) async {
        await setDesktopSize(tester);
        await tester.pumpWidget(const NovelWriterApp());
        await tester.pump();

        await openProjectDrawer(tester);
        await tester.tap(find.descendant(
          of: find.byKey(ProjectListPage.menuDrawerPanelKey),
          matching: find.text('设置'),
        ));
        await tester.pumpAndSettle();

        expect(find.text('设置与模型密钥'), findsOneWidget);

        await tapHandleBar(tester);
        await tester.tap(find.text('书架'));
        await tester.pumpAndSettle();

        expect(find.byKey(ProjectListPage.pageTitleKey), findsOneWidget);
      },
    );
  });
}
