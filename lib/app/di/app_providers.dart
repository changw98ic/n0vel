import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import '../../features/author_feedback/data/author_feedback_store.dart';
import '../../features/review_tasks/data/review_task_store.dart';
import '../../features/story_generation/data/character_memory_store.dart';
import '../../features/story_generation/data/character_memory_store_io.dart';
import '../../features/story_generation/data/roleplay_session_store.dart';
import '../../features/story_generation/data/roleplay_session_store_io.dart';
import '../../features/writing_stats/data/writing_stats_store.dart';
import '../../features/writing_stats/data/writing_stats_storage.dart';
import '../events/app_event_bus.dart';
import '../logging/app_event_log.dart';
import '../llm/app_llm_client.dart';
import '../llm/app_llm_request_pool.dart';
import '../state/app_ai_history_store.dart';
import '../state/app_ai_history_storage.dart';
import '../state/app_authoring_storage_io_support.dart';
import '../state/app_draft_storage.dart';
import '../state/app_draft_store.dart';
import '../state/app_scene_context_storage.dart';
import '../state/app_scene_context_store.dart';
import '../state/app_settings_storage.dart';
import '../state/app_settings_store.dart';
import '../state/app_simulation_storage.dart';
import '../state/app_simulation_store.dart';
import '../state/app_version_store.dart';
import '../state/app_version_storage.dart';
import '../state/app_workspace_storage.dart';
import '../state/app_workspace_store.dart';
import '../state/fulltext_search_service.dart';
import '../state/story_generation_run_storage.dart';
import '../state/story_generation_run_store.dart';
import '../state/story_generation_store.dart';
import '../state/story_generation_storage.dart';
import '../state/story_outline_store.dart';
import '../state/story_outline_storage.dart';
import '../state/story_arc_store.dart';
import '../state/story_arc_storage.dart';
import 'service_registry.dart';

/// Root provider that holds the [ServiceRegistry] reference.
///
/// During M4-02/M4-03 coexistence, this remains for legacy stores that
/// have not yet been migrated to native Riverpod providers.
/// Will be removed once all stores are native Riverpod providers.
final serviceRegistryProvider = Provider<ServiceRegistry>((ref) {
  throw StateError('serviceRegistryProvider not overridden in ProviderScope');
});

// ─────────────────────────────────────────────────────────────────────────────
// Foundational infrastructure providers (M4-02 native providers)
// ─────────────────────────────────────────────────────────────────────────────

/// Native Riverpod provider for [AppEventBus].
///
/// Replaces registry-based resolution. Disposal is handled by Riverpod.
final appEventBusProvider = Provider<AppEventBus>((ref) {
  final bus = AppEventBus();
  ref.onDispose(bus.dispose);
  return bus;
});

/// Native Riverpod provider for [AppEventLog].
///
/// Replaces registry-based resolution. No disposal needed.
final appEventLogProvider = Provider<AppEventLog>((ref) {
  return AppEventLog();
});

/// Native Riverpod provider for [AppLlmClient].
///
/// Replaces registry-based resolution. No disposal needed.
final appLlmClientProvider = Provider<AppLlmClient>((ref) {
  return createCachedAppLlmClient();
});

/// Native Riverpod provider for [AppLlmRequestPool].
///
/// Replaces registry-based resolution. No disposal needed.
final appLlmRequestPoolProvider = Provider<AppLlmRequestPool>((ref) {
  return AppLlmRequestPool(maxConcurrent: 3);
});

/// Native Riverpod provider for the authoring database.
///
/// Disposal is handled by Riverpod via [ref.onDispose].
final databaseProvider = Provider<sqlite3.Database>((ref) {
  final db = openAuthoringDatabase(resolveAuthoringDbPath());
  ref.onDispose(db.dispose);
  return db;
});

/// Native Riverpod provider for [FulltextSearchService].
///
/// Depends on [databaseProvider]. Lifecycle is tied to database disposal.
final fulltextSearchServiceProvider = Provider<FulltextSearchService>((ref) {
  final db = ref.watch(databaseProvider);
  return FulltextSearchService(db: db);
});

// -- M4-05 core leaf storage providers --
// These allow tests to inject in-memory storage instead of production defaults.

/// Native Riverpod provider for [AppVersionStorage].
final appVersionStorageProvider = Provider<AppVersionStorage>((ref) {
  return createDefaultAppVersionStorage();
});

