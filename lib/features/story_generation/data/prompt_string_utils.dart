/// Shared string utilities for LLM prompt construction.
///
/// Centralises hot-path helpers that were previously duplicated across
/// scene-generation orchestrators.  All RegExp instances are compiled once.
class PromptStringUtils {
  PromptStringUtils._();

  static final RegExp _whitespace = RegExp(r'\s+');

  /// Compact [value] to at most [maxChars], normalising whitespace first.
  static String compact(String value, {required int maxChars}) {
    final normalized = value.replaceAll(_whitespace, ' ').trim();
    if (normalized.length <= maxChars) return normalized;
    return '${normalized.substring(0, maxChars - 3)}...';
  }

  /// Map [items] through [mapper] and join with [separator] using a
  /// [StringBuffer] to avoid the intermediate `List<String>` and
  /// repeated `join()` allocations.
  static String mapJoin<T>(
    Iterable<T> items,
    String Function(T) mapper, {
    String separator = '',
  }) {
    final buf = StringBuffer();
    var first = true;
    for (final item in items) {
      if (!first) buf.write(separator);
      first = false;
      buf.write(mapper(item));
    }
    return buf.toString();
  }
}
