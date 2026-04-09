// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'editor_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SegmentImpl _$$SegmentImplFromJson(Map<String, dynamic> json) =>
    _$SegmentImpl(
      id: json['id'] as String,
      text: json['text'] as String,
      type: $enumDecode(_$SegmentTypeEnumMap, json['type']),
      needsIndent: json['needsIndent'] as bool? ?? true,
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