/// Native Riverpod provider for [AppAiHistoryStorage].
final appAiHistoryStorageProvider = Provider<AppAiHistoryStorage>((ref) {
  return createDefaultAppAiHistoryStorage();
});

/// Native Riverpod provider for [WritingStatsStorage].
final writingStatsStorageProvider = Provider<WritingStatsStorage>((ref) {
  return createDefaultWritingStatsStorage();
});

/// Native Riverpod provider for [AppDraftStorage].
final appDraftStorageProvider = Provider<AppDraftStorage>((ref) {
  return createDefaultAppDraftStorage();
});

/// Native Riverpod provider for [AppSceneContextStorage].
final appSceneContextStorageProvider = Provider<AppSceneContextStorage>((ref) {
  return createDefaultAppSceneContextStorage();
});

/// Native Riverpod provider for [AppSimulationStorage].
final appSimulationStorageProvider = Provider<AppSimulationStorage>((ref) {
  return createDefaultAppSimulationStorage();
});

/// Native Riverpod provider for [StoryOutlineStorage].
final storyOutlineStorageProvider = Provider<StoryOutlineStorage>((ref) {
  return createDefaultStoryOutlineStorage();
});

/// Native Riverpod provider for [StoryGenerationStorage].
final storyGenerationStorageProvider = Provider<StoryGenerationStorage>((ref) {
  return createDefaultStoryGenerationStorage();
});

/// Native Riverpod provider for [StoryArcStorage].
final storyArcStorageProvider = Provider<StoryArcStorage>((ref) {
  return createDefaultStoryArcStorage();
});

/// Native Riverpod provider for [AppSettingsStorage].
final appSettingsStorageProvider = Provider<AppSettingsStorage>((ref) {
  return createDefaultAppSettingsStorage();
});

/// Native Riverpod provider for [AppWorkspaceStorage].
final appWorkspaceStorageProvider = Provider<AppWorkspaceStorage>((ref) {
  return createDefaultAppWorkspaceStorage();
});

/// Native Riverpod provider for [StoryGenerationRunStorage].
final storyGenerationRunStorageProvider = Provider<StoryGenerationRunStorage>((
  ref,
) {
  return createDefaultStoryGenerationRunStorage();
});

// -- Core store providers --
// These providers expose ServiceRegistry-owned stores through Riverpod
// Notifiers. The stores are still the existing controllers for this migration
// step, but rebuilds are now driven by NotifierProvider instead of ad-hoc
// Provider invalidation or framework-owned disposal semantics.

/// Bridge notifier that exposes a [ServiceRegistry]-owned [Listenable] store
/// through Riverpod's [NotifierProvider].
///
/// `updateShouldNotify` always returns `true` because stores use a mutable
/// object pattern — the same instance is re-assigned as state on every
/// `notifyListeners()` call. Reference equality (`previous == next`) would
/// always be `true`, so we rely on the store's own `_version` counter for
/// future selective notification optimizations.
///
/// The real optimization path is Riverpod `select()` at the widget level,
/// which will become the default once stores migrate to native Riverpod
/// `Notifier`s instead of bridging legacy `Listenable` stores.
abstract class RegistryStoreNotifier<T extends Listenable> extends Notifier<T> {
  @override
  T build() {
    final store = ref.watch(serviceRegistryProvider).resolve<T>();
    void listener() => state = store;
    store.addListener(listener);
    ref.onDispose(() => store.removeListener(listener));
    return store;
  }

  @override
  bool updateShouldNotify(T previous, T next) => true;
}

/// Native Riverpod [NotifierProvider] for [AppWorkspaceStore].
///
/// Bridges [AppWorkspaceStore.notifyListeners()] to Riverpod rebuilds.
/// The store is constructed from native Riverpod dependencies.
class AppWorkspaceStoreNotifier extends Notifier<AppWorkspaceStore> {
  @override
  AppWorkspaceStore build() {
    final storage = ref.watch(appWorkspaceStorageProvider);
    final eventBus = ref.watch(appEventBusProvider);
    final roleplaySessionStore = ref.watch(roleplaySessionStoreProvider);
    final characterMemoryStore = ref.watch(characterMemoryStoreProvider);
    final store = AppWorkspaceStore(
      storage: storage,
      eventBus: eventBus,
      projectDeletionCleaners: [
        (projectId) => roleplaySessionStore.clearProject(projectId),
        (projectId) => characterMemoryStore.clearProject(projectId),
      ],
    );
    void listener() => state = store;
    store.addListener(listener);
    ref.onDispose(() {
      store.removeListener(listener);
      store.dispose();
    });
    return store;
  }

