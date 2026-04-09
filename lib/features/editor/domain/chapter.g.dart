// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chapter.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ChapterImpl _$$ChapterImplFromJson(Map<String, dynamic> json) =>
    _$ChapterImpl(
      id: json['id'] as String,
      volumeId: json['volumeId'] as String,
      workId: json['workId'] as String,
      title: json['title'] as String,
      content: json['content'] as String?,
      wordCount: (json['wordCount'] as num?)?.toInt() ?? 0,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      status: $enumDecodeNullable(_$ChapterStatusEnumMap, json['status']) ??
          ChapterStatus.draft,
      reviewScore: (json['reviewScore'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$ChapterImplToJson(_$ChapterImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'volumeId': instance.volumeId,
      'workId': instance.workId,
      'title': instance.title,
      'content': instance.content,
      'wordCount': instance.wordCount,
      'sortOrder': instance.sortOrder,
      'status': _$ChapterStatusEnumMap[instance.status]!,
      'reviewScore': instance.reviewScore,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

const _$ChapterStatusEnumMap = {
  ChapterStatus.draft: 'draft',
  ChapterStatus.reviewing: 'reviewing',
  ChapterStatus.published: 'published',
};

_$SegmentImpl _$$SegmentImplFromJson(Map<String, dynamic> json) =>
    _$SegmentImpl(
      id: json['id'] as String,
      text: json['text'] as String,
      type: $enumDecode(_$SegmentTypeEnumMap, json['type']),
      needsIndent: json['needsIndent'] as bool? ?? false,
      speakerId: json['speakerId'] as String?,
    );

Map<String, dynamic> _$$SegmentImplToJson(_$SegmentImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'text': instance.text,
      'type': _$SegmentTypeEnumMap[instance.type]!,
      'needsIndent': instance.needsIndent,
      'speakerId': instance.speakerId,
    };

const _$SegmentTypeEnumMap = {
  SegmentType.dialogue: 'dialogue',
  SegmentType.narration: 'narration',
  SegmentType.innerThought: 'innerThought',
  SegmentType.description: 'description',
  SegmentType.action: 'action',
  SegmentType.transition: 'transition',
};
