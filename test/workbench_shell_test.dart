import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/logging/app_event_log.dart';
import 'package:novel_writer/app/logging/app_event_log_storage.dart';
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
import 'package:novel_writer/app/state/story_generation_run_storage.dart';
import 'package:novel_writer/app/state/story_generation_run_store.dart';
import 'package:novel_writer/app/state/story_generation_storage.dart';
import 'package:novel_writer/app/state/story_generation_store.dart';
import 'package:novel_writer/app/state/story_outline_storage.dart';
import 'package:novel_writer/app/state/story_outline_store.dart';
import 'package:novel_writer/features/author_feedback/data/author_feedback_storage.dart';
import 'package:novel_writer/features/author_feedback/data/author_feedback_store.dart';
import 'package:novel_writer/features/author_feedback/domain/author_feedback_models.dart';
import 'package:novel_writer/features/author_feedback/presentation/author_feedback_panel.dart';
import 'package:novel_writer/features/review_tasks/data/review_task_storage.dart';
import 'package:novel_writer/features/review_tasks/data/review_task_store.dart';
import 'package:novel_writer/features/story_generation/data/chapter_generation_orchestrator.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';
import 'package:novel_writer/main.dart';
import 'test_support/app_settings_fake_storages.dart';
import 'test_support/clipboard_spy.dart';
import 'test_support/fake_app_llm_client.dart';

