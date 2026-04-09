// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'character_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BigFiveImpl _$$BigFiveImplFromJson(Map<String, dynamic> json) =>
    _$BigFiveImpl(
      openness: (json['openness'] as num?)?.toInt() ?? 50,
      conscientiousness: (json['conscientiousness'] as num?)?.toInt() ?? 50,
      extraversion: (json['extraversion'] as num?)?.toInt() ?? 50,
      agreeableness: (json['agreeableness'] as num?)?.toInt() ?? 50,
      neuroticism: (json['neuroticism'] as num?)?.toInt() ?? 50,
    );

Map<String, dynamic> _$$BigFiveImplToJson(_$BigFiveImpl instance) =>
    <String, dynamic>{
      'openness': instance.openness,
      'conscientiousness': instance.conscientiousness,
      'extraversion': instance.extraversion,
      'agreeableness': instance.agreeableness,
      'neuroticism': instance.neuroticism,
    };

_$SpeechStyleImpl _$$SpeechStyleImplFromJson(Map<String, dynamic> json) =>
    _$SpeechStyleImpl(
      languageStyle: json['languageStyle'] as String?,
      toneStyle: json['toneStyle'] as String?,
      speed: json['speed'] as String? ?? 'medium',
      sentencePatterns: (json['sentencePatterns'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      catchphrases: (json['catchphrases'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      vocabularyPreferences: (json['vocabularyPreferences'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      tabooWords: (json['tabooWords'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      examples: (json['examples'] as List<dynamic>?)
          ?.map((e) => SpeechExample.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$$SpeechStyleImplToJson(_$SpeechStyleImpl instance) =>
    <String, dynamic>{
      'languageStyle': instance.languageStyle,
      'toneStyle': instance.toneStyle,
      'speed': instance.speed,
      'sentencePatterns': instance.sentencePatterns,
      'catchphrases': instance.catchphrases,
      'vocabularyPreferences': instance.vocabularyPreferences,
      'tabooWords': instance.tabooWords,
      'examples': instance.examples,
    };

_$SpeechExampleImpl _$$SpeechExampleImplFromJson(Map<String, dynamic> json) =>
    _$SpeechExampleImpl(
      scene: json['scene'] as String,
      emotion: json['emotion'] as String,
      line: json['line'] as String,
    );

Map<String, dynamic> _$$SpeechExampleImplToJson(_$SpeechExampleImpl instance) =>
    <String, dynamic>{
      'scene': instance.scene,
      'emotion': instance.emotion,
      'line': instance.line,
    };

_$BehaviorPatternImpl _$$BehaviorPatternImplFromJson(
        Map<String, dynamic> json) =>
    _$BehaviorPatternImpl(
      trigger: json['trigger'] as String,
      behavior: json['behavior'] as String,
      description: json['description'] as String?,
    );

Map<String, dynamic> _$$BehaviorPatternImplToJson(
        _$BehaviorPatternImpl instance) =>
    <String, dynamic>{
      'trigger': instance.trigger,
      'behavior': instance.behavior,
      'description': instance.description,
    };

_$CharacterProfileImpl _$$CharacterProfileImplFromJson(
        Map<String, dynamic> json) =>
    _$CharacterProfileImpl(
      id: json['id'] as String,
      characterId: json['characterId'] as String,
      mbti: $enumDecodeNullable(_$MBTIEnumMap, json['mbti']),
      bigFive: json['bigFive'] == null
          ? null
          : BigFive.fromJson(json['bigFive'] as Map<String, dynamic>),
      personalityKeywords: (json['personalityKeywords'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      coreValues: json['coreValues'] as String?,
      fears: json['fears'] as String?,
      desires: json['desires'] as String?,
      moralBaseline: json['moralBaseline'] as String?,
      speechStyle: json['speechStyle'] == null
          ? null
          : SpeechStyle.fromJson(json['speechStyle'] as Map<String, dynamic>),
      behaviorPatterns: (json['behaviorPatterns'] as List<dynamic>?)
              ?.map((e) => BehaviorPattern.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$CharacterProfileImplToJson(
        _$CharacterProfileImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'characterId': instance.characterId,
      'mbti': _$MBTIEnumMap[instance.mbti],
      'bigFive': instance.bigFive,
      'personalityKeywords': instance.personalityKeywords,
      'coreValues': instance.coreValues,
      'fears': instance.fears,
      'desires': instance.desires,
      'moralBaseline': instance.moralBaseline,
      'speechStyle': instance.speechStyle,
      'behaviorPatterns': instance.behaviorPatterns,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

const _$MBTIEnumMap = {
  MBTI.intj: 'intj',
  MBTI.intp: 'intp',
  MBTI.entj: 'entj',
  MBTI.entp: 'entp',
  MBTI.infj: 'infj',
  MBTI.infp: 'infp',
  MBTI.enfj: 'enfj',
  MBTI.enfp: 'enfp',
  MBTI.istj: 'istj',
  MBTI.istp: 'istp',
  MBTI.estj: 'estj',
  MBTI.estp: 'estp',
  MBTI.isfj: 'isfj',
  MBTI.isfp: 'isfp',
  MBTI.esfj: 'esfj',
  MBTI.esfp: 'esfp',
};
