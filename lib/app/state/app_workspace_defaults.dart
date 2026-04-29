import 'dart:convert';

import 'app_workspace_records.dart';

class ProjectStyleState {
  const ProjectStyleState({
    required this.inputMode,
    required this.intensity,
    required this.bindingFeedback,
    required this.questionnaireDraft,
    required this.jsonDraft,
    required this.profiles,
    required this.selectedProfileId,
    required this.workflowState,
    required this.workflowMessage,
    required this.warningMessages,
  });

  final StyleInputMode inputMode;
  final int intensity;
  final String bindingFeedback;
  final Map<String, Object?> questionnaireDraft;
  final String jsonDraft;
  final List<StyleProfileRecord> profiles;
  final String selectedProfileId;
  final StyleWorkflowState workflowState;
  final String workflowMessage;
  final List<String> warningMessages;

  Map<String, Object?> toJson() {
    return {
      'styleInputMode': inputMode.name,
      'styleIntensity': intensity,
      'styleBindingFeedback': bindingFeedback,
      'questionnaireDraft': questionnaireDraft,
      'styleJsonDraft': jsonDraft,
      'styleProfiles': [for (final profile in profiles) profile.toJson()],
      'selectedStyleProfileId': selectedProfileId,
      'styleWorkflowState': workflowState.name,
      'styleWorkflowMessage': workflowMessage,
      'styleWarningMessages': warningMessages,
    };
  }

  ProjectStyleState copyWith({
    StyleInputMode? inputMode,
    int? intensity,
    String? bindingFeedback,
    Map<String, Object?>? questionnaireDraft,
    String? jsonDraft,
    List<StyleProfileRecord>? profiles,
    String? selectedProfileId,
    StyleWorkflowState? workflowState,
    String? workflowMessage,
    List<String>? warningMessages,
  }) {
    return ProjectStyleState(
      inputMode: inputMode ?? this.inputMode,
      intensity: intensity ?? this.intensity,
      bindingFeedback: bindingFeedback ?? this.bindingFeedback,
      questionnaireDraft: questionnaireDraft ?? this.questionnaireDraft,
      jsonDraft: jsonDraft ?? this.jsonDraft,
      profiles: profiles ?? this.profiles,
      selectedProfileId: selectedProfileId ?? this.selectedProfileId,
      workflowState: workflowState ?? this.workflowState,
      workflowMessage: workflowMessage ?? this.workflowMessage,
      warningMessages: warningMessages ?? this.warningMessages,
    );
  }
}

class ProjectAuditUiState {
  const ProjectAuditUiState({
    required this.selectedIssueId,
    required this.selectedIssueIndex,
    required this.filter,
    required this.actionFeedback,
  });

  final String selectedIssueId;
  final int selectedIssueIndex;
  final AuditIssueFilter filter;
  final String actionFeedback;

  Map<String, Object?> toJson() {
    return {
      'selectedAuditIssueId': selectedIssueId,
      'selectedAuditIssueIndex': selectedIssueIndex,
      'auditFilter': filter.name,
      'auditActionFeedback': actionFeedback,
    };
  }

  ProjectAuditUiState copyWith({
    String? selectedIssueId,
    int? selectedIssueIndex,
    AuditIssueFilter? filter,
    String? actionFeedback,
  }) {
    return ProjectAuditUiState(
      selectedIssueId: selectedIssueId ?? this.selectedIssueId,
      selectedIssueIndex: selectedIssueIndex ?? this.selectedIssueIndex,
      filter: filter ?? this.filter,
      actionFeedback: actionFeedback ?? this.actionFeedback,
    );
  }
}

class StyleValidationResult {
  const StyleValidationResult({
    required this.state,
    required this.message,
    required this.warningMessages,
    required this.profileJson,
  });

  final StyleWorkflowState state;
  final String message;
  final List<String> warningMessages;
  final Map<String, Object?> profileJson;
}

const defaultStyleBindingFeedback = '反馈会说明当前绑定范围、已同步的规则集和强度建议。';
const defaultAuditActionFeedback = '等待处理';

