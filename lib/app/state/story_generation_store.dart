import 'dart:async';

import '../events/app_domain_events.dart';
import '../events/app_event_bus.dart';
import 'app_store_listenable.dart';
import 'app_workspace_store.dart';
import 'persist_guard.dart';
import 'project_storage.dart';
import 'story_generation_storage.dart';
import 'story_generation_types.dart';

export 'story_generation_types.dart';

class StoryGenerationStore extends AppStoreListenable {
  StoryGenerationStore({
    StoryGenerationStorage? storage,
    AppWorkspaceStore? workspaceStore,
    AppEventBus? eventBus,
  }) : _storage = storage ?? createDefaultStoryGenerationStorage(),
       _workspaceStore = workspaceStore,
       _eventBus = eventBus {
    _activeProjectId = _resolveProjectId(workspaceStore);
    _snapshot = StoryGenerationSnapshot.empty(_activeProjectId);
    _workspaceStore?.addListener(_handleWorkspaceChanged);
    _projectDeletedSubscription = _eventBus?.listen<ProjectDeletedEvent>(
      _handleProjectDeleted,
    );
    _readyFuture = _restore();
    unawaited(_readyFuture);
  }

  final StoryGenerationStorage _storage;
  final AppWorkspaceStore? _workspaceStore;
  final AppEventBus? _eventBus;
  final Map<String, StoryGenerationSnapshot> _snapshotsByProjectId = {};
  late String _activeProjectId;
  late StoryGenerationSnapshot _snapshot;
  Future<void> _readyFuture = Future<void>.value();
  int _mutationVersion = 0;
  StreamSubscription<ProjectDeletedEvent>? _projectDeletedSubscription;

  @override
  Future<void> flushPersistence() => flushProjectStorage(_storage);

  StoryGenerationSnapshot get snapshot => _snapshot.deepCopy();
  String get activeProjectId => _activeProjectId;
  Future<void> get ready => _readyFuture;

  Map<String, Object?> exportJson() => _snapshot.toJson();

  Future<void> waitUntilReady() async {
    while (true) {
      final currentReadyFuture = _readyFuture;
      await currentReadyFuture;
      if (identical(currentReadyFuture, _readyFuture)) {
        return;
      }
    }
  }

  void importJson(Map<String, Object?> data) {
    replaceSnapshot(
      StoryGenerationSnapshot.fromJson({
        ...data,
        'projectId': _activeProjectId,
      }),
    );
  }

  void replaceSnapshot(StoryGenerationSnapshot snapshot) {
    final previousSnapshot = _snapshot;
    _mutationVersion += 1;
    _snapshot = snapshot.deepCopy().copyWith(projectId: _activeProjectId);
    _snapshotsByProjectId[_activeProjectId] = _snapshot.deepCopy();
    _readyFuture = safePersist(_persist, eventBus: _eventBus);
    _publishGenerationEvents(previousSnapshot, _snapshot);
    notifyListeners();
  }

  void _handleWorkspaceChanged() {
    final nextProjectId = _resolveProjectId(_workspaceStore);
    if (nextProjectId == _activeProjectId) {
      return;
    }
    _mutationVersion += 1;
    _activeProjectId = nextProjectId;
    _snapshot =
        _snapshotsByProjectId[nextProjectId]?.deepCopy() ??
        StoryGenerationSnapshot.empty(nextProjectId);
    _readyFuture = _restore();
    unawaited(_readyFuture);
    notifyListeners();
  }

  Future<void> _restore() async {
    final restoreVersion = _mutationVersion;
    final restored = await _storage.load(projectId: _activeProjectId);
    if (restoreVersion != _mutationVersion || restored == null) {
      return;
    }

    _snapshot = StoryGenerationSnapshot.fromJson({
      ...restored,
      'projectId': _activeProjectId,
    });
    _snapshotsByProjectId[_activeProjectId] = _snapshot.deepCopy();
    notifyListeners();
  }

  Future<void> _persist() =>
      _storage.save(_snapshot.toJson(), projectId: _activeProjectId);

