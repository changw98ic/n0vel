import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/logging/app_event_log.dart';
import 'package:novel_writer/app/logging/app_event_log_storage.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';
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
import 'package:novel_writer/features/author_feedback/data/author_feedback_storage.dart';
import 'package:novel_writer/features/author_feedback/data/author_feedback_store.dart';
import 'package:novel_writer/features/review_tasks/data/review_task_storage.dart';
import 'package:novel_writer/features/review_tasks/data/review_task_store.dart';
import 'package:novel_writer/features/story_generation/data/pipeline_stage_runner_impl.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';
import 'package:novel_writer/features/workbench/domain/workbench_orchestrator.dart';

void main() {
  test(
    'normal workbench generation starts the StoryPipeline instead of a one-off completion',
    () async {
      final llmClient = _CountingLlmClient();
      final eventLog = AppEventLog(storage: _MemoryEventLogStorage());
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: llmClient,
        eventLog: eventLog,
      );
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final generationStore = StoryGenerationStore(
        storage: InMemoryStoryGenerationStorage(),
        workspaceStore: workspaceStore,
      );
      await generationStore.waitUntilReady();
      await settingsStore.save(
        providerName: 'local test',
        baseUrl: 'http://127.0.0.1:3456/v1',
        model: 'test-model',
        apiKey: '',
        timeoutMs: 1000,
      );

      final pipeline = _PipelineOnlyRunner(settingsStore: settingsStore);
      final runStore = StoryGenerationRunStore(
        settingsStore: settingsStore,
        workspaceStore: workspaceStore,
        generationStore: generationStore,
        storage: InMemoryStoryGenerationRunStorage(),
        orchestratorFactory: (_) => pipeline,
      );
      await runStore.ready;
      final orchestrator = WorkbenchOrchestrator(
        draftStore: AppDraftStore(
          storage: InMemoryAppDraftStorage(),
          workspaceStore: workspaceStore,
        ),
        versionStore: AppVersionStore(
          storage: InMemoryAppVersionStorage(),
          workspaceStore: workspaceStore,
        ),
        settingsStore: settingsStore,
        workspaceStore: workspaceStore,
        historyStore: AppAiHistoryStore(
          storage: InMemoryAppAiHistoryStorage(),
          workspaceStore: workspaceStore,
        ),
        sceneContextStore: AppSceneContextStore(
          storage: InMemoryAppSceneContextStorage(),
          workspaceStore: workspaceStore,
        ),
        simulationStore: AppSimulationStore(
          storage: InMemoryAppSimulationStorage(),
          workspaceStore: workspaceStore,
          eventLog: eventLog,
        ),
        authorFeedbackStore: AuthorFeedbackStore(
          storage: InMemoryAuthorFeedbackStorage(),
          workspaceStore: workspaceStore,
        ),
        reviewTaskStore: ReviewTaskStore(
          storage: InMemoryReviewTaskStorage(),
          workspaceStore: workspaceStore,
        ),
        storyRunStore: runStore,
        eventLog: eventLog,
      );
      addTearDown(() {
        orchestrator.dispose();
        runStore.dispose();
        generationStore.dispose();
        workspaceStore.dispose();
        settingsStore.dispose();
      });

      final command = await orchestrator.prepareAiGeneration('保留谜团，不要改写旧稿。');

      expect(command, isA<ShowAiSceneRunResult>());
      expect(pipeline.calls, 1);
      expect(llmClient.chatCalls, 0);
      expect(runStore.snapshot.candidateProse, 'pipeline prose');
      expect(pipeline.lastBrief!.metadata['authorRevisionRequests'], [
        '保留谜团，不要改写旧稿。',
      ]);
    },
  );
}

class _PipelineOnlyRunner extends PipelineStageRunnerImpl {
  _PipelineOnlyRunner({required super.settingsStore});

  int calls = 0;
  SceneBrief? lastBrief;

  @override
  Future<SceneRuntimeOutput> runScene(
    SceneBrief brief, {
    ProjectMaterialSnapshot? materials,
    void Function()? onSpeculationReady,
  }) async {
    calls += 1;
    lastBrief = brief;
    return SceneRuntimeOutput(
      brief: brief,
      resolvedCast: const [],
      director: const SceneDirectorOutput(text: 'pipeline director'),
      roleOutputs: const [],
      prose: const SceneProseDraft(text: 'pipeline prose', attempt: 1),
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
}

class _CountingLlmClient implements AppLlmClient {
  int chatCalls = 0;

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    chatCalls += 1;
    return const AppLlmChatResult.success(text: 'unexpected direct completion');
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) {
    chatCalls += 1;
    return Stream<String>.value('unexpected direct completion');
  }
}

class _MemoryEventLogStorage implements AppEventLogStorage {
  @override
  Future<void> write(AppEventLogEntry entry) async {}
}
