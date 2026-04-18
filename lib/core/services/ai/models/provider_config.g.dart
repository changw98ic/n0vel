// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'provider_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ProviderConfigImpl _$$ProviderConfigImplFromJson(Map<String, dynamic> json) =>
    _$ProviderConfigImpl(
      id: json['id'] as String,
      type: $enumDecode(_$AIProviderTypeEnumMap, json['type']),
      name: json['name'] as String,
      apiKey: json['apiKey'] as String?,
      apiEndpoint: json['apiEndpoint'] as String?,
      headers:
          (json['headers'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          const {},
      timeoutSeconds: (json['timeoutSeconds'] as num?)?.toInt() ?? 30,
      maxRetries: (json['maxRetries'] as num?)?.toInt() ?? 3,
      isEnabled: json['isEnabled'] as bool? ?? true,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$ProviderConfigImplToJson(
  _$ProviderConfigImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'type': _$AIProviderTypeEnumMap[instance.type]!,
  'name': instance.name,
  'apiKey': instance.apiKey,
  'apiEndpoint': instance.apiEndpoint,
  'headers': instance.headers,
  'timeoutSeconds': instance.timeoutSeconds,
  'maxRetries': instance.maxRetries,
  'isEnabled': instance.isEnabled,
  'createdAt': instance.createdAt?.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
};

const _$AIProviderTypeEnumMap = {
  AIProviderType.openai: 'openai',
  AIProviderType.anthropic: 'anthropic',
  AIProviderType.ollama: 'ollama',
  AIProviderType.azure: 'azure',
  AIProviderType.custom: 'custom',
};

_$FunctionMappingImpl _$$FunctionMappingImplFromJson(
  Map<String, dynamic> json,
) => _$FunctionMappingImpl(
  functionKey: json['functionKey'] as String,
  overrideModelId: json['overrideModelId'] as String?,
  useOverride: json['useOverride'] as bool? ?? false,
);

Map<String, dynamic> _$$FunctionMappingImplToJson(
  _$FunctionMappingImpl instance,
) => <String, dynamic>{
  'functionKey': instance.functionKey,
  'overrideModelId': instance.overrideModelId,
  'useOverride': instance.useOverride,
};
