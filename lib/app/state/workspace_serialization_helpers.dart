import 'workspace_default_data.dart';
import 'workspace_style_helpers.dart';
import 'workspace_types.dart';

// ---------------------------------------------------------------------------
// Audit issue mutation
// ---------------------------------------------------------------------------

void updateAuditIssue({
  required Map<String, List<AuditIssueRecord>> auditIssuesByProjectId,
  required Map<String, ProjectAuditUiState> auditUiByProjectId,
  required String projectId,
  required String issueId,
  required AuditIssueRecord Function(AuditIssueRecord issue) transform,
  required String actionFeedback,
}) {
  auditIssuesByProjectId[projectId] = [
    for (final issue
        in auditIssuesByProjectId[projectId] ?? const <AuditIssueRecord>[])
      if (issue.id == issueId) transform(issue) else issue,
  ];
  final currentAuditState =
      auditUiByProjectId[projectId] ??
      const ProjectAuditUiState(
        selectedIssueId: '',
        selectedIssueIndex: 0,
        filter: AuditIssueFilter.all,
        actionFeedback: defaultAuditActionFeedback,
      );
  auditUiByProjectId[projectId] = currentAuditState.copyWith(
    actionFeedback: actionFeedback,
  );
}

// ---------------------------------------------------------------------------
// Raw-value decode helpers
// ---------------------------------------------------------------------------

List<Map<Object?, Object?>> listOfMapsFromRaw(Object? raw) {
  if (raw is! List) {
    return const <Map<Object?, Object?>>[];
  }
  return [
    for (final item in raw)
      if (item is Map) Map<Object?, Object?>.from(item),
  ];
}

int decodeClampedInt(
  Object? raw, {
  required int fallback,
  required int min,
  required int max,
}) {
  final parsed = int.tryParse(raw?.toString() ?? '');
  final value = parsed ?? fallback;
  return value.clamp(min, max);
}

StyleInputMode decodeStyleInputMode(Object? raw) {
  return switch (raw?.toString()) {
    'json' => StyleInputMode.json,
    _ => StyleInputMode.questionnaire,
  };
}

StyleWorkflowState decodeStyleWorkflowState(Object? raw) {
  return switch (raw?.toString()) {
    'empty' => StyleWorkflowState.empty,
    'jsonError' => StyleWorkflowState.jsonError,
    'unsupportedVersion' => StyleWorkflowState.unsupportedVersion,
    'unknownFieldsIgnored' => StyleWorkflowState.unknownFieldsIgnored,
    'missingRequiredFields' => StyleWorkflowState.missingRequiredFields,
    'validationFailed' => StyleWorkflowState.validationFailed,
    'maxProfilesReached' => StyleWorkflowState.maxProfilesReached,
    'sceneOverrideNotice' => StyleWorkflowState.sceneOverrideNotice,
    _ => StyleWorkflowState.ready,
  };
}

AuditIssueFilter decodeAuditIssueFilter(Object? raw) {
  return switch (raw?.toString()) {
    'open' => AuditIssueFilter.open,
    'resolved' => AuditIssueFilter.resolved,
    'ignored' => AuditIssueFilter.ignored,
    _ => AuditIssueFilter.all,
  };
}

ProjectTransferState decodeProjectTransferState(Object? raw) {
  return switch (raw?.toString()) {
    'importSuccess' => ProjectTransferState.importSuccess,
    'exportSuccess' => ProjectTransferState.exportSuccess,
    'overwriteSuccess' => ProjectTransferState.overwriteSuccess,
    'overwriteConfirm' => ProjectTransferState.overwriteConfirm,
    'invalidPackage' => ProjectTransferState.invalidPackage,
    'missingManifest' => ProjectTransferState.missingManifest,
    'noExportableProject' => ProjectTransferState.noExportableProject,
    'majorVersionBlocked' => ProjectTransferState.majorVersionBlocked,
    'minorVersionWarning' => ProjectTransferState.minorVersionWarning,
    _ => ProjectTransferState.ready,
  };
}