  @override
  bool updateShouldNotify(AppWorkspaceStore previous, AppWorkspaceStore next) =>
      true;
}

final appWorkspaceStoreProvider =
    NotifierProvider<AppWorkspaceStoreNotifier, AppWorkspaceStore>(
      AppWorkspaceStoreNotifier.new,
    );

/// Native Riverpod [NotifierProvider] for [AppSettingsStore].
///
/// Bridges [AppSettingsStore.notifyListeners()] to Riverpod rebuilds.
/// The store is constructed from native Riverpod dependencies.
class AppSettingsStoreNotifier extends Notifier<AppSettingsStore> {
  @override
  AppSettingsStore build() {
    final storage = ref.watch(appSettingsStorageProvider);
    final llmClient = ref.watch(appLlmClientProvider);
    final requestPool = ref.watch(appLlmRequestPoolProvider);
    final eventLog = ref.watch(appEventLogProvider);
    final eventBus = ref.watch(appEventBusProvider);
    final store = AppSettingsStore(
      storage: storage,
      llmClient: llmClient,
      requestPool: requestPool,
      eventLog: eventLog,
      eventBus: eventBus,
    );
    void listener() => state = store;
    store.addListener(listener);
    ref.onDispose(() {
      store.removeListener(listener);
      store.dispose();
    });
    return store;
  }

  @override
  bool updateShouldNotify(AppSettingsStore previous, AppSettingsStore next) =>
      true;
}

final appSettingsStoreProvider =
    NotifierProvider<AppSettingsStoreNotifier, AppSettingsStore>(
      AppSettingsStoreNotifier.new,
    );

final appDraftStoreProvider = Provider<AppDraftStore>((ref) {
  final workspaceStore = ref.watch(appWorkspaceStoreProvider);
  final eventBus = ref.watch(appEventBusProvider);
  final storage = ref.watch(appDraftStorageProvider);
  final store = AppDraftStore(
    storage: storage,
    workspaceStore: workspaceStore,
    eventBus: eventBus,
  );
  ref.onDispose(store.dispose);
  return store;
});

final appVersionStoreProvider = Provider<AppVersionStore>((ref) {
  final workspaceStore = ref.watch(appWorkspaceStoreProvider);
  final eventBus = ref.watch(appEventBusProvider);
  final storage = ref.watch(appVersionStorageProvider);
  final store = AppVersionStore(
    storage: storage,
    workspaceStore: workspaceStore,
    eventBus: eventBus,
  );
  ref.onDispose(store.dispose);
  return store;
});

final appAiHistoryStoreProvider = Provider<AppAiHistoryStore>((ref) {
  final workspaceStore = ref.watch(appWorkspaceStoreProvider);
  final eventBus = ref.watch(appEventBusProvider);
  final storage = ref.watch(appAiHistoryStorageProvider);
  final store = AppAiHistoryStore(
    storage: storage,
    workspaceStore: workspaceStore,
    eventBus: eventBus,
  );
  ref.onDispose(store.dispose);
  return store;
});

final appSceneContextStoreProvider = Provider<AppSceneContextStore>((ref) {
  final workspaceStore = ref.watch(appWorkspaceStoreProvider);
  final eventBus = ref.watch(appEventBusProvider);
  final storage = ref.watch(appSceneContextStorageProvider);
  final store = AppSceneContextStore(
    storage: storage,
    workspaceStore: workspaceStore,
    eventBus: eventBus,
  );
  ref.onDispose(store.dispose);
  return store;
});

final appSimulationStoreProvider = Provider<AppSimulationStore>((ref) {
  final workspaceStore = ref.watch(appWorkspaceStoreProvider);
  final eventLog = ref.watch(appEventLogProvider);
  final storage = ref.watch(appSimulationStorageProvider);
  final store = AppSimulationStore(
    storage: storage,
    workspaceStore: workspaceStore,
    eventLog: eventLog,
  );
  ref.onDispose(store.dispose);
  return store;
});

