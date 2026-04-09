import 'package:freezed_annotation/freezed_annotation.dart';

part 'volume.freezed.dart';
part 'volume.g.dart';

/// 卷领域模型
@freezed
class Volume with _$Volume {
  const Volume._();

  const factory Volume({
    required String id,
    required String workId,
    required String name,
    @Default(0) int sortOrder,
    required DateTime createdAt,
  }) = _Volume;

  factory Volume.fromJson(Map<String, dynamic> json) => _$VolumeFromJson(json);
}
