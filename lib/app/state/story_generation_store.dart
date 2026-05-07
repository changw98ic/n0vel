import 'dart:async';

import 'package:flutter/widgets.dart';

import '../events/app_domain_events.dart';
import '../events/app_event_bus.dart';
import 'app_workspace_store.dart';
import 'story_generation_storage.dart';
import 'story_generation_types.dart';

export 'story_generation_types.dart';

class StoryGenerationStore extends ChangeNotifier {
  StoryGenerationStore({
    StoryGenerationStorage? storage,
    AppWorkspaceStore? workspaceStore,
    AppEventBus? eventBus,
  }) : _storage =
           storage ??
           debugStorageOverride ??
           createDefaultStoryGenerationStorage(),
       _workspaceStore = workspaceStore,
       _eventBus = eventBus ?? AppEventBus.current {
    _activeProjectId = _resolveProjectId(workspaceStore);
    _snapshot = StoryGenerationSnapshot.empty(_activeProjectId);
    _workspaceStore?.addListener(_handleWorkspaceChanged);
    _readyFuture = _restore();
    unawaited(_readyFuture);
  }

  @visibleForTesting
  static StoryGenerationStorage? debugStorageOverride;

  final StoryGenerationStorage _storage;
  final AppWorkspaceStore? _workspaceStore;
  final AppEventBus? _eventBus;
  final Map<String, StoryGenerationSnapshot> _snapshotsByProjectId = {};
  late String _activeProjectId;
  late StoryGenerationSnapshot _snapshot;
  Future<void> _readyFuture = Future<void>.value();
  int _mutationVersion = 0;

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
    _readyFuture = Future<void>.value();
    unawaited(_persist());
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
    final previousActiveStatus = _activeStatus(previous);
    final currentActiveStatus = _activeStatus(current);
    if (previousActiveStatus == currentActiveStatus) {
      return;
    }
    final sceneId = _activeSceneId(current) ?? _activeSceneId(previous) ?? '';
    try {
      if (currentActiveStatus == _GenerationPhase.running) {
        bus.publish(StoryGenerationStartedEvent(
          projectId: projectId,
          sceneId: sceneId,
        ));
      } else if (currentActiveStatus == _GenerationPhase.completed) {
        bus.publish(StoryGenerationCompletedEvent(
          projectId: projectId,
          sceneId: sceneId,
        ));
      } else if (currentActiveStatus == _GenerationPhase.failed) {
        bus.publish(StoryGenerationFailedEvent(
          projectId: projectId,
          sceneId: sceneId,
          error: '',
        ));
      }
    } on StateError {
      // Event delivery should not break generation mutations.
    }
  }

  static _GenerationPhase _activeStatus(StoryGenerationSnapshot snapshot) {
    for (final chapter in snapshot.chapters) {
      for (final scene in chapter.scenes) {
        switch (scene.status) {
          case StorySceneGenerationStatus.directing:
          case StorySceneGenerationStatus.roleRunning:
          case StorySceneGenerationStatus.drafting:
          case StorySceneGenerationStatus.reviewing:
            return _GenerationPhase.running;
          case StorySceneGenerationStatus.blocked:
            return _GenerationPhase.failed;
          case StorySceneGenerationStatus.passed:
            return _GenerationPhase.completed;
          case StorySceneGenerationStatus.pending:
          case StorySceneGenerationStatus.invalidated:
            continue;
        }
      }
    }
    return _GenerationPhase.idle;
  }

  static String? _activeSceneId(StoryGenerationSnapshot snapshot) {
    for (final chapter in snapshot.chapters) {
      for (final scene in chapter.scenes) {
        if (scene.status != StorySceneGenerationStatus.pending &&
            scene.status != StorySceneGenerationStatus.invalidated) {
          return scene.sceneId;
        }
      }
    }
    return null;
  }

  @override
  void dispose() {
    _workspaceStore?.removeListener(_handleWorkspaceChanged);
    super.dispose();
  }
}

enum _GenerationPhase { idle, running, completed, failed }
