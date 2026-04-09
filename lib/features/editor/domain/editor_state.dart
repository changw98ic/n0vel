import 'package:freezed_annotation/freezed_annotation.dart';

part 'editor_state.freezed.dart';
part 'editor_state.g.dart';

/// 编辑器状态
@freezed
class EditorState with _$EditorState {
  const EditorState._();

  const factory EditorState({
    required String chapterId,
    String? content,
    @Default(false) bool isDirty,
    @Default(false) bool isSaving,
    @Default(false) bool autoSaveEnabled,
    DateTime? lastSavedAt,
    String? error,

    // 统计
    @Default(0) int wordCount,
    @Default(0) int paragraphCount,
    @Default(0) int dialogueCount,
    @Default(0) int dialogueWordCount,

    // 选中的角色
    @Default([]) List<String> involvedCharacterIds,

    // 撤销/重做
    @Default([]) List<EditorHistoryEntry> undoStack,
    @Default([]) List<EditorHistoryEntry> redoStack,
    @Default(0) int maxHistorySize,
  }) = _EditorState;

  /// 是否可撤销
  bool get canUndo => undoStack.isNotEmpty;

  /// 是否可重做
  bool get canRedo => redoStack.isNotEmpty;

  /// 对话占比
  double get dialogueRatio {
    if (wordCount == 0) return 0;
    return dialogueWordCount / wordCount;
  }
}

/// 编辑器历史记录条目
@freezed
class EditorHistoryEntry with _$EditorHistoryEntry {
  const factory EditorHistoryEntry({
    required String content,
    required int cursorPosition,
    required DateTime timestamp,
    String? description,
  }) = _EditorHistoryEntry;
}

/// 智能分段结果
@freezed
class SmartSegmentResult with _$SmartSegmentResult {
  const factory SmartSegmentResult({
    required List<Segment> segments,
    @Default([]) List<String> detectedSpeakers,
    @Default(0) int dialogueCount,
    @Default(0) int innerThoughtCount,
  }) = _SmartSegmentResult;
}

/// 段落类型
enum SegmentType {
  dialogue('对话'),
  narration('叙述'),
  innerThought('心理'),
  description('描写'),
  action('动作'),
  transition('过渡');

  const SegmentType(this.label);
  final String label;
}

/// 段落
@freezed
class Segment with _$Segment {
  const Segment._();

  const factory Segment({
    required String id,
    required String text,
    required SegmentType type,
    @Default(true) bool needsIndent,
    String? speakerId,
  }) = _Segment;

  factory Segment.fromJson(Map<String, dynamic> json) => _$SegmentFromJson(json);

  int get wordCount {
    final chineseCount = RegExp(r'[\u4e00-\u9fff]').allMatches(text).length;
    final englishCount = RegExp(r'[a-zA-Z]+').allMatches(text).length;
    return chineseCount + englishCount;
  }
}
