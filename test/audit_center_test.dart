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

  testWidgets('shows audit center ready state', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(home: AuditCenterPage()),
    );

    expect(find.text('审计中心'), findsOneWidget);
    expect(find.text('查看一致性问题、证据与处理状态'), findsOneWidget);
    expect(find.text('审计规则已同步'), findsOneWidget);
  });

  testWidgets('shows empty state', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: AuditCenterPage(uiState: AuditCenterUiState.empty),
      ),
    );

    expect(find.text('当前项目暂无问题'), findsOneWidget);
    expect(find.text('暂无一致性问题'), findsOneWidget);
    expect(
      find.textContaining('当前项目没有检测到角色、规则、道具或时间线冲突'),
      findsOneWidget,
    );
  });

  testWidgets('shows filter no results state', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: AuditCenterPage(uiState: AuditCenterUiState.filterNoResults),
      ),
    );

    expect(find.text('0 个匹配'), findsOneWidget);
    expect(find.text('当前筛选没有命中问题'), findsOneWidget);
    expect(find.text('清空筛选'), findsOneWidget);
    expect(find.text('未选中问题'), findsOneWidget);
    expect(find.text('无可用动作'), findsOneWidget);
  });

  testWidgets('shows related draft missing state', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: AuditCenterPage(
          uiState: AuditCenterUiState.relatedDraftMissing,
        ),
      ),
    );

    expect(find.text('无法定位关联草稿'), findsOneWidget);
    expect(
      find.textContaining('原始 SceneDraft 已被删除'),
      findsOneWidget,
    );
    expect(find.text('返回工作台'), findsOneWidget);
    expect(find.text('重新审计'), findsOneWidget);
  });

  testWidgets('shows jump failed state', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: AuditCenterPage(uiState: AuditCenterUiState.jumpFailed),
      ),
    );

    expect(find.text('跳转失败'), findsOneWidget);
    expect(
      find.textContaining('目标场景'),
      findsOneWidget,
    );
    expect(find.text('返回工作台'), findsOneWidget);
    expect(find.text('重新审计'), findsOneWidget);
  });
}
