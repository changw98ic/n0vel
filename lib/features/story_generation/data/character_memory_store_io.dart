import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import 'character_memory_conflict_policy.dart';
import 'character_memory_delta_models.dart';
import 'character_memory_store.dart';

class CharacterMemoryStoreIO implements CharacterMemoryStore {
  CharacterMemoryStoreIO({
    required this.db,
    CharacterMemoryConflictPolicy? conflictPolicy,
  }) : _conflictPolicy =
           conflictPolicy ?? const CharacterMemoryConflictPolicy();

  final Database db;
  final CharacterMemoryConflictPolicy _conflictPolicy;
  final List<CharacterMemoryConflict> _lastRejectedConflicts =
      <CharacterMemoryConflict>[];
  bool _migrated = false;

  List<CharacterMemoryConflict> get lastRejectedConflicts =>
      List<CharacterMemoryConflict>.unmodifiable(_lastRejectedConflicts);

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
    _lastRejectedConflicts.clear();
    final existingKeys = _loadAcceptedMemoryKeys(projectId);
    final existingMemories = _loadAcceptedMemories(projectId);
    for (final delta in deltas.where((delta) => delta.accepted)) {
      final key = _memoryContentKey(delta);
      if (!existingKeys.add(key)) {
        continue;
      }
      final conflict = _conflictPolicy.findConflict(
        incoming: delta,
        existing: existingMemories,
      );
      if (conflict != null) {
        _lastRejectedConflicts.add(conflict);
        continue;
      }
      db.execute(
        '''
        INSERT OR REPLACE INTO character_memories (
          id, project_id, chapter_id, scene_id, character_id, kind, content,
          source_round, source_turn_id, confidence, data
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          _memoryRowId(
            projectId: projectId,
            chapterId: chapterId,
            sceneId: sceneId,
            deltaId: delta.deltaId,
          ),
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
      existingMemories.add(delta);
    }
  }

  @override
  Future<List<CharacterMemoryDelta>> loadCharacterMemories({
    required String projectId,
    required String characterId,
  }) async {
    await ensureTables();
    final rows = db.select(
      '''
      SELECT data
      FROM character_memories
      WHERE project_id = ? AND (character_id = ? OR character_id = '')
      ORDER BY id
      ''',
      [projectId, characterId],
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
      '''
      SELECT data
      FROM character_memories
      WHERE project_id = ? AND character_id = ''
      ORDER BY id
      ''',
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

  Future<Map<String, Object?>?> exportProjectJson(String projectId) async {
    await ensureTables();
    final rows = db.select(
      '''
      SELECT id, chapter_id, scene_id, character_id, kind, content,
             source_round, source_turn_id, confidence, data
      FROM character_memories
      WHERE project_id = ?
      ORDER BY id
      ''',
      [projectId],
    );
    if (rows.isEmpty) return null;
    return {
      'memories': [
        for (final row in rows)
          {
            'id': row['id'] as String,
            'chapterId': row['chapter_id'] as String,
            'sceneId': row['scene_id'] as String,
            'characterId': row['character_id'] as String,
            'kind': row['kind'] as String,
            'content': row['content'] as String,
            'sourceRound': row['source_round'] as int,
            'sourceTurnId': row['source_turn_id'] as String,
            'confidence': (row['confidence'] as num).toDouble(),
            'data': row['data'] as String,
          },
      ],
    };
  }

  Future<void> importProjectJson(
    String projectId,
    Map<String, Object?> data,
  ) async {
    await ensureTables();
    final rawMemories = data['memories'];
    if (rawMemories is! List) return;
    db.execute('BEGIN TRANSACTION');
    try {
      db.execute('DELETE FROM character_memories WHERE project_id = ?', [
        projectId,
      ]);
      for (final raw in rawMemories) {
        if (raw is! Map) continue;
        final row = Map<String, Object?>.from(raw);
        final chapterId = _string(row['chapterId']);
        final sceneId = _string(row['sceneId']);
        final deltaId = _deltaIdFromRow(row);
        if (chapterId.isEmpty || sceneId.isEmpty || deltaId.isEmpty) {
          continue;
        }
        final id = _memoryRowId(
          projectId: projectId,
          chapterId: chapterId,
          sceneId: sceneId,
          deltaId: deltaId,
        );
        db.execute(
          '''
          INSERT OR REPLACE INTO character_memories (
            id, project_id, chapter_id, scene_id, character_id, kind, content,
            source_round, source_turn_id, confidence, data
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            id,
            projectId,
            chapterId,
            sceneId,
            _string(row['characterId']),
            _string(row['kind']),
            _string(row['content']),
            _int(row['sourceRound']),
            _string(row['sourceTurnId']),
            _double(row['confidence']) ?? 1,
            _jsonObjectString(row['data']),
          ],
        );
      }
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  CharacterMemoryDelta _decode(String raw) {
    return CharacterMemoryDelta.fromJson(
      Map<String, Object?>.from(jsonDecode(raw) as Map),
    );
  }

  List<CharacterMemoryDelta> _loadAcceptedMemories(String projectId) {
    final rows = db.select(
      '''
      SELECT data
      FROM character_memories
      WHERE project_id = ?
      ORDER BY id
      ''',
      [projectId],
    );
    return [for (final row in rows) _decode(row['data'] as String)];
  }

  Set<String> _loadAcceptedMemoryKeys(String projectId) {
    final rows = db.select(
      '''
      SELECT character_id, kind, content
      FROM character_memories
      WHERE project_id = ?
      ''',
      [projectId],
    );
    return {
      for (final row in rows)
        _memoryContentKeyParts(
          characterId: row['character_id'] as String,
          kind: row['kind'] as String,
          content: row['content'] as String,
        ),
    };
  }

  static String _memoryContentKey(CharacterMemoryDelta delta) {
    return _memoryContentKeyParts(
      characterId: delta.characterId,
      kind: delta.kind.name,
      content: delta.content,
    );
  }

  static String _memoryContentKeyParts({
    required String characterId,
    required String kind,
    required String content,
  }) {
    final normalizedContent = content.replaceAll(RegExp(r'\s+'), '').trim();
    return '$characterId|$kind|$normalizedContent';
  }

  static String _string(Object? raw) => raw is String ? raw : '';

  static int _int(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw) ?? 0;
    return 0;
  }

  static double? _double(Object? raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }

  static String _jsonObjectString(Object? raw) {
    final value = _string(raw);
    return value.trim().isEmpty ? '{}' : value;
  }

  static String _deltaIdFromRow(Map<String, Object?> row) {
    final data = _jsonObjectString(row['data']);
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map) {
        final deltaId = _string(decoded['deltaId']);
        if (deltaId.isNotEmpty) return deltaId;
      }
    } on FormatException {
      // Fall back to the package row id below.
    }
    return _string(row['id']);
  }

  static String _memoryRowId({
    required String projectId,
    required String chapterId,
    required String sceneId,
    required String deltaId,
  }) {
    return [projectId, chapterId, sceneId, deltaId].join(':');
  }
}