String normalizeCurrentProjectId({
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

// ---------------------------------------------------------------------------
// Generic list / map decode helpers
// ---------------------------------------------------------------------------

List<T> decodeList<T>(
  Object? raw,
  T Function(Map<Object?, Object?> json) decoder,
) {
  if (raw is! List) {
    return const [];
  }
  return [
    for (final item in raw)
      if (item is Map) decoder(Map<Object?, Object?>.from(item)),
  ];
}

Map<String, List<T>> decodeProjectRecordMap<T>({
  required Object? rawByProject,
  required Object? legacyRaw,
  required List<ProjectRecord> projects,
  required T Function(Map<Object?, Object?> json) decoder,
  required List<T> Function() fallbackFactory,
}) {
  if (rawByProject is Map) {
    final result = <String, List<T>>{};
    for (final entry in rawByProject.entries) {
      final value = entry.value;
      if (value is! List) {
        continue;
      }
      result[entry.key.toString()] = [
        for (final item in value)
          if (item is Map) decoder(Map<Object?, Object?>.from(item)),
      ];
    }
    for (final project in projects) {
      result.putIfAbsent(project.id, fallbackFactory);
    }
    return result;
  }

  final legacyDecoded = decodeList(legacyRaw, decoder);
  final fallback = legacyDecoded.isEmpty ? fallbackFactory() : legacyDecoded;
  return {for (final project in projects) project.id: List<T>.from(fallback)};
}

// ---------------------------------------------------------------------------
// Domain-specific decode functions
// ---------------------------------------------------------------------------

List<ProjectRecord> decodeProjects(Object? raw) {
  final decoded = decodeList(raw, ProjectRecord.fromJson);
  return decoded.isEmpty
      ? sortProjects(buildDefaultProjects())
      : sortProjects(decoded);
}

Map<String, List<CharacterRecord>> decodeCharactersByProject({
  required Object? rawByProject,
  required Object? legacyRaw,
  required List<ProjectRecord> projects,
}) {
  return decodeProjectRecordMap(
    rawByProject: rawByProject,
    legacyRaw: legacyRaw,
    projects: projects,
    decoder: CharacterRecord.fromJson,
    fallbackFactory: () => List<CharacterRecord>.from(defaultCharacters),
  );
}

Map<String, List<SceneRecord>> decodeScenesByProject({
  required Object? rawByProject,
  required List<ProjectRecord> projects,
}) {
  if (rawByProject is! Map) {
    return {
      for (final project in projects)
        project.id: defaultScenesForProject(project),
    };
  }
  final result = <String, List<SceneRecord>>{};
  for (final entry in rawByProject.entries) {
    final value = entry.value;
    if (value is! List) {
      continue;
    }
    result[entry.key.toString()] = [
      for (final item in value)
        if (item is Map) SceneRecord.fromJson(Map<Object?, Object?>.from(item)),
    ];
  }
  for (final project in projects) {
    result.putIfAbsent(project.id, () => defaultScenesForProject(project));
  }
  return result;
}

Map<String, List<WorldNodeRecord>> decodeWorldNodesByProject({
  required Object? rawByProject,
  required Object? legacyRaw,
  required List<ProjectRecord> projects,
}) {
  return decodeProjectRecordMap(
    rawByProject: rawByProject,
    legacyRaw: legacyRaw,
    projects: projects,
    decoder: WorldNodeRecord.fromJson,
    fallbackFactory: () => List<WorldNodeRecord>.from(defaultWorldNodes),
  );
}

Map<String, List<AuditIssueRecord>> decodeAuditIssuesByProject({
  required Object? rawByProject,
  required Object? legacyRaw,
  required List<ProjectRecord> projects,
}) {
  return decodeProjectRecordMap(
    rawByProject: rawByProject,
    legacyRaw: legacyRaw,
    projects: projects,
    decoder: AuditIssueRecord.fromJson,
    fallbackFactory: () => List<AuditIssueRecord>.from(defaultAuditIssues),
  );
}

Map<String, ProjectStyleState> decodeStyleByProject({
  required Object? rawByProject,
  required Map<String, Object?> legacyRaw,
  required List<ProjectRecord> projects,
}) {
  if (rawByProject is Map) {
    final result = <String, ProjectStyleState>{};
    for (final entry in rawByProject.entries) {
      final value = entry.value;
      if (value is! Map) {
        continue;
      }
      final questionnaireDraft = stringObjectMapFromRaw(
        value['questionnaireDraft'],
      );
      final profiles = [
        for (final item in listOfMapsFromRaw(value['styleProfiles']))
          StyleProfileRecord.fromJson(item),
      ];
      final selectedProfileId =
          value['selectedStyleProfileId']?.toString() ?? '';
      final fallbackStyle = defaultStyleState();
      final resolvedProfiles = profiles.isEmpty
          ? fallbackStyle.profiles
          : profiles;
      result[entry.key.toString()] = ProjectStyleState(
        inputMode: decodeStyleInputMode(value['styleInputMode']),
        intensity: decodeClampedInt(
          value['styleIntensity'],
          fallback: 1,
          min: 1,
          max: 3,
        ),
        bindingFeedback:
            value['styleBindingFeedback']?.toString() ??
            defaultStyleBindingFeedback,
        questionnaireDraft: questionnaireDraft.isEmpty
            ? fallbackStyle.questionnaireDraft
            : questionnaireDraft,
        jsonDraft:
            value['styleJsonDraft']?.toString() ??
            encodePrettyJson(resolvedProfiles.first.jsonData),
        profiles: resolvedProfiles,
        selectedProfileId: selectedProfileId.isEmpty
            ? resolvedProfiles.first.id
            : selectedProfileId,
        workflowState: decodeStyleWorkflowState(value['styleWorkflowState']),
        workflowMessage:
            value['styleWorkflowMessage']?.toString() ??
            fallbackStyle.workflowMessage,
        warningMessages: stringListFromRaw(value['styleWarningMessages']),
      );
    }
    return fillMissingProjectStyles(result, projects);
  }

  final fallback = defaultStyleState().copyWith(
    inputMode: decodeStyleInputMode(legacyRaw['styleInputMode']),
    intensity: decodeClampedInt(
      legacyRaw['styleIntensity'],
      fallback: 1,
      min: 1,
      max: 3,
    ),
    bindingFeedback:
        legacyRaw['styleBindingFeedback']?.toString() ??
        defaultStyleBindingFeedback,
  );
  return {for (final project in projects) project.id: fallback.copyWith()};
}

Map<String, ProjectAuditUiState> decodeAuditUiByProject({
  required Object? rawByProject,
  required Map<String, Object?> legacyRaw,
  required List<ProjectRecord> projects,
}) {
  if (rawByProject is Map) {
    final result = <String, ProjectAuditUiState>{};
    for (final entry in rawByProject.entries) {
      final value = entry.value;
      if (value is! Map) {
        continue;
      }
      result[entry.key.toString()] = ProjectAuditUiState(
        selectedIssueId: value['selectedAuditIssueId']?.toString() ?? '',
        selectedIssueIndex: decodeClampedInt(
          value['selectedAuditIssueIndex'],
          fallback: 0,
          min: 0,
          max: 999,
        ),
        filter: decodeAuditIssueFilter(value['auditFilter']),
        actionFeedback:
            value['auditActionFeedback']?.toString() ??
            defaultAuditActionFeedback,
      );
    }
    return fillMissingProjectAuditUi(result, projects);
  }

  final fallback = ProjectAuditUiState(
    selectedIssueId: legacyRaw['selectedAuditIssueId']?.toString() ?? '',
    selectedIssueIndex: decodeClampedInt(
      legacyRaw['selectedAuditIssueIndex'],
      fallback: 0,
      min: 0,
      max: 999,
    ),
    filter: decodeAuditIssueFilter(legacyRaw['auditFilter']),
    actionFeedback:
        legacyRaw['auditActionFeedback']?.toString() ??
        defaultAuditActionFeedback,
  );
  return {for (final project in projects) project.id: fallback};
}

// ---------------------------------------------------------------------------
// Fill-missing helpers
// ---------------------------------------------------------------------------

Map<String, ProjectStyleState> fillMissingProjectStyles(
  Map<String, ProjectStyleState> values,
  List<ProjectRecord> projects,
) {
  final filled = Map<String, ProjectStyleState>.from(values);
  for (final project in projects) {
    filled.putIfAbsent(project.id, defaultStyleState);
  }
  return filled;
}

Map<String, ProjectAuditUiState> fillMissingProjectAuditUi(
  Map<String, ProjectAuditUiState> values,
  List<ProjectRecord> projects,
) {
  final filled = Map<String, ProjectAuditUiState>.from(values);
  for (final project in projects) {
    filled.putIfAbsent(
      project.id,
      () => const ProjectAuditUiState(
        selectedIssueId: '',
        selectedIssueIndex: 0,
        filter: AuditIssueFilter.all,
        actionFeedback: defaultAuditActionFeedback,
      ),
    );
  }
  return filled;
}
