// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'relationship.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$RelationshipHeadImpl _$$RelationshipHeadImplFromJson(
        Map<String, dynamic> json) =>
    _$RelationshipHeadImpl(
      id: json['id'] as String,
      workId: json['workId'] as String,
      characterAId: json['characterAId'] as String,
      characterBId: json['characterBId'] as String,
      relationType: $enumDecode(_$RelationTypeEnumMap, json['relationType']),
      emotionDimensions: json['emotionDimensions'] == null
          ? null
          : EmotionDimensions.fromJson(
              json['emotionDimensions'] as Map<String, dynamic>),
      firstChapterId: json['firstChapterId'] as String?,
      latestChapterId: json['latestChapterId'] as String?,
      eventCount: (json['eventCount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$RelationshipHeadImplToJson(
        _$RelationshipHeadImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'workId': instance.workId,
      'characterAId': instance.characterAId,
      'characterBId': instance.characterBId,
      'relationType': _$RelationTypeEnumMap[instance.relationType]!,
      'emotionDimensions': instance.emotionDimensions,
      'firstChapterId': instance.firstChapterId,
      'latestChapterId': instance.latestChapterId,
      'eventCount': instance.eventCount,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

const _$RelationTypeEnumMap = {
  RelationType.enemy: 'enemy',
  RelationType.hostile: 'hostile',
  RelationType.neutral: 'neutral',
  RelationType.acquaintance: 'acquaintance',
  RelationType.friendly: 'friendly',
  RelationType.friend: 'friend',
  RelationType.closeFriend: 'closeFriend',
  RelationType.lover: 'lover',
  RelationType.family: 'family',
  RelationType.mentor: 'mentor',
  RelationType.rival: 'rival',
};

_$RelationshipEventImpl _$$RelationshipEventImplFromJson(
        Map<String, dynamic> json) =>
    _$RelationshipEventImpl(
      id: json['id'] as String,
      headId: json['headId'] as String,
      chapterId: json['chapterId'] as String,
      changeType: $enumDecode(_$ChangeTypeEnumMap, json['changeType']),
      prevRelationType:
          $enumDecodeNullable(_$RelationTypeEnumMap, json['prevRelationType']),
      newRelationType:
          $enumDecode(_$RelationTypeEnumMap, json['newRelationType']),
      prevEmotionDimensions: json['prevEmotionDimensions'] == null
          ? null
          : EmotionDimensions.fromJson(
              json['prevEmotionDimensions'] as Map<String, dynamic>),
      newEmotionDimensions: json['newEmotionDimensions'] == null
          ? null
          : EmotionDimensions.fromJson(
              json['newEmotionDimensions'] as Map<String, dynamic>),
      changeReason: json['changeReason'] as String?,
      isKeyEvent: json['isKeyEvent'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$RelationshipEventImplToJson(
        _$RelationshipEventImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'headId': instance.headId,
      'chapterId': instance.chapterId,
      'changeType': _$ChangeTypeEnumMap[instance.changeType]!,
      'prevRelationType': _$RelationTypeEnumMap[instance.prevRelationType],
      'newRelationType': _$RelationTypeEnumMap[instance.newRelationType]!,
      'prevEmotionDimensions': instance.prevEmotionDimensions,
      'newEmotionDimensions': instance.newEmotionDimensions,
      'changeReason': instance.changeReason,
      'isKeyEvent': instance.isKeyEvent,
      'createdAt': instance.createdAt.toIso8601String(),
    };

const _$ChangeTypeEnumMap = {
  ChangeType.create: 'create',
  ChangeType.update: 'update',
  ChangeType.majorShift: 'majorShift',
};