const defaultCharacters = <CharacterRecord>[
  CharacterRecord(
    id: 'character-liuxi',
    name: '柳溪',
    role: '调查记者',
    note: '失去搭档后的控制欲',
    need: '承认她也会判断失误',
    summary: '冷静、急迫、对线索高度敏感，对冲突说话速度会变快。',
    referenceSummary: '在雨夜码头与证人房间对峙两场里保持视角稳定。',
    linkedSceneIds: ['scene-03-rainy-dock', 'scene-05-witness-room'],
  ),
  CharacterRecord(
    id: 'character-yueren',
    name: '岳人',
    role: '线人 / 交通调度',
    note: '把自己放进最危险的交汇点',
    need: '在保命和忠诚之间做一次明确选择',
    summary: '说话更快，信息密度高，遇到追问会先交代事实再谈立场。',
    referenceSummary: '主要在证人房间提供交通调度信息并牵动后续仓库夜谈。',
    linkedSceneIds: ['scene-05-witness-room', 'scene-12-warehouse-talk'],
  ),
  CharacterRecord(
    id: 'character-fuxingzhou',
    name: '傅行舟',
    role: '码头保全主管',
    note: '把秩序看得高于情感',
    need: '承认规则并不能替代信任',
    summary: '言辞短促，控制边界感强，情绪几乎只通过停顿显露。',
    referenceSummary: '负责旧港规则的执行口径，也是门禁判断压力的直接来源。',
    linkedSceneIds: ['scene-03-rainy-dock'],
  ),
];

const defaultWorldNodes = <WorldNodeRecord>[
  WorldNodeRecord(
    id: 'world-old-harbor-rules',
    title: '旧港规则',
    location: '旧港城',
    type: '规则',
    detail: '风暴前两小时内，外来船只不得靠泊。',
    summary: '进入风暴预警后的仓库，出入口需要重新验证定位和通行状态。',
    ruleSummary: '风暴预警触发后，所有出入口二次核验。',
    referenceSummary: '会直接影响雨夜码头与仓库夜谈两场的行动路线。',
    linkedSceneIds: ['scene-03-rainy-dock', 'scene-12-warehouse-talk'],
  ),
  WorldNodeRecord(
    id: 'world-storm',
    title: '码头风暴',
    location: '外海边缘',
    type: '气候事件',
    detail: '风暴会切断旧港的临时照明与无线链路。',
    summary: '风暴会压缩行动窗口，并改变人物的出入口选择。',
    ruleSummary: '临时照明与链路失效后，角色会被迫改道。',
    referenceSummary: '压缩证人房间与码头追索段的可行动时间。',
    linkedSceneIds: ['scene-03-rainy-dock', 'scene-05-witness-room'],
  ),
  WorldNodeRecord(
    id: 'world-invalid-script',
    title: '失效脚本',
    location: '保全部门',
    type: '流程',
    detail: '旧脚本仍在巡检系统中误触发。',
    summary: '会导致仓库门禁记录偏移，给追逐段制造错位信息。',
    ruleSummary: '旧脚本触发时，门禁记录会与真实通行不一致。',
    referenceSummary: '是仓库层数记录偏移与时间线跳跃两条审计问题的共同来源。',
    linkedSceneIds: ['scene-05-witness-room', 'scene-12-warehouse-talk'],
  ),
];

const defaultAuditIssues = <AuditIssueRecord>[
  AuditIssueRecord(
    id: 'audit-motive-conflict',
    title: '角色动机冲突',
    evidence: '角色上一场景处于防御姿态，但当前段落突然主动进攻，且动机说明不足。',
    target: '场景 05',
  ),
  AuditIssueRecord(
    id: 'audit-warehouse-floor',
    title: '误把仓库当一层',
    evidence: '仓库层数认知与旧港地图不一致，可能导致后续追逐段空间关系错位。',
    target: '场景 04',
  ),
  AuditIssueRecord(
    id: 'audit-timeline-gap',
    title: '时间线跳跃',
    evidence: '同一小时内出现了两次不可能同时成立的行动记录。',
    target: '场景 06',
  ),
];

