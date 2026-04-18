// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'character.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CharacterImpl _$$CharacterImplFromJson(Map<String, dynamic> json) =>
    _$CharacterImpl(
      id: json['id'] as String,
      workId: json['workId'] as String,
      name: json['name'] as String,
      aliases:
          (json['aliases'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      tier: $enumDecode(_$CharacterTierEnumMap, json['tier']),
      avatarPath: json['avatarPath'] as String?,
      gender: json['gender'] as String?,
      age: json['age'] as String?,
      identity: json['identity'] as String?,
      bio: json['bio'] as String?,
      lifeStatus:
          $enumDecodeNullable(_$LifeStatusEnumMap, json['lifeStatus']) ??
          LifeStatus.alive,
      deathChapterId: json['deathChapterId'] as String?,
      deathReason: json['deathReason'] as String?,
      isArchived: json['isArchived'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$CharacterImplToJson(_$CharacterImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'workId': instance.workId,
      'name': instance.name,
      'aliases': instance.aliases,
      'tier': _$CharacterTierEnumMap[instance.tier]!,
      'avatarPath': instance.avatarPath,
      'gender': instance.gender,
      'age': instance.age,
      'identity': instance.identity,
      'bio': instance.bio,
      'lifeStatus': _$LifeStatusEnumMap[instance.lifeStatus]!,
      'deathChapterId': instance.deathChapterId,
      'deathReason': instance.deathReason,
      'isArchived': instance.isArchived,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

const _$CharacterTierEnumMap = {
  CharacterTier.protagonist: 'protagonist',
  CharacterTier.majorAntagonist: 'majorAntagonist',
  CharacterTier.antagonist: 'antagonist',
  CharacterTier.supporting: 'supporting',
  CharacterTier.minor: 'minor',
};

const _$LifeStatusEnumMap = {
  LifeStatus.alive: 'alive',
  LifeStatus.dead: 'dead',
  LifeStatus.missing: 'missing',
  LifeStatus.unknown: 'unknown',
};
