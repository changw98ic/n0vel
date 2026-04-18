// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pov_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$POVTaskImpl _$$POVTaskImplFromJson(Map<String, dynamic> json) =>
    _$POVTaskImpl(
      id: json['id'] as String,
      workId: json['workId'] as String,
      chapterId: json['chapterId'] as String,
      characterId: json['characterId'] as String,
      originalContent: json['originalContent'] as String,
      config: POVConfig.fromJson(json['config'] as Map<String, dynamic>),
      status:
          $enumDecodeNullable(_$POVTaskStatusEnumMap, json['status']) ??
          POVTaskStatus.pending,
      generatedContent: json['generatedContent'] as String?,
      analysis: json['analysis'] as String?,
      tokenUsage: (json['tokenUsage'] as num?)?.toInt() ?? 0,
      errorMessage: json['errorMessage'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
    );

Map<String, dynamic> _$$POVTaskImplToJson(_$POVTaskImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'workId': instance.workId,
      'chapterId': instance.chapterId,
      'characterId': instance.characterId,
      'originalContent': instance.originalContent,
      'config': instance.config,
      'status': _$POVTaskStatusEnumMap[instance.status]!,
      'generatedContent': instance.generatedContent,
      'analysis': instance.analysis,
      'tokenUsage': instance.tokenUsage,
      'errorMessage': instance.errorMessage,
      'createdAt': instance.createdAt.toIso8601String(),
      'completedAt': instance.completedAt?.toIso8601String(),
    };

const _$POVTaskStatusEnumMap = {
  POVTaskStatus.pending: 'pending',
  POVTaskStatus.analyzing: 'analyzing',
  POVTaskStatus.generating: 'generating',
  POVTaskStatus.completed: 'completed',
  POVTaskStatus.failed: 'failed',
  POVTaskStatus.cancelled: 'cancelled',
};

_$POVConfigImpl _$$POVConfigImplFromJson(
  Map<String, dynamic> json,
) => _$POVConfigImpl(
  mode: $enumDecodeNullable(_$POVModeEnumMap, json['mode']) ?? POVMode.rewrite,
  style:
      $enumDecodeNullable(_$POVStyleEnumMap, json['style']) ??
      POVStyle.firstPerson,
  keepDialogue: json['keepDialogue'] as bool? ?? true,
  addInnerThoughts: json['addInnerThoughts'] as bool? ?? true,
  expandObservations: json['expandObservations'] as bool? ?? true,
  emotionalIntensity: (json['emotionalIntensity'] as num?)?.toDouble() ?? 0.5,
  useCharacterVoice: json['useCharacterVoice'] as bool? ?? true,
  customInstructions: json['customInstructions'] as String?,
  targetWordCount: (json['targetWordCount'] as num?)?.toInt(),
);

Map<String, dynamic> _$$POVConfigImplToJson(_$POVConfigImpl instance) =>
    <String, dynamic>{
      'mode': _$POVModeEnumMap[instance.mode]!,
      'style': _$POVStyleEnumMap[instance.style]!,
      'keepDialogue': instance.keepDialogue,
      'addInnerThoughts': instance.addInnerThoughts,
      'expandObservations': instance.expandObservations,
      'emotionalIntensity': instance.emotionalIntensity,
      'useCharacterVoice': instance.useCharacterVoice,
      'customInstructions': instance.customInstructions,
      'targetWordCount': instance.targetWordCount,
    };

const _$POVModeEnumMap = {
  POVMode.rewrite: 'rewrite',
  POVMode.supplement: 'supplement',
  POVMode.summary: 'summary',
  POVMode.fragment: 'fragment',
};

const _$POVStyleEnumMap = {
  POVStyle.firstPerson: 'firstPerson',
  POVStyle.thirdPersonLimited: 'thirdPersonLimited',
  POVStyle.diary: 'diary',
  POVStyle.memoir: 'memoir',
};

_$POVAnalysisImpl _$$POVAnalysisImplFromJson(Map<String, dynamic> json) =>
    _$POVAnalysisImpl(
      appearances: (json['appearances'] as List<dynamic>)
          .map((e) => CharacterAppearance.fromJson(e as Map<String, dynamic>))
          .toList(),
      emotionCurve: (json['emotionCurve'] as List<dynamic>)
          .map((e) => EmotionPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      observations: (json['observations'] as List<dynamic>)
          .map((e) => KeyObservation.fromJson(e as Map<String, dynamic>))
          .toList(),
      interactions: (json['interactions'] as List<dynamic>)
          .map((e) => CharacterInteraction.fromJson(e as Map<String, dynamic>))
          .toList(),
      suggestedThoughts: (json['suggestedThoughts'] as List<dynamic>)
          .map((e) => InnerThought.fromJson(e as Map<String, dynamic>))
          .toList(),
      suggestions: (json['suggestions'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$$POVAnalysisImplToJson(_$POVAnalysisImpl instance) =>
    <String, dynamic>{
      'appearances': instance.appearances,
      'emotionCurve': instance.emotionCurve,
      'observations': instance.observations,
      'interactions': instance.interactions,
      'suggestedThoughts': instance.suggestedThoughts,
      'suggestions': instance.suggestions,
    };

_$CharacterAppearanceImpl _$$CharacterAppearanceImplFromJson(
  Map<String, dynamic> json,
) => _$CharacterAppearanceImpl(
  paragraphIndex: (json['paragraphIndex'] as num).toInt(),
  originalText: json['originalText'] as String,
  action: json['action'] as String?,
  dialogue: json['dialogue'] as String?,
  contextSummary: json['contextSummary'] as String?,
);

Map<String, dynamic> _$$CharacterAppearanceImplToJson(
  _$CharacterAppearanceImpl instance,
) => <String, dynamic>{
  'paragraphIndex': instance.paragraphIndex,
  'originalText': instance.originalText,
  'action': instance.action,
  'dialogue': instance.dialogue,
  'contextSummary': instance.contextSummary,
};

_$EmotionPointImpl _$$EmotionPointImplFromJson(Map<String, dynamic> json) =>
    _$EmotionPointImpl(
      position: (json['position'] as num).toInt(),
      type: $enumDecode(_$EmotionTypeEnumMap, json['type']),
      intensity: (json['intensity'] as num).toDouble(),
      trigger: json['trigger'] as String?,
      description: json['description'] as String?,
    );

Map<String, dynamic> _$$EmotionPointImplToJson(_$EmotionPointImpl instance) =>
    <String, dynamic>{
      'position': instance.position,
      'type': _$EmotionTypeEnumMap[instance.type]!,
      'intensity': instance.intensity,
      'trigger': instance.trigger,
      'description': instance.description,
    };

const _$EmotionTypeEnumMap = {
  EmotionType.joy: 'joy',
  EmotionType.sadness: 'sadness',
  EmotionType.anger: 'anger',
  EmotionType.fear: 'fear',
  EmotionType.surprise: 'surprise',
  EmotionType.disgust: 'disgust',
  EmotionType.anticipation: 'anticipation',
  EmotionType.trust: 'trust',
  EmotionType.love: 'love',
  EmotionType.hate: 'hate',
  EmotionType.hope: 'hope',
  EmotionType.despair: 'despair',
};

_$KeyObservationImpl _$$KeyObservationImplFromJson(Map<String, dynamic> json) =>
    _$KeyObservationImpl(
      position: (json['position'] as num).toInt(),
      content: json['content'] as String,
      type: $enumDecode(_$ObservationTypeEnumMap, json['type']),
      characterReaction: json['characterReaction'] as String?,
    );

Map<String, dynamic> _$$KeyObservationImplToJson(
  _$KeyObservationImpl instance,
) => <String, dynamic>{
  'position': instance.position,
  'content': instance.content,
  'type': _$ObservationTypeEnumMap[instance.type]!,
  'characterReaction': instance.characterReaction,
};

const _$ObservationTypeEnumMap = {
  ObservationType.character: 'character',
  ObservationType.environment: 'environment',
  ObservationType.action: 'action',
  ObservationType.dialogue: 'dialogue',
  ObservationType.inner: 'inner',
};

_$CharacterInteractionImpl _$$CharacterInteractionImplFromJson(
  Map<String, dynamic> json,
) => _$CharacterInteractionImpl(
  otherCharacterId: json['otherCharacterId'] as String,
  otherCharacterName: json['otherCharacterName'] as String,
  position: (json['position'] as num).toInt(),
  type: $enumDecode(_$InteractionTypeEnumMap, json['type']),
  content: json['content'] as String?,
  povCharacterReaction: json['povCharacterReaction'] as String?,
);

Map<String, dynamic> _$$CharacterInteractionImplToJson(
  _$CharacterInteractionImpl instance,
) => <String, dynamic>{
  'otherCharacterId': instance.otherCharacterId,
  'otherCharacterName': instance.otherCharacterName,
  'position': instance.position,
  'type': _$InteractionTypeEnumMap[instance.type]!,
  'content': instance.content,
  'povCharacterReaction': instance.povCharacterReaction,
};

const _$InteractionTypeEnumMap = {
  InteractionType.dialogue: 'dialogue',
  InteractionType.action: 'action',
  InteractionType.eye: 'eye',
  InteractionType.physical: 'physical',
  InteractionType.mental: 'mental',
};

_$InnerThoughtImpl _$$InnerThoughtImplFromJson(Map<String, dynamic> json) =>
    _$InnerThoughtImpl(
      position: (json['position'] as num).toInt(),
      content: json['content'] as String,
      type: $enumDecode(_$ThoughtTypeEnumMap, json['type']),
      trigger: json['trigger'] as String?,
    );

Map<String, dynamic> _$$InnerThoughtImplToJson(_$InnerThoughtImpl instance) =>
    <String, dynamic>{
      'position': instance.position,
      'content': instance.content,
      'type': _$ThoughtTypeEnumMap[instance.type]!,
      'trigger': instance.trigger,
    };

const _$ThoughtTypeEnumMap = {
  ThoughtType.reaction: 'reaction',
  ThoughtType.reflection: 'reflection',
  ThoughtType.memory: 'memory',
  ThoughtType.plan: 'plan',
  ThoughtType.emotion: 'emotion',
  ThoughtType.judgment: 'judgment',
};

_$POVTemplateImpl _$$POVTemplateImplFromJson(Map<String, dynamic> json) =>
    _$POVTemplateImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      config: POVConfig.fromJson(json['config'] as Map<String, dynamic>),
      suitableCharacterTypes:
          (json['suitableCharacterTypes'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      exampleOutput: json['exampleOutput'] as String?,
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
    );

Map<String, dynamic> _$$POVTemplateImplToJson(_$POVTemplateImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'config': instance.config,
      'suitableCharacterTypes': instance.suitableCharacterTypes,
      'exampleOutput': instance.exampleOutput,
      'isBuiltIn': instance.isBuiltIn,
    };

_$POVSaveOptionsImpl _$$POVSaveOptionsImplFromJson(Map<String, dynamic> json) =>
    _$POVSaveOptionsImpl(
      canSaveAsDraft: json['canSaveAsDraft'] as bool,
      canReplaceChapter: json['canReplaceChapter'] as bool,
      canCreateNewChapter: json['canCreateNewChapter'] as bool,
      currentChapterTitle: json['currentChapterTitle'] as String?,
      suggestedSortOrder: (json['suggestedSortOrder'] as num).toInt(),
      defaultVolumeId: json['defaultVolumeId'] as String?,
    );

Map<String, dynamic> _$$POVSaveOptionsImplToJson(
  _$POVSaveOptionsImpl instance,
) => <String, dynamic>{
  'canSaveAsDraft': instance.canSaveAsDraft,
  'canReplaceChapter': instance.canReplaceChapter,
  'canCreateNewChapter': instance.canCreateNewChapter,
  'currentChapterTitle': instance.currentChapterTitle,
  'suggestedSortOrder': instance.suggestedSortOrder,
  'defaultVolumeId': instance.defaultVolumeId,
};
