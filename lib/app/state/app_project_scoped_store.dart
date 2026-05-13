import 'dart:async';

import 'package:flutter/foundation.dart';

import '../events/app_domain_events.dart';
import '../events/app_event_bus.dart';
import 'app_store_listenable.dart';
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
abstract class AppProjectScopedStore extends AppStoreListenable {
  AppProjectScopedStore({
    AppWorkspaceStore? workspaceStore,
    AppEventBus? eventBus,
    this.scopeMode = AppStoreScopeMode.scene,
    String fallbackProjectId = '',
  }) : _workspaceStore = workspaceStore,
       _eventBus = eventBus,
       _fallbackProjectId = fallbackProjectId {
    _activeProjectId = _resolveProjectId();
    _workspaceStore?.addListener(_handleWorkspaceChanged);
    _projectDeletedSubscription = _eventBus
        ?.listen<ProjectDeletedEvent>(_handleProjectDeleted);
  }

  final AppWorkspaceStore? _workspaceStore;
  final AppEventBus? _eventBus;
  final String _fallbackProjectId;
  StreamSubscription<ProjectDeletedEvent>? _projectDeletedSubscription;

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

  @protected
  Future<void> clearDeletedProjectScope(String projectId) => Future.value();

  @protected
  void onProjectDeleted(String projectId) {}

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

  void _handleProjectDeleted(ProjectDeletedEvent event) {
    _mutationVersion += 1;
    onProjectDeleted(event.projectId);
    unawaited(clearDeletedProjectScope(event.projectId));
  }

  @override
  void dispose() {
    _workspaceStore?.removeListener(_handleWorkspaceChanged);
    unawaited(_projectDeletedSubscription?.cancel());
    _projectDeletedSubscription = null;
    super.dispose();
  }
}
