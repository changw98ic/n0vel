import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/app/rag/local_rag_storage.dart';
import 'package:novel_writer/app/rag/hybrid_retriever.dart';
import 'package:novel_writer/app/rag/sqlite_vss_store.dart';
import 'package:novel_writer/app/rag/vector_store.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/memory_policy.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/rag_retrieval_policy.dart';
import 'package:novel_writer/features/story_generation/domain/memory_models.dart';

void main() {
  group('RAG SQL admission', () {
    late Database db;
    late LocalRagStorage fts;
    late SqliteVssStore vectors;

    setUp(() {
      db = sqlite3.openInMemory();
      fts = LocalRagStorage(db: db);
      vectors = SqliteVssStore(db);
    });

    tearDown(() => db.dispose());

    test('blank required tag groups normalize to no constraint', () async {
      expect(
        normalizeRequiredTagGroups(const [
          ['  ', ''],
          [],
          [' clue ', 'clue', ' canon '],
        ]),
        const [
          ['canon', 'clue'],
        ],
      );

      await fts.indexDocument(
        projectId: 'project',
        path: 'untagged-fts',
        content: 'alpha clue',
        category: 'sceneSummary',
        metadata: const {
          'tier': 'scene',
          'visibility': 'publicObservable',
          'scopeId': 'chapter:1',
        },
      );
      await vectors.upsertAll(const [
        VectorStoreEntry(
          id: 'untagged-vector',
          projectId: 'project',
          content: 'alpha clue',
          embedding: [1, 0],
          tier: MemoryTier.scene,
          metadata: {'scopeId': 'chapter:1', 'visibility': 'publicObservable'},
        ),
      ]);
      const admission = RagAdmission(
        allowedTiers: {MemoryTier.scene},
        allowedScopeIds: ['chapter:1'],
        requiredTagGroups: [
          [' ', ''],
          [],
        ],
      );

      final lexical = await fts.searchFts(
        projectId: 'project',
        query: 'alpha',
        admission: admission,
      );
      final semantic = await vectors.searchDetailed(
        embedding: const [1, 0],
        projectId: 'project',
        tiers: const {MemoryTier.scene},
        admission: admission,
      );

      expect(lexical.map((hit) => hit.path), ['untagged-fts']);
      expect(semantic.hits.map((hit) => hit.id), ['untagged-vector']);
    });

    test(
      'more than 4096 ineligible high-score rows cannot starve Canon',
      () async {
        await fts.ensureTables();
        final document = db.prepare('''
        INSERT INTO rag_documents (
          path, content, project_id, category, tier, visibility, owner_id,
          scope_id, metadata
        ) VALUES (?, ?, 'project', 'sceneSummary', 'scene',
          'publicObservable', '', 'chapter:1', '{}')
      ''');
        try {
          for (var index = 0; index < 4097; index++) {
            document.execute(['draft-$index', 'dragon canon secret']);
          }
        } finally {
          document.dispose();
        }
        await fts.indexDocument(
          projectId: 'project',
          path: 'canon-rule',
          content: 'dragon canon secret: fire cannot harm the heir',
          category: 'worldFact',
          metadata: const {
            'tier': 'canon',
            'visibility': 'publicObservable',
            'scopeId': 'project',
            'tags': ['required-canon'],
          },
        );
        const admission = RagAdmission(
          allowedTiers: {MemoryTier.canon, MemoryTier.scene},
          allowedScopeIds: ['project', 'chapter:1'],
          requiredTagGroups: [
            ['required-canon'],
          ],
        );

        final lexical = await fts.searchFts(
          projectId: 'project',
          query: 'dragon canon secret',
          limit: 1,
          admission: admission,
        );
        expect(lexical.map((hit) => hit.path), ['canon-rule']);

        final entries = <VectorStoreEntry>[
          for (var index = 0; index < 4097; index++)
            VectorStoreEntry(
              id: 'vector-draft-$index',
              projectId: 'project',
              content: 'dragon canon secret',
              embedding: const [1, 0],
              tier: MemoryTier.scene,
              metadata: const {
                'scopeId': 'chapter:1',
                'visibility': 'publicObservable',
                'tags': <String>[],
              },
            ),
          const VectorStoreEntry(
            id: 'vector-canon-rule',
            projectId: 'project',
            content: 'fire cannot harm the heir',
            embedding: [0.8, 0.2],
            tier: MemoryTier.canon,
            metadata: {
              'scopeId': 'project',
              'visibility': 'publicObservable',
              'tags': ['required-canon'],
            },
          ),
        ];
        await vectors.upsertAll(entries);
        final semantic = await vectors.searchDetailed(
          embedding: const [1, 0],
          projectId: 'project',
          tiers: const {MemoryTier.canon, MemoryTier.scene},
          limit: 1,
          admission: admission,
        );
        expect(semantic.diagnostics.eligibleRows, 1);
        expect(semantic.hits.map((hit) => hit.id), ['vector-canon-rule']);
      },
    );

    test(
      'visibility, owner, explicit scope and group-wise tags are admitted',
      () async {
        await fts.indexDocument(
          projectId: 'project',
          path: 'private-alice',
          content: 'private clue',
          category: 'characterProfile',
          metadata: const {
            'tier': 'character',
            'visibility': 'agentPrivate',
            'ownerId': 'alice',
            'scopeId': 'ancestor',
            'tags': ['character', 'clue'],
          },
        );
        await fts.indexDocument(
          projectId: 'project',
          path: 'editor-note',
          content: 'editor clue',
          category: 'reviewFinding',
          metadata: const {
            'tier': 'canon',
            'visibility': 'editorOnly',
            'scopeId': 'ancestor',
            'tags': ['canon', 'clue'],
          },
        );
        const reader = RagAdmission(
          allowedTiers: {MemoryTier.character, MemoryTier.canon},
          viewerId: 'alice',
          allowedScopeIds: ['ancestor'],
          requiredTagGroups: [
            ['clue'],
            ['character', 'canon'],
          ],
        );
        final readerHits = await fts.searchFts(
          projectId: 'project',
          query: 'clue',
          admission: reader,
        );
        expect(readerHits.map((hit) => hit.path), ['private-alice']);

        const editor = RagAdmission(
          allowedTiers: {MemoryTier.character, MemoryTier.canon},
          viewerId: 'alice',
          viewerRole: MemoryViewerRole.editor,
          allowedScopeIds: ['ancestor'],
          requiredTagGroups: [
            ['clue'],
          ],
        );
        final editorHits = await fts.searchFts(
          projectId: 'project',
          query: 'clue',
          admission: editor,
        );
        expect(
          editorHits.map((hit) => hit.path),
          containsAll(['private-alice', 'editor-note']),
        );
      },
    );

    test(
      'query-level Canon reservation returns eligible Canon first',
      () async {
        final retriever = HybridRetriever.local(
          db: db,
          embeddingForText: (text) async =>
              text.contains('canon') ? const [0.5, 0.5] : const [1.0, 0.0],
        );
        await retriever.indexChunks(const [
          StoryMemoryChunk(
            id: 'scene-hit',
            projectId: 'project',
            scopeId: 'project',
            kind: MemorySourceKind.sceneSummary,
            content: 'scene clue',
            tier: MemoryTier.scene,
          ),
          StoryMemoryChunk(
            id: 'canon-hit',
            projectId: 'project',
            scopeId: 'project',
            kind: MemorySourceKind.worldFact,
            content: 'canon clue',
            tier: MemoryTier.canon,
            tags: ['canon'],
          ),
        ]);
        final pack = await retriever.retrieve(
          const StoryMemoryQuery(
            projectId: 'project',
            queryType: StoryMemoryQueryType.concreteFact,
            text: 'scene clue',
            scopeId: 'project',
            maxResults: 1,
            mustIncludeCanon: true,
          ),
          const RagRetrievalPolicy(
            roleId: 'test',
            allowedTiers: [MemoryTier.scene],
            rankingStrategy: RankingStrategy.semantic,
          ),
        );
        expect(pack.canonRequired, isTrue);
        expect(pack.canonAvailable, isTrue);
        expect(pack.hits.single.chunk.id, 'canon-hit');
      },
    );
  });
}
