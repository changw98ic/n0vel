part of 'roleplay_session_store_io.dart';

// ---------------------------------------------------------------------------
// Load helpers – row → domain model deserialization + validation
// ---------------------------------------------------------------------------

mixin _RoleplaySessionStoreIOLoad on _RoleplaySessionStoreIOFields {
  SceneRoleplaySession _loadValidatedSessionFromRow(Row row) {
    final session = _loadSessionFromRow(row);
    _requireValidCommittedFactChain(session);
    return session;
  }

  void _validateProjectCommittedFactChains(String projectId) {
    final rows = db.select(
      'SELECT * FROM roleplay_sessions WHERE project_id = ? ORDER BY id',
      [projectId],
    );
    for (final row in rows) {
      _requireValidCommittedFactChain(_loadSessionFromRow(row));
    }
  }

  void _requireValidCommittedFactChain(SceneRoleplaySession session) {
    final errors = session.validateCommittedFactChain();
    if (errors.isEmpty) return;
    throw StateError(
      'Invalid roleplay committed fact chain for '
      '${session.chapterId}/${session.sceneId}: ${errors.join('; ')}',
    );
  }

  SceneRoleplaySession _loadSessionFromRow(Row row) {
    final sessionId = row['id'] as String;
    final roundRows = db.select(
      'SELECT round FROM roleplay_rounds WHERE session_id = ? ORDER BY round',
      [sessionId],
    );
    final turnsByRound = <int, List<SceneRoleplayTurn>>{};
    final turnRows = db.select(
      '''
      SELECT * FROM roleplay_turns
      WHERE session_id = ?
      ORDER BY round, turn_order
      ''',
      [sessionId],
    );
    for (final turnRow in turnRows) {
      final round = turnRow['round'] as int;
      turnsByRound
          .putIfAbsent(round, () => <SceneRoleplayTurn>[])
          .add(
            SceneRoleplayTurn(
              round: round,
              characterId: turnRow['character_id'] as String,
              name: turnRow['name'] as String,
              intent: turnRow['intent'] as String,
              visibleAction: turnRow['visible_action'] as String,
              dialogue: turnRow['dialogue'] as String,
              innerState: turnRow['inner_state'] as String,
              proseFragment: turnRow['prose_fragment'] as String,
              taboo: turnRow['taboo'] as String,
              rawText: turnRow['raw_text'] as String,
              skillId: turnRow['skill_id'] as String,
              skillVersion: turnRow['skill_version'] as String,
              proposedMemoryDeltas: _decodeDeltas(
                turnRow['proposed_memory_deltas'] as String,
              ),
            ),
          );
    }

    final arbitrationByRound = <int, SceneRoleplayArbitration>{};
    final arbitrationRows = db.select(
      'SELECT * FROM roleplay_arbitrations WHERE session_id = ?',
      [sessionId],
    );
    for (final arbitrationRow in arbitrationRows) {
      final round = arbitrationRow['round'] as int;
      arbitrationByRound[round] = SceneRoleplayArbitration(
        fact: arbitrationRow['fact'] as String,
        state: arbitrationRow['state'] as String,
        pressure: arbitrationRow['pressure'] as String,
        nextPublicState: arbitrationRow['next_public_state'] as String,
        shouldStop: (arbitrationRow['should_stop'] as int) == 1,
        rawText: arbitrationRow['raw_text'] as String,
        skillId: arbitrationRow['skill_id'] as String,
        skillVersion: arbitrationRow['skill_version'] as String,
        acceptedMemoryDeltas: _decodeDeltas(
          arbitrationRow['accepted_memory_deltas'] as String,
        ),
        rejectedMemoryDeltas: _decodeDeltas(
          arbitrationRow['rejected_memory_deltas'] as String,
        ),
      );
    }

    final rounds = [
      for (final roundRow in roundRows)
        SceneRoleplayRound(
          round: roundRow['round'] as int,
          turns:
              turnsByRound[roundRow['round'] as int] ??
              const <SceneRoleplayTurn>[],
          arbitration:
              arbitrationByRound[roundRow['round'] as int] ??
              const SceneRoleplayArbitration(
                fact: '',
                state: '',
                pressure: '',
                nextPublicState: '',
                shouldStop: false,
                rawText: '',
              ),
        ),
    ];

    final factRows = db.select(
      '''
      SELECT * FROM roleplay_committed_facts
      WHERE session_id = ?
      ORDER BY sequence_id
      ''',
      [sessionId],
    );

    return SceneRoleplaySession(
      chapterId: row['chapter_id'] as String,
      sceneId: row['scene_id'] as String,
      sceneTitle: row['scene_title'] as String,
      rounds: rounds,
      committedFacts: [
        for (final factRow in factRows)
          SceneRoleplayCommittedFact(
            sequenceId: factRow['sequence_id'] as int,
            round: factRow['round'] as int,
            source: factRow['source'] as String,
            content: factRow['content'] as String,
            previousHash: factRow['previous_hash'] as String,
            contentHash: factRow['content_hash'] as String,
          ),
      ],
      finalPublicState: row['final_public_state'] as String,
    );
  }

  void _deleteSessionRows(String sessionId) {
    db.execute('DELETE FROM roleplay_committed_facts WHERE session_id = ?', [
      sessionId,
    ]);
    db.execute('DELETE FROM roleplay_arbitrations WHERE session_id = ?', [
      sessionId,
    ]);
    db.execute('DELETE FROM roleplay_turns WHERE session_id = ?', [sessionId]);
    db.execute('DELETE FROM roleplay_rounds WHERE session_id = ?', [sessionId]);
  }

  void _ensureColumn({
    required String table,
    required String column,
    required String definition,
  }) {
    final safeTable = checkedSqlIdentifier(table);
    final safeColumn = checkedSqlIdentifier(column);
    final columns = db.select(
      'PRAGMA table_info(${quotedSqlIdentifier(safeTable)})',
    );
    final exists = columns.any((r) => r['name'] == column);
    if (!exists) {
      db.execute(
        'ALTER TABLE ${quotedSqlIdentifier(safeTable)} '
        'ADD COLUMN ${quotedSqlIdentifier(safeColumn)} $definition',
      );
    }
  }

  String _encodeDeltas(List<CharacterMemoryDelta> deltas) {
    return jsonEncode([for (final delta in deltas) delta.toJson()]);
  }

  List<CharacterMemoryDelta> _decodeDeltas(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const <CharacterMemoryDelta>[];
    return [
      for (final value in decoded)
        if (value is Map)
          CharacterMemoryDelta.fromJson(Map<String, Object?>.from(value)),
    ];
  }
}
