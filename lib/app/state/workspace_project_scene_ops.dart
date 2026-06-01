part of 'app_workspace_store.dart';

mixin _ProjectSceneOps on _WorkspaceFields {
  // ---------------------------------------------------------------------------
  // Project CRUD
  // ---------------------------------------------------------------------------

  ProjectRecord createProject({String? projectName}) {
    final nextIndex = _nextNewProjectIndex();
    final project = ProjectRecord(
      id: generateProjectId(),
      sceneId: generateSceneId(),
      title: projectName ?? '新建项目 $nextIndex',
      genre: '悬疑 / 草稿',
      summary: '从空白书架里直接开始，先搭设定，还是先落正文都可以。',
      recentLocation: '第 1 章 / 场景 01 · 等待命名',
      lastOpenedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    _projects = sortProjects([project, ..._projects]);
    _currentProjectId = project.id;
    _scenesByProjectId[_currentProjectId] = defaultScenesForProject(project);
    _initializeProjectResources(_currentProjectId);
    _commitMutation();
    _publishWorkspaceEvent(ProjectCreatedEvent(projectId: _currentProjectId));
    _publishWorkspaceEvent(
      ProjectScopeChangedEvent(
        projectId: _currentProjectId,
        sceneScopeId: currentSceneScopeId,
      ),
    );
    return project;
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