const defaultStyleQuestionnaireDraft = <String, Object?>{
  'profile_name': '冷峻悬疑第一人称',
  'language': 'zh-CN',
  'genre_tags': ['悬疑'],
  'audience_tone': ['冷峻', '压抑'],
  'pov_mode': 'third_person_limited',
  'narrative_distance': 'close',
  'inner_monologue_ratio': 'medium',
  'sentence_length_preference': 'short_medium',
  'rhythm_profile': 'tight',
  'lexical_density': 'balanced',
  'metaphor_intensity': 'low',
  'dialogue_ratio': 'medium',
  'description_density': 'medium',
  'action_focus': 'high',
  'sensory_focus': ['视觉', '空间感'],
  'emotional_intensity': 'medium_high',
  'tone_keywords': ['压迫', '克制', '湿冷'],
  'violence_explicitness': 'suggestive',
  'taboo_patterns': ['过度抒情', '全知解释', '空泛形容词'],
  'custom_notes': '优先通过动作和环境传达紧张，不直接讲解人物心理。',
  'suspense_release_rate': 'slow',
};

List<ProjectRecord> buildDefaultProjects() {
  final now = DateTime.now();
  return [
    ProjectRecord(
      id: 'project-yuechao',
      sceneId: 'scene-05-witness-room',
      title: '月潮回声',
      genre: '悬疑 / 8.7 万字',
      summary: '证人房间的对峙停在最危险的地方，只差最后一步就会撬开旧港城的暗线。',
      recentLocation: '第 3 章 / 场景 05 · 证人房间对峙',
      lastOpenedAtMs: now.millisecondsSinceEpoch,
    ),
    ProjectRecord(
      id: 'project-yangang',
      sceneId: 'scene-12-warehouse-talk',
      title: '盐港档案',
      genre: '都市现实 / 4.3 万字',
      summary: '仓库夜谈刚写到一半，线人给出的口供还没有被彻底拆开。',
      recentLocation: '第 1 卷 / 场景 12 · 仓库夜谈',
      lastOpenedAtMs: now
          .subtract(const Duration(days: 1))
          .millisecondsSinceEpoch,
    ),
    ProjectRecord(
      id: 'project-huijin',
      sceneId: 'scene-03-platform-farewell',
      title: '灰烬天气',
      genre: '成长 / 2.1 万字',
      summary: '站台告别之后的那场沉默还没补完，整段情绪需要再收紧一次。',
      recentLocation: '第 2 章 / 场景 03 · 站台告别',
      lastOpenedAtMs: now
          .subtract(const Duration(days: 3))
          .millisecondsSinceEpoch,
    ),
  ];
}

Map<String, List<CharacterRecord>> buildDefaultProjectCharacters(
  List<ProjectRecord> projects,
) {
  return {
    for (final project in projects)
      project.id: List<CharacterRecord>.from(defaultCharacters),
  };
}

Map<String, List<SceneRecord>> buildDefaultProjectScenes(
  List<ProjectRecord> projects,
) {
  return {
    for (final project in projects)
      project.id: defaultScenesForProject(project),
  };
}

Map<String, List<WorldNodeRecord>> buildDefaultProjectWorldNodes(
  List<ProjectRecord> projects,
) {
  return {
    for (final project in projects)
      project.id: List<WorldNodeRecord>.from(defaultWorldNodes),
  };
}

Map<String, List<AuditIssueRecord>> buildDefaultProjectAuditIssues(
  List<ProjectRecord> projects,
) {
  return {
    for (final project in projects)
      project.id: List<AuditIssueRecord>.from(defaultAuditIssues),
  };
}

Map<String, ProjectStyleState> buildDefaultProjectStyles(
  List<ProjectRecord> projects,
) {
  return {for (final project in projects) project.id: defaultStyleState()};
}

Map<String, ProjectAuditUiState> buildDefaultProjectAuditUi(
  List<ProjectRecord> projects,
) {
  return {
    for (final project in projects)
      project.id: const ProjectAuditUiState(
        selectedIssueId: '',
        selectedIssueIndex: 0,
        filter: AuditIssueFilter.all,
        actionFeedback: defaultAuditActionFeedback,
      ),
  };
}

