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

  testWidgets('shows style panel ready summary', (tester) async {
    await tester.pumpWidget(const NovelWriterApp(home: StylePanelPage()));

    expect(find.text('风格面板'), findsOneWidget);
    expect(find.text('以问卷为主，支持 JSON 导入的风格配置'), findsOneWidget);
    expect(find.text('生成风格配置'), findsOneWidget);
    expect(find.text('校验就绪 · 问卷已完成 · 支持 JSON Schema v1.0'), findsOneWidget);
    expect(find.text('冷峻悬疑第一人称'), findsWidgets);
    expect(find.text('第三人称限知'), findsWidgets);
  });

  testWidgets('switches between questionnaire and json input modes', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: StylePanelPage()));

    expect(find.text('风格名称'), findsOneWidget);
    expect(find.text('问卷输入'), findsOneWidget);
    expect(find.text('优先补全问卷字段，再生成当前项目的风格摘要。'), findsOneWidget);

    await tester.tap(find.byKey(StylePanelPage.jsonModeButtonKey));
    await tester.pumpAndSettle();

    expect(find.byKey(StylePanelPage.jsonDraftFieldKey), findsOneWidget);
    expect(find.text('选择 JSON 文件'), findsOneWidget);
    expect(find.text('JSON'), findsWidgets);
    expect(find.text('JSON 草稿'), findsOneWidget);
    expect(
      find.text('可直接粘贴或导入 StyleProfile JSON，导入后会保留字段校验结果。'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(StylePanelPage.questionnaireModeButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('风格名称'), findsOneWidget);
  });

  testWidgets('adjusts intensity and shows binding feedback', (tester) async {
    await tester.pumpWidget(const NovelWriterApp(home: StylePanelPage()));

    expect(find.text('1x'), findsOneWidget);

    await tester.tap(find.byKey(StylePanelPage.intensityIncreaseButtonKey));
    await tester.pump();
    expect(find.text('2x'), findsOneWidget);

    await tester.tap(find.byKey(StylePanelPage.bindProjectButtonKey));
    await tester.pump();
    expect(find.textContaining('绑定到项目默认风格'), findsOneWidget);

    await tester.tap(find.byKey(StylePanelPage.bindSceneButtonKey));
    await tester.pump();
    expect(find.textContaining('场景覆盖'), findsOneWidget);
  });

  testWidgets('style selections persist after reopening the page', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp());

    await openProjectDrawer(tester);
    await tester.tap(find.byKey(ProjectListPage.styleShortcutKey));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(StylePanelPage.jsonModeButtonKey));
    await tester.pump();
    await tester.tap(find.byKey(StylePanelPage.intensityIncreaseButtonKey));
    await tester.pump();
    await tester.tap(find.byKey(StylePanelPage.bindSceneButtonKey));
    await tester.pump();

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    await openProjectDrawer(tester);
    await tester.tap(find.byKey(ProjectListPage.styleShortcutKey));
    await tester.pumpAndSettle();

    expect(find.byKey(StylePanelPage.jsonDraftFieldKey), findsOneWidget);
    expect(find.text('2x'), findsOneWidget);
    expect(find.textContaining('场景覆盖'), findsOneWidget);
  });

  testWidgets('style selections are scoped to the selected project', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp());
    final workspaceStore = AppWorkspaceScope.of(
      tester.element(find.byType(ProjectListPage)),
    );

    workspaceStore.createProject();
    await tester.pump();

    await openProjectDrawer(tester);
    await tester.tap(find.byKey(ProjectListPage.styleShortcutKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(StylePanelPage.jsonModeButtonKey));
    await tester.pump();
    await tester.tap(find.byKey(StylePanelPage.intensityIncreaseButtonKey));
    await tester.pump();
    expect(find.text('2x'), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    workspaceStore.openProject('project-yuechao');
    await tester.pump();

    await openProjectDrawer(tester);
    await tester.tap(find.byKey(ProjectListPage.styleShortcutKey));
    await tester.pumpAndSettle();

    expect(find.text('风格名称'), findsOneWidget);
    expect(find.text('2x'), findsNothing);
    expect(find.text('1x'), findsOneWidget);
  });

  testWidgets('shows style panel empty state', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: StylePanelPage(uiState: StylePanelUiState.empty),
      ),
    );

    expect(find.text('尚未生成风格摘要'), findsOneWidget);
    expect(find.textContaining('从填写问卷或导入配置文件开始'), findsOneWidget);
  });

  testWidgets('shows config file format error state', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: StylePanelPage(uiState: StylePanelUiState.jsonError),
      ),
    );

    expect(find.text('JSON 校验失败'), findsOneWidget);
    expect(find.text('错误 1：缺少必填字段 version'), findsOneWidget);
    expect(find.text('错误 2：rhythm_profile 值不受支持'), findsOneWidget);
    expect(find.textContaining('系统不会生成风格配置'), findsOneWidget);
    expect(find.text('处理建议'), findsOneWidget);
  });

  testWidgets('shows unsupported version blocked state', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: StylePanelPage(uiState: StylePanelUiState.unsupportedVersion),
      ),
    );

    expect(find.text('配置版本不受支持'), findsOneWidget);
    expect(find.text('MVP 仅支持 1.0 版配置。'), findsOneWidget);
  });

  testWidgets('shows unknown fields ignored notice', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: StylePanelPage(uiState: StylePanelUiState.unknownFieldsIgnored),
      ),
    );

    expect(find.text('未知字段已忽略'), findsOneWidget);
    expect(find.textContaining('已忽略并继续生成'), findsOneWidget);
  });

  testWidgets('shows missing required fields state', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: StylePanelPage(uiState: StylePanelUiState.missingRequiredFields),
      ),
    );

    expect(find.text('问卷缺少必填项'), findsOneWidget);
    expect(find.text('缺失必填项'), findsOneWidget);
    expect(find.textContaining('不会生成风格配置'), findsOneWidget);
    expect(find.text('建议修正'), findsOneWidget);
  });

  testWidgets('shows validation failed state', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: StylePanelPage(uiState: StylePanelUiState.validationFailed),
      ),
    );

    expect(find.text('风格校验失败'), findsOneWidget);
    expect(find.text('失败原因'), findsOneWidget);
    expect(find.textContaining('当前风格输入之间存在冲突'), findsOneWidget);
    expect(find.text('建议修正'), findsOneWidget);
    expect(find.text('结果说明'), findsOneWidget);
  });

  testWidgets('shows max profiles reached state', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: StylePanelPage(uiState: StylePanelUiState.maxProfilesReached),
      ),
    );

    expect(find.text('达到风格配置上限'), findsOneWidget);
    expect(find.text('同一项目最多保留 3 个风格配置，请先删除或替换现有配置。'), findsOneWidget);
  });

  testWidgets('shows scene override notice', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: StylePanelPage(uiState: StylePanelUiState.sceneOverrideNotice),
      ),
    );

    expect(find.text('场景级覆盖已生效'), findsOneWidget);
    expect(find.text('场景级绑定优先于项目级默认风格，切换场景后仍会恢复项目默认配置。'), findsOneWidget);
  });
}
