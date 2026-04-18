// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ItemImpl _$$ItemImplFromJson(Map<String, dynamic> json) => _$ItemImpl(
  id: json['id'] as String,
  workId: json['workId'] as String,
  name: json['name'] as String,
  type: json['type'] as String?,
  rarity: json['rarity'] as String?,
  iconPath: json['iconPath'] as String?,
  description: json['description'] as String?,
  abilities:
      (json['abilities'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  holderId: json['holderId'] as String?,
  isArchived: json['isArchived'] as bool? ?? false,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$$ItemImplToJson(_$ItemImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'workId': instance.workId,
      'name': instance.name,
      'type': instance.type,
      'rarity': instance.rarity,
      'iconPath': instance.iconPath,
      'description': instance.description,
      'abilities': instance.abilities,
      'holderId': instance.holderId,
      'isArchived': instance.isArchived,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
