part of 'app_workspace_store.dart';

// ============================================================================
// Decode / Encode Mixin
// ============================================================================

mixin _WorkspaceCodec on _WorkspaceFields {
  // ---------------------------------------------------------------------------
  // Restore & Persist
  // ---------------------------------------------------------------------------

  @override
  Future<void> _restore() async {
    final restored = await _storage.load();
    if (restored == null || _hasLocalMutations) {
      return;
    }

    _projects = _decodeProjects(restored['projects']);
    _charactersByProjectId = _decodeCharactersByProject(
      rawByProject: restored['charactersByProject'],
      legacyRaw: restored['characters'],
      projects: _projects,
    );
    _scenesByProjectId = _decodeScenesByProject(
      rawByProject: restored['scenesByProject'],
      projects: _projects,
    );
    _worldNodesByProjectId = _decodeWorldNodesByProject(
      rawByProject: restored['worldNodesByProject'],
      legacyRaw: restored['worldNodes'],
      projects: _projects,
    );
    _auditIssuesByProjectId = _decodeAuditIssuesByProject(
      rawByProject: restored['auditIssuesByProject'],
      legacyRaw: restored['auditIssues'],
      projects: _projects,
    );
    _styleByProjectId = _decodeStyleByProject(
      rawByProject: restored['projectStyles'],
      legacyRaw: restored,
      projects: _projects,
    );
    _auditUiByProjectId = _decodeAuditUiByProject(
      rawByProject: restored['projectAuditStates'],
      legacyRaw: restored,
      projects: _projects,
    );
    _projectTransferState = decodeProjectTransferState(
      restored['projectTransferState'],
    );
    _currentProjectId = _normalizeCurrentProjectId(
      preferredProjectId: restored['currentProjectId']?.toString(),
      projects: _projects,
    );
    notifyListeners();
  }

  @override
  Future<void> _persist() async {
    await _storage.save(exportJson());
  }

  // ---------------------------------------------------------------------------
  // Decode Methods
  // ---------------------------------------------------------------------------

  List<ProjectRecord> _decodeProjects(Object? raw) {
    final decoded = _decodeList(raw, ProjectRecord.fromJson);
    return decoded.isEmpty
        ? sortProjects(buildDefaultProjects())
        : sortProjects(decoded);
  }

  Map<String, List<CharacterRecord>> _decodeCharactersByProject({
    required Object? rawByProject,
    required Object? legacyRaw,
    required List<ProjectRecord> projects,
  }) {
    return _decodeProjectRecordMap(
      rawByProject: rawByProject,
      legacyRaw: legacyRaw,
      projects: projects,
      decoder: CharacterRecord.fromJson,
      fallbackFactory: () => List<CharacterRecord>.from(defaultCharacters),
    );
  }

  Map<String, List<SceneRecord>> _decodeScenesByProject({
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
          if (item is Map)
            SceneRecord.fromJson(Map<Object?, Object?>.from(item)),
      ];
    }
    for (final project in projects) {
      result.putIfAbsent(project.id, () => defaultScenesForProject(project));
    }
    return result;
  }

  Map<String, List<WorldNodeRecord>> _decodeWorldNodesByProject({
    required Object? rawByProject,
    required Object? legacyRaw,
    required List<ProjectRecord> projects,
  }) {
    return _decodeProjectRecordMap(
      rawByProject: rawByProject,
      legacyRaw: legacyRaw,
      projects: projects,
      decoder: WorldNodeRecord.fromJson,
      fallbackFactory: () => List<WorldNodeRecord>.from(defaultWorldNodes),
    );
  }

  Map<String, List<AuditIssueRecord>> _decodeAuditIssuesByProject({
    required Object? rawByProject,
    required Object? legacyRaw,
    required List<ProjectRecord> projects,
  }) {
    return _decodeProjectRecordMap(
      rawByProject: rawByProject,
      legacyRaw: legacyRaw,
      projects: projects,
      decoder: AuditIssueRecord.fromJson,
      fallbackFactory: () => List<AuditIssueRecord>.from(defaultAuditIssues),
    );
  }

  Map<String, ProjectStyleState> _decodeStyleByProject({
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
      return _fillMissingProjectStyles(result, projects);
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

  Map<String, ProjectAuditUiState> _decodeAuditUiByProject({
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
      return _fillMissingProjectAuditUi(result, projects);
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
  // Decode Helpers
  // ---------------------------------------------------------------------------

  List<T> _decodeList<T>(
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

  Map<String, List<T>> _decodeProjectRecordMap<T>({
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

    final legacyDecoded = _decodeList(legacyRaw, decoder);
    final fallback = legacyDecoded.isEmpty ? fallbackFactory() : legacyDecoded;
    return {for (final project in projects) project.id: List<T>.from(fallback)};
  }

  // ---------------------------------------------------------------------------
  // Fill Missing
  // ---------------------------------------------------------------------------

  Map<String, ProjectStyleState> _fillMissingProjectStyles(
    Map<String, ProjectStyleState> values,
    List<ProjectRecord> projects,
  ) {
    final filled = Map<String, ProjectStyleState>.from(values);
    for (final project in projects) {
      filled.putIfAbsent(project.id, defaultStyleState);
    }
    return filled;
  }

  Map<String, ProjectAuditUiState> _fillMissingProjectAuditUi(
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

  @override
  void _ensureProjectResources(String projectId) {
    _charactersByProjectId.putIfAbsent(
      projectId,
      () => List<CharacterRecord>.from(defaultCharacters),
    );
    _scenesByProjectId.putIfAbsent(
      projectId,
      () => defaultScenesForProject(projectById(projectId) ?? currentProject),
    );
    _worldNodesByProjectId.putIfAbsent(
      projectId,
      () => List<WorldNodeRecord>.from(defaultWorldNodes),
    );
    _auditIssuesByProjectId.putIfAbsent(
      projectId,
      () => List<AuditIssueRecord>.from(defaultAuditIssues),
    );
    _styleByProjectId.putIfAbsent(projectId, defaultStyleState);
    _auditUiByProjectId.putIfAbsent(
      projectId,
      () => const ProjectAuditUiState(
        selectedIssueId: '',
        selectedIssueIndex: 0,
        filter: AuditIssueFilter.all,
        actionFeedback: defaultAuditActionFeedback,
      ),
    );
  }
}
