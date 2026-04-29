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

  testWidgets('shows character library ready state', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(home: CharacterLibraryPage()),
    );

    expect(find.text('角色库'), findsOneWidget);
    expect(find.text('维护人物信息、心理参数与引用场景'), findsOneWidget);
    expect(find.text('新建角色'), findsOneWidget);
    expect(find.text('角色索引已同步'), findsOneWidget);
  });

  testWidgets('shows empty state', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: CharacterLibraryPage(uiState: CharacterLibraryUiState.empty),
      ),
    );

    expect(find.text('当前项目无角色'), findsOneWidget);
    expect(find.text('创建第一个角色'), findsOneWidget);
    expect(
      find.textContaining('先建立主要人物'),
      findsOneWidget,
    );
  });

  testWidgets('shows search no results state', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: CharacterLibraryPage(
          uiState: CharacterLibraryUiState.searchNoResults,
        ),
      ),
    );

    expect(find.text('0 个匹配'), findsOneWidget);
    expect(find.text('没有找到匹配角色'), findsOneWidget);
    expect(find.text('清空搜索'), findsOneWidget);
    expect(find.text('未选中角色'), findsOneWidget);
  });

  testWidgets('shows missing required fields state', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: CharacterLibraryPage(
          uiState: CharacterLibraryUiState.missingRequiredFields,
        ),
      ),
    );

    expect(find.text('缺少必填字段'), findsOneWidget);
    expect(
      find.textContaining('当前角色尚未填写姓名'),
      findsOneWidget,
    );
    expect(
      find.textContaining('缺少姓名时，系统不会生成角色摘要'),
      findsOneWidget,
    );
  });

  testWidgets('shows delete referenced confirm overlay', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: CharacterLibraryPage(
          uiState: CharacterLibraryUiState.deleteReferencedConfirm,
        ),
      ),
    );

    expect(find.text('删除被引用角色？'), findsOneWidget);
    expect(find.textContaining('仍被'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('查看引用后再删'), findsOneWidget);
  });

  testWidgets('ready state shows character list with default characters', (
    tester,
  ) async {
    await tester.pumpWidget(
      const NovelWriterApp(home: CharacterLibraryPage()),
    );
    final workspaceStore = AppWorkspaceScope.of(
      tester.element(find.byType(CharacterLibraryPage)),
    );
    workspaceStore.createProject();
    await tester.pump();

    expect(find.byKey(CharacterLibraryPage.searchFieldKey), findsOneWidget);
    expect(find.text('柳溪'), findsWidgets);
    expect(find.text('岳人'), findsWidgets);
    expect(find.text('傅行舟'), findsWidgets);
  });

  testWidgets('ready state shows editable fields for selected character', (
    tester,
  ) async {
    await tester.pumpWidget(
      const NovelWriterApp(home: CharacterLibraryPage()),
    );
    final workspaceStore = AppWorkspaceScope.of(
      tester.element(find.byType(CharacterLibraryPage)),
    );
    workspaceStore.createProject();
    await tester.pump();

    expect(find.text('角色详情'), findsOneWidget);
    expect(find.text('姓名'), findsOneWidget);
    expect(find.text('身份'), findsOneWidget);
    expect(find.text('笔记'), findsOneWidget);
    expect(find.text('核心需求'), findsOneWidget);
    expect(find.text('人物摘要'), findsWidgets);
  });

  testWidgets('ready state shows summary panel', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(home: CharacterLibraryPage()),
    );
    final workspaceStore = AppWorkspaceScope.of(
      tester.element(find.byType(CharacterLibraryPage)),
    );
    workspaceStore.createProject();
    await tester.pump();

    expect(find.text('引用摘要'), findsOneWidget);
    expect(find.text('引用场景'), findsWidgets);
  });
}
