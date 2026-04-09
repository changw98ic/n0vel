// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prompt_template.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PromptTemplateImpl _$$PromptTemplateImplFromJson(Map<String, dynamic> json) =>
    _$PromptTemplateImpl(
      id: json['id'] as String,
      functionType: json['functionType'] as String,
      name: json['name'] as String,
      systemPrompt: json['systemPrompt'] as String,
      userPromptTemplate: json['userPromptTemplate'] as String,
      description: json['description'] as String?,
      variables: (json['variables'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      version: (json['version'] as num?)?.toInt() ?? 1,
      isDefault: json['isDefault'] as bool? ?? false,
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$PromptTemplateImplToJson(
        _$PromptTemplateImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'functionType': instance.functionType,
      'name': instance.name,
      'systemPrompt': instance.systemPrompt,
      'userPromptTemplate': instance.userPromptTemplate,
      'description': instance.description,
      'variables': instance.variables,
      'version': instance.version,
      'isDefault': instance.isDefault,
      'isBuiltIn': instance.isBuiltIn,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
