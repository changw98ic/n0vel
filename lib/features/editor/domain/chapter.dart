import 'package:freezed_annotation/freezed_annotation.dart';

part 'chapter.freezed.dart';
part 'chapter.g.dart';

/// 章节状态
enum ChapterStatus {
  draft('草稿'),
  reviewing('审查中'),
  published('已发布');

  const ChapterStatus(this.label);
  final String label;
}

/// 章节领域模型
@freezed
class Chapter with _$Chapter {
  const Chapter._();

  const factory Chapter({
    required String id,
    required String volumeId,
    required String workId,
    required String title,
    String? content,
    @Default(0) int wordCount,
    @Default(0) int sortOrder,
    @Default(ChapterStatus.draft) ChapterStatus status,
    double? reviewScore,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Chapter;

  factory Chapter.fromJson(Map<String, dynamic> json) => _$ChapterFromJson(json);

  /// 是否有内容
  bool get hasContent => content != null && content!.isNotEmpty;

  /// 预估阅读时间（分钟）
  int get estimatedReadingTime => (wordCount / 300).ceil();
}

/// 段落类型
enum SegmentType {
  dialogue,       // 对话
  narration,      // 叙述
  innerThought,   // 心理活动
  description,    // 描写
  action,         // 动作
  transition,     // 过渡
}

/// 段落（用于智能分段）
@freezed
class Segment with _$Segment {
  const Segment._();

  const factory Segment({
    required String id,
    required String text,
    required SegmentType type,
    @Default(false) bool needsIndent,
    String? speakerId,  // 对话说话人
  }) = _Segment;

  factory Segment.fromJson(Map<String, dynamic> json) => _$SegmentFromJson(json);

  /// 字数
  int get wordCount {
    final chineseCount = RegExp(r'[\u4e00-\u9fff]').allMatches(text).length;
    final englishCount = RegExp(r'[a-zA-Z]+').allMatches(text).length;
    return chineseCount + englishCount;
  }
}
