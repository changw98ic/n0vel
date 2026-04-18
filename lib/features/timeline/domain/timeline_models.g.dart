// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timeline_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$StoryEventImpl _$$StoryEventImplFromJson(
  Map<String, dynamic> json,
) => _$StoryEventImpl(
  id: json['id'] as String,
  workId: json['workId'] as String,
  name: json['name'] as String,
  type: $enumDecodeNullable(_$EventTypeEnumMap, json['type']) ?? EventType.main,
  importance:
      $enumDecodeNullable(_$EventImportanceEnumMap, json['importance']) ??
      EventImportance.normal,
  storyTime: json['storyTime'] as String?,
  relativeTime: json['relativeTime'] as String?,
  chapterId: json['chapterId'] as String?,
  chapterPosition: (json['chapterPosition'] as num?)?.toInt(),
  locationId: json['locationId'] as String?,
  characterIds:
      (json['characterIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  description: json['description'] as String?,
  consequences: json['consequences'] as String?,
  predecessorId: json['predecessorId'] as String?,
  successorId: json['successorId'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$$StoryEventImplToJson(_$StoryEventImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'workId': instance.workId,
      'name': instance.name,
      'type': _$EventTypeEnumMap[instance.type]!,
      'importance': _$EventImportanceEnumMap[instance.importance]!,
      'storyTime': instance.storyTime,
      'relativeTime': instance.relativeTime,
      'chapterId': instance.chapterId,
      'chapterPosition': instance.chapterPosition,
      'locationId': instance.locationId,
      'characterIds': instance.characterIds,
      'description': instance.description,
      'consequences': instance.consequences,
      'predecessorId': instance.predecessorId,
      'successorId': instance.successorId,
      'createdAt': instance.createdAt.toIso8601String(),
    };

const _$EventTypeEnumMap = {
  EventType.main: 'main',
  EventType.sub: 'sub',
  EventType.daily: 'daily',
  EventType.battle: 'battle',
  EventType.romance: 'romance',
  EventType.mystery: 'mystery',
  EventType.turning: 'turning',
};

const _$EventImportanceEnumMap = {
  EventImportance.normal: 'normal',
  EventImportance.important: 'important',
  EventImportance.key: 'key',
  EventImportance.turning: 'turning',
};

_$CharacterTrajectoryPointImpl _$$CharacterTrajectoryPointImplFromJson(
  Map<String, dynamic> json,
) => _$CharacterTrajectoryPointImpl(
  characterId: json['characterId'] as String,
  chapterId: json['chapterId'] as String,
  locationId: json['locationId'] as String?,
  emotionalState: json['emotionalState'] as String?,
  keyAction: json['keyAction'] as String?,
  interactedCharacterIds:
      (json['interactedCharacterIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  note: json['note'] as String?,
);

Map<String, dynamic> _$$CharacterTrajectoryPointImplToJson(
  _$CharacterTrajectoryPointImpl instance,
) => <String, dynamic>{
  'characterId': instance.characterId,
  'chapterId': instance.chapterId,
  'locationId': instance.locationId,
  'emotionalState': instance.emotionalState,
  'keyAction': instance.keyAction,
  'interactedCharacterIds': instance.interactedCharacterIds,
  'note': instance.note,
};

_$TimeConflictImpl _$$TimeConflictImplFromJson(Map<String, dynamic> json) =>
    _$TimeConflictImpl(
      id: json['id'] as String,
      type: $enumDecode(_$ConflictTypeEnumMap, json['type']),
      description: json['description'] as String,
      eventId1: json['eventId1'] as String,
      eventId2: json['eventId2'] as String?,
      suggestion: json['suggestion'] as String?,
      isResolved: json['isResolved'] as bool? ?? false,
    );

Map<String, dynamic> _$$TimeConflictImplToJson(_$TimeConflictImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$ConflictTypeEnumMap[instance.type]!,
      'description': instance.description,
      'eventId1': instance.eventId1,
      'eventId2': instance.eventId2,
      'suggestion': instance.suggestion,
      'isResolved': instance.isResolved,
    };

const _$ConflictTypeEnumMap = {
  ConflictType.timeSequence: 'timeSequence',
  ConflictType.locationConflict: 'locationConflict',
  ConflictType.stateConflict: 'stateConflict',
  ConflictType.characterAvailability: 'characterAvailability',
};

_$StoryTimeSystemImpl _$$StoryTimeSystemImplFromJson(
  Map<String, dynamic> json,
) => _$StoryTimeSystemImpl(
  workId: json['workId'] as String,
  startEpoch: json['startEpoch'] as String,
  calendarType: json['calendarType'] as String?,
  customUnits:
      (json['customUnits'] as List<dynamic>?)
          ?.map((e) => TimeUnit.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$$StoryTimeSystemImplToJson(
  _$StoryTimeSystemImpl instance,
) => <String, dynamic>{
  'workId': instance.workId,
  'startEpoch': instance.startEpoch,
  'calendarType': instance.calendarType,
  'customUnits': instance.customUnits,
};

_$TimeUnitImpl _$$TimeUnitImplFromJson(Map<String, dynamic> json) =>
    _$TimeUnitImpl(
      name: json['name'] as String,
      baseValue: (json['baseValue'] as num).toInt(),
      description: json['description'] as String?,
    );

Map<String, dynamic> _$$TimeUnitImplToJson(_$TimeUnitImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'baseValue': instance.baseValue,
      'description': instance.description,
    };
