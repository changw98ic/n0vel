part of '../app_workspace_store.dart';

abstract interface class WorkspaceProjectSceneFacade {
  List<ProjectRecord> get projects;
  String get currentProjectId;
  ProjectRecord? get currentProjectOrNull;
  ProjectRecord get currentProject;
  String get currentProjectBreadcrumb;
  List<SceneRecord> get scenes;
  SceneRecord? get currentSceneOrNull;
  SceneRecord get currentScene;
  String get currentSceneScopeId;
  bool get canDeleteCurrentScene;

  bool hasProjectWithId(String projectId);
  ProjectRecord? projectById(String projectId);
  SceneRecord? sceneById(String projectId, String sceneId);

  void createProject({String? projectName});
  void deleteProject(ProjectRecord project);
  void selectProject(String projectId);
  void openProject(String projectId);
  void updateCurrentScene({
    required String sceneId,
    required String recentLocation,
  });
  void createScene(String title);
  void renameCurrentScene(String title);
  void updateCurrentSceneChapterLabel(String chapterLabel);
  void updateCurrentSceneSummary(String summary);
  void moveCurrentSceneUp();
  void moveCurrentSceneDown();
  void deleteCurrentScene();
}

abstract interface class WorkspaceResourceLibraryFacade {
  List<CharacterRecord> get characters;
  List<WorldNodeRecord> get worldNodes;

  CharacterRecord createCharacter();
  void updateCharacter({
    required String characterId,
    String? name,
    String? role,
    String? note,
    String? need,
    String? summary,
    String? referenceSummary,
  });
  void setCharacterSceneLinked({
    required String characterId,
    required String sceneId,
    required bool linked,
  });
  void deleteCharacter(String characterId);
  void createWorldNode();
  void updateWorldNode({
    required String nodeId,
    String? title,
    String? location,
    String? type,
    String? detail,
    String? summary,
    String? ruleSummary,
    String? referenceSummary,
  });
  void setWorldNodeSceneLinked({
    required String nodeId,
    required String sceneId,
    required bool linked,
  });
  void deleteWorldNode(String nodeId);
}

abstract interface class WorkspaceStyleFacade {
  StyleInputMode get styleInputMode;
  int get styleIntensity;
  String get styleBindingFeedback;
  Map<String, Object?> get styleQuestionnaireDraft;
  String get styleJsonDraft;
  List<StyleProfileRecord> get styleProfiles;
  String get selectedStyleProfileId;
  StyleProfileRecord? get selectedStyleProfile;
  StyleWorkflowState get styleWorkflowState;
  String get styleWorkflowMessage;
  List<String> get styleWarningMessages;

  void setStyleInputMode(StyleInputMode mode);
  void updateStyleQuestionnaireField(String fieldId, Object? value);
  void toggleStyleQuestionnaireTag(String fieldId, String value);
  void setStyleJsonDraft(String value);
  void selectStyleProfile(String profileId);
  void generateStyleProfileFromQuestionnaire();
  void importStyleFromJsonDraft();
  void increaseStyleIntensity();
  void decreaseStyleIntensity();
  void bindStyleToProject();
  void bindStyleToScene();
}

abstract interface class WorkspaceAuditFacade {
  List<AuditIssueRecord> get auditIssues;
  int get selectedAuditIssueIndex;
  AuditIssueRecord? get selectedAuditIssueOrNull;
  AuditIssueRecord get selectedAuditIssue;
  AuditIssueFilter get auditIssueFilter;
  List<AuditIssueRecord> get filteredAuditIssues;
  String get auditActionFeedback;

  void selectAuditIssue(int index);
  void selectAuditIssueById(String issueId);
  void setAuditFilter(AuditIssueFilter filter);
  void updateSelectedAuditIgnoreReason(String value);
  void jumpToSelectedAuditScene();
  void markSelectedAuditIssueResolved();
  void ignoreSelectedAuditIssue();
}

