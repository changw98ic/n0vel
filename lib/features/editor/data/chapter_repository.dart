import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../domain/chapter.dart' as domain;

/// 绔犺妭鏁版嵁浠撳簱
class ChapterRepository {
  final AppDatabase _db;

  ChapterRepository(this._db);

  /// 鑾峰彇绔犺妭鍒楄〃锛堟寜鍗峰垎缁勶級
  Future<List<domain.Chapter>> getChaptersByWorkId(String workId) async {
    final query = _db.select(_db.chapters)
      ..where((t) => t.workId.equals(workId))
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);

    final results = await query.get();
    return results.map(_toDomain).toList();
  }

  /// 鑾峰彇鍗曚釜绔犺妭
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
      WHERE c.work_id = ?
        AND (
          c.title LIKE ? COLLATE NOCASE
          OR (
            c.content IS NOT NULL
            AND c.rowid IN (
              SELECT rowid
              FROM chapters_fts
              WHERE chapters_fts MATCH ?
            )
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

  /// 鍒涘缓绔犺妭
  /// 濡傛灉 sortOrder 涓庡悓鍗峰凡鏈夌珷鑺傚啿绐侊紝鑷姩浣跨敤鏈€澶у€?1
  Future<domain.Chapter> createChapter({
    required String volumeId,
    required String workId,
    required String title,
    int sortOrder = 0,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();

    // 鏌ヨ璇ュ嵎涓嬪凡鏈夌殑鏈€澶?sortOrder
    final existing = await (_db.select(_db.chapters)
          ..where((t) => t.volumeId.equals(volumeId)))
        .get();
    final maxSort = existing.isEmpty
        ? -1
        : existing.map((c) => c.sortOrder).reduce((a, b) => a > b ? a : b);

    // 濡傛灉鎸囧畾 sortOrder 宸茶鍗犵敤锛岃嚜鍔ㄨ拷鍔犲埌鏈熬
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

  Future<domain.Chapter?> getChapterByVolumeAndTitle({
    required String volumeId,
    required String title,
  }) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) return null;
    final query = _db.select(_db.chapters)
      ..where((t) => t.volumeId.equals(volumeId) & t.title.equals(normalizedTitle))
      ..limit(1);
    final result = await query.getSingleOrNull();
    return result != null ? _toDomain(result) : null;
  }

  Future<domain.Chapter> createOrGetChapterByTitle({
    required String volumeId,
    required String workId,
    required String title,
    int sortOrder = 0,
  }) async {
    final normalizedTitle = title.trim();
    final existing = await getChapterByVolumeAndTitle(
      volumeId: volumeId,
      title: normalizedTitle,
    );
    if (existing != null) return existing;
    return createChapter(
      volumeId: volumeId,
      workId: workId,
      title: normalizedTitle,
      sortOrder: sortOrder,
    );
  }

  /// 鏇存柊绔犺妭鍐呭
  Future<void> updateContent(String id, String content, int wordCount) async {
    final companion = ChaptersCompanion(
      content: Value(content),
      wordCount: Value(wordCount),
      updatedAt: Value(DateTime.now()),
    );
    await _safeUpdate(id, companion);
    await _syncWorkWordCountForChapter(id);
  }

  /// 鏇存柊绔犺妭鏍囬
  Future<void> updateTitle(String id, String title) async {
    await _safeUpdate(id, ChaptersCompanion(
      title: Value(title),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// 鏇存柊绔犺妭鐘舵€?
  Future<void> updateStatus(String id, domain.ChapterStatus status) async {
    await _safeUpdate(id, ChaptersCompanion(
      status: Value(status.name),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// 瀹夊叏鏇存柊锛欶TS 瑙﹀彂鍣ㄦ崯鍧忔椂鍏堝垹闄よЕ鍙戝櫒鍐嶉噸璇?
  Future<void> _safeUpdate(String id, ChaptersCompanion companion) async {
    Future<int> writeUpdate() {
      return (_db.update(_db.chapters)..where((t) => t.id.equals(id))).write(
        companion,
      );
    }

    try {
      final updatedRows = await writeUpdate();
      if (updatedRows > 0) {
        return;
      }
    } catch (_) {
      // FTS 瑙﹀彂鍣ㄥ紓甯?鈥?鍒犻櫎鍚庨噸璇曪紝涓嬫鍚姩鏃堕噸寤?
      try {
        await _db.customStatement('DROP TRIGGER IF EXISTS chapters_au');
        await _db.customStatement('DROP TRIGGER IF EXISTS chapters_ai');
        await _db.customStatement('DROP TRIGGER IF EXISTS chapters_ad');
      } catch (_) {}
      final updatedRows = await writeUpdate();
      if (updatedRows > 0) {
        return;
      }
    }

    throw StateError('Failed to update chapter: $id');
  }

  /// 鍒犻櫎绔犺妭
  Future<void> deleteChapter(String id) async {
    final chapter = await getChapterById(id);
    final workId = chapter?.workId;

    // 娓呯悊澶栭敭寮曠敤锛氬垹闄?arcChapters 鍏宠仈
    await (_db.delete(_db.arcChapters)..where((t) => t.chapterId.equals(id))).go();

    // 娓呯悊澶栭敭寮曠敤锛氱疆绌?storyArcs 鐨?startChapterId / endChapterId
    await (_db.update(_db.storyArcs)..where((t) => t.startChapterId.equals(id)))
        .write(const StoryArcsCompanion(startChapterId: Value(null)));
    await (_db.update(_db.storyArcs)..where((t) => t.endChapterId.equals(id)))
        .write(const StoryArcsCompanion(endChapterId: Value(null)));

    // 娓呯悊澶栭敭寮曠敤锛氱疆绌?foreshadows 鐨?plantChapterId / payoffChapterId
    await (_db.update(_db.foreshadows)..where((t) => t.plantChapterId.equals(id)))
        .write(const ForeshadowsCompanion(plantChapterId: Value(null)));
    await (_db.update(_db.foreshadows)..where((t) => t.payoffChapterId.equals(id)))
        .write(const ForeshadowsCompanion(payoffChapterId: Value(null)));

    await (_db.delete(_db.chapters)..where((t) => t.id.equals(id))).go();
    if (workId != null) {
      await _syncWorkWordCount(workId);
    }
  }

  /// 灏嗙珷鑺傛墍灞炰綔鍝佺殑 currentWords 鍚屾涓烘墍鏈夌珷鑺傚瓧鏁颁箣鍜?
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

  /// 鑾峰彇鐩搁偦绔犺妭
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

