// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ModelConfigImpl _$$ModelConfigImplFromJson(Map<String, dynamic> json) =>
    _$ModelConfigImpl(
      id: json['id'] as String,
      tier: $enumDecode(_$ModelTierEnumMap, json['tier']),
      displayName: json['displayName'] as String,
      providerType: json['providerType'] as String,
      modelName: json['modelName'] as String,
      apiEndpoint: json['apiEndpoint'] as String?,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
      maxOutputTokens: (json['maxOutputTokens'] as num?)?.toInt() ?? 16384,
      topP: (json['topP'] as num?)?.toDouble() ?? 1.0,
      frequencyPenalty: (json['frequencyPenalty'] as num?)?.toDouble() ?? 0.0,
      presencePenalty: (json['presencePenalty'] as num?)?.toDouble() ?? 0.0,
      isEnabled: json['isEnabled'] as bool? ?? true,
      lastValidatedAt: json['lastValidatedAt'] == null
          ? null
          : DateTime.parse(json['lastValidatedAt'] as String),
      isValid: json['isValid'] as bool? ?? false,
    );

Map<String, dynamic> _$$ModelConfigImplToJson(_$ModelConfigImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tier': _$ModelTierEnumMap[instance.tier]!,
      'displayName': instance.displayName,
      'providerType': instance.providerType,
      'modelName': instance.modelName,
      'apiEndpoint': instance.apiEndpoint,
      'temperature': instance.temperature,
      'maxOutputTokens': instance.maxOutputTokens,
      'topP': instance.topP,
      'frequencyPenalty': instance.frequencyPenalty,
      'presencePenalty': instance.presencePenalty,
      'isEnabled': instance.isEnabled,
      'lastValidatedAt': instance.lastValidatedAt?.toIso8601String(),
      'isValid': instance.isValid,
    };

const _$ModelTierEnumMap = {
  ModelTier.thinking: 'thinking',
  ModelTier.middle: 'middle',
  ModelTier.fast: 'fast',
};
