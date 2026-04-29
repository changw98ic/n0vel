import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../domain/memory_models.dart';
import 'story_memory_storage.dart';

/// SQLite implementation of [StoryMemoryStorage].
///
/// Stores complex fields as JSON strings following the project storage style.
class StoryMemoryStorageIO implements StoryMemoryStorage {
  StoryMemoryStorageIO({required this.db});

  final Database db;

  bool _migrated = false;

  Future<void> ensureTables() async {
    if (_migrated) return;
    db.execute('''
      CREATE TABLE IF NOT EXISTS story_memory_sources (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        data TEXT NOT NULL
      )
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_memory_sources_project
      ON story_memory_sources (project_id)
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS story_memory_chunks (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        data TEXT NOT NULL
      )
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_memory_chunks_project
      ON story_memory_chunks (project_id)
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS story_thought_atoms (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        data TEXT NOT NULL
      )
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_thought_atoms_project
      ON story_thought_atoms (project_id)
    ''');
    _migrated = true;
  }

  @override
  Future<void> saveSources(
    String projectId,
    List<StoryMemorySource> sources,
  ) async {
    await ensureTables();
    final existing = await loadSources(projectId);
    final existingIds = {for (final s in existing) s.id};
    for (final source in sources) {
      final json = jsonEncode(source.toJson());
      if (existingIds.contains(source.id)) {
        db.execute(
          'UPDATE story_memory_sources SET data = ? WHERE id = ?',
          [json, source.id],
        );
      } else {
        db.execute(
          'INSERT INTO story_memory_sources (id, project_id, data) VALUES (?, ?, ?)',
          [source.id, projectId, json],
        );
      }
    }
  }

  @override
  Future<List<StoryMemorySource>> loadSources(String projectId) async {
    await ensureTables();
    final rows = db.select(
      'SELECT data FROM story_memory_sources WHERE project_id = ? ORDER BY id',
      [projectId],
    );
    return [
      for (final row in rows)
        StoryMemorySource.fromJson(
          jsonDecode(row['data'] as String) as Map<String, Object?>,
        ),
    ];
  }

  @override
  Future<void> saveChunks(
    String projectId,
    List<StoryMemoryChunk> chunks,
  ) async {
    await ensureTables();
    final existing = await loadChunks(projectId);
    final existingIds = {for (final c in existing) c.id};
    for (final chunk in chunks) {
      final json = jsonEncode(chunk.toJson());
      if (existingIds.contains(chunk.id)) {
        db.execute(
          'UPDATE story_memory_chunks SET data = ? WHERE id = ?',
          [json, chunk.id],
        );
      } else {
        db.execute(
          'INSERT INTO story_memory_chunks (id, project_id, data) VALUES (?, ?, ?)',
          [chunk.id, projectId, json],
        );
      }
    }
  }

  @override
  Future<List<StoryMemoryChunk>> loadChunks(String projectId) async {
    await ensureTables();
    final rows = db.select(
      'SELECT data FROM story_memory_chunks WHERE project_id = ? ORDER BY id',
      [projectId],
    );
    return [
      for (final row in rows)
        StoryMemoryChunk.fromJson(
          jsonDecode(row['data'] as String) as Map<String, Object?>,
        ),
    ];
  }

  @override
  Future<void> saveThoughts(
    String projectId,
    List<ThoughtAtom> thoughts,
  ) async {
    await ensureTables();
    final existing = await loadThoughts(projectId);
    final existingIds = {for (final t in existing) t.id};
    for (final thought in thoughts) {
      final json = jsonEncode(thought.toJson());
      if (existingIds.contains(thought.id)) {
        db.execute(
          'UPDATE story_thought_atoms SET data = ? WHERE id = ?',
          [json, thought.id],
        );
      } else {
        db.execute(
          'INSERT INTO story_thought_atoms (id, project_id, data) VALUES (?, ?, ?)',
          [thought.id, projectId, json],
        );
      }
    }
  }

  @override
  Future<List<ThoughtAtom>> loadThoughts(String projectId) async {
    await ensureTables();
    final rows = db.select(
      'SELECT data FROM story_thought_atoms WHERE project_id = ? ORDER BY id',
      [projectId],
    );
    return [
      for (final row in rows)
        ThoughtAtom.fromJson(
          jsonDecode(row['data'] as String) as Map<String, Object?>,
        ),
    ];
  }

  @override
  Future<void> clearProject(String projectId) async {
    await ensureTables();
    db.execute(
      'DELETE FROM story_memory_sources WHERE project_id = ?',
      [projectId],
    );
    db.execute(
      'DELETE FROM story_memory_chunks WHERE project_id = ?',
      [projectId],
    );
    db.execute(
      'DELETE FROM story_thought_atoms WHERE project_id = ?',
      [projectId],
    );
  }
}