final storyOutlineStoreProvider = Provider<StoryOutlineStore>((ref) {
  final workspaceStore = ref.watch(appWorkspaceStoreProvider);
  final eventBus = ref.watch(appEventBusProvider);
  final storage = ref.watch(storyOutlineStorageProvider);
  final store = StoryOutlineStore(
    storage: storage,
    workspaceStore: workspaceStore,
    eventBus: eventBus,
  );
  ref.onDispose(store.dispose);
  return store;
});

final storyGenerationStoreProvider = Provider<StoryGenerationStore>((ref) {
  final workspaceStore = ref.watch(appWorkspaceStoreProvider);
  final eventBus = ref.watch(appEventBusProvider);
  final storage = ref.watch(storyGenerationStorageProvider);
  final store = StoryGenerationStore(
    storage: storage,
    workspaceStore: workspaceStore,
    eventBus: eventBus,
  );
  ref.onDispose(store.dispose);
  return store;
});

final storyArcStoreProvider = Provider<StoryArcStore>((ref) {
  final workspaceStore = ref.watch(appWorkspaceStoreProvider);
  final eventBus = ref.watch(appEventBusProvider);
  final storage = ref.watch(storyArcStorageProvider);
  final store = StoryArcStore(
    storage: storage,
    workspaceStore: workspaceStore,
    eventBus: eventBus,
  );
  ref.onDispose(store.dispose);
  return store;
});

// -- Feature store providers --
// M4-04: AuthorFeedbackStore and ReviewTaskStore migrated to native Riverpod

/// Native Riverpod provider for [AuthorFeedbackStore].
///
/// Replaces registry-based resolution. The store owns its lifecycle and
/// must be disposed when the provider container is disposed.
final authorFeedbackStoreProvider = Provider<AuthorFeedbackStore>((ref) {
  final workspaceStore = ref.watch(appWorkspaceStoreProvider);
  final eventBus = ref.watch(appEventBusProvider);
  final store = AuthorFeedbackStore(
    workspaceStore: workspaceStore,
    eventBus: eventBus,
  );
  ref.onDispose(store.dispose);
  return store;
});

/// Native Riverpod provider for [ReviewTaskStore].
///
/// Replaces registry-based resolution. The store owns its lifecycle and
/// must be disposed when the provider container is disposed.
final reviewTaskStoreProvider = Provider<ReviewTaskStore>((ref) {
  final workspaceStore = ref.watch(appWorkspaceStoreProvider);
  final eventBus = ref.watch(appEventBusProvider);
  final store = ReviewTaskStore(
    workspaceStore: workspaceStore,
    eventBus: eventBus,
  );
  ref.onDispose(store.dispose);
  return store;
});

// -- M4-10 story generation run store provider --

/// Native Riverpod [NotifierProvider] for [StoryGenerationRunStore].
///
/// Bridges [StoryGenerationRunStore.notifyListeners()] to Riverpod rebuilds.
/// The store is constructed from native Riverpod dependencies.
class StoryGenerationRunStoreNotifier
    extends Notifier<StoryGenerationRunStore> {
  @override
  StoryGenerationRunStore build() {
    final settingsStore = ref.watch(appSettingsStoreProvider);
    final workspaceStore = ref.watch(appWorkspaceStoreProvider);
    final generationStore = ref.watch(storyGenerationStoreProvider);
    final sceneContextStore = ref.watch(appSceneContextStoreProvider);
    final outlineStore = ref.watch(storyOutlineStoreProvider);
    final authorFeedbackStore = ref.watch(authorFeedbackStoreProvider);
    final roleplaySessionStore = ref.watch(roleplaySessionStoreProvider);
    final characterMemoryStore = ref.watch(characterMemoryStoreProvider);
    final reviewTaskStore = ref.watch(reviewTaskStoreProvider);
    final eventBus = ref.watch(appEventBusProvider);
    final storage = ref.watch(storyGenerationRunStorageProvider);
    final store = StoryGenerationRunStore(
      settingsStore: settingsStore,
      workspaceStore: workspaceStore,
      generationStore: generationStore,
      sceneContextStore: sceneContextStore,
      outlineStore: outlineStore,
      authorFeedbackStore: authorFeedbackStore,
      roleplaySessionStore: roleplaySessionStore,
      characterMemoryStore: characterMemoryStore,
      reviewTaskStore: reviewTaskStore,
      eventBus: eventBus,
      storage: storage,
    );
    void listener() => state = store;
    store.addListener(listener);
    ref.onDispose(() {
      store.removeListener(listener);
      store.dispose();
    });
    return store;
  }

  @override
  bool updateShouldNotify(
    StoryGenerationRunStore previous,
    StoryGenerationRunStore next,
  ) => true;
}