List<SceneRecord> defaultScenesForProject(ProjectRecord project) {
  switch (project.id) {
    case 'project-yuechao':
      return const [
        SceneRecord(
          id: 'scene-03-rainy-dock',
          chapterLabel: '第 3 章 / 场景 03',
          title: '雨夜码头',
          summary: '柳溪在雨夜码头继续追索失效脚本的前情。',
        ),
        SceneRecord(
          id: 'scene-05-witness-room',
          chapterLabel: '第 3 章 / 场景 05',
          title: '证人房间对峙',
          summary: '证人与柳溪的对峙停在最危险的地方。',
        ),
      ];
    case 'project-yangang':
      return const [
        SceneRecord(
          id: 'scene-12-warehouse-talk',
          chapterLabel: '第 1 卷 / 场景 12',
          title: '仓库夜谈',
          summary: '仓库里的夜谈把第一层口供缓慢拆开。',
        ),
      ];
    case 'project-huijin':
      return const [
        SceneRecord(
          id: 'scene-03-platform-farewell',
          chapterLabel: '第 2 章 / 场景 03',
          title: '站台告别',
          summary: '站台上的告别留下一段没有收束的沉默。',
        ),
      ];
    default:
      return [
        SceneRecord(
          id: project.sceneId,
          chapterLabel: chapterLabelFromRecentLocation(project.recentLocation),
          title: sceneTitleFromRecentLocation(project.recentLocation),
          summary: '等待补充场景目标、冲突和收束条件。',
        ),
      ];
  }
}

List<ProjectRecord> sortProjects(List<ProjectRecord> projects) {
  final sorted = List<ProjectRecord>.from(projects);
  sorted.sort(
    (left, right) => right.lastOpenedAtMs.compareTo(left.lastOpenedAtMs),
  );
  return sorted;
}

String chapterLabelFromRecentLocation(String recentLocation) {
  final parts = recentLocation.split('·');
  return parts.first.trim();
}

String sceneTitleFromRecentLocation(String recentLocation) {
  final parts = recentLocation.split('·');
  if (parts.length < 2) {
    return recentLocation;
  }
  return parts.last.trim();
}

String nextSceneChapterLabel(List<SceneRecord> scenes) {
  if (scenes.isEmpty) {
    return '第 1 章 / 场景 01';
  }
  final chapterPrefix = scenes.last.chapterLabel.split('/').first.trim();
  final sceneNumbers = scenes
      .map(
        (scene) =>
            RegExp(r'场景\s*(\d+)').firstMatch(scene.chapterLabel)?.group(1),
      )
      .whereType<String>()
      .map(int.parse);
  final nextNumber = sceneNumbers.isEmpty
      ? 1
      : sceneNumbers.reduce((a, b) => a > b ? a : b) + 1;
  return '$chapterPrefix / 场景 ${nextNumber.toString().padLeft(2, '0')}';
}

String normalizeOptionalText(String? value, {required String fallback}) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return fallback;
  }
  return trimmed;
}

List<String> toggleSceneId({
  required List<String> source,
  required String sceneId,
  required bool linked,
}) {
  final next = <String>[
    for (final item in source)
      if (item != sceneId) item,
  ];
  if (linked) {
    next.add(sceneId);
  }
  return next;
}

String encodePrettyJson(Map<String, Object?> jsonData) {
  return const JsonEncoder.withIndent('  ').convert(jsonData);
}

String normalizeStyleName(Object? rawName) {
  final trimmed = rawName?.toString().trim() ?? '';
  return trimmed.isEmpty ? '未命名风格' : trimmed;
}

Map<String, Object?> styleDraftFromProfileJson(Map<String, Object?> jsonData) {
  final next = Map<String, Object?>.from(defaultStyleQuestionnaireDraft);
  for (final entry in jsonData.entries) {
    next[entry.key] = entry.value;
  }
  return next;
}

