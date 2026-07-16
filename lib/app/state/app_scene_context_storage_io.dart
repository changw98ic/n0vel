import 'app_authoring_storage_io_support.dart';
import 'app_scene_context_storage.dart';
import 'cached_project_storage.dart';
import '../../features/story_generation/data/generation_material_manifest_repository.dart';

class SqliteAppSceneContextStorage implements AppSceneContextStorage {
  SqliteAppSceneContextStorage({String? dbPath})
    : _dbPath = dbPath ?? resolveAuthoringDbPath();

  final String _dbPath;

  @override
  Future<Map<String, Object?>?> load({required String projectId}) async {
    return withAuthoringDb(_dbPath, (database) {
      final rows = database.select(
        '''
        SELECT scene_summary, character_summary, world_summary
        FROM scene_context_snapshots
        WHERE project_id = ?
        LIMIT 1
        ''',
        [projectId],
      );
      if (rows.isEmpty) {
        return null;
      }
      return {
        'sceneSummary': rows.first['scene_summary'] as String,
        'characterSummary': rows.first['character_summary'] as String,
        'worldSummary': rows.first['world_summary'] as String,
      };
    });
  }

  @override
  Future<void> save(Map<String, Object?> data, {required String projectId}) {
    withAuthoringDb(_dbPath, (database) {
      final now = DateTime.now().millisecondsSinceEpoch;
      database.execute('BEGIN IMMEDIATE');
      try {
        database.execute(
          '''
          INSERT INTO scene_context_snapshots (
            project_id, scene_summary, character_summary, world_summary, updated_at_ms
          ) VALUES (?, ?, ?, ?, ?)
          ON CONFLICT(project_id) DO UPDATE SET
            scene_summary = excluded.scene_summary,
            character_summary = excluded.character_summary,
            world_summary = excluded.world_summary,
            updated_at_ms = excluded.updated_at_ms
          ''',
          [
            projectId,
            data['sceneSummary']?.toString() ?? '',
            data['characterSummary']?.toString() ?? '',
            data['worldSummary']?.toString() ?? '',
            now,
          ],
        );
        GenerationMaterialManifestRepository(
          db: database,
        ).replaceCanonicalSource(
          projectId: projectId,
          sceneId: '*',
          sourceKind: 'sceneContext',
          sourceId: projectId,
          canonicalContent: data,
          updatedAtMs: now,
        );
        database.execute('COMMIT');
      } catch (_) {
        if (!database.autocommit) database.execute('ROLLBACK');
        rethrow;
      }
    });
    return Future.value();
  }

  @override
  Future<void> clear({String? projectId}) {
    withAuthoringDb(_dbPath, (database) {
      clearByProject(database, 'scene_context_snapshots', projectId: projectId);
    });
    return Future.value();
  }

  @override
  Future<void> clearProject(String projectId) {
    withAuthoringDb(_dbPath, (database) {
      database.execute('BEGIN IMMEDIATE');
      try {
        clearByProjectScope(database, 'scene_context_snapshots', projectId);
        database.execute(
          '''DELETE FROM story_generation_material_sources
             WHERE project_id = ? AND source_kind = 'sceneContext' ''',
          [projectId],
        );
        database.execute('COMMIT');
      } catch (_) {
        if (!database.autocommit) database.execute('ROLLBACK');
        rethrow;
      }
    });
    return Future.value();
  }
}

class _CachedSqliteAppSceneContextStorage extends CachedProjectStorage
    implements AppSceneContextStorage {
  _CachedSqliteAppSceneContextStorage({String? dbPath})
    : super(SqliteAppSceneContextStorage(dbPath: dbPath));
}

AppSceneContextStorage createAppSceneContextStorage() =>
    _CachedSqliteAppSceneContextStorage();
