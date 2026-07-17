import 'dart:convert';

import 'workspace_style_helpers.dart';
import 'workspace_types.dart';

// ---------------------------------------------------------------------------
// Default data constants
// ---------------------------------------------------------------------------

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
    referenceSummary: '是仓库层数记录偏移与时间线跳跃两条问题的共同来源。',
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
    target: '场景 99',
  ),
  AuditIssueRecord(
    id: 'audit-timeline-gap',
    title: '时间线跳跃',
    evidence: '同一小时内出现了两次不可能同时成立的行动记录。',
    target: '场景 04',
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

// ---------------------------------------------------------------------------
// Default data builder functions
// ---------------------------------------------------------------------------

List<ProjectRecord> buildDefaultProjects() => const [];

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
      return const [];
  }
}

// ---------------------------------------------------------------------------
// General utility functions
// ---------------------------------------------------------------------------

List<ProjectRecord> sortProjects(List<ProjectRecord> projects) {
  final sorted = List<ProjectRecord>.from(projects);
  sorted.sort(
    (left, right) => right.lastOpenedAtMs.compareTo(left.lastOpenedAtMs),
  );
  final dedupedById = <String, ProjectRecord>{};
  for (final project in sorted) {
    dedupedById.putIfAbsent(project.id, () => project);
  }
  return dedupedById.values.toList();
}

String chapterLabelFromRecentLocation(String recentLocation) {
  final parts = recentLocation.split('·');
  final label = parts.first.trim();
  return label.isEmpty ? '第 1 章 / 场景 01' : label;
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
  final chapterNumbers = scenes
      .map((scene) => scene.locationParts.chapterNumber)
      .whereType<int>();
  final nextNumber = chapterNumbers.isEmpty
      ? scenes.length + 1
      : chapterNumbers.reduce((a, b) => a > b ? a : b) + 1;
  return '第 $nextNumber 章 / 场景 01';
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
