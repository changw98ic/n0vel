import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../domain/chapter.dart' as domain;

/// 章节数据仓库
class ChapterRepository {
  final AppDatabase _db;

  ChapterRepository(this._db);

  /// 获取章节列表（按卷分组）
  Future<List<domain.Chapter>> getChaptersByWorkId(String workId) async {
    final query = _db.select(_db.chapters)
      ..where((t) => t.workId.equals(workId))
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);

    final results = await query.get();
    return results.map(_toDomain).toList();
  }

  /// 获取单个章节
  Future<domain.Chapter?> getChapterById(String id) async {
    final query = _db.select(_db.chapters)..where((t) => t.id.equals(id));
    final result = await query.getSingleOrNull();
    return result != null ? _toDomain(result) : null;
  }

  Future<List<domain.Chapter>> searchChapters(
    String workId,
    String query,
  ) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return const [];
    }

    final titlePattern = '%$normalized%';
    final ftsQuery = _toFtsQuery(normalized);
    final rows = await _db
        .customSelect(
          '''
      SELECT DISTINCT
        c.id,
        c.volume_id,
        c.work_id,
        c.title,
        c.content,
        c.word_count,
        c.sort_order,
        c.status,
        c.review_score,
        c.created_at,
        c.updated_at
      FROM chapters AS c
      LEFT JOIN chapters_fts AS fts ON fts.rowid = c.rowid
      WHERE c.work_id = ?
        AND (
          c.title LIKE ? COLLATE NOCASE
          OR (
            c.content IS NOT NULL
            AND chapters_fts MATCH ?
          )
        )
      ORDER BY c.sort_order ASC, c.updated_at DESC
      ''',
          variables: [
            Variable<String>(workId),
            Variable<String>(titlePattern),
            Variable<String>(ftsQuery),
          ],
          readsFrom: {_db.chapters},
        )
        .get();

    return rows
        .map(
          (row) => _toDomain(
            Chapter(
              id: row.read<String>('id'),
              volumeId: row.read<String>('volume_id'),
              workId: row.read<String>('work_id'),
              title: row.read<String>('title'),
              content: row.readNullable<String>('content'),
              wordCount: row.read<int>('word_count'),
              sortOrder: row.read<int>('sort_order'),
              status: row.read<String>('status'),
              reviewScore: row.readNullable<double>('review_score'),
              createdAt: row.read<DateTime>('created_at'),
              updatedAt: row.read<DateTime>('updated_at'),
            ),
          ),
        )
        .toList();
  }

  /// 创建章节
  /// 如果 sortOrder 与同卷已有章节冲突，自动使用最大值+1
  Future<domain.Chapter> createChapter({
    required String volumeId,
    required String workId,
    required String title,
    int sortOrder = 0,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();

    // 查询该卷下已有的最大 sortOrder
    final existing = await (_db.select(_db.chapters)
          ..where((t) => t.volumeId.equals(volumeId)))
        .get();
    final maxSort = existing.isEmpty
        ? -1
        : existing.map((c) => c.sortOrder).reduce((a, b) => a > b ? a : b);

    // 如果指定 sortOrder 已被占用，自动追加到末尾
    final usedOrders = existing.map((c) => c.sortOrder).toSet();
    final effectiveSort = usedOrders.contains(sortOrder) ? maxSort + 1 : sortOrder;

    await _db
        .into(_db.chapters)
        .insert(
          ChaptersCompanion(
            id: Value(id),
            volumeId: Value(volumeId),
            workId: Value(workId),
            title: Value(title),
            sortOrder: Value(effectiveSort),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    return (await getChapterById(id))!;
  }

  /// 更新章节内容
  Future<void> updateContent(String id, String content, int wordCount) async {
    final companion = ChaptersCompanion(
      content: Value(content),
      wordCount: Value(wordCount),
      updatedAt: Value(DateTime.now()),
    );
    await _safeUpdate(id, companion);
    await _syncWorkWordCountForChapter(id);
  }

  /// 更新章节标题
  Future<void> updateTitle(String id, String title) async {
    await _safeUpdate(id, ChaptersCompanion(
      title: Value(title),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// 更新章节状态
  Future<void> updateStatus(String id, domain.ChapterStatus status) async {
    await _safeUpdate(id, ChaptersCompanion(
      status: Value(status.name),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// 安全更新：FTS 触发器损坏时先删除触发器再重试
  Future<void> _safeUpdate(String id, ChaptersCompanion companion) async {
    try {
      await (_db.update(_db.chapters)..where((t) => t.id.equals(id))).write(companion);
    } catch (_) {
      // FTS 触发器异常 — 删除后重试，下次启动时重建
      try {
        await _db.customStatement('DROP TRIGGER IF EXISTS chapters_au');
        await _db.customStatement('DROP TRIGGER IF EXISTS chapters_ai');
        await _db.customStatement('DROP TRIGGER IF EXISTS chapters_ad');
      } catch (_) {}
      await (_db.update(_db.chapters)..where((t) => t.id.equals(id))).write(companion);
    }
  }

  /// 删除章节
  Future<void> deleteChapter(String id) async {
    final chapter = await getChapterById(id);
    final workId = chapter?.workId;
    await (_db.delete(_db.chapters)..where((t) => t.id.equals(id))).go();
    if (workId != null) {
      await _syncWorkWordCount(workId);
    }
  }

  /// 将章节所属作品的 currentWords 同步为所有章节字数之和
  Future<void> _syncWorkWordCountForChapter(String chapterId) async {
    final chapter = await getChapterById(chapterId);
    if (chapter == null) return;
    await _syncWorkWordCount(chapter.workId);
  }

  Future<void> _syncWorkWordCount(String workId) async {
    final chapters = await (_db.select(_db.chapters)
          ..where((t) => t.workId.equals(workId)))
        .get();
    final totalWords = chapters.fold(0, (sum, c) => sum + c.wordCount);
    await (_db.update(_db.works)..where((t) => t.id.equals(workId))).write(
      WorksCompanion(
        currentWords: Value(totalWords),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 获取相邻章节
  Future<domain.Chapter?> getPreviousChapter(String chapterId) async {
    final chapter = await getChapterById(chapterId);
    if (chapter == null) return null;

    final query = _db.select(_db.chapters)
      ..where(
        (t) =>
            t.workId.equals(chapter.workId) &
            t.sortOrder.isSmallerThanValue(chapter.sortOrder),
      )
      ..orderBy([(t) => OrderingTerm.desc(t.sortOrder)])
      ..limit(1);

    final result = await query.getSingleOrNull();
    return result != null ? _toDomain(result) : null;
  }

  Future<domain.Chapter?> getNextChapter(String chapterId) async {
    final chapter = await getChapterById(chapterId);
    if (chapter == null) return null;

    final query = _db.select(_db.chapters)
      ..where(
        (t) =>
            t.workId.equals(chapter.workId) &
            t.sortOrder.isBiggerThanValue(chapter.sortOrder),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])
      ..limit(1);

    final result = await query.getSingleOrNull();
    return result != null ? _toDomain(result) : null;
  }

  String _toFtsQuery(String query) {
    final tokens = query
        .split(RegExp(r'\s+'))
        .map((token) => token.trim())
        .where((token) => token.isNotEmpty)
        .map((token) => '"${token.replaceAll('"', '""')}"*')
        .toList();

    if (tokens.isEmpty) {
      return '""';
    }

    return tokens.join(' ');
  }

  domain.Chapter _toDomain(Chapter data) {
    return domain.Chapter(
      id: data.id,
      volumeId: data.volumeId,
      workId: data.workId,
      title: data.title,
      content: data.content,
      wordCount: data.wordCount,
      sortOrder: data.sortOrder,
      status: domain.ChapterStatus.values.firstWhere(
        (e) => e.name == data.status,
        orElse: () => domain.ChapterStatus.draft,
      ),
      reviewScore: data.reviewScore,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
    );
  }
}
