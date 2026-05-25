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
import '../events/app_event_bus.dart';
import '../logging/app_event_log.dart';
import '../llm/app_llm_client.dart';
import '../llm/app_llm_request_pool.dart';
import '../state/app_ai_history_store.dart';
import '../state/app_authoring_storage_io_support.dart';
import '../state/app_draft_store.dart';
import '../state/app_scene_context_store.dart';
import '../state/app_settings_store.dart';
import '../state/app_simulation_store.dart';
import '../state/app_version_store.dart';
import '../state/app_workspace_store.dart';
import '../state/fulltext_search_service.dart';
import '../state/story_generation_run_store.dart';
import '../state/story_generation_store.dart';
import '../state/story_outline_store.dart';
import '../state/story_arc_store.dart';
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

class AppWorkspaceStoreNotifier
    extends RegistryStoreNotifier<AppWorkspaceStore> {}

class AppSettingsStoreNotifier
    extends RegistryStoreNotifier<AppSettingsStore> {}

class AppDraftStoreNotifier extends RegistryStoreNotifier<AppDraftStore> {}

class AppVersionStoreNotifier extends RegistryStoreNotifier<AppVersionStore> {}

class AppAiHistoryStoreNotifier
    extends RegistryStoreNotifier<AppAiHistoryStore> {}

class AppSceneContextStoreNotifier
    extends RegistryStoreNotifier<AppSceneContextStore> {}

class AppSimulationStoreNotifier
    extends RegistryStoreNotifier<AppSimulationStore> {}

class StoryOutlineStoreNotifier
    extends RegistryStoreNotifier<StoryOutlineStore> {}

class StoryGenerationStoreNotifier
    extends RegistryStoreNotifier<StoryGenerationStore> {}

class StoryArcStoreNotifier extends RegistryStoreNotifier<StoryArcStore> {}

final appWorkspaceStoreProvider =
    NotifierProvider<AppWorkspaceStoreNotifier, AppWorkspaceStore>(
      AppWorkspaceStoreNotifier.new,
    );

final appSettingsStoreProvider =
    NotifierProvider<AppSettingsStoreNotifier, AppSettingsStore>(
      AppSettingsStoreNotifier.new,
    );

final appDraftStoreProvider =
    NotifierProvider<AppDraftStoreNotifier, AppDraftStore>(
      AppDraftStoreNotifier.new,
    );

final appVersionStoreProvider =
    NotifierProvider<AppVersionStoreNotifier, AppVersionStore>(
      AppVersionStoreNotifier.new,
    );

final appAiHistoryStoreProvider =
    NotifierProvider<AppAiHistoryStoreNotifier, AppAiHistoryStore>(
      AppAiHistoryStoreNotifier.new,
    );

final appSceneContextStoreProvider =
    NotifierProvider<AppSceneContextStoreNotifier, AppSceneContextStore>(
      AppSceneContextStoreNotifier.new,
    );

final appSimulationStoreProvider =
    NotifierProvider<AppSimulationStoreNotifier, AppSimulationStore>(
      AppSimulationStoreNotifier.new,
    );

final storyOutlineStoreProvider =
    NotifierProvider<StoryOutlineStoreNotifier, StoryOutlineStore>(
      StoryOutlineStoreNotifier.new,
    );

final storyGenerationStoreProvider =
    NotifierProvider<StoryGenerationStoreNotifier, StoryGenerationStore>(
      StoryGenerationStoreNotifier.new,
    );

final storyArcStoreProvider =
    NotifierProvider<StoryArcStoreNotifier, StoryArcStore>(
      StoryArcStoreNotifier.new,
    );

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

// StoryGenerationRunStore remains registry-backed (out of scope for M4-04)

class StoryGenerationRunStoreNotifier
    extends RegistryStoreNotifier<StoryGenerationRunStore> {}

final storyGenerationRunStoreProvider =
    NotifierProvider<StoryGenerationRunStoreNotifier, StoryGenerationRunStore>(
      StoryGenerationRunStoreNotifier.new,
    );

// -- Writing stats store provider --

class WritingStatsStoreNotifier
    extends RegistryStoreNotifier<WritingStatsStore> {}

final writingStatsStoreProvider =
    NotifierProvider<WritingStatsStoreNotifier, WritingStatsStore>(
      WritingStatsStoreNotifier.new,
    );

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
  ];
}
