import 'dart:async';

import 'package:sqlite3/sqlite3.dart';

/// 单条全文搜索索引条目，对应一个场景的文本内容。
class FulltextIndexEntry {
  const FulltextIndexEntry({
    required this.projectId,
    required this.chapterIndex,
    required this.chapterTitle,
    required this.sceneId,
    required this.sceneTitle,
    required this.characterNames,
    required this.content,
  });

  final String projectId;
  final int chapterIndex;
  final String chapterTitle;
  final String sceneId;
  final String sceneTitle;
  final String characterNames;
  final String content;
}

/// 全文搜索结果行。
class FulltextResultRow {
  const FulltextResultRow({
    required this.projectId,
    required this.chapterIndex,
    required this.chapterTitle,
    required this.sceneId,
    required this.sceneTitle,
    required this.characterNames,
    required this.snippet,
    required this.score,
  });

  final String projectId;
  final int chapterIndex;
  final String chapterTitle;
  final String sceneId;
  final String sceneTitle;
  final String characterNames;
  final String snippet;
  final double score;
}

/// 全文搜索分页结果集。
class FulltextSearchResultSet {
  const FulltextSearchResultSet({
    required this.rows,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  final List<FulltextResultRow> rows;
  final int totalCount;
  final int page;
  final int pageSize;

  int get totalPages => pageSize > 0 ? (totalCount / pageSize).ceil() : 0;
  bool get hasNextPage => page < totalPages - 1;
  bool get hasPreviousPage => page > 0;
}

/// 同步创建全文搜索表（供 migration 调用）。
void createFulltextSearchTables(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS fulltext_chapter_contents (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      chapter_index INTEGER NOT NULL,
      chapter_title TEXT NOT NULL,
      scene_id TEXT NOT NULL,
      scene_title TEXT NOT NULL,
      character_names TEXT NOT NULL DEFAULT '',
      content TEXT NOT NULL
    )
  ''');

  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_ftcontents_project
    ON fulltext_chapter_contents (project_id)
  ''');

  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_ftcontents_chapter
    ON fulltext_chapter_contents (project_id, chapter_index)
  ''');

  db.execute('''
    CREATE VIRTUAL TABLE IF NOT EXISTS fulltext_chapters USING fts5(
      chapter_title, scene_title, character_names, content,
      content='fulltext_chapter_contents',
      content_rowid='rowid'
    )
  ''');

  _ensureFtsTriggersSync(db);
}

/// 同步创建 FTS5 触发器（供 migration 调用）。
void _ensureFtsTriggersSync(Database db) {
  db.execute('''
    CREATE TRIGGER IF NOT EXISTS ftcontents_ai
    AFTER INSERT ON fulltext_chapter_contents BEGIN
      INSERT INTO fulltext_chapters(rowid, chapter_title, scene_title, character_names, content)
      VALUES (new.rowid, new.chapter_title, new.scene_title, new.character_names, new.content);
    END
  ''');
  db.execute('''
    CREATE TRIGGER IF NOT EXISTS ftcontents_ad
    AFTER DELETE ON fulltext_chapter_contents BEGIN
      INSERT INTO fulltext_chapters(fulltext_chapters, rowid, chapter_title, scene_title, character_names, content)
      VALUES('delete', old.rowid, old.chapter_title, old.scene_title, old.character_names, old.content);
    END
  ''');
  db.execute('''
    CREATE TRIGGER IF NOT EXISTS ftcontents_au
    AFTER UPDATE ON fulltext_chapter_contents BEGIN
      INSERT INTO fulltext_chapters(fulltext_chapters, rowid, chapter_title, scene_title, character_names, content)
      VALUES('delete', old.rowid, old.chapter_title, old.scene_title, old.character_names, old.content);
      INSERT INTO fulltext_chapters(rowid, chapter_title, scene_title, character_names, content)
      VALUES (new.rowid, new.chapter_title, new.scene_title, new.character_names, new.content);
    END
  ''');
}

/// SQLite FTS5 全文搜索存储层。
///
/// 管理 `fulltext_chapter_contents` 内容表和 `fulltext_chapters` FTS5 虚拟表。
/// 通过触发器自动同步索引，支持增量更新。
class FulltextSearchStorage {
  FulltextSearchStorage({required this.db});

  final Database db;
  bool _migrated = false;

  /// 确保全文搜索表和索引已创建。
  Future<void> ensureTables() async {
    if (_migrated) return;

    createFulltextSearchTables(db);
    // 首次创建时重建索引（防漏）
    db.execute("INSERT INTO fulltext_chapters(fulltext_chapters) VALUES('rebuild')");

    _migrated = true;
  }

  /// 索引一条场景内容。按 (project_id, scene_id) 唯一，存在则更新。
  Future<void> indexScene(FulltextIndexEntry entry) async {
    await ensureTables();
    final id = '${entry.projectId}_scene_${entry.sceneId}';

    final existing = db.select(
      'SELECT rowid FROM fulltext_chapter_contents WHERE id = ?',
      [id],
    );

    if (existing.isNotEmpty) {
      db.execute(
        '''UPDATE fulltext_chapter_contents
           SET project_id = ?, chapter_index = ?, chapter_title = ?,
               scene_id = ?, scene_title = ?, character_names = ?, content = ?
           WHERE id = ?''',
        [
          entry.projectId,
          entry.chapterIndex,
          entry.chapterTitle,
          entry.sceneId,
          entry.sceneTitle,
          entry.characterNames,
          entry.content,
          id,
        ],
      );
    } else {
      db.execute(
        '''INSERT INTO fulltext_chapter_contents
           (id, project_id, chapter_index, chapter_title,
            scene_id, scene_title, character_names, content)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          id,
          entry.projectId,
          entry.chapterIndex,
          entry.chapterTitle,
          entry.sceneId,
          entry.sceneTitle,
          entry.characterNames,
          entry.content,
        ],
      );
    }
  }

  /// 批量索引多条场景内容（事务内执行，性能更优）。
  Future<void> indexScenes(List<FulltextIndexEntry> entries) async {
    if (entries.isEmpty) return;
    await ensureTables();
    for (final entry in entries) {
      await indexScene(entry);
    }
  }

  /// 删除某个项目的全部索引。
  Future<void> clearProject(String projectId) async {
    await ensureTables();
    db.execute(
      'DELETE FROM fulltext_chapter_contents WHERE project_id = ?',
      [projectId],
    );
  }

  /// 删除某个场景的索引。
  Future<void> removeScene(String projectId, String sceneId) async {
    await ensureTables();
    final id = '${projectId}_scene_$sceneId';
    db.execute(
      'DELETE FROM fulltext_chapter_contents WHERE id = ?',
      [id],
    );
  }

  /// 全文搜索（BM25 排序）。
  ///
  /// [characterFilter] 按角色名过滤（LIKE 匹配）。
  /// [chapterRange] 限定章节范围 [start, end]（闭区间）。
  /// [offset] / [limit] 分页。
  Future<FulltextSearchResultSet> search({
    required String projectId,
    required String query,
    String? characterFilter,
    int? chapterRangeStart,
    int? chapterRangeEnd,
    int offset = 0,
    int limit = 20,
  }) async {
    await ensureTables();

    final matchExpr = _buildMatchExpression(query);
    if (matchExpr.isEmpty) {
      return FulltextSearchResultSet(
        rows: const [],
        totalCount: 0,
        page: offset ~/ limit,
        pageSize: limit,
      );
    }

    // 构建 WHERE 子句
    final whereClauses = <String>['fc.project_id = ?'];
    final params = <Object?>[matchExpr, projectId];

    if (characterFilter != null && characterFilter.isNotEmpty) {
      whereClauses.add('fc.character_names LIKE ?');
      params.add('%$characterFilter%');
    }
    if (chapterRangeStart != null) {
      whereClauses.add('fc.chapter_index >= ?');
      params.add(chapterRangeStart);
    }
    if (chapterRangeEnd != null) {
      whereClauses.add('fc.chapter_index <= ?');
      params.add(chapterRangeEnd);
    }

    final whereSql = whereClauses.join(' AND ');

    // 查询总数
    final countRow = db.select('''
      SELECT COUNT(*) AS cnt
      FROM fulltext_chapters AS fts
      JOIN fulltext_chapter_contents AS fc ON fts.rowid = fc.rowid
      WHERE fts.fulltext_chapters MATCH ? AND $whereSql
    ''', params);
    final totalCount = countRow.first['cnt'] as int;

    // 分页查询，使用 snippet() 生成高亮摘要
    final queryParams = <Object?>[...params, limit, offset];
    final rows = db.select('''
      SELECT
        fc.project_id,
        fc.chapter_index,
        fc.chapter_title,
        fc.scene_id,
        fc.scene_title,
        fc.character_names,
        snippet(fulltext_chapters, 3, '<mark>', '</mark>', '...', 32) AS snip,
        fts.rank
      FROM fulltext_chapters AS fts
      JOIN fulltext_chapter_contents AS fc ON fts.rowid = fc.rowid
      WHERE fts.fulltext_chapters MATCH ? AND $whereSql
      ORDER BY fts.rank
      LIMIT ? OFFSET ?
    ''', queryParams);

    final results = <FulltextResultRow>[
      for (final row in rows)
        FulltextResultRow(
          projectId: row['project_id'] as String,
          chapterIndex: row['chapter_index'] as int,
          chapterTitle: row['chapter_title'] as String,
          sceneId: row['scene_id'] as String,
          sceneTitle: row['scene_title'] as String,
          characterNames: row['character_names'] as String,
          snippet: row['snip'] as String? ?? '',
          score: _bm25ToScore(row['rank'] as double),
        ),
    ];

    // CJK 回退：如果 FTS5 结果不足，用 LIKE 补充
    var effectiveTotalCount = totalCount;
    if (_containsCjk(query) && results.length < limit) {
      final cjkResults = _searchCjkFallback(
        projectId: projectId,
        query: query,
        characterFilter: characterFilter,
        chapterRangeStart: chapterRangeStart,
        chapterRangeEnd: chapterRangeEnd,
        limit: limit,
        existingIds: {for (final r in results) r.sceneId},
      );
      results.addAll(cjkResults);
      // CJK 回退时，用 FTS + LIKE 的并集作为总数
      if (cjkResults.isNotEmpty) {
        effectiveTotalCount = _countCjkFallback(
          projectId: projectId,
          query: query,
          characterFilter: characterFilter,
          chapterRangeStart: chapterRangeStart,
          chapterRangeEnd: chapterRangeEnd,
        );
      }
    }

    return FulltextSearchResultSet(
      rows: results,
      totalCount: effectiveTotalCount,
      page: offset ~/ limit,
      pageSize: limit,
    );
  }

  /// 返回项目中已索引的章节范围 [min, max]，若无数据返回 null。
  Future<(int, int)?> indexedChapterRange(String projectId) async {
    await ensureTables();
    final rows = db.select('''
      SELECT MIN(chapter_index) AS min_ch, MAX(chapter_index) AS max_ch
      FROM fulltext_chapter_contents
      WHERE project_id = ?
    ''', [projectId]);
    if (rows.isEmpty) return null;
    final minCh = rows.first['min_ch'] as int?;
    final maxCh = rows.first['max_ch'] as int?;
    if (minCh == null || maxCh == null) return null;
    return (minCh, maxCh);
  }

  /// 返回项目中已索引的不同角色名列表。
  Future<List<String>> indexedCharacterNames(String projectId) async {
    await ensureTables();
    final rows = db.select('''
      SELECT DISTINCT character_names
      FROM fulltext_chapter_contents
      WHERE project_id = ? AND character_names != ''
    ''', [projectId]);

    final names = <String>{};
    for (final row in rows) {
      for (final name in (row['character_names'] as String).split(',')) {
        final trimmed = name.trim();
        if (trimmed.isNotEmpty) names.add(trimmed);
      }
    }
    return names.toList()..sort();
  }

  // ── 内部方法 ──────────────────────────────────────────────────────────────

  /// BM25 rank（负值）转 0-1 分数。
  double _bm25ToScore(double rank) {
    if (rank >= 0) return 0.0;
    return (1.0 / (1.0 - rank)).clamp(0.0, 1.0);
  }

  /// 构建 FTS5 MATCH 表达式。CJK 字符逐字拆分 + AND 连接。
  String _buildMatchExpression(String query) {
    final terms = RegExp(r'[\p{L}\p{N}_-]+', unicode: true)
        .allMatches(query)
        .map((m) => m.group(0)!.trim())
        .where((t) => t.isNotEmpty)
        .take(16)
        .toList();
    if (terms.isEmpty) return '';
    return terms.map(_expandTermForFts).join(' OR ');
  }

  /// 将单个 term 展开为 FTS5 表达式。CJK 字符拆为逐字 AND。
  String _expandTermForFts(String term) {
    final cjkChars = <String>[];
    final nonCjk = StringBuffer();
    for (final rune in term.runes) {
      if (_isCjk(rune)) {
        cjkChars.add(String.fromCharCode(rune));
      } else {
        nonCjk.writeCharCode(rune);
      }
    }

    final parts = <String>[];
    if (nonCjk.isNotEmpty) {
      parts.add('"${nonCjk.toString().replaceAll('"', '""')}"');
    }
    for (final ch in cjkChars) {
      parts.add('"$ch"');
    }

    if (parts.length == 1) return parts.first;
    return '(${parts.join(' AND ')})';
  }

  /// CJK LIKE 回退搜索。
  List<FulltextResultRow> _searchCjkFallback({
    required String projectId,
    required String query,
    String? characterFilter,
    int? chapterRangeStart,
    int? chapterRangeEnd,
    required int limit,
    required Set<String> existingIds,
  }) {
    final needles = _buildCjkNeedles(query);
    if (needles.isEmpty) return const [];

    final whereClauses = <String>['fc.project_id = ?'];
    final params = <Object?>[projectId];

    if (characterFilter != null && characterFilter.isNotEmpty) {
      whereClauses.add('fc.character_names LIKE ?');
      params.add('%$characterFilter%');
    }
    if (chapterRangeStart != null) {
      whereClauses.add('fc.chapter_index >= ?');
      params.add(chapterRangeStart);
    }
    if (chapterRangeEnd != null) {
      whereClauses.add('fc.chapter_index <= ?');
      params.add(chapterRangeEnd);
    }

    final likeClauses = needles
        .map((_) => '(fc.content LIKE ? OR fc.scene_title LIKE ?)')
        .join(' OR ');
    for (final needle in needles) {
      params.addAll(['%$needle%', '%$needle%']);
    }
    params.add(limit * 2);

    final rows = db.select('''
      SELECT fc.project_id, fc.chapter_index, fc.chapter_title,
             fc.scene_id, fc.scene_title, fc.character_names, fc.content
      FROM fulltext_chapter_contents AS fc
      WHERE ${whereClauses.join(' AND ')} AND ($likeClauses)
      LIMIT ?
    ''', params);

    final results = <FulltextResultRow>[];
    for (final row in rows) {
      final sceneId = row['scene_id'] as String;
      if (existingIds.contains(sceneId)) continue;
      if (results.length >= limit) break;

      final content = row['content'] as String;
      results.add(FulltextResultRow(
        projectId: row['project_id'] as String,
        chapterIndex: row['chapter_index'] as int,
        chapterTitle: row['chapter_title'] as String,
        sceneId: sceneId,
        sceneTitle: row['scene_title'] as String,
        characterNames: row['character_names'] as String,
        snippet: _buildCjkSnippet(content, needles),
        score: _scoreCjk(content, needles),
      ));
    }
    return results;
  }

  /// CJK 回退计数。
  int _countCjkFallback({
    required String projectId,
    required String query,
    String? characterFilter,
    int? chapterRangeStart,
    int? chapterRangeEnd,
  }) {
    final needles = _buildCjkNeedles(query);
    if (needles.isEmpty) return 0;

    final whereClauses = <String>['fc.project_id = ?'];
    final params = <Object?>[projectId];

    if (characterFilter != null && characterFilter.isNotEmpty) {
      whereClauses.add('fc.character_names LIKE ?');
      params.add('%$characterFilter%');
    }
    if (chapterRangeStart != null) {
      whereClauses.add('fc.chapter_index >= ?');
      params.add(chapterRangeStart);
    }
    if (chapterRangeEnd != null) {
      whereClauses.add('fc.chapter_index <= ?');
      params.add(chapterRangeEnd);
    }

    final likeClauses = needles
        .map((_) => '(fc.content LIKE ? OR fc.scene_title LIKE ?)')
        .join(' OR ');
    for (final needle in needles) {
      params.addAll(['%$needle%', '%$needle%']);
    }

    final rows = db.select('''
      SELECT COUNT(*) AS cnt
      FROM fulltext_chapter_contents AS fc
      WHERE ${whereClauses.join(' AND ')} AND ($likeClauses)
    ''', params);

    return rows.first['cnt'] as int;
  }

  /// 构建 CJK 搜索用的 needle 列表（bigram 拆分）。
  List<String> _buildCjkNeedles(String query) {
    final needles = <String>{};
    final runes = query.runes.toList();
    for (var i = 0; i < runes.length; i++) {
      if (!_isCjk(runes[i])) continue;
      final start = i;
      while (i + 1 < runes.length && _isCjk(runes[i + 1])) {
        i++;
      }
      final cjkRun = String.fromCharCodes(runes.sublist(start, i + 1));
      if (cjkRun.runes.length <= 2) {
        needles.add(cjkRun);
      } else {
        final cjkRunes = cjkRun.runes.toList();
        for (var j = 0; j < cjkRunes.length - 1; j++) {
          needles.add(String.fromCharCodes(cjkRunes.sublist(j, j + 2)));
        }
      }
    }
    return needles.take(16).toList();
  }

  /// 为 CJK 回退结果生成带高标的摘要。
  String _buildCjkSnippet(String content, List<String> needles) {
    if (needles.isEmpty || content.isEmpty) return content;
    // 找到第一个 needle 出现的位置，截取周围文本
    for (final needle in needles) {
      final idx = content.indexOf(needle);
      if (idx >= 0) {
        final start = (idx - 40).clamp(0, content.length);
        final end = (idx + needle.length + 80).clamp(0, content.length);
        var snippet = content.substring(start, end);
        // 高亮所有 needle
        for (final n in needles) {
          snippet = snippet.replaceAll(n, '<mark>$n</mark>');
        }
        final prefix = start > 0 ? '...' : '';
        final suffix = end < content.length ? '...' : '';
        return '$prefix$snippet$suffix';
      }
    }
    // 没找到位置，返回前 120 字符
    final truncated = content.length > 120
        ? '${content.substring(0, 117)}...'
        : content;
    return truncated;
  }

  /// CJK 回退评分。
  double _scoreCjk(String content, List<String> needles) {
    var matched = 0.0;
    var total = 0.0;
    for (final needle in needles) {
      final weight = needle.runes.length > 1 ? 2.0 : 0.5;
      total += weight;
      if (content.contains(needle)) matched += weight;
    }
    if (matched == 0 || total == 0) return 0.0;
    return (0.35 + (matched / total) * 0.65).clamp(0.0, 1.0);
  }

  static bool _isCjk(int codeUnit) {
    return (codeUnit >= 0x4E00 && codeUnit <= 0x9FFF) ||
        (codeUnit >= 0x3400 && codeUnit <= 0x4DBF) ||
        (codeUnit >= 0x3040 && codeUnit <= 0x309F) ||
        (codeUnit >= 0x30A0 && codeUnit <= 0x30FF) ||
        (codeUnit >= 0xAC00 && codeUnit <= 0xD7AF);
  }

  static bool _containsCjk(String value) {
    return value.runes.any(_isCjk);
  }

}
