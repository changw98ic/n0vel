import '../state/app_workspace_records.dart';
import 'workspace_data.dart';

enum ValidationSeverity { warning, error }

class ValidationIssue {
  const ValidationIssue({
    required this.severity,
    required this.field,
    required this.message,
  });

  final ValidationSeverity severity;
  final String field;
  final String message;

  @override
  String toString() => '[${severity.name}] $field: $message';
}

class WorkspaceValidationResult {
  const WorkspaceValidationResult({required this.issues});

  final List<ValidationIssue> issues;

  bool get hasErrors =>
      issues.any((issue) => issue.severity == ValidationSeverity.error);

  bool get hasWarnings =>
      issues.any((issue) => issue.severity == ValidationSeverity.warning);

  bool get isValid => !hasErrors;

  List<ValidationIssue> get errors =>
      issues.where((i) => i.severity == ValidationSeverity.error).toList();

  List<ValidationIssue> get warnings =>
      issues.where((i) => i.severity == ValidationSeverity.warning).toList();
}

// --- Individual record validators ---

List<ValidationIssue> validateProjectRecord(ProjectRecord project) {
  final issues = <ValidationIssue>[];
  if (project.id.trim().isEmpty) {
    issues.add(const ValidationIssue(
      severity: ValidationSeverity.error,
      field: 'ProjectRecord.id',
      message: '项目 ID 不能为空。',
    ));
  }
  if (project.sceneId.trim().isEmpty) {
    issues.add(const ValidationIssue(
      severity: ValidationSeverity.error,
      field: 'ProjectRecord.sceneId',
      message: '项目当前场景 ID 不能为空。',
    ));
  }
  if (project.title.trim().isEmpty) {
    issues.add(const ValidationIssue(
      severity: ValidationSeverity.warning,
      field: 'ProjectRecord.title',
      message: '项目标题为空，将使用默认值。',
    ));
  }
  if (project.lastOpenedAtMs <= 0) {
    issues.add(const ValidationIssue(
      severity: ValidationSeverity.warning,
      field: 'ProjectRecord.lastOpenedAtMs',
      message: '项目打开时间戳异常，排序可能不正确。',
    ));
  }
  return issues;
}

List<ValidationIssue> validateSceneRecord(SceneRecord scene) {
  final issues = <ValidationIssue>[];
  if (scene.id.trim().isEmpty) {
    issues.add(const ValidationIssue(
      severity: ValidationSeverity.error,
      field: 'SceneRecord.id',
      message: '场景 ID 不能为空。',
    ));
  }
  if (scene.title.trim().isEmpty) {
    issues.add(const ValidationIssue(
      severity: ValidationSeverity.warning,
      field: 'SceneRecord.title',
      message: '场景标题为空。',
    ));
  }
  return issues;
}

List<ValidationIssue> validateCharacterRecord(CharacterRecord character) {
  final issues = <ValidationIssue>[];
  if (character.id.trim().isEmpty) {
    issues.add(const ValidationIssue(
      severity: ValidationSeverity.error,
      field: 'CharacterRecord.id',
      message: '角色 ID 不能为空。',
    ));
  }
  if (character.name.trim().isEmpty) {
    issues.add(const ValidationIssue(
      severity: ValidationSeverity.warning,
      field: 'CharacterRecord.name',
      message: '角色名称为空。',
    ));
  }
  return issues;
}

List<ValidationIssue> validateWorldNodeRecord(WorldNodeRecord node) {
  final issues = <ValidationIssue>[];
  if (node.id.trim().isEmpty) {
    issues.add(const ValidationIssue(
      severity: ValidationSeverity.error,
      field: 'WorldNodeRecord.id',
      message: '世界节点 ID 不能为空。',
    ));
  }
  if (node.title.trim().isEmpty) {
    issues.add(const ValidationIssue(
      severity: ValidationSeverity.warning,
      field: 'WorldNodeRecord.title',
      message: '世界节点标题为空。',
    ));
  }
  return issues;
}

List<ValidationIssue> validateAuditIssueRecord(AuditIssueRecord issue) {
  final issues = <ValidationIssue>[];
  if (issue.id.trim().isEmpty) {
    issues.add(const ValidationIssue(
      severity: ValidationSeverity.error,
      field: 'AuditIssueRecord.id',
      message: '审计问题 ID 不能为空。',
    ));
  }
  if (issue.title.trim().isEmpty) {
    issues.add(const ValidationIssue(
      severity: ValidationSeverity.warning,
      field: 'AuditIssueRecord.title',
      message: '审计问题标题为空。',
    ));
  }
  return issues;
}

List<ValidationIssue> validateStyleProfileRecord(StyleProfileRecord profile) {
  final issues = <ValidationIssue>[];
  if (profile.id.trim().isEmpty) {
    issues.add(const ValidationIssue(
      severity: ValidationSeverity.error,
      field: 'StyleProfileRecord.id',
      message: '风格配置 ID 不能为空。',
    ));
  }
  if (profile.name.trim().isEmpty) {
    issues.add(const ValidationIssue(
      severity: ValidationSeverity.warning,
      field: 'StyleProfileRecord.name',
      message: '风格配置名称为空。',
    ));
  }
  return issues;
}

// --- Cross-record / aggregate validators ---

