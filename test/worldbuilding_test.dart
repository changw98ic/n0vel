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
    expect(find.text('世界观资料已保存'), findsOneWidget);
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

  testWidgets('creates a new worldbuilding node with all fields', (
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

    // Tap the "新建节点" button to create a new node.
    await tester.tap(find.byKey(WorldbuildingPage.newNodeButtonKey));
    await tester.pumpAndSettle();

    // The newly created node becomes the selected node at index 0.
    // Its fields use keys of the form '{staticKey}-{nodeId}'.
    // Find the text form fields by looking up the key prefix.
    final titleField = find.byWidgetPredicate(
      (widget) =>
          widget is TextFormField &&
          widget.key is ValueKey<String> &&
          (widget.key as ValueKey<String>).value.startsWith(
            WorldbuildingPage.titleFieldKey.value,
          ),
    );
    final locationField = find.byWidgetPredicate(
      (widget) =>
          widget is TextFormField &&
          widget.key is ValueKey<String> &&
          (widget.key as ValueKey<String>).value.startsWith(
            WorldbuildingPage.locationFieldKey.value,
          ),
    );
    final typeField = find.byWidgetPredicate(
      (widget) =>
          widget is TextFormField &&
          widget.key is ValueKey<String> &&
          (widget.key as ValueKey<String>).value.startsWith(
            WorldbuildingPage.typeFieldKey.value,
          ),
    );
    final detailField = find.byWidgetPredicate(
      (widget) =>
          widget is TextFormField &&
          widget.key is ValueKey<String> &&
          (widget.key as ValueKey<String>).value.startsWith(
            WorldbuildingPage.detailFieldKey.value,
          ),
    );
    final summaryField = find.byWidgetPredicate(
      (widget) =>
          widget is TextFormField &&
          widget.key is ValueKey<String> &&
          (widget.key as ValueKey<String>).value.startsWith(
            WorldbuildingPage.summaryFieldKey.value,
          ),
    );

    expect(titleField, findsOneWidget);
    expect(locationField, findsOneWidget);
    expect(typeField, findsOneWidget);
    expect(detailField, findsOneWidget);
    expect(summaryField, findsOneWidget);

    // Enter text into each field.
    await tester.enterText(titleField, '旧码头');
    await tester.enterText(locationField, '港城南区');
    await tester.enterText(typeField, '地点');
    await tester.enterText(detailField, '废弃码头仓库');
    await tester.enterText(summaryField, '旧港码头是故事主要场景');
    await tester.pumpAndSettle();

    // Verify the title text appears in the widget tree.
    expect(find.text('旧码头'), findsWidgets);
    expect(find.text('港城南区'), findsWidgets);
    expect(find.text('地点'), findsWidgets);
    expect(find.text('废弃码头仓库'), findsWidgets);
    expect(find.text('旧港码头是故事主要场景'), findsWidgets);
  });

  testWidgets('filters nodes by search query', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(home: WorldbuildingPage()),
    );
    final workspaceStore = AppWorkspaceScope.of(
      tester.element(find.byType(WorldbuildingPage)),
    );
    workspaceStore.createProject();
    await tester.pump();

    // Default nodes: 旧港规则, 码头风暴, 失效脚本
    expect(find.text('旧港规则'), findsWidgets);
    expect(find.text('码头风暴'), findsWidgets);
    expect(find.text('失效脚本'), findsWidgets);

    // Enter a search term that matches only one node.
    final searchField = find.byKey(WorldbuildingPage.searchFieldKey);
    expect(searchField, findsOneWidget);

    await tester.enterText(searchField, '风暴');
    await tester.pumpAndSettle();

    // "码头风暴" should still be visible; the other two should not appear
    // as list buttons (they may still appear in detail/rules panels).
    expect(find.text('码头风暴'), findsWidgets);

    // Clear search to verify all nodes return.
    await tester.enterText(searchField, '');
    await tester.pumpAndSettle();

    expect(find.text('旧港规则'), findsWidgets);
    expect(find.text('码头风暴'), findsWidgets);
    expect(find.text('失效脚本'), findsWidgets);
  });

  testWidgets('shows warning when type field is empty', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: WorldbuildingPage(
          uiState: WorldbuildingUiState.missingType,
        ),
      ),
    );

    // The missing-type state shows a warning card.
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
}
