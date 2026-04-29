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

  Future<void> openProjectDrawer(WidgetTester tester) async {
    if (find.byKey(ProjectListPage.menuDrawerPanelKey).evaluate().isNotEmpty) {
      return;
    }
    await tester.tap(find.byKey(ProjectListPage.menuDrawerHandleKey));
    await tester.pump();
  }

  testWidgets('shows character library ready state', (tester) async {
    await tester.pumpWidget(const NovelWriterApp(home: CharacterLibraryPage()));

    expect(find.text('角色库'), findsOneWidget);
    expect(find.text('柳溪'), findsWidgets);
    expect(find.textContaining('引用摘要'), findsWidgets);
  });

  testWidgets('selecting another character updates the detail panel', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: CharacterLibraryPage()));

    await tester.tap(find.byKey(CharacterLibraryPage.yueRenKey));
    await tester.pump();

    expect(find.text('岳人'), findsWidgets);
    expect(find.text('线人 / 交通调度'), findsOneWidget);
  });

  testWidgets('creating and searching characters updates the list', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: CharacterLibraryPage()));

    await tester.tap(find.byKey(CharacterLibraryPage.newCharacterButtonKey));
    await tester.pump();
    expect(find.text('新角色 4'), findsWidgets);

    await tester.enterText(
      find.byKey(CharacterLibraryPage.searchFieldKey),
      '新角色 4',
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('新角色 4'), findsWidgets);
    expect(find.text('柳溪'), findsNothing);
  });

  testWidgets('created character persists after reopening the page', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp());

    await openProjectDrawer(tester);
    await tester.tap(find.byKey(ProjectListPage.characterShortcutKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(CharacterLibraryPage.newCharacterButtonKey));
    await tester.pump();
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    await openProjectDrawer(tester);
    await tester.tap(find.byKey(ProjectListPage.characterShortcutKey));
    await tester.pumpAndSettle();

    expect(find.text('新角色 4'), findsWidgets);
  });

  testWidgets('characters are scoped to the selected project', (tester) async {
    await tester.pumpWidget(const NovelWriterApp());
    final workspaceStore = AppWorkspaceScope.of(
      tester.element(find.byType(ProjectListPage)),
    );

    workspaceStore.createProject();
    await tester.pump();

    await openProjectDrawer(tester);
    await tester.tap(find.byKey(ProjectListPage.characterShortcutKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(CharacterLibraryPage.newCharacterButtonKey));
    await tester.pump();
    expect(find.text('新角色 4'), findsWidgets);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    workspaceStore.openProject('project-yuechao');
    await tester.pump();

    await openProjectDrawer(tester);
    await tester.tap(find.byKey(ProjectListPage.characterShortcutKey));
    await tester.pumpAndSettle();

    expect(find.text('新角色 4'), findsNothing);
    expect(find.text('柳溪'), findsWidgets);
  });

  testWidgets('shows character library empty state', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: CharacterLibraryPage(uiState: CharacterLibraryUiState.empty),
      ),
    );

    expect(find.text('角色列表'), findsOneWidget);
    expect(find.text('当前项目无角色'), findsOneWidget);
    expect(find.text('创建第一个角色'), findsOneWidget);
    expect(find.text('先建立主要人物，再为其填写角色定位、Fear、Need 和引用场景。'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '新建角色'), findsWidgets);
  });

  testWidgets('shows character library search no-results state', (
    tester,
  ) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: CharacterLibraryPage(
          uiState: CharacterLibraryUiState.searchNoResults,
        ),
      ),
    );

    expect(find.text('搜索结果'), findsOneWidget);
    expect(find.text('0 个匹配'), findsOneWidget);
    expect(find.text('没有找到匹配角色'), findsOneWidget);
    expect(find.text('试试更短的名字、别名或身份关键词。'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '清空搜索'), findsOneWidget);
    expect(find.text('未选中角色'), findsOneWidget);
    expect(find.text('当前搜索没有结果，因此这里不显示角色详情。'), findsOneWidget);
    expect(find.text('改搜建议'), findsOneWidget);
    expect(find.text('试试角色名、关系称谓、标签或登场场景关键词。'), findsOneWidget);
    expect(find.text('搜索无结果时，不展示引用片段。'), findsOneWidget);
  });

  testWidgets('shows character library warning states', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: CharacterLibraryPage(
          uiState: CharacterLibraryUiState.missingRequiredFields,
        ),
      ),
    );

    expect(find.text('缺少必填字段'), findsOneWidget);
    expect(
      find.text('当前角色尚未填写姓名，因此本轮不会写入角色索引，也不会同步到写作工作台的角色摘要。'),
      findsOneWidget,
    );
    expect(find.text('缺少姓名时，系统不会生成角色摘要，也不会同步到写作工作台。'), findsOneWidget);
  });

  testWidgets('shows character library delete referenced confirm', (
    tester,
  ) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: CharacterLibraryPage(
          uiState: CharacterLibraryUiState.deleteReferencedConfirm,
        ),
      ),
    );

    expect(find.text('删除被引用角色？'), findsOneWidget);
    expect(find.textContaining('仍被 Scene 05 引用'), findsOneWidget);
    expect(find.text('引用场景'), findsWidgets);
    expect(find.text('查看引用后再删'), findsOneWidget);
  });

  testWidgets('shows worldbuilding ready state', (tester) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorldbuildingPage()));

    expect(find.text('世界观'), findsOneWidget);
    expect(find.text('旧港规则'), findsWidgets);
  });

  testWidgets('selecting another world node updates the detail panel', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorldbuildingPage()));

    await tester.tap(find.byKey(WorldbuildingPage.stormNodeKey));
    await tester.pump();

    expect(find.text('码头风暴'), findsWidgets);
    expect(find.text('气候事件'), findsOneWidget);
  });

  testWidgets('creating and searching world nodes updates the tree', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorldbuildingPage()));

    await tester.tap(find.byKey(WorldbuildingPage.newNodeButtonKey));
    await tester.pump();
    expect(find.text('新节点 4'), findsWidgets);

    await tester.enterText(
      find.byKey(WorldbuildingPage.searchFieldKey),
      '新节点 4',
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('新节点 4'), findsWidgets);
    expect(find.text('旧港规则'), findsNothing);
  });

  testWidgets('created world node persists after reopening the page', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp());

    await openProjectDrawer(tester);
    await tester.tap(find.byKey(ProjectListPage.worldShortcutKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(WorldbuildingPage.newNodeButtonKey));
    await tester.pump();
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    await openProjectDrawer(tester);
    await tester.tap(find.byKey(ProjectListPage.worldShortcutKey));
    await tester.pumpAndSettle();

    expect(find.text('新节点 4'), findsWidgets);
  });

  testWidgets('shows worldbuilding empty and filter states', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: WorldbuildingPage(uiState: WorldbuildingUiState.empty),
      ),
    );
    expect(find.text('世界观树'), findsOneWidget);
    expect(find.text('创建第一个世界观节点'), findsOneWidget);
    expect(find.text('先建立地点、组织或关键物件，再补限制条件与引用场景。'), findsOneWidget);

    await tester.pumpWidget(
      const NovelWriterApp(
        home: WorldbuildingPage(uiState: WorldbuildingUiState.filterNoResults),
      ),
    );
    expect(find.text('0 个匹配'), findsOneWidget);
    expect(find.text('没有匹配节点'), findsOneWidget);
    expect(find.text('试试更短的地名、组织名或规则关键词。'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '清空筛选'), findsOneWidget);
    expect(find.text('未选中节点'), findsOneWidget);
    expect(find.text('当前筛选没有结果，因此这里不显示节点详情。'), findsOneWidget);
    expect(find.text('改筛建议'), findsOneWidget);
    expect(find.text('可尝试地点名、组织名、物件名或规则关键词。'), findsOneWidget);
    expect(find.text('筛选无结果时，不展示引用片段。'), findsOneWidget);
  });

  testWidgets('shows worldbuilding blocking states', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: WorldbuildingPage(uiState: WorldbuildingUiState.missingType),
      ),
    );
    expect(find.text('缺少必填类型'), findsOneWidget);
    expect(find.text('当前节点尚未指定类型，因此本轮不会写入世界观索引，也不会同步规则引用。'), findsOneWidget);
    expect(find.text('节点类型缺失时，系统不会将该节点纳入规则摘要或引用索引。'), findsOneWidget);

    await tester.pumpWidget(
      const NovelWriterApp(
        home: WorldbuildingPage(
          uiState: WorldbuildingUiState.deleteParentConfirm,
        ),
      ),
    );
    expect(find.text('删除父节点？'), findsOneWidget);
    expect(find.textContaining('仍包含子节点或关联规则'), findsOneWidget);
    expect(find.text('当前层级'), findsOneWidget);
  });

  testWidgets('shows audit center ready state', (tester) async {
    await tester.pumpWidget(const NovelWriterApp(home: AuditCenterPage()));

    expect(find.text('审计中心'), findsOneWidget);
    expect(find.textContaining('角色动机冲突'), findsOneWidget);
  });

  testWidgets('audit actions update handling feedback', (tester) async {
    await tester.pumpWidget(const NovelWriterApp(home: AuditCenterPage()));
    final store = AppWorkspaceScope.of(
      tester.element(find.byType(AuditCenterPage)),
    );

    await tester.tap(find.byKey(AuditCenterPage.markResolvedKey));
    await tester.pump();
    expect(store.selectedAuditIssue.status, AuditIssueStatus.resolved);
    expect(store.auditActionFeedback, contains('已标记为已处理'));

    await tester.tap(find.byKey(AuditCenterPage.ignoreIssueKey));
    await tester.pump();
    expect(find.textContaining('请先填写忽略原因'), findsOneWidget);
  });

  testWidgets('selecting another audit issue updates evidence detail', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: AuditCenterPage()));

    await tester.tap(find.byKey(AuditCenterPage.warehouseIssueKey));
    await tester.pump();

    expect(find.textContaining('误把仓库当一层'), findsWidgets);
    expect(find.textContaining('仓库层数认知与旧港地图不一致'), findsOneWidget);
  });

  testWidgets('audit selection and feedback persist after reopening the page', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp());

    await openProjectDrawer(tester);
    await tester.tap(find.byKey(ProjectListPage.auditShortcutKey));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AuditCenterPage.warehouseIssueKey));
    await tester.pump();
    await tester.tap(find.byKey(AuditCenterPage.markResolvedKey));
    await tester.pump();

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    await openProjectDrawer(tester);
    await tester.tap(find.byKey(ProjectListPage.auditShortcutKey));
    await tester.pumpAndSettle();

    expect(find.textContaining('仓库层数认知与旧港地图不一致'), findsOneWidget);
    expect(find.textContaining('已标记为已处理'), findsWidgets);
  });

  testWidgets('shows audit center empty and filter states', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: AuditCenterPage(uiState: AuditCenterUiState.empty),
      ),
    );
    expect(find.text('当前项目暂无问题'), findsOneWidget);
    expect(find.text('暂无一致性问题'), findsOneWidget);
    expect(find.text('当前项目没有检测到角色、规则、道具或时间线冲突。'), findsOneWidget);
    expect(find.text('当前无需处理。后续运行审计后，问题会出现在这里。'), findsOneWidget);

    await tester.pumpWidget(
      const NovelWriterApp(
        home: AuditCenterPage(uiState: AuditCenterUiState.filterNoResults),
      ),
    );
    expect(find.text('0 个匹配'), findsOneWidget);
    expect(find.text('当前筛选没有命中问题'), findsOneWidget);
    expect(find.text('试试放宽筛选条件，或切换到问题列表查看全部结果。'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '清空筛选'), findsOneWidget);
    expect(find.text('未选中问题'), findsOneWidget);
    expect(find.text('当前筛选没有结果，因此这里不展示证据详情。'), findsOneWidget);
    expect(find.text('无可用动作'), findsOneWidget);
    expect(find.text('当前没有命中的问题，因此这里不显示跳转、处理或忽略操作。'), findsOneWidget);
  });

  testWidgets('shows audit center error states', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: AuditCenterPage(uiState: AuditCenterUiState.relatedDraftMissing),
      ),
    );
    expect(find.text('无法定位关联草稿'), findsOneWidget);
    expect(
      find.text('原始 SceneDraft 已被删除或索引失效，因此系统无法在中间区展示对应文本片段。'),
      findsOneWidget,
    );
    expect(find.text('建议动作'), findsOneWidget);
    expect(find.text('重新审计'), findsOneWidget);
    expect(find.text('当前限制'), findsOneWidget);

    await tester.pumpWidget(
      const NovelWriterApp(
        home: AuditCenterPage(uiState: AuditCenterUiState.jumpFailed),
      ),
    );
    expect(find.text('跳转失败'), findsOneWidget);
    expect(
      find.text('目标场景 `Scene 05` 已被删除、重命名，或当前索引已失效，因此无法从审计中心直接跳回原位置。'),
      findsOneWidget,
    );
    expect(find.text('建议动作'), findsOneWidget);
    expect(find.text('重新审计'), findsOneWidget);
    expect(find.text('当前限制'), findsOneWidget);
  });
}
