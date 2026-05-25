import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:novel_writer/app/di/service_registry.dart';
import 'package:novel_writer/app/di/app_providers.dart';
import 'package:novel_writer/app/events/app_event_bus.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/llm/app_llm_request_pool.dart';
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
import 'package:novel_writer/app/state/story_arc_storage.dart';
import 'package:novel_writer/app/state/story_outline_storage.dart';
import 'package:novel_writer/app/state/story_outline_store.dart';
import 'package:novel_writer/features/author_feedback/data/author_feedback_storage.dart';
import 'package:novel_writer/features/author_feedback/data/author_feedback_store.dart';
import 'package:novel_writer/features/review_tasks/data/review_task_storage.dart';
import 'package:novel_writer/features/review_tasks/data/review_task_store.dart';
import 'package:novel_writer/features/writing_stats/data/writing_stats_store.dart';
import 'package:novel_writer/features/writing_stats/data/writing_stats_storage.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'fake_app_llm_client.dart';

/// Creates a [ServiceRegistry] with in-memory storages and a fake LLM client.
///
/// Use in widget tests that pump [NovelWriterApp]:
/// ```dart
/// setUp(() {
///   NovelWriterApp.debugRegistryOverride = createTestRegistry();
/// });
/// tearDown(() {
///   NovelWriterApp.debugRegistryOverride = null;
/// });
/// ```
ServiceRegistry createTestRegistry({AppLlmClient? llmClient}) {
  final registry = ServiceRegistry();

  // Infrastructure
  registry.registerFactory<AppEventBus>((_) => AppEventBus());
  registry.registerFactory<AppEventLog>((_) => AppEventLog());
  registry.registerFactory<AppLlmClient>(
    (_) => llmClient ?? FakeAppLlmClient(),
  );
  registry.registerFactory<AppLlmRequestPool>(
    (_) => AppLlmRequestPool(maxConcurrent: 3),
  );

  // Core stores with in-memory storages
  registry.registerFactory<AppWorkspaceStore>(
    (r) => AppWorkspaceStore(
      storage: InMemoryAppWorkspaceStorage(),
      eventBus: r.resolve<AppEventBus>(),
    ),
  );
  registry.registerFactory<AppAiHistoryStore>(
    (r) => AppAiHistoryStore(
      storage: InMemoryAppAiHistoryStorage(),
      workspaceStore: r.resolve<AppWorkspaceStore>(),
      eventBus: r.resolve<AppEventBus>(),
    ),
  );
  registry.registerFactory<AppSceneContextStore>(
    (r) => AppSceneContextStore(
      storage: InMemoryAppSceneContextStorage(),
      workspaceStore: r.resolve<AppWorkspaceStore>(),
      eventBus: r.resolve<AppEventBus>(),
    ),
  );
  registry.registerFactory<AppSimulationStore>(
    (r) => AppSimulationStore(
      storage: InMemoryAppSimulationStorage(),
      workspaceStore: r.resolve<AppWorkspaceStore>(),
      eventBus: r.resolve<AppEventBus>(),
    ),
  );
  registry.registerFactory<AppDraftStore>(
    (r) => AppDraftStore(
      storage: InMemoryAppDraftStorage(),
      workspaceStore: r.resolve<AppWorkspaceStore>(),
      eventBus: r.resolve<AppEventBus>(),
    ),
  );
  registry.registerFactory<AppVersionStore>(
    (r) => AppVersionStore(
      storage: InMemoryAppVersionStorage(),
      workspaceStore: r.resolve<AppWorkspaceStore>(),
      eventBus: r.resolve<AppEventBus>(),
    ),
  );
  registry.registerFactory<WritingStatsStore>(
    (r) => WritingStatsStore(
      storage: _InMemoryWritingStatsStorage(),
      workspaceStore: r.resolve<AppWorkspaceStore>(),
      eventBus: r.resolve<AppEventBus>(),
    ),
  );
  registry.registerFactory<StoryOutlineStore>(
    (r) => StoryOutlineStore(
      storage: InMemoryStoryOutlineStorage(),
      workspaceStore: r.resolve<AppWorkspaceStore>(),
      eventBus: r.resolve<AppEventBus>(),
    ),
  );
  registry.registerFactory<StoryGenerationStore>(
    (r) => StoryGenerationStore(
      storage: InMemoryStoryGenerationStorage(),
      workspaceStore: r.resolve<AppWorkspaceStore>(),
      eventBus: r.resolve<AppEventBus>(),
    ),
  );
  registry.registerFactory<AppSettingsStore>(
    (r) => AppSettingsStore(
      storage: InMemoryAppSettingsStorage(),
      llmClient: r.resolve<AppLlmClient>(),
      requestPool: r.resolve<AppLlmRequestPool>(),
      eventLog: r.resolve<AppEventLog>(),
      eventBus: r.resolve<AppEventBus>(),
    ),
  );

  // Feature stores with in-memory storages
  registry.registerFactory<AuthorFeedbackStore>(
    (r) => AuthorFeedbackStore(
      storage: InMemoryAuthorFeedbackStorage(),
      workspaceStore: r.resolve<AppWorkspaceStore>(),
      eventBus: r.resolve<AppEventBus>(),
    ),
  );
  registry.registerFactory<ReviewTaskStore>(
    (r) => ReviewTaskStore(
      storage: InMemoryReviewTaskStorage(),
      workspaceStore: r.resolve<AppWorkspaceStore>(),
      eventBus: r.resolve<AppEventBus>(),
    ),
  );
  registry.registerFactory<StoryGenerationRunStore>(
    (r) => StoryGenerationRunStore(
      settingsStore: r.resolve<AppSettingsStore>(),
      workspaceStore: r.resolve<AppWorkspaceStore>(),
      generationStore: r.resolve<StoryGenerationStore>(),
      sceneContextStore: r.resolve<AppSceneContextStore>(),
      outlineStore: r.resolve<StoryOutlineStore>(),
      authorFeedbackStore: r.resolve<AuthorFeedbackStore>(),
      reviewTaskStore: r.resolve<ReviewTaskStore>(),
      eventBus: r.resolve<AppEventBus>(),
      storage: InMemoryStoryGenerationRunStorage(),
    ),
  );

  return registry;
}

