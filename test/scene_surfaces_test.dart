import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/state/app_ai_history_storage.dart';
import 'package:novel_writer/app/state/app_draft_storage.dart';
import 'package:novel_writer/app/state/app_draft_store.dart';
import 'package:novel_writer/app/state/app_scene_context_storage.dart';
import 'package:novel_writer/app/state/app_scene_context_store.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/app/state/app_simulation_storage.dart';
import 'package:novel_writer/app/state/app_simulation_store.dart';
import 'package:novel_writer/app/state/app_version_storage.dart';
import 'package:novel_writer/app/state/app_version_store.dart';
import 'package:novel_writer/app/state/app_workspace_storage.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';
import 'package:novel_writer/main.dart';

void main() {
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

  Future<void> openProjectDrawer(WidgetTester tester) async {
    if (find.byKey(ProjectListPage.menuDrawerPanelKey).evaluate().isNotEmpty) {
      return;
    }
    await tester.tap(find.byKey(ProjectListPage.menuDrawerHandleKey));
    await tester.pump();
  }

  testWidgets('opens the scene manager from the project shelf drawer', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp());

    await openProjectDrawer(tester);
    await tester.tap(find.byKey(ProjectListPage.sceneShortcutKey));
    await tester.pumpAndSettle();

    expect(find.text('场景管理'), findsOneWidget);
    expect(find.text('证人房间对峙'), findsWidgets);
    expect(find.text('第 3 章'), findsWidgets);
    expect(find.text('共 2 个场景'), findsOneWidget);
  });

  testWidgets('renders pencil-aligned scene detail fields and action summary', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: SceneManagementPage()));

    expect(find.text('场景详情'), findsOneWidget);
    expect(find.text('场景标题'), findsOneWidget);
    expect(find.text('章节标签'), findsWidgets);
    expect(find.text('场景摘要'), findsOneWidget);
    expect(find.text('最近修改'), findsOneWidget);
    expect(find.text('第 3 章 / 场景 05 · 证人房间对峙'), findsOneWidget);
    expect(find.text('场景操作'), findsOneWidget);
    expect(find.textContaining('新建、重命名、编辑章节标签'), findsOneWidget);
  });

  testWidgets('creates a scene from the scene manager', (tester) async {
    await tester.pumpWidget(const NovelWriterApp(home: SceneManagementPage()));

    await tester.tap(find.byKey(SceneManagementPage.newSceneButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('创建后会出现在当前项目的场景列表中，并立即可在工作台中继续写作。'), findsOneWidget);
    expect(find.text('场景标题'), findsWidgets);

    await tester.enterText(
      find.byKey(SceneManagementPage.sceneTitleFieldKey),
      '天台交锋',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('天台交锋'), findsWidgets);
    expect(find.text('第 3 章 / 场景 06'), findsWidgets);
  });

  testWidgets('renames the selected scene from the scene manager', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: SceneManagementPage()));

    await tester.tap(find.byKey(SceneManagementPage.renameSceneButtonKey));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(SceneManagementPage.sceneTitleFieldKey),
      '证人房间加压',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('证人房间加压'), findsWidgets);
    expect(find.text('证人房间对峙'), findsNothing);
  });

  testWidgets('deletes the selected scene from the scene manager', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: SceneManagementPage()));

    await tester.ensureVisible(
      find.byKey(SceneManagementPage.deleteSceneButtonKey),
    );
    await tester.tap(find.byKey(SceneManagementPage.deleteSceneButtonKey));
    await tester.pumpAndSettle();

    expect(
      find.text('删除后会从当前项目的场景列表中移除，工作台会自动切换到相邻场景，并同步刷新相关引用摘要。'),
      findsOneWidget,
    );

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(find.text('证人房间对峙'), findsNothing);
    expect(find.text('雨夜码头'), findsWidgets);
  });

  testWidgets('moves the selected scene up in the scene manager', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: SceneManagementPage()));

    await tester.ensureVisible(
      find.byKey(SceneManagementPage.moveSceneUpButtonKey),
    );
    await tester.tap(find.byKey(SceneManagementPage.moveSceneUpButtonKey));
    await tester.pumpAndSettle();

    final first = tester.getTopLeft(find.text('第 3 章 / 场景 05 · 证人房间对峙')).dy;
    final second = tester.getTopLeft(find.text('第 3 章 / 场景 03 · 雨夜码头')).dy;
    expect(first, lessThan(second));
  });

  testWidgets('edits the chapter label of the selected scene', (tester) async {
    await tester.pumpWidget(const NovelWriterApp(home: SceneManagementPage()));

    await tester.tap(find.byKey(SceneManagementPage.chapterLabelButtonKey));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(SceneManagementPage.chapterLabelFieldKey),
      '第 4 章 / 场景 01',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('第 4 章 / 场景 01'), findsWidgets);
    expect(find.text('第 4 章'), findsWidgets);
  });

  testWidgets('edits the summary of the selected scene', (tester) async {
    await tester.pumpWidget(const NovelWriterApp(home: SceneManagementPage()));

    await tester.tap(find.byKey(SceneManagementPage.sceneSummaryButtonKey));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(SceneManagementPage.sceneSummaryFieldKey),
      '这是更新后的场景摘要。',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('这是更新后的场景摘要。'), findsWidgets);
  });
}
