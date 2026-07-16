import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/rag/sqlite_vss_store.dart';
import 'package:novel_writer/app/rag/vector_store.dart';
import 'package:novel_writer/app/rag/vector_store_schema.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/memory_policy.dart';
import 'package:sqlite3/sqlite3.dart';

import '../tool/rag_vector_evaluator_support.dart';

void main() {
  group('SQLite indexed vector search contract', () {
    late Database db;
    late SqliteVssStore store;

    setUp(() {
      db = sqlite3.openInMemory();
      store = SqliteVssStore(db);
    });

    tearDown(() => db.dispose());

    test('candidate voting is covering-index-only', () {
      db.execute('''
        INSERT INTO temp_vector_lsh_search_probes (table_no, bucket)
        VALUES (0, 123), (1, 456)
      ''');
      final plan = db.select(
        '''
        EXPLAIN QUERY PLAN
        WITH collisions AS (
          SELECT b.vector_row_id, COUNT(*) AS collisions
          FROM temp_vector_lsh_search_probes AS p
          JOIN $vectorLshBucketsTable AS b INDEXED BY $vectorLshLookupIndex
            ON b.table_no = p.table_no AND b.bucket = p.bucket
          WHERE b.project_id = ? AND b.tier IN (?) AND b.dimension = ?
          GROUP BY b.vector_row_id
        )
        SELECT vector_row_id, collisions, COUNT(*) OVER () AS matched_rows
        FROM collisions
        ORDER BY collisions DESC, vector_row_id
        LIMIT ?
      ''',
        ['project-a', MemoryTier.scene.name, 32, 5120],
      );
      final details = plan.map((row) => row['detail'].toString()).toList();

      expect(
        details.any((detail) => detail.contains(vectorLshLookupIndex)),
        isTrue,
        reason: details.join('\n'),
      );
      expect(
        details.any(
          (detail) =>
              detail.contains('SCAN b') ||
              detail.contains('SCAN $vectorLshBucketsTable'),
        ),
        isFalse,
        reason: details.join('\n'),
      );
      expect(
        details.any((detail) => detail.contains(vectorEmbeddingsTable)),
        isFalse,
        reason: details.join('\n'),
      );
    });

    test('large eligible scope decodes only bounded LSH candidates', () async {
      const vectorCount = 4096;
      const dimensions = 32;
      final corpus = DeterministicVectorCorpus.generate(
        vectorCount: vectorCount,
        dimensions: dimensions,
        seed: defaultVectorEvaluatorSeed,
      );
      final entries = <VectorStoreEntry>[
        for (var index = 0; index < vectorCount; index++)
          VectorStoreEntry(
            id: corpus.idAt(index),
            projectId: 'target-project',
            content: 'target vector $index',
            embedding: corpus.vectorAt(index),
            tier: MemoryTier.scene,
            metadata: const {'projectId': 'target-project'},
          ),
        for (var index = 0; index < 128; index++)
          VectorStoreEntry(
            id: 'other-$index',
            projectId: 'other-project',
            content: 'cross-project distractor $index',
            embedding: corpus.vectorAt(index),
            tier: MemoryTier.scene,
            metadata: const {'projectId': 'other-project'},
          ),
        for (var index = 0; index < 64; index++)
          VectorStoreEntry(
            id: 'draft-$index',
            projectId: 'target-project',
            content: 'wrong-tier distractor $index',
            embedding: corpus.vectorAt(index),
            tier: MemoryTier.draft,
            metadata: const {'projectId': 'target-project'},
          ),
      ];
      await store.upsertAll(entries);

      final page = await store.searchDetailed(
        embedding: corpus.queryForOrdinal(3),
        projectId: 'target-project',
        tiers: {MemoryTier.scene},
        limit: 10,
      );

      expect(page.hits, hasLength(10));
      expect(page.hits.every((hit) => hit.tier == MemoryTier.scene), isTrue);
      expect(
        page.hits.every((hit) => hit.metadata['projectId'] == 'target-project'),
        isTrue,
      );
      expect(page.diagnostics.totalRows, entries.length);
      expect(page.diagnostics.eligibleRows, vectorCount);
      expect(page.diagnostics.usedFullScan, isFalse);
      expect(page.diagnostics.probeCount, greaterThan(0));
      expect(
        page.diagnostics.candidateRows,
        lessThanOrEqualTo(page.diagnostics.candidateLimit),
      );
      expect(
        page.diagnostics.candidateRows,
        lessThan(page.diagnostics.eligibleRows),
      );
      expect(page.diagnostics.decodedRows, page.diagnostics.candidateRows);
      expect(page.diagnostics.scoredRows, page.diagnostics.decodedRows);
      expect(
        store.lastSearchStats.materializedRows,
        page.diagnostics.candidateRows,
      );
      expect(
        store.lastSearchStats.materializedRows,
        lessThanOrEqualTo(store.lastSearchStats.candidateLimit),
      );
    });

    test(
      '100k collision fanout materializes only the candidate budget in Dart',
      () async {
        const vectorCount = 100000;
        const dimensions = 32;
        final vector = List<double>.generate(
          dimensions,
          (index) => index == 0 ? 1 : 0,
          growable: false,
        );
        final blob = encodeFloat32Vector(normalizeVector(vector));
        final signature = vectorLshSignatures(vector).first;
        final entryStatement = db.prepare('''
          INSERT INTO $vectorEmbeddingsTable (
            row_id, project_id, id, content, embedding_blob, dimension, tier,
            metadata_json, lsh_version
          ) VALUES (?, ?, ?, '', ?, ?, ?, '{}', ?)
        ''');
        final bucketStatement = db.prepare('''
          INSERT INTO $vectorLshBucketsTable (
            vector_row_id, project_id, tier, dimension, table_no, bucket
          ) VALUES (?, ?, ?, ?, 0, ?)
        ''');
        db.execute('BEGIN');
        try {
          for (var index = 1; index <= vectorCount; index++) {
            entryStatement.execute([
              index,
              'fanout-project',
              'fanout-$index',
              blob,
              dimensions,
              MemoryTier.scene.name,
              vectorLshVersion,
            ]);
            bucketStatement.execute([
              index,
              'fanout-project',
              MemoryTier.scene.name,
              dimensions,
              signature,
            ]);
          }
          db.execute('COMMIT');
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        } finally {
          entryStatement.dispose();
          bucketStatement.dispose();
        }

        final page = await store.searchDetailed(
          embedding: vector,
          projectId: 'fanout-project',
          tiers: {MemoryTier.scene},
          limit: 10,
        );
        final stats = store.lastSearchStats;

        expect(page.diagnostics.eligibleRows, vectorCount);
        expect(stats.matchedRows, vectorCount);
        expect(stats.materializedRows, page.diagnostics.candidateLimit);
        expect(stats.materializedRows, 10 * SqliteVssStore.candidateRowsPerHit);
        expect(stats.materializedRows, lessThan(stats.matchedRows));
        expect(stats.materializedRows, lessThanOrEqualTo(stats.candidateLimit));
        expect(page.diagnostics.decodedRows, stats.materializedRows);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test('deterministic clustered corpus reaches recall@10 floor', () async {
      const vectorCount = 4096;
      const dimensions = 32;
      const queryCount = 8;
      final corpus = DeterministicVectorCorpus.generate(
        vectorCount: vectorCount,
        dimensions: dimensions,
        seed: defaultVectorEvaluatorSeed,
      );
      await store.upsertAll([
        for (var index = 0; index < vectorCount; index++)
          VectorStoreEntry(
            id: corpus.idAt(index),
            projectId: 'recall-project',
            content: 'recall vector $index',
            embedding: corpus.vectorAt(index),
            tier: MemoryTier.scene,
            metadata: const {'projectId': 'recall-project'},
          ),
      ]);

      final recalls = <double>[];
      for (var ordinal = 0; ordinal < queryCount; ordinal++) {
        final query = corpus.queryForOrdinal(ordinal);
        final exact =
            <({String id, double score})>[
              for (var index = 0; index < vectorCount; index++)
                (
                  id: corpus.idAt(index),
                  score: cosineSimilarity(query, corpus.vectorAt(index)),
                ),
            ]..sort((left, right) {
              final scoreOrder = right.score.compareTo(left.score);
              return scoreOrder != 0 ? scoreOrder : left.id.compareTo(right.id);
            });
        final page = await store.searchDetailed(
          embedding: query,
          projectId: 'recall-project',
          tiers: {MemoryTier.scene},
          limit: 10,
        );
        recalls.add(
          recallAtK(
            page.hits.map((hit) => hit.id),
            exact.take(10).map((neighbor) => neighbor.id),
            10,
          ),
        );
      }

      final meanRecall =
          recalls.reduce((left, right) => left + right) / recalls.length;
      expect(meanRecall, greaterThanOrEqualTo(0.80), reason: '$recalls');
    });

    test(
      'uniform corpus keeps recall when radius-two fallback is needed',
      () async {
        const vectorCount = 4096;
        const dimensions = 32;
        const queryCount = 8;
        final vectors = _uniformVectors(
          count: vectorCount,
          dimensions: dimensions,
          seed: 0x5eed1234,
        );
        await store.upsertAll([
          for (var index = 0; index < vectorCount; index++)
            VectorStoreEntry(
              id: 'uniform-$index',
              projectId: 'uniform-project',
              content: 'uniform vector $index',
              embedding: vectors[index],
              tier: MemoryTier.scene,
              metadata: const {'projectId': 'uniform-project'},
            ),
        ]);

        final queryRandom = FixedXorShift32(0x13579bdf);
        final recalls = <double>[];
        for (var ordinal = 0; ordinal < queryCount; ordinal++) {
          final query = _randomUnitVector(queryRandom, dimensions);
          final exact =
              <({String id, double score})>[
                for (var index = 0; index < vectorCount; index++)
                  (
                    id: 'uniform-$index',
                    score: cosineSimilarity(query, vectors[index]),
                  ),
              ]..sort((left, right) {
                final scoreOrder = right.score.compareTo(left.score);
                return scoreOrder != 0
                    ? scoreOrder
                    : left.id.compareTo(right.id);
              });
          final page = await store.searchDetailed(
            embedding: query,
            projectId: 'uniform-project',
            tiers: {MemoryTier.scene},
            limit: 10,
          );
          recalls.add(
            recallAtK(
              page.hits.map((hit) => hit.id),
              exact.take(10).map((neighbor) => neighbor.id),
              10,
            ),
          );
          expect(page.diagnostics.usedFullScan, isFalse);
          expect(page.diagnostics.probeCount, greaterThan(272));
        }

        final meanRecall =
            recalls.reduce((left, right) => left + right) / recalls.length;
        expect(meanRecall, greaterThanOrEqualTo(0.80), reason: '$recalls');
      },
    );
  });
}

List<Float32List> _uniformVectors({
  required int count,
  required int dimensions,
  required int seed,
}) {
  final random = FixedXorShift32(seed);
  return List<Float32List>.generate(
    count,
    (_) => _randomUnitVector(random, dimensions),
    growable: false,
  );
}

Float32List _randomUnitVector(FixedXorShift32 random, int dimensions) {
  final vector = Float32List(dimensions);
  var normSquared = 0.0;
  for (var dimension = 0; dimension < dimensions; dimension++) {
    final value = random.nextSignedDouble();
    vector[dimension] = value;
    normSquared += value * value;
  }
  final norm = math.sqrt(normSquared);
  for (var dimension = 0; dimension < dimensions; dimension++) {
    vector[dimension] /= norm;
  }
  return vector;
}
