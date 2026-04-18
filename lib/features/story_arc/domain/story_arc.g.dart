// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'story_arc.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$StoryArcModelImpl _$$StoryArcModelImplFromJson(Map<String, dynamic> json) =>
    _$StoryArcModelImpl(
      id: json['id'] as String,
      workId: json['workId'] as String,
      name: json['name'] as String,
      arcType: $enumDecode(_$ArcTypeEnumMap, json['arcType']),
      description: json['description'] as String?,
      startChapterId: json['startChapterId'] as String?,
      endChapterId: json['endChapterId'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      status:
          $enumDecodeNullable(_$ArcStatusEnumMap, json['status']) ??
          ArcStatus.active,
      metadata: json['metadata'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$StoryArcModelImplToJson(_$StoryArcModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'workId': instance.workId,
      'name': instance.name,
      'arcType': _$ArcTypeEnumMap[instance.arcType]!,
      'description': instance.description,
      'startChapterId': instance.startChapterId,
      'endChapterId': instance.endChapterId,
      'sortOrder': instance.sortOrder,
      'status': _$ArcStatusEnumMap[instance.status]!,
      'metadata': instance.metadata,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };

const _$ArcTypeEnumMap = {
  ArcType.main: 'main',
  ArcType.subplot: 'subplot',
  ArcType.hidden: 'hidden',
  ArcType.romance: 'romance',
  ArcType.comedy: 'comedy',
};

const _$ArcStatusEnumMap = {
  ArcStatus.active: 'active',
  ArcStatus.resolved: 'resolved',
  ArcStatus.abandoned: 'abandoned',
};

_$ArcChapterModelImpl _$$ArcChapterModelImplFromJson(
  Map<String, dynamic> json,
) => _$ArcChapterModelImpl(
  id: json['id'] as String,
  arcId: json['arcId'] as String,
  chapterId: json['chapterId'] as String,
  role:
      $enumDecodeNullable(_$ArcChapterRoleEnumMap, json['role']) ??
      ArcChapterRole.progression,
  note: json['note'] as String?,
  sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$$ArcChapterModelImplToJson(
  _$ArcChapterModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'arcId': instance.arcId,
  'chapterId': instance.chapterId,
  'role': _$ArcChapterRoleEnumMap[instance.role]!,
  'note': instance.note,
  'sortOrder': instance.sortOrder,
};

const _$ArcChapterRoleEnumMap = {
  ArcChapterRole.progression: 'progression',
  ArcChapterRole.climax: 'climax',
  ArcChapterRole.twist: 'twist',
  ArcChapterRole.resolution: 'resolution',
  ArcChapterRole.foreshadow: 'foreshadow',
  ArcChapterRole.callback: 'callback',
};

_$ArcCharacterModelImpl _$$ArcCharacterModelImplFromJson(
  Map<String, dynamic> json,
) => _$ArcCharacterModelImpl(
  id: json['id'] as String,
  arcId: json['arcId'] as String,
  characterId: json['characterId'] as String,
  role:
      $enumDecodeNullable(_$ArcCharacterRoleEnumMap, json['role']) ??
      ArcCharacterRole.participant,
  note: json['note'] as String?,
);

Map<String, dynamic> _$$ArcCharacterModelImplToJson(
  _$ArcCharacterModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'arcId': instance.arcId,
  'characterId': instance.characterId,
  'role': _$ArcCharacterRoleEnumMap[instance.role]!,
  'note': instance.note,
};

const _$ArcCharacterRoleEnumMap = {
  ArcCharacterRole.protagonist: 'protagonist',
  ArcCharacterRole.antagonist: 'antagonist',
  ArcCharacterRole.mentor: 'mentor',
  ArcCharacterRole.participant: 'participant',
  ArcCharacterRole.observer: 'observer',
};

_$ForeshadowModelImpl _$$ForeshadowModelImplFromJson(
  Map<String, dynamic> json,
) => _$ForeshadowModelImpl(
  id: json['id'] as String,
  workId: json['workId'] as String,
  description: json['description'] as String,
  plantChapterId: json['plantChapterId'] as String?,
  plantParagraphIndex: (json['plantParagraphIndex'] as num?)?.toInt(),
  payoffChapterId: json['payoffChapterId'] as String?,
  payoffParagraphIndex: (json['payoffParagraphIndex'] as num?)?.toInt(),
  status:
      $enumDecodeNullable(_$ForeshadowStatusEnumMap, json['status']) ??
      ForeshadowStatus.planted,
  importance:
      $enumDecodeNullable(_$ForeshadowImportanceEnumMap, json['importance']) ??
      ForeshadowImportance.minor,
  arcId: json['arcId'] as String?,
  note: json['note'] as String?,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$$ForeshadowModelImplToJson(
  _$ForeshadowModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'workId': instance.workId,
  'description': instance.description,
  'plantChapterId': instance.plantChapterId,
  'plantParagraphIndex': instance.plantParagraphIndex,
  'payoffChapterId': instance.payoffChapterId,
  'payoffParagraphIndex': instance.payoffParagraphIndex,
  'status': _$ForeshadowStatusEnumMap[instance.status]!,
  'importance': _$ForeshadowImportanceEnumMap[instance.importance]!,
  'arcId': instance.arcId,
  'note': instance.note,
  'createdAt': instance.createdAt?.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
};

const _$ForeshadowStatusEnumMap = {
  ForeshadowStatus.planted: 'planted',
  ForeshadowStatus.hinted: 'hinted',
  ForeshadowStatus.paidOff: 'paidOff',
  ForeshadowStatus.abandoned: 'abandoned',
};

const _$ForeshadowImportanceEnumMap = {
  ForeshadowImportance.critical: 'critical',
  ForeshadowImportance.major: 'major',
  ForeshadowImportance.minor: 'minor',
};
