import 'dart:io';

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
import 'package:novel_writer/app/state/story_generation_store.dart';
import 'package:novel_writer/app/state/story_outline_store.dart';
import 'package:novel_writer/app/widgets/desktop_shell.dart';
import 'package:novel_writer/features/import_export/data/project_transfer_service.dart';
import 'package:novel_writer/main.dart';
import 'test_support/app_settings_fake_storages.dart';
import 'test_support/clipboard_spy.dart';

void main() {
  late FakeProjectTransferService transferService;

  setUp(() {
    transferService = FakeProjectTransferService();
    AppAiHistoryStore.debugStorageOverride = InMemoryAppAiHistoryStorage();
    AppDraftStore.debugStorageOverride = InMemoryAppDraftStorage();
    AppSceneContextStore.debugStorageOverride =
        InMemoryAppSceneContextStorage();
    AppSettingsStore.debugStorageOverride = InMemoryAppSettingsStorage();
    AppSimulationStore.debugStorageOverride = InMemoryAppSimulationStorage();
    AppVersionStore.debugStorageOverride = InMemoryAppVersionStorage();
    AppWorkspaceStore.debugStorageOverride = InMemoryAppWorkspaceStorage();
    ProjectImportExportPage.debugServiceOverride = transferService;
  });

  tearDown(() {
    AppAiHistoryStore.debugStorageOverride = null;
    AppDraftStore.debugStorageOverride = null;
    AppSceneContextStore.debugStorageOverride = null;
    AppSettingsStore.debugStorageOverride = null;
    AppSimulationStore.debugStorageOverride = null;
    AppVersionStore.debugStorageOverride = null;
    AppWorkspaceStore.debugStorageOverride = null;
    ProjectImportExportPage.debugServiceOverride = null;
  });

  Future<void> openProjectDrawer(WidgetTester tester) async {
    if (find.byKey(ProjectListPage.menuDrawerPanelKey).evaluate().isNotEmpty) {
      return;
    }
    await tester.tap(find.byKey(ProjectListPage.menuDrawerHandleKey));
    await tester.pump();
  }

  Future<void> stageImportPackage({
    bool duplicateCurrentProject = false,
  }) async {
    final draftStore = AppDraftStore(storage: InMemoryAppDraftStorage());
    final versionStore = AppVersionStore(storage: InMemoryAppVersionStorage());
    final workspaceStore = AppWorkspaceStore(
      storage: InMemoryAppWorkspaceStorage(),
    );
    addTearDown(draftStore.dispose);
    addTearDown(versionStore.dispose);
    addTearDown(workspaceStore.dispose);

    draftStore.updateText('测试导入的真实草稿');
    versionStore.captureSnapshot(label: '测试导入版本', content: '测试导入版本内容');
    if (!duplicateCurrentProject) {
      workspaceStore.createProject();
    }

    await transferService.stageImportFromStores(
      draftStore: draftStore,
      versionStore: versionStore,
      workspaceStore: workspaceStore,
    );
  }

  testWidgets('launches to the project list by default', (tester) async {
    await tester.pumpWidget(const NovelWriterApp());
    await tester.pump();

    expect(find.byKey(ProjectListPage.pageTitleKey), findsOneWidget);
    expect(find.byKey(ProjectListPage.shelfKey), findsOneWidget);
    expect(find.byKey(ProjectListPage.footerKey), findsOneWidget);
    expect(find.text('项目'), findsWidgets);
    expect(find.text('本地优先的长篇小说创作工作区'), findsOneWidget);
    expect(find.text('进行中的小说项目'), findsOneWidget);
    expect(find.text('书架中共有 3 部作品，按最近写作进度排列。'), findsOneWidget);
    expect(find.text('项目概览'), findsOneWidget);
    expect(find.text('最近内容'), findsOneWidget);
    expect(find.text('新建项目'), findsWidgets);
    expect(find.text('导入工程'), findsWidgets);
    expect(find.text('全部项目'), findsOneWidget);
    expect(find.text('最近打开'), findsWidgets);
    expect(find.text('进行中'), findsOneWidget);
  });

  testWidgets(
    'shows the global secure store warning on the project list shell',
    (tester) async {
      AppSettingsStore.debugStorageOverride = ReadFailureWarningStorage();

      await tester.pumpWidget(const NovelWriterApp());
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('设置文件读取失败'), findsOneWidget);
      expect(find.textContaining('无法读取 settings.json'), findsOneWidget);
    },
  );

  testWidgets('validation errors do not surface as a global shell warning', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: SettingsShellPage()));

    await tester.enterText(
      find.byKey(SettingsShellPage.baseUrlFieldKey),
      'not-a-url',
    );
    await tester.enterText(
      find.byKey(SettingsShellPage.apiKeyFieldKey),
      'sk-test-key',
    );
    await tester.tap(find.byKey(SettingsShellPage.saveButtonKey));
    await tester.pump();

    expect(find.text('请输入有效的 base_url'), findsWidgets);
    expect(find.text('重试配置'), findsNothing);
    expect(find.text('设置文件读取失败'), findsNothing);
  });

  testWidgets('global secure store warning can be retried from the shell', (
    tester,
  ) async {
    AppSettingsStore.debugStorageOverride = RecoveringReadStorage();

    await tester.pumpWidget(const NovelWriterApp());
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('设置文件读取失败'), findsOneWidget);
    await tester.tap(find.text('重试配置'));
    await tester.pumpAndSettle();

    expect(find.text('设置文件读取失败'), findsNothing);
    expect(find.text('重试配置'), findsNothing);
  });

  testWidgets('global shell warning can copy diagnostic details', (
    tester,
  ) async {
    AppSettingsStore.debugStorageOverride = ReadFailureWarningStorage();
    final clipboard = ClipboardSpy(tester)..attach();
    addTearDown(() {
      clipboard.detach();
    });

    await tester.pumpWidget(const NovelWriterApp());
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(DesktopShellFrame.copyDiagnosticButtonKey));
    await tester.pump();

    expect(clipboard.text, contains('类别：settings_file_read_failed'));
    expect(clipboard.text, contains('诊断：settings.json is unreadable'));
    expect(find.text('诊断已复制'), findsOneWidget);
  });

  testWidgets('opens the workbench from project list', (tester) async {
    await tester.pumpWidget(const NovelWriterApp());
    await tester.pump();

    await tester.tap(find.byKey(ProjectListPage.openProjectButtonKey));
    await tester.pumpAndSettle();

    expect(find.byKey(WorkbenchShellPage.editorPaneKey), findsOneWidget);
  });

  testWidgets('search filters the project shelf and can be cleared', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp());
    await tester.pump();

    await tester.enterText(find.byKey(ProjectListPage.searchFieldKey), '盐港');
    await tester.pump();

    expect(find.text('盐港档案'), findsWidgets);
    expect(find.text('月潮回声'), findsNothing);

    await tester.enterText(find.byKey(ProjectListPage.searchFieldKey), '');
    await tester.pump();

    expect(find.text('月潮回声'), findsWidgets);
    expect(find.text('盐港档案'), findsWidgets);
  });

  testWidgets('creating a new project adds it to the shelf and selects it', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp());
    await tester.pump();

    await tester.ensureVisible(find.byKey(ProjectListPage.newProjectButtonKey));
    await tester.tap(find.byKey(ProjectListPage.newProjectButtonKey));
    await tester.pump();

    expect(find.text('新建项目 4'), findsWidgets);
    expect(find.text('打开'), findsOneWidget);
    expect(find.text('编辑'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
  });

  testWidgets(
    'created project persists after leaving and reopening project list',
    (tester) async {
      await tester.pumpWidget(const NovelWriterApp());
      await tester.pump();

      await tester.ensureVisible(
        find.byKey(ProjectListPage.newProjectButtonKey),
      );
      await tester.tap(find.byKey(ProjectListPage.newProjectButtonKey));
      await tester.pump();
      await openProjectDrawer(tester);
      await tester.tap(find.byKey(ProjectListPage.workbenchShortcutKey));
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();

      expect(find.text('新建项目 4'), findsWidgets);
    },
  );

  testWidgets('created project persists after rebuilding the app shell', (
    tester,
  ) async {
    final workspaceStorage = InMemoryAppWorkspaceStorage();
    AppWorkspaceStore.debugStorageOverride = workspaceStorage;

    await tester.pumpWidget(const NovelWriterApp());
    await tester.pump();

    await tester.ensureVisible(find.byKey(ProjectListPage.newProjectButtonKey));
    await tester.tap(find.byKey(ProjectListPage.newProjectButtonKey));
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(const NovelWriterApp());
    await tester.pump();
    await tester.pump();

    expect(find.text('新建项目 4'), findsWidgets);
  });

  testWidgets('different projects keep independent draft content', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp());
    await tester.pump();

    await tester.ensureVisible(find.byKey(ProjectListPage.newProjectButtonKey));
    await tester.tap(find.byKey(ProjectListPage.newProjectButtonKey));
    await tester.pump();

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          MaterialPageRoute<void>(builder: (_) => const WorkbenchShellPage()),
        );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(WorkbenchShellPage.editorTextFieldKey),
      '新建项目自己的草稿',
    );
    await tester.pump();
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    final workspaceStore = AppWorkspaceScope.of(
      tester.element(find.byType(ProjectListPage)),
    );
    final originalProject = workspaceStore.projects.firstWhere(
      (project) => project.title == '月潮回声',
    );
    final createdProject = workspaceStore.projects.firstWhere(
      (project) => project.title == '新建项目 4',
    );

    workspaceStore.openProject(originalProject.id);
    await tester.pump();
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          MaterialPageRoute<void>(builder: (_) => const WorkbenchShellPage()),
        );
    await tester.pumpAndSettle();

    expect(find.text('新建项目自己的草稿'), findsNothing);
    expect(find.text('她推开仓库门，雨水顺着袖口滴进掌心，远处码头的雾灯像一根迟疑的针。'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    workspaceStore.openProject(createdProject.id);
    await tester.pump();
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          MaterialPageRoute<void>(builder: (_) => const WorkbenchShellPage()),
        );
    await tester.pumpAndSettle();

    expect(find.text('新建项目自己的草稿'), findsOneWidget);
  });

  testWidgets('workbench breadcrumb follows the selected project', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp());
    await tester.pump();
    final workspaceStore = AppWorkspaceScope.of(
      tester.element(find.byType(ProjectListPage)),
    );

    workspaceStore.createProject();
    await tester.pump();

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          MaterialPageRoute<void>(builder: (_) => const WorkbenchShellPage()),
        );
    await tester.pumpAndSettle();

    expect(find.text('新建项目 4 / 第 1 章 / 场景 01 · 等待命名'), findsWidgets);
  });

  testWidgets(
    'workbench breadcrumb follows the current scene within a project',
    (tester) async {
      await tester.pumpWidget(const NovelWriterApp());
      await tester.pump();
      final workspaceStore = AppWorkspaceScope.of(
        tester.element(find.byType(ProjectListPage)),
      );

      workspaceStore.updateCurrentScene(
        sceneId: 'scene-07-balcony-conflict',
        recentLocation: '第 3 章 / 场景 07 · 阳台争执',
      );
      await tester.pump();

      tester
          .state<NavigatorState>(find.byType(Navigator))
          .push(
            MaterialPageRoute<void>(builder: (_) => const WorkbenchShellPage()),
          );
      await tester.pumpAndSettle();

      expect(find.text('月潮回声 / 第 3 章 / 场景 07 · 阳台争执'), findsWidgets);
    },
  );

  testWidgets('continue composing opens the workbench from project detail', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp());
    await tester.pump();

    await tester.tap(find.byKey(ProjectListPage.continueProjectButtonKey));
    await tester.pumpAndSettle();

    expect(find.byKey(WorkbenchShellPage.editorPaneKey), findsOneWidget);
  });

  testWidgets('opens import export from project list', (tester) async {
    await tester.pumpWidget(const NovelWriterApp());
    await tester.pump();

    await openProjectDrawer(tester);
    await tester.tap(find.byKey(ProjectListPage.importButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(ProjectImportExportPage.titleKey), findsOneWidget);
  });

  testWidgets('executing import persists after reopening import export page', (
    tester,
  ) async {
    await stageImportPackage();
    await tester.pumpWidget(const NovelWriterApp());
    await tester.pump();

    await openProjectDrawer(tester);
    await tester.tap(find.byKey(ProjectListPage.importButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(
      find.byKey(ProjectImportExportPage.executeImportButtonKey),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await openProjectDrawer(tester);
    await tester.tap(find.byKey(ProjectListPage.importButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('导入成功'), findsOneWidget);
    expect(find.textContaining('角色、世界观、风格、版本'), findsOneWidget);
  });

  testWidgets(
    'opens style, character, world, and audit modules from project list',
    (tester) async {
      await tester.pumpWidget(const NovelWriterApp());
      await tester.pump();

      await openProjectDrawer(tester);
      await tester.tap(find.byKey(ProjectListPage.styleShortcutKey));
      await tester.pumpAndSettle();
      expect(find.text('风格面板'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await openProjectDrawer(tester);
      await tester.tap(find.byKey(ProjectListPage.characterShortcutKey));
      await tester.pumpAndSettle();
      expect(find.text('角色库'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await openProjectDrawer(tester);
      await tester.tap(find.byKey(ProjectListPage.worldShortcutKey));
      await tester.pumpAndSettle();
      expect(find.text('世界观'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await openProjectDrawer(tester);
      await tester.tap(find.byKey(ProjectListPage.auditShortcutKey));
      await tester.pumpAndSettle();
      expect(find.text('审计中心'), findsOneWidget);
    },
  );

  testWidgets('shows project list empty state', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: ProjectListPage(uiState: ProjectListUiState.empty),
      ),
    );

    expect(find.text('当前还没有项目'), findsOneWidget);
    expect(find.text('新建项目'), findsWidgets);
    expect(find.text('打开菜单'), findsOneWidget);
  });

  testWidgets('shows project list search no results state', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: ProjectListPage(uiState: ProjectListUiState.searchNoResults),
      ),
    );

    expect(find.text('没有匹配的项目'), findsOneWidget);
    expect(find.text('清空搜索'), findsOneWidget);
  });

  testWidgets('shows project list database read failed state', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: ProjectListPage(uiState: ProjectListUiState.databaseReadFailed),
      ),
    );

    expect(find.text('书架未加载'), findsOneWidget);
    expect(find.textContaining('本地数据库读取失败'), findsOneWidget);
  });

  testWidgets(
    'retry from database failure replaces the failed page with ready state',
    (tester) async {
      await tester.pumpWidget(
        const NovelWriterApp(
          home: ProjectListPage(uiState: ProjectListUiState.databaseReadFailed),
        ),
      );

      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();

      expect(find.byKey(ProjectListPage.shelfKey), findsOneWidget);
      expect(find.text('书架未加载'), findsNothing);
    },
  );

  testWidgets('shows project list delete confirmation state', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: ProjectListPage(uiState: ProjectListUiState.deleteConfirm),
      ),
    );

    expect(find.text('删除确认'), findsOneWidget);
    expect(find.textContaining('移除本地书架中的项目记录'), findsOneWidget);
  });

  testWidgets('shows project list import failed notice state', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: ProjectListPage(uiState: ProjectListUiState.importFailed),
      ),
    );

    expect(find.text('导入失败'), findsOneWidget);
    expect(find.text('工程包结构不完整，当前书架内容未受影响，可修正包后重试。'), findsOneWidget);
  });

  testWidgets('delete action shows pencil-aligned project delete dialog', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp());
    await tester.pump();

    final deleteButton = find.descendant(
      of: find.byKey(ProjectListPage.detailKey),
      matching: find.widgetWithText(OutlinedButton, '删除'),
    );
    await tester.ensureVisible(deleteButton);
    await tester.tap(deleteButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('删除对象'), findsOneWidget);
    expect(find.text('月潮回声'), findsWidgets);
    expect(find.text('删除说明'), findsOneWidget);
    expect(find.textContaining('不会删除你手动导出的工程包'), findsOneWidget);
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();
  });

  testWidgets('default import export ready view renders key panels', (
    tester,
  ) async {
    await tester.pumpWidget(
      const NovelWriterApp(home: ProjectImportExportPage()),
    );

    expect(find.byKey(ProjectImportExportPage.titleKey), findsOneWidget);
    expect(find.text('导出工程'), findsOneWidget);
    expect(find.text('导入工程'), findsOneWidget);
    expect(
      find.byKey(ProjectImportExportPage.executeImportButtonKey),
      findsOneWidget,
    );
    expect(find.byKey(ProjectImportExportPage.manifestKey), findsOneWidget);
    expect(find.text('准备导入'), findsOneWidget);
    expect(find.text('导入导出准备就绪'), findsOneWidget);
  });

  testWidgets('shows import success summary', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: ProjectImportExportPage(
          uiState: ProjectImportExportUiState.importSuccess,
        ),
      ),
    );

    expect(find.text('导入成功'), findsOneWidget);
    expect(find.text('导入结果'), findsOneWidget);
    expect(find.text('已刷新内容'), findsOneWidget);
    expect(find.text('打开项目'), findsOneWidget);
    expect(find.text('返回项目列表'), findsOneWidget);
  });

  testWidgets('shows overwrite confirm summary', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: ProjectImportExportPage(
          uiState: ProjectImportExportUiState.overwriteConfirm,
        ),
      ),
    );

    expect(find.text('覆盖确认'), findsOneWidget);
    expect(find.textContaining('会替换同 ID 项目'), findsOneWidget);
  });

  testWidgets('shows overwrite success summary', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: ProjectImportExportPage(
          uiState: ProjectImportExportUiState.overwriteSuccess,
        ),
      ),
    );

    expect(find.text('覆盖导入成功'), findsOneWidget);
    expect(find.text('已覆盖'), findsOneWidget);
    expect(find.textContaining('旧索引已被替换刷新'), findsOneWidget);
    expect(find.text('打开项目'), findsOneWidget);
    expect(find.text('返回项目列表'), findsOneWidget);
    expect(find.text('覆盖导入完成'), findsOneWidget);
  });

  testWidgets('shows missing manifest blocked state', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: ProjectImportExportPage(
          uiState: ProjectImportExportUiState.missingManifest,
        ),
      ),
    );

    expect(find.text('缺少 manifest.json'), findsOneWidget);
    expect(find.textContaining('无法读取项目元信息'), findsOneWidget);
  });

  testWidgets('shows major version blocked state', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: ProjectImportExportPage(
          uiState: ProjectImportExportUiState.majorVersionBlocked,
        ),
      ),
    );

    expect(find.text('版本主号不兼容'), findsOneWidget);
    expect(find.text('失败原因'), findsOneWidget);
    expect(find.textContaining('schema v1.x'), findsOneWidget);
  });

  testWidgets('shows minor version compatibility warning state', (
    tester,
  ) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: ProjectImportExportPage(
          uiState: ProjectImportExportUiState.minorVersionWarning,
        ),
      ),
    );

    expect(find.text('版本次号兼容性警告'), findsOneWidget);
    expect(find.text('兼容性提示'), findsOneWidget);
    expect(find.text('允许继续导入，但建议先核对内容后再继续'), findsOneWidget);
  });

  testWidgets('shows no exportable project state', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: ProjectImportExportPage(
          uiState: ProjectImportExportUiState.noExportableProject,
        ),
      ),
    );

    expect(find.text('无可导出项目'), findsOneWidget);
    expect(find.textContaining('请先创建项目或导入一个工程'), findsOneWidget);
  });

  testWidgets(
    'running import from default page shows import success feedback',
    (tester) async {
      await stageImportPackage();
      await tester.pumpWidget(
        const NovelWriterApp(home: ProjectImportExportPage()),
      );

      await tester.tap(
        find.byKey(ProjectImportExportPage.executeImportButtonKey),
      );
      await tester.pumpAndSettle();

      expect(find.text('导入成功'), findsOneWidget);
      expect(find.textContaining('角色、世界观、风格、版本'), findsOneWidget);
    },
  );

  testWidgets(
    'duplicate import requires overwrite confirmation before applying',
    (tester) async {
      await stageImportPackage(duplicateCurrentProject: true);
      await tester.pumpWidget(
        const NovelWriterApp(home: ProjectImportExportPage()),
      );

      await tester.tap(
        find.byKey(ProjectImportExportPage.executeImportButtonKey),
      );
      await tester.pump();

      expect(find.text('覆盖确认'), findsOneWidget);
      expect(find.textContaining('会替换同 ID 项目'), findsOneWidget);

      await tester.tap(
        find.byKey(ProjectImportExportPage.executeImportButtonKey),
      );
      await tester.pump();

      expect(find.text('覆盖导入成功'), findsOneWidget);
      expect(find.textContaining('旧索引已被替换刷新'), findsOneWidget);
    },
  );

  testWidgets('exporting from default page shows export success feedback', (
    tester,
  ) async {
    await tester.pumpWidget(
      const NovelWriterApp(home: ProjectImportExportPage()),
    );

    await tester.tap(find.text('导出当前工程'));
    await tester.pump();

    expect(find.text('导出成功'), findsOneWidget);
    expect(find.textContaining('工程包已写入本地导出目录'), findsOneWidget);
  });
}

