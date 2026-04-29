part of 'app_workspace_store.dart';

mixin _AuditTransferOps on _WorkspaceCodec {
  // ---------------------------------------------------------------------------
  // Transfer
  // ---------------------------------------------------------------------------

  void exportCurrentProject() {
    _projectTransferState = ProjectTransferState.exportSuccess;
    _commitMutation();
  }

  void executeImport() {
    _projectTransferState =
        _projectTransferState == ProjectTransferState.overwriteConfirm
        ? ProjectTransferState.overwriteSuccess
        : ProjectTransferState.importSuccess;
    _commitMutation();
  }

  void setProjectTransferState(ProjectTransferState state) {
    if (_projectTransferState == state) {
      return;
    }
    _projectTransferState = state;
    _commitMutation();
  }

  // ---------------------------------------------------------------------------
  // Audit Management
  // ---------------------------------------------------------------------------

  void selectAuditIssue(int index) {
    final issues = auditIssues;
    if (index < 0 || index >= issues.length) {
      return;
    }
    selectAuditIssueById(issues[index].id);
  }

  void selectAuditIssueById(String issueId) {
    final issues = auditIssues;
    final nextIndex = issues.indexWhere((issue) => issue.id == issueId);
    if (nextIndex == -1) {
      return;
    }
    final currentAuditState = _selectedAuditStateForCurrentProject();
    if (currentAuditState.selectedIssueId == issueId &&
        currentAuditState.selectedIssueIndex == nextIndex) {
      return;
    }
    _auditUiByProjectId[_currentProjectId] = currentAuditState.copyWith(
      selectedIssueId: issueId,
      selectedIssueIndex: nextIndex,
    );
    _commitMutation();
  }

  void setAuditFilter(AuditIssueFilter filter) {
    final currentAuditState = _selectedAuditStateForCurrentProject();
    if (currentAuditState.filter == filter) {
      return;
    }
    final issues = auditIssues;
    final visibleIssues = [
      for (final issue in issues)
        if (filter == AuditIssueFilter.all || issue.status.name == filter.name)
          issue,
    ];
    final nextIssueId =
        visibleIssues.any(
          (issue) => issue.id == currentAuditState.selectedIssueId,
        )
        ? currentAuditState.selectedIssueId
        : (visibleIssues.isEmpty ? '' : visibleIssues.first.id);
    final nextIndex = nextIssueId.isEmpty
        ? 0
        : issues.indexWhere((issue) => issue.id == nextIssueId);
    _auditUiByProjectId[_currentProjectId] = currentAuditState.copyWith(
      filter: filter,
      selectedIssueId: nextIssueId,
      selectedIssueIndex: nextIndex < 0 ? 0 : nextIndex,
    );
    _commitMutation();
  }

  void updateSelectedAuditIgnoreReason(String value) {
    final currentIssue = selectedAuditIssue;
    updateAuditIssue(
      auditIssuesByProjectId: _auditIssuesByProjectId,
      auditUiByProjectId: _auditUiByProjectId,
      projectId: _currentProjectId,
      issueId: currentIssue.id,
      transform: (issue) => issue.copyWith(ignoreReason: value.trim()),
      actionFeedback: value.trim().isEmpty ? '请填写忽略原因。' : '忽略原因已保存。',
    );
  }

  void jumpToSelectedAuditScene() {
    final targetScene = _sceneForAuditIssue(selectedAuditIssue);
    if (targetScene != null) {
      updateCurrentScene(
        sceneId: targetScene.id,
        recentLocation: targetScene.displayLocation,
      );
    }
    updateAuditIssue(
      auditIssuesByProjectId: _auditIssuesByProjectId,
      auditUiByProjectId: _auditUiByProjectId,
      projectId: _currentProjectId,
      issueId: selectedAuditIssue.id,
      transform: (issue) => issue.copyWith(lastAction: '已跳转到 ${issue.target}'),
      actionFeedback: targetScene == null
          ? '未能定位到 ${selectedAuditIssue.target} 对应场景。'
          : '已跳转到关联场景 ${selectedAuditIssue.target}。',
    );
  }

  void markSelectedAuditIssueResolved() {
    updateAuditIssue(
      auditIssuesByProjectId: _auditIssuesByProjectId,
      auditUiByProjectId: _auditUiByProjectId,
      projectId: _currentProjectId,
      issueId: selectedAuditIssue.id,
      transform: (issue) => issue.copyWith(
        status: AuditIssueStatus.resolved,
        lastAction: '已标记为已处理',
      ),
      actionFeedback: '已标记为已处理，可在下一轮审计中复核。',
    );
  }

  void ignoreSelectedAuditIssue() {
    final currentIssue = selectedAuditIssue;
    if (currentIssue.ignoreReason.trim().isEmpty) {
      _auditUiByProjectId[_currentProjectId] =
          _selectedAuditStateForCurrentProject().copyWith(
            actionFeedback: '请先填写忽略原因。',
          );
      _commitMutation();
      return;
    }
    updateAuditIssue(
      auditIssuesByProjectId: _auditIssuesByProjectId,
      auditUiByProjectId: _auditUiByProjectId,
      projectId: _currentProjectId,
      issueId: currentIssue.id,
      transform: (issue) =>
          issue.copyWith(status: AuditIssueStatus.ignored, lastAction: '已忽略'),
      actionFeedback: '已忽略当前问题，并记录忽略原因。',
    );
  }

  // ---------------------------------------------------------------------------
  // Import
  // ---------------------------------------------------------------------------

  void importJson(Map<String, Object?> data) {
    _projects = _decodeProjects(data['projects']);
    _charactersByProjectId = _decodeCharactersByProject(
      rawByProject: data['charactersByProject'],
      legacyRaw: data['characters'],
      projects: _projects,
    );
    _scenesByProjectId = _decodeScenesByProject(
      rawByProject: data['scenesByProject'],
      projects: _projects,
    );
    _worldNodesByProjectId = _decodeWorldNodesByProject(
      rawByProject: data['worldNodesByProject'],
      legacyRaw: data['worldNodes'],
      projects: _projects,
    );
    _auditIssuesByProjectId = _decodeAuditIssuesByProject(
      rawByProject: data['auditIssuesByProject'],
      legacyRaw: data['auditIssues'],
      projects: _projects,
    );
    _styleByProjectId = _decodeStyleByProject(
      rawByProject: data['projectStyles'],
      legacyRaw: data,
      projects: _projects,
    );
    _auditUiByProjectId = _decodeAuditUiByProject(
      rawByProject: data['projectAuditStates'],
      legacyRaw: data,
      projects: _projects,
    );
    _projectTransferState = decodeProjectTransferState(
      data['projectTransferState'],
    );
    _currentProjectId = _normalizeCurrentProjectId(
      preferredProjectId: data['currentProjectId']?.toString(),
      projects: _projects,
    );
    _hasLocalMutations = true;
    unawaited(_persist());
    notifyListeners();
  }

  void importProjectJson(
    Map<String, Object?> data, {
    required bool overwriteExisting,
  }) {
    final rawProjects = data['projects'];
    if (rawProjects is! List) {
      return;
    }
    final incomingProjects = _decodeList(rawProjects, ProjectRecord.fromJson);
    if (incomingProjects.isEmpty) {
      return;
    }
    final incomingProject = incomingProjects.first.copyWith(
      lastOpenedAtMs: DateTime.now().millisecondsSinceEpoch,
    );

    final nextProjects = [
      for (final project in _projects)
        if (project.id != incomingProject.id) project,
    ];
    if (!overwriteExisting && !hasProjectWithId(incomingProject.id)) {
      nextProjects.insert(0, incomingProject);
    } else {
      nextProjects.add(incomingProject);
    }
    _projects = sortProjects(nextProjects);

    final incomingCharacters = _decodeCharactersByProject(
      rawByProject: data['charactersByProject'],
      legacyRaw: data['characters'],
      projects: [incomingProject],
    );
    final incomingScenes = _decodeScenesByProject(
      rawByProject: data['scenesByProject'],
      projects: [incomingProject],
    );
    final incomingWorldNodes = _decodeWorldNodesByProject(
      rawByProject: data['worldNodesByProject'],
      legacyRaw: data['worldNodes'],
      projects: [incomingProject],
    );
    final incomingAuditIssues = _decodeAuditIssuesByProject(
      rawByProject: data['auditIssuesByProject'],
      legacyRaw: data['auditIssues'],
      projects: [incomingProject],
    );
    final incomingStyles = _decodeStyleByProject(
      rawByProject: data['projectStyles'],
      legacyRaw: data,
      projects: [incomingProject],
    );
    final incomingAuditStates = _decodeAuditUiByProject(
      rawByProject: data['projectAuditStates'],
      legacyRaw: data,
      projects: [incomingProject],
    );

    _charactersByProjectId[incomingProject.id] =
        incomingCharacters[incomingProject.id] ?? const [];
    _scenesByProjectId[incomingProject.id] =
        incomingScenes[incomingProject.id] ?? const [];
    _worldNodesByProjectId[incomingProject.id] =
        incomingWorldNodes[incomingProject.id] ?? const [];
    _auditIssuesByProjectId[incomingProject.id] =
        incomingAuditIssues[incomingProject.id] ?? const [];
    _styleByProjectId[incomingProject.id] = incomingStyles[incomingProject.id]!;
    _auditUiByProjectId[incomingProject.id] =
        incomingAuditStates[incomingProject.id]!;

    _currentProjectId = incomingProject.id;
    _hasLocalMutations = true;
    unawaited(_persist());
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Audit Helpers
  // ---------------------------------------------------------------------------

  SceneRecord? _sceneForAuditIssue(AuditIssueRecord issue) {
    final sceneNumber = RegExp(
      r'场景\s*(\d+)',
    ).firstMatch(issue.target)?.group(1);
    if (sceneNumber == null) {
      return null;
    }
    final padded = sceneNumber.padLeft(2, '0');
    for (final scene in _scenesForCurrentProject()) {
      if (scene.chapterLabel.contains('场景 $padded')) {
        return scene;
      }
    }
    return null;
  }
}
