import 'package:freezed_annotation/freezed_annotation.dart';

part 'timeline_models.freezed.dart';
part 'timeline_models.g.dart';

/// 事件类型
enum EventType {
  main('主线'),
  sub('支线'),
  daily('日常'),
  battle('战斗'),
  romance('感情'),
  mystery('悬疑'),
  turning('转折');

  const EventType(this.label);
  final String label;
}

/// 事件重要程度
enum EventImportance {
  normal('一般'),
  important('重要'),
  key('关键'),
  turning('转折点');

  const EventImportance(this.label);
  final String label;
}

/// 故事事件
@freezed
class StoryEvent with _$StoryEvent {
  const StoryEvent._();

  const factory StoryEvent({
    required String id,
    required String workId,
    required String name,
    @Default(EventType.main) EventType type,
    @Default(EventImportance.normal) EventImportance importance,

    // 时间定位
    String? storyTime,       // 故事内时间（如：天元历1245年春）
    String? relativeTime,    // 相对时间（如：入门后第156天）
    String? chapterId,       // 发生章节
    int? chapterPosition,    // 章节内位置

    // 地点和角色
    String? locationId,
    @Default([]) List<String> characterIds,
    String? description,
    String? consequences,

    // 事件关联
    String? predecessorId,
    String? successorId,

    required DateTime createdAt,
  }) = _StoryEvent;

  factory StoryEvent.fromJson(Map<String, dynamic> json) =>
      _$StoryEventFromJson(json);

  /// 是否为关键事件
  bool get isKey =>
      importance == EventImportance.key || importance == EventImportance.turning;
}

/// 角色轨迹点
@freezed
class CharacterTrajectoryPoint with _$CharacterTrajectoryPoint {
  const factory CharacterTrajectoryPoint({
    required String characterId,
    required String chapterId,
    String? locationId,
    String? emotionalState,
    String? keyAction,
    @Default([]) List<String> interactedCharacterIds,
    String? note,
  }) = _CharacterTrajectoryPoint;

  factory CharacterTrajectoryPoint.fromJson(Map<String, dynamic> json) =>
      _$CharacterTrajectoryPointFromJson(json);
}

/// 时间冲突类型
enum ConflictType {
  timeSequence('时间顺序冲突'),
  locationConflict('位置冲突'),
  stateConflict('状态冲突'),
  characterAvailability('角色可用性冲突');

  const ConflictType(this.label);
  final String label;
}

/// 时间冲突
@freezed
class TimeConflict with _$TimeConflict {
  const factory TimeConflict({
    required String id,
    required ConflictType type,
    required String description,
    required String eventId1,
    String? eventId2,
    String? suggestion,
    @Default(false) bool isResolved,
  }) = _TimeConflict;

  factory TimeConflict.fromJson(Map<String, dynamic> json) =>
      _$TimeConflictFromJson(json);
}

/// 故事时间系统
@freezed
class StoryTimeSystem with _$StoryTimeSystem {
  const factory StoryTimeSystem({
    required String workId,
    required String startEpoch,    // 故事起点描述
    String? calendarType,          // 纪年方式
    @Default([]) List<TimeUnit> customUnits,
  }) = _StoryTimeSystem;

  factory StoryTimeSystem.fromJson(Map<String, dynamic> json) =>
      _$StoryTimeSystemFromJson(json);
}

/// 自定义时间单位
@freezed
class TimeUnit with _$TimeUnit {
  const factory TimeUnit({
    required String name,
    required int baseValue,        // 相对于基准单位的比例
    String? description,
  }) = _TimeUnit;

  factory TimeUnit.fromJson(Map<String, dynamic> json) =>
      _$TimeUnitFromJson(json);
}
