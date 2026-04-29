import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app_workspace_store.dart';

/// Whether the store resolves its scope from the current project or scene.
enum AppStoreScopeMode {
  /// Uses [AppWorkspaceStore.currentProjectId].
  project,

  /// Uses [AppWorkspaceStore.currentSceneScopeId].
  scene,
}

/// Base class for stores scoped to the active project or scene.
///
/// Manages workspace change listener lifecycle, active project ID tracking
/// with configurable scope resolution, and mutation versioning for safe
/// async restore operations.
///
/// Subclasses must implement:
/// - [onProjectScopeChanged] to reset state when the project scope changes.
/// - [onRestore] to load persisted data for the current scope.
abstract class AppProjectScopedStore extends ChangeNotifier {
  AppProjectScopedStore({
    AppWorkspaceStore? workspaceStore,
    this.scopeMode = AppStoreScopeMode.scene,
    String fallbackProjectId = 'project-yuechao::scene-05-witness-room',
  }) : _workspaceStore = workspaceStore,
       _fallbackProjectId = fallbackProjectId {
    _activeProjectId = _resolveProjectId();
    _workspaceStore?.addListener(_handleWorkspaceChanged);
  }

  final AppWorkspaceStore? _workspaceStore;
  final String _fallbackProjectId;

  /// Whether to resolve scope from project ID or scene scope ID.
  final AppStoreScopeMode scopeMode;

  late String _activeProjectId;
  int _mutationVersion = 0;

  /// The currently active project scope ID.
  String get activeProjectId => _activeProjectId;

  /// Protected access to the workspace store.
  @protected
  AppWorkspaceStore? get workspaceStore => _workspaceStore;

  /// Increment mutation version to invalidate in-flight restores.
  @protected
  void markMutated() {
    _mutationVersion += 1;
  }

  /// Current mutation version for safe async restore guards.
  @protected
  int get mutationVersion => _mutationVersion;

  /// Called when the active project scope changes.
  ///
  /// Subclasses must reset their state to appropriate defaults
  /// for the new scope.
  @protected
  void onProjectScopeChanged(String previousProjectId, String nextProjectId);

  /// Called to restore data from storage for the current scope.
  @protected
  Future<void> onRestore();

  String _resolveProjectId() {
    final ws = _workspaceStore;
    if (ws == null || ws.currentProjectId.isEmpty) {
      return _fallbackProjectId;
    }
    return switch (scopeMode) {
      AppStoreScopeMode.project => ws.currentProjectId,
      AppStoreScopeMode.scene => ws.currentSceneScopeId,
    };
  }

  void _handleWorkspaceChanged() {
    final nextProjectId = _resolveProjectId();
    if (nextProjectId == _activeProjectId) return;
    _mutationVersion += 1;
    final previousProjectId = _activeProjectId;
    _activeProjectId = nextProjectId;
    onProjectScopeChanged(previousProjectId, nextProjectId);
    unawaited(onRestore());
    notifyListeners();
  }

  @override
  void dispose() {
    _workspaceStore?.removeListener(_handleWorkspaceChanged);
    super.dispose();
  }
}
