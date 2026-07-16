import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:novel_writer/app/rag/sqlite_vss_store.dart';
import 'package:novel_writer/app/rag/vector_store.dart';
import 'package:novel_writer/app/rag/vector_store_schema.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/memory_policy.dart';
import 'package:sqlite3/sqlite3.dart';

import 'rag_vector_evaluator_support.dart';

Future<void> main(List<String> arguments) async {
  RagVectorEvaluatorConfig config;
  try {
    config = RagVectorEvaluatorConfig.parse(arguments);
  } on FormatException catch (error) {
    stderr.writeln('Invalid evaluator arguments: ${error.message}');
    exitCode = 64;
    return;
  }

  final failures = <String>[];
  final report = <String, Object?>{
    'schemaVersion': 1,
    'config': config.toJson(),
    'invocation': <String, Object?>{
      'tool': 'tool/rag_vector_index_evaluator.dart',
      'arguments': arguments,
    },
    'environment': {
      'dart': Platform.version,
      'operatingSystem': Platform.operatingSystem,
      'operatingSystemVersion': Platform.operatingSystemVersion,
      'sqlite': sqlite3.version.libVersion,
    },
  };

  Directory? directory;
  Database? database;
  try {
    final migration = await _evaluateLegacyMigration();
    report['migration'] = migration;
    if (migration['pass'] != true) {
      failures.add('legacy JSON vector migration failed');
    }

    final cleanup = await _evaluateProjectCleanup();
    report['cleanup'] = cleanup;
    if (cleanup['pass'] != true) {
      failures.add('repeated project synchronization left stale rows');
    }

    stderr.writeln(
      'Generating deterministic ${config.vectorCount} x ${config.dimensions} corpus...',
    );
    final generationWatch = Stopwatch()..start();
    final corpus = DeterministicVectorCorpus.generate(
      vectorCount: config.vectorCount,
      dimensions: config.dimensions,
      seed: config.seed,
    );
    generationWatch.stop();

    directory = await Directory.systemTemp.createTemp(
      'novel_writer_rag_vector_evaluator_',
    );
    database = sqlite3.open('${directory.path}/vectors.db');
    var store = SqliteVssStore(database);

    stderr.writeln('Building the SQLite LSH index...');
    final buildWatch = Stopwatch()..start();
    const insertBatchSize = 750;
    for (
      var offset = 0;
      offset < corpus.vectorCount;
      offset += insertBatchSize
    ) {
      final end = math.min(offset + insertBatchSize, corpus.vectorCount);
      await store.upsertAll([
        for (var index = offset; index < end; index++)
          VectorStoreEntry(
            id: corpus.idAt(index),
            projectId: corpus.projectAt(index),
            content: 'deterministic clustered vector $index',
            embedding: corpus.vectorAt(index),
            tier: corpus.tierAt(index),
            metadata: {'projectId': corpus.projectAt(index), 'ordinal': index},
          ),
      ]);
    }
    buildWatch.stop();

    final expectedVectorRows =
        database
                .select('SELECT COUNT(*) AS count FROM $vectorEmbeddingsTable')
                .single['count']
            as int;
    final expectedBucketRows =
        database
                .select('SELECT COUNT(*) AS count FROM $vectorLshBucketsTable')
                .single['count']
            as int;
    database.dispose();
    database = sqlite3.open('${directory.path}/vectors.db');
    final reopenChangesBefore = _totalChanges(database);
    final reopenWatch = Stopwatch()..start();
    store = SqliteVssStore(database);
    reopenWatch.stop();
    final reopenChanges = _totalChanges(database) - reopenChangesBefore;
    final reopenedVectorRows =
        database
                .select('SELECT COUNT(*) AS count FROM $vectorEmbeddingsTable')
                .single['count']
            as int;
    final reopenedBucketRows =
        database
                .select('SELECT COUNT(*) AS count FROM $vectorLshBucketsTable')
                .single['count']
            as int;
    final reopenMs = reopenWatch.elapsedMicroseconds / 1000.0;
    final reopenPass =
        reopenChanges == 0 &&
        reopenedVectorRows == expectedVectorRows &&
        reopenedBucketRows == expectedBucketRows &&
        reopenMs <= config.maxReopenMs;
    if (!reopenPass) {
      failures.add(
        'populated database reopen changed rows or exceeded '
        '${config.maxReopenMs.toStringAsFixed(1)}ms',
      );
    }
    report['reopen'] = <String, Object>{
      'elapsedMs': reopenMs,
      'maximumMs': config.maxReopenMs,
      'sqliteChanges': reopenChanges,
      'vectorRowsBefore': expectedVectorRows,
      'vectorRowsAfter': reopenedVectorRows,
      'lshBucketRowsBefore': expectedBucketRows,
      'lshBucketRowsAfter': reopenedBucketRows,
      'pass': reopenPass,
    };

    final recallScores = <double>[];
    final recallPages = <VectorSearchResult>[];
    final recallSearchStats = <SqliteVssSearchStats>[];
    var filterPushdownPass = true;
    stderr.writeln('Computing exact cosine baselines and recall@10...');
    for (var ordinal = 0; ordinal < config.recallQueries; ordinal++) {
      final vectorIndex = corpus.queryVectorIndex(ordinal);
      final projectId = corpus.projectAt(vectorIndex);
      final tiers = {corpus.tierAt(vectorIndex)};
      final query = corpus.queryForOrdinal(ordinal);
      final expected = corpus.exactTopK(
        query: query,
        projectId: projectId,
        tiers: tiers,
        limit: config.limit,
      );
      final page = await store.searchDetailed(
        embedding: query,
        projectId: projectId,
        tiers: tiers,
        limit: config.limit,
      );
      recallPages.add(page);
      recallSearchStats.add(store.lastSearchStats);
      filterPushdownPass =
          filterPushdownPass &&
          _hasExpectedFilterScope(
            page: page,
            corpus: corpus,
            projectId: projectId,
            tiers: tiers,
          );
      recallScores.add(
        recallAtK(
          page.hits.map((hit) => hit.id),
          expected.map((neighbor) => neighbor.id),
          config.limit,
        ),
      );
    }

    final recallAt10 =
        recallScores.reduce((left, right) => left + right) /
        recallScores.length;
    if (recallAt10 < config.minRecallAt10) {
      failures.add(
        'recall@10 ${recallAt10.toStringAsFixed(4)} is below '
        '${config.minRecallAt10.toStringAsFixed(4)}',
      );
    }

    final warmupQueryCount = config.warmupQueries;
    for (var ordinal = 0; ordinal < warmupQueryCount; ordinal++) {
      final vectorIndex = corpus.queryVectorIndex(ordinal);
      await store.searchDetailed(
        embedding: corpus.queryForOrdinal(ordinal),
        projectId: corpus.projectAt(vectorIndex),
        tiers: {corpus.tierAt(vectorIndex)},
        limit: config.limit,
      );
    }

    final roundP95Ms = <double>[];
    final allLatencyMs = <double>[];
    final latencyPages = <VectorSearchResult>[];
    final latencySearchStats = <SqliteVssSearchStats>[];
    for (var round = 0; round < config.latencyRounds; round++) {
      final roundSamples = <double>[];
      for (
        var queryIndex = 0;
        queryIndex < config.latencyQueries;
        queryIndex++
      ) {
        final ordinal = 1000 + round * config.latencyQueries + queryIndex;
        final vectorIndex = corpus.queryVectorIndex(ordinal);
        final watch = Stopwatch()..start();
        final page = await store.searchDetailed(
          embedding: corpus.queryForOrdinal(ordinal),
          projectId: corpus.projectAt(vectorIndex),
          tiers: {corpus.tierAt(vectorIndex)},
          limit: config.limit,
        );
        watch.stop();
        filterPushdownPass =
            filterPushdownPass &&
            _hasExpectedFilterScope(
              page: page,
              corpus: corpus,
              projectId: corpus.projectAt(vectorIndex),
              tiers: {corpus.tierAt(vectorIndex)},
            );
        final elapsedMs = watch.elapsedMicroseconds / 1000.0;
        roundSamples.add(elapsedMs);
        allLatencyMs.add(elapsedMs);
        latencyPages.add(page);
        latencySearchStats.add(store.lastSearchStats);
      }
      roundP95Ms.add(nearestRankPercentile(roundSamples, 0.95));
    }

    final p95Ms = median(roundP95Ms);
    if (p95Ms > config.maxP95Ms) {
      failures.add(
        'median round p95 ${p95Ms.toStringAsFixed(3)}ms exceeds '
        '${config.maxP95Ms.toStringAsFixed(3)}ms',
      );
    }

    final observedPages = [...recallPages, ...latencyPages];
    final observedSearchStats = [...recallSearchStats, ...latencySearchStats];
    final maxCandidateRows = observedPages
        .map((page) => page.diagnostics.candidateRows)
        .fold<int>(0, math.max);
    final maxDecodedRows = observedPages
        .map((page) => page.diagnostics.decodedRows)
        .fold<int>(0, math.max);
    final maxScoredRows = observedPages
        .map((page) => page.diagnostics.scoredRows)
        .fold<int>(0, math.max);
    final minEligibleRows = observedPages
        .map((page) => page.diagnostics.eligibleRows)
        .reduce(math.min);
    final usedFullScan = observedPages.any(
      (page) => page.diagnostics.usedFullScan,
    );
    final exceededInternalBudget = observedPages.any(
      (page) =>
          page.diagnostics.candidateRows > page.diagnostics.candidateLimit,
    );
    final decodedOutsideCandidates = observedPages.any(
      (page) =>
          page.diagnostics.decodedRows > page.diagnostics.candidateRows ||
          page.diagnostics.scoredRows > page.diagnostics.decodedRows,
    );
    final unboundedCandidates =
        maxCandidateRows > config.maxCandidates ||
        maxCandidateRows >= minEligibleRows;
    final maxMatchedLshRows = observedSearchStats
        .map((stats) => stats.matchedRows)
        .fold<int>(0, math.max);
    final maxMaterializedVoteRows = observedSearchStats
        .map((stats) => stats.materializedRows)
        .fold<int>(0, math.max);
    final voteBufferExceeded = observedSearchStats.any(
      (stats) =>
          stats.materializedRows > stats.candidateLimit ||
          stats.materializedRows > config.maxCandidates,
    );

    if (usedFullScan) failures.add('search diagnostics reported a full scan');
    if (!filterPushdownPass) {
      failures.add(
        'project/tier filters were not applied before vector decoding',
      );
    }
    if (exceededInternalBudget) {
      failures.add('search exceeded its declared internal candidate limit');
    }
    if (decodedOutsideCandidates) {
      failures.add('vectors were decoded or scored outside the candidate set');
    }
    if (unboundedCandidates) {
      failures.add(
        'candidate set was not bounded: max=$maxCandidateRows, '
        'eligible-min=$minEligibleRows, acceptance-max=${config.maxCandidates}',
      );
    }
    if (voteBufferExceeded) {
      failures.add(
        'Dart LSH vote workspace exceeded its candidate budget: '
        'max=$maxMaterializedVoteRows, acceptance-max=${config.maxCandidates}',
      );
    }

    final vectorRows =
        database
                .select('SELECT COUNT(*) AS count FROM $vectorEmbeddingsTable')
                .single['count']
            as int;
    final bucketRows =
        database
                .select('SELECT COUNT(*) AS count FROM $vectorLshBucketsTable')
                .single['count']
            as int;
    final fileBytes = File('${directory.path}/vectors.db').lengthSync();

    report['dataset'] = {
      'rows': vectorRows,
      'dimensions': config.dimensions,
      'lshBucketRows': bucketRows,
      'databaseBytes': fileBytes,
      'generationMs': generationWatch.elapsedMilliseconds,
      'indexBuildMs': buildWatch.elapsedMilliseconds,
    };
    report['structural'] = {
      'usedFullScan': usedFullScan,
      'maxCandidateRows': maxCandidateRows,
      'maxMatchedLshRowsBeforeLimit': maxMatchedLshRows,
      'maxMaterializedVoteRows': maxMaterializedVoteRows,
      'maxDecodedRows': maxDecodedRows,
      'maxScoredRows': maxScoredRows,
      'minEligibleRows': minEligibleRows,
      'acceptanceMaxCandidates': config.maxCandidates,
      'candidateLimitRespected': !exceededInternalBudget,
      'dartVoteWorkspaceBounded': !voteBufferExceeded,
      'decodeBoundedByCandidates': !decodedOutsideCandidates,
      'filterPushdownPass': filterPushdownPass,
      'pass':
          !usedFullScan &&
          filterPushdownPass &&
          !exceededInternalBudget &&
          !voteBufferExceeded &&
          !decodedOutsideCandidates &&
          !unboundedCandidates,
    };
    report['quality'] = {
      'recallAt10': recallAt10,
      'minimumRecallAt10': config.minRecallAt10,
      'queryCount': recallScores.length,
      'minimumPerQueryRecall': recallScores.reduce(math.min),
      'pass': recallAt10 >= config.minRecallAt10,
    };
    report['latency'] = {
      'sampleCount': allLatencyMs.length,
      'p50Ms': nearestRankPercentile(allLatencyMs, 0.50),
      'p95Ms': p95Ms,
      'roundP95Ms': roundP95Ms,
      'maximumP95Ms': config.maxP95Ms,
      'pass': p95Ms <= config.maxP95Ms,
    };
  } on Object catch (error, stackTrace) {
    failures.add('evaluator error: $error');
    report['error'] = error.toString();
    report['stackTrace'] = stackTrace.toString();
  } finally {
    database?.dispose();
    if (directory != null && await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  report['pass'] = failures.isEmpty;
  report['failures'] = failures;
  final encoder = config.jsonOutput
      ? const JsonEncoder()
      : const JsonEncoder.withIndent('  ');
  final encodedReport = encoder.convert(report);
  final outputPath = config.outputPath;
  if (outputPath != null) {
    final output = File(outputPath).absolute;
    output.parent.createSync(recursive: true);
    output.writeAsStringSync('$encodedReport\n', flush: true);
  }
  stdout.writeln(encodedReport);
  if (failures.isNotEmpty) exitCode = 1;
}

Future<Map<String, Object>> _evaluateLegacyMigration() async {
  final db = sqlite3.openInMemory();
  try {
    db.execute('''
      CREATE TABLE vector_embeddings (
        id TEXT PRIMARY KEY,
        content TEXT NOT NULL,
        embedding TEXT NOT NULL,
        tier TEXT NOT NULL,
        metadata TEXT NOT NULL DEFAULT '{}'
      )
    ''');
    db.execute(
      '''INSERT INTO vector_embeddings
        (id, content, embedding, tier, metadata)
        VALUES (?, ?, ?, ?, ?)''',
      [
        'legacy-project/world/fact-1',
        'legacy indexed fact',
        jsonEncode(const [1.0, 0.0, 0.0, 0.0]),
        MemoryTier.canon.name,
        jsonEncode({'projectId': 'legacy-project'}),
      ],
    );
    final store = SqliteVssStore(db);
    final page = await store.searchDetailed(
      embedding: const [1.0, 0.0, 0.0, 0.0],
      projectId: 'legacy-project',
      tiers: {MemoryTier.canon},
      limit: 10,
    );
    final row = db.select('''
      SELECT typeof(embedding_blob) AS kind, dimension
      FROM $vectorEmbeddingsTable
    ''').single;
    final pass =
        page.hits.length == 1 &&
        page.hits.single.id == 'legacy-project/world/fact-1' &&
        row['kind'] == 'blob' &&
        row['dimension'] == 4;
    return {
      'pass': pass,
      'migratedRows': page.hits.length,
      'storageType': row['kind'] as String,
      'dimension': row['dimension'] as int,
    };
  } finally {
    db.dispose();
  }
}

Future<Map<String, Object>> _evaluateProjectCleanup() async {
  final db = sqlite3.openInMemory();
  try {
    final store = SqliteVssStore(db);
    await store.replaceProject(
      'cleanup-project',
      _cleanupEntries('cleanup-project', const [
        'hero-one',
        'hero-two',
        'hero-three',
        'old-world',
      ]),
    );
    await store.replaceProject(
      'preserved-project',
      _cleanupEntries('preserved-project', const [
        'preserved-hero',
        'preserved-world',
      ]),
    );
    await store.replaceProject(
      'cleanup-project',
      _cleanupEntries('cleanup-project', const ['replacement-hero']),
    );
    await store.replaceProject(
      'cleanup-project',
      _cleanupEntries('cleanup-project', const ['replacement-hero']),
    );

    final cleanupIds = db
        .select(
          '''SELECT id FROM $vectorEmbeddingsTable
            WHERE project_id = ? ORDER BY id''',
          ['cleanup-project'],
        )
        .map((row) => row['id'] as String)
        .toList();
    final cleanupBucketRows =
        db.select(
              'SELECT COUNT(*) AS count FROM $vectorLshBucketsTable WHERE project_id = ?',
              ['cleanup-project'],
            ).single['count']
            as int;
    final preservedVectorRows =
        db.select(
              'SELECT COUNT(*) AS count FROM $vectorEmbeddingsTable WHERE project_id = ?',
              ['preserved-project'],
            ).single['count']
            as int;
    final preservedBucketRows =
        db.select(
              'SELECT COUNT(*) AS count FROM $vectorLshBucketsTable WHERE project_id = ?',
              ['preserved-project'],
            ).single['count']
            as int;
    final pass =
        cleanupIds.length == 1 &&
        cleanupIds.single == 'replacement-hero' &&
        cleanupBucketRows == vectorLshTableCount &&
        preservedVectorRows == 2 &&
        preservedBucketRows == 2 * vectorLshTableCount;
    return {
      'pass': pass,
      'replacementVectorIds': cleanupIds,
      'replacementBucketRows': cleanupBucketRows,
      'preservedVectorRows': preservedVectorRows,
      'preservedBucketRows': preservedBucketRows,
    };
  } finally {
    db.dispose();
  }
}

List<VectorStoreEntry> _cleanupEntries(String projectId, List<String> ids) => [
  for (var index = 0; index < ids.length; index++)
    VectorStoreEntry(
      id: ids[index],
      projectId: projectId,
      content: ids[index],
      embedding: [index + 1.0, 1.0, 0.0, 0.0],
      tier: MemoryTier.scene,
      metadata: {'projectId': projectId},
    ),
];

int _totalChanges(Database db) =>
    db.select('SELECT total_changes() AS count').single['count'] as int;

bool _hasExpectedFilterScope({
  required VectorSearchResult page,
  required DeterministicVectorCorpus corpus,
  required String projectId,
  required Set<MemoryTier> tiers,
}) {
  final expectedEligibleRows = corpus.eligibleRowCount(projectId, tiers);
  return page.diagnostics.totalRows == corpus.vectorCount &&
      page.diagnostics.eligibleRows == expectedEligibleRows &&
      page.hits.every(
        (hit) =>
            hit.metadata['projectId'] == projectId && tiers.contains(hit.tier),
      );
}
