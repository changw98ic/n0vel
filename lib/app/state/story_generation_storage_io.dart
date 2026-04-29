import 'app_authoring_storage_io_support.dart';
import 'app_sqlite_json_blob_storage.dart';
import 'cached_project_storage.dart';
import 'story_generation_storage.dart';

class SqliteStoryGenerationStorage implements StoryGenerationStorage {
  SqliteStoryGenerationStorage({String? dbPath})
      : _impl = SqliteJsonBlobStorage(
          dbPath: dbPath ?? resolveAuthoringDbPath(),
          tableName: 'story_generation_state',
          jsonColumn: 'payload_json',
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

class _CachedSqliteStoryGenerationStorage extends CachedProjectStorage
    implements StoryGenerationStorage {
  _CachedSqliteStoryGenerationStorage({String? dbPath})
      : super(SqliteStoryGenerationStorage(dbPath: dbPath));
}

StoryGenerationStorage createStoryGenerationStorage() =>
    _CachedSqliteStoryGenerationStorage();
