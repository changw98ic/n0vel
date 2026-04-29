import '../state/app_workspace_defaults.dart';
import '../state/app_workspace_records.dart';
import 'workspace_validator.dart';

class WorkspaceData {
  const WorkspaceData({
    required this.projects,
    required this.charactersByProjectId,
    required this.scenesByProjectId,
    required this.worldNodesByProjectId,
    required this.auditIssuesByProjectId,
    required this.styleByProjectId,
    required this.auditUiByProjectId,
    required this.projectTransferState,
    required this.currentProjectId,
  });

  final List<ProjectRecord> projects;
  final Map<String, List<CharacterRecord>> charactersByProjectId;
  final Map<String, List<SceneRecord>> scenesByProjectId;
  final Map<String, List<WorldNodeRecord>> worldNodesByProjectId;
  final Map<String, List<AuditIssueRecord>> auditIssuesByProjectId;
  final Map<String, ProjectStyleState> styleByProjectId;
  final Map<String, ProjectAuditUiState> auditUiByProjectId;
  final ProjectTransferState projectTransferState;
  final String currentProjectId;

  Map<String, Object?> toJson() {
    return {
      'projects': [for (final project in projects) project.toJson()],
      'charactersByProject': {
        for (final entry in charactersByProjectId.entries)
          entry.key: [for (final character in entry.value) character.toJson()],
      },
      'scenesByProject': {
        for (final entry in scenesByProjectId.entries)
          entry.key: [for (final scene in entry.value) scene.toJson()],
      },
      'worldNodesByProject': {
        for (final entry in worldNodesByProjectId.entries)
          entry.key: [for (final node in entry.value) node.toJson()],
      },
      'auditIssuesByProject': {
        for (final entry in auditIssuesByProjectId.entries)
          entry.key: [for (final issue in entry.value) issue.toJson()],
      },
      'projectStyles': {
        for (final entry in styleByProjectId.entries)
          entry.key: entry.value.toJson(),
      },
      'projectAuditStates': {
        for (final entry in auditUiByProjectId.entries)
          entry.key: entry.value.toJson(),
      },
      'projectTransferState': projectTransferState.name,
      'currentProjectId': currentProjectId,
    };
  }

  static WorkspaceData fromJson(Map<String, Object?> json) {
    final projects = decodeProjects(json['projects']);
    return WorkspaceData(
      projects: projects,
      charactersByProjectId: decodeCharactersByProject(
        rawByProject: json['charactersByProject'],
        legacyRaw: json['characters'],
        projects: projects,
      ),
      scenesByProjectId: decodeScenesByProject(
        rawByProject: json['scenesByProject'],
        projects: projects,
      ),
      worldNodesByProjectId: decodeWorldNodesByProject(
        rawByProject: json['worldNodesByProject'],
        legacyRaw: json['worldNodes'],
        projects: projects,
      ),
      auditIssuesByProjectId: decodeAuditIssuesByProject(
        rawByProject: json['auditIssuesByProject'],
        legacyRaw: json['auditIssues'],
        projects: projects,
      ),
      styleByProjectId: decodeStyleByProject(
        rawByProject: json['projectStyles'],
        legacyRaw: json,
        projects: projects,
      ),
      auditUiByProjectId: decodeAuditUiByProject(
        rawByProject: json['projectAuditStates'],
        legacyRaw: json,
        projects: projects,
      ),
      projectTransferState: decodeProjectTransferState(
        json['projectTransferState'],
      ),
      currentProjectId: normalizeCurrentProjectId(
        preferredProjectId: json['currentProjectId']?.toString(),
        projects: projects,
      ),
    );
  }

  static WorkspaceData empty() {
    final projects = sortProjects(buildDefaultProjects());
    return WorkspaceData(
      projects: projects,
      charactersByProjectId: buildDefaultProjectCharacters(projects),
      scenesByProjectId: buildDefaultProjectScenes(projects),
      worldNodesByProjectId: buildDefaultProjectWorldNodes(projects),
      auditIssuesByProjectId: buildDefaultProjectAuditIssues(projects),
      styleByProjectId: buildDefaultProjectStyles(projects),
      auditUiByProjectId: buildDefaultProjectAuditUi(projects),
      projectTransferState: ProjectTransferState.ready,
      currentProjectId: projects.first.id,
    );
  }

  WorkspaceValidationResult validate() => validateWorkspaceData(this);

  WorkspaceData copyWith({
    List<ProjectRecord>? projects,
    Map<String, List<CharacterRecord>>? charactersByProjectId,
    Map<String, List<SceneRecord>>? scenesByProjectId,
    Map<String, List<WorldNodeRecord>>? worldNodesByProjectId,
    Map<String, List<AuditIssueRecord>>? auditIssuesByProjectId,
    Map<String, ProjectStyleState>? styleByProjectId,
    Map<String, ProjectAuditUiState>? auditUiByProjectId,
    ProjectTransferState? projectTransferState,
    String? currentProjectId,
  }) {
    return WorkspaceData(
      projects: projects ?? this.projects,
      charactersByProjectId: charactersByProjectId ?? this.charactersByProjectId,
      scenesByProjectId: scenesByProjectId ?? this.scenesByProjectId,
      worldNodesByProjectId: worldNodesByProjectId ?? this.worldNodesByProjectId,
      auditIssuesByProjectId:
          auditIssuesByProjectId ?? this.auditIssuesByProjectId,
      styleByProjectId: styleByProjectId ?? this.styleByProjectId,
      auditUiByProjectId: auditUiByProjectId ?? this.auditUiByProjectId,
      projectTransferState:
          projectTransferState ?? this.projectTransferState,
      currentProjectId: currentProjectId ?? this.currentProjectId,
    );
  }
}
