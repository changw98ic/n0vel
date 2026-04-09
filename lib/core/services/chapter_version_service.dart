import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';

/// 版本差异信息
class VersionDiff {
  final String addedText; // 新增的文本
  final String removedText; // 删除的文本
  final int wordsAdded;
  final int wordsRemoved;
  final double similarity; // 0.0-1.0 相似度

  const VersionDiff({
    required this.addedText,
    required this.removedText,
    required this.wordsAdded,
    required this.wordsRemoved,
    required this.similarity,
  });
}

/// 章节版本服务
class ChapterVersionService {
  final AppDatabase _db;
  final _uuid = const Uuid();

  ChapterVersionService(this._db);

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// 创建版本快照
  Future<ChapterVersion> createSnapshot({
    required String chapterId,
    required String title,
    required String content,
    required int wordCount,
    String? changeDescription,
    String changeType = 'manual',
  }) async {
    final latestVersion = await getLatestVersion(chapterId);
    final versionNumber = (latestVersion?.versionNumber ?? 0) + 1;

    final id = _uuid.v4();
    final now = DateTime.now();

    await _db.into(_db.chapterVersions).insert(
          ChapterVersionsCompanion.insert(
            id: id,
            chapterId: chapterId,
            title: title,
            content: content,
            wordCount: wordCount,
            versionNumber: versionNumber,
            createdAt: now,
            changeDescription: Value(changeDescription),
            changeType: Value(changeType),
          ),
        );

    return ChapterVersion(
      id: id,
      chapterId: chapterId,
      title: title,
      content: content,
      wordCount: wordCount,
      changeDescription: changeDescription,
      changeType: changeType,
      versionNumber: versionNumber,
      createdAt: now,
    );
  }

  /// 获取章节的所有版本（按版本号降序）
  Future<List<ChapterVersion>> getVersions(String chapterId) async {
    return (_db.select(_db.chapterVersions)
          ..where((t) => t.chapterId.equals(chapterId))
          ..orderBy([(t) => OrderingTerm.desc(t.versionNumber)]))
        .get();
  }

  /// 获取最新版本
  Future<ChapterVersion?> getLatestVersion(String chapterId) async {
    return (_db.select(_db.chapterVersions)
          ..where((t) => t.chapterId.equals(chapterId))
          ..orderBy([(t) => OrderingTerm.desc(t.versionNumber)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// 获取特定版本
  Future<ChapterVersion?> getVersion(String versionId) async {
    return (_db.select(_db.chapterVersions)
          ..where((t) => t.id.equals(versionId)))
        .getSingleOrNull();
  }

  /// 恢复到指定版本（创建新快照 + 更新章节内容）
  Future<void> restoreVersion(String versionId) async {
    final version = await getVersion(versionId);
    if (version == null) return;

    // Create a new snapshot recording the restore action
    await createSnapshot(
      chapterId: version.chapterId,
      title: '恢复至版本 ${version.versionNumber}',
      content: version.content,
      wordCount: version.wordCount,
      changeDescription: '从版本 ${version.versionNumber} 恢复',
      changeType: 'restore',
    );

    // Update the chapter's content
    await (_db.update(_db.chapters)
          ..where((t) => t.id.equals(version.chapterId)))
        .write(
      ChaptersCompanion(
        content: Value(version.content),
        wordCount: Value(version.wordCount),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 比较两个版本的差异
  VersionDiff compareVersions(String contentA, String contentB) {
    final linesA = contentA.split('\n');
    final linesB = contentB.split('\n');

    final setA = linesA.toSet();
    final setB = linesB.toSet();

    // Lines only in A (removed when going A -> B)
    final removedLines = setA.difference(setB).toList();
    // Lines only in B (added when going A -> B)
    final addedLines = setB.difference(setA).toList();

    final removedText = removedLines.join('\n');
    final addedText = addedLines.join('\n');

    final wordsRemoved = _countWords(removedText);
    final wordsAdded = _countWords(addedText);

    // Compute similarity using line-based Jaccard index
    final totalUniqueLines = setA.union(setB).length;
    final commonLines = setA.intersection(setB).length;
    final similarity =
        totalUniqueLines > 0 ? commonLines / totalUniqueLines : 1.0;

    return VersionDiff(
      addedText: addedText,
      removedText: removedText,
      wordsAdded: wordsAdded,
      wordsRemoved: wordsRemoved,
      similarity: similarity,
    );
  }

  /// 自动保存（仅在内容变化超过阈值时）
  Future<bool> autoSaveIfNeeded({
    required String chapterId,
    required String currentContent,
    required int currentWordCount,
    int minChangeWords = 100,
  }) async {
    final latest = await getLatestVersion(chapterId);
    if (latest == null) {
      // No previous version exists, create initial snapshot
      await createSnapshot(
        chapterId: chapterId,
        title: '自动保存',
        content: currentContent,
        wordCount: currentWordCount,
        changeType: 'auto_save',
      );
      return true;
    }

    final diff = compareVersions(latest.content, currentContent);
    final changeWords = diff.wordsAdded + diff.wordsRemoved;

    if (changeWords < minChangeWords) {
      return false;
    }

    await createSnapshot(
      chapterId: chapterId,
      title: '自动保存',
      content: currentContent,
      wordCount: currentWordCount,
      changeDescription: '新增 ${diff.wordsAdded} 字，删除 ${diff.wordsRemoved} 字',
      changeType: 'auto_save',
    );
    return true;
  }

  /// 清理旧版本（保留最近 N 个）
  Future<void> cleanupOldVersions(String chapterId, {int keepCount = 20}) async {
    final versions = await getVersions(chapterId);
    if (versions.length <= keepCount) return;

    // versions are already sorted descending by versionNumber,
    // so the ones to delete are at the end (oldest)
    final toDelete = versions.skip(keepCount);
    for (final version in toDelete) {
      await (_db.delete(_db.chapterVersions)
            ..where((t) => t.id.equals(version.id)))
          .go();
    }
  }

  /// 获取版本数量
  Future<int> getVersionCount(String chapterId) async {
    final versions = await (_db.select(_db.chapterVersions)
          ..where((t) => t.chapterId.equals(chapterId)))
        .get();
    return versions.length;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Count words in text. Handles both Chinese characters and
  /// whitespace-separated words (e.g. English).
  int _countWords(String text) {
    if (text.isEmpty) return 0;

    // Count CJK characters
    final cjkRegex = RegExp(r'[\u4e00-\u9fff\u3400-\u4dbf\uf900-\ufaff]');
    final cjkMatches = cjkRegex.allMatches(text);
    int count = cjkMatches.length;

    // Remove CJK characters and count remaining whitespace-separated words
    final withoutCjk = text.replaceAll(cjkRegex, ' ');
    final words = withoutCjk.split(RegExp(r'\s+'));
    for (final word in words) {
      if (word.isNotEmpty) {
        count++;
      }
    }

    return count;
  }
}
