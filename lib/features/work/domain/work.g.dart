// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'work.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$WorkImpl _$$WorkImplFromJson(Map<String, dynamic> json) => _$WorkImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String?,
      description: json['description'] as String?,
      coverPath: json['coverPath'] as String?,
      targetWords: (json['targetWords'] as num?)?.toInt(),
      currentWords: (json['currentWords'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'draft',
      isPinned: json['isPinned'] as bool? ?? false,
      isArchived: json['isArchived'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$WorkImplToJson(_$WorkImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': instance.type,
      'description': instance.description,
      'coverPath': instance.coverPath,
      'targetWords': instance.targetWords,
      'currentWords': instance.currentWords,
      'status': instance.status,
      'isPinned': instance.isPinned,
      'isArchived': instance.isArchived,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
