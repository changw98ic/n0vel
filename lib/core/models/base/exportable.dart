/// 可导出接口
/// 支持导出功能的实体
abstract class Exportable {
  /// 导出为 JSON
  Map<String, dynamic> toJson();

  /// 导出为纯文本
  String toPlainText();
}
