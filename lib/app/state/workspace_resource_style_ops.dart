part of 'app_workspace_store.dart';

mixin _ResourceStyleOps on _WorkspaceFields {
  // ---------------------------------------------------------------------------
  // Character Management
  // ---------------------------------------------------------------------------

  void createCharacter() {
    final projectId = _currentProjectId;
    final existing = _charactersForProject(projectId);
    final nextIndex = existing.length + 1;
    _charactersByProjectId[projectId] = [
      CharacterRecord(
        id: generateScopedRecordId('character'),
        name: '新角色 $nextIndex',
        role: '待定义角色',
        note: '等待补充人物背景与驱动',
        need: '等待明确目标与风险',
        summary: '新角色已创建，可继续补充设定、关系和场景引用。',
        referenceSummary: '创建后可补充角色引用摘要与关联场景。',
      ),
      ...existing,
    ];
    _commitMutation();
  }

  void updateCharacter({
    required String characterId,
    String? name,
    String? role,
    String? note,
    String? need,
    String? summary,
    String? referenceSummary,
  }) {
    _charactersByProjectId[_currentProjectId] = [
      for (final character in _charactersForCurrentProject())
        if (character.id == characterId)
          character.copyWith(
            name: normalizeOptionalText(name, fallback: character.name),
            role: normalizeOptionalText(role, fallback: character.role),
            note: normalizeOptionalText(note, fallback: character.note),
            need: normalizeOptionalText(need, fallback: character.need),
            summary: normalizeOptionalText(
              summary,
              fallback: character.summary,
            ),
            referenceSummary: normalizeOptionalText(
              referenceSummary,
              fallback: character.referenceSummary,
            ),
          )
        else
          character,
    ];
    _commitMutation();
  }

  void setCharacterSceneLinked({
    required String characterId,
    required String sceneId,
    required bool linked,
  }) {
    _charactersByProjectId[_currentProjectId] = [
      for (final character in _charactersForCurrentProject())
        if (character.id == characterId)
          character.copyWith(
            linkedSceneIds: toggleSceneId(
              source: character.linkedSceneIds,
              sceneId: sceneId,
              linked: linked,
            ),
          )
        else
          character,
    ];
    _commitMutation();
  }

  // ---------------------------------------------------------------------------
  // World Node Management
  // ---------------------------------------------------------------------------

  void createWorldNode() {
    final projectId = _currentProjectId;
    final existing = _worldNodesForProject(projectId);
    final nextIndex = existing.length + 1;
    _worldNodesByProjectId[projectId] = [
      WorldNodeRecord(
        id: generateScopedRecordId('world'),
        title: '新节点 $nextIndex',
        location: '待定义区域',
        type: '待定义',
        detail: '等待补充规则、位置和依赖关系。',
        summary: '新节点已创建，可继续补充引用和约束。',
        ruleSummary: '创建后可补充规则摘要。',
        referenceSummary: '创建后可补充此节点影响的场景与引用。',
      ),
      ...existing,
    ];
    _commitMutation();
  }

  void updateWorldNode({
    required String nodeId,
    String? title,
    String? location,
    String? type,
    String? detail,
    String? summary,
    String? ruleSummary,
    String? referenceSummary,
  }) {
    _worldNodesByProjectId[_currentProjectId] = [
      for (final node in _worldNodesForCurrentProject())
        if (node.id == nodeId)
          node.copyWith(
            title: normalizeOptionalText(title, fallback: node.title),
            location: normalizeOptionalText(location, fallback: node.location),
            type: normalizeOptionalText(type, fallback: node.type),
            detail: normalizeOptionalText(detail, fallback: node.detail),
            summary: normalizeOptionalText(summary, fallback: node.summary),
            ruleSummary: normalizeOptionalText(
              ruleSummary,
              fallback: node.ruleSummary,
            ),
            referenceSummary: normalizeOptionalText(
              referenceSummary,
              fallback: node.referenceSummary,
            ),
          )
        else
          node,
    ];
    _commitMutation();
  }

  void setWorldNodeSceneLinked({
    required String nodeId,
    required String sceneId,
    required bool linked,
  }) {
    _worldNodesByProjectId[_currentProjectId] = [
      for (final node in _worldNodesForCurrentProject())
        if (node.id == nodeId)
          node.copyWith(
            linkedSceneIds: toggleSceneId(
              source: node.linkedSceneIds,
              sceneId: sceneId,
              linked: linked,
            ),
          )
        else
          node,
    ];
    _commitMutation();
  }

  // ---------------------------------------------------------------------------
  // Style Management
  // ---------------------------------------------------------------------------

  void setStyleInputMode(StyleInputMode mode) {
    final currentStyle = _styleStateForCurrentProject();
    if (currentStyle.inputMode == mode) {
      return;
    }
    _styleByProjectId[_currentProjectId] = currentStyle.copyWith(
      inputMode: mode,
    );
    _commitMutation();
  }

  void updateStyleQuestionnaireField(String fieldId, Object? value) {
    final currentStyle = _styleStateForCurrentProject();
    final nextDraft = Map<String, Object?>.from(
      currentStyle.questionnaireDraft,
    );
    nextDraft[fieldId] = value;
    _styleByProjectId[_currentProjectId] = currentStyle.copyWith(
      questionnaireDraft: nextDraft,
      workflowState: StyleWorkflowState.ready,
      workflowMessage: '问卷草稿已保存在当前项目。',
      warningMessages: styleWarningMessages(nextDraft),
    );
    _commitMutation();
  }

  void toggleStyleQuestionnaireTag(String fieldId, String value) {
    final currentValues = stringListFromRaw(styleQuestionnaireDraft[fieldId]);
    final nextValues = currentValues.contains(value)
        ? [
            for (final item in currentValues)
              if (item != value) item,
          ]
        : [...currentValues, value];
    updateStyleQuestionnaireField(fieldId, nextValues);
  }

  void setStyleJsonDraft(String value) {
    final currentStyle = _styleStateForCurrentProject();
    _styleByProjectId[_currentProjectId] = currentStyle.copyWith(
      jsonDraft: value,
      workflowState: value.trim().isEmpty
          ? StyleWorkflowState.empty
          : StyleWorkflowState.ready,
      workflowMessage: value.trim().isEmpty
          ? '尚未输入配置 JSON。'
          : 'JSON 草稿已保存在当前项目。',
    );
    _commitMutation();
  }

  void selectStyleProfile(String profileId) {
    final currentStyle = _styleStateForCurrentProject();
    StyleProfileRecord? profile;
    for (final item in currentStyle.profiles) {
      if (item.id == profileId) {
        profile = item;
        break;
      }
    }
    if (profile == null) {
      return;
    }
    _styleByProjectId[_currentProjectId] = currentStyle.copyWith(
      selectedProfileId: profile.id,
      questionnaireDraft: styleDraftFromProfileJson(profile.jsonData),
      jsonDraft: encodePrettyJson(profile.jsonData),
      workflowState: StyleWorkflowState.ready,
      workflowMessage: '已切换到风格配置「${profile.name}」。',
      warningMessages: styleWarningMessages(profile.jsonData),
    );
    _commitMutation();
  }

  void generateStyleProfileFromQuestionnaire() {
    final currentStyle = _styleStateForCurrentProject();
    final normalizedDraft = normalizeStyleDraft(
      currentStyle.questionnaireDraft,
    );
    final missingFields = missingStyleRequiredFields(normalizedDraft);
    if (missingFields.isNotEmpty) {
      _styleByProjectId[_currentProjectId] = currentStyle.copyWith(
        workflowState: StyleWorkflowState.missingRequiredFields,
        workflowMessage: '缺少必填字段：${missingFields.join('、')}',
        warningMessages: styleWarningMessages(normalizedDraft),
      );
      _commitMutation();
      return;
    }
    final profileJson = buildStyleProfileJson(normalizedDraft);
    saveStyleProfile(
      styleByProjectId: _styleByProjectId,
      projectId: _currentProjectId,
      profile: StyleProfileRecord(
        id: generateScopedRecordId('style'),
        name: profileJson['name']?.toString() ?? '未命名风格',
        source: 'questionnaire',
        jsonData: profileJson,
      ),
      workflowState: StyleWorkflowState.ready,
      workflowMessage: '已生成 StyleProfile，可绑定到项目或场景。',
    );
  }

  void importStyleFromJsonDraft() {
    final currentStyle = _styleStateForCurrentProject();
    final rawDraft = currentStyle.jsonDraft.trim();
    if (rawDraft.isEmpty) {
      _styleByProjectId[_currentProjectId] = currentStyle.copyWith(
        workflowState: StyleWorkflowState.empty,
        workflowMessage: '请先输入或粘贴 StyleProfileJson。',
      );
      _commitMutation();
      return;
    }
    Object? decoded;
    try {
      decoded = jsonDecode(rawDraft);
    } on FormatException {
      _styleByProjectId[_currentProjectId] = currentStyle.copyWith(
        workflowState: StyleWorkflowState.jsonError,
        workflowMessage: '配置文件格式非法，请检查 JSON 结构。',
      );
      _commitMutation();
      return;
    }
    if (decoded is! Map) {
      _styleByProjectId[_currentProjectId] = currentStyle.copyWith(
        workflowState: StyleWorkflowState.validationFailed,
        workflowMessage: '配置文件必须是对象结构。',
      );
      _commitMutation();
      return;
    }
    final result = validateStyleProfileJson(stringObjectMapFromRaw(decoded));
    if (result.state == StyleWorkflowState.unsupportedVersion ||
        result.state == StyleWorkflowState.missingRequiredFields ||
        result.state == StyleWorkflowState.validationFailed ||
        result.state == StyleWorkflowState.jsonError) {
      _styleByProjectId[_currentProjectId] = currentStyle.copyWith(
        workflowState: result.state,
        workflowMessage: result.message,
        warningMessages: result.warningMessages,
      );
      _commitMutation();
      return;
    }
    saveStyleProfile(
      styleByProjectId: _styleByProjectId,
      projectId: _currentProjectId,
      profile: StyleProfileRecord(
        id: generateScopedRecordId('style'),
        name: result.profileJson['name']?.toString() ?? '未命名风格',
        source: 'json',
        jsonData: result.profileJson,
      ),
      workflowState: result.state,
      workflowMessage: result.message,
      warningMessages: result.warningMessages,
    );
  }

  void increaseStyleIntensity() {
    final currentStyle = _styleStateForCurrentProject();
    if (currentStyle.intensity >= 3) {
      return;
    }
    _styleByProjectId[_currentProjectId] = currentStyle.copyWith(
      intensity: currentStyle.intensity + 1,
    );
    _commitMutation();
  }

  void decreaseStyleIntensity() {
    final currentStyle = _styleStateForCurrentProject();
    if (currentStyle.intensity <= 1) {
      return;
    }
    _styleByProjectId[_currentProjectId] = currentStyle.copyWith(
      intensity: currentStyle.intensity - 1,
    );
    _commitMutation();
  }

  void bindStyleToProject() {
    final currentStyle = _styleStateForCurrentProject();
    final activeName =
        selectedStyleProfile?.name ??
        normalizeStyleName(currentStyle.questionnaireDraft['profile_name']);
    _styleByProjectId[_currentProjectId] = currentStyle.copyWith(
      bindingFeedback:
          '已将「$activeName」绑定到项目默认风格，当前强度 ${currentStyle.intensity}x。',
    );
    _commitMutation();
  }

  void bindStyleToScene() {
    final currentStyle = _styleStateForCurrentProject();
    final activeName =
        selectedStyleProfile?.name ??
        normalizeStyleName(currentStyle.questionnaireDraft['profile_name']);
    _styleByProjectId[_currentProjectId] = currentStyle.copyWith(
      bindingFeedback: '当前场景覆盖为「$activeName」，场景级约束优先于项目默认值。',
      workflowState: StyleWorkflowState.sceneOverrideNotice,
      workflowMessage: '当前场景级绑定优先于项目级默认风格。',
    );
    _commitMutation();
  }
}