Map<String, Object?> normalizeStyleDraft(Map<String, Object?> draft) {
  final next = <String, Object?>{};
  for (final entry in draft.entries) {
    final value = entry.value;
    if (value is List) {
      final normalized = <String>{};
      for (final item in value) {
        final trimmed = item.toString().trim();
        if (trimmed.isNotEmpty) {
          normalized.add(trimmed);
        }
      }
      next[entry.key] = normalized.toList(growable: false);
    } else if (value is String) {
      next[entry.key] = value.trim();
    } else {
      next[entry.key] = value;
    }
  }
  return next;
}

List<String> missingStyleRequiredFields(Map<String, Object?> draft) {
  final missing = <String>[];
  void requireText(String key, String label) {
    if ((draft[key]?.toString().trim() ?? '').isEmpty) {
      missing.add(label);
    }
  }

  void requireList(String key, String label) {
    if (stringListFromRaw(draft[key]).isEmpty) {
      missing.add(label);
    }
  }

  requireText('profile_name', '风格名称');
  requireList('genre_tags', '主要体裁');
  requireText('pov_mode', '叙事视角');
  requireText('dialogue_ratio', '对白比例');
  requireText('description_density', '描写密度');
  requireText('emotional_intensity', '情绪强度');
  requireText('rhythm_profile', '节奏轮廓');
  requireList('taboo_patterns', '禁忌表达');
  return missing;
}

List<String> computeStyleWarningMessages(Map<String, Object?> draft) {
  final warnings = <String>[];
  if ((draft['dialogue_ratio']?.toString() ?? '') == 'high' &&
      (draft['description_density']?.toString() ?? '') == 'high') {
    warnings.add('对白比例与描写密度同时偏高，正文可能过满。');
  }
  if ((draft['sentence_length_preference']?.toString() ?? '') ==
          'medium_long' &&
      (draft['rhythm_profile']?.toString() ?? '') == 'tight') {
    warnings.add('句长与节奏目标可能冲突。');
  }
  if ((draft['pov_mode']?.toString() ?? '') == 'third_person_multi' &&
      (draft['narrative_distance']?.toString() ?? '') == 'close') {
    warnings.add('多视角贴近叙述会增加一致性控制难度。');
  }
  return warnings;
}

Map<String, Object?> buildStyleProfileJson(Map<String, Object?> draft) {
  final normalized = normalizeStyleDraft(draft);
  return {
    'version': '1.0',
    'name': normalizeStyleName(normalized['profile_name']),
    'language': normalized['language']?.toString().trim().isEmpty ?? true
        ? 'zh-CN'
        : normalized['language'],
    'genre_tags': stringListFromRaw(normalized['genre_tags']),
    'pov_mode': normalized['pov_mode'],
    'dialogue_ratio': normalized['dialogue_ratio'],
    'description_density': normalized['description_density'],
    'emotional_intensity': normalized['emotional_intensity'],
    'rhythm_profile': normalized['rhythm_profile'],
    'taboo_patterns': stringListFromRaw(normalized['taboo_patterns']),
    'sentence_length_preference': normalized['sentence_length_preference'],
    'tone_keywords': stringListFromRaw(normalized['tone_keywords']),
    'narrative_distance': normalized['narrative_distance'],
    'notes': normalized['custom_notes'],
  };
}

