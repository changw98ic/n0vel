import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';

import 'fulltext_search_storage.dart';

/// 全文搜索配置。
class FulltextSearchConfig {
  const FulltextSearchConfig({
    this.defaultPageSize = 20,
    this.maxPageSize = 100,
    this.rebuildOnSync = true,
  });

  final int defaultPageSize;
  final int maxPageSize;

  /// syncProject 后是否自动全量重建索引。
  final bool rebuildOnSync;
}

/// 全文搜索服务。
///
/// 封装 FulltextSearchStorage，提供面向业务层的搜索接口，
/// 包括增量索引、异步更新、失败重试等能力。
class FulltextSearchService {
  FulltextSearchService({
    required Database db,
    FulltextSearchConfig config = const FulltextSearchConfig(),
  }) : _storage = FulltextSearchStorage(db: db),
       _config = config;

  final FulltextSearchStorage _storage;
  final FulltextSearchConfig _config;

  /// 异步索引重试队列。
  final List<_PendingIndexTask> _retryQueue = [];

  /// 搜索结果（带分页）。
  Future<FulltextSearchResultSet> search({
    required String projectId,
    required String query,
    String? characterFilter,
    int? chapterRangeStart,
    int? chapterRangeEnd,
    int page = 0,
    int? pageSize,
    FulltextSortOrder sortOrder = FulltextSortOrder.relevance,
  }) async {
    final effectivePageSize = (pageSize ?? _config.defaultPageSize).clamp(
      1,
      _config.maxPageSize,
    );
    final offset = page * effectivePageSize;

    final result = await _storage.search(
      projectId: projectId,
      query: query,
      characterFilter: characterFilter,
      chapterRangeStart: chapterRangeStart,
      chapterRangeEnd: chapterRangeEnd,
      offset: offset,
      limit: effectivePageSize,
    );

    // 按指定排序方式重新排列
    final sorted = _applySort(result.rows, sortOrder);

    return FulltextSearchResultSet(
      rows: sorted,
      totalCount: result.totalCount,
      page: page,
      pageSize: effectivePageSize,
    );
  }

  /// 增量索引：写入一条场景内容后调用。
  ///
  /// 失败时加入重试队列，最多重试 3 次。
  Future<void> indexScene(FulltextIndexEntry entry) async {
    try {
      await _storage.indexScene(entry);
    } on Object catch (e) {
      debugPrint('[FulltextSearch] 索引失败，加入重试队列: $e');
      _retryQueue.add(_PendingIndexTask(entry: entry, attempts: 1));
      _scheduleRetry();
    }
  }

  /// 批量索引（用于全量同步）。
  Future<void> indexScenes(List<FulltextIndexEntry> entries) async {
    for (final entry in entries) {
      await indexScene(entry);
    }
  }

  /// 全量同步某个项目：清空旧索引后重新写入。
  Future<void> syncProject({
    required String projectId,
    required List<FulltextIndexEntry> entries,
  }) async {
    await _storage.clearProject(projectId);
    await _storage.indexScenes(entries);
  }

  /// 删除某个场景的索引。
  Future<void> removeScene(String projectId, String sceneId) async {
    await _storage.removeScene(projectId, sceneId);
  }

  /// 获取已索引的章节范围。
  Future<(int, int)?> indexedChapterRange(String projectId) {
    return _storage.indexedChapterRange(projectId);
  }

  /// 获取已索引的角色名列表。
  Future<List<String>> indexedCharacterNames(String projectId) {
    return _storage.indexedCharacterNames(projectId);
  }

  /// 应用排序策略。
  List<FulltextResultRow> _applySort(
    List<FulltextResultRow> rows,
    FulltextSortOrder order,
  ) {
    switch (order) {
      case FulltextSortOrder.relevance:
        // 已按 BM25 排序，无需调整
        return rows;
      case FulltextSortOrder.chapterAsc:
        return rows..sort((a, b) {
          final cmp = a.chapterIndex.compareTo(b.chapterIndex);
          return cmp != 0 ? cmp : b.score.compareTo(a.score);
        });
      case FulltextSortOrder.chapterDesc:
        return rows..sort((a, b) {
          final cmp = b.chapterIndex.compareTo(a.chapterIndex);
          return cmp != 0 ? cmp : b.score.compareTo(a.score);
        });
    }
  }

  /// 调度异步重试。
  void _scheduleRetry() {
    Future.delayed(const Duration(seconds: 2), _processRetryQueue);
  }

  /// 处理重试队列。
  Future<void> _processRetryQueue() async {
    if (_retryQueue.isEmpty) return;

    final pending = List<_PendingIndexTask>.from(_retryQueue);
    _retryQueue.clear();

    for (final task in pending) {
      try {
        await _storage.indexScene(task.entry);
      } on Object catch (e) {
        if (task.attempts < 3) {
          debugPrint('[FulltextSearch] 重试失败 (${task.attempts}/3): $e');
          _retryQueue.add(task.increment());
        } else {
          debugPrint('[FulltextSearch] 索引最终失败，已放弃: ${task.entry.sceneId}');
        }
      }
    }

    if (_retryQueue.isNotEmpty) {
      _scheduleRetry();
    }
  }
}

/// 排序策略。
enum FulltextSortOrder {
  /// 按相关度（BM25 分数）降序
  relevance,

  /// 按章节号升序
  chapterAsc,

  /// 按章节号降序
  chapterDesc,
}

/// 待重试的索引任务。
class _PendingIndexTask {
  const _PendingIndexTask({required this.entry, required this.attempts});

  final FulltextIndexEntry entry;
  final int attempts;

  _PendingIndexTask increment() =>
      _PendingIndexTask(entry: entry, attempts: attempts + 1);
}
