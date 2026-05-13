import 'app_authoring_storage_io_support.dart';
import 'app_sqlite_json_blob_storage.dart';
import 'cached_project_storage.dart';
import 'story_arc_storage.dart';

/// 基于 SQLite 的故事弧线状态持久化
///
/// 使用 story_arc_states 表存储 JSON blob，复用 SqliteJsonBlobStorage。
class SqliteStoryArcStorage implements StoryArcStorage {
  SqliteStoryArcStorage({String? dbPath})
    : _impl = SqliteJsonBlobStorage(
        dbPath: dbPath ?? resolveAuthoringDbPath(),
        tableName: 'story_arc_states',
        jsonColumn: 'state_json',
      );

  final SqliteJsonBlobStorage _impl;

  @override
  Future<Map<String, Object?>?> load({required String projectId}) =>
      _impl.load(projectId: projectId);

  @override
  Future<void> save(Map<String, Object?> data, {required String projectId}) =>
      _impl.save(data, projectId: projectId);

  @override
  Future<void> clear({String? projectId}) => _impl.clear(projectId: projectId);

  @override
  Future<void> clearProject(String projectId) => _impl.clearProject(projectId);
}

class _CachedSqliteStoryArcStorage extends CachedProjectStorage
    implements StoryArcStorage {
  _CachedSqliteStoryArcStorage({String? dbPath})
    : super(SqliteStoryArcStorage(dbPath: dbPath));
}

StoryArcStorage createStoryArcStorage() => _CachedSqliteStoryArcStorage();
