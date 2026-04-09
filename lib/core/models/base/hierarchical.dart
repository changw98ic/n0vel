/// 层级结构接口
/// 用于支持父子关系的实体（如卷-章节、地点层级）
abstract class Hierarchical<T> {
  /// 父级 ID（null 表示顶层）
  String? get parentId;

  /// 子级列表
  List<T> get children;

  /// 层级深度（0 = 顶层）
  int get depth;
}