final storyGenerationRunStoreProvider =
    NotifierProvider<StoryGenerationRunStoreNotifier, StoryGenerationRunStore>(
      StoryGenerationRunStoreNotifier.new,
    );

// -- Writing stats store provider (M4-05 native) --

final writingStatsStoreProvider = Provider<WritingStatsStore>((ref) {
  final workspaceStore = ref.watch(appWorkspaceStoreProvider);
  final eventBus = ref.watch(appEventBusProvider);
  final storage = ref.watch(writingStatsStorageProvider);
  final store = WritingStatsStore(
    storage: storage,
    workspaceStore: workspaceStore,
    eventBus: eventBus,
  );
  ref.onDispose(store.dispose);
  return store;
});

// ─────────────────────────────────────────────────────────────────────────────
// DB-backed stores (M4-03 native providers)
// Native Riverpod providers backed by [databaseProvider].
// ─────────────────────────────────────────────────────────────────────────────

/// Native Riverpod provider for [RoleplaySessionStore].
///
/// Backed by [databaseProvider]. The store interface has no `dispose()` method;
/// lifecycle is tied to the database provider.
final roleplaySessionStoreProvider = Provider<RoleplaySessionStore>((ref) {
  final db = ref.watch(databaseProvider);
  return RoleplaySessionStoreIO(db: db);
});

/// Native Riverpod provider for [CharacterMemoryStore].
///
/// Backed by [databaseProvider]. The store interface has no `dispose()` method;
/// lifecycle is tied to the database provider.
final characterMemoryStoreProvider = Provider<CharacterMemoryStore>((ref) {
  final db = ref.watch(databaseProvider);
  return CharacterMemoryStoreIO(db: db);
});

// ─────────────────────────────────────────────────────────────────────────────
// App bootstrap helper for M4-02/M4-03 coexistence
// ─────────────────────────────────────────────────────────────────────────────

