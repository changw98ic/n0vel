import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/roleplay_session_store_io.dart';
import 'package:novel_writer/features/story_generation/data/scene_roleplay_session_models.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('RoleplaySessionStoreIO', () {
    test('saves and loads roleplay prose fragments', () async {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);
      final store = RoleplaySessionStoreIO(db: db);

      await store.saveSession(
        projectId: 'project-01',
        session: _session(proseFragment: '柳溪把旧照片压在雨水里，挡住岳刃退路。'),
      );

      final loaded = await store.loadSession(
        projectId: 'project-01',
        chapterId: 'chapter-01',
        sceneId: 'scene-01',
      );

      final turn = loaded!.rounds.single.turns.single;
      expect(turn.proseFragment, '柳溪把旧照片压在雨水里，挡住岳刃退路。');
      expect(loaded.roleplayDraft, contains('柳溪把旧照片压在雨水里'));
    });

    test(
      'adds prose fragment column to existing roleplay turn table',
      () async {
        final db = sqlite3.openInMemory();
        addTearDown(db.dispose);
        db.execute('''
        CREATE TABLE roleplay_turns (
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
        final store = RoleplaySessionStoreIO(db: db);

        await store.ensureTables();

        final columns = db
            .select("PRAGMA table_info('roleplay_turns')")
            .map((row) => row['name'] as String)
            .toList(growable: false);
        expect(columns, contains('prose_fragment'));
      },
    );
  });
}

SceneRoleplaySession _session({required String proseFragment}) {
  return SceneRoleplaySession(
    chapterId: 'chapter-01',
    sceneId: 'scene-01',
    sceneTitle: '旧码头',
    rounds: [
      SceneRoleplayRound(
        round: 1,
        turns: [
          SceneRoleplayTurn(
            round: 1,
            characterId: 'char-liuxi',
            name: '柳溪',
            intent: '逼问货单',
            visibleAction: '挡住退路',
            dialogue: '货单在哪',
            innerState: '先逼出破绽。',
            proseFragment: proseFragment,
            taboo: '',
            rawText: 'fake',
          ),
        ],
        arbitration: const SceneRoleplayArbitration(
          fact: '柳溪挡住岳刃退路',
          state: '逼问推进',
          pressure: '升级',
          nextPublicState: '岳刃被迫回应',
          shouldStop: true,
          rawText: 'fake',
        ),
      ),
    ],
    committedFacts: [
      SceneRoleplayCommittedFact(
        sequenceId: 1,
        round: 1,
        source: 'arbiter',
        content: '柳溪挡住岳刃退路',
        previousHash: 'root',
        contentHash: SceneRoleplayCommittedFact.computeContentHash(
          sequenceId: 1,
          round: 1,
          source: 'arbiter',
          previousHash: 'root',
          content: '柳溪挡住岳刃退路',
        ),
      ),
    ],
    finalPublicState: '岳刃被迫回应',
  );
}
