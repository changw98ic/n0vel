import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:novel_writer/features/review_tasks/data/review_task_storage.dart';
import 'package:novel_writer/features/review_tasks/data/review_task_store.dart';
import 'package:novel_writer/features/workbench/presentation/workbench_shell_page.dart';

void main() {
  group('WorkbenchShellPage restored story runs', () {
    late ServiceRegistry registry;
    late AppWorkspaceStore workspaceStore;
    late StoryGenerationRunStore runStore;

    tearDown(() {
      registry.disposeAll();
    });

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
          overrides: [serviceRegistryProvider.overrideWithValue(registry)],
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
            overrides: [serviceRegistryProvider.overrideWithValue(registry)],
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

  group('WorkbenchShellPage three-pane layout', () {
    late ServiceRegistry registry;

    tearDown(() {
      registry.disposeAll();
    });

    testWidgets('renders editor pane filling available space', (tester) async {
      tester.view.physicalSize = const Size(1280, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      registry = ServiceRegistry();
      _registerWorkbenchStores(registry);
      final runStorage = InMemoryStoryGenerationRunStorage();
      _registerStoryRunStore(registry, runStorage: runStorage);
      await registry.resolve<StoryGenerationRunStore>().ready;
      final workspaceStore = registry.resolve<AppWorkspaceStore>();
      workspaceStore.createProject(projectName: '布局测试');
      workspaceStore.createScene('第一章');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [serviceRegistryProvider.overrideWithValue(registry)],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const WorkbenchShellPage(),
          ),
        ),
      );
      await tester.pump();

      // Verify editor pane exists and no placeholder panes
      expect(find.byType(Row), findsWidgets);
      expect(find.byIcon(Icons.summarize_outlined), findsNothing);
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
    ..registerSingleton<ReviewTaskStore>(reviewTaskStore);
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