final class _AppWorkspaceProjectSceneFacade
    implements WorkspaceProjectSceneFacade {
  const _AppWorkspaceProjectSceneFacade(this._store);

  final AppWorkspaceStore _store;

  @override
  List<ProjectRecord> get projects => _store.projects;

  @override
  String get currentProjectId => _store.currentProjectId;

  @override
  ProjectRecord? get currentProjectOrNull => _store.currentProjectOrNull;

  @override
  ProjectRecord get currentProject => _store.currentProject;

  @override
  String get currentProjectBreadcrumb => _store.currentProjectBreadcrumb;

  @override
  List<SceneRecord> get scenes => _store.scenes;

  @override
  SceneRecord? get currentSceneOrNull => _store.currentSceneOrNull;

  @override
  SceneRecord get currentScene => _store.currentScene;

  @override
  String get currentSceneScopeId => _store.currentSceneScopeId;

  @override
  bool get canDeleteCurrentScene => _store.canDeleteCurrentScene;

  @override
  bool hasProjectWithId(String projectId) => _store.hasProjectWithId(projectId);

  @override
  ProjectRecord? projectById(String projectId) => _store.projectById(projectId);

  @override
  SceneRecord? sceneById(String projectId, String sceneId) =>
      _store.sceneById(projectId, sceneId);

  @override
  void createProject({String? projectName}) =>
      _store.createProject(projectName: projectName);

  @override
  void deleteProject(ProjectRecord project) => _store.deleteProject(project);

  @override
  void selectProject(String projectId) => _store.selectProject(projectId);

  @override
  void openProject(String projectId) => _store.openProject(projectId);

  @override
  void updateCurrentScene({
    required String sceneId,
    required String recentLocation,
  }) => _store.updateCurrentScene(
    sceneId: sceneId,
    recentLocation: recentLocation,
  );

  @override
  void createScene(String title) => _store.createScene(title);

  @override
  void renameCurrentScene(String title) => _store.renameCurrentScene(title);

  @override
  void updateCurrentSceneChapterLabel(String chapterLabel) =>
      _store.updateCurrentSceneChapterLabel(chapterLabel);

  @override
  void updateCurrentSceneSummary(String summary) =>
      _store.updateCurrentSceneSummary(summary);

  @override
  void moveCurrentSceneUp() => _store.moveCurrentSceneUp();

  @override
  void moveCurrentSceneDown() => _store.moveCurrentSceneDown();

  @override
  void deleteCurrentScene() => _store.deleteCurrentScene();
}

final class _AppWorkspaceResourceLibraryFacade
    implements WorkspaceResourceLibraryFacade {
  const _AppWorkspaceResourceLibraryFacade(this._store);

  final AppWorkspaceStore _store;

  @override
  List<CharacterRecord> get characters => _store.characters;

  @override
  List<WorldNodeRecord> get worldNodes => _store.worldNodes;

  @override
  CharacterRecord createCharacter() => _store.createCharacter();

  @override
  void updateCharacter({
    required String characterId,
    String? name,
    String? role,
    String? note,
    String? need,
    String? summary,
    String? referenceSummary,
  }) => _store.updateCharacter(
    characterId: characterId,
    name: name,
    role: role,
    note: note,
    need: need,
    summary: summary,
    referenceSummary: referenceSummary,
  );

  @override
  void setCharacterSceneLinked({
    required String characterId,
    required String sceneId,
    required bool linked,
  }) => _store.setCharacterSceneLinked(
    characterId: characterId,
    sceneId: sceneId,
    linked: linked,
  );

  @override
  void deleteCharacter(String characterId) =>
      _store.deleteCharacter(characterId);

  @override
  void createWorldNode() => _store.createWorldNode();

  @override
  void updateWorldNode({
    required String nodeId,
    String? title,
    String? location,
    String? type,
    String? detail,
    String? summary,
    String? ruleSummary,
    String? referenceSummary,
  }) => _store.updateWorldNode(
    nodeId: nodeId,
    title: title,
    location: location,
    type: type,
    detail: detail,
    summary: summary,
    ruleSummary: ruleSummary,
    referenceSummary: referenceSummary,
  );

  @override
  void setWorldNodeSceneLinked({
    required String nodeId,
    required String sceneId,
    required bool linked,
  }) => _store.setWorldNodeSceneLinked(
    nodeId: nodeId,
    sceneId: sceneId,
    linked: linked,
  );

  @override
  void deleteWorldNode(String nodeId) => _store.deleteWorldNode(nodeId);
}

