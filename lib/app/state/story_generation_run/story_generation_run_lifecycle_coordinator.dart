part of '../story_generation_run_store.dart';

/// Owns visible scene scope and restore/readiness bookkeeping for run state.
class StoryGenerationRunLifecycleCoordinator {
  StoryGenerationRunLifecycleCoordinator({required String initialSceneScopeId})
    : _activeSceneScopeId = initialSceneScopeId;

  String _activeSceneScopeId;
  Future<void> _readyFuture = Future<void>.value();
  int _mutationVersion = 0;

  String get activeSceneScopeId => _activeSceneScopeId;
  Future<void> get ready => _readyFuture;
  int get mutationVersion => _mutationVersion;

  int markMutated() {
    _mutationVersion += 1;
    return _mutationVersion;
  }

  bool moveToSceneScope(String nextSceneScopeId) {
    if (nextSceneScopeId == _activeSceneScopeId) {
      return false;
    }
    _activeSceneScopeId = nextSceneScopeId;
    markMutated();
    return true;
  }

  Future<void> trackReady(Future<void> readyFuture) {
    _readyFuture = readyFuture;
    return readyFuture;
  }

  Future<void> waitUntilReady() async {
    while (true) {
      final currentReadyFuture = _readyFuture;
      await currentReadyFuture;
      if (identical(currentReadyFuture, _readyFuture)) {
        return;
      }
    }
  }

  bool isCurrent(int mutationVersion, String sceneScopeId) {
    return mutationVersion == _mutationVersion &&
        sceneScopeId == _activeSceneScopeId;
  }
}