class FakeProjectTransferService extends ProjectTransferService {
  FakeProjectTransferService() : super();

  static const String _fakeExportPath =
      '/tmp/novel_writer_test/exports/lunaris-export.zip';
  static const String _fakeImportPath =
      '/tmp/novel_writer_test/imports/lunaris-export.zip';

  ProjectPackageManifest? _exportManifest;
  ProjectPackageManifest? _importManifest;
  Map<String, Object?>? _stagedDraftJson;
  Map<String, Object?>? _stagedVersionJson;
  Map<String, Object?>? _stagedWorkspaceJson;

  @override
  String get exportPackagePath => _fakeExportPath;

  @override
  String get importPackagePath => _fakeImportPath;

  Future<void> stageImportFromStores({
    required AppDraftStore draftStore,
    required AppVersionStore versionStore,
    required AppWorkspaceStore workspaceStore,
  }) async {
    _stagedDraftJson = draftStore.exportJson();
    _stagedVersionJson = versionStore.exportJson();
    _stagedWorkspaceJson = workspaceStore.exportJson();
    _importManifest = ProjectPackageManifest(
      packageName: 'lunarifest',
      projectId: workspaceStore.currentProjectId,
      projectTitle: workspaceStore.currentProject.title,
      schemaMajor: 1,
      schemaMinor: 0,
      exportedAtMs: DateTime.now().millisecondsSinceEpoch,
      contentSummary: '正文 / 资料 / 风格 / 版本',
    );
  }

