/// 时长格式化工具
class DurationFormatter {
  /// 格式化时长为可读字符串
  /// 例如: "2小时15分钟" 或 "45分钟"
  static String format(Duration duration, {bool showSeconds = false}) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    final parts = <String>[];

    if (hours > 0) {
      parts.add('$hours小时');
    }
    if (minutes > 0 || hours > 0) {
      parts.add('$minutes分钟');
    }
    if (showSeconds && seconds > 0 && hours == 0) {
      parts.add('$seconds秒');
    }

    if (parts.isEmpty) return showSeconds ? '0秒' : '0分钟';
    return parts.join('');
  }

  /// 格式化为简短形式
  /// 例如: "2:15" 或 "45:00"
  static String formatShort(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// 格式化预估阅读时间
  /// 假设阅读速度为 300 字/分钟
  static String readingTime(int wordCount, {int wordsPerMinute = 300}) {
    final minutes = (wordCount / wordsPerMinute).ceil();
    if (minutes < 1) return '不到1分钟';
    if (minutes < 60) return '约$minutes分钟';
    final hours = minutes ~/ 60;
    final remainMinutes = minutes % 60;
    if (remainMinutes == 0) return '约$hours小时';
    return '约$hours小时$remainMinutes分钟';
  }

  /// 格式化写作时长（用于统计）
  static String writingDuration(Duration duration) {
    if (duration.inMinutes < 1) return '刚写';
    if (duration.inMinutes < 60) return '${duration.inMinutes}分钟';
    if (duration.inHours < 24) return format(duration);
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    return '$days天${hours}小时';
  }
}
