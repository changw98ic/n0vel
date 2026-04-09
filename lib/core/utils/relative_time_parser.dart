/// 相对时间解析器
/// 用于解析故事内的相对时间描述（如"入门后第156天"）
class RelativeTimeParser {
  /// 相对时间点
  final DateTime? anchorDate;  // 锚点日期
  final String? anchorEvent;   // 锚点事件描述
  final Map<String, int> customUnits;  // 自定义时间单位（如"甲子"）

  RelativeTimeParser({
    this.anchorDate,
    this.anchorEvent,
    this.customUnits = const {},
  });

  /// 解析相对时间字符串
  /// 支持格式：
  /// - "第156天"
  /// - "三个月后"
  /// - "入门后第156天"
  /// - "天元历1245年春"
  RelativeTimeResult? parse(String text) {
    // 尝试匹配 "第N天" 格式
    final dayPattern = RegExp(r'第(\d+)天');
    final dayMatch = dayPattern.firstMatch(text);
    if (dayMatch != null) {
      final days = int.parse(dayMatch.group(1)!);
      return RelativeTimeResult(
        type: RelativeTimeType.days,
        value: days,
        originalText: text,
      );
    }

    // 尝试匹配 "N个月后" 格式
    final monthPattern = RegExp(r'(\d+)[个]?月[以]?后');
    final monthMatch = monthPattern.firstMatch(text);
    if (monthMatch != null) {
      final months = int.parse(monthMatch.group(1)!);
      return RelativeTimeResult(
        type: RelativeTimeType.months,
        value: months,
        originalText: text,
      );
    }

    // 尝试匹配 "N年后" 格式
    final yearPattern = RegExp(r'(\d+)[个]?年[以]?后');
    final yearMatch = yearPattern.firstMatch(text);
    if (yearMatch != null) {
      final years = int.parse(yearMatch.group(1)!);
      return RelativeTimeResult(
        type: RelativeTimeType.years,
        value: years,
        originalText: text,
      );
    }

    // 尝试匹配自定义纪年格式（如"天元历1245年春"）
    final customPattern = RegExp(r'(.+?)(\d+)年(.+)?');
    final customMatch = customPattern.firstMatch(text);
    if (customMatch != null) {
      final eraName = customMatch.group(1)!;
      final year = int.parse(customMatch.group(2)!);
      final season = customMatch.group(3)?.trim();
      return RelativeTimeResult(
        type: RelativeTimeType.customEra,
        value: year,
        eraName: eraName,
        season: season,
        originalText: text,
      );
    }

    return null;
  }

  /// 计算两个相对时间点之间的间隔
  static Duration? between(RelativeTimeResult from, RelativeTimeResult to) {
    if (from.type != to.type) return null;

    switch (from.type) {
      case RelativeTimeType.days:
        return Duration(days: to.value - from.value);
      case RelativeTimeType.months:
        return Duration(days: (to.value - from.value) * 30);
      case RelativeTimeType.years:
        return Duration(days: (to.value - from.value) * 365);
      case RelativeTimeType.customEra:
        // 自定义纪年需要更多上下文
        return null;
    }
  }
}

/// 相对时间解析结果
class RelativeTimeResult {
  final RelativeTimeType type;
  final int value;
  final String? eraName;
  final String? season;
  final String originalText;

  RelativeTimeResult({
    required this.type,
    required this.value,
    this.eraName,
    this.season,
    required this.originalText,
  });

  /// 格式化显示
  String get display {
    switch (type) {
      case RelativeTimeType.days:
        return '第${value}天';
      case RelativeTimeType.months:
        return '${value}个月后';
      case RelativeTimeType.years:
        return '${value}年后';
      case RelativeTimeType.customEra:
        final parts = <String>[if (eraName != null) eraName!, '${value}年'];
        if (season != null) parts.add(season!);
        return parts.join('');
    }
  }
}

enum RelativeTimeType { days, months, years, customEra }
