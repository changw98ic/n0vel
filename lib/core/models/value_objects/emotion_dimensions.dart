import 'package:freezed_annotation/freezed_annotation.dart';

part 'emotion_dimensions.freezed.dart';
part 'emotion_dimensions.g.dart';

/// 情感维度值对象
/// 用于描述角色间关系的情感状态
@freezed
class EmotionDimensions with _$EmotionDimensions {
  const EmotionDimensions._();

  const factory EmotionDimensions({
    @Default(50) int affection,  // 好感度 0-100
    @Default(50) int trust,      // 信任度 0-100
    @Default(50) int respect,    // 尊敬度 0-100
    @Default(0) int fear,        // 恐惧度 0-100
  }) = _EmotionDimensions;

  factory EmotionDimensions.fromJson(Map<String, dynamic> json) =>
      _$EmotionDimensionsFromJson(json);

  /// 计算总体关系倾向
  /// 正数表示友好，负数表示敌对
  int get overallTendency {
    return affection + trust + respect - fear - 100;
  }

  /// 关系类型描述
  String get relationshipType {
    final tendency = overallTendency;
    if (tendency >= 100) return '挚友';
    if (tendency >= 50) return '好友';
    if (tendency >= 20) return '友好';
    if (tendency >= -20) return '中立';
    if (tendency >= -50) return '疏远';
    if (tendency >= -100) return '敌对';
    return '死敌';
  }

  /// 与另一个情感维度比较变化
  EmotionChange compareWith(EmotionDimensions other) {
    return EmotionChange(
      affectionDelta: other.affection - affection,
      trustDelta: other.trust - trust,
      respectDelta: other.respect - respect,
      fearDelta: other.fear - fear,
    );
  }
}

/// 情感变化
@freezed
class EmotionChange with _$EmotionChange {
  const EmotionChange._();

  const factory EmotionChange({
    required int affectionDelta,
    required int trustDelta,
    required int respectDelta,
    required int fearDelta,
  }) = _EmotionChange;

  /// 是否有显著变化
  bool get hasSignificantChange {
    return affectionDelta.abs() >= 10 ||
           trustDelta.abs() >= 10 ||
           respectDelta.abs() >= 10 ||
           fearDelta.abs() >= 10;
  }

  /// 变化描述
  String get description {
    final changes = <String>[];
    if (affectionDelta.abs() >= 10) {
      changes.add('好感${affectionDelta > 0 ? "+" : ""}$affectionDelta');
    }
    if (trustDelta.abs() >= 10) {
      changes.add('信任${trustDelta > 0 ? "+" : ""}$trustDelta');
    }
    if (respectDelta.abs() >= 10) {
      changes.add('尊敬${respectDelta > 0 ? "+" : ""}$respectDelta');
    }
    if (fearDelta.abs() >= 10) {
      changes.add('恐惧${fearDelta > 0 ? "+" : ""}$fearDelta');
    }
    return changes.join('，');
  }
}
