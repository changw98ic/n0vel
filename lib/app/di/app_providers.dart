import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/author_feedback/data/author_feedback_store.dart';
import '../../features/review_tasks/data/review_task_store.dart';
import '../../features/story_generation/data/character_memory_store.dart';
import '../../features/story_generation/data/roleplay_session_store.dart';
import '../../features/writing_stats/data/writing_stats_store.dart';
import '../events/app_event_bus.dart';
import '../logging/app_event_log.dart';
import '../llm/app_llm_client.dart';
import '../llm/app_llm_request_pool.dart';
import '../state/app_ai_history_store.dart';
import '../state/app_draft_store.dart';
import '../state/app_scene_context_store.dart';
import '../state/app_settings_store.dart';
import '../state/app_simulation_store.dart';
import '../state/app_version_store.dart';
import '../state/app_workspace_store.dart';
import '../state/story_generation_run_store.dart';
import '../state/story_generation_store.dart';
import '../state/story_outline_store.dart';
import '../state/story_arc_store.dart';
import 'service_registry.dart';

/// Root provider that holds the [ServiceRegistry] reference.
/// Will be removed once all stores are native Riverpod providers.
final serviceRegistryProvider = Provider<ServiceRegistry>((ref) {
  throw StateError('serviceRegistryProvider not overridden in ProviderScope');
});

// -- Infrastructure providers --

final appEventBusProvider = Provider<AppEventBus>((ref) {
  return ref.watch(serviceRegistryProvider).resolve<AppEventBus>();
});

final appEventLogProvider = Provider<AppEventLog>((ref) {
  return ref.watch(serviceRegistryProvider).resolve<AppEventLog>();
});

final appLlmClientProvider = Provider<AppLlmClient>((ref) {
  return ref.watch(serviceRegistryProvider).resolve<AppLlmClient>();
});

final appLlmRequestPoolProvider = Provider<AppLlmRequestPool>((ref) {
  return ref.watch(serviceRegistryProvider).resolve<AppLlmRequestPool>();
});

final roleplaySessionStoreProvider = Provider<RoleplaySessionStore>((ref) {
  return ref.watch(serviceRegistryProvider).resolve<RoleplaySessionStore>();
});

final characterMemoryStoreProvider = Provider<CharacterMemoryStore>((ref) {
  return ref.watch(serviceRegistryProvider).resolve<CharacterMemoryStore>();
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

class AuthorFeedbackStoreNotifier
    extends RegistryStoreNotifier<AuthorFeedbackStore> {}

class ReviewTaskStoreNotifier extends RegistryStoreNotifier<ReviewTaskStore> {}

class StoryGenerationRunStoreNotifier
    extends RegistryStoreNotifier<StoryGenerationRunStore> {}

final authorFeedbackStoreProvider =
    NotifierProvider<AuthorFeedbackStoreNotifier, AuthorFeedbackStore>(
      AuthorFeedbackStoreNotifier.new,
    );

final reviewTaskStoreProvider =
    NotifierProvider<ReviewTaskStoreNotifier, ReviewTaskStore>(
      ReviewTaskStoreNotifier.new,
    );

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
