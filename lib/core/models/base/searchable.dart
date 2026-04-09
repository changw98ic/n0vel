/// 可搜索接口
/// 用于全文搜索的实体
abstract class Searchable {
  /// 用于全文搜索的文本内容
  String get searchableText;

  /// 关键词/标签列表
  List<String> get keywords;
}
