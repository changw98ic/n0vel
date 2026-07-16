import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/rag/local_rag_storage.dart';
import 'package:novel_writer/app/rag/sqlite_vss_store.dart';
import 'package:novel_writer/app/rag/vector_store.dart';
import 'package:novel_writer/app/rag/vector_store_schema.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/memory_policy.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('populated RAG database reopen', () {
    late Directory tempDirectory;

    setUp(() {
      tempDirectory = Directory.systemTemp.createTempSync(
        'novel-writer-rag-reopen-',
      );
    });

    tearDown(() {
      if (tempDirectory.existsSync()) {
        tempDirectory.deleteSync(recursive: true);
      }
    });

    test(
      'vector schema reopen does not rewrite admission or LSH rows',
      () async {
        final path = '${tempDirectory.path}/vectors.sqlite';
        var db = sqlite3.open(path);
        var store = SqliteVssStore(db);
        await store.upsertAll(<VectorStoreEntry>[
          for (var index = 0; index < 32; index += 1)
            VectorStoreEntry(
              id: 'vector-$index',
              projectId: 'project-a',
              content: 'vector content $index',
              embedding: <double>[1, index / 32, 0, 0],
              tier: MemoryTier.scene,
              metadata: const <String, Object?>{
                'projectId': 'project-a',
                'scopeId': 'scope-a',
                'tags': <String>['chapter'],
              },
            ),
        ]);
        final expectedCounts = _vectorCounts(db);
        db.dispose();

        db = sqlite3.open(path);
        final changesBefore = _totalChanges(db);
        store = SqliteVssStore(db);
        final changesAfter = _totalChanges(db);

        expect(changesAfter - changesBefore, 0);
        expect(_vectorCounts(db), expectedCounts);
        await store.search(
          embedding: const <double>[1, 0, 0, 0],
          projectId: 'project-a',
          tiers: const <MemoryTier>{MemoryTier.scene},
        );
        db.dispose();
      },
    );

    test(
      'FTS schema reopen does not rewrite documents or rebuild indexes',
      () async {
        final path = '${tempDirectory.path}/fts.sqlite';
        var db = sqlite3.open(path);
        var storage = LocalRagStorage(db: db);
        for (var index = 0; index < 32; index += 1) {
          await storage.indexDocument(
            projectId: 'project-a',
            path: 'chapter-$index.md',
            content: '第$index章 港口 守夜人 dragon',
            category: 'sceneSummary',
            metadata: const <String, Object?>{
              'scopeId': 'scope-a',
              'tags': <String>['chapter'],
            },
          );
        }
        final expectedCounts = _documentCounts(db);
        db.dispose();

        db = sqlite3.open(path);
        final changesBefore = _totalChanges(db);
        storage = LocalRagStorage(db: db);
        await storage.ensureTables();
        final changesAfter = _totalChanges(db);

        expect(changesAfter - changesBefore, 0);
        expect(_documentCounts(db), expectedCounts);
        expect(
          await storage.searchFts(
            projectId: 'project-a',
            query: '港口',
            limit: 5,
          ),
          hasLength(5),
        );
        db.dispose();
      },
    );

    test(
      'missing side indexes are rebuilt in bounded migration batches',
      () async {
        final path = '${tempDirectory.path}/side-index-recovery.sqlite';
        var db = sqlite3.open(path);
        var storage = LocalRagStorage(db: db);
        final store = SqliteVssStore(db);
        const documentCount = LocalRagStorage.schemaMigrationBatchSize + 44;
        for (var index = 0; index < documentCount; index += 1) {
          await storage.indexDocument(
            projectId: 'project-a',
            path: 'chapter-$index.md',
            content: '第$index章 港口 ${String.fromCharCode(0x4e00 + index)}',
            category: 'sceneSummary',
            metadata: const <String, Object?>{
              'scopeId': 'scope-a',
              'tags': <String>['chapter'],
            },
          );
        }
        await store.upsertAll(<VectorStoreEntry>[
          for (var index = 0; index < documentCount; index += 1)
            VectorStoreEntry(
              id: 'vector-$index',
              projectId: 'project-a',
              content: 'vector content $index',
              embedding: <double>[1, index / documentCount, 0, 0],
              tier: MemoryTier.scene,
              metadata: const <String, Object?>{
                'scopeId': 'scope-a',
                'tags': <String>['chapter'],
              },
            ),
        ]);
        db.execute('DROP TABLE rag_document_tags');
        db.execute('DROP TABLE rag_fts');
        db.execute('DROP TABLE rag_cjk_fts');
        db.execute('DROP TABLE vector_embedding_tags');
        db.dispose();

        db = sqlite3.open(path);
        storage = LocalRagStorage(db: db);
        await storage.ensureTables();
        SqliteVssStore(db);

        expect(_documentCounts(db), <int>[
          documentCount,
          documentCount,
          documentCount,
          documentCount,
        ]);
        expect(
          db
              .select('SELECT COUNT(*) AS count FROM vector_embedding_tags')
              .single['count'],
          documentCount,
        );
        final recoveredHits = await storage.searchFts(
          projectId: 'project-a',
          query: String.fromCharCode(0x4e00 + documentCount - 1),
        );
        expect(
          recoveredHits.map((hit) => hit.path),
          contains('chapter-${documentCount - 1}.md'),
        );
        db.dispose();
      },
    );

    test('cleanup is project-scoped with foreign key cascades disabled', () async {
      final db = sqlite3.openInMemory();
      try {
        expect(db.select('PRAGMA foreign_keys').single.values.single, 0);
        final storage = LocalRagStorage(db: db);
        for (final projectId in <String>['project-a', 'project-b']) {
          await storage.indexDocument(
            projectId: projectId,
            path: 'shared.md',
            content: '$projectId shared chapter',
            category: 'sceneSummary',
            metadata: const <String, Object?>{
              'tags': <String>['shared'],
            },
          );
        }
        await storage.removeDocument('shared.md', projectId: 'project-a');
        expect(
          db
              .select(
                'SELECT project_id FROM rag_documents ORDER BY project_id',
              )
              .map((row) => row['project_id']),
          <String>['project-b'],
        );
        expect(
          db
              .select(
                'SELECT project_id FROM rag_document_tags ORDER BY project_id',
              )
              .map((row) => row['project_id']),
          <String>['project-b'],
        );
        await storage.clearProject('project-b');
        expect(db.select('SELECT * FROM rag_document_tags'), isEmpty);

        final store = SqliteVssStore(db);
        await store.upsertAll(<VectorStoreEntry>[
          for (final projectId in <String>['project-a', 'project-b'])
            VectorStoreEntry(
              id: 'shared',
              projectId: projectId,
              content: '$projectId shared vector',
              embedding: const <double>[1, 0, 0, 0],
              tier: MemoryTier.scene,
              metadata: const <String, Object?>{
                'tags': <String>['shared'],
              },
            ),
        ]);
        await store.delete('shared', projectId: 'project-a');
        expect(
          db
              .select(
                'SELECT project_id FROM vector_embedding_tags ORDER BY project_id',
              )
              .map((row) => row['project_id']),
          <String>['project-b'],
        );
        await store.clearProject('project-b');
        expect(db.select('SELECT * FROM vector_embedding_tags'), isEmpty);
      } finally {
        db.dispose();
      }
    });
  });
}

int _totalChanges(Database db) =>
    db.select('SELECT total_changes() AS count').single['count'] as int;

List<int> _vectorCounts(Database db) => <int>[
  db
          .select('SELECT COUNT(*) AS count FROM $vectorEmbeddingsTable')
          .single['count']
      as int,
  db
          .select('SELECT COUNT(*) AS count FROM $vectorLshBucketsTable')
          .single['count']
      as int,
  db
          .select('SELECT COUNT(*) AS count FROM vector_embedding_tags')
          .single['count']
      as int,
];

List<int> _documentCounts(Database db) => <int>[
  db.select('SELECT COUNT(*) AS count FROM rag_documents').single['count']
      as int,
  db.select('SELECT COUNT(*) AS count FROM rag_fts').single['count'] as int,
  db.select('SELECT COUNT(*) AS count FROM rag_cjk_fts').single['count'] as int,
  db.select('SELECT COUNT(*) AS count FROM rag_document_tags').single['count']
      as int,
];
