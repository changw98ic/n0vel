// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'detection_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ForbiddenPatternImpl _$$ForbiddenPatternImplFromJson(
        Map<String, dynamic> json) =>
    _$ForbiddenPatternImpl(
      id: json['id'] as String,
      pattern: json['pattern'] as String,
      description: json['description'] as String,
      examples: (json['examples'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      isEnabled: json['isEnabled'] as bool? ?? true,
    );

Map<String, dynamic> _$$ForbiddenPatternImplToJson(
        _$ForbiddenPatternImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'pattern': instance.pattern,
      'description': instance.description,
      'examples': instance.examples,
      'isEnabled': instance.isEnabled,
    };

_$PunctuationLimitImpl _$$PunctuationLimitImplFromJson(
        Map<String, dynamic> json) =>
    _$PunctuationLimitImpl(
      punctuation: json['punctuation'] as String,
      maxPerThousand: (json['maxPerThousand'] as num).toInt(),
      description: json['description'] as String,
    );

Map<String, dynamic> _$$PunctuationLimitImplToJson(
        _$PunctuationLimitImpl instance) =>
    <String, dynamic>{
      'punctuation': instance.punctuation,
      'maxPerThousand': instance.maxPerThousand,
      'description': instance.description,
    };

_$AIVocabularyImpl _$$AIVocabularyImplFromJson(Map<String, dynamic> json) =>
    _$AIVocabularyImpl(
      word: json['word'] as String,
      category: json['category'] as String,
      alternatives: (json['alternatives'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$AIVocabularyImplToJson(_$AIVocabularyImpl instance) =>
    <String, dynamic>{
      'word': instance.word,
      'category': instance.category,
      'alternatives': instance.alternatives,
    };

_$DetectionResultImpl _$$DetectionResultImplFromJson(
        Map<String, dynamic> json) =>
    _$DetectionResultImpl(
      id: json['id'] as String,
      type: $enumDecode(_$DetectionTypeEnumMap, json['type']),
      matchedText: json['matchedText'] as String,
      startOffset: (json['startOffset'] as num).toInt(),
      endOffset: (json['endOffset'] as num).toInt(),
      suggestion: json['suggestion'] as String?,
      description: json['description'] as String?,
      pattern: json['pattern'] as String?,
    );

Map<String, dynamic> _$$DetectionResultImplToJson(
        _$DetectionResultImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$DetectionTypeEnumMap[instance.type]!,
      'matchedText': instance.matchedText,
      'startOffset': instance.startOffset,
      'endOffset': instance.endOffset,
      'suggestion': instance.suggestion,
      'description': instance.description,
      'pattern': instance.pattern,
    };

const _$DetectionTypeEnumMap = {
  DetectionType.forbiddenPattern: 'forbiddenPattern',
  DetectionType.punctuationAbuse: 'punctuationAbuse',
  DetectionType.aiVocabulary: 'aiVocabulary',
  DetectionType.perspectiveIssue: 'perspectiveIssue',
  DetectionType.pacingIssue: 'pacingIssue',
  DetectionType.standardizedOutput: 'standardizedOutput',
};

_$DetectionReportImpl _$$DetectionReportImplFromJson(
        Map<String, dynamic> json) =>
    _$DetectionReportImpl(
      chapterId: json['chapterId'] as String,
      analyzedAt: DateTime.parse(json['analyzedAt'] as String),
      results: (json['results'] as List<dynamic>)
          .map((e) => DetectionResult.fromJson(e as Map<String, dynamic>))
          .toList(),
      typeCounts: Map<String, int>.from(json['typeCounts'] as Map),
      totalIssues: (json['totalIssues'] as num?)?.toInt() ?? 0,
      wordCount: (json['wordCount'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$DetectionReportImplToJson(
        _$DetectionReportImpl instance) =>
    <String, dynamic>{
      'chapterId': instance.chapterId,
      'analyzedAt': instance.analyzedAt.toIso8601String(),
      'results': instance.results,
      'typeCounts': instance.typeCounts,
      'totalIssues': instance.totalIssues,
      'wordCount': instance.wordCount,
    };
