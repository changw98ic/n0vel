part of '../story_generation_run_store.dart';

/// Owns active run token and scene-scope bookkeeping for a run session.
class StoryGenerationRunSessionController {
  int _runToken = 0;
  int? _activeRunToken;
  String? _activeRunSceneScopeId;

  int? get activeRunToken => _activeRunToken;
  String? get activeRunSceneScopeId => _activeRunSceneScopeId;
  bool get hasActiveRun => _activeRunToken != null;

  int begin(String sceneScopeId) {
    _runToken += 1;
    _activeRunToken = _runToken;
    _activeRunSceneScopeId = sceneScopeId;
    return _runToken;
  }

  bool isCurrent({
    required int runToken,
    required String runSceneScopeId,
    required String visibleSceneScopeId,
  }) {
    return _activeRunToken == runToken &&
        _activeRunSceneScopeId == runSceneScopeId &&
        visibleSceneScopeId == runSceneScopeId;
  }

  bool isActiveRunForScene(String sceneScopeId) {
    return _activeRunToken != null && _activeRunSceneScopeId == sceneScopeId;
  }

  void finish(int runToken) {
    if (_activeRunToken != runToken) {
      return;
    }
    clearActiveRun();
  }

  void clearActiveRun() {
    _activeRunToken = null;
    _activeRunSceneScopeId = null;
  }

  bool clearProject(String projectId) {
    if (!_activeRunScopeMatchesProject(projectId)) {
      return false;
    }
    clearActiveRun();
    _runToken += 1;
    return true;
  }

  bool _activeRunScopeMatchesProject(String projectId) {
    final activeScope = _activeRunSceneScopeId;
    if (activeScope == null) {
      return false;
    }
    return activeScope == projectId || activeScope.startsWith('$projectId::');
  }
}