  @override
  Future<ProjectTransferResult> exportPackage({
    AppAiHistoryStore? aiHistoryStore,
    required AppDraftStore draftStore,
    AppSceneContextStore? sceneContextStore,
    AppSimulationStore? simulationStore,
    StoryOutlineStore? storyOutlineStore,
    StoryGenerationStore? storyGenerationStore,
    required AppVersionStore versionStore,
    required AppWorkspaceStore workspaceStore,
  }) async {
    _exportManifest = ProjectPackageManifest(
      packageName: 'lunarifest',
      projectId: workspaceStore.currentProjectId,
      projectTitle: workspaceStore.currentProject.title,
      schemaMajor: 1,
      schemaMinor: 0,
      exportedAtMs: DateTime.now().millisecondsSinceEpoch,
      contentSummary: '正文 / 资料 / 风格 / 版本',
    );
    return ProjectTransferResult(
      state: ProjectTransferState.exportSuccess,
      packagePath: exportPackagePath,
      manifest: _exportManifest,
    );
  }

  @override
  Future<ProjectTransferResult> importPackage({
    AppAiHistoryStore? aiHistoryStore,
    required AppDraftStore draftStore,
    AppSceneContextStore? sceneContextStore,
    AppSimulationStore? simulationStore,
    StoryOutlineStore? storyOutlineStore,
    StoryGenerationStore? storyGenerationStore,
    required AppVersionStore versionStore,
    required AppWorkspaceStore workspaceStore,
    bool overwriteExisting = false,
  }) async {
    if (_stagedDraftJson == null ||
        _stagedVersionJson == null ||
        _stagedWorkspaceJson == null ||
        _importManifest == null) {
      return ProjectTransferResult(
        state: ProjectTransferState.invalidPackage,
        packagePath: importPackagePath,
      );
    }

    if (_importManifest!.projectId.isNotEmpty &&
        workspaceStore.hasProjectWithId(_importManifest!.projectId) &&
        !overwriteExisting) {
      return ProjectTransferResult(
        state: ProjectTransferState.overwriteConfirm,
        packagePath: importPackagePath,
        manifest: _importManifest,
      );
    }

    draftStore.importJson(_stagedDraftJson!);
    versionStore.importJson(_stagedVersionJson!);
    workspaceStore.importJson(_stagedWorkspaceJson!);
    return ProjectTransferResult(
      state: overwriteExisting
          ? ProjectTransferState.overwriteSuccess
          : ProjectTransferState.importSuccess,
      packagePath: importPackagePath,
      manifest: _importManifest,
    );
  }

  @override
  Future<ProjectPackageInspection> inspectPackage(File packageFile) async {
    if (packageFile.path == exportPackagePath && _exportManifest != null) {
      return ProjectPackageInspection(
        state: ProjectTransferState.ready,
        packagePath: exportPackagePath,
        manifest: _exportManifest,
      );
    }
    if (packageFile.path == importPackagePath && _importManifest != null) {
      return ProjectPackageInspection(
        state: ProjectTransferState.ready,
        packagePath: importPackagePath,
        manifest: _importManifest,
      );
    }
    return ProjectPackageInspection(
      state: ProjectTransferState.invalidPackage,
      packagePath: packageFile.path,
    );
  }
}
