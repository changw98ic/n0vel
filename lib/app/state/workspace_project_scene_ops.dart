part of 'app_workspace_store.dart';

enum DeleteProjectStatus { deleted, notFound, failed }

/// Outcome of the awaitable project-deletion workflow.
class DeleteProjectResult {
  const DeleteProjectResult({
    required this.status,
    required this.projectId,
    this.error,
    this.stackTrace,
  });

  final DeleteProjectStatus status;
  final String projectId;
  final Object? error;
  final StackTrace? stackTrace;

  bool get succeeded => status == DeleteProjectStatus.deleted;
}

mixin _ProjectSceneOps on _WorkspaceFields {
  // ---------------------------------------------------------------------------
  // Project CRUD
  // ---------------------------------------------------------------------------

  void createProject({String? projectName}) {
    final nextIndex = _nextNewProjectIndex();
    _projects = sortProjects([
      ProjectRecord(
        id: generateProjectId(),
        sceneId: generateSceneId(),
        title: projectName ?? '新建项目 $nextIndex',
        genre: '悬疑 / 草稿',
        summary: '从空白书架里直接开始，先搭设定，还是先落正文都可以。',
        recentLocation: '第 1 章 / 场景 01 · 等待命名',
        lastOpenedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
      ..._projects,
    ]);
    _currentProjectId = _projects.first.id;
    _scenesByProjectId[_currentProjectId] = defaultScenesForProject(
      _projects.first,
    );
    _initializeProjectResources(_currentProjectId);
    _commitMutation();
    _publishWorkspaceEvent(ProjectCreatedEvent(projectId: _currentProjectId));
    _publishWorkspaceEvent(
      ProjectScopeChangedEvent(
        projectId: _currentProjectId,
        sceneScopeId: currentSceneScopeId,
      ),
    );
  }

  void deleteProject(ProjectRecord project) {
    final nextProjects = _projects
        .where((candidate) => candidate.id != project.id)
        .toList(growable: false);
    if (nextProjects.length == _projects.length) {
      return;
    }
    _projects = nextProjects;
    _charactersByProjectId.remove(project.id);
    _scenesByProjectId.remove(project.id);
    _worldNodesByProjectId.remove(project.id);
    _auditIssuesByProjectId.remove(project.id);
    _styleByProjectId.remove(project.id);
    _auditUiByProjectId.remove(project.id);
    _currentProjectId = _normalizeCurrentProjectId(
      preferredProjectId: _currentProjectId == project.id
          ? null
          : _currentProjectId,
      projects: _projects,
    );
    _commitMutation();
    _publishWorkspaceEvent(ProjectDeletedEvent(projectId: project.id));
    for (final cleaner in _projectDeletionCleaners) {
      unawaited(cleaner(project.id));
    }
  }

  /// Deletes a project only after all external project cleaners complete.
  ///
  /// The legacy [deleteProject] method remains synchronous for callers that
  /// only need the in-memory projection. Product deletion flows should use
  /// this method so a cleaner failure leaves the workspace intact and the
  /// operation can be retried without duplicating work.
  Future<DeleteProjectResult> deleteProjectAndWait(ProjectRecord project) {
    final existing = _projectDeletionOperations[project.id];
    if (existing != null) return existing;
    final operation = _deleteProjectAndWait(project);
    _projectDeletionOperations[project.id] = operation;
    return operation.whenComplete(() {
      if (identical(_projectDeletionOperations[project.id], operation)) {
        _projectDeletionOperations.remove(project.id);
      }
    });
  }

  Future<DeleteProjectResult> _deleteProjectAndWait(
    ProjectRecord project,
  ) async {
    if (!_projects.any((candidate) => candidate.id == project.id)) {
      return DeleteProjectResult(
        status: DeleteProjectStatus.notFound,
        projectId: project.id,
      );
    }

    final projectionBeforeDelete = _ProjectProjectionSnapshot.capture(this);
    final startedAtMs = DateTime.now().millisecondsSinceEpoch;
    final existingTombstone = _projectDeletionTombstones[project.id];
    try {
      await flushPersistence();
      await _prepareProjectDeletionFlush?.call();
      await _prepareProjectDeletionBackup?.call();
      _projectDeletionTombstones[project.id] = {
        ...?existingTombstone,
        'status': 'pending',
        'startedAtMs': existingTombstone?['startedAtMs'] ?? startedAtMs,
        'lastAttemptAtMs': startedAtMs,
        'lastError': null,
      };
      _commitMutation();
      await flushPersistence();
      await Future.wait([
        for (final cleaner in _projectDeletionCleaners) cleaner(project.id),
      ]);
    } catch (error, stackTrace) {
      _projectDeletionTombstones[project.id] = {
        ...?existingTombstone,
        'status': 'failed',
        'startedAtMs': existingTombstone?['startedAtMs'] ?? startedAtMs,
        'lastAttemptAtMs': startedAtMs,
        'lastError': error.toString(),
      };
      _commitMutation();
      unawaited(flushPersistence());
      return DeleteProjectResult(
        status: DeleteProjectStatus.failed,
        projectId: project.id,
        error: error,
        stackTrace: stackTrace,
      );
    }

    _removeProjectProjection(project);
    _projectDeletionTombstones.remove(project.id);
    _commitMutation();
    try {
      await flushPersistence();
    } catch (error, stackTrace) {
      _restoreProjectProjection(projectionBeforeDelete);
      _projectDeletionTombstones[project.id] = {
        ...?existingTombstone,
        'status': 'failed',
        'startedAtMs': existingTombstone?['startedAtMs'] ?? startedAtMs,
        'lastAttemptAtMs': DateTime.now().millisecondsSinceEpoch,
        'lastError': error.toString(),
      };
      _commitMutation();
      return DeleteProjectResult(
        status: DeleteProjectStatus.failed,
        projectId: project.id,
        error: error,
        stackTrace: stackTrace,
      );
    }
    _publishWorkspaceEvent(ProjectDeletedEvent(projectId: project.id));
    return DeleteProjectResult(
      status: DeleteProjectStatus.deleted,
      projectId: project.id,
    );
  }

  void _removeProjectProjection(ProjectRecord project) {
    _projects = _projects
        .where((candidate) => candidate.id != project.id)
        .toList(growable: false);
    _charactersByProjectId.remove(project.id);
    _scenesByProjectId.remove(project.id);
    _worldNodesByProjectId.remove(project.id);
    _auditIssuesByProjectId.remove(project.id);
    _styleByProjectId.remove(project.id);
    _auditUiByProjectId.remove(project.id);
    _currentProjectId = _normalizeCurrentProjectId(
      preferredProjectId: _currentProjectId == project.id
          ? null
          : _currentProjectId,
      projects: _projects,
    );
  }

  void _restoreProjectProjection(_ProjectProjectionSnapshot snapshot) {
    _projects = snapshot.projects;
    _charactersByProjectId = snapshot.charactersByProjectId;
    _scenesByProjectId = snapshot.scenesByProjectId;
    _worldNodesByProjectId = snapshot.worldNodesByProjectId;
    _auditIssuesByProjectId = snapshot.auditIssuesByProjectId;
    _styleByProjectId = snapshot.styleByProjectId;
    _auditUiByProjectId = snapshot.auditUiByProjectId;
    _currentProjectId = snapshot.currentProjectId;
  }

  void selectProject(String projectId) {
    if (!hasProjectWithId(projectId) || _currentProjectId == projectId) {
      return;
    }
    _currentProjectId = projectId;
    _commitMutation();
    _publishWorkspaceEvent(
      ProjectScopeChangedEvent(
        projectId: _currentProjectId,
        sceneScopeId: currentSceneScopeId,
      ),
    );
  }

  void openProject(String projectId) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    var found = false;
    final nextProjects = <ProjectRecord>[];
    for (final project in _projects) {
      if (project.id == projectId) {
        found = true;
        nextProjects.add(project.copyWith(lastOpenedAtMs: nowMs));
      } else {
        nextProjects.add(project);
      }
    }
    if (!found) {
      return;
    }
    _projects = sortProjects(nextProjects);
    _currentProjectId = projectId;
    _ensureProjectResources(projectId);
    _commitMutation();
    _publishWorkspaceEvent(
      ProjectScopeChangedEvent(
        projectId: _currentProjectId,
        sceneScopeId: currentSceneScopeId,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Scene Management
  // ---------------------------------------------------------------------------

  @override
  void updateCurrentScene({
    required String sceneId,
    required String recentLocation,
  }) {
    if (_currentProjectId.isEmpty) {
      return;
    }
    final nextProjects = <ProjectRecord>[];
    var changed = false;
    for (final project in _projects) {
      if (project.id == _currentProjectId) {
        changed = true;
        final scenes = _scenesForProject(project.id);
        final sceneExists = scenes.any((scene) => scene.id == sceneId);
        _scenesByProjectId[project.id] = [
          if (!sceneExists)
            SceneRecord(
              id: sceneId,
              chapterLabel: chapterLabelFromRecentLocation(recentLocation),
              title: sceneTitleFromRecentLocation(recentLocation),
              summary: '等待补充目标、冲突和收束条件。',
            ),
          for (final scene in scenes)
            if (scene.id == sceneId)
              SceneRecord(
                id: scene.id,
                chapterLabel: chapterLabelFromRecentLocation(recentLocation),
                title: sceneTitleFromRecentLocation(recentLocation),
                summary: scene.summary,
              )
            else
              scene,
        ];
        nextProjects.add(
          project.copyWith(sceneId: sceneId, recentLocation: recentLocation),
        );
      } else {
        nextProjects.add(project);
      }
    }
    if (!changed) {
      return;
    }
    _projects = nextProjects;
    _commitMutation();
    _publishWorkspaceEvent(
      SceneChangedEvent(
        projectId: _currentProjectId,
        sceneId: sceneId,
        sceneScopeId: currentSceneScopeId,
      ),
    );
  }

  void createScene(String title) {
    if (_currentProjectId.isEmpty) {
      return;
    }
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      return;
    }
    final currentScenes = _scenesForCurrentProject();
    if (currentScenes.length == 1 &&
        (currentScenes.single.id != currentProject.sceneId ||
            currentScenes.single.title.trim() == '等待命名')) {
      final currentScene = currentScenes.single;
      final renamedScene = SceneRecord(
        id: currentScene.id,
        chapterLabel: currentScene.chapterLabel,
        title: trimmedTitle,
        summary: currentScene.summary.trim().isEmpty
            ? '等待补充目标、冲突和收束条件。'
            : currentScene.summary,
      );
      _scenesByProjectId[_currentProjectId] = [renamedScene];
      updateCurrentScene(
        sceneId: renamedScene.id,
        recentLocation: renamedScene.displayLocation,
      );
      notifyListeners();
      return;
    }
    final sceneId = generateSceneId();
    final scene = SceneRecord(
      id: sceneId,
      chapterLabel: nextSceneChapterLabel(currentScenes),
      title: trimmedTitle,
      summary: '等待补充目标、冲突和收束条件。',
    );
    _scenesByProjectId[_currentProjectId] = [...currentScenes, scene];
    updateCurrentScene(
      sceneId: scene.id,
      recentLocation: scene.displayLocation,
    );
    notifyListeners();
  }

  void renameCurrentScene(String title) {
    if (_currentProjectId.isEmpty) {
      return;
    }
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      return;
    }
    final currentSceneId = currentProject.sceneId;
    _scenesByProjectId[_currentProjectId] = [
      for (final scene in _scenesForCurrentProject())
        if (scene.id == currentSceneId)
          SceneRecord(
            id: scene.id,
            chapterLabel: scene.chapterLabel,
            title: trimmedTitle,
            summary: scene.summary,
          )
        else
          scene,
    ];
    updateCurrentScene(
      sceneId: currentSceneId,
      recentLocation: '${currentScene.chapterLabel} · $trimmedTitle',
    );
  }

  void updateCurrentSceneChapterLabel(String chapterLabel) {
    if (_currentProjectId.isEmpty) {
      return;
    }
    final trimmedLabel = chapterLabel.trim();
    if (trimmedLabel.isEmpty) {
      return;
    }
    final sceneSuffix = currentScene.locationParts.sceneLabel;
    final submittedParts = SceneLocationParts.fromLabel(trimmedLabel);
    final keepSceneSuffix =
        submittedParts.sceneLabel.isEmpty &&
        sceneSuffix.isNotEmpty &&
        currentScene.title.trim() != '等待命名' &&
        !_titleLooksLikeChapterHeading(currentScene.title);
    final nextLabel =
        submittedParts.sceneLabel.isNotEmpty ||
            sceneSuffix.isEmpty ||
            !keepSceneSuffix
        ? submittedParts.fullLabel
        : '${submittedParts.chapterLabel} / $sceneSuffix';
    final currentSceneId = currentProject.sceneId;
    _scenesByProjectId[_currentProjectId] = [
      for (final scene in _scenesForCurrentProject())
        if (scene.id == currentSceneId)
          SceneRecord(
            id: scene.id,
            chapterLabel: nextLabel,
            title: scene.title,
            summary: scene.summary,
          )
        else
          scene,
    ];
    updateCurrentScene(
      sceneId: currentSceneId,
      recentLocation: '$nextLabel · ${currentScene.title}',
    );
  }

  void updateCurrentSceneSummary(String summary) {
    if (_currentProjectId.isEmpty) {
      return;
    }
    final trimmedSummary = summary.trim();
    final nextSummary = trimmedSummary.isEmpty
        ? '等待补充目标、冲突和收束条件。'
        : trimmedSummary;
    final currentSceneId = currentProject.sceneId;
    _scenesByProjectId[_currentProjectId] = [
      for (final scene in _scenesForCurrentProject())
        if (scene.id == currentSceneId)
          SceneRecord(
            id: scene.id,
            chapterLabel: scene.chapterLabel,
            title: scene.title,
            summary: nextSummary,
          )
        else
          scene,
    ];
    _commitMutation();
  }

  void moveCurrentSceneUp() {
    if (_currentProjectId.isEmpty) {
      return;
    }
    final currentScenes = _scenesForCurrentProject();
    final currentIndex = currentScenes.indexWhere(
      (scene) => scene.id == currentProject.sceneId,
    );
    if (currentIndex <= 0) {
      return;
    }
    final reordered = List<SceneRecord>.from(currentScenes);
    final target = reordered.removeAt(currentIndex);
    reordered.insert(currentIndex - 1, target);
    _scenesByProjectId[_currentProjectId] = reordered;
    _commitMutation();
  }

  void moveCurrentSceneDown() {
    if (_currentProjectId.isEmpty) {
      return;
    }
    final currentScenes = _scenesForCurrentProject();
    final currentIndex = currentScenes.indexWhere(
      (scene) => scene.id == currentProject.sceneId,
    );
    if (currentIndex == -1 || currentIndex >= currentScenes.length - 1) {
      return;
    }
    final reordered = List<SceneRecord>.from(currentScenes);
    final target = reordered.removeAt(currentIndex);
    reordered.insert(currentIndex + 1, target);
    _scenesByProjectId[_currentProjectId] = reordered;
    _commitMutation();
  }

  void deleteCurrentScene() {
    if (!canDeleteCurrentScene) {
      return;
    }
    final projectId = _currentProjectId;
    final currentSceneId = currentProject.sceneId;
    final remaining = [
      for (final scene in _scenesForCurrentProject())
        if (scene.id != currentSceneId) scene,
    ];
    if (remaining.isEmpty) {
      return;
    }
    _scenesByProjectId[projectId] = remaining;
    _charactersByProjectId[projectId] = [
      for (final character in _charactersForProject(projectId))
        character.copyWith(
          linkedSceneIds: [
            for (final sceneId in character.linkedSceneIds)
              if (sceneId != currentSceneId) sceneId,
          ],
        ),
    ];
    _worldNodesByProjectId[projectId] = [
      for (final node in _worldNodesForProject(projectId))
        node.copyWith(
          linkedSceneIds: [
            for (final sceneId in node.linkedSceneIds)
              if (sceneId != currentSceneId) sceneId,
          ],
        ),
    ];
    updateCurrentScene(
      sceneId: remaining.first.id,
      recentLocation: remaining.first.displayLocation,
    );
  }

  // ---------------------------------------------------------------------------
  // Initialize Resources (used by createProject)
  // ---------------------------------------------------------------------------

  void _initializeProjectResources(String targetProjectId) {
    _charactersByProjectId[targetProjectId] = List<CharacterRecord>.from(
      defaultCharacters,
    );
    _scenesByProjectId[targetProjectId] = defaultScenesForProject(
      projectById(targetProjectId) ?? currentProject,
    );
    _worldNodesByProjectId[targetProjectId] = List<WorldNodeRecord>.from(
      defaultWorldNodes,
    );
    _auditIssuesByProjectId[targetProjectId] = _auditIssuesForProject(
      targetProjectId,
    );
    _styleByProjectId[targetProjectId] = _styleStateForProject(targetProjectId);
    _auditUiByProjectId[targetProjectId] = _auditUiStateForProject(
      targetProjectId,
    );
  }

  int _nextNewProjectIndex() {
    final pattern = RegExp(r'^新建项目\s+(\d+)$');
    var maxIndex = 0;
    for (final project in _projects) {
      final match = pattern.firstMatch(project.title.trim());
      if (match == null) {
        continue;
      }
      final index = int.tryParse(match.group(1) ?? '');
      if (index != null && index > maxIndex) {
        maxIndex = index;
      }
    }
    return maxIndex + 1;
  }

  bool _titleLooksLikeChapterHeading(String title) {
    return RegExp(r'^第[一二三四五六七八九十百千万零〇两0-9]+章').hasMatch(title.trim());
  }
}

class _ProjectProjectionSnapshot {
  const _ProjectProjectionSnapshot({
    required this.projects,
    required this.charactersByProjectId,
    required this.scenesByProjectId,
    required this.worldNodesByProjectId,
    required this.auditIssuesByProjectId,
    required this.styleByProjectId,
    required this.auditUiByProjectId,
    required this.currentProjectId,
  });

  final List<ProjectRecord> projects;
  final Map<String, List<CharacterRecord>> charactersByProjectId;
  final Map<String, List<SceneRecord>> scenesByProjectId;
  final Map<String, List<WorldNodeRecord>> worldNodesByProjectId;
  final Map<String, List<AuditIssueRecord>> auditIssuesByProjectId;
  final Map<String, ProjectStyleState> styleByProjectId;
  final Map<String, ProjectAuditUiState> auditUiByProjectId;
  final String currentProjectId;

  static _ProjectProjectionSnapshot capture(_WorkspaceFields fields) {
    return _ProjectProjectionSnapshot(
      projects: List<ProjectRecord>.of(fields._projects),
      charactersByProjectId: {
        for (final entry in fields._charactersByProjectId.entries)
          entry.key: List<CharacterRecord>.of(entry.value),
      },
      scenesByProjectId: {
        for (final entry in fields._scenesByProjectId.entries)
          entry.key: List<SceneRecord>.of(entry.value),
      },
      worldNodesByProjectId: {
        for (final entry in fields._worldNodesByProjectId.entries)
          entry.key: List<WorldNodeRecord>.of(entry.value),
      },
      auditIssuesByProjectId: {
        for (final entry in fields._auditIssuesByProjectId.entries)
          entry.key: List<AuditIssueRecord>.of(entry.value),
      },
      styleByProjectId: Map<String, ProjectStyleState>.of(
        fields._styleByProjectId,
      ),
      auditUiByProjectId: Map<String, ProjectAuditUiState>.of(
        fields._auditUiByProjectId,
      ),
      currentProjectId: fields._currentProjectId,
    );
  }
}
