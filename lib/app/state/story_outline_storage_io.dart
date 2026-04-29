import 'app_authoring_storage_io_support.dart';
import 'app_sqlite_json_blob_storage.dart';
import 'cached_project_storage.dart';
import 'story_outline_storage.dart';

class SqliteStoryOutlineStorage implements StoryOutlineStorage {
  SqliteStoryOutlineStorage({String? dbPath})
      : _impl = SqliteJsonBlobStorage(
          dbPath: dbPath ?? resolveAuthoringDbPath(),
          tableName: 'story_outline_snapshots',
          jsonColumn: 'snapshot_json',
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
}

class _CachedSqliteStoryOutlineStorage extends CachedProjectStorage
    implements StoryOutlineStorage {
  _CachedSqliteStoryOutlineStorage({String? dbPath})
      : super(SqliteStoryOutlineStorage(dbPath: dbPath));
}

StoryOutlineStorage createStoryOutlineStorage() =>
    _CachedSqliteStoryOutlineStorage();