Future<void> configureWorkbenchAi(WidgetTester tester) async {
  await tester.tap(find.byKey(WorkbenchShellPage.settingsToolButtonKey));
  await tester.pump();
  await tester.tap(find.text('打开完整设置'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(SettingsShellPage.apiKeyFieldKey),
    'sk-test-key',
  );
  await tester.tap(find.byKey(SettingsShellPage.saveButtonKey));
  await tester.pump();
  await tester.pageBack();
  await tester.pumpAndSettle();
}

Future<void> startWorkbenchSimulation(
  WidgetTester tester, {
  bool forceFailure = false,
}) async {
  final runButton = find.byKey(
    forceFailure
        ? WorkbenchShellPage.failSimulationButtonKey
        : WorkbenchShellPage.runSimulationButtonKey,
  );
  await tester.ensureVisible(runButton);
  await tester.pump();
  await tester.tap(runButton);
  await tester.pump();

  final confirmButton = find.text('确认生成候选稿');
  if (confirmButton.evaluate().isNotEmpty) {
    await tester.tap(confirmButton);
    await tester.pump();
  }
}

Future<void> openWorkbenchSimulationProcess(WidgetTester tester) async {
  final processLink = find.text('查看生成过程').last;
  await tester.ensureVisible(processLink);
  await tester.pump();
  await tester.tap(processLink);
  await tester.pumpAndSettle();
}

void setWorkbenchEditorSelection(
  WidgetTester tester, {
  required int start,
  required int end,
}) {
  final textField = tester.widget<TextField>(
    find.byKey(WorkbenchShellPage.editorTextFieldKey),
  );
  textField.controller!.selection = TextSelection(
    baseOffset: start,
    extentOffset: end,
  );
}

EditableTextState workbenchEditorState(WidgetTester tester) {
  return tester.state<EditableTextState>(find.byType(EditableText).first);
}

void main() {
  late _RecordingAppEventLogStorage eventLogStorage;

  setUp(() {
    eventLogStorage = _RecordingAppEventLogStorage();
    AppEventLog.debugStorageOverride = eventLogStorage;
    AppAiHistoryStore.debugStorageOverride = InMemoryAppAiHistoryStorage();
    AppDraftStore.debugStorageOverride = InMemoryAppDraftStorage();
    AppSceneContextStore.debugStorageOverride =
        InMemoryAppSceneContextStorage();
    AppSettingsStore.debugStorageOverride = InMemoryAppSettingsStorage()
      ..save({
        'providerName': 'OpenAI 兼容服务',
        'baseUrl': 'https://api.example.com/v1',
        'model': 'gpt-4.1-mini',
        'apiKey': 'sk-test-key',
        'themePreference': 'light',
      });
    AppSettingsStore.debugLlmClientOverride = FakeAppLlmClient();
    AppSimulationStore.debugStorageOverride = InMemoryAppSimulationStorage();
    AppVersionStore.debugStorageOverride = InMemoryAppVersionStorage();
    AppWorkspaceStore.debugStorageOverride = InMemoryAppWorkspaceStorage();
    AuthorFeedbackStore.debugStorageOverride = InMemoryAuthorFeedbackStorage();
    ReviewTaskStore.debugStorageOverride = InMemoryReviewTaskStorage();
    StoryGenerationRunStore.debugStorageOverride =
        InMemoryStoryGenerationRunStorage();
    StoryGenerationRunStore.debugOrchestratorFactoryOverride =
        (settingsStore) =>
            _ImmediateStoryRunOrchestrator(settingsStore: settingsStore);
    StoryGenerationStore.debugStorageOverride =
        InMemoryStoryGenerationStorage();
    StoryOutlineStore.debugStorageOverride = InMemoryStoryOutlineStorage();
  });

  tearDown(() {
    AppEventLog.debugStorageOverride = null;
    AppAiHistoryStore.debugStorageOverride = null;
    AppDraftStore.debugStorageOverride = null;
    AppSceneContextStore.debugStorageOverride = null;
    AppSettingsStore.debugStorageOverride = null;
    AppSettingsStore.debugLlmClientOverride = null;
    AppSimulationStore.debugStorageOverride = null;
    AppVersionStore.debugStorageOverride = null;
    AppWorkspaceStore.debugStorageOverride = null;
    AuthorFeedbackStore.debugStorageOverride = null;
    ReviewTaskStore.debugStorageOverride = null;
    StoryGenerationRunStore.debugStorageOverride = null;
    StoryGenerationRunStore.debugOrchestratorFactoryOverride = null;
    StoryGenerationStore.debugStorageOverride = null;
    StoryOutlineStore.debugStorageOverride = null;
  });

  testWidgets('renders the MVP workbench shell regions', (tester) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    expect(find.byKey(WorkbenchShellPage.menuDrawerHandleKey), findsOneWidget);
    expect(find.byKey(WorkbenchShellPage.breadcrumbKey), findsOneWidget);
    expect(
      find.byKey(WorkbenchShellPage.editorSurfaceHeaderKey),
      findsOneWidget,
    );
    expect(find.byKey(WorkbenchShellPage.editorSurfaceMetaKey), findsOneWidget);
    expect(find.byKey(WorkbenchShellPage.editorPaneKey), findsOneWidget);
    expect(find.byKey(WorkbenchShellPage.toolRailKey), findsOneWidget);
    expect(find.byKey(WorkbenchShellPage.statusBarKey), findsOneWidget);
    expect(find.text('自动保存 · Markdown'), findsWidgets);
    expect(find.textContaining('阅读模式可切换'), findsOneWidget);
  });

  testWidgets('captures an author feedback revision request from workbench', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    await tester.tap(find.byKey(WorkbenchShellPage.feedbackToolButtonKey));
    await tester.pump();
    await tester.enterText(
      find.byKey(AuthorFeedbackPanel.noteFieldKey),
      'Tighten the scene aftermath before accepting the chapter.',
    );
    await tester.tap(find.byKey(AuthorFeedbackPanel.requestRevisionButtonKey));
    await tester.pump();

    expect(find.textContaining('Tighten the scene aftermath'), findsOneWidget);
    expect(find.text('已请求修订'), findsOneWidget);

    final store = AuthorFeedbackScope.of(
      tester.element(find.byType(WorkbenchShellPage)),
    );
    expect(store.items.single.status, AuthorFeedbackStatus.revisionRequested);
  });

  testWidgets('shows the drawer when the drawer-open state is active', (
    tester,
  ) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: WorkbenchShellPage(uiState: WorkbenchUiState.menuDrawerOpen),
      ),
    );

    expect(find.byKey(WorkbenchShellPage.menuDrawerPanelKey), findsOneWidget);
    expect(find.text('导航'), findsOneWidget);
  });

  testWidgets('keeps the drawer handle attached to the opened menu edge', (
    tester,
  ) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: WorkbenchShellPage(uiState: WorkbenchUiState.menuDrawerOpen),
      ),
    );

    final handleLeft = tester
        .getTopLeft(find.byKey(WorkbenchShellPage.menuDrawerHandleKey))
        .dx;
    final drawerRight = tester
        .getTopRight(find.byKey(WorkbenchShellPage.menuDrawerPanelKey))
        .dx;

    expect(handleLeft, greaterThan(drawerRight));
  });

  testWidgets('toggles the drawer from the handle in interactive mode', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    expect(find.byKey(WorkbenchShellPage.menuDrawerPanelKey), findsNothing);

    await tester.tap(find.byKey(WorkbenchShellPage.menuDrawerHandleKey));
    await tester.pump();

    expect(find.byKey(WorkbenchShellPage.menuDrawerPanelKey), findsOneWidget);

    await tester.tap(find.byKey(WorkbenchShellPage.menuDrawerHandleKey));
    await tester.pump();

    expect(find.byKey(WorkbenchShellPage.menuDrawerPanelKey), findsNothing);
  });

  testWidgets('shows the API key blocking message in the workbench context', (
    tester,
  ) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: WorkbenchShellPage(uiState: WorkbenchUiState.apiKeyMissing),
      ),
    );

    expect(find.text('生成候选稿前需要连接模型服务'), findsOneWidget);
    expect(find.text('前往设置'), findsOneWidget);
  });

  testWidgets('shows the missing character binding guidance', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: WorkbenchShellPage(
          uiState: WorkbenchUiState.missingCharacterBinding,
        ),
      ),
    );

    expect(find.text('本章还没选择出场人物。'), findsOneWidget);
  });

  testWidgets('store-driven scene bindings disable simulation when missing', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));
    final workspaceStore = AppWorkspaceScope.of(
      tester.element(find.byType(WorkbenchShellPage)),
    );
    final currentSceneId = workspaceStore.currentProject.sceneId;
    for (final character in workspaceStore.characters) {
      if (character.linkedSceneIds.contains(currentSceneId)) {
        workspaceStore.setCharacterSceneLinked(
          characterId: character.id,
          sceneId: currentSceneId,
          linked: false,
        );
      }
    }
    await tester.pump();

    // Scene context fallback keeps hasSceneCharacterBinding=true,
    // and with pre-populated settings canGenerateAi=true,
    // so the banner falls through all checks to null (no banner).
    expect(find.text('章节可先继续写'), findsNothing);
    final runButton = tester.widget<FilledButton>(
      find.byKey(WorkbenchShellPage.runSimulationButtonKey),
    );
    expect(runButton.onPressed, isNotNull);
  });

  testWidgets('shows the missing character reference notice', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: WorkbenchShellPage(
          uiState: WorkbenchUiState.missingCharacterReference,
        ),
      ),
    );

    expect(find.text('出场人物需要重新确认，正文仍可继续编辑。'), findsOneWidget);
  });

  testWidgets(
    'shows resource panel missing character state when reference is lost',
    (tester) async {
      await tester.pumpWidget(
        const NovelWriterApp(
          home: WorkbenchShellPage(
            uiState: WorkbenchUiState.missingCharacterReference,
          ),
        ),
      );

      await tester.tap(find.byKey(WorkbenchShellPage.resourcesToolButtonKey));
      await tester.pump();

      expect(find.text('出场人物需要重新确认'), findsOneWidget);
    },
  );

  testWidgets('shows the missing world reference notice', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: WorkbenchShellPage(
          uiState: WorkbenchUiState.missingWorldReference,
        ),
      ),
    );

    expect(find.text('本章还没选择世界观资料。'), findsOneWidget);
  });

  testWidgets(
    'shows resource panel missing world state when reference is lost',
    (tester) async {
      await tester.pumpWidget(
        const NovelWriterApp(
          home: WorkbenchShellPage(
            uiState: WorkbenchUiState.missingWorldReference,
          ),
        ),
      );

      await tester.tap(find.byKey(WorkbenchShellPage.resourcesToolButtonKey));
      await tester.pump();

      expect(find.text('世界观资料需要重新确认'), findsOneWidget);
    },
  );

  testWidgets('shows the no-simulation-yet notice', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: WorkbenchShellPage(uiState: WorkbenchUiState.noSimulationYet),
      ),
    );

    // AI config is now valid (pre-populated settings), so noSimulationYet banner shows.
    expect(find.text('还没有 AI 试写记录。'), findsOneWidget);
  });

  testWidgets('starts a local simulation from the default workbench flow', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    expect(find.text('还没有 AI 试写记录。'), findsNothing);
    expect(find.text('还没有 AI 试写记录'), findsWidgets);

    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.runSimulationButtonKey),
    );
    await startWorkbenchSimulation(tester);

    expect(find.text('AI 正在写本章'), findsWidgets);
    expect(find.text('查看生成过程'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();

    expect(find.text('AI 试写完成'), findsWidgets);
    expect(find.text('查看生成过程'), findsOneWidget);
  });

  testWidgets('shows story generation run snapshot in the workbench actions', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    expect(find.byKey(WorkbenchShellPage.runSnapshotPanelKey), findsOneWidget);
    expect(find.text('还没有 AI 试写记录'), findsWidgets);
    expect(find.text('未开始'), findsOneWidget);

    await startWorkbenchSimulation(tester);
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('AI 试写完成'), findsWidgets);
    expect(find.textContaining('写作任务：'), findsOneWidget);
    expect(find.textContaining('审查结果：'), findsOneWidget);
    final runButton = tester.widget<FilledButton>(
      find.byKey(WorkbenchShellPage.runSimulationButtonKey),
    );
    expect(runButton.onPressed, isNotNull);
  });

  testWidgets('can stop an active story generation run from the workbench', (
    tester,
  ) async {
    _ControlledStoryRunOrchestrator? orchestrator;
    StoryGenerationRunStore.debugOrchestratorFactoryOverride =
        (settingsStore) => orchestrator = _ControlledStoryRunOrchestrator(
          settingsStore: settingsStore,
        );

    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    await startWorkbenchSimulation(tester);
    await orchestrator!.started.future;

    final cancelButton = find.byKey(WorkbenchShellPage.cancelRunButtonKey);
    expect(cancelButton, findsOneWidget);
    await tester.ensureVisible(cancelButton);
    await tester.pump();
    await tester.tap(cancelButton);
    await tester.pump();

    expect(find.text('AI 试写已取消'), findsOneWidget);
    expect(find.text('已取消'), findsOneWidget);
    expect(find.byKey(WorkbenchShellPage.cancelRunButtonKey), findsNothing);
    final runButton = tester.widget<FilledButton>(
      find.byKey(WorkbenchShellPage.runSimulationButtonKey),
    );
    expect(runButton.onPressed, isNotNull);

    orchestrator!.release.complete();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump();
    expect(find.text('AI 试写已取消'), findsOneWidget);
  });

  testWidgets('opens sandbox monitor after simulation starts', (tester) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    await startWorkbenchSimulation(tester);

    await openWorkbenchSimulationProcess(tester);

    expect(find.text('AI 生成过程'), findsOneWidget);
    expect(find.text('参与角色'), findsOneWidget);
    expect(find.text('生成记录'), findsOneWidget);
  });

  testWidgets('starts a local failure path from the default workbench flow', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    await startWorkbenchSimulation(tester, forceFailure: true);

    expect(find.text('AI 正在写本章'), findsWidgets);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(find.text('AI 试写未完成，正文保持原样。'), findsOneWidget);
    expect(find.text('AI 试写失败'), findsWidgets);
  });

  testWidgets('retains edited draft text inside the workbench', (tester) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    await tester.enterText(
      find.byKey(WorkbenchShellPage.editorTextFieldKey),
      '新的草稿内容',
    );
    await tester.pump();

    await tester.tap(find.byKey(WorkbenchShellPage.resourcesToolButtonKey));
    await tester.pump();
    await tester.tap(find.byKey(WorkbenchShellPage.resourcesToolButtonKey));
    await tester.pump();

    expect(find.text('新的草稿内容'), findsOneWidget);
  });

  testWidgets('opens chapter versions with the latest saved draft snapshot', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    await tester.enterText(
      find.byKey(WorkbenchShellPage.editorTextFieldKey),
      '新的版本内容',
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.saveVersionButtonKey),
    );
    await tester.tap(find.byKey(WorkbenchShellPage.saveVersionButtonKey));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.openVersionsButtonKey),
    );
    await tester.tap(find.byKey(WorkbenchShellPage.openVersionsButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('章节版本'), findsOneWidget);
    expect(find.byKey(VersionHistoryPage.versionListKey), findsOneWidget);
    expect(find.text('版本信息'), findsOneWidget);
    expect(find.text('版本池'), findsOneWidget);
    expect(find.text('手动保存'), findsOneWidget);
    expect(find.text('来源'), findsOneWidget);
    expect(find.text('新的版本内容'), findsWidgets);
  });

  testWidgets('draft and versions persist after rebuilding the app shell', (
    tester,
  ) async {
    final draftStorage = InMemoryAppDraftStorage();
    final versionStorage = InMemoryAppVersionStorage();
    AppDraftStore.debugStorageOverride = draftStorage;
    AppVersionStore.debugStorageOverride = versionStorage;

    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    await tester.enterText(
      find.byKey(WorkbenchShellPage.editorTextFieldKey),
      '跨重启保留的草稿内容',
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.saveVersionButtonKey),
    );
    await tester.tap(find.byKey(WorkbenchShellPage.saveVersionButtonKey));
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));
    await tester.pump();

    expect(find.text('跨重启保留的草稿内容'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.openVersionsButtonKey),
    );
    await tester.tap(find.byKey(WorkbenchShellPage.openVersionsButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('手动保存'), findsOneWidget);
    expect(find.text('来源：手动保存'), findsOneWidget);
  });

  testWidgets('restores an older draft version back into the workbench', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    await tester.enterText(
      find.byKey(WorkbenchShellPage.editorTextFieldKey),
      '新的版本内容',
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.saveVersionButtonKey),
    );
    await tester.tap(find.byKey(WorkbenchShellPage.saveVersionButtonKey));
    await tester.pump();

    await tester.enterText(
      find.byKey(WorkbenchShellPage.editorTextFieldKey),
      '另一个当前草稿',
    );
    await tester.pump();

    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.openVersionsButtonKey),
    );
    await tester.tap(find.byKey(WorkbenchShellPage.openVersionsButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('初始版本'));
    await tester.pump();
    await tester.tap(find.text('恢复此版本'));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('她推开仓库门，雨水顺着袖口滴进掌心，远处码头的雾灯像一根迟疑的针。'), findsOneWidget);
  });

  testWidgets('shows the context synced notice', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: WorkbenchShellPage(uiState: WorkbenchUiState.contextSynced),
      ),
    );

    expect(find.text('当前章节资料已刷新。'), findsOneWidget);
  });

  testWidgets('shows the simulation completed notice', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: WorkbenchShellPage(uiState: WorkbenchUiState.simulationCompleted),
      ),
    );

    expect(find.text('AI 试写完成'), findsWidgets);
    expect(find.text('查看生成过程'), findsOneWidget);
  });

  testWidgets('shows the simulation failed summary notice', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: WorkbenchShellPage(
          uiState: WorkbenchUiState.simulationFailedSummary,
        ),
      ),
    );

    expect(find.text('AI 试写未完成，正文保持原样。'), findsOneWidget);
    expect(find.text('查看原因'), findsOneWidget);
  });

  testWidgets('opens the resources tool window from the tool rail', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    expect(find.byKey(WorkbenchShellPage.toolWindowKey), findsNothing);

    await tester.tap(find.byKey(WorkbenchShellPage.resourcesToolButtonKey));
    await tester.pump();

    expect(find.byKey(WorkbenchShellPage.toolWindowKey), findsOneWidget);
    expect(find.text('章节资料'), findsOneWidget);
    expect(find.text('当前章节：第 3 章 · 证人房间对峙 · 等待同步'), findsOneWidget);
    expect(find.text('角色摘要：柳溪 · 调查记者'), findsOneWidget);
    expect(find.text('世界观摘要：旧港规则 · 规则'), findsOneWidget);
  });

  testWidgets('syncs resource context back into the workbench', (tester) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    await tester.tap(find.byKey(WorkbenchShellPage.resourcesToolButtonKey));
    await tester.pump();
    await tester.tap(find.text('刷新当前章节资料'));
    await tester.pump();

    expect(find.text('当前章节资料已刷新。'), findsOneWidget);
    expect(find.text('当前章节：第 3 章 · 证人房间对峙'), findsOneWidget);
    expect(find.text('角色摘要：柳溪 · 已重新同步'), findsOneWidget);
    expect(find.text('世界观摘要：旧港规则 · 已刷新'), findsOneWidget);
  });

  testWidgets('switching scenes from the resource panel updates breadcrumb', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    await tester.tap(find.byKey(WorkbenchShellPage.resourcesToolButtonKey));
    await tester.pump();
    await tester.tap(find.text('雨夜码头'));
    await tester.pump();

    expect(find.text('月潮回声 / 第 3 章 · 雨夜码头'), findsWidgets);
    expect(find.text('当前章节：第 3 章 · 雨夜码头 · 等待同步'), findsOneWidget);
  });

  testWidgets('creates a new scene from the resource panel', (tester) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    await tester.tap(find.byKey(WorkbenchShellPage.resourcesToolButtonKey));
    await tester.pump();
    await tester.tap(find.byKey(WorkbenchShellPage.createSceneButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('创建后会出现在当前项目的章节列表中，并立即可在工作台中继续写作。'), findsOneWidget);

    await tester.enterText(
      find.byKey(WorkbenchShellPage.sceneTitleFieldKey),
      '阳台争执',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('阳台争执'), findsWidgets);
    expect(find.text('月潮回声 / 第 4 章 · 阳台争执'), findsWidgets);
  });

  testWidgets('renames the current scene from the resource panel', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    await tester.tap(find.byKey(WorkbenchShellPage.resourcesToolButtonKey));
    await tester.pump();
    await tester.tap(find.byKey(WorkbenchShellPage.renameSceneButtonKey));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(WorkbenchShellPage.sceneTitleFieldKey),
      '证人房间加压',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('证人房间加压'), findsWidgets);
    expect(find.text('月潮回声 / 第 3 章 · 证人房间加压'), findsWidgets);
  });

  testWidgets('deletes the current scene from the resource panel', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    await tester.tap(find.byKey(WorkbenchShellPage.resourcesToolButtonKey));
    await tester.pump();
    await tester.tap(find.byKey(WorkbenchShellPage.deleteSceneButtonKey));
    await tester.pumpAndSettle();

    expect(
      find.text('删除后会从当前项目的章节列表中移除，工作台会自动切换到相邻章节，并同步刷新相关引用摘要。'),
      findsOneWidget,
    );

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(find.text('证人房间对峙'), findsNothing);
    expect(find.text('月潮回声 / 第 3 章 · 雨夜码头'), findsWidgets);
  });

  testWidgets('switches between tool window tabs from the tool rail', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    await tester.tap(find.byKey(WorkbenchShellPage.resourcesToolButtonKey));
    await tester.pump();
    expect(find.text('章节资料'), findsOneWidget);

    await tester.tap(find.byKey(WorkbenchShellPage.aiToolButtonKey));
    await tester.pump();
    expect(find.text('AI 写作助手'), findsOneWidget);
    expect(find.text('选择写作动作、查看历史记录，并告诉 AI 你想怎么改。'), findsOneWidget);

    await tester.tap(find.byKey(WorkbenchShellPage.settingsToolButtonKey));
    await tester.pump();
    expect(find.text('设置快捷面板'), findsOneWidget);
    expect(find.text('当前模型服务、模型、界面模式和快速入口会显示在这里。'), findsOneWidget);
  });

  testWidgets('shows AI panel unconfigured guidance before provider setup', (
    tester,
  ) async {
    AppSettingsStore.debugStorageOverride = InMemoryAppSettingsStorage();

    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    await tester.tap(find.byKey(WorkbenchShellPage.aiToolButtonKey));
    await tester.pump();

    expect(find.text('AI 暂不可用'), findsOneWidget);
    expect(find.text('需要生成候选稿时，再到设置连接模型服务。'), findsOneWidget);
  });

  testWidgets('surfaces secure store read failures in the AI panel', (
    tester,
  ) async {
    AppSettingsStore.debugStorageOverride = ReadFailureWarningStorage();

    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(WorkbenchShellPage.aiToolButtonKey));
    await tester.pump();

    expect(find.text('AI 配置异常'), findsOneWidget);
    expect(find.text('检查设置'), findsOneWidget);
    expect(find.textContaining('无法读取本地配置文件'), findsWidgets);
  });

  testWidgets('AI panel can retry secure store access from the warning state', (
    tester,
  ) async {
    AppSettingsStore.debugStorageOverride = RecoveringReadStorage();

    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(WorkbenchShellPage.aiToolButtonKey));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiRetrySecureStoreButtonKey),
    );
    await tester.tap(
      find.byKey(WorkbenchShellPage.aiRetrySecureStoreButtonKey),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI 配置异常'), findsNothing);
    expect(find.text('AI 已就绪'), findsOneWidget);
    expect(find.text('当前模型：glm-4'), findsOneWidget);
  });

  testWidgets('AI panel can retry secure store access after a write failure', (
    tester,
  ) async {
    AppSettingsStore.debugStorageOverride = RecoveringWriteStorage();

    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    await tester.tap(find.byKey(WorkbenchShellPage.settingsToolButtonKey));
    await tester.pump();
    await tester.tap(find.text('打开完整设置'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(SettingsShellPage.apiKeyFieldKey),
      'sk-test-key',
    );
    await tester.tap(find.byKey(SettingsShellPage.saveButtonKey));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(WorkbenchShellPage.aiToolButtonKey));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiRetrySecureStoreButtonKey),
    );

    expect(
      find.byKey(WorkbenchShellPage.aiRetrySecureStoreButtonKey),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(WorkbenchShellPage.aiRetrySecureStoreButtonKey),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(WorkbenchShellPage.aiRetrySecureStoreButtonKey),
      findsNothing,
    );
    expect(find.text('AI 已就绪'), findsOneWidget);
    expect(find.text('当前模型：gpt-4.1-mini'), findsOneWidget);
  });

  testWidgets(
    'AI panel can copy diagnostic details from a persistence warning',
    (tester) async {
      AppSettingsStore.debugStorageOverride = ReadFailureWarningStorage();
      final clipboard = ClipboardSpy(tester)..attach();
      addTearDown(() {
        clipboard.detach();
      });

      await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(WorkbenchShellPage.aiToolButtonKey));
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(WorkbenchShellPage.aiCopyDiagnosticButtonKey),
      );
      await tester.tap(
        find.byKey(WorkbenchShellPage.aiCopyDiagnosticButtonKey),
      );
      await tester.pump();

      expect(clipboard.text, contains('类别：settings_file_read_failed'));
      expect(clipboard.text, contains('诊断：settings.json is unreadable'));
      expect(find.text('诊断已复制'), findsOneWidget);
    },
  );

  testWidgets('AI panel can copy diagnostic details after a write failure', (
    tester,
  ) async {
    AppSettingsStore.debugStorageOverride = FailingSecureSettingsStorage();
    final clipboard = ClipboardSpy(tester)..attach();
    addTearDown(() {
      clipboard.detach();
    });

    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    await tester.tap(find.byKey(WorkbenchShellPage.settingsToolButtonKey));
    await tester.pump();
    await tester.tap(find.text('打开完整设置'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(SettingsShellPage.apiKeyFieldKey),
      'sk-warning-key',
    );
    await tester.tap(find.byKey(SettingsShellPage.saveButtonKey));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(WorkbenchShellPage.aiToolButtonKey));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiCopyDiagnosticButtonKey),
    );
    await tester.tap(find.byKey(WorkbenchShellPage.aiCopyDiagnosticButtonKey));
    await tester.pump();

    expect(clipboard.text, contains('类别：settings_file_write_failed'));
    expect(clipboard.text, contains('诊断：settings.json write denied'));
    expect(find.text('诊断已复制'), findsOneWidget);
  });

  testWidgets('opens the full settings page from the settings quick panel', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    await tester.tap(find.byKey(WorkbenchShellPage.settingsToolButtonKey));
    await tester.pump();
    await tester.tap(find.text('打开完整设置'));
    await tester.pumpAndSettle();

    expect(find.byKey(SettingsShellPage.providerConfigKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(SettingsShellPage.providerConfigKey),
        matching: find.text('设置'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('navigates to the settings page from the API key notice', (
    tester,
  ) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: WorkbenchShellPage(uiState: WorkbenchUiState.apiKeyMissing),
      ),
    );

    await tester.tap(find.text('前往设置'));
    await tester.pumpAndSettle();

    expect(find.byKey(SettingsShellPage.providerConfigKey), findsOneWidget);
    expect(find.text('模型连接'), findsOneWidget);
  });

  testWidgets('navigates to reading mode from the tool rail', (tester) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    await tester.tap(find.byKey(WorkbenchShellPage.readingToolButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('月潮回声 · 第 3 章 · 证人房间对峙'), findsOneWidget);
    expect(find.byKey(ReadingModePage.pageBodyKey), findsOneWidget);
    expect(find.text('返回写作'), findsOneWidget);
  });

  testWidgets('returns to the workbench from reading mode', (tester) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    await tester.tap(find.byKey(WorkbenchShellPage.readingToolButtonKey));
    await tester.pumpAndSettle();
    expect(find.text('月潮回声 · 第 3 章 · 证人房间对峙'), findsOneWidget);

    await tester.tap(find.text('返回写作'));
    await tester.pumpAndSettle();

    expect(find.text('月潮回声 · 第 3 章 · 证人房间对峙'), findsNothing);
    expect(find.byKey(WorkbenchShellPage.editorPaneKey), findsOneWidget);
  });

  testWidgets('shows the current draft text in reading mode', (tester) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    await tester.enterText(
      find.byKey(WorkbenchShellPage.editorTextFieldKey),
      '新的草稿内容',
    );
    await tester.pump();

    await tester.tap(find.byKey(WorkbenchShellPage.readingToolButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('新的草稿内容'), findsOneWidget);
  });

  testWidgets(
    'supports keyboard paging and chapter boundary hints in reading mode',
    (tester) async {
      final longChapter = '甲' * 500;
      await tester.pumpWidget(
        NovelWriterApp(
          home: ReadingModePage(
            session: ReadingSessionData(
              projectTitle: '月潮回声',
              initialSceneId: 'scene-01',
              documents: [
                ReadingSceneDocument(
                  sceneId: 'scene-01',
                  locationLabel: '第 1 章 · 风暴前夜',
                  text: longChapter,
                ),
                const ReadingSceneDocument(
                  sceneId: 'scene-02',
                  locationLabel: '第 2 章 · 码头回响',
                  text: '乙乙乙乙乙乙乙乙乙乙乙乙乙乙乙乙乙乙乙乙',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('第 1 / 3 页'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('第 2 / 3 页'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('第 3 / 3 页'), findsOneWidget);
      expect(find.text('章节边界'), findsOneWidget);
      expect(find.text('当前为本章最后一页。继续向右翻页时，将进入下一章第一页。'), findsOneWidget);
      expect(find.byTooltip('下一章'), findsOneWidget);
      expect(find.text('当前已在终章最后一页。'), findsNothing);
      expect(find.text('再翻一页进入下一章第一页'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('月潮回声 · 第 2 章 · 码头回响'), findsOneWidget);
      expect(find.text('单页'), findsOneWidget);
      expect(find.text('单页阅读'), findsOneWidget);
      expect(find.text('当前章节内容较短或无需拆分页，因此以整章单页方式展示。'), findsOneWidget);
      expect(find.text('单页可切换到上一章'), findsOneWidget);
    },
  );

  testWidgets('shows the single-page reading chrome for short chapters', (
    tester,
  ) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: ReadingModePage(
          session: ReadingSessionData(
            projectTitle: '月潮回声',
            initialSceneId: 'scene-01',
            documents: [
              ReadingSceneDocument(
                sceneId: 'scene-01',
                locationLabel: '第 1 章 · 风暴前夜',
                text: '短章内容',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('单页阅读'), findsOneWidget);
    expect(find.text('当前章节内容较短或无需拆分页，因此以整章单页方式展示。'), findsOneWidget);
    expect(find.text('单页'), findsOneWidget);
    expect(find.text('当前章节无法分页 · 退出后回到进入前位置'), findsOneWidget);
    expect(find.text('—'), findsNothing);
  });

  testWidgets('keeps punctuation attached to the preceding reading page', (
    tester,
  ) async {
    final firstPage = '${'甲' * 210}。';
    const secondPage = '乙乙乙乙乙乙乙乙乙乙乙乙乙乙乙乙乙乙乙乙乙乙乙乙乙乙乙乙乙乙';
    await tester.pumpWidget(
      NovelWriterApp(
        home: ReadingModePage(
          session: ReadingSessionData(
            projectTitle: '月潮回声',
            initialSceneId: 'scene-01',
            documents: [
              ReadingSceneDocument(
                sceneId: 'scene-01',
                locationLabel: '第 1 章 · 风暴前夜',
                text: '$firstPage$secondPage',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(firstPage), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(find.text(secondPage), findsOneWidget);
    expect(find.text('。$secondPage'), findsNothing);
  });

  testWidgets(
    'refreshes reading pages when content changes but length stays the same',
    (tester) async {
      await tester.pumpWidget(
        const NovelWriterApp(
          home: ReadingModePage(
            session: ReadingSessionData(
              projectTitle: '月潮回声',
              initialSceneId: 'scene-01',
              documents: [
                ReadingSceneDocument(
                  sceneId: 'scene-01',
                  locationLabel: '第 1 章 · 风暴前夜',
                  text: 'AAAAAA',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('AAAAAA'), findsOneWidget);

      await tester.pumpWidget(
        const NovelWriterApp(
          home: ReadingModePage(
            session: ReadingSessionData(
              projectTitle: '月潮回声',
              initialSceneId: 'scene-01',
              documents: [
                ReadingSceneDocument(
                  sceneId: 'scene-01',
                  locationLabel: '第 1 章 · 风暴前夜',
                  text: 'BBBBBB',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('BBBBBB'), findsOneWidget);
      expect(find.text('AAAAAA'), findsNothing);
    },
  );

  testWidgets(
    'restores editor selection and focus after leaving reading mode',
    (tester) async {
      await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

      await tester.enterText(
        find.byKey(WorkbenchShellPage.editorTextFieldKey),
        'ABCDEFGHIJKL',
      );
      await tester.pump();
      setWorkbenchEditorSelection(tester, start: 2, end: 6);
      await tester.pump();

      await tester.tap(find.byKey(WorkbenchShellPage.readingToolButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ReadingModePage.closeButtonKey));
      await tester.pumpAndSettle();

      final editorState = workbenchEditorState(tester);
      expect(
        editorState.widget.controller.selection,
        const TextSelection(baseOffset: 2, extentOffset: 6),
      );
      expect(editorState.widget.focusNode.hasFocus, isTrue);
    },
  );

  testWidgets(
    'restores editor selection and focus after returning from settings',
    (tester) async {
      await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

      await tester.enterText(
        find.byKey(WorkbenchShellPage.editorTextFieldKey),
        'ABCDEFGHIJKL',
      );
      await tester.pump();
      setWorkbenchEditorSelection(tester, start: 3, end: 8);
      await tester.pump();

      await tester.tap(find.byKey(WorkbenchShellPage.settingsToolButtonKey));
      await tester.pump();
      await tester.tap(find.text('打开完整设置'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      final editorState = workbenchEditorState(tester);
      expect(
        editorState.widget.controller.selection,
        const TextSelection(baseOffset: 3, extentOffset: 8),
      );
      expect(editorState.widget.focusNode.hasFocus, isTrue);
    },
  );

  testWidgets(
    'switching draft scope clears the previous scene selection anchor',
    (tester) async {
      await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

      await tester.enterText(
        find.byKey(WorkbenchShellPage.editorTextFieldKey),
        'ABCDEFGHIJKL',
      );
      await tester.pump();
      setWorkbenchEditorSelection(tester, start: 3, end: 8);
      await tester.pump();

      final workspaceStore = AppWorkspaceScope.of(
        tester.element(find.byType(WorkbenchShellPage)),
      );
      final nextScene = workspaceStore.scenes.firstWhere(
        (scene) => scene.id != workspaceStore.currentProject.sceneId,
      );
      workspaceStore.updateCurrentScene(
        sceneId: nextScene.id,
        recentLocation: nextScene.displayLocation,
      );
      await tester.pumpAndSettle();

      final editorState = workbenchEditorState(tester);
      expect(editorState.widget.controller.text, isNot('ABCDEFGHIJKL'));
      final expectedOffset = editorState.widget.controller.text.length;
      expect(
        editorState.widget.controller.selection,
        TextSelection.collapsed(offset: expectedOffset),
      );
    },
  );

  testWidgets(
    'switching to another untouched scene resets selection even when text matches',
    (tester) async {
      await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

      final initialText = workbenchEditorState(tester).widget.controller.text;
      setWorkbenchEditorSelection(tester, start: 1, end: 5);
      await tester.pump();

      final workspaceStore = AppWorkspaceScope.of(
        tester.element(find.byType(WorkbenchShellPage)),
      );
      final nextScene = workspaceStore.scenes.firstWhere(
        (scene) => scene.id != workspaceStore.currentProject.sceneId,
      );
      workspaceStore.updateCurrentScene(
        sceneId: nextScene.id,
        recentLocation: nextScene.displayLocation,
      );
      await tester.pumpAndSettle();

      final editorState = workbenchEditorState(tester);
      expect(editorState.widget.controller.text, initialText);
      expect(
        editorState.widget.controller.selection,
        TextSelection.collapsed(offset: initialText.length),
      );
    },
  );

  testWidgets('shows the missing API key feedback on settings save', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: SettingsShellPage()));

    await tester.tap(find.byKey(SettingsShellPage.saveButtonKey));
    await tester.pump();

    expect(find.text('请先填写密钥'), findsWidgets);
  });

  testWidgets('shows save success after entering an API key', (tester) async {
    await tester.pumpWidget(const NovelWriterApp(home: SettingsShellPage()));

    await tester.enterText(
      find.byKey(SettingsShellPage.apiKeyFieldKey),
      'sk-test-key',
    );
    await tester.tap(find.byKey(SettingsShellPage.saveButtonKey));
    await tester.pump();

    expect(find.text('保存成功'), findsWidgets);
    expect(find.text('新配置会从下一次 AI 请求开始生效。'), findsWidgets);
  });

  testWidgets('shows invalid interface address feedback on save', (
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

    expect(find.text('请输入有效的接口地址'), findsWidgets);
  });

  testWidgets(
    'validation errors do not promote the AI panel into a secure store warning',
    (tester) async {
      await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

      await tester.tap(find.byKey(WorkbenchShellPage.settingsToolButtonKey));
      await tester.pump();
      await tester.tap(find.text('打开完整设置'));
      await tester.pumpAndSettle();

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
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(WorkbenchShellPage.aiToolButtonKey));
      await tester.pump();

      expect(find.text('AI 配置异常'), findsNothing);
      expect(find.text('检查设置'), findsNothing);
      expect(find.text('AI 已就绪'), findsOneWidget);
    },
  );

  testWidgets('shows missing model feedback on save', (tester) async {
    await tester.pumpWidget(const NovelWriterApp(home: SettingsShellPage()));

    await tester.enterText(find.byKey(SettingsShellPage.modelFieldKey), '');
    await tester.enterText(
      find.byKey(SettingsShellPage.apiKeyFieldKey),
      'sk-test-key',
    );
    await tester.tap(find.byKey(SettingsShellPage.saveButtonKey));
    await tester.pump();

    expect(find.text('请先填写模型名称'), findsWidgets);
  });

  testWidgets(
    'shows connection test success when required fields are present',
    (tester) async {
      await tester.pumpWidget(const NovelWriterApp(home: SettingsShellPage()));

      await tester.enterText(
        find.byKey(SettingsShellPage.apiKeyFieldKey),
        'sk-test-key',
      );
      await tester.pump();
      await tester.tap(find.byKey(SettingsShellPage.testConnectionButtonKey));
      await tester.pumpAndSettle();

      expect(find.text('连接测试成功'), findsWidgets);
      expect(find.text('gpt-4.1-mini · 182ms'), findsWidgets);
    },
  );

  testWidgets('updates the settings quick panel after saving settings', (
    tester,
  ) async {
    AppSettingsStore.debugStorageOverride = InMemoryAppSettingsStorage();

    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    await tester.tap(find.byKey(WorkbenchShellPage.settingsToolButtonKey));
    await tester.pump();
    expect(find.text('未连接模型服务'), findsOneWidget);

    await tester.tap(find.text('打开完整设置'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(SettingsShellPage.apiKeyFieldKey),
      'sk-test-key',
    );
    await tester.tap(find.byKey(SettingsShellPage.saveButtonKey));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(WorkbenchShellPage.settingsToolButtonKey));
    await tester.pump();

    expect(find.text('模型服务已连接'), findsOneWidget);
    expect(find.text('OpenAI 兼容服务 · gpt-4.1-mini'), findsOneWidget);
  });

  testWidgets(
    'surfaces secure store read failures in the settings quick panel',
    (tester) async {
      AppSettingsStore.debugStorageOverride = ReadFailureWarningStorage();

      await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(WorkbenchShellPage.settingsToolButtonKey));
      await tester.pump();

      expect(find.text('设置文件读取失败'), findsWidgets);
      expect(find.textContaining('无法读取本地配置文件'), findsWidgets);
    },
  );

  testWidgets(
    'settings quick panel can copy diagnostic details from a persistence warning',
    (tester) async {
      AppSettingsStore.debugStorageOverride = ReadFailureWarningStorage();
      final clipboard = ClipboardSpy(tester)..attach();
      addTearDown(() {
        clipboard.detach();
      });

      await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(WorkbenchShellPage.settingsToolButtonKey));
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(WorkbenchShellPage.settingsCopyDiagnosticButtonKey),
      );
      await tester.tap(
        find.byKey(WorkbenchShellPage.settingsCopyDiagnosticButtonKey),
      );
      await tester.pump();

      expect(clipboard.text, contains('类别：settings_file_read_failed'));
      expect(clipboard.text, contains('诊断：settings.json is unreadable'));
      expect(find.text('诊断已复制'), findsOneWidget);
    },
  );

  testWidgets(
    'settings quick panel can copy diagnostic details after a write failure',
    (tester) async {
      AppSettingsStore.debugStorageOverride = FailingSecureSettingsStorage();
      final clipboard = ClipboardSpy(tester)..attach();
      addTearDown(() {
        clipboard.detach();
      });

      await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

      await tester.tap(find.byKey(WorkbenchShellPage.settingsToolButtonKey));
      await tester.pump();
      await tester.tap(find.text('打开完整设置'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(SettingsShellPage.apiKeyFieldKey),
        'sk-warning-key',
      );
      await tester.tap(find.byKey(SettingsShellPage.saveButtonKey));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(WorkbenchShellPage.settingsToolButtonKey));
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(WorkbenchShellPage.settingsCopyDiagnosticButtonKey),
      );
      await tester.tap(
        find.byKey(WorkbenchShellPage.settingsCopyDiagnosticButtonKey),
      );
      await tester.pump();

      expect(clipboard.text, contains('类别：settings_file_write_failed'));
      expect(clipboard.text, contains('诊断：settings.json write denied'));
      expect(find.text('诊断已复制'), findsOneWidget);
    },
  );

  testWidgets(
    'settings quick panel can retry secure store access from the warning state',
    (tester) async {
      AppSettingsStore.debugStorageOverride = RecoveringReadStorage();

      await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(WorkbenchShellPage.settingsToolButtonKey));
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(WorkbenchShellPage.settingsRetrySecureStoreButtonKey),
      );
      await tester.tap(
        find.byKey(WorkbenchShellPage.settingsRetrySecureStoreButtonKey),
      );
      await tester.pumpAndSettle();

      expect(find.text('设置文件读取失败'), findsNothing);
      expect(find.text('模型服务已连接'), findsOneWidget);
      expect(find.text('智谱 GLM · glm-4'), findsOneWidget);
    },
  );

  testWidgets(
    'settings quick panel can retry secure store access after a write failure',
    (tester) async {
      AppSettingsStore.debugStorageOverride = RecoveringWriteStorage();

      await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

      await tester.tap(find.byKey(WorkbenchShellPage.settingsToolButtonKey));
      await tester.pump();
      await tester.tap(find.text('打开完整设置'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(SettingsShellPage.apiKeyFieldKey),
        'sk-test-key',
      );
      await tester.tap(find.byKey(SettingsShellPage.saveButtonKey));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(WorkbenchShellPage.settingsToolButtonKey));
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(WorkbenchShellPage.settingsRetrySecureStoreButtonKey),
      );

      expect(
        find.byKey(WorkbenchShellPage.settingsRetrySecureStoreButtonKey),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(WorkbenchShellPage.settingsRetrySecureStoreButtonKey),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(WorkbenchShellPage.settingsRetrySecureStoreButtonKey),
        findsNothing,
      );
      expect(find.text('模型服务已连接'), findsOneWidget);
      expect(find.text('OpenAI 兼容服务 · gpt-4.1-mini'), findsOneWidget);
    },
  );

  testWidgets('shows AI model summary after provider setup', (tester) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    await tester.tap(find.byKey(WorkbenchShellPage.settingsToolButtonKey));
    await tester.pump();
    await tester.tap(find.text('打开完整设置'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(SettingsShellPage.apiKeyFieldKey),
      'sk-test-key',
    );
    await tester.tap(find.byKey(SettingsShellPage.saveButtonKey));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(WorkbenchShellPage.aiToolButtonKey));
    await tester.pump();

    expect(find.text('AI 已就绪'), findsOneWidget);
    expect(find.text('当前模型：gpt-4.1-mini'), findsOneWidget);
    expect(find.text('当前模式：改写'), findsOneWidget);
    expect(find.text('历史区'), findsOneWidget);
    expect(find.text('暂无 AI 历史'), findsOneWidget);
  });

  testWidgets('switches AI tool mode and records it in history', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    await tester.tap(find.byKey(WorkbenchShellPage.settingsToolButtonKey));
    await tester.pump();
    await tester.tap(find.text('打开完整设置'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(SettingsShellPage.apiKeyFieldKey),
      'sk-test-key',
    );
    await tester.tap(find.byKey(SettingsShellPage.saveButtonKey));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(WorkbenchShellPage.aiToolButtonKey));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiContinueModeButtonKey),
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiContinueModeButtonKey),
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiContinueModeButtonKey),
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiContinueModeButtonKey),
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiContinueModeButtonKey),
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiContinueModeButtonKey),
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiContinueModeButtonKey),
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiContinueModeButtonKey),
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiContinueModeButtonKey),
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiContinueModeButtonKey),
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiContinueModeButtonKey),
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiContinueModeButtonKey),
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiContinueModeButtonKey),
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiContinueModeButtonKey),
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiContinueModeButtonKey),
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiContinueModeButtonKey),
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiContinueModeButtonKey),
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiContinueModeButtonKey),
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiContinueModeButtonKey),
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiContinueModeButtonKey),
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiContinueModeButtonKey),
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiContinueModeButtonKey),
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiContinueModeButtonKey),
    );
    await tester.tap(find.byKey(WorkbenchShellPage.aiContinueModeButtonKey));
    await tester.pump();

    expect(find.text('当前模式：续写'), findsOneWidget);
    expect(find.text('生成续写建议'), findsOneWidget);
    expect(find.text('输入续写意图，例如：补一段'), findsOneWidget);

    await tester.enterText(
      find.byKey(WorkbenchShellPage.aiPromptFieldKey),
      '补一段',
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiGenerateButtonKey),
    );
    await tester.tap(find.byKey(WorkbenchShellPage.aiGenerateButtonKey));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('拒绝变更'));
    await tester.tap(find.text('拒绝变更'));
    await tester.pumpAndSettle();

    expect(find.text('续写 · 补一段'), findsOneWidget);
  });

  testWidgets('uses the AI prompt text when generating suggestions', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    await tester.tap(find.byKey(WorkbenchShellPage.settingsToolButtonKey));
    await tester.pump();
    await tester.tap(find.text('打开完整设置'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(SettingsShellPage.apiKeyFieldKey),
      'sk-test-key',
    );
    await tester.tap(find.byKey(SettingsShellPage.saveButtonKey));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(WorkbenchShellPage.aiToolButtonKey));
    await tester.pump();
    await tester.enterText(
      find.byKey(WorkbenchShellPage.aiPromptFieldKey),
      '压缩节奏',
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiGenerateButtonKey),
    );
    await tester.tap(find.byKey(WorkbenchShellPage.aiGenerateButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('压缩节奏'), findsWidgets);
    expect(find.text('改写 · 压缩节奏'), findsOneWidget);
    expect(find.text('第1次 · 刚刚生成'), findsOneWidget);
  });

  testWidgets('includes bound style metadata in the AI review dialog', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));
    await configureWorkbenchAi(tester);

    await tester.tap(find.byKey(WorkbenchShellPage.aiToolButtonKey));
    await tester.pump();
    await tester.enterText(
      find.byKey(WorkbenchShellPage.aiPromptFieldKey),
      '压缩节奏',
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiGenerateButtonKey),
    );
    await tester.tap(find.byKey(WorkbenchShellPage.aiGenerateButtonKey));
    await tester.pumpAndSettle();

    expect(find.textContaining('风格约束：'), findsOneWidget);
    expect(find.textContaining('冷峻悬疑第一人称 · 1x'), findsOneWidget);
  });

  testWidgets(
    'saving settings updates the config used by the next manual AI request without auto-retrying older requests',
    (tester) async {
      await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

      await configureWorkbenchAi(tester);

      await tester.tap(find.byKey(WorkbenchShellPage.aiToolButtonKey));
      await tester.pump();
      await tester.enterText(
        find.byKey(WorkbenchShellPage.aiPromptFieldKey),
        '压缩节奏',
      );
      await tester.ensureVisible(
        find.byKey(WorkbenchShellPage.aiGenerateButtonKey),
      );
      await tester.tap(find.byKey(WorkbenchShellPage.aiGenerateButtonKey));
      await tester.pumpAndSettle();

      expect(find.text('请求配置：OpenAI 兼容服务 · gpt-4.1-mini'), findsOneWidget);
      expect(find.text('接口：api.example.com'), findsOneWidget);

      await tester.ensureVisible(find.text('拒绝变更'));
      await tester.tap(find.text('拒绝变更'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(WorkbenchShellPage.settingsToolButtonKey));
      await tester.pump();
      await tester.tap(find.text('打开完整设置'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(SettingsShellPage.baseUrlFieldKey),
        'https://api.openai.local/v1',
      );
      await tester.enterText(
        find.byKey(SettingsShellPage.modelFieldKey),
        'gpt-5.4',
      );
      await tester.enterText(
        find.byKey(SettingsShellPage.apiKeyFieldKey),
        'sk-next-key',
      );
      await tester.tap(find.byKey(SettingsShellPage.saveButtonKey));
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(WorkbenchShellPage.aiToolButtonKey));
      await tester.pump();

      expect(find.text('第2次 · 刚刚生成'), findsNothing);

      await tester.enterText(
        find.byKey(WorkbenchShellPage.aiPromptFieldKey),
        '补强对峙',
      );
      await tester.ensureVisible(
        find.byKey(WorkbenchShellPage.aiGenerateButtonKey),
      );
      await tester.tap(find.byKey(WorkbenchShellPage.aiGenerateButtonKey));
      await tester.pumpAndSettle();

      expect(find.text('请求配置：OpenAI 兼容服务 · gpt-5.4'), findsOneWidget);
      expect(find.text('接口：api.openai.local'), findsOneWidget);
      expect(find.text('第2次 · 刚刚生成'), findsOneWidget);
    },
  );

  testWidgets('clears the current AI prompt input', (tester) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    await tester.tap(find.byKey(WorkbenchShellPage.settingsToolButtonKey));
    await tester.pump();
    await tester.tap(find.text('打开完整设置'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(SettingsShellPage.apiKeyFieldKey),
      'sk-test-key',
    );
    await tester.tap(find.byKey(SettingsShellPage.saveButtonKey));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(WorkbenchShellPage.aiToolButtonKey));
    await tester.pump();
    await tester.enterText(
      find.byKey(WorkbenchShellPage.aiPromptFieldKey),
      '压缩节奏',
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiClearPromptButtonKey),
    );
    await tester.pump();
    await tester.tap(find.byKey(WorkbenchShellPage.aiClearPromptButtonKey));
    await tester.pump();

    final field = tester.widget<TextField>(
      find.byKey(WorkbenchShellPage.aiPromptFieldKey),
    );
    expect(field.controller?.text, '');
  });

  testWidgets('orders AI history entries with the newest first', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    await tester.tap(find.byKey(WorkbenchShellPage.settingsToolButtonKey));
    await tester.pump();
    await tester.tap(find.text('打开完整设置'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(SettingsShellPage.apiKeyFieldKey),
      'sk-test-key',
    );
    await tester.tap(find.byKey(SettingsShellPage.saveButtonKey));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(WorkbenchShellPage.aiToolButtonKey));
    await tester.pump();
    await tester.enterText(
      find.byKey(WorkbenchShellPage.aiPromptFieldKey),
      '压缩节奏',
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiGenerateButtonKey),
    );
    await tester.tap(find.byKey(WorkbenchShellPage.aiGenerateButtonKey));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('拒绝变更'));
    await tester.tap(find.text('拒绝变更'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiContinueModeButtonKey),
    );
    await tester.tap(find.byKey(WorkbenchShellPage.aiContinueModeButtonKey));
    await tester.pump();
    await tester.enterText(
      find.byKey(WorkbenchShellPage.aiPromptFieldKey),
      '补一段',
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiGenerateButtonKey),
    );
    await tester.tap(find.byKey(WorkbenchShellPage.aiGenerateButtonKey));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('拒绝变更'));
    await tester.tap(find.text('拒绝变更'));
    await tester.pumpAndSettle();

    final second = tester.getTopLeft(find.text('第2次 · 刚刚生成')).dy;
    final first = tester.getTopLeft(find.text('第1次 · 较早记录')).dy;
    expect(second, lessThan(first));
  });

  testWidgets('clears AI history back to the empty state', (tester) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    await tester.tap(find.byKey(WorkbenchShellPage.settingsToolButtonKey));
    await tester.pump();
    await tester.tap(find.text('打开完整设置'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(SettingsShellPage.apiKeyFieldKey),
      'sk-test-key',
    );
    await tester.tap(find.byKey(SettingsShellPage.saveButtonKey));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(WorkbenchShellPage.aiToolButtonKey));
    await tester.pump();
    await tester.enterText(
      find.byKey(WorkbenchShellPage.aiPromptFieldKey),
      '压缩节奏',
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiGenerateButtonKey),
    );
    await tester.tap(find.byKey(WorkbenchShellPage.aiGenerateButtonKey));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('拒绝变更'));
    await tester.tap(find.text('拒绝变更'));
    await tester.pumpAndSettle();

    expect(find.text('改写 · 压缩节奏'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiClearHistoryButtonKey),
    );
    await tester.tap(find.byKey(WorkbenchShellPage.aiClearHistoryButtonKey));
    await tester.pump();

    expect(find.text('暂无 AI 历史'), findsOneWidget);
    expect(find.text('改写 · 压缩节奏'), findsNothing);
  });

  testWidgets('removes a single AI history entry', (tester) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    await tester.tap(find.byKey(WorkbenchShellPage.settingsToolButtonKey));
    await tester.pump();
    await tester.tap(find.text('打开完整设置'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(SettingsShellPage.apiKeyFieldKey),
      'sk-test-key',
    );
    await tester.tap(find.byKey(SettingsShellPage.saveButtonKey));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(WorkbenchShellPage.aiToolButtonKey));
    await tester.pump();
    await tester.enterText(
      find.byKey(WorkbenchShellPage.aiPromptFieldKey),
      '压缩节奏',
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiGenerateButtonKey),
    );
    await tester.tap(find.byKey(WorkbenchShellPage.aiGenerateButtonKey));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('拒绝变更'));
    await tester.tap(find.text('拒绝变更'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(WorkbenchShellPage.aiContinueModeButtonKey));
    await tester.pump();
    await tester.enterText(
      find.byKey(WorkbenchShellPage.aiPromptFieldKey),
      '补一段',
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiGenerateButtonKey),
    );
    await tester.tap(find.byKey(WorkbenchShellPage.aiGenerateButtonKey));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('拒绝变更'));
    await tester.tap(find.text('拒绝变更'));
    await tester.pumpAndSettle();

    expect(find.text('续写 · 补一段'), findsOneWidget);
    expect(find.text('改写 · 压缩节奏'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiHistoryDeleteButtonKey(2)),
    );
    await tester.tap(
      find.byKey(WorkbenchShellPage.aiHistoryDeleteButtonKey(2)),
    );
    await tester.pump();

    expect(find.text('续写 · 补一段'), findsNothing);
    expect(find.text('改写 · 压缩节奏'), findsOneWidget);
  });

  testWidgets('restores the prompt from AI history when tapped', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    await tester.tap(find.byKey(WorkbenchShellPage.settingsToolButtonKey));
    await tester.pump();
    await tester.tap(find.text('打开完整设置'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(SettingsShellPage.apiKeyFieldKey),
      'sk-test-key',
    );
    await tester.tap(find.byKey(SettingsShellPage.saveButtonKey));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(WorkbenchShellPage.aiToolButtonKey));
    await tester.pump();
    await tester.enterText(
      find.byKey(WorkbenchShellPage.aiPromptFieldKey),
      '压缩节奏',
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiGenerateButtonKey),
    );
    await tester.tap(find.byKey(WorkbenchShellPage.aiGenerateButtonKey));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('拒绝变更'));
    await tester.tap(find.text('拒绝变更'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(WorkbenchShellPage.aiPromptFieldKey),
      '新的意图',
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiHistoryPromptKey(1)),
    );
    await tester.tap(find.byKey(WorkbenchShellPage.aiHistoryPromptKey(1)));
    await tester.pump();

    final field = tester.widget<TextField>(
      find.byKey(WorkbenchShellPage.aiPromptFieldKey),
    );
    expect(field.controller?.text, '压缩节奏');
  });

  testWidgets('re-runs an AI history item directly from history', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    await tester.tap(find.byKey(WorkbenchShellPage.settingsToolButtonKey));
    await tester.pump();
    await tester.tap(find.text('打开完整设置'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(SettingsShellPage.apiKeyFieldKey),
      'sk-test-key',
    );
    await tester.tap(find.byKey(SettingsShellPage.saveButtonKey));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(WorkbenchShellPage.aiToolButtonKey));
    await tester.pump();
    await tester.enterText(
      find.byKey(WorkbenchShellPage.aiPromptFieldKey),
      '压缩节奏',
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiGenerateButtonKey),
    );
    await tester.tap(find.byKey(WorkbenchShellPage.aiGenerateButtonKey));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('拒绝变更'));
    await tester.tap(find.text('拒绝变更'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiHistoryReplayButtonKey(1)),
    );
    await tester.tap(
      find.byKey(WorkbenchShellPage.aiHistoryReplayButtonKey(1)),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI 修改确认'), findsOneWidget);
    expect(find.text('修改意图：压缩节奏'), findsOneWidget);
    await tester.ensureVisible(find.text('拒绝变更'));
    await tester.tap(find.text('拒绝变更'));
    await tester.pumpAndSettle();

    expect(find.text('第2次 · 刚刚生成'), findsOneWidget);
    expect(find.text('改写 · 压缩节奏'), findsWidgets);
  });

  testWidgets('opens the AI review dialog after generating suggestions', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    await tester.tap(find.byKey(WorkbenchShellPage.settingsToolButtonKey));
    await tester.pump();
    await tester.tap(find.text('打开完整设置'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(SettingsShellPage.apiKeyFieldKey),
      'sk-test-key',
    );
    await tester.tap(find.byKey(SettingsShellPage.saveButtonKey));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(WorkbenchShellPage.aiToolButtonKey));
    await tester.pump();
    await tester.enterText(
      find.byKey(WorkbenchShellPage.aiPromptFieldKey),
      '压缩节奏',
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiGenerateButtonKey),
    );
    await tester.tap(find.byKey(WorkbenchShellPage.aiGenerateButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('AI 修改确认'), findsOneWidget);
    expect(find.text('接受变更'), findsOneWidget);
    expect(find.text('拒绝变更'), findsOneWidget);
    expect(find.text('修改意图：压缩节奏'), findsOneWidget);
    expect(find.text('已保留 1 / 1 个修改块'), findsOneWidget);
    expect(find.text('修改块 1'), findsOneWidget);
    expect(find.text('修改块 2'), findsNothing);
    expect(find.text('上一段'), findsWidgets);
    expect(find.text('当前被修改段'), findsWidgets);
    expect(find.text('下一段'), findsWidgets);
    expect(find.text('作者该段修改意见'), findsWidgets);
    expect(find.text('压缩节奏'), findsWidgets);
  });

  testWidgets('uses a continue-specific review title and block labels', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    await tester.tap(find.byKey(WorkbenchShellPage.settingsToolButtonKey));
    await tester.pump();
    await tester.tap(find.text('打开完整设置'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(SettingsShellPage.apiKeyFieldKey),
      'sk-test-key',
    );
    await tester.tap(find.byKey(SettingsShellPage.saveButtonKey));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(WorkbenchShellPage.aiToolButtonKey));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiContinueModeButtonKey),
    );
    await tester.tap(find.byKey(WorkbenchShellPage.aiContinueModeButtonKey));
    await tester.pump();
    await tester.enterText(
      find.byKey(WorkbenchShellPage.aiPromptFieldKey),
      '补一段',
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiGenerateButtonKey),
    );
    await tester.tap(find.byKey(WorkbenchShellPage.aiGenerateButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('AI 续写确认'), findsOneWidget);
    expect(find.text('续写块 1'), findsOneWidget);
    expect(find.text('续写块 2'), findsNothing);
  });

  testWidgets('AI generate emits structured request and review-open events', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    await configureWorkbenchAi(tester);
    await tester.tap(find.byKey(WorkbenchShellPage.aiToolButtonKey));
    await tester.pump();

    final prompt = List<String>.filled(40, '压缩节奏').join(' ');
    await tester.enterText(
      find.byKey(WorkbenchShellPage.aiPromptFieldKey),
      prompt,
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiGenerateButtonKey),
    );
    await tester.tap(find.byKey(WorkbenchShellPage.aiGenerateButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('AI 修改确认'), findsOneWidget);
    expect(
      _entriesForAction(eventLogStorage.entries, 'ui.ai.generate.started'),
      hasLength(1),
    );
    expect(
      _entriesForAction(eventLogStorage.entries, 'ai.chat.request.started'),
      hasLength(1),
    );
    expect(
      _entriesForAction(eventLogStorage.entries, 'ai.chat.request.succeeded'),
      hasLength(1),
    );
    expect(
      _entriesForAction(
        eventLogStorage.entries,
        'ui.ai.review_opened.succeeded',
      ),
      hasLength(1),
    );

    final requestStarted = _entriesForAction(
      eventLogStorage.entries,
      'ai.chat.request.started',
    ).single;
    expect(requestStarted.metadata.containsValue(prompt), isFalse);
    expect(requestStarted.metadata['promptLength'], prompt.length);
    expect(
      (requestStarted.metadata['promptPreview'] as String).length,
      lessThanOrEqualTo(160),
    );
  });

  testWidgets('AI history replay emits replay and review-open events', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    await configureWorkbenchAi(tester);
    await tester.tap(find.byKey(WorkbenchShellPage.aiToolButtonKey));
    await tester.pump();
    await tester.enterText(
      find.byKey(WorkbenchShellPage.aiPromptFieldKey),
      '压缩节奏',
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiGenerateButtonKey),
    );
    await tester.tap(find.byKey(WorkbenchShellPage.aiGenerateButtonKey));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('拒绝变更'));
    await tester.tap(find.text('拒绝变更'));
    await tester.pumpAndSettle();

    final baselineCount = eventLogStorage.entries.length;

    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiHistoryReplayButtonKey(1)),
    );
    await tester.tap(
      find.byKey(WorkbenchShellPage.aiHistoryReplayButtonKey(1)),
    );
    await tester.pumpAndSettle();

    final replayEntries = eventLogStorage.entries.skip(baselineCount).toList();
    expect(
      _entriesForAction(replayEntries, 'ui.ai.replay.started'),
      hasLength(1),
    );
    expect(
      _entriesForAction(replayEntries, 'ai.chat.request.started'),
      hasLength(1),
    );
    expect(
      _entriesForAction(replayEntries, 'ui.ai.review_opened.succeeded'),
      hasLength(1),
    );
  });

  testWidgets('accepting AI suggestions updates the draft', (tester) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    await tester.enterText(
      find.byKey(WorkbenchShellPage.editorTextFieldKey),
      '原始正文',
    );
    await tester.pump();

    await tester.tap(find.byKey(WorkbenchShellPage.settingsToolButtonKey));
    await tester.pump();
    await tester.tap(find.text('打开完整设置'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(SettingsShellPage.apiKeyFieldKey),
      'sk-test-key',
    );
    await tester.tap(find.byKey(SettingsShellPage.saveButtonKey));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(WorkbenchShellPage.aiToolButtonKey));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiGenerateButtonKey),
    );
    await tester.tap(find.byKey(WorkbenchShellPage.aiGenerateButtonKey));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('接受变更'));
    await tester.tap(find.text('接受变更'));
    await tester.pumpAndSettle();

    expect(find.text('调整语气与节奏'), findsOneWidget);
  });

  testWidgets(
    'accepting AI suggestions in continue mode records continue output',
    (tester) async {
      await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

      await tester.enterText(
        find.byKey(WorkbenchShellPage.editorTextFieldKey),
        '原始正文',
      );
      await tester.pump();

      await tester.tap(find.byKey(WorkbenchShellPage.settingsToolButtonKey));
      await tester.pump();
      await tester.tap(find.text('打开完整设置'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(SettingsShellPage.apiKeyFieldKey),
        'sk-test-key',
      );
      await tester.tap(find.byKey(SettingsShellPage.saveButtonKey));
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(WorkbenchShellPage.aiToolButtonKey));
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(WorkbenchShellPage.aiContinueModeButtonKey),
      );
      await tester.tap(find.byKey(WorkbenchShellPage.aiContinueModeButtonKey));
      await tester.pump();
      await tester.enterText(
        find.byKey(WorkbenchShellPage.aiPromptFieldKey),
        '补一段',
      );
      await tester.ensureVisible(
        find.byKey(WorkbenchShellPage.aiGenerateButtonKey),
      );
      await tester.tap(find.byKey(WorkbenchShellPage.aiGenerateButtonKey));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('接受变更'));
      await tester.tap(find.text('接受变更'));
      await tester.pumpAndSettle();

      expect(find.text('原始正文\n\n补一段'), findsOneWidget);

      final versionsButton = find.byKey(
        WorkbenchShellPage.openVersionsButtonKey,
      );
      await tester.ensureVisible(versionsButton);
      await tester.pump();
      await tester.tap(versionsButton);
      await tester.pumpAndSettle();

      expect(find.text('来源：AI 接受变更（续写）'), findsOneWidget);
      expect(find.text('原始正文\n\n补一段'), findsWidgets);
    },
  );

  testWidgets('rejecting AI suggestions keeps the original draft', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    await tester.enterText(
      find.byKey(WorkbenchShellPage.editorTextFieldKey),
      '原始正文',
    );
    await tester.pump();

    await tester.tap(find.byKey(WorkbenchShellPage.settingsToolButtonKey));
    await tester.pump();
    await tester.tap(find.text('打开完整设置'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(SettingsShellPage.apiKeyFieldKey),
      'sk-test-key',
    );
    await tester.tap(find.byKey(SettingsShellPage.saveButtonKey));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(WorkbenchShellPage.aiToolButtonKey));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiGenerateButtonKey),
    );
    await tester.tap(find.byKey(WorkbenchShellPage.aiGenerateButtonKey));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('拒绝变更'));
    await tester.tap(find.text('拒绝变更'));
    await tester.pumpAndSettle();

    expect(find.text('原始正文'), findsOneWidget);
    expect(
      find.text('原始正文\n\n[AI建议 1] 调整了语气。\n\n[AI建议 2] 强化了节奏。'),
      findsNothing,
    );
  });

  testWidgets('blocks AI generation when added rewrite selections overlap', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));
    await configureWorkbenchAi(tester);

    await tester.enterText(
      find.byKey(WorkbenchShellPage.editorTextFieldKey),
      'ABCDEFGHIJ',
    );
    await tester.pump();
    await tester.tap(find.byKey(WorkbenchShellPage.aiToolButtonKey));
    await tester.pump();

    setWorkbenchEditorSelection(tester, start: 0, end: 4);
    await tester.pump();
    await tester.enterText(
      find.byKey(WorkbenchShellPage.aiPromptFieldKey),
      '改第一段',
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiAddSelectionButtonKey),
    );
    await tester.tap(find.byKey(WorkbenchShellPage.aiAddSelectionButtonKey));
    await tester.pumpAndSettle();

    setWorkbenchEditorSelection(tester, start: 2, end: 6);
    await tester.pump();
    await tester.enterText(
      find.byKey(WorkbenchShellPage.aiPromptFieldKey),
      '改重叠段',
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiAddSelectionButtonKey),
    );
    await tester.tap(find.byKey(WorkbenchShellPage.aiAddSelectionButtonKey));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiGenerateButtonKey),
    );
    await tester.tap(find.byKey(WorkbenchShellPage.aiGenerateButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('多处选区重叠'), findsOneWidget);
    expect(find.textContaining('当前请求未发出'), findsOneWidget);
  });

  testWidgets(
    'treats adjacent rewrite selections as valid non-overlapping blocks',
    (tester) async {
      await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));
      await configureWorkbenchAi(tester);

      await tester.enterText(
        find.byKey(WorkbenchShellPage.editorTextFieldKey),
        'ABCDEFGH',
      );
      await tester.pump();
      await tester.tap(find.byKey(WorkbenchShellPage.aiToolButtonKey));
      await tester.pump();

      setWorkbenchEditorSelection(tester, start: 0, end: 2);
      await tester.pump();
      await tester.enterText(
        find.byKey(WorkbenchShellPage.aiPromptFieldKey),
        '改第一段',
      );
      await tester.ensureVisible(
        find.byKey(WorkbenchShellPage.aiAddSelectionButtonKey),
      );
      await tester.tap(find.byKey(WorkbenchShellPage.aiAddSelectionButtonKey));
      await tester.pumpAndSettle();

      setWorkbenchEditorSelection(tester, start: 2, end: 4);
      await tester.pump();
      await tester.enterText(
        find.byKey(WorkbenchShellPage.aiPromptFieldKey),
        '改第二段',
      );
      await tester.ensureVisible(
        find.byKey(WorkbenchShellPage.aiAddSelectionButtonKey),
      );
      await tester.tap(find.byKey(WorkbenchShellPage.aiAddSelectionButtonKey));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(WorkbenchShellPage.aiGenerateButtonKey),
      );
      await tester.tap(find.byKey(WorkbenchShellPage.aiGenerateButtonKey));
      await tester.pumpAndSettle();

      expect(find.text('多处选区重叠'), findsNothing);
      expect(find.text('修改块 1'), findsOneWidget);
      expect(find.text('修改块 2'), findsOneWidget);

      await tester.ensureVisible(find.text('接受变更'));
      await tester.tap(find.text('接受变更'));
      await tester.pumpAndSettle();

      expect(find.text('改第一段改第二段EFGH'), findsOneWidget);
    },
  );

  testWidgets('supports excluding and restoring AI suggestion blocks', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));
    await configureWorkbenchAi(tester);

    await tester.enterText(
      find.byKey(WorkbenchShellPage.editorTextFieldKey),
      'ABCDEFGH',
    );
    await tester.pump();
    await tester.tap(find.byKey(WorkbenchShellPage.aiToolButtonKey));
    await tester.pump();

    setWorkbenchEditorSelection(tester, start: 0, end: 2);
    await tester.pump();
    await tester.enterText(
      find.byKey(WorkbenchShellPage.aiPromptFieldKey),
      '改第一段',
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiAddSelectionButtonKey),
    );
    await tester.tap(find.byKey(WorkbenchShellPage.aiAddSelectionButtonKey));
    await tester.pumpAndSettle();

    setWorkbenchEditorSelection(tester, start: 2, end: 4);
    await tester.pump();
    await tester.enterText(
      find.byKey(WorkbenchShellPage.aiPromptFieldKey),
      '改第二段',
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiAddSelectionButtonKey),
    );
    await tester.tap(find.byKey(WorkbenchShellPage.aiAddSelectionButtonKey));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiGenerateButtonKey),
    );
    await tester.tap(find.byKey(WorkbenchShellPage.aiGenerateButtonKey));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('排除修改块 1'));
    await tester.tap(find.text('排除修改块 1'));
    await tester.pump();
    expect(find.text('恢复修改块 1'), findsOneWidget);
    expect(find.text('已保留 1 / 2 个修改块'), findsOneWidget);

    await tester.ensureVisible(find.text('恢复修改块 1'));
    await tester.tap(find.text('恢复修改块 1'));
    await tester.pump();
    expect(find.text('排除修改块 1'), findsOneWidget);
    expect(find.text('已保留 2 / 2 个修改块'), findsOneWidget);
  });

  testWidgets('prevents accepting when all AI suggestion blocks are excluded', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));
    await configureWorkbenchAi(tester);

    await tester.enterText(
      find.byKey(WorkbenchShellPage.editorTextFieldKey),
      'ABCDEFGH',
    );
    await tester.pump();
    await tester.tap(find.byKey(WorkbenchShellPage.aiToolButtonKey));
    await tester.pump();

    setWorkbenchEditorSelection(tester, start: 0, end: 2);
    await tester.pump();
    await tester.enterText(
      find.byKey(WorkbenchShellPage.aiPromptFieldKey),
      '改第一段',
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiAddSelectionButtonKey),
    );
    await tester.tap(find.byKey(WorkbenchShellPage.aiAddSelectionButtonKey));
    await tester.pumpAndSettle();

    setWorkbenchEditorSelection(tester, start: 2, end: 4);
    await tester.pump();
    await tester.enterText(
      find.byKey(WorkbenchShellPage.aiPromptFieldKey),
      '改第二段',
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiAddSelectionButtonKey),
    );
    await tester.tap(find.byKey(WorkbenchShellPage.aiAddSelectionButtonKey));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiGenerateButtonKey),
    );
    await tester.tap(find.byKey(WorkbenchShellPage.aiGenerateButtonKey));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('排除修改块 1'));
    await tester.tap(find.text('排除修改块 1'));
    await tester.pump();
    await tester.ensureVisible(find.text('排除修改块 2'));
    await tester.tap(find.text('排除修改块 2'));
    await tester.pump();

    expect(find.text('至少保留 1 个修改块'), findsOneWidget);
  });

  testWidgets('accepts only the remaining AI suggestion blocks', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));
    await configureWorkbenchAi(tester);

    await tester.enterText(
      find.byKey(WorkbenchShellPage.editorTextFieldKey),
      'ABCDEFGH',
    );
    await tester.pump();

    await tester.tap(find.byKey(WorkbenchShellPage.aiToolButtonKey));
    await tester.pump();

    setWorkbenchEditorSelection(tester, start: 0, end: 2);
    await tester.pump();
    await tester.enterText(
      find.byKey(WorkbenchShellPage.aiPromptFieldKey),
      '改第一段',
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiAddSelectionButtonKey),
    );
    await tester.tap(find.byKey(WorkbenchShellPage.aiAddSelectionButtonKey));
    await tester.pumpAndSettle();

    setWorkbenchEditorSelection(tester, start: 2, end: 4);
    await tester.pump();
    await tester.enterText(
      find.byKey(WorkbenchShellPage.aiPromptFieldKey),
      '改第二段',
    );
    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiAddSelectionButtonKey),
    );
    await tester.tap(find.byKey(WorkbenchShellPage.aiAddSelectionButtonKey));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(WorkbenchShellPage.aiGenerateButtonKey),
    );
    await tester.tap(find.byKey(WorkbenchShellPage.aiGenerateButtonKey));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('排除修改块 2'));
    await tester.tap(find.text('排除修改块 2'));
    await tester.pump();
    await tester.ensureVisible(find.text('接受变更'));
    await tester.tap(find.text('接受变更'));
    await tester.pumpAndSettle();

    expect(find.text('改第一段CDEFGH'), findsOneWidget);
    expect(find.textContaining('改第二段'), findsNothing);
  });

  testWidgets(
    'opens the sandbox monitor from the simulation completed banner',
    (tester) async {
      await tester.pumpWidget(
        const NovelWriterApp(
          home: WorkbenchShellPage(
            uiState: WorkbenchUiState.simulationCompleted,
          ),
        ),
      );

      await tester.tap(find.text('查看生成过程'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('AI 生成过程'), findsOneWidget);
      expect(find.text('生成记录'), findsOneWidget);
    },
  );

  testWidgets('opens the sandbox monitor from the simulation failed banner', (
    tester,
  ) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: WorkbenchShellPage(
          uiState: WorkbenchUiState.simulationFailedSummary,
        ),
      ),
    );

    await tester.tap(find.text('查看原因'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('AI 生成过程'), findsOneWidget);
    expect(find.text('生成记录'), findsOneWidget);
  });

  testWidgets('shows the empty sandbox state when no simulation has run', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: SandboxMonitorPage()));

    expect(find.text('还没有生成过程'), findsOneWidget);
    expect(
      find.text('这一场还没有 AI 生成记录。你可以先回到写作工作台，让 AI 按当前场景资料试写。'),
      findsOneWidget,
    );
  });

  testWidgets('sandbox monitor uses the pencil-aligned modal copy deck', (
    tester,
  ) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: WorkbenchShellPage(uiState: WorkbenchUiState.simulationCompleted),
      ),
    );

    await tester.tap(find.text('查看生成过程'));
    await tester.pumpAndSettle();

    expect(find.text('生成记录'), findsOneWidget);
    expect(find.textContaining('月潮回声 / 第 3 章'), findsWidgets);
  });

  testWidgets('shows single-version fallback messaging in version history', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: VersionHistoryPage()));
    await tester.pumpAndSettle();

    expect(find.text('当前章节只有 1 个版本'), findsOneWidget);
    expect(find.text('版本信息'), findsOneWidget);
    expect(find.text('版本池'), findsOneWidget);
    expect(find.text('暂不可恢复'), findsOneWidget);
    expect(find.text('当前只有一个章节版本，因此暂时不可恢复或对比历史版本。'), findsOneWidget);
  });

  testWidgets('selecting another participant exposes prompt editing entry', (
    tester,
  ) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: SandboxMonitorPage(previewStatus: SimulationStatus.completed),
      ),
    );

    expect(find.text('任务分配'), findsOneWidget);
    expect(find.byKey(SandboxMonitorPage.editPromptButtonKey), findsOneWidget);

    await tester.tap(find.byKey(SandboxMonitorPage.yueRenParticipantKey));
    await tester.pump();

    expect(find.text('岳人 · 对峙'), findsWidgets);
    expect(find.byKey(SandboxMonitorPage.editPromptButtonKey), findsOneWidget);
  });

  testWidgets('shows failure-focused detail in sandbox failure mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      const NovelWriterApp(home: SandboxMonitorPage(failureMode: true)),
    );

    expect(find.text('运行失败摘要'), findsWidgets);
    expect(find.text('状态机拒绝了关键动作，正文未被改写。'), findsWidgets);
  });

  testWidgets('sandbox monitor shows structured scene-aware run summaries', (
    tester,
  ) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: SandboxMonitorPage(previewStatus: SimulationStatus.completed),
      ),
    );

    expect(find.text('运行摘要'), findsOneWidget);
    expect(find.text('当前场景'), findsOneWidget);
    expect(find.text('输出分类'), findsOneWidget);
    expect(find.textContaining('发言'), findsWidgets);
    expect(find.textContaining('意图'), findsWidgets);
    expect(find.textContaining('裁决'), findsWidgets);
  });

  testWidgets(
    'editing selected participant prompt updates the participant list',
    (tester) async {
      await tester.pumpWidget(
        const NovelWriterApp(
          home: SandboxMonitorPage(previewStatus: SimulationStatus.completed),
        ),
      );

      await tester.tap(find.byKey(SandboxMonitorPage.editPromptButtonKey));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(SandboxMonitorPage.editPromptFieldKey),
        '认知：先压低语气，再决定是否继续追问。',
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(SandboxMonitorPage.liuXiParticipantKey),
          matching: find.textContaining('先压低语气，再决定是否继续追问'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'editing prompt from preview completed monitor updates preview state',
    (tester) async {
      await tester.pumpWidget(
        const NovelWriterApp(
          home: SandboxMonitorPage(previewStatus: SimulationStatus.completed),
        ),
      );

      await tester.tap(find.byKey(SandboxMonitorPage.editPromptButtonKey));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(SandboxMonitorPage.editPromptFieldKey),
        '认知：先观察停顿，再决定追问顺序。',
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(SandboxMonitorPage.liuXiParticipantKey),
          matching: find.textContaining('先观察停顿，再决定追问顺序'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('sending feedback to director influences task ordering', (
    tester,
  ) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: SandboxMonitorPage(previewStatus: SimulationStatus.completed),
      ),
    );

    await tester.enterText(
      find.byKey(SandboxMonitorPage.feedbackFieldKey),
      '让岳人先说话',
    );
    await tester.tap(find.byKey(SandboxMonitorPage.sendFeedbackButtonKey));
    await tester.pump();

    expect(find.textContaining('任务 1：岳人围绕'), findsWidgets);
  });
}

class _ControlledStoryRunOrchestrator extends ChapterGenerationOrchestrator {
  _ControlledStoryRunOrchestrator({required super.settingsStore});

  final Completer<void> started = Completer<void>();
  final Completer<void> release = Completer<void>();

  @override
  Future<SceneRuntimeOutput> runScene(
    SceneBrief brief, {
    ProjectMaterialSnapshot? materials,
    void Function(String message)? onStatus,
    void Function()? onSpeculationReady,
  }) async {
    onStatus?.call('fake orchestrator running');
    started.complete();
    await release.future;
    return _fakeSceneRuntimeOutput(brief);
  }
}

class _ImmediateStoryRunOrchestrator extends ChapterGenerationOrchestrator {
  _ImmediateStoryRunOrchestrator({required super.settingsStore});

  @override
  Future<SceneRuntimeOutput> runScene(
    SceneBrief brief, {
    ProjectMaterialSnapshot? materials,
    void Function(String message)? onStatus,
    void Function()? onSpeculationReady,
  }) async {
    onStatus?.call('fake orchestrator running');
    onSpeculationReady?.call();
    return _fakeSceneRuntimeOutput(brief);
  }
}

SceneRuntimeOutput _fakeSceneRuntimeOutput(SceneBrief brief) {
  return SceneRuntimeOutput(
    brief: brief,
    resolvedCast: const [],
    director: const SceneDirectorOutput(text: 'director output'),
    roleOutputs: const [],
    prose: const SceneProseDraft(text: 'prose', attempt: 1),
    review: const SceneReviewResult(
      judge: SceneReviewPassResult(
        status: SceneReviewStatus.pass,
        reason: 'pass',
        rawText: '',
      ),
      consistency: SceneReviewPassResult(
        status: SceneReviewStatus.pass,
        reason: 'consistent',
        rawText: '',
      ),
      decision: SceneReviewDecision.pass,
    ),
    proseAttempts: 1,
    softFailureCount: 0,
  );
}

List<AppEventLogEntry> _entriesForAction(
  List<AppEventLogEntry> entries,
  String action,
) {
  return entries.where((entry) => entry.action == action).toList();
}

class _RecordingAppEventLogStorage implements AppEventLogStorage {
  final List<AppEventLogEntry> entries = <AppEventLogEntry>[];

  @override
  Future<void> write(AppEventLogEntry entry) async {
    entries.add(entry);
  }
}