List<ValidationIssue> _validateSceneReferences({
  required String projectId,
  required List<SceneRecord> scenes,
  required List<CharacterRecord> characters,
  required List<WorldNodeRecord> worldNodes,
}) {
  final issues = <ValidationIssue>[];
  final sceneIds = <String>{};
  for (final scene in scenes) {
    if (!sceneIds.add(scene.id)) {
      issues.add(ValidationIssue(
        severity: ValidationSeverity.warning,
        field: 'scenes[$projectId]',
        message: '场景 ID 重复：${scene.id}。',
      ));
    }
  }

  for (final character in characters) {
    for (final sceneId in character.linkedSceneIds) {
      if (sceneId.isNotEmpty && !sceneIds.contains(sceneId)) {
        issues.add(ValidationIssue(
          severity: ValidationSeverity.warning,
          field: 'CharacterRecord(${character.id}).linkedSceneIds',
          message: '角色「${character.name}」引用了不存在的场景 $sceneId。',
        ));
      }
    }
  }

  for (final node in worldNodes) {
    for (final sceneId in node.linkedSceneIds) {
      if (sceneId.isNotEmpty && !sceneIds.contains(sceneId)) {
        issues.add(ValidationIssue(
          severity: ValidationSeverity.warning,
          field: 'WorldNodeRecord(${node.id}).linkedSceneIds',
          message: '世界节点「${node.title}」引用了不存在的场景 $sceneId。',
        ));
      }
    }
  }

  return issues;
}

// --- Top-level workspace validator ---

WorkspaceValidationResult validateWorkspaceData(WorkspaceData data) {
  final issues = <ValidationIssue>[];

  if (data.projects.isEmpty) {
    issues.add(const ValidationIssue(
      severity: ValidationSeverity.error,
      field: 'WorkspaceData.projects',
      message: '工作区至少需要一个项目。',
    ));
  }

  final projectIds = <String>{};
  for (final project in data.projects) {
    issues.addAll(validateProjectRecord(project));
    if (!projectIds.add(project.id)) {
      issues.add(ValidationIssue(
        severity: ValidationSeverity.error,
        field: 'WorkspaceData.projects',
        message: '项目 ID 重复：${project.id}。',
      ));
    }
  }

  if (data.currentProjectId.trim().isEmpty) {
    issues.add(const ValidationIssue(
      severity: ValidationSeverity.error,
      field: 'WorkspaceData.currentProjectId',
      message: '当前项目 ID 不能为空。',
    ));
  } else if (!projectIds.contains(data.currentProjectId)) {
    issues.add(ValidationIssue(
      severity: ValidationSeverity.error,
      field: 'WorkspaceData.currentProjectId',
      message: '当前项目 ID ${data.currentProjectId} 不存在于项目列表中。',
    ));
  }

  for (final project in data.projects) {
    final scenes = data.scenesByProjectId[project.id] ?? const [];
    final characters = data.charactersByProjectId[project.id] ?? const [];
    final worldNodes = data.worldNodesByProjectId[project.id] ?? const [];
    final auditIssues = data.auditIssuesByProjectId[project.id] ?? const [];

    for (final scene in scenes) {
      issues.addAll(validateSceneRecord(scene));
    }
    for (final character in characters) {
      issues.addAll(validateCharacterRecord(character));
    }
    for (final node in worldNodes) {
      issues.addAll(validateWorldNodeRecord(node));
    }
    for (final auditIssue in auditIssues) {
      issues.addAll(validateAuditIssueRecord(auditIssue));
    }

    issues.addAll(_validateSceneReferences(
      projectId: project.id,
      scenes: scenes,
      characters: characters,
      worldNodes: worldNodes,
    ));

    // Validate that the project's sceneId references an existing scene.
    if (scenes.isNotEmpty &&
        !scenes.any((s) => s.id == project.sceneId)) {
      issues.add(ValidationIssue(
        severity: ValidationSeverity.warning,
        field: 'ProjectRecord(${project.id}).sceneId',
        message: '项目当前场景 ${project.sceneId} 不存在于场景列表中。',
      ));
    }

    final styleState = data.styleByProjectId[project.id];
    if (styleState != null) {
      for (final profile in styleState.profiles) {
        issues.addAll(validateStyleProfileRecord(profile));
      }
      if (styleState.intensity < 1 || styleState.intensity > 3) {
        issues.add(ValidationIssue(
          severity: ValidationSeverity.warning,
          field: 'ProjectStyleState(${project.id}).intensity',
          message: '风格强度 ${styleState.intensity} 超出合法范围 [1, 3]。',
        ));
      }
    }
  }

  // Check for orphan data: records that reference projects not in the list.
  for (final projectId in data.charactersByProjectId.keys) {
    if (!projectIds.contains(projectId)) {
      issues.add(ValidationIssue(
        severity: ValidationSeverity.warning,
        field: 'WorkspaceData.charactersByProjectId',
        message: '角色数据引用了不存在的项目 $projectId。',
      ));
    }
  }
  for (final projectId in data.scenesByProjectId.keys) {
    if (!projectIds.contains(projectId)) {
      issues.add(ValidationIssue(
        severity: ValidationSeverity.warning,
        field: 'WorkspaceData.scenesByProjectId',
        message: '场景数据引用了不存在的项目 $projectId。',
      ));
    }
  }

  return WorkspaceValidationResult(issues: issues);
}
