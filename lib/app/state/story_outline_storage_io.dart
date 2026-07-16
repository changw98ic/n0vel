import 'dart:convert';
import 'dart:isolate';

import 'package:sqlite3/sqlite3.dart';

import 'app_authoring_storage_io_support.dart';
import 'app_sqlite_json_blob_storage.dart';
import 'cached_project_storage.dart';
import 'story_outline_storage.dart';
import '../../features/story_generation/data/generation_material_manifest_repository.dart';

class SqliteStoryOutlineStorage implements StoryOutlineStorage {
  SqliteStoryOutlineStorage({
    String? dbPath,
    bool requireExistingSchema = false,
  }) : _requireExistingSchema = requireExistingSchema,
       _dbPath = dbPath ?? resolveAuthoringDbPath(),
       _impl = SqliteJsonBlobStorage(
         dbPath: dbPath ?? resolveAuthoringDbPath(),
         tableName: 'story_outline_snapshots',
         jsonColumn: 'snapshot_json',
         requireExistingSchema: requireExistingSchema,
       );

  final SqliteJsonBlobStorage _impl;
  final String _dbPath;
  final bool _requireExistingSchema;

  @override
  Future<Map<String, Object?>?> load({required String projectId}) =>
      _impl.load(projectId: projectId);

  @override
  Future<void> save(Map<String, Object?> data, {required String projectId}) {
    return Isolate.run(() {
      void write(Database db) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final snapshot = <String, Object?>{
          for (final entry in data.entries) entry.key: entry.value,
          'projectId': data['projectId']?.toString() ?? projectId,
        };
        db.execute('BEGIN IMMEDIATE');
        try {
          db.execute(
            '''
            INSERT INTO story_outline_snapshots (
              project_id, snapshot_json, updated_at_ms
            ) VALUES (?, ?, ?)
            ON CONFLICT(project_id) DO UPDATE SET
              snapshot_json = excluded.snapshot_json,
              updated_at_ms = excluded.updated_at_ms
            ''',
            [projectId, jsonEncode(snapshot), now],
          );
          final journal = GenerationMaterialManifestRepository(db: db);
          journal.deleteSource(
            projectId: projectId,
            sceneId: '*',
            sourceKind: 'outline',
            sourceId: projectId,
          );
          journal.replaceCanonicalSource(
            projectId: projectId,
            sceneId: '*',
            sourceKind: 'outline',
            sourceId: projectId,
            canonicalContent: _outlineMaterialSubset(snapshot),
            updatedAtMs: now,
          );
          db.execute('COMMIT');
        } catch (_) {
          if (!db.autocommit) {
            db.execute('ROLLBACK');
          }
          rethrow;
        }
      }

      _requireExistingSchema
          ? withExistingAuthoringDb(_dbPath, write)
          : withAuthoringDb(_dbPath, write);
    });
  }

  @override
  Future<void> clear({String? projectId}) => _impl.clear(projectId: projectId);

  @override
  Future<void> clearProject(String projectId) => _impl.clearProject(projectId);
}

Object? _outlineMaterialSubset(Object? value) {
  if (value is Map) {
    return {
      for (final entry in value.entries)
        if (const {
          'chapters',
          'scenePlans',
          'executablePlan',
          'scenes',
          'beats',
          'summary',
          'sequence',
          'order',
          'id',
          'title',
          'content',
        }.contains(entry.key.toString()))
          entry.key.toString(): _outlineMaterialSubset(entry.value),
    };
  }
  if (value is List) {
    return [for (final item in value) _outlineMaterialSubset(item)];
  }
  return value;
}

class _CachedSqliteStoryOutlineStorage extends CachedProjectStorage
    implements StoryOutlineStorage {
  _CachedSqliteStoryOutlineStorage({String? dbPath})
    : super(SqliteStoryOutlineStorage(dbPath: dbPath));
}

StoryOutlineStorage createStoryOutlineStorage() =>
    _CachedSqliteStoryOutlineStorage();