StyleValidationResult validateStyleProfileJson(Map<String, Object?> jsonData) {
  final version = jsonData['version']?.toString() ?? '';
  if (version != '1.0') {
    return const StyleValidationResult(
      state: StyleWorkflowState.unsupportedVersion,
      message: '配置版本不受支持，请改用 version 1.0。',
      warningMessages: <String>[],
      profileJson: <String, Object?>{},
    );
  }

  final missing = <String>[];
  for (final key in const [
    'name',
    'language',
    'pov_mode',
    'dialogue_ratio',
    'description_density',
    'emotional_intensity',
    'rhythm_profile',
  ]) {
    if ((jsonData[key]?.toString().trim() ?? '').isEmpty) {
      missing.add(key);
    }
  }
  if (stringListFromRaw(jsonData['genre_tags']).isEmpty) {
    missing.add('genre_tags');
  }
  if (stringListFromRaw(jsonData['taboo_patterns']).isEmpty) {
    missing.add('taboo_patterns');
  }
  if (missing.isNotEmpty) {
    return StyleValidationResult(
      state: StyleWorkflowState.missingRequiredFields,
      message: 'JSON 缺少必填字段：${missing.join('、')}',
      warningMessages: const <String>[],
      profileJson: const <String, Object?>{},
    );
  }

  final allowedKeys = <String>{
    'version',
    'name',
    'language',
    'genre_tags',
    'pov_mode',
    'dialogue_ratio',
    'description_density',
    'emotional_intensity',
    'rhythm_profile',
    'taboo_patterns',
    'sentence_length_preference',
    'tone_keywords',
    'narrative_distance',
    'notes',
  };
  final ignored = <String>[
    for (final key in jsonData.keys)
      if (!allowedKeys.contains(key)) key,
  ];
  final profileJson = {
    for (final entry in jsonData.entries)
      if (allowedKeys.contains(entry.key)) entry.key: entry.value,
  };
  final warnings = computeStyleWarningMessages(
    styleDraftFromProfileJson(profileJson),
  );
  if (ignored.isNotEmpty) {
    warnings.add('已忽略未知字段：${ignored.join('、')}');
  }

  return StyleValidationResult(
    state: ignored.isNotEmpty
        ? StyleWorkflowState.unknownFieldsIgnored
        : StyleWorkflowState.ready,
    message: ignored.isNotEmpty ? '配置导入成功，未知字段已忽略。' : '配置导入成功，可直接绑定到项目或场景。',
    warningMessages: warnings,
    profileJson: profileJson,
  );
}

ProjectStyleState defaultStyleState() {
  final profileJson = buildStyleProfileJson(defaultStyleQuestionnaireDraft);
  final profile = StyleProfileRecord(
    id: 'style-default',
    name: normalizeStyleName(profileJson['name']),
    source: 'questionnaire',
    jsonData: profileJson,
  );
  return ProjectStyleState(
    inputMode: StyleInputMode.questionnaire,
    intensity: 1,
    bindingFeedback: defaultStyleBindingFeedback,
    questionnaireDraft: Map<String, Object?>.from(
      defaultStyleQuestionnaireDraft,
    ),
    jsonDraft: encodePrettyJson(profileJson),
    profiles: [profile],
    selectedProfileId: profile.id,
    workflowState: StyleWorkflowState.ready,
    workflowMessage: '已生成默认风格摘要，可继续调整或导入 JSON。',
    warningMessages: computeStyleWarningMessages(
      defaultStyleQuestionnaireDraft,
    ),
  );
}

void saveStyleProfile({
  required Map<String, ProjectStyleState> styleByProjectId,
  required String projectId,
  required StyleProfileRecord profile,
  required StyleWorkflowState workflowState,
  required String workflowMessage,
  List<String>? warningMessages,
}) {
  final currentStyle = styleByProjectId[projectId] ?? defaultStyleState();
  final existingProfiles = [
    for (final item in currentStyle.profiles)
      if (item.id != profile.id) item,
  ];
  if (existingProfiles.length >= 3) {
    styleByProjectId[projectId] = currentStyle.copyWith(
      workflowState: StyleWorkflowState.maxProfilesReached,
      workflowMessage: '同一项目最多保留 3 个风格配置，请先替换现有配置。',
    );
    return;
  }
  final nextProfiles = [profile, ...existingProfiles];
  styleByProjectId[projectId] = currentStyle.copyWith(
    profiles: nextProfiles,
    selectedProfileId: profile.id,
    questionnaireDraft: styleDraftFromProfileJson(profile.jsonData),
    jsonDraft: encodePrettyJson(profile.jsonData),
    workflowState: workflowState,
    workflowMessage: workflowMessage,
    warningMessages:
        warningMessages ?? computeStyleWarningMessages(profile.jsonData),
  );
}

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
