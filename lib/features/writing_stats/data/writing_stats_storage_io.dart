import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:novel_writer/app/state/app_authoring_storage_io_support.dart';
import 'writing_stats_storage.dart';

/// SQLite 实现的写作统计存储。
///
/// 每次操作独立打开/关闭数据库连接，与项目其他 IO 存储保持一致。
class SqliteWritingStatsStorage implements WritingStatsStorage {
  SqliteWritingStatsStorage({String? dbPath})
    : _dbPath = dbPath ?? resolveAuthoringDbPath();

  final String _dbPath;

  @override
  Future<List<Map<String, Object?>>> loadDailyStats({
    required String projectId,
    String? fromDate,
    String? toDate,
  }) async {
    final db = _open();
    try {
      final params = <Object?>[projectId];
      final where = StringBuffer('project_id = ?');
      if (fromDate != null) {
        where.write(' AND stat_date >= ?');
        params.add(fromDate);
      }
      if (toDate != null) {
        where.write(' AND stat_date <= ?');
        params.add(toDate);
      }
      final rows = db.select(
        'SELECT stat_date, scene_scope_id, project_id, char_count, '
        'delta_chars, chapters_completed, goal_reached, updated_at_ms '
        'FROM writing_daily_stats WHERE $where ORDER BY stat_date ASC',
        params,
      );
      return [
        for (final row in rows)
          {
            'date': row['stat_date'],
            'sceneScopeId': row['scene_scope_id'],
            'projectId': row['project_id'],
            'charCount': row['char_count'],
            'deltaChars': row['delta_chars'],
            'chaptersCompleted': row['chapters_completed'],
            'goalReached': row['goal_reached'],
            'updatedAtMs': row['updated_at_ms'],
          },
      ];
    } finally {
      db.dispose();
    }
  }

  @override
  Future<void> upsertDailyStat(Map<String, Object?> row) async {
    final db = _open();
    try {
      db.execute(
        '''
        INSERT INTO writing_daily_stats (
          stat_date, scene_scope_id, project_id, char_count,
          delta_chars, chapters_completed, goal_reached, updated_at_ms
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(stat_date, scene_scope_id) DO UPDATE SET
          char_count = excluded.char_count,
          delta_chars = excluded.delta_chars,
          chapters_completed = excluded.chapters_completed,
          goal_reached = excluded.goal_reached,
          updated_at_ms = excluded.updated_at_ms
        ''',
        [
          row['date'],
          row['sceneScopeId'],
          row['projectId'],
          row['charCount'],
          row['deltaChars'],
          row['chaptersCompleted'],
          row['goalReached'],
          row['updatedAtMs'],
        ],
      );
    } finally {
      db.dispose();
    }
  }

  @override
  Future<Map<String, Object?>?> loadProjectStat({
    required String projectId,
  }) async {
    final db = _open();
    try {
      final rows = db.select(
        'SELECT project_id, total_char_count, total_delta_chars, '
        'total_chapters, total_sessions, first_write_at_ms, '
        'last_write_at_ms, best_day_chars, best_day_date '
        'FROM writing_project_stats WHERE project_id = ?',
        [projectId],
      );
      if (rows.isEmpty) return null;
      final row = rows.first;
      return {
        'projectId': row['project_id'],
        'totalCharCount': row['total_char_count'],
        'totalDeltaChars': row['total_delta_chars'],
        'totalChapters': row['total_chapters'],
        'totalSessions': row['total_sessions'],
        'firstWriteAtMs': row['first_write_at_ms'],
        'lastWriteAtMs': row['last_write_at_ms'],
        'bestDayChars': row['best_day_chars'],
        'bestDayDate': row['best_day_date'],
      };
    } finally {
      db.dispose();
    }
  }

  @override
  Future<void> upsertProjectStat(Map<String, Object?> row) async {
    final db = _open();
    try {
      db.execute(
        '''
        INSERT INTO writing_project_stats (
          project_id, total_char_count, total_delta_chars,
          total_chapters, total_sessions, first_write_at_ms,
          last_write_at_ms, best_day_chars, best_day_date
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(project_id) DO UPDATE SET
          total_char_count = excluded.total_char_count,
          total_delta_chars = excluded.total_delta_chars,
          total_chapters = excluded.total_chapters,
          total_sessions = excluded.total_sessions,
          first_write_at_ms = excluded.first_write_at_ms,
          last_write_at_ms = excluded.last_write_at_ms,
          best_day_chars = excluded.best_day_chars,
          best_day_date = excluded.best_day_date
        ''',
        [
          row['projectId'],
          row['totalCharCount'],
          row['totalDeltaChars'],
          row['totalChapters'],
          row['totalSessions'],
          row['firstWriteAtMs'],
          row['lastWriteAtMs'],
          row['bestDayChars'],
          row['bestDayDate'],
        ],
      );
    } finally {
      db.dispose();
    }
  }

  @override
  Future<List<Map<String, Object?>>> loadGoals({String? projectId}) async {
    final db = _open();
    try {
      final String sql;
      final List<Object?> params;
      if (projectId != null && projectId.isNotEmpty) {
        sql =
            'SELECT id, project_id, goal_type, target_value, period, '
            'enabled, created_at_ms FROM writing_goals '
            'WHERE project_id = ? OR project_id = \'\' ORDER BY created_at_ms';
        params = [projectId];
      } else {
        sql =
            'SELECT id, project_id, goal_type, target_value, period, '
            'enabled, created_at_ms FROM writing_goals ORDER BY created_at_ms';
        params = [];
      }
      final rows = db.select(sql, params);
      return [
        for (final row in rows)
          {
            'id': row['id'],
            'projectId': row['project_id'],
            'goalType': row['goal_type'],
            'targetValue': row['target_value'],
            'period': row['period'],
            'enabled': row['enabled'],
            'createdAtMs': row['created_at_ms'],
          },
      ];
    } finally {
      db.dispose();
    }
  }

  @override
  Future<void> upsertGoal(Map<String, Object?> goal) async {
    final db = _open();
    try {
      db.execute(
        '''
        INSERT INTO writing_goals (
          id, project_id, goal_type, target_value, period, enabled, created_at_ms
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          project_id = excluded.project_id,
          goal_type = excluded.goal_type,
          target_value = excluded.target_value,
          period = excluded.period,
          enabled = excluded.enabled
        ''',
        [
          goal['id'],
          goal['projectId'],
          goal['goalType'],
          goal['targetValue'],
          goal['period'],
          goal['enabled'],
          goal['createdAtMs'],
        ],
      );
    } finally {
      db.dispose();
    }
  }

  @override
  Future<void> deleteGoal({required String goalId}) async {
    final db = _open();
    try {
      db.execute('DELETE FROM writing_goals WHERE id = ?', [goalId]);
    } finally {
      db.dispose();
    }
  }

  @override
  Future<void> clearProject(String projectId) async {
    final db = _open();
    try {
      runInTransaction(db, () {
        db.execute('DELETE FROM writing_daily_stats WHERE project_id = ?', [
          projectId,
        ]);
        db.execute('DELETE FROM writing_project_stats WHERE project_id = ?', [
          projectId,
        ]);
        db.execute('DELETE FROM writing_goals WHERE project_id = ?', [
          projectId,
        ]);
      });
    } finally {
      db.dispose();
    }
  }

  sqlite3.Database _open() =>
      openAuthoringDatabase(_dbPath, verifyIntegrity: false);
}
