import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/app/state/authoring_db_schema.dart';
import 'package:novel_writer/app/state/db_schema_manager.dart';
import 'package:novel_writer/app/rag/hybrid_retriever.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/memory_policy.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/rag_retrieval_policy.dart';
import 'package:novel_writer/features/story_generation/domain/memory_models.dart';
import 'package:novel_writer/features/story_generation/data/story_memory_storage_stub.dart';
import 'package:novel_writer/features/story_generation/data/story_memory_storage_io.dart';
import 'package:novel_writer/features/story_generation/data/story_memory_storage.dart';

void main() {
  group('stub storage', () {
    late StoryMemoryStorage storage;

    setUp(() {
      storage = StoryMemoryStorageStub();
    });

    test('save and load sources by project', () async {
      const sources = [
        StoryMemorySource(
          id: 'src-1',
          projectId: 'proj-a',
          scopeId: 'scene-1',
          kind: MemorySourceKind.worldFact,
          content: 'Dragons sleep in winter.',
          createdAtMs: 100,
        ),
        StoryMemorySource(
          id: 'src-2',
          projectId: 'proj-a',
          scopeId: 'scene-2',
          kind: MemorySourceKind.characterProfile,
          content: 'Mei is a healer.',
          createdAtMs: 200,
        ),
      ];
      await storage.saveSources('proj-a', sources);
      final loaded = await storage.loadSources('proj-a');
      expect(loaded.length, 2);
      // Sorted by createdAtMs then id
      expect(loaded.first.id, 'src-1');
      expect(loaded.last.id, 'src-2');
    });

    test('save and load chunks by project', () async {
      const chunks = [
        StoryMemoryChunk(
          id: 'chunk-2',
          projectId: 'proj-a',
          scopeId: 'scene-2',
          kind: MemorySourceKind.outlineBeat,
          content: 'The hero enters the cave.',
          createdAtMs: 300,
        ),
        StoryMemoryChunk(
          id: 'chunk-1',
          projectId: 'proj-a',
          scopeId: 'scene-1',
          kind: MemorySourceKind.worldFact,
          content: 'Caves are damp.',
          createdAtMs: 200,
        ),
      ];
      await storage.saveChunks('proj-a', chunks);
      final loaded = await storage.loadChunks('proj-a');
      expect(loaded.length, 2);
      expect(loaded.first.id, 'chunk-1');
      expect(loaded.first.createdAtMs, 200);
    });

    test('save and load thoughts by project', () async {
      const thoughts = [
        ThoughtAtom(
          id: 'thought-1',
          projectId: 'proj-a',
          scopeId: 'scene-1',
          thoughtType: ThoughtType.persona,
          content: 'Hero is brave.',
          confidence: 0.9,
          sourceRefs: [
            MemorySourceRef(
              sourceId: 's1',
              sourceType: MemorySourceKind.sceneSummary,
            ),
          ],
          rootSourceIds: ['s1'],
          createdAtMs: 100,
        ),
      ];
      await storage.saveThoughts('proj-a', thoughts);
      final loaded = await storage.loadThoughts('proj-a');
      expect(loaded.length, 1);
      expect(loaded.first.thoughtType, ThoughtType.persona);
      expect(loaded.first.rootSourceIds, contains('s1'));
    });

    test('clear memory by project', () async {
      await storage.saveSources('proj-a', [
        const StoryMemorySource(
          id: 'src-1',
          projectId: 'proj-a',
          scopeId: 's1',
          kind: MemorySourceKind.worldFact,
          content: 'test',
        ),
      ]);
      await storage.saveSources('proj-b', [
        const StoryMemorySource(
          id: 'src-2',
          projectId: 'proj-b',
          scopeId: 's1',
          kind: MemorySourceKind.worldFact,
          content: 'other',
        ),
      ]);
      await storage.clearProject('proj-a');
      final a = await storage.loadSources('proj-a');
      final b = await storage.loadSources('proj-b');
      expect(a, isEmpty);
      expect(b, isNotEmpty);
    });

    test('preserve source traces through save/load', () async {
      const source = StoryMemorySource(
        id: 'src-trace',
        projectId: 'proj-a',
        scopeId: 'scene-1',
        kind: MemorySourceKind.acceptedState,
        content: 'Key is lost.',
        sourceRefs: [
          MemorySourceRef(
            sourceId: 'ch1:sc1',
            sourceType: MemorySourceKind.sceneSummary,
          ),
          MemorySourceRef(
            sourceId: 'ch1:sc2',
            sourceType: MemorySourceKind.acceptedState,
          ),
        ],
        rootSourceIds: ['ch1:sc1', 'ch1:sc2'],
      );
      await storage.saveSources('proj-a', [source]);
      final loaded = await storage.loadSources('proj-a');
      expect(loaded.first.sourceRefs.length, 2);
      expect(loaded.first.rootSourceIds, containsAll(['ch1:sc1', 'ch1:sc2']));
    });
  });

  group('sqlite storage', () {
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'novel_writer_memory_io_test',
      );
      dbPath = '${tempDir.path}/memory.db';
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    StoryMemoryStorageIO openStorage() {
      final db = sqlite3.open(dbPath);
      return StoryMemoryStorageIO(db: db);
    }

    test('records survive store reconstruction', () async {
      const source = StoryMemorySource(
        id: 'src-1',
        projectId: 'proj-x',
        scopeId: 'scene-1',
        kind: MemorySourceKind.worldFact,
        content: 'Magic requires a catalyst stone.',
        sourceRefs: [
          MemorySourceRef(
            sourceId: 'world-1',
            sourceType: MemorySourceKind.worldFact,
          ),
        ],
        rootSourceIds: ['world-1'],
        tags: ['magic'],
        priority: 3,
        tokenCostEstimate: 12,
        createdAtMs: 1777046400000,
      );
      await (openStorage()).saveSources('proj-x', [source]);

      final loaded = await (openStorage()).loadSources('proj-x');
      expect(loaded.length, 1);
      expect(loaded.first.id, 'src-1');
      expect(loaded.first.content, 'Magic requires a catalyst stone.');
      expect(loaded.first.sourceRefs.single.sourceId, 'world-1');
      expect(loaded.first.rootSourceIds, contains('world-1'));
      expect(loaded.first.tags, contains('magic'));
      expect(loaded.first.priority, 3);
    });

    test('different projects are isolated', () async {
      final s = openStorage();
      await s.saveSources('proj-a', [
        const StoryMemorySource(
          id: 'src-a',
          projectId: 'proj-a',
          scopeId: 's1',
          kind: MemorySourceKind.worldFact,
          content: 'Project A fact',
        ),
      ]);
      await s.saveSources('proj-b', [
        const StoryMemorySource(
          id: 'src-b',
          projectId: 'proj-b',
          scopeId: 's1',
          kind: MemorySourceKind.worldFact,
          content: 'Project B fact',
        ),
      ]);

      final a = await s.loadSources('proj-a');
      final b = await s.loadSources('proj-b');
      expect(a.length, 1);
      expect(a.first.id, 'src-a');
      expect(b.length, 1);
      expect(b.first.id, 'src-b');
    });

    test('thoughts keep rootSourceIds through persistence', () async {
      const thought = ThoughtAtom(
        id: 'thought-1',
        projectId: 'proj-x',
        scopeId: 'scene-1',
        thoughtType: ThoughtType.plotCausality,
        content: 'The key was stolen by the shadow agent.',
        confidence: 0.91,
        abstractionLevel: 2.5,
        sourceRefs: [
          MemorySourceRef(
            sourceId: 'scene-1',
            sourceType: MemorySourceKind.sceneSummary,
          ),
        ],
        rootSourceIds: ['scene-1:beat-3', 'scene-1:beat-4'],
        tags: ['plot', 'key'],
        priority: 5,
        tokenCostEstimate: 22,
        createdAtMs: 1777046500000,
      );
      await (openStorage()).saveThoughts('proj-x', [thought]);

      final loaded = await (openStorage()).loadThoughts('proj-x');
      expect(loaded.length, 1);
      expect(
        loaded.first.rootSourceIds,
        containsAll(['scene-1:beat-3', 'scene-1:beat-4']),
      );
      expect(loaded.first.confidence, 0.91);
      expect(loaded.first.abstractionLevel, 2.5);
      expect(loaded.first.thoughtType, ThoughtType.plotCausality);
    });

    test('clearing one project does not clear another', () async {
      final s = openStorage();
      await s.saveSources('proj-a', [
        const StoryMemorySource(
          id: 'src-a',
          projectId: 'proj-a',
          scopeId: 's1',
          kind: MemorySourceKind.worldFact,
          content: 'A fact',
        ),
      ]);
      await s.saveChunks('proj-a', [
        const StoryMemoryChunk(
          id: 'chunk-a',
          projectId: 'proj-a',
          scopeId: 's1',
          kind: MemorySourceKind.worldFact,
          content: 'A chunk',
        ),
      ]);
      await s.saveSources('proj-b', [
        const StoryMemorySource(
          id: 'src-b',
          projectId: 'proj-b',
          scopeId: 's1',
          kind: MemorySourceKind.characterProfile,
          content: 'B fact',
        ),
      ]);
      await s.saveThoughts('proj-b', [
        const ThoughtAtom(
          id: 'thought-b',
          projectId: 'proj-b',
          scopeId: 's1',
          thoughtType: ThoughtType.persona,
          content: 'B thought',
          confidence: 0.8,
        ),
      ]);

      await s.clearProject('proj-a');

      final aSources = await s.loadSources('proj-a');
      final aChunks = await s.loadChunks('proj-a');
      final bSources = await s.loadSources('proj-b');
      final bThoughts = await s.loadThoughts('proj-b');

      expect(aSources, isEmpty);
      expect(aChunks, isEmpty);
      expect(bSources.length, 1);
      expect(bSources.first.id, 'src-b');
      expect(bThoughts.length, 1);
      expect(bThoughts.first.id, 'thought-b');
    });

    test(
      'new table has tier and producer columns plus idx_memory_tier',
      () async {
        final s = openStorage();
        await s.ensureTables();

        final cols = sqlite3
            .open(dbPath)
            .select(
              "SELECT name FROM pragma_table_info('story_memory_chunks')",
            );
        final colNames = {for (final r in cols) r['name'] as String};
        expect(colNames, containsAll(['tier', 'producer']));
        expect(colNames, isNot(contains('owner_id')));

        final idxRows = sqlite3
            .open(dbPath)
            .select(
              "SELECT name FROM pragma_index_list('story_memory_chunks')",
            );
        final idxNames = {for (final r in idxRows) r['name'] as String};
        expect(idxNames, contains('idx_memory_tier'));
      },
    );

    test('old table without tier/producer columns gets migrated', () async {
      // Create a legacy table without tier/producer columns.
      final raw = sqlite3.open(dbPath);
      raw.execute('''
        CREATE TABLE story_memory_chunks (
          id TEXT PRIMARY KEY,
          project_id TEXT NOT NULL,
          data TEXT NOT NULL
        )
      ''');
      raw.execute(
        'INSERT INTO story_memory_chunks (id, project_id, data) VALUES (?, ?, ?)',
        [
          'old-1',
          'proj-m',
          '{"id":"old-1","projectId":"proj-m","scopeId":"s1","kind":"worldFact","content":"legacy"}',
        ],
      );
      raw.dispose();

      // Opening storage triggers migration.
      final s = openStorage();
      await s.saveChunks('proj-m', [
        const StoryMemoryChunk(
          id: 'new-1',
          projectId: 'proj-m',
          scopeId: 's1',
          kind: MemorySourceKind.worldFact,
          content: 'migrated row',
          tier: MemoryTier.canon,
          producer: 'review',
        ),
      ]);

      final loaded = await s.loadChunks('proj-m');
      expect(loaded.length, 2);
      final byId = {for (final c in loaded) c.id: c};
      // Old row loaded via JSON (no tier/producer in JSON → defaults).
      expect(byId['old-1']!.tier, MemoryTier.scene);
      expect(byId['old-1']!.producer, '');
      // New row has explicit tier/producer.
      expect(byId['new-1']!.tier, MemoryTier.canon);
      expect(byId['new-1']!.producer, 'review');
    });

    test(
      'saved chunk rows persist tier and producer in columns and model',
      () async {
        final s = openStorage();
        await s.saveChunks('proj-t', [
          const StoryMemoryChunk(
            id: 'c-1',
            projectId: 'proj-t',
            scopeId: 's1',
            kind: MemorySourceKind.sceneSummary,
            content: 'The dragon awakens.',
            tier: MemoryTier.character,
            producer: 'scene-agent',
          ),
          const StoryMemoryChunk(
            id: 'c-2',
            projectId: 'proj-t',
            scopeId: 's2',
            kind: MemorySourceKind.outlineBeat,
            content: 'Hero retreats.',
            tier: MemoryTier.scene,
            producer: '',
          ),
        ]);

        // Verify row-level columns directly.
        final raw = sqlite3.open(dbPath);
        final rows = raw.select(
          'SELECT id, tier, producer FROM story_memory_chunks WHERE project_id = ? ORDER BY id',
          ['proj-t'],
        );
        expect(rows.length, 2);
        expect(rows[0]['tier'], 'character');
        expect(rows[0]['producer'], 'scene-agent');
        expect(rows[1]['tier'], 'scene');
        expect(rows[1]['producer'], '');
        raw.dispose();

        // Verify model round-trip.
        final loaded = await s.loadChunks('proj-t');
        expect(loaded.first.tier, MemoryTier.character);
        expect(loaded.first.producer, 'scene-agent');
        expect(loaded.last.tier, MemoryTier.scene);
        expect(loaded.last.producer, '');

        // Upsert changes tier and producer.
        await s.saveChunks('proj-t', [
          const StoryMemoryChunk(
            id: 'c-1',
            projectId: 'proj-t',
            scopeId: 's1',
            kind: MemorySourceKind.sceneSummary,
            content: 'The dragon sleeps.',
            tier: MemoryTier.canon,
            producer: 'review-pass',
          ),
        ]);
        final updated = await s.loadChunks('proj-t');
        expect(updated.firstWhere((c) => c.id == 'c-1').tier, MemoryTier.canon);
        expect(
          updated.firstWhere((c) => c.id == 'c-1').producer,
          'review-pass',
        );
      },
    );

    test('upsert updates existing records', () async {
      final s = openStorage();
      await s.saveChunks('proj-x', [
        const StoryMemoryChunk(
          id: 'chunk-1',
          projectId: 'proj-x',
          scopeId: 's1',
          kind: MemorySourceKind.worldFact,
          content: 'Original content',
          priority: 1,
          createdAtMs: 100,
        ),
      ]);

      await s.saveChunks('proj-x', [
        const StoryMemoryChunk(
          id: 'chunk-1',
          projectId: 'proj-x',
          scopeId: 's1',
          kind: MemorySourceKind.worldFact,
          content: 'Updated content',
          priority: 5,
          createdAtMs: 100,
        ),
      ]);

      final loaded = await s.loadChunks('proj-x');
      expect(loaded.length, 1);
      expect(loaded.first.content, 'Updated content');
      expect(loaded.first.priority, 5);
    });

    test('round-trips records through the central authoring schema', () async {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);
      DatabaseSchemaManager(
        migrations: authoringSchemaMigrations,
      ).ensureSchema(db);
      final storage = StoryMemoryStorageIO(db: db);

      const source = StoryMemorySource(
        id: 'central-source',
        projectId: 'central-project',
        scopeId: 'scene-7',
        kind: MemorySourceKind.characterProfile,
        content: 'Lin never lies to her sister.',
        sourceRefs: [
          MemorySourceRef(
            sourceId: 'character-lin',
            sourceType: MemorySourceKind.characterProfile,
          ),
        ],
        rootSourceIds: ['character-lin'],
        visibility: MemoryVisibility.agentPrivate,
        ownerId: 'source-owner',
        tags: ['lin'],
        priority: 4,
        tokenCostEstimate: 9,
        createdAtMs: 123,
      );
      const chunk = StoryMemoryChunk(
        id: 'central-chunk',
        projectId: 'central-project',
        scopeId: 'scene-7',
        kind: MemorySourceKind.sceneSummary,
        content: 'Lin withholds the map but tells no direct lie.',
        tier: MemoryTier.character,
        producer: 'scene-review',
        sourceRefs: [
          MemorySourceRef(
            sourceId: 'central-source',
            sourceType: MemorySourceKind.characterProfile,
          ),
        ],
        rootSourceIds: ['character-lin'],
        visibility: MemoryVisibility.agentPrivate,
        ownerId: 'chunk-owner',
        tags: ['map'],
        priority: 5,
        tokenCostEstimate: 11,
        createdAtMs: 456,
      );
      const thought = ThoughtAtom(
        id: 'central-thought',
        projectId: 'central-project',
        scopeId: 'scene-7',
        thoughtType: ThoughtType.persona,
        content: 'Lin protects family promises through careful omission.',
        tier: MemoryTier.canon,
        confidence: 0.93,
        abstractionLevel: 2.0,
        sourceRefs: [
          MemorySourceRef(
            sourceId: 'central-chunk',
            sourceType: MemorySourceKind.sceneSummary,
          ),
        ],
        rootSourceIds: ['character-lin'],
        tags: ['promise'],
        priority: 6,
        tokenCostEstimate: 13,
        createdAtMs: 789,
      );

      await storage.saveSources('central-project', [source]);
      await storage.saveChunks('central-project', [chunk]);
      await storage.saveThoughts('central-project', [thought]);

      expect(
        (await storage.loadSources('central-project')).single.toJson(),
        source.toJson(),
      );
      expect(
        (await storage.loadChunks('central-project')).single.toJson(),
        chunk.toJson(),
      );
      expect(
        (await storage.loadThoughts('central-project')).single.toJson(),
        thought.toJson(),
      );
      expect(
        db.select('SELECT raw_content FROM story_memory_sources WHERE id = ?', [
          'central-source',
        ]).single['raw_content'],
        source.content,
      );
      expect(
        db.select('SELECT owner_id FROM story_memory_chunks WHERE id = ?', [
          'central-chunk',
        ]).single['owner_id'],
        'chunk-owner',
      );

      await storage.clearProject('central-project');
      expect(await storage.loadSources('central-project'), isEmpty);
      expect(await storage.loadChunks('central-project'), isEmpty);
      expect(await storage.loadThoughts('central-project'), isEmpty);
    });

    test(
      'direct normalized V26 storage runs the complete V27 migration',
      () async {
        final database = sqlite3.open(dbPath);
        addTearDown(database.dispose);
        final v26Migrations = authoringSchemaMigrations
            .where((migration) => migration.version <= 26)
            .toList(growable: false);
        DatabaseSchemaManager(migrations: v26Migrations).ensureSchema(database);
        // Fresh table declarations reflect the latest layout; make this an
        // actual V26 fixture before exercising the V27 migration authority.
        database.execute(
          'ALTER TABLE story_memory_chunks DROP COLUMN owner_id',
        );

        final storage = StoryMemoryStorageIO(db: database);
        await storage.ensureTables();

        expect(
          database.select('PRAGMA user_version').single['user_version'],
          27,
        );
        expect(
          database
              .select(
                "SELECT name FROM pragma_table_info('story_memory_chunks')",
              )
              .map((row) => row['name']),
          contains('owner_id'),
        );
        expect(
          database
              .select(
                'SELECT min_reader_version, min_writer_version '
                'FROM schema_compatibility_contracts '
                'WHERE schema_version = 27',
              )
              .single
              .values,
          <Object?>[27, 27],
        );
      },
    );

    test(
      'direct partial V26 storage rejects without installing owner_id',
      () async {
        final database = sqlite3.open(dbPath);
        addTearDown(database.dispose);
        database.execute('''
          CREATE TABLE story_memory_chunks (
            id TEXT PRIMARY KEY,
            project_id TEXT NOT NULL,
            scope_id TEXT NOT NULL,
            content TEXT NOT NULL
          )
        ''');
        database.execute('PRAGMA user_version = 26');

        final storage = StoryMemoryStorageIO(db: database);
        await expectLater(
          storage.ensureTables(),
          throwsA(isA<SqliteException>()),
        );

        expect(
          database.select('PRAGMA user_version').single['user_version'],
          26,
        );
        expect(
          database
              .select(
                "SELECT name FROM pragma_table_info('story_memory_chunks')",
              )
              .map((row) => row['name']),
          isNot(contains('owner_id')),
        );
      },
    );

    test(
      'normalized private owner survives reopen and remains fail-closed',
      () async {
        var database = sqlite3.open(dbPath);
        DatabaseSchemaManager(
          migrations: authoringSchemaMigrations,
        ).ensureSchema(database);
        var storage = StoryMemoryStorageIO(db: database);
        await storage.saveChunks('private-project', [
          const StoryMemoryChunk(
            id: 'private-chunk',
            projectId: 'private-project',
            scopeId: 'private-scene',
            kind: MemorySourceKind.characterProfile,
            content: 'alpha private promise',
            visibility: MemoryVisibility.agentPrivate,
            ownerId: 'alice',
          ),
        ]);
        database.dispose();

        database = sqlite3.open(dbPath);
        addTearDown(database.dispose);
        DatabaseSchemaManager(
          migrations: authoringSchemaMigrations,
        ).ensureSchema(database);
        storage = StoryMemoryStorageIO(db: database);
        final persisted = await storage.loadChunks('private-project');
        expect(persisted.single.ownerId, 'alice');

        final retriever = HybridRetriever.local(db: database);
        await retriever.indexChunks(persisted);
        const policy = RagRetrievalPolicy(
          roleId: 'test',
          allowedTiers: [MemoryTier.scene],
          rankingStrategy: RankingStrategy.semantic,
        );
        Future<List<String>> retrieveAs(String viewerId) async => [
          for (final hit in (await retriever.retrieve(
            StoryMemoryQuery(
              projectId: 'private-project',
              queryType: StoryMemoryQueryType.persona,
              text: 'alpha private promise',
              scopeId: 'private-scene',
              viewerId: viewerId,
            ),
            policy,
          )).hits)
            hit.chunk.id,
        ];

        expect(await retrieveAs('alice'), ['private-chunk']);
        expect(await retrieveAs('bob'), isEmpty);
        expect(await retrieveAs(''), isEmpty);
      },
    );
  });
}
