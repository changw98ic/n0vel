import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/models/value_objects/emotion_dimensions.dart';

part 'relationship.freezed.dart';
part 'relationship.g.dart';

/// 关系类型
enum RelationType {
  enemy('敌对'),
  hostile('敌意'),
  neutral('中立'),
  acquaintance('相识'),
  friendly('友好'),
  friend('朋友'),
  closeFriend('挚友'),
  lover('恋人'),
  family('亲人'),
  mentor('师徒'),
  rival('对手');

  const RelationType(this.label);

  final String label;

  /// 获取关系倾向值（用于排序）
  int get tendencyValue => switch (this) {
        RelationType.enemy => -100,
        RelationType.hostile => -60,
        RelationType.neutral => 0,
        RelationType.acquaintance => 20,
        RelationType.friendly => 40,
        RelationType.friend => 60,
        RelationType.closeFriend => 80,
        RelationType.lover => 100,
        RelationType.family => 90,
        RelationType.mentor => 70,
        RelationType.rival => -30,
      };
}

/// 关系头（当前状态）
@freezed
class RelationshipHead with _$RelationshipHead {
  const RelationshipHead._();

  const factory RelationshipHead({
    required String id,
    required String workId,
    required String characterAId,  // id较小者
    required String characterBId,  // id较大者
    required RelationType relationType,
    EmotionDimensions? emotionDimensions,
    String? firstChapterId,
    String? latestChapterId,
    @Default(0) int eventCount,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _RelationshipHead;

  factory RelationshipHead.fromJson(Map<String, dynamic> json) =>
      _$RelationshipHeadFromJson(json);

  /// 获取关系键（用于查找）
  static String getKey(String idA, String idB) {
    final sorted = [idA, idB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }
}

/// 变更类型
enum ChangeType {
  create('建立'),
  update('变化'),
  majorShift('重大转折');

  const ChangeType(this.label);
  final String label;
}

/// 关系事件（变更历史）
@freezed
class RelationshipEvent with _$RelationshipEvent {
  const RelationshipEvent._();

  const factory RelationshipEvent({
    required String id,
    required String headId,
    required String chapterId,
    required ChangeType changeType,
    RelationType? prevRelationType,
    required RelationType newRelationType,
    EmotionDimensions? prevEmotionDimensions,
    EmotionDimensions? newEmotionDimensions,
    String? changeReason,
    @Default(false) bool isKeyEvent,
    required DateTime createdAt,
  }) = _RelationshipEvent;

  factory RelationshipEvent.fromJson(Map<String, dynamic> json) =>
      _$RelationshipEventFromJson(json);

  /// 是否有显著变化
  bool get hasSignificantChange {
    if (prevRelationType != newRelationType) return true;
    if (prevEmotionDimensions != null && newEmotionDimensions != null) {
      final change = prevEmotionDimensions!.compareWith(newEmotionDimensions!);
      return change.hasSignificantChange;
    }
    return false;
  }
}
