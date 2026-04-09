/// 文件名安全化工具
/// 将任意字符串转换为安全的文件名
class Slugify {
  static final _invalidChars = RegExp(r'[<>:"/\\|?*\x00-\x1f]');
  static final _whitespace = RegExp(r'\s+');
  static final _multipleDashes = RegExp(r'-+');
  static final _reservedNames = {
    'CON', 'PRN', 'AUX', 'NUL',
    'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
    'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9',
  };

  /// 将字符串转换为安全的文件名
  static String convert(String input, {int maxLength = 200}) {
    var result = input
        .replaceAll(_invalidChars, '')
        .replaceAll(_whitespace, '-')
        .replaceAll(_multipleDashes, '-')
        .trim();

    // 移除首尾的点号和空格
    while (result.startsWith('.') || result.startsWith('-') || result.startsWith(' ')) {
      result = result.substring(1);
    }
    while (result.endsWith('.') || result.endsWith('-') || result.endsWith(' ')) {
      result = result.substring(0, result.length - 1);
    }

    // 检查保留名
    if (_reservedNames.contains(result.toUpperCase())) {
      result = '_$result';
    }

    // 截断长度
    if (result.length > maxLength) {
      result = result.substring(0, maxLength);
      // 确保不以部分 UTF-8 字符结尾
      while (result.isNotEmpty && result.codeUnitAt(result.length - 1) >= 0xD800 && result.codeUnitAt(result.length - 1) <= 0xDFFF) {
        result = result.substring(0, result.length - 1);
      }
    }

    return result.isEmpty ? 'untitled' : result;
  }

  /// 生成带序号的唯一文件名
  static String unique(String baseName, Set<String> existingNames, {int maxLength = 200}) {
    var name = convert(baseName, maxLength: maxLength);
    if (!existingNames.contains(name)) return name;

    var counter = 1;
    final extension = _getExtension(name);
    final nameWithoutExt = extension.isEmpty ? name : name.substring(0, name.length - extension.length - 1);

    while (true) {
      final newName = '$nameWithoutExt ($counter).$extension';
      if (!existingNames.contains(newName)) return newName;
      counter++;
    }
  }

  static String _getExtension(String filename) {
    final dotIndex = filename.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == 0) return '';
    return filename.substring(dotIndex + 1);
  }
}
