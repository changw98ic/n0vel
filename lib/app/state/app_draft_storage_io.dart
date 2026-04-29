import 'app_authoring_storage_io_support.dart';
import 'app_draft_storage.dart';
import 'cached_project_storage.dart';

class SqliteAppDraftStorage implements AppDraftStorage {
  SqliteAppDraftStorage({String? dbPath})
      : _dbPath = dbPath ?? resolveAuthoringDbPath();

  final String _dbPath;

  @override
  Future<Map<String, Object?>?> load({required String projectId}) async {
    return withAuthoringDb(_dbPath, (database) {
      final rows = database.select(
        '''
        SELECT text_body
        FROM draft_documents
        WHERE project_id = ?
        LIMIT 1
        ''',
        [projectId],
      );
      if (rows.isEmpty) {
        return null;
      }
      return {'text': rows.first['text_body'] as String};
    });
  }

  @override
  Future<void> save(Map<String, Object?> data, {required String projectId}) {
    withAuthoringDb(_dbPath, (database) {
      database.execute(
        '''
        INSERT INTO draft_documents (project_id, text_body, updated_at_ms)
        VALUES (?, ?, ?)
        ON CONFLICT(project_id) DO UPDATE SET
          text_body = excluded.text_body,
          updated_at_ms = excluded.updated_at_ms
        ''',
        [
          projectId,
          data['text']?.toString() ?? '',
          DateTime.now().millisecondsSinceEpoch,
        ],
      );
    });
    return Future.value();
  }

  @override
  Future<void> clear({String? projectId}) {
    withAuthoringDb(_dbPath, (database) {
      clearByProject(database, 'draft_documents', projectId: projectId);
    });
    return Future.value();
  }
}

class _CachedSqliteAppDraftStorage extends CachedProjectStorage
    implements AppDraftStorage {
  _CachedSqliteAppDraftStorage({String? dbPath})
      : super(SqliteAppDraftStorage(dbPath: dbPath));
}

AppDraftStorage createAppDraftStorage() => _CachedSqliteAppDraftStorage();
