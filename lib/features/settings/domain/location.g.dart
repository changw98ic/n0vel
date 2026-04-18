// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'location.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$LocationImpl _$$LocationImplFromJson(Map<String, dynamic> json) =>
    _$LocationImpl(
      id: json['id'] as String,
      workId: json['workId'] as String,
      name: json['name'] as String,
      type: json['type'] as String?,
      parentId: json['parentId'] as String?,
      description: json['description'] as String?,
      importantPlaces:
          (json['importantPlaces'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      characterIds:
          (json['characterIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      isArchived: json['isArchived'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$LocationImplToJson(_$LocationImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'workId': instance.workId,
      'name': instance.name,
      'type': instance.type,
      'parentId': instance.parentId,
      'description': instance.description,
      'importantPlaces': instance.importantPlaces,
      'characterIds': instance.characterIds,
      'isArchived': instance.isArchived,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

_$LocationCharacterImpl _$$LocationCharacterImplFromJson(
  Map<String, dynamic> json,
) => _$LocationCharacterImpl(
  id: json['id'] as String,
  locationId: json['locationId'] as String,
  characterId: json['characterId'] as String,
  relationship: json['relationship'] as String?,
  startChapterId: json['startChapterId'] as String?,
  endChapterId: json['endChapterId'] as String?,
  status: json['status'] as String? ?? 'active',
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$$LocationCharacterImplToJson(
  _$LocationCharacterImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'locationId': instance.locationId,
  'characterId': instance.characterId,
  'relationship': instance.relationship,
  'startChapterId': instance.startChapterId,
  'endChapterId': instance.endChapterId,
  'status': instance.status,
  'createdAt': instance.createdAt.toIso8601String(),
};
