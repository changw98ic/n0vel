import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/rag/hybrid_retriever.dart';
import 'package:novel_writer/app/rag/local_rag_storage.dart';
import 'package:novel_writer/app/rag/sqlite_vss_store.dart';
import 'package:novel_writer/app/rag/vector_store_schema.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/memory_policy.dart';
import 'package:novel_writer/features/story_generation/domain/memory_models.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('HybridRetriever project replacement', () {
    late Database db;
    late HybridRetriever retriever;

    setUp(() {
      db = sqlite3.openInMemory();
      retriever = HybridRetriever.local(db: db);
    });

    tearDown(() => db.dispose());

    test(
      'repeated sync removes stale vectors and preserves other projects',
      () async {
        await retriever.syncProject(
          projectId: 'project-a',
          characterProfiles: const ['hero one', 'hero two', 'hero three'],
          outlineBeats: const ['old outline'],
          worldFacts: const ['old fact one', 'old fact two'],
          chapterContents: const ['old chapter'],
        );
        await retriever.syncProject(
          projectId: 'project-b',
          characterProfiles: const ['preserved hero'],
          outlineBeats: const [],
          worldFacts: const ['preserved world'],
        );

        await retriever.syncProject(
          projectId: 'project-a',
          characterProfiles: const ['replacement hero'],
          outlineBeats: const [],
          worldFacts: const [],
        );
        await retriever.syncProject(
          projectId: 'project-a',
          characterProfiles: const ['replacement hero'],
          outlineBeats: const [],
          worldFacts: const [],
        );

        expect(_vectorIds(db, 'project-a'), ['project-a/characters/char_0.md']);
        expect(_documentPaths(db, 'project-a'), [
          'project-a/characters/char_0.md',
        ]);
        expect(_vectorIds(db, 'project-b'), [
          'project-b/characters/char_0.md',
          'project-b/worldbuilding/fact_0.md',
        ]);
        expect(_documentPaths(db, 'project-b'), [
          'project-b/characters/char_0.md',
          'project-b/worldbuilding/fact_0.md',
        ]);
        expect(
          _count(
            db,
            vectorLshBucketsTable,
            where: 'project_id = ?',
            parameters: const ['project-a'],
          ),
          vectorLshTableCount,
        );
        expect(
          _count(
            db,
            vectorLshBucketsTable,
            where: 'project_id = ?',
            parameters: const ['project-b'],
          ),
          2 * vectorLshTableCount,
        );
      },
    );

    test(
      'embedding failure leaves the previous project index intact',
      () async {
        var rejectReplacement = false;
        final guardedRetriever = HybridRetriever(
          ftsStorage: LocalRagStorage(db: db),
          vectorStore: SqliteVssStore(db),
          embeddingForText: (text) {
            if (rejectReplacement && text.contains('replacement')) {
              throw StateError('embedding failed');
            }
            return HybridRetriever.defaultEmbedding(text);
          },
        );
        await guardedRetriever.syncProject(
          projectId: 'project-a',
          characterProfiles: const ['stable hero'],
          outlineBeats: const ['stable outline'],
          worldFacts: const [],
        );
        final vectorIdsBefore = _vectorIds(db, 'project-a');
        final documentPathsBefore = _documentPaths(db, 'project-a');
        final bucketCountBefore = _count(
          db,
          vectorLshBucketsTable,
          where: 'project_id = ?',
          parameters: const ['project-a'],
        );

        rejectReplacement = true;
        await expectLater(
          guardedRetriever.syncProject(
            projectId: 'project-a',
            characterProfiles: const ['replacement hero'],
            outlineBeats: const [],
            worldFacts: const [],
          ),
          throwsStateError,
        );

        expect(_vectorIds(db, 'project-a'), vectorIdsBefore);
        expect(_documentPaths(db, 'project-a'), documentPathsBefore);
        expect(
          _count(
            db,
            vectorLshBucketsTable,
            where: 'project_id = ?',
            parameters: const ['project-a'],
          ),
          bucketCountBefore,
        );
      },
    );

    test(
      'non-shared databases reject replacement before changing FTS or vectors',
      () async {
        final ftsDb = sqlite3.openInMemory();
        final vectorDb = sqlite3.openInMemory();
        addTearDown(ftsDb.dispose);
        addTearDown(vectorDb.dispose);
        final ftsStorage = LocalRagStorage(db: ftsDb);
        final vectorStore = SqliteVssStore(vectorDb);
        await ftsStorage.indexDocument(
          projectId: 'project-a',
          path: 'project-a/stable.md',
          content: 'stable FTS content',
          category: 'worldFact',
        );
        await vectorStore.upsert(
          id: 'stable-vector',
          projectId: 'project-a',
          content: 'stable vector content',
          embedding: const [1.0, 0.0],
          tier: MemoryTier.scene,
          metadata: const {'projectId': 'project-a'},
        );
        final documentPathsBefore = _documentPaths(ftsDb, 'project-a');
        final vectorIdsBefore = _vectorIds(vectorDb, 'project-a');
        var embeddingCalls = 0;
        final splitRetriever = HybridRetriever(
          ftsStorage: ftsStorage,
          vectorStore: vectorStore,
          embeddingForText: (text) async {
            embeddingCalls++;
            return const [0.0, 1.0];
          },
        );

        await expectLater(
          splitRetriever.syncProject(
            projectId: 'project-a',
            characterProfiles: const ['replacement hero'],
            outlineBeats: const [],
            worldFacts: const [],
          ),
          throwsStateError,
        );

        expect(embeddingCalls, 0);
        expect(_documentPaths(ftsDb, 'project-a'), documentPathsBefore);
        expect(_vectorIds(vectorDb, 'project-a'), vectorIdsBefore);
      },
    );

    test(
      'incremental index and project sync prepare concurrently then commit consistently',
      () async {
        final incrementalStarted = Completer<void>();
        final syncStarted = Completer<void>();
        final releaseEmbeddings = Completer<void>();
        final concurrentRetriever = HybridRetriever.local(
          db: db,
          embeddingForText: (text) async {
            if (text == 'incremental-memory') {
              incrementalStarted.complete();
              await releaseEmbeddings.future;
            } else if (text == 'replacement-memory') {
              syncStarted.complete();
              await releaseEmbeddings.future;
            }
            return HybridRetriever.defaultEmbedding(text);
          },
        );

        final incremental = concurrentRetriever.indexChunks(const [
          StoryMemoryChunk(
            id: 'project-a/incremental.md',
            projectId: 'project-a',
            scopeId: 'project-a',
            kind: MemorySourceKind.sceneSummary,
            content: 'incremental-memory',
          ),
        ]);
        final sync = concurrentRetriever.syncProject(
          projectId: 'project-a',
          characterProfiles: const ['replacement-memory'],
          outlineBeats: const [],
          worldFacts: const [],
        );
        await Future.wait(<Future<void>>[
          incrementalStarted.future,
          syncStarted.future,
        ]);
        releaseEmbeddings.complete();
        await Future.wait(<Future<void>>[incremental, sync]);

        final vectorIds = _vectorIds(db, 'project-a').toSet();
        final documentPaths = _documentPaths(db, 'project-a').toSet();
        expect(vectorIds, documentPaths);
        expect(
          vectorIds,
          anyOf(
            <String>{'project-a/characters/char_0.md'},
            <String>{
              'project-a/characters/char_0.md',
              'project-a/incremental.md',
            },
          ),
        );
        expect(
          _count(
            db,
            vectorLshBucketsTable,
            where: 'project_id = ?',
            parameters: const ['project-a'],
          ),
          vectorIds.length * vectorLshTableCount,
        );
      },
    );
  });
}

List<String> _vectorIds(Database db, String projectId) => db
    .select(
      '''SELECT id FROM $vectorEmbeddingsTable
        WHERE project_id = ? ORDER BY id''',
      [projectId],
    )
    .map((row) => row['id'] as String)
    .toList();

List<String> _documentPaths(Database db, String projectId) => db
    .select(
      'SELECT path FROM rag_documents WHERE project_id = ? ORDER BY path',
      [projectId],
    )
    .map((row) => row['path'] as String)
    .toList();

int _count(
  Database db,
  String table, {
  required String where,
  required List<Object?> parameters,
}) =>
    db
            .select(
              'SELECT COUNT(*) AS count FROM $table WHERE $where',
              parameters,
            )
            .single['count']
        as int;
