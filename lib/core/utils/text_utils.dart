/// 文本差异对比工具
/// 用于增量更新和变更检测
class TextDiffer {
  /// 计算两个文本的差异
  static TextDiff diff(String oldText, String newText) {
    if (oldText == newText) {
      return TextDiff(equals: true, changes: []);
    }

    final changes = <TextChange>[];
    final oldLines = oldText.split('\n');
    final newLines = newText.split('\n');

    // 简单的行级差异检测
    int oldIndex = 0;
    int newIndex = 0;

    while (oldIndex < oldLines.length || newIndex < newLines.length) {
      if (oldIndex >= oldLines.length) {
        // 新增行
        changes.add(TextChange(
          type: ChangeType.added,
          newLineNumber: newIndex,
          content: newLines[newIndex],
        ));
        newIndex++;
      } else if (newIndex >= newLines.length) {
        // 删除行
        changes.add(TextChange(
          type: ChangeType.removed,
          oldLineNumber: oldIndex,
          content: oldLines[oldIndex],
        ));
        oldIndex++;
      } else if (oldLines[oldIndex] == newLines[newIndex]) {
        // 未变化
        oldIndex++;
        newIndex++;
      } else {
        // 查找是否有匹配行
        int matchInOld = -1;
        int matchInNew = -1;

        for (int i = newIndex; i < newLines.length && i < newIndex + 3; i++) {
          if (newLines[i] == oldLines[oldIndex]) {
            matchInNew = i;
            break;
          }
        }

        for (int i = oldIndex; i < oldLines.length && i < oldIndex + 3; i++) {
          if (oldLines[i] == newLines[newIndex]) {
            matchInOld = i;
            break;
          }
        }

        if (matchInNew != -1 && (matchInOld == -1 || matchInNew <= matchInOld)) {
          // 新增行
          for (int i = newIndex; i < matchInNew; i++) {
            changes.add(TextChange(
              type: ChangeType.added,
              newLineNumber: i,
              content: newLines[i],
            ));
          }
          newIndex = matchInNew;
        } else if (matchInOld != -1) {
          // 删除行
          for (int i = oldIndex; i < matchInOld; i++) {
            changes.add(TextChange(
              type: ChangeType.removed,
              oldLineNumber: i,
              content: oldLines[i],
            ));
          }
          oldIndex = matchInOld;
        } else {
          // 修改行
          changes.add(TextChange(
            type: ChangeType.modified,
            oldLineNumber: oldIndex,
            newLineNumber: newIndex,
            content: newLines[newIndex],
            oldContent: oldLines[oldIndex],
          ));
          oldIndex++;
          newIndex++;
        }
      }
    }

    return TextDiff(equals: false, changes: changes);
  }

  /// 计算文本内容的哈希值（用于增量检测）
  static String computeHash(String text) {
    // 简单的哈希计算，实际应使用更安全的算法
    int hash = 0;
    for (int i = 0; i < text.length; i++) {
      hash = ((hash << 5) - hash) + text.codeUnitAt(i);
      hash = hash & 0xFFFFFFFF;
    }
    return hash.toRadixString(16);
  }

  /// 检测文本是否有显著变化
  static bool hasSignificantChange(String oldText, String newText, {int threshold = 50}) {
    if (oldText.length == newText.length) {
      int diffCount = 0;
      for (int i = 0; i < oldText.length; i++) {
        if (oldText[i] != newText[i]) diffCount++;
        if (diffCount >= threshold) return true;
      }
      return diffCount >= threshold;
    }
    return (oldText.length - newText.length).abs() >= threshold;
  }
}

/// 文本差异结果
class TextDiff {
  final bool equals;
  final List<TextChange> changes;

  TextDiff({required this.equals, required this.changes});

  int get addedCount => changes.where((c) => c.type == ChangeType.added).length;
  int get removedCount => changes.where((c) => c.type == ChangeType.removed).length;
  int get modifiedCount => changes.where((c) => c.type == ChangeType.modified).length;
}

/// 文本变更
class TextChange {
  final ChangeType type;
  final int? oldLineNumber;
  final int? newLineNumber;
  final String content;
  final String? oldContent;

  TextChange({
    required this.type,
    this.oldLineNumber,
    this.newLineNumber,
    required this.content,
    this.oldContent,
  });
}

enum ChangeType { added, removed, modified }
