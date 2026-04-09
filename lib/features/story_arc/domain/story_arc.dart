import 'package:freezed_annotation/freezed_annotation.dart';

part 'story_arc.freezed.dart';
part 'story_arc.g.dart';

/// 故事弧线类型
enum ArcType { main, subplot, hidden, romance, comedy }

/// 弧线状态
enum ArcStatus { active, resolved, abandoned }

/// 章节在弧线中的角色
enum ArcChapterRole {
  progression,
  climax,
  twist,
  resolution,
  foreshadow,
  callback
}

/// 角色在弧线中的角色
enum ArcCharacterRole {
  protagonist,
  antagonist,
  mentor,
  participant,
  observer
}

/// 伏笔状态
enum ForeshadowStatus { planted, hinted, paidOff, abandoned }

/// 伏笔重要性
enum ForeshadowImportance { critical, major, minor }

/// 故事弧线
@freezed
class StoryArcModel with _$StoryArcModel {
  const factory StoryArcModel({
    required String id,
    required String workId,
    required String name,
    required ArcType arcType,
    String? description,
    String? startChapterId,
    String? endChapterId,
    @Default(0) int sortOrder,
    @Default(ArcStatus.active) ArcStatus status,
    String? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _StoryArcModel;

  factory StoryArcModel.fromJson(Map<String, dynamic> json) =>
      _$StoryArcModelFromJson(json);
}

/// 弧线-章节关联
@freezed
class ArcChapterModel with _$ArcChapterModel {
  const factory ArcChapterModel({
    required String id,
    required String arcId,
    required String chapterId,
    @Default(ArcChapterRole.progression) ArcChapterRole role,
    String? note,
    @Default(0) int sortOrder,
  }) = _ArcChapterModel;

  factory ArcChapterModel.fromJson(Map<String, dynamic> json) =>
      _$ArcChapterModelFromJson(json);
}

/// 弧线-角色关联
@freezed
class ArcCharacterModel with _$ArcCharacterModel {
  const factory ArcCharacterModel({
    required String id,
    required String arcId,
    required String characterId,
    @Default(ArcCharacterRole.participant) ArcCharacterRole role,
    String? note,
  }) = _ArcCharacterModel;

  factory ArcCharacterModel.fromJson(Map<String, dynamic> json) =>
      _$ArcCharacterModelFromJson(json);
}

/// 伏笔追踪
@freezed
class ForeshadowModel with _$ForeshadowModel {
  const factory ForeshadowModel({
    required String id,
    required String workId,
    required String description,
    String? plantChapterId,
    int? plantParagraphIndex,
    String? payoffChapterId,
    int? payoffParagraphIndex,
    @Default(ForeshadowStatus.planted) ForeshadowStatus status,
    @Default(ForeshadowImportance.minor) ForeshadowImportance importance,
    String? arcId,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _ForeshadowModel;

  factory ForeshadowModel.fromJson(Map<String, dynamic> json) =>
      _$ForeshadowModelFromJson(json);
}
