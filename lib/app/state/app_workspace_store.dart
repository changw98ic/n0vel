import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../events/app_domain_events.dart';
import '../events/app_event_bus.dart';
import 'app_workspace_storage.dart';
import 'workspace_codec_utils.dart';
import 'workspace_types.dart';

export 'workspace_types.dart';

part 'workspace_codec.dart';
part 'workspace_project_scene_ops.dart';
part 'workspace_resource_style_ops.dart';
part 'workspace_audit_transfer_ops.dart';

// ============================================================================
// Fields & Infrastructure Mixin
// ============================================================================

mixin _WorkspaceFields on ChangeNotifier {
  // -------------------------------------------------------------------------
  // Abstract Fields
  // -------------------------------------------------------------------------

  AppWorkspaceStorage get _storage;

  abstract List<ProjectRecord> _projects;
  abstract Map<String, List<CharacterRecord>> _charactersByProjectId;
  abstract Map<String, List<SceneRecord>> _scenesByProjectId;
  abstract Map<String, List<WorldNodeRecord>> _worldNodesByProjectId;
  abstract Map<String, List<AuditIssueRecord>> _auditIssuesByProjectId;
  abstract Map<String, ProjectStyleState> _styleByProjectId;
  abstract Map<String, ProjectAuditUiState> _auditUiByProjectId;
  abstract String _currentProjectId;
  abstract ProjectTransferState _projectTransferState;
  abstract bool _hasLocalMutations;
  AppEventBus? get _eventBus;

  // -------------------------------------------------------------------------
  // Abstract Methods (implemented in domain mixins)
  // -------------------------------------------------------------------------

  // ignore: unused_element
  Future<void> _restore();
  Future<void> _persist();
  void _ensureProjectResources(String projectId);
  void updateCurrentScene({
    required String sceneId,
    required String recentLocation,
  });

  // -------------------------------------------------------------------------
  // Public Getters
  // -------------------------------------------------------------------------

  List<ProjectRecord> get projects => List.unmodifiable(_projects);
  List<CharacterRecord> get characters =>
      List.unmodifiable(_charactersForCurrentProject());
  List<SceneRecord> get scenes => List.unmodifiable(_scenesForCurrentProject());
  List<WorldNodeRecord> get worldNodes =>
      List.unmodifiable(_worldNodesForCurrentProject());
  List<AuditIssueRecord> get auditIssues =>
      List.unmodifiable(_auditIssuesForCurrentProject());
  StyleInputMode get styleInputMode => _styleStateForCurrentProject().inputMode;
  int get styleIntensity => _styleStateForCurrentProject().intensity;
  String get styleBindingFeedback =>
      _styleStateForCurrentProject().bindingFeedback;
  Map<String, Object?> get styleQuestionnaireDraft => Map<String, Object?>.from(
    _styleStateForCurrentProject().questionnaireDraft,
  );
  String get styleJsonDraft => _styleStateForCurrentProject().jsonDraft;
  List<StyleProfileRecord> get styleProfiles =>
      List.unmodifiable(_styleStateForCurrentProject().profiles);
  String get selectedStyleProfileId =>
      _styleStateForCurrentProject().selectedProfileId;
  StyleProfileRecord? get selectedStyleProfile {
    final profiles = styleProfiles;
    if (profiles.isEmpty) {
      return null;
    }
    final selectedId = selectedStyleProfileId;
    for (final profile in profiles) {
      if (profile.id == selectedId) {
        return profile;
      }
    }
    return profiles.first;
  }

  StyleWorkflowState get styleWorkflowState =>
      _styleStateForCurrentProject().workflowState;
  String get styleWorkflowMessage =>
      _styleStateForCurrentProject().workflowMessage;
  List<String> get styleWarningMessages =>
      List.unmodifiable(_styleStateForCurrentProject().warningMessages);
  ProjectTransferState get projectTransferState => _projectTransferState;
  String get currentProjectId => _currentProjectId;
  ProjectRecord get currentProject =>
      projectById(_currentProjectId) ?? _projects.first;
  String get currentProjectBreadcrumb =>
      '${currentProject.title} / ${currentProject.recentLocation}';
  String get currentSceneScopeId =>
      '${currentProject.id}::${currentProject.sceneId}';
  SceneRecord get currentScene =>
      sceneById(_currentProjectId, currentProject.sceneId) ??
      _scenesForCurrentProject().first;
  int get selectedAuditIssueIndex =>
      _auditSelectionIndexForProject(_currentProjectId);
  AuditIssueRecord get selectedAuditIssue =>
      auditIssues[selectedAuditIssueIndex];
  AuditIssueFilter get auditIssueFilter =>
      _selectedAuditStateForCurrentProject().filter;
  List<AuditIssueRecord> get filteredAuditIssues {
    final filter = auditIssueFilter;
    if (filter == AuditIssueFilter.all) {
      return auditIssues;
    }
    return [
      for (final issue in auditIssues)
        if (issue.status.name == filter.name) issue,
    ];
  }

  String get auditActionFeedback =>
      _selectedAuditStateForCurrentProject().actionFeedback;

  bool get canDeleteCurrentScene => scenes.length > 1;

  // -------------------------------------------------------------------------
  // Query Methods
  // -------------------------------------------------------------------------

  bool hasProjectWithId(String projectId) =>
      _projects.any((project) => project.id == projectId);

  ProjectRecord? projectById(String projectId) {
    for (final project in _projects) {
      if (project.id == projectId) {
        return project;
      }
    }
    return null;
  }

  SceneRecord? sceneById(String projectId, String sceneId) {
    for (final scene in _scenesForProject(projectId)) {
      if (scene.id == sceneId) {
        return scene;
      }
    }
    return null;
  }

  // -------------------------------------------------------------------------
  // Export
  // -------------------------------------------------------------------------

  Map<String, Object?> exportJson() {
    return {
      'projects': [for (final project in _projects) project.toJson()],
      'charactersByProject': {
        for (final entry in _charactersByProjectId.entries)
          entry.key: [for (final character in entry.value) character.toJson()],
      },
      'scenesByProject': {
        for (final entry in _scenesByProjectId.entries)
          entry.key: [for (final scene in entry.value) scene.toJson()],
      },
      'worldNodesByProject': {
        for (final entry in _worldNodesByProjectId.entries)
          entry.key: [for (final node in entry.value) node.toJson()],
      },
      'auditIssuesByProject': {
        for (final entry in _auditIssuesByProjectId.entries)
          entry.key: [for (final issue in entry.value) issue.toJson()],
      },
      'projectStyles': {
        for (final entry in _styleByProjectId.entries)
          entry.key: entry.value.toJson(),
      },
      'projectAuditStates': {
        for (final entry in _auditUiByProjectId.entries)
          entry.key: entry.value.toJson(),
      },
      'projectTransferState': _projectTransferState.name,
      'currentProjectId': _currentProjectId,
    };
  }

  Map<String, Object?> exportCurrentProjectJson() {
    final project = currentProject;
    return {
      'projects': [project.toJson()],
      'charactersByProject': {
        project.id: [
          for (final character in _charactersForProject(project.id))
            character.toJson(),
        ],
      },
      'scenesByProject': {
        project.id: [
          for (final scene in _scenesForProject(project.id)) scene.toJson(),
        ],
      },
      'worldNodesByProject': {
        project.id: [
          for (final node in _worldNodesForProject(project.id)) node.toJson(),
        ],
      },
      'auditIssuesByProject': {
        project.id: [
          for (final issue in _auditIssuesForProject(project.id))
            issue.toJson(),
        ],
      },
      'projectStyles': {project.id: _styleStateForProject(project.id).toJson()},
      'projectAuditStates': {
        project.id: _auditUiStateForProject(project.id).toJson(),
      },
      'projectTransferState': ProjectTransferState.ready.name,
      'currentProjectId': project.id,
    };
  }

  // -------------------------------------------------------------------------
  // Core Infrastructure
  // -------------------------------------------------------------------------

  void _commitMutation() {
    _hasLocalMutations = true;
    unawaited(_persist());
    notifyListeners();
  }

  void _publishWorkspaceEvent(AppDomainEvent event) {
    final bus = _eventBus;
    if (bus == null) {
      return;
    }
    try {
      bus.publish(event);
    } on StateError {
      // Event delivery should not break workspace mutations.
    }
  }

  String _normalizeCurrentProjectId({
    required String? preferredProjectId,
    required List<ProjectRecord> projects,
  }) {
    if (projects.isEmpty) {
      return '';
    }
    if (preferredProjectId != null &&
        projects.any((project) => project.id == preferredProjectId)) {
      return preferredProjectId;
    }
    return projects.first.id;
  }

  // -------------------------------------------------------------------------
  // Internal Accessors
  // -------------------------------------------------------------------------

  List<CharacterRecord> _charactersForCurrentProject() =>
      _charactersForProject(_currentProjectId);

  List<CharacterRecord> _charactersForProject(String projectId) =>
      List<CharacterRecord>.from(
        _charactersByProjectId[projectId] ?? defaultCharacters,
      );

  List<SceneRecord> _scenesForCurrentProject() =>
      _scenesForProject(_currentProjectId);

  List<SceneRecord> _scenesForProject(String projectId) =>
      List<SceneRecord>.from(
        _scenesByProjectId[projectId] ??
            defaultScenesForProject(projectById(projectId) ?? currentProject),
      );

  List<WorldNodeRecord> _worldNodesForCurrentProject() =>
      _worldNodesForProject(_currentProjectId);

  List<WorldNodeRecord> _worldNodesForProject(String projectId) =>
      List<WorldNodeRecord>.from(
        _worldNodesByProjectId[projectId] ?? defaultWorldNodes,
      );

  List<AuditIssueRecord> _auditIssuesForCurrentProject() =>
      _auditIssuesForProject(_currentProjectId);

  List<AuditIssueRecord> _auditIssuesForProject(String projectId) =>
      List<AuditIssueRecord>.from(
        _auditIssuesByProjectId[projectId] ?? defaultAuditIssues,
      );

  ProjectStyleState _styleStateForCurrentProject() =>
      _styleStateForProject(_currentProjectId);

  ProjectStyleState _styleStateForProject(String projectId) =>
      _styleByProjectId[projectId] ?? defaultStyleState();

  ProjectAuditUiState _selectedAuditStateForCurrentProject() =>
      _auditUiStateForProject(_currentProjectId);

  ProjectAuditUiState _auditUiStateForProject(String projectId) {
    final issues = _auditIssuesForProject(projectId);
    final state =
        _auditUiByProjectId[projectId] ??
        const ProjectAuditUiState(
          selectedIssueId: '',
          selectedIssueIndex: 0,
          filter: AuditIssueFilter.all,
          actionFeedback: defaultAuditActionFeedback,
        );
    if (issues.isEmpty) {
      return state.copyWith(selectedIssueId: '', selectedIssueIndex: 0);
    }
    final indexById = issues.indexWhere(
      (issue) => issue.id == state.selectedIssueId,
    );
    final resolvedIndex = indexById == -1
        ? state.selectedIssueIndex.clamp(0, issues.length - 1)
        : indexById;
    final resolvedId = issues[resolvedIndex].id;
    if (resolvedIndex == state.selectedIssueIndex &&
        resolvedId == state.selectedIssueId) {
      return state;
    }
    return state.copyWith(
      selectedIssueId: resolvedId,
      selectedIssueIndex: resolvedIndex,
    );
  }

  int _auditSelectionIndexForProject(String projectId) =>
      _auditUiStateForProject(projectId).selectedIssueIndex;
}

