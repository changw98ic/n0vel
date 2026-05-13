part of 'roleplay_session_store_io.dart';

// ---------------------------------------------------------------------------
// Import / Export – JSON serialization helpers for project transfer
// ---------------------------------------------------------------------------

mixin _RoleplaySessionStoreIOTransfer on _RoleplaySessionStoreIOFields, _RoleplaySessionStoreIOLoad {
  Future<Map<String, Object?>?> exportProjectJson(String projectId) async {
    await ensureTables();
    final sessions = db.select(
      '''
      SELECT id, chapter_id, scene_id, scene_title, final_public_state
      FROM roleplay_sessions
      WHERE project_id = ?
      ORDER BY chapter_id, scene_id
      ''',
      [projectId],
    );
    if (sessions.isEmpty) return null;

    final rounds = <Map<String, Object?>>[];
    final turns = <Map<String, Object?>>[];
    final arbitrations = <Map<String, Object?>>[];
    final committedFacts = <Map<String, Object?>>[];
    for (final session in sessions) {
      final sessionId = session['id'] as String;
      rounds.addAll([
        for (final row in db.select(
          '''
          SELECT session_id, round
          FROM roleplay_rounds
          WHERE session_id = ?
          ORDER BY round
          ''',
          [sessionId],
        ))
          {
            'sessionId': row['session_id'] as String,
            'round': row['round'] as int,
          },
      ]);
      turns.addAll([
        for (final row in db.select(
          '''
          SELECT session_id, round, turn_order, character_id, name, intent,
                 visible_action, dialogue, inner_state, prose_fragment, taboo,
                 raw_text, skill_id, skill_version, proposed_memory_deltas
          FROM roleplay_turns
          WHERE session_id = ?
          ORDER BY round, turn_order
          ''',
          [sessionId],
        ))
          {
            'sessionId': row['session_id'] as String,
            'round': row['round'] as int,
            'turnOrder': row['turn_order'] as int,
            'characterId': row['character_id'] as String,
            'name': row['name'] as String,
            'intent': row['intent'] as String,
            'visibleAction': row['visible_action'] as String,
            'dialogue': row['dialogue'] as String,
            'innerState': row['inner_state'] as String,
            'proseFragment': row['prose_fragment'] as String,
            'taboo': row['taboo'] as String,
            'rawText': row['raw_text'] as String,
            'skillId': row['skill_id'] as String,
            'skillVersion': row['skill_version'] as String,
            'proposedMemoryDeltas': row['proposed_memory_deltas'] as String,
          },
      ]);
      arbitrations.addAll([
        for (final row in db.select(
          '''
          SELECT session_id, round, fact, state, pressure, next_public_state,
                 should_stop, raw_text, skill_id, skill_version,
                 accepted_memory_deltas, rejected_memory_deltas
          FROM roleplay_arbitrations
          WHERE session_id = ?
          ORDER BY round
          ''',
          [sessionId],
        ))
          {
            'sessionId': row['session_id'] as String,
            'round': row['round'] as int,
            'fact': row['fact'] as String,
            'state': row['state'] as String,
            'pressure': row['pressure'] as String,
            'nextPublicState': row['next_public_state'] as String,
            'shouldStop': (row['should_stop'] as int) == 1,
            'rawText': row['raw_text'] as String,
            'skillId': row['skill_id'] as String,
            'skillVersion': row['skill_version'] as String,
            'acceptedMemoryDeltas': row['accepted_memory_deltas'] as String,
            'rejectedMemoryDeltas': row['rejected_memory_deltas'] as String,
          },
      ]);
      committedFacts.addAll([
        for (final row in db.select(
          '''
          SELECT session_id, sequence_id, round, source, content,
                 previous_hash, content_hash
          FROM roleplay_committed_facts
          WHERE session_id = ?
          ORDER BY sequence_id
          ''',
          [sessionId],
        ))
          {
            'sessionId': row['session_id'] as String,
            'sequenceId': row['sequence_id'] as int,
            'round': row['round'] as int,
            'source': row['source'] as String,
            'content': row['content'] as String,
            'previousHash': row['previous_hash'] as String,
            'contentHash': row['content_hash'] as String,
          },
      ]);
    }

    return {
      'sessions': [
        for (final session in sessions)
          {
            'id': session['id'] as String,
            'chapterId': session['chapter_id'] as String,
            'sceneId': session['scene_id'] as String,
            'sceneTitle': session['scene_title'] as String,
            'finalPublicState': session['final_public_state'] as String,
          },
      ],
      'rounds': rounds,
      'turns': turns,
      'arbitrations': arbitrations,
      'committedFacts': committedFacts,
    };
  }

  Future<void> importProjectJson(
    String projectId,
    Map<String, Object?> data,
  ) async {
    await ensureTables();
    final rawSessions = data['sessions'];
    if (rawSessions is! List) return;
    final existingRows = db.select(
      'SELECT id FROM roleplay_sessions WHERE project_id = ?',
      [projectId],
    );
    db.execute('BEGIN TRANSACTION');
    try {
      for (final row in existingRows) {
        _deleteSessionRows(row['id'] as String);
      }
      db.execute('DELETE FROM roleplay_sessions WHERE project_id = ?', [
        projectId,
      ]);

      final sessionIdBySourceId = <String, String>{};
      for (final raw in rawSessions) {
        if (raw is! Map) continue;
        final row = Map<String, Object?>.from(raw);
        var sourceSessionId = _string(row['id']);
        final chapterId = _string(row['chapterId']);
        final sceneId = _string(row['sceneId']);
        if (chapterId.isEmpty || sceneId.isEmpty) continue;
        final sessionId = _sessionId(projectId, chapterId, sceneId);
        if (sourceSessionId.isEmpty) sourceSessionId = sessionId;
        sessionIdBySourceId[sourceSessionId] = sessionId;
        sessionIdBySourceId[sessionId] = sessionId;
        db.execute(
          '''
          INSERT OR REPLACE INTO roleplay_sessions (
            id, project_id, chapter_id, scene_id, scene_title,
            final_public_state
          ) VALUES (?, ?, ?, ?, ?, ?)
          ''',
          [
            sessionId,
            projectId,
            chapterId,
            sceneId,
            _string(row['sceneTitle']),
            _string(row['finalPublicState']),
          ],
        );
      }

      for (final raw in _list(data['rounds'])) {
        if (raw is! Map) continue;
        final row = Map<String, Object?>.from(raw);
        final sessionId = sessionIdBySourceId[_string(row['sessionId'])];
        if (sessionId == null) continue;
        db.execute(
          'INSERT OR REPLACE INTO roleplay_rounds (session_id, round) VALUES (?, ?)',
          [sessionId, _int(row['round'])],
        );
      }
      for (final raw in _list(data['turns'])) {
        if (raw is! Map) continue;
        final row = Map<String, Object?>.from(raw);
        final sessionId = sessionIdBySourceId[_string(row['sessionId'])];
        if (sessionId == null) continue;
        db.execute(
          '''
          INSERT OR REPLACE INTO roleplay_turns (
            session_id, round, turn_order, character_id, name, intent,
            visible_action, dialogue, inner_state, prose_fragment, taboo,
            raw_text, skill_id, skill_version, proposed_memory_deltas
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            sessionId,
            _int(row['round']),
            _int(row['turnOrder']),
            _string(row['characterId']),
            _string(row['name']),
            _string(row['intent']),
            _string(row['visibleAction']),
            _string(row['dialogue']),
            _string(row['innerState']),
            _string(row['proseFragment']),
            _string(row['taboo']),
            _string(row['rawText']),
            _string(row['skillId']),
            _string(row['skillVersion']),
            _jsonArrayString(row['proposedMemoryDeltas']),
          ],
        );
      }
      for (final raw in _list(data['arbitrations'])) {
        if (raw is! Map) continue;
        final row = Map<String, Object?>.from(raw);
        final sessionId = sessionIdBySourceId[_string(row['sessionId'])];
        if (sessionId == null) continue;
        db.execute(
          '''
          INSERT OR REPLACE INTO roleplay_arbitrations (
            session_id, round, fact, state, pressure, next_public_state,
            should_stop, raw_text, skill_id, skill_version,
            accepted_memory_deltas, rejected_memory_deltas
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            sessionId,
            _int(row['round']),
            _string(row['fact']),
            _string(row['state']),
            _string(row['pressure']),
            _string(row['nextPublicState']),
            row['shouldStop'] == true ? 1 : 0,
            _string(row['rawText']),
            _string(row['skillId']),
            _string(row['skillVersion']),
            _jsonArrayString(row['acceptedMemoryDeltas']),
            _jsonArrayString(row['rejectedMemoryDeltas']),
          ],
        );
      }
      for (final raw in _list(data['committedFacts'])) {
        if (raw is! Map) continue;
        final row = Map<String, Object?>.from(raw);
        final sessionId = sessionIdBySourceId[_string(row['sessionId'])];
        if (sessionId == null) continue;
        db.execute(
          '''
          INSERT OR REPLACE INTO roleplay_committed_facts (
            session_id, sequence_id, round, source, content,
            previous_hash, content_hash
          ) VALUES (?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            sessionId,
            _int(row['sequenceId']),
            _int(row['round']),
            _string(row['source']),
            _string(row['content']),
            _string(row['previousHash']),
            _string(row['contentHash']),
          ],
        );
      }
      _validateProjectCommittedFactChains(projectId);
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  static List<Object?> _list(Object? raw) =>
      raw is List ? raw.cast<Object?>() : const <Object?>[];

  static String _string(Object? raw) => raw is String ? raw : '';

  static int _int(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw) ?? 0;
    return 0;
  }

  static String _jsonArrayString(Object? raw) {
    final value = _string(raw);
    return value.trim().isEmpty ? '[]' : value;
  }
}
