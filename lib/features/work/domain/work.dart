import 'package:freezed_annotation/freezed_annotation.dart';

part 'work.freezed.dart';
part 'work.g.dart';

/// 作品领域模型
@freezed
class Work with _$Work {
  const Work._();

  const factory Work({
    required String id,
    required String name,
    String? type,
    String? description,
    String? coverPath,
    int? targetWords,
    @Default(0) int currentWords,
    @Default('draft') String status,
    @Default(false) bool isPinned,
    @Default(false) bool isArchived,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Work;

  factory Work.fromJson(Map<String, dynamic> json) => _$WorkFromJson(json);

  /// 计算进度百分比
  double get progress {
    if (targetWords == null || targetWords! <= 0) return 0;
    final p = currentWords / targetWords!;
    return p.clamp(0.0, 1.0);
  }

  /// 格式化进度显示
  String get progressText {
    if (targetWords == null) return '${_formatNumber(currentWords)}字';
    return '${_formatNumber(currentWords)} / ${_formatNumber(targetWords!)}字';
  }

  /// 状态显示文本
  String get statusText {
    return switch (status) {
      'draft' => '草稿',
      'ongoing' => '连载中',
      'completed' => '已完结',
      _ => status,
    };
  }

  /// 是否已设置目标
  bool get hasTarget => targetWords != null && targetWords! > 0;

  String _formatNumber(int n) {
    if (n >= 10000) {
      return '${(n / 10000).toStringAsFixed(1)}万';
    }
    return n.toString();
  }
}

/// 作品类型
enum WorkType {
  novel('小说'),
  novella('中篇'),
  shortStory('短篇'),
  fanfiction('同人'),
  other('其他');

  const WorkType(this.label);
  final String label;
}
