// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'emotion_dimensions.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$EmotionDimensionsImpl _$$EmotionDimensionsImplFromJson(
  Map<String, dynamic> json,
) => _$EmotionDimensionsImpl(
  affection: (json['affection'] as num?)?.toInt() ?? 50,
  trust: (json['trust'] as num?)?.toInt() ?? 50,
  respect: (json['respect'] as num?)?.toInt() ?? 50,
  fear: (json['fear'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$$EmotionDimensionsImplToJson(
  _$EmotionDimensionsImpl instance,
) => <String, dynamic>{
  'affection': instance.affection,
  'trust': instance.trust,
  'respect': instance.respect,
  'fear': instance.fear,
};
