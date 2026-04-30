import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app_workspace_store.dart';
import 'story_generation_storage.dart';
import 'story_generation_types.dart';

export 'story_generation_types.dart';

class StoryGenerationStore extends ChangeNotifier {
  StoryGenerationStore({
    StoryGenerationStorage? storage,
    AppWorkspaceStore? workspaceStore,
  }) : _storage =
           storage ??
           debugStorageOverride ??
           createDefaultStoryGenerationStorage(),
       _workspaceStore = workspaceStore {
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
    _mutationVersion += 1;
    _snapshot = snapshot.deepCopy().copyWith(projectId: _activeProjectId);
    _snapshotsByProjectId[_activeProjectId] = _snapshot.deepCopy();
    _readyFuture = Future<void>.value();
    unawaited(_persist());
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

  @override
  void dispose() {
    _workspaceStore?.removeListener(_handleWorkspaceChanged);
    super.dispose();
  }
}
