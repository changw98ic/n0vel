import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import 'character_memory_delta_models.dart';
import 'roleplay_session_store.dart';
import 'scene_roleplay_session_models.dart';

class RoleplaySessionStoreIO implements RoleplaySessionStore {
  RoleplaySessionStoreIO({required this.db});

  final Database db;
  bool _migrated = false;

  Future<void> ensureTables() async {
    if (_migrated) return;
    db.execute('''
      CREATE TABLE IF NOT EXISTS roleplay_sessions (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        chapter_id TEXT NOT NULL,
        scene_id TEXT NOT NULL,
        scene_title TEXT NOT NULL,
        final_public_state TEXT NOT NULL
      )
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_roleplay_sessions_project_chapter
      ON roleplay_sessions (project_id, chapter_id)
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS roleplay_rounds (
        session_id TEXT NOT NULL,
        round INTEGER NOT NULL,
        PRIMARY KEY (session_id, round)
      )
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS roleplay_turns (
        session_id TEXT NOT NULL,
        round INTEGER NOT NULL,
        turn_order INTEGER NOT NULL,
        character_id TEXT NOT NULL,
        name TEXT NOT NULL,
        intent TEXT NOT NULL,
        visible_action TEXT NOT NULL,
        dialogue TEXT NOT NULL,
        inner_state TEXT NOT NULL,
        taboo TEXT NOT NULL,
        raw_text TEXT NOT NULL,
        skill_id TEXT NOT NULL,
        skill_version TEXT NOT NULL,
        proposed_memory_deltas TEXT NOT NULL,
        PRIMARY KEY (session_id, round, turn_order)
      )
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS roleplay_arbitrations (
        session_id TEXT NOT NULL,
        round INTEGER NOT NULL,
        fact TEXT NOT NULL,
        state TEXT NOT NULL,
        pressure TEXT NOT NULL,
        next_public_state TEXT NOT NULL,
        should_stop INTEGER NOT NULL,
        raw_text TEXT NOT NULL,
        skill_id TEXT NOT NULL,
        skill_version TEXT NOT NULL,
        accepted_memory_deltas TEXT NOT NULL,
        rejected_memory_deltas TEXT NOT NULL,
        PRIMARY KEY (session_id, round)
      )
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS roleplay_committed_facts (
        session_id TEXT NOT NULL,
        sequence_id INTEGER NOT NULL,
        round INTEGER NOT NULL,
        source TEXT NOT NULL,
        content TEXT NOT NULL,
        previous_hash TEXT NOT NULL,
        content_hash TEXT NOT NULL,
        PRIMARY KEY (session_id, sequence_id)
      )
    ''');
    _migrated = true;
  }

  @override
  Future<void> saveSession({
    required String projectId,
    required SceneRoleplaySession session,
  }) async {
    await ensureTables();
    final sessionId = _sessionId(projectId, session.chapterId, session.sceneId);
    db.execute('BEGIN TRANSACTION');
    try {
      _deleteSessionRows(sessionId);
      db.execute(
        '''
        INSERT OR REPLACE INTO roleplay_sessions
        (id, project_id, chapter_id, scene_id, scene_title, final_public_state)
        VALUES (?, ?, ?, ?, ?, ?)
        ''',
        [
          sessionId,
          projectId,
          session.chapterId,
          session.sceneId,
          session.sceneTitle,
          session.finalPublicState,
        ],
      );
      for (final round in session.rounds) {
        db.execute(
          'INSERT INTO roleplay_rounds (session_id, round) VALUES (?, ?)',
          [sessionId, round.round],
        );
        for (var index = 0; index < round.turns.length; index += 1) {
          final turn = round.turns[index];
          db.execute(
            '''
            INSERT INTO roleplay_turns (
              session_id, round, turn_order, character_id, name, intent,
              visible_action, dialogue, inner_state, taboo, raw_text,
              skill_id, skill_version, proposed_memory_deltas
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''',
            [
              sessionId,
              round.round,
              index,
              turn.characterId,
              turn.name,
              turn.intent,
              turn.visibleAction,
              turn.dialogue,
              turn.innerState,
              turn.taboo,
              turn.rawText,
              turn.skillId,
              turn.skillVersion,
              _encodeDeltas(turn.proposedMemoryDeltas),
            ],
          );
        }
        final arbitration = round.arbitration;
        db.execute(
          '''
          INSERT INTO roleplay_arbitrations (
            session_id, round, fact, state, pressure, next_public_state,
            should_stop, raw_text, skill_id, skill_version,
            accepted_memory_deltas, rejected_memory_deltas
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            sessionId,
            round.round,
            arbitration.fact,
            arbitration.state,
            arbitration.pressure,
            arbitration.nextPublicState,
            arbitration.shouldStop ? 1 : 0,
            arbitration.rawText,
            arbitration.skillId,
            arbitration.skillVersion,
            _encodeDeltas(arbitration.acceptedMemoryDeltas),
            _encodeDeltas(arbitration.rejectedMemoryDeltas),
          ],
        );
      }
      for (final fact in session.committedFacts) {
        db.execute(
          '''
          INSERT INTO roleplay_committed_facts (
            session_id, sequence_id, round, source, content,
            previous_hash, content_hash
          ) VALUES (?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            sessionId,
            fact.sequenceId,
            fact.round,
            fact.source,
            fact.content,
            fact.previousHash,
            fact.contentHash,
          ],
        );
      }
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  @override
  Future<SceneRoleplaySession?> loadSession({
    required String projectId,
    required String chapterId,
    required String sceneId,
  }) async {
    await ensureTables();
    final sessionId = _sessionId(projectId, chapterId, sceneId);
    final rows = db.select('SELECT * FROM roleplay_sessions WHERE id = ?', [
      sessionId,
    ]);
    if (rows.isEmpty) return null;
    return _loadSessionFromRow(rows.single);
  }

  @override
  Future<List<SceneRoleplaySession>> loadChapterSessions({
    required String projectId,
    required String chapterId,
  }) async {
    await ensureTables();
    final rows = db.select(
      '''
      SELECT * FROM roleplay_sessions
      WHERE project_id = ? AND chapter_id = ?
      ORDER BY scene_id
      ''',
      [projectId, chapterId],
    );
    return [for (final row in rows) _loadSessionFromRow(row)];
  }

  @override
  Future<void> clearProject(String projectId) async {
    await ensureTables();
    final rows = db.select(
      'SELECT id FROM roleplay_sessions WHERE project_id = ?',
      [projectId],
    );
    db.execute('BEGIN TRANSACTION');
    try {
      for (final row in rows) {
        _deleteSessionRows(row['id'] as String);
      }
      db.execute('DELETE FROM roleplay_sessions WHERE project_id = ?', [
        projectId,
      ]);
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
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

  String _sessionId(String projectId, String chapterId, String sceneId) =>
      '$projectId:$chapterId:$sceneId';

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
