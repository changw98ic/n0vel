/// 基础实体接口
/// 所有数据模型的基础接口
abstract class BaseEntity {
  /// 唯一标识符
  String get id;

  /// 显示名称
  String get name;

  /// 创建时间（毫秒时间戳）
  DateTime get createdAt;

  /// 更新时间（毫秒时间戳）
  DateTime get updatedAt;

  /// 是否已归档
  bool get isArchived;
}
