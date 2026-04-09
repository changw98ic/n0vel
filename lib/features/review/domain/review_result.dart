import 'package:freezed_annotation/freezed_annotation.dart';

part 'review_result.freezed.dart';

/// 审查结果（用于UI显示）
@freezed
class ReviewResult with _$ReviewResult {
  const factory ReviewResult({
    required String chapterId,
    required String chapterTitle,
    double? score,
    @Default(0) int issueCount,
    @Default(0) int criticalCount,
    required ReviewStatus status,
    DateTime? reviewedAt,
  }) = _ReviewResult;
}

/// 审查状态
enum ReviewStatus {
  notReviewed('未审查'),
  reviewing('审查中'),
  passed('已通过'),
  needsFix('待修复'),
  failed('不通过');

  const ReviewStatus(this.label);
  final String label;
}

/// 维度评分详情
@freezed
class DimensionScoreDetail with _$DimensionScoreDetail {
  const factory DimensionScoreDetail({
    required ReviewDimension dimension,
    required double score,
    required int issueCount,
    String? comment,
  }) = _DimensionScoreDetail;
}

/// 审查维度
enum ReviewDimension {
  consistency('设定一致性'),
  characterOoc('角色OOC'),
  plotLogic('剧情逻辑'),
  pacing('节奏把控'),
  spelling('错别字'),
  aiStyle('AI口吻'),
  perspective('视角合理'),
  dialogue('对话质量');

  const ReviewDimension(this.label);
  final String label;
}
