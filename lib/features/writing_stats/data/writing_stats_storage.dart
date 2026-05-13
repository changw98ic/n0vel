import 'writing_stats_storage_io.dart'
    if (dart.library.io) 'writing_stats_storage_io.dart';

/// 写作统计存储的抽象接口。
abstract class WritingStatsStorage {
  /// 查询指定项目在日期范围内的日级统计。
  Future<List<Map<String, Object?>>> loadDailyStats({
    required String projectId,
    String? fromDate,
    String? toDate,
  });

  /// 插入或更新一条日级统计（按 date + scene_scope_id 唯一）。
  Future<void> upsertDailyStat(Map<String, Object?> row);

  /// 查询项目级累计统计。
  Future<Map<String, Object?>?> loadProjectStat({required String projectId});

  /// 插入或更新项目级统计。
  Future<void> upsertProjectStat(Map<String, Object?> row);

  /// 查询所有写作目标。
  Future<List<Map<String, Object?>>> loadGoals({String? projectId});

  /// 插入或更新一条写作目标。
  Future<void> upsertGoal(Map<String, Object?> goal);

  /// 删除一条写作目标。
  Future<void> deleteGoal({required String goalId});

  /// 删除指定项目的所有统计数据。
  Future<void> clearProject(String projectId);
}

/// 生产环境工厂。
WritingStatsStorage createDefaultWritingStatsStorage() =>
    SqliteWritingStatsStorage();
