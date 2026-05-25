import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:novel_writer/app/di/app_providers.dart';
import 'package:novel_writer/app/di/service_registry.dart';
import 'package:novel_writer/app/events/app_event_bus.dart';
import 'package:novel_writer/app/logging/app_event_log.dart';
import 'package:novel_writer/app/state/app_ai_history_storage.dart';
import 'package:novel_writer/app/state/app_ai_history_store.dart';
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
import 'package:novel_writer/app/state/story_generation_run_storage.dart';
import 'package:novel_writer/app/state/story_generation_run_store.dart';
import 'package:novel_writer/app/state/story_generation_storage.dart';
import 'package:novel_writer/app/state/story_generation_store.dart';
import 'package:novel_writer/app/state/story_outline_storage.dart';
import 'package:novel_writer/app/state/story_outline_store.dart';
import 'package:novel_writer/app/theme/app_theme.dart';
import 'package:novel_writer/features/author_feedback/data/author_feedback_storage.dart';
import 'package:novel_writer/features/author_feedback/data/author_feedback_store.dart';
import 'package:novel_writer/features/characters/presentation/character_state_card.dart';
import 'package:novel_writer/features/review_tasks/data/review_task_storage.dart';
import 'package:novel_writer/features/review_tasks/data/review_task_store.dart';
import 'package:novel_writer/features/story_generation/data/pipeline_definition.dart';
import 'package:novel_writer/features/workbench/presentation/workbench_shell_page.dart';
import 'package:novel_writer/features/workbench/presentation/workbench_tool_window_panel.dart';