/// Creates in-memory overrides for tests that exercise native Riverpod
/// provider bootstrapping without [ServiceRegistry].
List<Override> createTestProviderOverrides({AppLlmClient? llmClient}) {
  return [
    databaseProvider.overrideWith((ref) {
      final db = sqlite3.sqlite3.openInMemory();
      ref.onDispose(db.dispose);
      return db;
    }),
    appLlmClientProvider.overrideWith((ref) => llmClient ?? FakeAppLlmClient()),
    appWorkspaceStorageProvider.overrideWith(
      (ref) => InMemoryAppWorkspaceStorage(),
    ),
    appSettingsStorageProvider.overrideWith(
      (ref) => InMemoryAppSettingsStorage(),
    ),
    appVersionStorageProvider.overrideWith(
      (ref) => InMemoryAppVersionStorage(),
    ),
    appAiHistoryStorageProvider.overrideWith(
      (ref) => InMemoryAppAiHistoryStorage(),
    ),
    writingStatsStorageProvider.overrideWith(
      (ref) => _InMemoryWritingStatsStorage(),
    ),
    appDraftStorageProvider.overrideWith((ref) => InMemoryAppDraftStorage()),
    appSceneContextStorageProvider.overrideWith(
      (ref) => InMemoryAppSceneContextStorage(),
    ),
    appSimulationStorageProvider.overrideWith(
      (ref) => InMemoryAppSimulationStorage(),
    ),
    storyOutlineStorageProvider.overrideWith(
      (ref) => InMemoryStoryOutlineStorage(),
    ),
    storyGenerationStorageProvider.overrideWith(
      (ref) => InMemoryStoryGenerationStorage(),
    ),
    storyArcStorageProvider.overrideWith((ref) => InMemoryStoryArcStorage()),
    storyGenerationRunStorageProvider.overrideWith(
      (ref) => InMemoryStoryGenerationRunStorage(),
    ),
  ];
}

class _InMemoryWritingStatsStorage implements WritingStatsStorage {
  final List<Map<String, Object?>> dailyStats = [];
  final Map<String, Map<String, Object?>> projectStats = {};
  final Map<String, Map<String, Object?>> goals = {};

  @override
  Future<List<Map<String, Object?>>> loadDailyStats({
    required String projectId,
    String? fromDate,
    String? toDate,
  }) async {
    return [
      for (final row in dailyStats)
        if (row['projectId'] == projectId) Map<String, Object?>.from(row),
    ];
  }

  @override
  Future<Map<String, Object?>?> loadProjectStat({
    required String projectId,
  }) async {
    final row = projectStats[projectId];
    return row == null ? null : Map<String, Object?>.from(row);
  }

  @override
  Future<List<Map<String, Object?>>> loadGoals({String? projectId}) async {
    return [
      for (final row in goals.values)
        if (projectId == null ||
            projectId.isEmpty ||
            row['projectId'] == projectId ||
            row['projectId'] == '')
          Map<String, Object?>.from(row),
    ];
  }

  @override
  Future<void> upsertDailyStat(Map<String, Object?> row) async {
    dailyStats.removeWhere(
      (existing) =>
          existing['date'] == row['date'] &&
          existing['sceneScopeId'] == row['sceneScopeId'],
    );
    dailyStats.add(Map<String, Object?>.from(row));
  }

  @override
  Future<void> upsertProjectStat(Map<String, Object?> row) async {
    projectStats[row['projectId']?.toString() ?? ''] =
        Map<String, Object?>.from(row);
  }

  @override
  Future<void> upsertGoal(Map<String, Object?> goal) async {
    goals[goal['id']?.toString() ?? ''] = Map<String, Object?>.from(goal);
  }

  @override
  Future<void> deleteGoal({required String goalId}) async {
    goals.remove(goalId);
  }

  @override
  Future<void> clearProject(String projectId) async {
    dailyStats.removeWhere((row) => row['projectId'] == projectId);
    projectStats.remove(projectId);
    goals.removeWhere((_, row) => row['projectId'] == projectId);
  }
}