  void _handleProjectDeleted(ProjectDeletedEvent event) {
    _mutationVersion += 1;
    _snapshotsByProjectId.remove(event.projectId);
    unawaited(_storage.clearProject(event.projectId));
  }

  static String _resolveProjectId(AppWorkspaceStore? workspaceStore) {
    if (workspaceStore == null || workspaceStore.currentProjectId.isEmpty) {
      return fallbackStoryGenerationProjectId;
    }
    return workspaceStore.currentProjectId;
  }

  void _publishGenerationEvents(
    StoryGenerationSnapshot previous,
    StoryGenerationSnapshot current,
  ) {
    final bus = _eventBus;
    if (bus == null) {
      return;
    }
    final projectId = _activeProjectId;
    final event = _activeEvent(previous, current);
    if (event == null) {
      return;
    }
    try {
      if (event.phase == _GenerationPhase.running) {
        bus.publish(
          StoryGenerationStartedEvent(
            projectId: projectId,
            sceneId: event.sceneId,
          ),
        );
      } else if (event.phase == _GenerationPhase.completed) {
        bus.publish(
          StoryGenerationCompletedEvent(
            projectId: projectId,
            sceneId: event.sceneId,
          ),
        );
      } else if (event.phase == _GenerationPhase.failed) {
        bus.publish(
          StoryGenerationFailedEvent(
            projectId: projectId,
            sceneId: event.sceneId,
            error: '',
          ),
        );
      } else if (event.phase == _GenerationPhase.cancelled) {
        bus.publish(
          StoryGenerationCancelledEvent(
            projectId: projectId,
            sceneId: event.sceneId,
          ),
        );
      }
    } on StateError {
      // Event delivery should not break generation mutations.
    }
  }

  static _GenerationEvent? _activeEvent(
    StoryGenerationSnapshot previous,
    StoryGenerationSnapshot current,
  ) {
    final previousStatuses = <String, _GenerationPhase>{};
    for (final scene in _scenes(previous)) {
      previousStatuses[scene.sceneId] = _phaseForScene(scene);
    }

    _GenerationEvent? terminalEvent;
    for (final scene in _scenes(current)) {
      final currentPhase = _phaseForScene(scene);
      if (previousStatuses[scene.sceneId] == currentPhase ||
          currentPhase == _GenerationPhase.idle) {
        continue;
      }

      final event = _GenerationEvent(scene.sceneId, currentPhase);
      if (currentPhase == _GenerationPhase.running) {
        return event;
      }
      terminalEvent ??= event;
    }
    return terminalEvent;
  }

  static Iterable<StorySceneGenerationState> _scenes(
    StoryGenerationSnapshot snapshot,
  ) sync* {
    for (final chapter in snapshot.chapters) {
      yield* chapter.scenes;
    }
  }

  static _GenerationPhase _phaseForScene(StorySceneGenerationState scene) {
    switch (scene.status) {
      case StorySceneGenerationStatus.directing:
      case StorySceneGenerationStatus.roleRunning:
      case StorySceneGenerationStatus.drafting:
      case StorySceneGenerationStatus.reviewing:
        return _GenerationPhase.running;
      case StorySceneGenerationStatus.blocked:
        if (scene.terminalReason == 'cancelled') {
          return _GenerationPhase.cancelled;
        }
        return _GenerationPhase.failed;
      case StorySceneGenerationStatus.passed:
        return _GenerationPhase.completed;
      case StorySceneGenerationStatus.pending:
      case StorySceneGenerationStatus.invalidated:
        return _GenerationPhase.idle;
    }
  }

  @override
  void dispose() {
    _workspaceStore?.removeListener(_handleWorkspaceChanged);
    unawaited(_projectDeletedSubscription?.cancel());
    _projectDeletedSubscription = null;
    if (_storage case final ProjectStorageDiscardable discardable) {
      discardable.discard();
    }
    super.dispose();
  }
}

enum _GenerationPhase { idle, running, completed, failed, cancelled }

class _GenerationEvent {
  const _GenerationEvent(this.sceneId, this.phase);

  final String sceneId;
  final _GenerationPhase phase;
}
