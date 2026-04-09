// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review_report.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ReviewReportImpl _$$ReviewReportImplFromJson(Map<String, dynamic> json) =>
    _$ReviewReportImpl(
      id: json['id'] as String,
      chapterId: json['chapterId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      overallScore: (json['overallScore'] as num?)?.toDouble() ?? 0,
      dimensionScores: (json['dimensionScores'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, (e as num).toDouble()),
      ),
      issues: (json['issues'] as List<dynamic>)
          .map((e) => ReviewIssue.fromJson(e as Map<String, dynamic>))
          .toList(),
      criticalCount: (json['criticalCount'] as num?)?.toInt() ?? 0,
      majorCount: (json['majorCount'] as num?)?.toInt() ?? 0,
      minorCount: (json['minorCount'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$ReviewReportImplToJson(_$ReviewReportImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'chapterId': instance.chapterId,
      'createdAt': instance.createdAt.toIso8601String(),
      'overallScore': instance.overallScore,
      'dimensionScores': instance.dimensionScores,
      'issues': instance.issues,
      'criticalCount': instance.criticalCount,
      'majorCount': instance.majorCount,
      'minorCount': instance.minorCount,
    };

_$ReviewIssueImpl _$$ReviewIssueImplFromJson(Map<String, dynamic> json) =>
    _$ReviewIssueImpl(
      id: json['id'] as String,
      reportId: json['reportId'] as String,
      dimension: $enumDecode(_$ReviewDimensionEnumMap, json['dimension']),
      severity: $enumDecode(_$IssueSeverityEnumMap, json['severity']),
      status: $enumDecodeNullable(_$IssueStatusEnumMap, json['status']) ??
          IssueStatus.pending,
      description: json['description'] as String,
      originalText: json['originalText'] as String?,
      location: json['location'] as String?,
      startOffset: (json['startOffset'] as num?)?.toInt(),
      endOffset: (json['endOffset'] as num?)?.toInt(),
      suggestion: json['suggestion'] as String?,
      relatedCharacterId: json['relatedCharacterId'] as String?,
      relatedSettingId: json['relatedSettingId'] as String?,
      fixedAt: json['fixedAt'] == null
          ? null
          : DateTime.parse(json['fixedAt'] as String),
      fixedBy: json['fixedBy'] as String?,
    );

Map<String, dynamic> _$$ReviewIssueImplToJson(_$ReviewIssueImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'reportId': instance.reportId,
      'dimension': _$ReviewDimensionEnumMap[instance.dimension]!,
      'severity': _$IssueSeverityEnumMap[instance.severity]!,
      'status': _$IssueStatusEnumMap[instance.status]!,
      'description': instance.description,
      'originalText': instance.originalText,
      'location': instance.location,
      'startOffset': instance.startOffset,
      'endOffset': instance.endOffset,
      'suggestion': instance.suggestion,
      'relatedCharacterId': instance.relatedCharacterId,
      'relatedSettingId': instance.relatedSettingId,
      'fixedAt': instance.fixedAt?.toIso8601String(),
      'fixedBy': instance.fixedBy,
    };

const _$ReviewDimensionEnumMap = {
  ReviewDimension.consistency: 'consistency',
  ReviewDimension.characterOoc: 'characterOoc',
  ReviewDimension.plotLogic: 'plotLogic',
  ReviewDimension.pacing: 'pacing',
  ReviewDimension.spelling: 'spelling',
  ReviewDimension.aiStyle: 'aiStyle',
  ReviewDimension.perspective: 'perspective',
  ReviewDimension.dialogue: 'dialogue',
};

const _$IssueSeverityEnumMap = {
  IssueSeverity.critical: 'critical',
  IssueSeverity.major: 'major',
  IssueSeverity.minor: 'minor',
};

const _$IssueStatusEnumMap = {
  IssueStatus.pending: 'pending',
  IssueStatus.ignored: 'ignored',
  IssueStatus.fixed: 'fixed',
  IssueStatus.falsePositive: 'falsePositive',
};

_$ReviewConfigImpl _$$ReviewConfigImplFromJson(Map<String, dynamic> json) =>
    _$ReviewConfigImpl(
      autoReview: json['autoReview'] as bool? ?? true,
      dimensionStrictness:
          (json['dimensionStrictness'] as Map<String, dynamic>?)?.map(
                (k, e) => MapEntry(k, (e as num).toInt()),
              ) ??
              const {},
      checkAiStyle: json['checkAiStyle'] as bool? ?? false,
      checkPerspective: json['checkPerspective'] as bool? ?? false,
      checkPacing: json['checkPacing'] as bool? ?? false,
      aiModelId: json['aiModelId'] as String,
    );

Map<String, dynamic> _$$ReviewConfigImplToJson(_$ReviewConfigImpl instance) =>
    <String, dynamic>{
      'autoReview': instance.autoReview,
      'dimensionStrictness': instance.dimensionStrictness,
      'checkAiStyle': instance.checkAiStyle,
      'checkPerspective': instance.checkPerspective,
      'checkPacing': instance.checkPacing,
      'aiModelId': instance.aiModelId,
    };
