// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'faction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$FactionImpl _$$FactionImplFromJson(Map<String, dynamic> json) =>
    _$FactionImpl(
      id: json['id'] as String,
      workId: json['workId'] as String,
      name: json['name'] as String,
      type: json['type'] as String?,
      emblemPath: json['emblemPath'] as String?,
      description: json['description'] as String?,
      traits:
          (json['traits'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      leaderId: json['leaderId'] as String?,
      isArchived: json['isArchived'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$FactionImplToJson(_$FactionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'workId': instance.workId,
      'name': instance.name,
      'type': instance.type,
      'emblemPath': instance.emblemPath,
      'description': instance.description,
      'traits': instance.traits,
      'leaderId': instance.leaderId,
      'isArchived': instance.isArchived,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

_$FactionMemberImpl _$$FactionMemberImplFromJson(Map<String, dynamic> json) =>
    _$FactionMemberImpl(
      id: json['id'] as String,
      factionId: json['factionId'] as String,
      characterId: json['characterId'] as String,
      role: json['role'] as String?,
      joinChapterId: json['joinChapterId'] as String?,
      leaveChapterId: json['leaveChapterId'] as String?,
      status: json['status'] as String? ?? 'active',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$FactionMemberImplToJson(_$FactionMemberImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'factionId': instance.factionId,
      'characterId': instance.characterId,
      'role': instance.role,
      'joinChapterId': instance.joinChapterId,
      'leaveChapterId': instance.leaveChapterId,
      'status': instance.status,
      'createdAt': instance.createdAt.toIso8601String(),
    };
