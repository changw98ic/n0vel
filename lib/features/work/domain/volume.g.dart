// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'volume.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$VolumeImpl _$$VolumeImplFromJson(Map<String, dynamic> json) => _$VolumeImpl(
      id: json['id'] as String,
      workId: json['workId'] as String,
      name: json['name'] as String,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$VolumeImplToJson(_$VolumeImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'workId': instance.workId,
      'name': instance.name,
      'sortOrder': instance.sortOrder,
      'createdAt': instance.createdAt.toIso8601String(),
    };