final class _AppWorkspaceStyleFacade implements WorkspaceStyleFacade {
  const _AppWorkspaceStyleFacade(this._store);

  final AppWorkspaceStore _store;

  @override
  StyleInputMode get styleInputMode => _store.styleInputMode;

  @override
  int get styleIntensity => _store.styleIntensity;

  @override
  String get styleBindingFeedback => _store.styleBindingFeedback;

  @override
  Map<String, Object?> get styleQuestionnaireDraft =>
      _store.styleQuestionnaireDraft;

  @override
  String get styleJsonDraft => _store.styleJsonDraft;

  @override
  List<StyleProfileRecord> get styleProfiles => _store.styleProfiles;

  @override
  String get selectedStyleProfileId => _store.selectedStyleProfileId;

  @override
  StyleProfileRecord? get selectedStyleProfile => _store.selectedStyleProfile;

  @override
  StyleWorkflowState get styleWorkflowState => _store.styleWorkflowState;

  @override
  String get styleWorkflowMessage => _store.styleWorkflowMessage;

  @override
  List<String> get styleWarningMessages => _store.styleWarningMessages;

  @override
  void setStyleInputMode(StyleInputMode mode) => _store.setStyleInputMode(mode);

  @override
  void updateStyleQuestionnaireField(String fieldId, Object? value) =>
      _store.updateStyleQuestionnaireField(fieldId, value);

  @override
  void toggleStyleQuestionnaireTag(String fieldId, String value) =>
      _store.toggleStyleQuestionnaireTag(fieldId, value);

  @override
  void setStyleJsonDraft(String value) => _store.setStyleJsonDraft(value);

  @override
  void selectStyleProfile(String profileId) =>
      _store.selectStyleProfile(profileId);

  @override
  void generateStyleProfileFromQuestionnaire() =>
      _store.generateStyleProfileFromQuestionnaire();

  @override
  void importStyleFromJsonDraft() => _store.importStyleFromJsonDraft();

  @override
  void increaseStyleIntensity() => _store.increaseStyleIntensity();

  @override
  void decreaseStyleIntensity() => _store.decreaseStyleIntensity();

  @override
  void bindStyleToProject() => _store.bindStyleToProject();

  @override
  void bindStyleToScene() => _store.bindStyleToScene();
}

final class _AppWorkspaceAuditFacade implements WorkspaceAuditFacade {
  const _AppWorkspaceAuditFacade(this._store);

  final AppWorkspaceStore _store;

  @override
  List<AuditIssueRecord> get auditIssues => _store.auditIssues;

  @override
  int get selectedAuditIssueIndex => _store.selectedAuditIssueIndex;

  @override
  AuditIssueRecord? get selectedAuditIssueOrNull =>
      _store.selectedAuditIssueOrNull;

  @override
  AuditIssueRecord get selectedAuditIssue => _store.selectedAuditIssue;

  @override
  AuditIssueFilter get auditIssueFilter => _store.auditIssueFilter;

  @override
  List<AuditIssueRecord> get filteredAuditIssues => _store.filteredAuditIssues;

  @override
  String get auditActionFeedback => _store.auditActionFeedback;

  @override
  void selectAuditIssue(int index) => _store.selectAuditIssue(index);

  @override
  void selectAuditIssueById(String issueId) =>
      _store.selectAuditIssueById(issueId);

  @override
  void setAuditFilter(AuditIssueFilter filter) => _store.setAuditFilter(filter);

  @override
  void updateSelectedAuditIgnoreReason(String value) =>
      _store.updateSelectedAuditIgnoreReason(value);

  @override
  void jumpToSelectedAuditScene() => _store.jumpToSelectedAuditScene();

  @override
  void markSelectedAuditIssueResolved() =>
      _store.markSelectedAuditIssueResolved();

  @override
  void ignoreSelectedAuditIssue() => _store.ignoreSelectedAuditIssue();
}
