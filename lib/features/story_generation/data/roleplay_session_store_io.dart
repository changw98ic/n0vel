import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../../../app/state/sql_identifier.dart';
import 'character_memory_delta_models.dart';
import 'roleplay_session_store.dart';
import 'scene_roleplay_session_models.dart';

part 'roleplay_session_store_io_load.dart';
part 'roleplay_session_store_io_transfer.dart';

/// Field + shared method declarations for [RoleplaySessionStoreIO] part mixins.
mixin _RoleplaySessionStoreIOFields {
  abstract final Database db;

  Future<void> ensureTables();
  String _sessionId(String projectId, String chapterId, String sceneId);
}

class RoleplaySessionStoreIO extends Object
    with _RoleplaySessionStoreIOFields, _RoleplaySessionStoreIOLoad, _RoleplaySessionStoreIOTransfer
    implements RoleplaySessionStore {
  RoleplaySessionStoreIO({required this.db});

  @override
  final Database db;

  bool _migrated = false;

  @override
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
        prose_fragment TEXT NOT NULL DEFAULT '',
        taboo TEXT NOT NULL,
        raw_text TEXT NOT NULL,
        skill_id TEXT NOT NULL,
        skill_version TEXT NOT NULL,
        proposed_memory_deltas TEXT NOT NULL,
        PRIMARY KEY (session_id, round, turn_order)
      )
    ''');
    _ensureColumn(
      table: 'roleplay_turns',
      column: 'prose_fragment',
      definition: "TEXT NOT NULL DEFAULT ''",
    );
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
    _requireValidCommittedFactChain(session);
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
              visible_action, dialogue, inner_state, prose_fragment, taboo,
              raw_text, skill_id, skill_version, proposed_memory_deltas
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
              turn.proseFragment,
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
    return _loadValidatedSessionFromRow(rows.single);
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
    return [for (final row in rows) _loadValidatedSessionFromRow(row)];
  }

  @override
  Future<List<SceneRoleplaySession>> loadProjectSessions({
    required String projectId,
  }) async {
    await ensureTables();
    final rows = db.select(
      '''
      SELECT * FROM roleplay_sessions
      WHERE project_id = ?
      ORDER BY chapter_id, scene_id
      ''',
      [projectId],
    );
    return [for (final row in rows) _loadValidatedSessionFromRow(row)];
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

  @override
  String _sessionId(String projectId, String chapterId, String sceneId) =>
      '$projectId:$chapterId:$sceneId';
}
