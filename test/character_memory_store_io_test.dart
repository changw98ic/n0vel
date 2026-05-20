import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/features/story_generation/data/character_memory_delta_models.dart';
import 'package:novel_writer/features/story_generation/data/character_memory_store_io.dart';
import 'package:novel_writer/features/story_generation/data/character_visible_context_models.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/memory_policy.dart';

void main() {
  late Database db;
  late CharacterMemoryStoreIO store;

  setUp(() {
    db = sqlite3.openInMemory();
    store = CharacterMemoryStoreIO(db: db);
  });

  tearDown(() {
    db.dispose();
  });

  group('saveAcceptedDeltas + loadCharacterMemories', () {
    test('character-tier roleplay delta is returned for matching tier', () async {
      final delta = CharacterMemoryDelta(
        deltaId: 'd1',
        characterId: 'char-A',
        kind: CharacterMemoryDeltaKind.belief,
        content: 'The old man cannot be trusted.',
        acl: VisibilityAcl.characters({'char-A'}),
        sourceRound: 1,
        sourceTurnId: 'turn-1',
        confidence: 0.9,
        accepted: true,
      );

      await store.saveAcceptedDeltas(
        projectId: 'proj-1',
        chapterId: 'ch-1',
        sceneId: 'sc-1',
        tier: MemoryTier.character,
        producer: 'roleplay',
        deltas: [delta],
      );

      final loaded = await store.loadCharacterMemories(
        projectId: 'proj-1',
        characterId: 'char-A',
        tier: MemoryTier.character,
      );

      expect(loaded, hasLength(1));
      expect(loaded.first.deltaId, 'd1');
      expect(loaded.first.content, 'The old man cannot be trusted.');
    });

    test('scene tier does not return character-tier deltas', () async {
      final delta = CharacterMemoryDelta(
        deltaId: 'd2',
        characterId: 'char-B',
        kind: CharacterMemoryDeltaKind.observation,
        content: 'A shadow moved.',
        acl: VisibilityAcl.characters({'char-B'}),
        sourceRound: 1,
        accepted: true,
      );

      await store.saveAcceptedDeltas(
        projectId: 'proj-1',
        chapterId: 'ch-1',
        sceneId: 'sc-1',
        tier: MemoryTier.character,
        producer: 'roleplay',
        deltas: [delta],
      );

      final loaded = await store.loadCharacterMemories(
        projectId: 'proj-1',
        characterId: 'char-B',
        tier: MemoryTier.scene,
      );

      expect(loaded, isEmpty);
    });
  });

  group('loadPublicMemories', () {
    test('returns only public deltas for the requested tier', () async {
      final publicDelta = CharacterMemoryDelta(
        deltaId: 'pub-1',
        characterId: '',
        kind: CharacterMemoryDeltaKind.worldFact,
        content: 'It rained all night.',
        acl: VisibilityAcl.public(),
        sourceRound: 1,
        accepted: true,
      );
      final privateDelta = CharacterMemoryDelta(
        deltaId: 'priv-1',
        characterId: 'char-C',
        kind: CharacterMemoryDeltaKind.observation,
        content: 'She hid the letter.',
        acl: VisibilityAcl.characters({'char-C'}),
        sourceRound: 1,
        accepted: true,
      );

      await store.saveAcceptedDeltas(
        projectId: 'proj-2',
        chapterId: 'ch-1',
        sceneId: 'sc-1',
        tier: MemoryTier.scene,
        producer: 'narrator',
        deltas: [publicDelta, privateDelta],
      );

      final loaded = await store.loadPublicMemories(
        projectId: 'proj-2',
        tier: MemoryTier.scene,
      );

      expect(loaded, hasLength(1));
      expect(loaded.first.deltaId, 'pub-1');
    });

    test('does not return public deltas from a different tier', () async {
      final delta = CharacterMemoryDelta(
        deltaId: 'pub-2',
        characterId: '',
        kind: CharacterMemoryDeltaKind.worldFact,
        content: 'The kingdom fell.',
        acl: VisibilityAcl.public(),
        sourceRound: 1,
        accepted: true,
      );

      await store.saveAcceptedDeltas(
        projectId: 'proj-2',
        chapterId: 'ch-1',
        sceneId: 'sc-1',
        tier: MemoryTier.character,
        producer: 'narrator',
        deltas: [delta],
      );

      final loaded = await store.loadPublicMemories(
        projectId: 'proj-2',
        tier: MemoryTier.scene,
      );

      expect(loaded, isEmpty);
    });
  });

  group('migration', () {
    test('adds tier and producer columns with defaults to legacy table', () async {
      // Simulate legacy schema without tier/producer.
      db.execute('''
        CREATE TABLE character_memories (
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

      final legacyData = jsonEncode(CharacterMemoryDelta(
        deltaId: 'legacy-1',
        characterId: 'char-X',
        kind: CharacterMemoryDeltaKind.belief,
        content: 'Old belief.',
        acl: VisibilityAcl.characters({'char-X'}),
        sourceRound: 1,
        accepted: true,
      ).toJson());

      db.execute(
        '''
        INSERT INTO character_memories (
          id, project_id, chapter_id, scene_id, character_id, kind, content,
          source_round, source_turn_id, confidence, data
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          'proj-m:ch-m:sc-m:legacy-1',
          'proj-m',
          'ch-m',
          'sc-m',
          'char-X',
          'belief',
          'Old belief.',
          1,
          '',
          1.0,
          legacyData,
        ],
      );

      // Run migration via ensureTables.
      await store.ensureTables();

      final rows = db.select(
        'SELECT tier, producer FROM character_memories WHERE id = ?',
        ['proj-m:ch-m:sc-m:legacy-1'],
      );
      expect(rows, hasLength(1));
      expect(rows.first['tier'], 'character');
      expect(rows.first['producer'], '');
    });
  });

  group('export/import', () {
    test('exportProjectJson includes tier and producer; importProjectJson preserves them', () async {
      final delta = CharacterMemoryDelta(
        deltaId: 'exp-1',
        characterId: 'char-Y',
        kind: CharacterMemoryDeltaKind.emotion,
        content: 'A wave of nostalgia.',
        acl: VisibilityAcl.characters({'char-Y'}),
        sourceRound: 2,
        sourceTurnId: 'turn-2',
        confidence: 0.8,
        accepted: true,
      );

      await store.saveAcceptedDeltas(
        projectId: 'proj-e',
        chapterId: 'ch-e',
        sceneId: 'sc-e',
        tier: MemoryTier.character,
        producer: 'roleplay',
        deltas: [delta],
      );

      final exported = await store.exportProjectJson('proj-e');
      expect(exported, isNotNull);
      final memories = exported!['memories'] as List;
      expect(memories, hasLength(1));
      expect(memories.first['tier'], 'character');
      expect(memories.first['producer'], 'roleplay');

      // Import into a fresh database.
      final db2 = sqlite3.openInMemory();
      final store2 = CharacterMemoryStoreIO(db: db2);
      try {
        await store2.importProjectJson('proj-e', exported);

        final loaded = await store2.loadCharacterMemories(
          projectId: 'proj-e',
          characterId: 'char-Y',
          tier: MemoryTier.character,
        );
        expect(loaded, hasLength(1));
        expect(loaded.first.deltaId, 'exp-1');
        expect(loaded.first.content, 'A wave of nostalgia.');

        // Verify tier persisted through round-trip.
        final rows = db2.select(
          'SELECT tier, producer FROM character_memories WHERE id = ?',
          ['proj-e:ch-e:sc-e:exp-1'],
        );
        expect(rows.first['tier'], 'character');
        expect(rows.first['producer'], 'roleplay');
      } finally {
        db2.dispose();
      }
    });
  });
}
