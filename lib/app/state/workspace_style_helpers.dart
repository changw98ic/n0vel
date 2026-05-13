import 'workspace_default_data.dart';
import 'workspace_types.dart';

// ---------------------------------------------------------------------------
// Style name / draft helpers
// ---------------------------------------------------------------------------

String normalizeStyleName(Object? rawName) {
  final trimmed = rawName?.toString().trim() ?? '';
  return trimmed.isEmpty ? '默认风格' : trimmed;
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

// ---------------------------------------------------------------------------
// Style validation helpers
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Style profile builder
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Style profile JSON validation
// ---------------------------------------------------------------------------

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
    message: ignored.isNotEmpty ? '配置导入成功，未知字段已忽略。' : '配置导入成功，可直接绑定到项目或章节。',
    warningMessages: warnings,
    profileJson: profileJson,
  );
}

// ---------------------------------------------------------------------------
// Default style state factory
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Style profile save mutation
// ---------------------------------------------------------------------------

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
