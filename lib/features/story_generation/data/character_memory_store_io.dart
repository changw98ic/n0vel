import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import 'character_memory_delta_models.dart';
import 'character_memory_store.dart';

class CharacterMemoryStoreIO implements CharacterMemoryStore {
  CharacterMemoryStoreIO({required this.db});

  final Database db;
  bool _migrated = false;

  Future<void> ensureTables() async {
    if (_migrated) return;
    db.execute('''
      CREATE TABLE IF NOT EXISTS character_memories (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        chapter_id TEXT NOT NULL,
        scene_id TEXT NOT NULL,
        character_id TEXT NOT NULL,
        kind TEXT NOT NULL,
        content TEXT NOT NULL,
        source_round INTEGER NOT NULL,
        source_turn_id TEXT NOT NULL,
        confidence REAL NOT NULL,
        data TEXT NOT NULL
      )
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_character_memories_project_character
      ON character_memories (project_id, character_id)
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_character_memories_project
      ON character_memories (project_id)
    ''');
    _migrated = true;
  }

  @override
  Future<void> saveAcceptedDeltas({
    required String projectId,
    required String chapterId,
    required String sceneId,
    required List<CharacterMemoryDelta> deltas,
  }) async {
    await ensureTables();
    for (final delta in deltas.where((delta) => delta.accepted)) {
      db.execute(
        '''
        INSERT OR REPLACE INTO character_memories (
          id, project_id, chapter_id, scene_id, character_id, kind, content,
          source_round, source_turn_id, confidence, data
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          delta.deltaId,
          projectId,
          chapterId,
          sceneId,
          delta.characterId,
          delta.kind.name,
          delta.content,
          delta.sourceRound,
          delta.sourceTurnId,
          delta.confidence,
          jsonEncode(delta.toJson()),
        ],
      );
    }
  }

  @override
  Future<List<CharacterMemoryDelta>> loadCharacterMemories({
    required String projectId,
    required String characterId,
  }) async {
    await ensureTables();
    final rows = db.select(
      'SELECT data FROM character_memories WHERE project_id = ? ORDER BY id',
      [projectId],
    );
    final deltas = [for (final row in rows) _decode(row['data'] as String)];
    return [
      for (final delta in deltas)
        if (delta.acl.canSee(characterId)) delta,
    ];
  }

  @override
  Future<List<CharacterMemoryDelta>> loadPublicMemories({
    required String projectId,
  }) async {
    await ensureTables();
    final rows = db.select(
      'SELECT data FROM character_memories WHERE project_id = ? ORDER BY id',
      [projectId],
    );
    final deltas = [for (final row in rows) _decode(row['data'] as String)];
    return [
      for (final delta in deltas)
        if (delta.characterId.isEmpty && delta.acl.isPublic) delta,
    ];
  }

  @override
  Future<void> clearProject(String projectId) async {
    await ensureTables();
    db.execute('DELETE FROM character_memories WHERE project_id = ?', [
      projectId,
    ]);
  }

  CharacterMemoryDelta _decode(String raw) {
    return CharacterMemoryDelta.fromJson(
      Map<String, Object?>.from(jsonDecode(raw) as Map),
    );
  }
}
