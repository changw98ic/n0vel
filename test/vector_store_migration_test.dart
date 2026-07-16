import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/rag/sqlite_vss_store.dart';
import 'package:novel_writer/app/rag/vector_store.dart';
import 'package:novel_writer/app/rag/vector_store_schema.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/memory_policy.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('vector store legacy migration', () {
    test(
      'migrates JSON vectors to indexed Float32 BLOB rows durably',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'novel_writer_vector_migration_',
        );
        final path = '${directory.path}/authoring.db';
        addTearDown(() async {
          if (await directory.exists()) {
            await directory.delete(recursive: true);
          }
        });

        var db = sqlite3.open(path);
        db.execute('PRAGMA user_version = 41');
        _createLegacyVectorTable(db);
        _insertLegacyRow(
          db,
          id: 'project-a/chapters/chapter-1',
          projectId: 'project-a',
          tier: 'scene',
          embedding: const [1.0, 0.0, 0.0, 0.0],
        );
        _insertLegacyRow(
          db,
          id: 'project-b/characters/hero',
          projectId: 'project-b',
          tier: 'character',
          embedding: const [0.0, 1.0, 0.0, 0.0],
        );

        ensureVectorStoreSchema(db);
        ensureVectorStoreSchema(db);

        expect(
          _columnNames(db),
          containsAll(<String>{
            'project_id',
            'embedding_blob',
            'dimension',
            'metadata_json',
          }),
        );
        expect(db.select('PRAGMA user_version').single['user_version'], 41);
        expect(
          db.select(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
            [vectorLshBucketsTable],
          ),
          hasLength(1),
        );
        expect(
          db.select(
            "SELECT name FROM sqlite_master WHERE type = 'index' AND name = ?",
            [vectorLshLookupIndex],
          ),
          hasLength(1),
        );

        final migratedRows = db.select('''
        SELECT id, project_id, tier, dimension, typeof(embedding_blob) AS kind,
               length(embedding_blob) AS byte_count, metadata_json
        FROM $vectorEmbeddingsTable
        ORDER BY id
      ''');
        expect(migratedRows, hasLength(2));
        expect(migratedRows.first['project_id'], 'project-a');
        expect(migratedRows.first['dimension'], 4);
        expect(migratedRows.first['kind'], 'blob');
        expect(
          migratedRows.first['byte_count'],
          4 * Float32List.bytesPerElement,
        );
        expect(
          jsonDecode(migratedRows.first['metadata_json'] as String),
          containsPair('projectId', 'project-a'),
        );
        expect(
          db
              .select('SELECT COUNT(*) AS count FROM $vectorLshBucketsTable')
              .single['count'],
          2 * vectorLshTableCount,
        );

        db.dispose();
        db = sqlite3.open(path);
        ensureVectorStoreSchema(db);
        expect(
          db
              .select('SELECT COUNT(*) AS count FROM $vectorEmbeddingsTable')
              .single['count'],
          2,
        );
        expect(
          db
              .select('SELECT COUNT(*) AS count FROM $vectorLshBucketsTable')
              .single['count'],
          2 * vectorLshTableCount,
        );
        expect(db.select('PRAGMA user_version').single['user_version'], 41);
        db.dispose();
      },
    );

    test('derives project scope from a legacy path when metadata lacks it', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);
      _createLegacyVectorTable(db);
      db.execute(
        '''INSERT INTO vector_embeddings
          (id, content, embedding, tier, metadata)
          VALUES (?, ?, ?, ?, ?)''',
        [
          'fallback-project/world/fact-1',
          'legacy fact',
          jsonEncode(const [1.0, 0.0]),
          'canon',
          '{}',
        ],
      );

      ensureVectorStoreSchema(db);

      final row = db
          .select('SELECT project_id, dimension FROM $vectorEmbeddingsTable')
          .single;
      expect(row['project_id'], 'fallback-project');
      expect(row['dimension'], 2);
    });

    test(
      'aborts non-list JSON migration without changing the legacy table or version',
      () {
        final db = sqlite3.openInMemory();
        addTearDown(db.dispose);
        db.execute('PRAGMA user_version = 17');
        _createLegacyVectorTable(db);
        const invalidEmbedding = '{"not":"a vector"}';
        db.execute(
          '''INSERT INTO vector_embeddings
            (id, content, embedding, tier, metadata)
            VALUES (?, ?, ?, ?, ?)''',
          [
            'legacy-invalid',
            'must survive failed migration',
            invalidEmbedding,
            'scene',
            '{"projectId":"project-a"}',
          ],
        );

        expect(
          () => ensureVectorStoreSchema(db),
          throwsA(isA<FormatException>()),
        );

        expect(db.select('PRAGMA user_version').single['user_version'], 17);
        expect(_columnNames(db), contains('embedding'));
        expect(_columnNames(db), isNot(contains('embedding_blob')));
        final legacyRow = db
            .select('SELECT id, content, embedding FROM vector_embeddings')
            .single;
        expect(legacyRow['id'], 'legacy-invalid');
        expect(legacyRow['content'], 'must survive failed migration');
        expect(legacyRow['embedding'], invalidEmbedding);
        expect(
          db.select(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
            [vectorLshBucketsTable],
          ),
          isEmpty,
        );
      },
    );

    test('isolates a legacy row with no project scope under the sentinel', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);
      _createLegacyVectorTable(db);
      db.execute(
        '''INSERT INTO vector_embeddings
          (id, content, embedding, tier, metadata)
          VALUES (?, ?, ?, ?, ?)''',
        [
          'unscoped-id',
          'legacy unscoped content',
          jsonEncode(const [1.0, 0.0]),
          'scene',
          '{}',
        ],
      );

      ensureVectorStoreSchema(db);

      final row = db
          .select('SELECT project_id, id FROM $vectorEmbeddingsTable')
          .single;
      expect(row['project_id'], legacyUnscopedVectorProjectId);
      expect(row['id'], 'unscoped-id');
    });

    test('rebuilds stale-version and missing LSH bucket rows', () async {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);
      final store = SqliteVssStore(db);
      await store.upsertAll(const [
        VectorStoreEntry(
          id: 'stale-version',
          projectId: 'project-a',
          content: 'stale version',
          embedding: [1.0, 0.0, 0.0],
          tier: MemoryTier.scene,
        ),
        VectorStoreEntry(
          id: 'missing-buckets',
          projectId: 'project-a',
          content: 'missing buckets',
          embedding: [0.0, 1.0, 0.0],
          tier: MemoryTier.scene,
        ),
      ]);
      final rowIds = {
        for (final row in db.select(
          'SELECT id, row_id FROM $vectorEmbeddingsTable',
        ))
          row['id'] as String: row['row_id'] as int,
      };
      db.execute(
        'UPDATE $vectorEmbeddingsTable SET lsh_version = ? WHERE row_id = ?',
        [vectorLshVersion - 1, rowIds['stale-version']],
      );
      db.execute(
        'UPDATE $vectorLshBucketsTable SET bucket = -1 WHERE vector_row_id = ?',
        [rowIds['stale-version']],
      );
      db.execute(
        '''DELETE FROM $vectorLshBucketsTable
           WHERE vector_row_id = ? AND table_no = 0''',
        [rowIds['missing-buckets']],
      );

      ensureVectorStoreSchema(db);

      final rows = db.select(
        'SELECT id, lsh_version FROM $vectorEmbeddingsTable ORDER BY id',
      );
      expect(
        rows.map((row) => row['lsh_version']),
        everyElement(vectorLshVersion),
      );
      for (final rowId in rowIds.values) {
        expect(
          db
              .select(
                '''SELECT COUNT(*) AS count FROM $vectorLshBucketsTable
                  WHERE vector_row_id = ?''',
                [rowId],
              )
              .single['count'],
          vectorLshTableCount,
        );
      }
      final rebuiltBuckets = db
          .select(
            '''SELECT bucket FROM $vectorLshBucketsTable
              WHERE vector_row_id = ? ORDER BY table_no''',
            [rowIds['stale-version']],
          )
          .map((row) => row['bucket'] as int)
          .toList();
      expect(rebuiltBuckets, vectorLshSignatures(const [1.0, 0.0, 0.0]));
    });
  });
}

void _createLegacyVectorTable(Database db) {
  db.execute('''
    CREATE TABLE vector_embeddings (
      id TEXT PRIMARY KEY,
      content TEXT NOT NULL,
      embedding TEXT NOT NULL,
      tier TEXT NOT NULL,
      metadata TEXT NOT NULL DEFAULT '{}'
    )
  ''');
}

void _insertLegacyRow(
  Database db, {
  required String id,
  required String projectId,
  required String tier,
  required List<double> embedding,
}) {
  db.execute(
    '''INSERT INTO vector_embeddings
      (id, content, embedding, tier, metadata)
      VALUES (?, ?, ?, ?, ?)''',
    [
      id,
      'content for $id',
      jsonEncode(embedding),
      tier,
      jsonEncode({'projectId': projectId, 'source': 'legacy-test'}),
    ],
  );
}

Set<String> _columnNames(Database db) => db
    .select("PRAGMA table_info('$vectorEmbeddingsTable')")
    .map((row) => row['name'] as String)
    .toSet();