void main() {
  late ServiceRegistry registry;

  List<Override> registryOverrides() =>
      appProviderOverridesForRegistry(registry);

  tearDown(() {
    registry.disposeAll();
  });

  group('WorkbenchShellPage restored story runs', () {
    late AppWorkspaceStore workspaceStore;
    late StoryGenerationRunStore runStore;

    testWidgets('prompts when an unfinished generation run is restored', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      registry = ServiceRegistry();
      final runStorage = InMemoryStoryGenerationRunStorage();
      _registerWorkbenchStores(registry);
      workspaceStore = registry.resolve<AppWorkspaceStore>();
      workspaceStore.createProject(projectName: '恢复测试');
      await runStorage.save(
        const StoryGenerationRunSnapshot(
          status: StoryGenerationRunStatus.running,
          sceneId: 'restored-scene',
          sceneLabel: '第 1 章 / 场景 01',
          headline: 'AI 正在写作',
          summary: '应用关闭前仍有一轮生成未完成。',
          stageSummary: '正在准备候选稿',
        ).toJson(),
        sceneScopeId: workspaceStore.currentSceneScopeId,
      );
      runStore = _registerStoryRunStore(registry, runStorage: runStorage);
      await runStore.ready;

      await tester.pumpWidget(
        ProviderScope(
          overrides: registryOverrides(),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const WorkbenchShellPage(),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('workbench-run-recovery-prompt')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('workbench-run-recovery-retry-button'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('workbench-run-recovery-discard-button'),
        ),
        findsOneWidget,
      );
      expect(find.text('检测到未完成的 AI 试写'), findsOneWidget);
    });

    for (final status in [
      StoryGenerationRunStatus.completed,
      StoryGenerationRunStatus.failed,
      StoryGenerationRunStatus.cancelled,
    ]) {
      testWidgets('does not prompt for restored ${status.name} runs', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1280, 820);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        registry = ServiceRegistry();
        final runStorage = InMemoryStoryGenerationRunStorage();
        _registerWorkbenchStores(registry);
        workspaceStore = registry.resolve<AppWorkspaceStore>();
        workspaceStore.createProject(projectName: '终态恢复测试');
        await runStorage.save(
          StoryGenerationRunSnapshot(
            status: status,
            sceneId: 'terminal-scene',
            sceneLabel: '第 1 章 / 场景 01',
            headline: 'AI 试写终态',
            summary: '这轮生成已经结束。',
            stageSummary: status.name,
          ).toJson(),
          sceneScopeId: workspaceStore.currentSceneScopeId,
        );
        runStore = _registerStoryRunStore(registry, runStorage: runStorage);
        await runStore.ready;

        await tester.pumpWidget(
          ProviderScope(
            overrides: registryOverrides(),
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const WorkbenchShellPage(),
            ),
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const ValueKey<String>('workbench-run-recovery-prompt')),
          findsNothing,
        );
        expect(find.text('检测到未完成的 AI 试写'), findsNothing);
      });
    }
  });

  group('WorkbenchShellPage center pane AI tool invitation', () {
    late AppWorkspaceStore workspaceStore;

    testWidgets('shows AI tool invitation in center pane with working action', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      registry = ServiceRegistry();
      _registerWorkbenchStores(registry);
      workspaceStore = registry.resolve<AppWorkspaceStore>();
      workspaceStore.createProject(projectName: '测试项目');

      await tester.pumpWidget(
        ProviderScope(
          overrides: registryOverrides(),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const WorkbenchShellPage(),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // The center pane should show "AI 写作助手" header
      expect(
        find.text('AI 写作助手'),
        findsOneWidget,
        reason: 'Center pane should show "AI 写作助手" header',
      );

      // The center pane should show the "打开 AI 面板" button
      // This button opens the AI tool panel when tapped
      final openAiButton = find.text('打开 AI 面板');
      expect(
        openAiButton,
        findsOneWidget,
        reason: 'Center pane should show "打开 AI 面板" button',
      );
      expect(find.text('续写、润色、对话等多种模式'), findsOneWidget);

      // Tap the button to open the AI tool panel
      await tester.tap(openAiButton);
      await tester.pump();

      // After tapping, the AI tool panel should be visible
      // The AI panel shows "助手" and "写作助手" headers
      expect(find.text('助手'), findsOneWidget);
      expect(find.text('写作助手'), findsOneWidget);
    });
  });

  group('WorkbenchShellPage Run Center', () {
    late AppWorkspaceStore workspaceStore;

    testWidgets('opens from visible toolbar button and shows idle state', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      registry = ServiceRegistry();
      _registerWorkbenchStores(registry);
      workspaceStore = registry.resolve<AppWorkspaceStore>();
      workspaceStore.createProject(projectName: '测试项目');

      await tester.pumpWidget(
        ProviderScope(
          overrides: registryOverrides(),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const WorkbenchShellPage(),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // Run Center button should be visible in toolbar
      final runCenterButton = find.byKey(
        WorkbenchShellPage.runCenterToolButtonKey,
      );
      expect(runCenterButton, findsOneWidget);

      // Tap to open Run Center
      await tester.tap(runCenterButton);
      await tester.pump();

      // Run Center panel should be visible with idle state
      expect(
        find.byKey(const ValueKey<String>('workbench-run-center-panel')),
        findsOneWidget,
      );
      expect(find.text('未运行'), findsOneWidget);
      expect(find.text('尚未运行'), findsOneWidget);
    });

    testWidgets('shows failed state with retry button', (tester) async {
      tester.view.physicalSize = const Size(1280, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      registry = ServiceRegistry();
      final runStorage = InMemoryStoryGenerationRunStorage();
      _registerWorkbenchStores(registry);
      workspaceStore = registry.resolve<AppWorkspaceStore>();
      workspaceStore.createProject(projectName: '测试项目');
      final sceneId = workspaceStore.currentScene.id;
      await runStorage.save(
        StoryGenerationRunSnapshot(
          status: StoryGenerationRunStatus.failed,
          sceneId: sceneId,
          sceneLabel: '第 1 章 / 场景 01',
          headline: '生成失败',
          summary: '网络连接超时',
          stageSummary: '准备候选稿',
          errorDetail: '连接API超时',
        ).toJson(),
        sceneScopeId: workspaceStore.currentSceneScopeId,
      );
      final runStore = _registerStoryRunStore(registry, runStorage: runStorage);
      await runStore.ready;

      await tester.pumpWidget(
        ProviderScope(
          overrides: registryOverrides(),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const WorkbenchShellPage(),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // Open Run Center
      await tester.tap(find.byKey(WorkbenchShellPage.runCenterToolButtonKey));
      await tester.pump();

      // Failed state should be visible with retry button
      expect(find.text('失败'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('workbench-run-center-retry-button')),
        findsOneWidget,
      );
    });

    testWidgets(
      'shows stage timeline for completed run with all stages completed',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 820);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        registry = ServiceRegistry();
        final runStorage = InMemoryStoryGenerationRunStorage();
        _registerWorkbenchStores(registry);
        workspaceStore = registry.resolve<AppWorkspaceStore>();
        workspaceStore.createProject(projectName: '测试项目');
        final sceneId = workspaceStore.currentScene.id;

        // Seed a completed run with stage timeline
        final completedTimeline = [
          for (final spec in BuiltInPresets.defaultNineStage.enabledStages)
            StoryGenerationRunStageSnapshot(
              stageId: spec.id,
              label: spec.label,
              status: StoryGenerationRunStageStatus.completed,
            ),
        ];
        await runStorage.save(
          StoryGenerationRunSnapshot(
            status: StoryGenerationRunStatus.completed,
            sceneId: sceneId,
            sceneLabel: '第 1 章 / 场景 01',
            headline: 'AI 试写完成',
            summary: '候选稿已生成',
            stageSummary: '候选稿已生成，等待作者采纳',
            stageTimeline: completedTimeline,
          ).toJson(),
          sceneScopeId: workspaceStore.currentSceneScopeId,
        );
        final runStore = _registerStoryRunStore(
          registry,
          runStorage: runStorage,
        );
        await runStore.ready;

        await tester.pumpWidget(
          ProviderScope(
            overrides: registryOverrides(),
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const WorkbenchShellPage(),
            ),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        // Open Run Center
        await tester.tap(find.byKey(WorkbenchShellPage.runCenterToolButtonKey));
        await tester.pump();

        // Stage timeline should be visible
        expect(
          find.byKey(const ValueKey<String>('workbench-stage-timeline')),
          findsOneWidget,
          reason: 'Stage timeline container should be visible',
        );

        // At least one stage row should be visible
        expect(
          find.byKey(
            const ValueKey<String>('stage-timeline-row-contextEnrichment'),
          ),
          findsOneWidget,
          reason: 'First stage row should be visible',
        );
      },
    );

    testWidgets(
      'shows failed stage timeline with truncated long error summary',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 820);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        registry = ServiceRegistry();
        final runStorage = InMemoryStoryGenerationRunStorage();
        _registerWorkbenchStores(registry);
        workspaceStore = registry.resolve<AppWorkspaceStore>();
        workspaceStore.createProject(projectName: '测试项目');
        final sceneId = workspaceStore.currentScene.id;

        // Create a long error summary that would overflow without ellipsis
        final longErrorSummary =
            '这是一个非常长的错误消息，它可能会导致UI溢出问题，如果不进行适当的截断处理的话。' * 5;

        // Seed a failed run with stage timeline including failed stage
        final failedTimeline = [
          const StoryGenerationRunStageSnapshot(
            stageId: PipelineStageId.contextEnrichment,
            label: '上下文增强',
            status: StoryGenerationRunStageStatus.completed,
          ),
          StoryGenerationRunStageSnapshot(
            stageId: PipelineStageId.scenePlanning,
            label: '场景规划',
            status: StoryGenerationRunStageStatus.failed,
            failureCode: 'orchestrator',
            summary: longErrorSummary,
          ),
        ];
        await runStorage.save(
          StoryGenerationRunSnapshot(
            status: StoryGenerationRunStatus.failed,
            sceneId: sceneId,
            sceneLabel: '第 1 章 / 场景 01',
            headline: 'AI 试写失败',
            summary: '试写未完成',
            stageSummary: '失败',
            errorDetail: 'pipeline-error',
            stageTimeline: failedTimeline,
          ).toJson(),
          sceneScopeId: workspaceStore.currentSceneScopeId,
        );
        final runStore = _registerStoryRunStore(
          registry,
          runStorage: runStorage,
        );
        await runStore.ready;

        await tester.pumpWidget(
          ProviderScope(
            overrides: registryOverrides(),
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const WorkbenchShellPage(),
            ),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        // Open Run Center
        await tester.tap(find.byKey(WorkbenchShellPage.runCenterToolButtonKey));
        await tester.pump();

        // Stage timeline should be visible
        expect(
          find.byKey(const ValueKey<String>('workbench-stage-timeline')),
          findsOneWidget,
        );

        // Failed stage label with summary should be rendered without overflow
        expect(
          find.byKey(
            const ValueKey<String>('stage-failed-label-scenePlanning'),
          ),
          findsOneWidget,
          reason: 'Failed stage label should be visible',
        );

        // Pump without throwing overflow exceptions
        await tester.pump();
      },
    );
  });

  group('WorkbenchShellPage scene switch guards', () {
    late AppWorkspaceStore workspaceStore;

    testWidgets(
      'running run scene switch shows confirmation and switches only after confirm',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 820);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        registry = ServiceRegistry();
        final runStorage = InMemoryStoryGenerationRunStorage();
        _registerWorkbenchStores(registry);
        workspaceStore = registry.resolve<AppWorkspaceStore>();
        workspaceStore.createProject(projectName: '测试项目');
        workspaceStore.createScene('第一章');
        final firstSceneId = workspaceStore.currentScene.id;
        workspaceStore.createScene('第二章');
        final secondSceneId = workspaceStore.currentScene.id;
        workspaceStore.updateCurrentScene(
          sceneId: firstSceneId,
          recentLocation: workspaceStore.scenes
              .firstWhere((scene) => scene.id == firstSceneId)
              .displayLocation,
        );

        // Seed a running run for the first scene (avoid runCurrentScene in widget tests)
        await runStorage.save(
          StoryGenerationRunSnapshot(
            status: StoryGenerationRunStatus.running,
            sceneId: firstSceneId,
            sceneLabel: '第 1 章 / 场景 01',
            headline: 'AI 正在写作',
            summary: '生成进行中',
            stageSummary: '正在准备候选稿',
          ).toJson(),
          sceneScopeId: workspaceStore.currentSceneScopeId,
        );
        final runStore = _registerStoryRunStore(
          registry,
          runStorage: runStorage,
        );
        await runStore.ready;

        await tester.pumpWidget(
          ProviderScope(
            overrides: registryOverrides(),
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const WorkbenchShellPage(),
            ),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        // Verify run is active
        expect(runStore.snapshot.status, StoryGenerationRunStatus.running);

        // Tap second scene
        await tester.tap(
          find.byKey(ValueKey('workbench-chapter-list-scene-$secondSceneId')),
        );
        await tester.pumpAndSettle();

        // Confirmation dialog should appear
        expect(find.text('切换章节'), findsOneWidget);
        expect(find.text('留在当前章节'), findsOneWidget);
        expect(find.text('取消运行并切换'), findsOneWidget);

        // Tap cancel to stay on first scene
        await tester.tap(find.text('留在当前章节'));
        await tester.pumpAndSettle();

        // Should still be on first scene and run still active
        expect(workspaceStore.currentScene.id, firstSceneId);
        expect(runStore.snapshot.status, StoryGenerationRunStatus.running);

        // Now tap second scene again and confirm switch
        // Note: Full cancellation requires internal state from runCurrentScene(),
        // which hangs in widget tests. We verify the dialog flow and scene switch.
        await tester.tap(
          find.byKey(ValueKey('workbench-chapter-list-scene-$secondSceneId')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('取消运行并切换'));
        await tester.pumpAndSettle();

        // Should now be on second scene (dialog accepted)
        expect(workspaceStore.currentScene.id, secondSceneId);
        // Note: run cancellation status not tested here due to widget test limitations
      },
    );

    testWidgets('same-scene click does not show confirmation', (tester) async {
      tester.view.physicalSize = const Size(1280, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      registry = ServiceRegistry();
      final runStorage = InMemoryStoryGenerationRunStorage();
      _registerWorkbenchStores(registry);
      workspaceStore = registry.resolve<AppWorkspaceStore>();
      workspaceStore.createProject(projectName: '测试项目');
      workspaceStore.createScene('第一章');
      final firstSceneId = workspaceStore.currentScene.id;

      // Seed a running run (avoid runCurrentScene in widget tests)
      await runStorage.save(
        StoryGenerationRunSnapshot(
          status: StoryGenerationRunStatus.running,
          sceneId: firstSceneId,
          sceneLabel: '第 1 章 / 场景 01',
          headline: 'AI 正在写作',
          summary: '生成进行中',
          stageSummary: '正在准备候选稿',
        ).toJson(),
        sceneScopeId: workspaceStore.currentSceneScopeId,
      );
      final runStore = _registerStoryRunStore(registry, runStorage: runStorage);
      await runStore.ready;

      await tester.pumpWidget(
        ProviderScope(
          overrides: registryOverrides(),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const WorkbenchShellPage(),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify run is active
      expect(runStore.snapshot.status, StoryGenerationRunStatus.running);

      // Tap the same scene
      await tester.tap(
        find.byKey(ValueKey('workbench-chapter-list-scene-$firstSceneId')),
      );
      await tester.pumpAndSettle();

      // No confirmation dialog should appear
      expect(find.text('切换章节'), findsNothing);
      expect(find.text('留在当前章节'), findsNothing);

      // Should still be on same scene
      expect(workspaceStore.currentScene.id, firstSceneId);
    });
  });

  group('WorkbenchShellPage character state card', () {
    late AppWorkspaceStore workspaceStore;

    testWidgets('resources side panel shows and updates character state', (
      tester,
    ) async {
      registry = ServiceRegistry();
      _registerWorkbenchStores(registry);
      workspaceStore = registry.resolve<AppWorkspaceStore>();
      workspaceStore.createProject(projectName: '角色状态测试');
      final settingsStore = registry.resolve<AppSettingsStore>();
      final promptController = TextEditingController();
      addTearDown(promptController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 760,
              child: ToolWindowPanel(
                activePanel: WorkbenchToolPanel.resources,
                authorFeedbackStore: registry.resolve<AuthorFeedbackStore>(),
                reviewTaskStore: registry.resolve<ReviewTaskStore>(),
                sceneContext: registry.resolve<AppSceneContextStore>().snapshot,
                characters: workspaceStore.characters,
                scenes: workspaceStore.scenes,
                currentSceneId: workspaceStore.currentScene.id,
                currentChapterId: workspaceStore.currentScene.chapterLabel,
                currentSceneLabel: workspaceStore.currentScene.displayLocation,
                sourceRunId: null,
                sourceRunLabel: null,
                uiState: WorkbenchUiState.defaultHidden,
                settings: settingsStore.snapshot,
                settingsFeedback: settingsStore.feedback,
                settingsHasPersistenceIssue: false,
                canGenerateAi: false,
                isGeneratingAi: false,
                diagnosticReport: null,
                aiToolMode: AiToolMode.rewrite,
                historyEntries: const [],
                aiPromptController: promptController,
                onRetrySecureStore: () async {},
                draftText: '',
                currentSelectionPreview: '',
                selectionDrafts: const [],
                onSelectAiMode: (_) {},
                onAddCurrentSelection: () {},
                onEditSelectionPrompt: (_) {},
                onRemoveSelection: (_) {},
                onGenerateAiSuggestion: () {},
                onReplayAiHistory: (_) {},
                onDeleteAiHistoryEntry: (_) {},
                onClearAiHistory: () {},
                onUpdateCharacterState: (character, update) {
                  workspaceStore.updateCharacter(
                    characterId: character.id,
                    summary: update.currentState,
                    referenceSummary: characterStateHistoryToReferenceSummary(
                      update.history,
                    ),
                  );
                },
                onSyncContext: () {},
                onSelectScene: (_) async {},
                onCreateScene: () {},
                onRenameScene: () {},
                onDeleteScene: () {},
                canDeleteScene: false,
                onOpenSettings: () {},
                onShowAiMetadata: () {},
                runSnapshot: const StoryGenerationRunSnapshot(
                  status: StoryGenerationRunStatus.idle,
                  sceneId: '',
                  sceneLabel: '',
                  headline: '',
                  summary: '',
                  stageSummary: '',
                ),
                isRunActive: false,
                canCancelRun: false,
                canRetryRun: false,
                onRetryRun: () {},
                onDiscardRun: () {},
                onCancelRun: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(CharacterStateCard.cardKey), findsOneWidget);
      expect(find.text('角色状态'), findsOneWidget);
      expect(find.text('柳溪'), findsOneWidget);
      expect(find.text('当前状态'), findsOneWidget);
      expect(find.text('最近变化'), findsOneWidget);

      await tester.enterText(
        find.byKey(CharacterStateCard.stateFieldKey),
        '证人房间后保持警觉，准备逼近线人。',
      );
      await tester.enterText(
        find.byKey(CharacterStateCard.changeFieldKey),
        '手动记录：证词顺序被改写',
      );
      await tester.tap(find.byKey(CharacterStateCard.saveButtonKey));
      await tester.pumpAndSettle();

      final updated = workspaceStore.characters.first;
      expect(updated.summary, '证人房间后保持警觉，准备逼近线人。');
      expect(updated.referenceSummary, contains('状态历史'));
      expect(updated.referenceSummary, contains('手动记录：证词顺序被改写'));
    });
  });
}

void _registerWorkbenchStores(ServiceRegistry registry) {
  final eventBus = AppEventBus();
  final eventLog = AppEventLog();
  final workspaceStore = AppWorkspaceStore(
    storage: InMemoryAppWorkspaceStorage(),
    eventBus: eventBus,
  );
  final settingsStore = AppSettingsStore(storage: InMemoryAppSettingsStorage());
  final draftStore = AppDraftStore(
    storage: InMemoryAppDraftStorage(),
    workspaceStore: workspaceStore,
  );
  final versionStore = AppVersionStore(
    storage: InMemoryAppVersionStorage(),
    workspaceStore: workspaceStore,
  );
  final historyStore = AppAiHistoryStore(
    storage: InMemoryAppAiHistoryStorage(),
    workspaceStore: workspaceStore,
  );
  final sceneContextStore = AppSceneContextStore(
    storage: InMemoryAppSceneContextStorage(),
    workspaceStore: workspaceStore,
  );
  final simulationStore = AppSimulationStore(
    storage: InMemoryAppSimulationStorage(),
    workspaceStore: workspaceStore,
    eventLog: eventLog,
  );
  final generationStore = StoryGenerationStore(
    storage: InMemoryStoryGenerationStorage(),
    workspaceStore: workspaceStore,
  );
  final outlineStore = StoryOutlineStore(
    storage: InMemoryStoryOutlineStorage(),
    workspaceStore: workspaceStore,
  );
  final authorFeedbackStore = AuthorFeedbackStore(
    storage: InMemoryAuthorFeedbackStorage(),
    workspaceStore: workspaceStore,
  );
  final reviewTaskStore = ReviewTaskStore(
    storage: InMemoryReviewTaskStorage(),
    workspaceStore: workspaceStore,
  );
  final runStore = StoryGenerationRunStore(
    settingsStore: settingsStore,
    workspaceStore: workspaceStore,
    generationStore: generationStore,
    sceneContextStore: sceneContextStore,
    outlineStore: outlineStore,
    authorFeedbackStore: authorFeedbackStore,
    storage: InMemoryStoryGenerationRunStorage(),
  );
  registry
    ..registerSingleton<AppEventBus>(eventBus)
    ..registerSingleton<AppEventLog>(eventLog)
    ..registerSingleton<AppWorkspaceStore>(workspaceStore)
    ..registerSingleton<AppSettingsStore>(settingsStore)
    ..registerSingleton<AppDraftStore>(draftStore)
    ..registerSingleton<AppVersionStore>(versionStore)
    ..registerSingleton<AppAiHistoryStore>(historyStore)
    ..registerSingleton<AppSceneContextStore>(sceneContextStore)
    ..registerSingleton<AppSimulationStore>(simulationStore)
    ..registerSingleton<StoryGenerationStore>(generationStore)
    ..registerSingleton<StoryOutlineStore>(outlineStore)
    ..registerSingleton<AuthorFeedbackStore>(authorFeedbackStore)
    ..registerSingleton<ReviewTaskStore>(reviewTaskStore)
    ..registerSingleton<StoryGenerationRunStore>(runStore);
}

StoryGenerationRunStore _registerStoryRunStore(
  ServiceRegistry registry, {
  required StoryGenerationRunStorage runStorage,
}) {
  final runStore = StoryGenerationRunStore(
    settingsStore: registry.resolve<AppSettingsStore>(),
    workspaceStore: registry.resolve<AppWorkspaceStore>(),
    generationStore: registry.resolve<StoryGenerationStore>(),
    sceneContextStore: registry.resolve<AppSceneContextStore>(),
    outlineStore: registry.resolve<StoryOutlineStore>(),
    authorFeedbackStore: registry.resolve<AuthorFeedbackStore>(),
    storage: runStorage,
  );
  registry.registerSingleton<StoryGenerationRunStore>(runStore);
  return runStore;
}