// ============================================================================
// Concrete Store
// ============================================================================

class AppWorkspaceStore extends ChangeNotifier
    with
        _WorkspaceFields,
        _WorkspaceCodec,
        _ProjectSceneOps,
        _ResourceStyleOps,
        _AuditTransferOps {
  AppWorkspaceStore({AppWorkspaceStorage? storage, AppEventBus? eventBus})
    : _storage =
          storage ?? debugStorageOverride ?? createDefaultAppWorkspaceStorage(),
      _eventBus = eventBus ?? AppEventBus.current,
      _projects = sortProjects(buildDefaultProjects()),
      _charactersByProjectId = buildDefaultProjectCharacters(
        buildDefaultProjects(),
      ),
      _scenesByProjectId = buildDefaultProjectScenes(buildDefaultProjects()),
      _worldNodesByProjectId = buildDefaultProjectWorldNodes(
        buildDefaultProjects(),
      ),
      _auditIssuesByProjectId = buildDefaultProjectAuditIssues(
        buildDefaultProjects(),
      ),
      _styleByProjectId = buildDefaultProjectStyles(buildDefaultProjects()),
      _auditUiByProjectId = buildDefaultProjectAuditUi(buildDefaultProjects()),
      _currentProjectId = buildDefaultProjects().first.id {
    _restore();
  }

  @visibleForTesting
  static AppWorkspaceStorage? debugStorageOverride;

  @override
  final AppWorkspaceStorage _storage;

  @override
  final AppEventBus? _eventBus;

  @override
  List<ProjectRecord> _projects;

  @override
  Map<String, List<CharacterRecord>> _charactersByProjectId;

  @override
  Map<String, List<SceneRecord>> _scenesByProjectId;

  @override
  Map<String, List<WorldNodeRecord>> _worldNodesByProjectId;

  @override
  Map<String, List<AuditIssueRecord>> _auditIssuesByProjectId;

  @override
  Map<String, ProjectStyleState> _styleByProjectId;

  @override
  Map<String, ProjectAuditUiState> _auditUiByProjectId;

  @override
  String _currentProjectId;

  @override
  ProjectTransferState _projectTransferState = ProjectTransferState.ready;

  @override
  bool _hasLocalMutations = false;
}

// ============================================================================
// Inherited Widget
// ============================================================================

class AppWorkspaceScope extends InheritedNotifier<AppWorkspaceStore> {
  const AppWorkspaceScope({
    super.key,
    required AppWorkspaceStore store,
    required super.child,
  }) : super(notifier: store);

  static AppWorkspaceStore of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppWorkspaceScope>();
    assert(scope != null, 'AppWorkspaceScope is missing in the widget tree.');
    return scope!.notifier!;
  }
}