/// Returns ProviderScope overrides that make native foundational providers
/// share the same singleton instances as [ServiceRegistry].
///
/// This prevents duplicate singletons during app coexistence, where both the
/// registry and native providers exist. The registry remains the disposer for
/// shared instances; Riverpod overrides do not double-dispose them.
///
/// Use lazy `overrideWith` instead of eager `overrideWithValue` so that
/// foundational instances are created only when first accessed through Riverpod,
/// preserving the original startup timing.
List<Override> appProviderOverridesForRegistry(ServiceRegistry registry) {
  return [
    serviceRegistryProvider.overrideWithValue(registry),
    appEventBusProvider.overrideWith((ref) => registry.resolve<AppEventBus>()),
    appEventLogProvider.overrideWith((ref) => registry.resolve<AppEventLog>()),
    appLlmClientProvider.overrideWith(
      (ref) => registry.resolve<AppLlmClient>(),
    ),
    appLlmRequestPoolProvider.overrideWith(
      (ref) => registry.resolve<AppLlmRequestPool>(),
    ),
    databaseProvider.overrideWith(
      (ref) => registry.resolve<sqlite3.Database>(),
    ),
    fulltextSearchServiceProvider.overrideWith(
      (ref) => registry.resolve<FulltextSearchService>(),
    ),
    // DB-backed stores: use registry-owned instances during normal app bootstrap
    roleplaySessionStoreProvider.overrideWith(
      (ref) => registry.resolve<RoleplaySessionStore>(),
    ),
    characterMemoryStoreProvider.overrideWith(
      (ref) => registry.resolve<CharacterMemoryStore>(),
    ),
    // M4-04 feature stores: use registry-owned instances during normal app bootstrap
    // This is required because StoryGenerationRunStore remains registry-backed
    // and resolves these stores from ServiceRegistry.
    // Do not double-dispose: registry remains the disposer for shared instances.
    authorFeedbackStoreProvider.overrideWith(
      (ref) => registry.resolve<AuthorFeedbackStore>(),
    ),
    reviewTaskStoreProvider.overrideWith(
      (ref) => registry.resolve<ReviewTaskStore>(),
    ),
    // M4-05 core leaf stores: use registry-owned instances during normal app bootstrap
    // Do not double-dispose: registry remains the disposer for shared instances.
    appVersionStoreProvider.overrideWith(
      (ref) => registry.resolve<AppVersionStore>(),
    ),
    writingStatsStoreProvider.overrideWith(
      (ref) => registry.resolve<WritingStatsStore>(),
    ),
    appAiHistoryStoreProvider.overrideWith(
      (ref) => registry.resolve<AppAiHistoryStore>(),
    ),
    // M4-06 workspace/session stores: use registry-owned instances during normal app bootstrap
    // Do not double-dispose: registry remains the disposer for shared instances.
    appDraftStoreProvider.overrideWith(
      (ref) => registry.resolve<AppDraftStore>(),
    ),
    appSceneContextStoreProvider.overrideWith(
      (ref) => registry.resolve<AppSceneContextStore>(),
    ),
    appSimulationStoreProvider.overrideWith(
      (ref) => registry.resolve<AppSimulationStore>(),
    ),
    // M4-07 story core stores: use registry-owned instances during normal app bootstrap
    // Do not double-dispose: registry remains the disposer for shared instances.
    storyOutlineStoreProvider.overrideWith(
      (ref) => registry.resolve<StoryOutlineStore>(),
    ),
    storyGenerationStoreProvider.overrideWith(
      (ref) => registry.resolve<StoryGenerationStore>(),
    ),
    storyArcStoreProvider.overrideWith(
      (ref) => registry.resolve<StoryArcStore>(),
    ),
    // M4-08 settings store: use registry-owned instance during normal app bootstrap
    // Do not double-dispose: registry remains the disposer for shared instances.
    appSettingsStoreProvider.overrideWith(
      () => _RegistryAppSettingsStoreNotifier(registry),
    ),
    // M4-09 workspace store: use registry-owned instance during normal app bootstrap
    // Do not double-dispose: registry remains the disposer for shared instances.
    appWorkspaceStoreProvider.overrideWith(
      () => _RegistryAppWorkspaceStoreNotifier(registry),
    ),
    // M4-10 story generation run store: use registry-owned instance during normal app bootstrap
    // Do not double-dispose: registry remains the disposer for shared instances.
    storyGenerationRunStoreProvider.overrideWith(
      () => _RegistryStoryGenerationRunStoreNotifier(registry),
    ),
  ];
}

/// Registry-backed notifier for [AppSettingsStore] used during app bootstrap.
class _RegistryAppSettingsStoreNotifier extends AppSettingsStoreNotifier {
  _RegistryAppSettingsStoreNotifier(this._registry);

  final ServiceRegistry _registry;

  @override
  AppSettingsStore build() {
    final store = _registry.resolve<AppSettingsStore>();
    void listener() => state = store;
    store.addListener(listener);
    ref.onDispose(() => store.removeListener(listener));
    return store;
  }

  @override
  bool updateShouldNotify(AppSettingsStore previous, AppSettingsStore next) =>
      true;
}

/// Registry-backed notifier for [AppWorkspaceStore] used during app bootstrap.
class _RegistryAppWorkspaceStoreNotifier extends AppWorkspaceStoreNotifier {
  _RegistryAppWorkspaceStoreNotifier(this._registry);

  final ServiceRegistry _registry;

  @override
  AppWorkspaceStore build() {
    final store = _registry.resolve<AppWorkspaceStore>();
    void listener() => state = store;
    store.addListener(listener);
    ref.onDispose(() => store.removeListener(listener));
    return store;
  }

  @override
  bool updateShouldNotify(AppWorkspaceStore previous, AppWorkspaceStore next) =>
      true;
}

/// Registry-backed notifier for [StoryGenerationRunStore] used during app bootstrap.
class _RegistryStoryGenerationRunStoreNotifier
    extends StoryGenerationRunStoreNotifier {
  _RegistryStoryGenerationRunStoreNotifier(this._registry);

  final ServiceRegistry _registry;

  @override
  StoryGenerationRunStore build() {
    final store = _registry.resolve<StoryGenerationRunStore>();
    void listener() => state = store;
    store.addListener(listener);
    ref.onDispose(() => store.removeListener(listener));
    return store;
  }

  @override
  bool updateShouldNotify(
    StoryGenerationRunStore previous,
    StoryGenerationRunStore next,
  ) => true;
}
