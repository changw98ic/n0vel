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

  testWidgets('shows worldbuilding ready state', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(home: WorldbuildingPage()),
    );

    expect(find.text('世界观'), findsOneWidget);
    expect(find.text('维护地点、组织、规则与引用关系'), findsOneWidget);
    expect(find.text('新建节点'), findsOneWidget);
    expect(find.text('规则索引已同步'), findsOneWidget);
  });

  testWidgets('shows empty state', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: WorldbuildingPage(uiState: WorldbuildingUiState.empty),
      ),
    );

    expect(find.text('当前项目没有世界观节点'), findsOneWidget);
    expect(find.text('创建第一个世界观节点'), findsOneWidget);
    expect(
      find.textContaining('先建立地点、组织或关键物件'),
      findsOneWidget,
    );
  });

  testWidgets('shows filter no results state', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: WorldbuildingPage(
          uiState: WorldbuildingUiState.filterNoResults,
        ),
      ),
    );

    expect(find.text('0 个匹配'), findsOneWidget);
    expect(find.text('没有匹配节点'), findsOneWidget);
    expect(find.text('清空筛选'), findsOneWidget);
    expect(find.text('未选中节点'), findsOneWidget);
  });

  testWidgets('shows missing type state', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: WorldbuildingPage(
          uiState: WorldbuildingUiState.missingType,
        ),
      ),
    );

    expect(find.text('缺少必填类型'), findsOneWidget);
    expect(
      find.textContaining('当前节点尚未指定类型'),
      findsOneWidget,
    );
    expect(
      find.textContaining('节点类型缺失时，系统不会将该节点纳入规则摘要'),
      findsOneWidget,
    );
  });

  testWidgets('shows delete parent confirm overlay', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: WorldbuildingPage(
          uiState: WorldbuildingUiState.deleteParentConfirm,
        ),
      ),
    );

    expect(find.text('删除父节点？'), findsOneWidget);
    expect(find.textContaining('仍包含子节点'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('查看影响后再删'), findsOneWidget);
  });

  testWidgets('ready state shows node list with default nodes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const NovelWriterApp(home: WorldbuildingPage()),
    );
    final workspaceStore = AppWorkspaceScope.of(
      tester.element(find.byType(WorldbuildingPage)),
    );
    workspaceStore.createProject();
    await tester.pump();

    expect(find.byKey(WorldbuildingPage.searchFieldKey), findsOneWidget);
    expect(find.text('旧港规则'), findsWidgets);
    expect(find.text('码头风暴'), findsWidgets);
    expect(find.text('失效脚本'), findsWidgets);
  });

  testWidgets('ready state shows editable fields for selected node', (
    tester,
  ) async {
    await tester.pumpWidget(
      const NovelWriterApp(home: WorldbuildingPage()),
    );
    final workspaceStore = AppWorkspaceScope.of(
      tester.element(find.byType(WorldbuildingPage)),
    );
    workspaceStore.createProject();
    await tester.pump();

    expect(find.text('节点详情'), findsOneWidget);
    expect(find.text('节点名称'), findsOneWidget);
    expect(find.text('所在区域'), findsOneWidget);
    expect(find.text('类型'), findsOneWidget);
    expect(find.text('附属信息'), findsOneWidget);
    expect(find.text('节点摘要'), findsOneWidget);
  });

  testWidgets('ready state shows rules panel', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(home: WorldbuildingPage()),
    );
    final workspaceStore = AppWorkspaceScope.of(
      tester.element(find.byType(WorldbuildingPage)),
    );
    workspaceStore.createProject();
    await tester.pump();

    expect(find.text('规则与引用'), findsOneWidget);
    expect(find.text('规则摘要'), findsOneWidget);
    expect(find.text('引用摘要'), findsOneWidget);
  });
}
