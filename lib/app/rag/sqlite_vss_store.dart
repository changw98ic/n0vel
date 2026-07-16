import 'dart:convert';
import 'dart:math';

import 'package:sqlite3/sqlite3.dart';

import '../../features/story_generation/domain/contracts/memory_policy.dart';
import '../../features/story_generation/domain/memory_models.dart';
import '../state/sqlite_write_coordinator.dart';
import 'local_rag_storage.dart' show RagAdmission, normalizeRequiredTagGroups;
import 'vector_store.dart';
import 'vector_store_schema.dart';

/// Portable SQLite vector search using B-tree indexed random-hyperplane LSH
/// followed by exact cosine re-ranking in Dart.
class SqliteVssStore implements VectorStore {
  SqliteVssStore(this._db, {SqliteWriteCoordinator? writeCoordinator})
    : writeCoordinator =
          writeCoordinator ?? SqliteWriteCoordinator.forDatabase(_db) {
    ensureVectorStoreSchema(_db);
    _db.execute('''
      CREATE TEMP TABLE IF NOT EXISTS $_searchProbesTable (
        table_no INTEGER NOT NULL,
        bucket INTEGER NOT NULL,
        PRIMARY KEY (table_no, bucket)
      ) WITHOUT ROWID
    ''');
  }

  final Database _db;
  final SqliteWriteCoordinator writeCoordinator;

  static const int exactSearchThreshold = 2048;
  static const int maxCandidateRows = 8192;
  static const int minCandidateRows = 4096;
  static const int candidateRowsPerHit = 512;
  static const int probeBatchSize = 400;
  static const int selectBatchSize = 800;
  static const int minCandidatesBeforeRadiusTwo = 64;
  static const int candidatesPerRequestedHitBeforeRadiusTwo = 8;
  static const int strongCollisionsBeforeRadiusTwo = 2;
  static const int indexWriteBatchSize = 128;
  static const String _searchProbesTable = 'temp_vector_lsh_search_probes';

  SqliteVssSearchStats _lastSearchStats = const SqliteVssSearchStats.empty();

  /// Bounded-memory evidence for the most recent synchronous SQLite search.
  ///
  /// A [SqliteVssStore] owns one SQLite connection and executes the search
  /// synchronously, so callers can read this immediately after
  /// [searchDetailed] when evaluating index behavior.
  SqliteVssSearchStats get lastSearchStats => _lastSearchStats;

  @override
  Future<void> upsert({
    required String id,
    required String projectId,
    required String content,
    required List<double> embedding,
    required MemoryTier tier,
    Map<String, dynamic> metadata = const {},
  }) {
    return upsertAll([
      VectorStoreEntry(
        id: id,
        projectId: _requireProjectId(projectId),
        content: content,
        embedding: embedding,
        tier: tier,
        metadata: metadata,
      ),
    ]);
  }

  @override
  Future<void> upsertAll(List<VectorStoreEntry> entries) =>
      upsertAllCoordinated(entries);

  /// [upsertAll] with an optional lease for a wider atomic write.
  Future<void> upsertAllCoordinated(
    List<VectorStoreEntry> entries, {
    SqliteWriteLease? lease,
  }) async {
    if (entries.isEmpty) return;
    for (final entry in entries) {
      _requireProjectId(entry.projectId);
      final visibility = _visibilityByName(entry.metadata['visibility']);
      final ownerId = entry.metadata['ownerId']?.toString().trim() ?? '';
      if (visibility == MemoryVisibility.agentPrivate && ownerId.isEmpty) {
        throw ArgumentError.value(
          entries,
          'entries',
          'agentPrivate vector entries require metadata.ownerId',
        );
      }
    }

    await writeCoordinator.synchronized<void>((_) {
      _db.execute('SAVEPOINT vector_store_upsert');
      final entryStatement = _db.prepare('''
      INSERT INTO $vectorEmbeddingsTable (
        project_id, id, content, embedding_blob, dimension, tier,
        scope_id, visibility, owner_id, metadata_json, lsh_version
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(project_id, id) DO UPDATE SET
        content = excluded.content,
        embedding_blob = excluded.embedding_blob,
        dimension = excluded.dimension,
        tier = excluded.tier,
        scope_id = excluded.scope_id,
        visibility = excluded.visibility,
        owner_id = excluded.owner_id,
        metadata_json = excluded.metadata_json,
        lsh_version = excluded.lsh_version
    ''');
      final rowIdStatement = _db.prepare('''
      SELECT row_id FROM $vectorEmbeddingsTable
      WHERE project_id = ? AND id = ?
    ''');
      final deleteBucketsStatement = _db.prepare('''
      DELETE FROM $vectorLshBucketsTable WHERE vector_row_id = ?
    ''');
      final bucketStatement = _db.prepare('''
      INSERT INTO $vectorLshBucketsTable (
        vector_row_id, project_id, tier, dimension, table_no, bucket
      ) VALUES (?, ?, ?, ?, ?, ?)
    ''');
      final deleteTagsStatement = _db.prepare('''
      DELETE FROM vector_embedding_tags WHERE vector_row_id = ?
    ''');
      final tagStatement = _db.prepare('''
      INSERT INTO vector_embedding_tags (project_id, vector_row_id, tag)
      VALUES (?, ?, ?)
    ''');
      try {
        for (final entry in entries) {
          final projectId = _requireProjectId(entry.projectId);
          final normalizedEmbedding = normalizeVector(entry.embedding);
          final dimension = normalizedEmbedding.length;
          final visibility = _visibilityByName(entry.metadata['visibility']);
          final ownerId = entry.metadata['ownerId']?.toString().trim() ?? '';
          entryStatement.execute([
            projectId,
            entry.id,
            entry.content,
            encodeFloat32Vector(normalizedEmbedding),
            dimension,
            entry.tier.name,
            entry.metadata['scopeId']?.toString().trim() ?? '',
            visibility.name,
            ownerId,
            jsonEncode(entry.metadata),
            vectorLshVersion,
          ]);
          final rowId =
              rowIdStatement.select([projectId, entry.id]).single['row_id']
                  as int;
          deleteBucketsStatement.execute([rowId]);
          deleteTagsStatement.execute([rowId]);
          for (final tag in _metadataTags(entry.metadata['tags'])) {
            tagStatement.execute([projectId, rowId, tag]);
          }
          final signatures = vectorLshSignatures(normalizedEmbedding);
          for (var table = 0; table < signatures.length; table++) {
            bucketStatement.execute([
              rowId,
              projectId,
              entry.tier.name,
              dimension,
              table,
              signatures[table],
            ]);
          }
        }
        _db.execute('RELEASE SAVEPOINT vector_store_upsert');
      } catch (_) {
        _db.execute('ROLLBACK TO SAVEPOINT vector_store_upsert');
        _db.execute('RELEASE SAVEPOINT vector_store_upsert');
        rethrow;
      } finally {
        entryStatement.dispose();
        rowIdStatement.dispose();
        deleteBucketsStatement.dispose();
        bucketStatement.dispose();
        deleteTagsStatement.dispose();
        tagStatement.dispose();
      }
    }, lease: lease);
  }

  @override
  Future<List<VectorSearchHit>> search({
    required List<double> embedding,
    required String projectId,
    Set<MemoryTier>? tiers,
    int limit = 10,
  }) async {
    return (await searchDetailed(
      embedding: embedding,
      projectId: projectId,
      tiers: tiers,
      limit: limit,
    )).hits;
  }

  @override
  Future<VectorSearchResult> searchDetailed({
    required List<double> embedding,
    required String projectId,
    Set<MemoryTier>? tiers,
    int limit = 10,
    RagAdmission? admission,
  }) async {
    _lastSearchStats = const SqliteVssSearchStats.empty();
    final effectiveProjectId = _requireProjectId(projectId);
    final normalizedQuery = normalizeVector(embedding);
    final effectiveTiers = tiers ?? MemoryTier.values.toSet();
    final totalRows = _countRows();
    final eligibleRows = effectiveTiers.isEmpty
        ? 0
        : _countEligibleRows(
            effectiveProjectId,
            effectiveTiers,
            normalizedQuery.length,
            admission,
          );
    if (limit <= 0 || eligibleRows == 0 || effectiveTiers.isEmpty) {
      return VectorSearchResult(
        hits: const [],
        diagnostics: VectorSearchDiagnostics(
          totalRows: totalRows,
          eligibleRows: eligibleRows,
          candidateRows: 0,
          decodedRows: 0,
          scoredRows: 0,
          candidateLimit: 0,
          probeCount: 0,
          usedFullScan: eligibleRows <= exactSearchThreshold,
        ),
      );
    }

    final useFullScan = eligibleRows <= exactSearchThreshold;
    final candidateLimit = useFullScan
        ? eligibleRows
        : min(
            eligibleRows,
            max(
              minCandidateRows,
              min(maxCandidateRows, limit * candidateRowsPerHit),
            ),
          ).toInt();
    final annSelection = useFullScan
        ? null
        : _selectAnnCandidateRowIds(
            normalizedQuery,
            effectiveProjectId,
            effectiveTiers,
            candidateLimit,
            limit,
            admission,
          );
    final candidateRowIds = useFullScan
        ? _selectEligibleRowIds(
            effectiveProjectId,
            effectiveTiers,
            normalizedQuery.length,
            admission,
          )
        : annSelection!.rowIds;
    final boundedCandidateIds = candidateRowIds.length <= candidateLimit
        ? candidateRowIds
        : candidateRowIds.take(candidateLimit).toList(growable: false);

    final topRows = _scoreTopRows(normalizedQuery, boundedCandidateIds, limit);
    final hits = _loadHits(topRows);
    final probeCount = useFullScan ? 0 : annSelection!.probeCount;
    _lastSearchStats = useFullScan
        ? SqliteVssSearchStats.fullScan(
            candidateLimit: candidateLimit,
            materializedRows: boundedCandidateIds.length,
          )
        : SqliteVssSearchStats.indexed(
            candidateLimit: candidateLimit,
            matchedRows: annSelection!.matchedRows,
            materializedRows: annSelection.materializedRows,
            probeCount: annSelection.probeCount,
            expandedRadiusTwo: annSelection.expandedRadiusTwo,
          );
    return VectorSearchResult(
      hits: hits,
      diagnostics: VectorSearchDiagnostics(
        totalRows: totalRows,
        eligibleRows: eligibleRows,
        candidateRows: boundedCandidateIds.length,
        decodedRows: boundedCandidateIds.length,
        scoredRows: boundedCandidateIds.length,
        candidateLimit: candidateLimit,
        probeCount: probeCount,
        usedFullScan: useFullScan,
      ),
    );
  }

  @override
  Future<void> indexChunks(
    List<StoryMemoryChunk> chunks,
    Future<List<double>> Function(String content) embeddingForChunk,
  ) async {
    final batches = <List<VectorStoreEntry>>[];
    for (
      var offset = 0;
      offset < chunks.length;
      offset += indexWriteBatchSize
    ) {
      final batchChunks = chunks.sublist(
        offset,
        min(chunks.length, offset + indexWriteBatchSize),
      );
      batches.add(
        await Future.wait(
          batchChunks.map((chunk) async {
            return VectorStoreEntry(
              id: chunk.id,
              projectId: chunk.projectId,
              content: chunk.content,
              embedding: await embeddingForChunk(chunk.content),
              tier: chunk.tier,
              metadata: {
                'projectId': chunk.projectId,
                'scopeId': chunk.scopeId,
                'kind': chunk.kind.name,
                'tier': chunk.tier.name,
                'visibility': chunk.visibility.name,
                'ownerId': chunk.ownerId,
                'tags': chunk.tags,
              },
            );
          }),
        ),
      );
    }
    await writeCoordinator.synchronized<void>((lease) async {
      _db.execute('SAVEPOINT vector_store_index_chunks');
      try {
        for (final entries in batches) {
          await upsertAllCoordinated(entries, lease: lease);
        }
        _db.execute('RELEASE SAVEPOINT vector_store_index_chunks');
      } catch (_) {
        _db.execute('ROLLBACK TO SAVEPOINT vector_store_index_chunks');
        _db.execute('RELEASE SAVEPOINT vector_store_index_chunks');
        rethrow;
      }
    });
  }

  @override
  Future<void> delete(String id, {required String projectId}) =>
      deleteCoordinated(id, projectId: projectId);

  /// [delete] with an optional lease for a wider atomic write.
  Future<void> deleteCoordinated(
    String id, {
    required String projectId,
    SqliteWriteLease? lease,
  }) async {
    final effectiveProjectId = _requireProjectId(projectId);
    const where = 'project_id = ? AND id = ?';
    final parameters = <Object?>[effectiveProjectId, id];
    await writeCoordinator.synchronized<void>((_) {
      _db.execute('SAVEPOINT vector_store_delete');
      try {
        _db.execute('''
        DELETE FROM vector_embedding_tags
        WHERE vector_row_id IN (
          SELECT row_id FROM $vectorEmbeddingsTable WHERE $where
        )
      ''', parameters);
        _db.execute('''
        DELETE FROM $vectorLshBucketsTable
        WHERE vector_row_id IN (
          SELECT row_id FROM $vectorEmbeddingsTable WHERE $where
        )
      ''', parameters);
        _db.execute(
          'DELETE FROM $vectorEmbeddingsTable WHERE $where',
          parameters,
        );
        _db.execute('RELEASE SAVEPOINT vector_store_delete');
      } catch (_) {
        _db.execute('ROLLBACK TO SAVEPOINT vector_store_delete');
        _db.execute('RELEASE SAVEPOINT vector_store_delete');
        rethrow;
      }
    }, lease: lease);
  }

  @override
  Future<void> clearProject(String projectId) =>
      clearProjectCoordinated(projectId);

  /// [clearProject] with an optional lease for a wider atomic write.
  Future<void> clearProjectCoordinated(
    String projectId, {
    SqliteWriteLease? lease,
  }) async {
    final effectiveProjectId = _requireProjectId(projectId);
    await writeCoordinator.synchronized<void>((_) {
      _db.execute('SAVEPOINT vector_store_clear_project');
      try {
        _db.execute('DELETE FROM vector_embedding_tags WHERE project_id = ?', [
          effectiveProjectId,
        ]);
        _db.execute('DELETE FROM $vectorLshBucketsTable WHERE project_id = ?', [
          effectiveProjectId,
        ]);
        _db.execute('DELETE FROM $vectorEmbeddingsTable WHERE project_id = ?', [
          effectiveProjectId,
        ]);
        _db.execute('RELEASE SAVEPOINT vector_store_clear_project');
      } catch (_) {
        _db.execute('ROLLBACK TO SAVEPOINT vector_store_clear_project');
        _db.execute('RELEASE SAVEPOINT vector_store_clear_project');
        rethrow;
      }
    }, lease: lease);
  }

  /// Atomically replaces all vectors for one project.
  Future<void> replaceProject(
    String projectId,
    List<VectorStoreEntry> entries,
  ) async {
    final effectiveProjectId = _requireProjectId(projectId);
    if (entries.any((entry) => entry.projectId != effectiveProjectId)) {
      throw ArgumentError.value(
        entries,
        'entries',
        'all entries must belong to project $effectiveProjectId',
      );
    }
    await writeCoordinator.synchronized<void>((lease) async {
      _db.execute('SAVEPOINT vector_store_replace_project');
      try {
        await clearProjectCoordinated(effectiveProjectId, lease: lease);
        await upsertAllCoordinated(entries, lease: lease);
        _db.execute('RELEASE SAVEPOINT vector_store_replace_project');
      } catch (_) {
        _db.execute('ROLLBACK TO SAVEPOINT vector_store_replace_project');
        _db.execute('RELEASE SAVEPOINT vector_store_replace_project');
        rethrow;
      }
    });
  }

  bool usesDatabase(Database database) => identical(_db, database);

  int _countRows() =>
      _db
              .select('SELECT COUNT(*) AS count FROM $vectorEmbeddingsTable')
              .single['count']
          as int;

  int _countEligibleRows(
    String projectId,
    Set<MemoryTier> tiers,
    int dimension,
    RagAdmission? admission,
  ) {
    final tierNames = [for (final tier in tiers) tier.name]..sort();
    final placeholders = List.filled(tierNames.length, '?').join(', ');
    final clause = _admissionClause(admission, alias: 'e');
    final parameters = <Object?>[
      projectId,
      ...tierNames,
      dimension,
      ...clause.parameters,
    ];
    return _db.select('''
      SELECT COUNT(*) AS count FROM $vectorEmbeddingsTable AS e
      WHERE e.project_id = ? AND e.tier IN ($placeholders) AND e.dimension = ?
      ${clause.sql}
    ''', parameters).single['count']
        as int;
  }

  List<int> _selectEligibleRowIds(
    String projectId,
    Set<MemoryTier> tiers,
    int dimension,
    RagAdmission? admission,
  ) {
    final tierNames = [for (final tier in tiers) tier.name]..sort();
    final placeholders = List.filled(tierNames.length, '?').join(', ');
    final clause = _admissionClause(admission, alias: 'e');
    final parameters = <Object?>[
      projectId,
      ...tierNames,
      dimension,
      ...clause.parameters,
    ];
    return [
      for (final row in _db.select('''
        SELECT row_id FROM $vectorEmbeddingsTable
        AS e WHERE e.project_id = ? AND e.tier IN ($placeholders) AND e.dimension = ?
        ${clause.sql}
        ORDER BY e.row_id
      ''', parameters))
        row['row_id'] as int,
    ];
  }

  _AnnCandidateSelection _selectAnnCandidateRowIds(
    List<double> normalizedQuery,
    String projectId,
    Set<MemoryTier> tiers,
    int candidateLimit,
    int requestedLimit,
    RagAdmission? admission,
  ) {
    final tierNames = [for (final tier in tiers) tier.name]..sort();
    final tierPlaceholders = List.filled(tierNames.length, '?').join(', ');
    final radiusOneProbes = vectorLshProbes(normalizedQuery, radius: 1);
    var selection = _selectProbeCandidates(
      radiusOneProbes,
      projectId: projectId,
      tierNames: tierNames,
      tierPlaceholders: tierPlaceholders,
      dimension: normalizedQuery.length,
      candidateLimit: candidateLimit,
      admission: admission,
    );
    var probeCount = radiusOneProbes.length;
    final expansionFloor = max(
      minCandidatesBeforeRadiusTwo,
      requestedLimit * candidatesPerRequestedHitBeforeRadiusTwo,
    );
    var expandedRadiusTwo = false;
    if (selection.matchedRows < expansionFloor ||
        selection.strongMatchedRows < requestedLimit) {
      final radiusTwoProbes = vectorLshProbes(normalizedQuery, radius: 2);
      selection = _selectProbeCandidates(
        radiusTwoProbes,
        projectId: projectId,
        tierNames: tierNames,
        tierPlaceholders: tierPlaceholders,
        dimension: normalizedQuery.length,
        candidateLimit: candidateLimit,
        admission: admission,
      );
      probeCount = radiusTwoProbes.length;
      expandedRadiusTwo = true;
    }
    return _AnnCandidateSelection(
      rowIds: selection.rowIds,
      probeCount: probeCount,
      matchedRows: selection.matchedRows,
      materializedRows: selection.rowIds.length,
      expandedRadiusTwo: expandedRadiusTwo,
    );
  }

  _ProbeCandidateSelection _selectProbeCandidates(
    List<VectorLshProbe> probes, {
    required String projectId,
    required List<String> tierNames,
    required String tierPlaceholders,
    required int dimension,
    required int candidateLimit,
    required RagAdmission? admission,
  }) {
    _db.execute('DELETE FROM $_searchProbesTable');
    for (var offset = 0; offset < probes.length; offset += probeBatchSize) {
      final end = min(offset + probeBatchSize, probes.length);
      final batch = probes.sublist(offset, end);
      final values = List.filled(batch.length, '(?, ?)').join(', ');
      _db.execute(
        'INSERT INTO $_searchProbesTable (table_no, bucket) VALUES $values',
        [
          for (final probe in batch) ...[probe.tableNo, probe.bucket],
        ],
      );
    }
    final admissionJoin = admission == null
        ? ''
        : 'JOIN $vectorEmbeddingsTable AS e ON e.row_id = b.vector_row_id';
    final admissionClause = admission == null
        ? const _SqlAdmissionClause('', [])
        : _admissionClause(admission, alias: 'e');
    try {
      final rows = _db.select(
        '''
        WITH collisions AS (
          SELECT b.vector_row_id, COUNT(*) AS collisions
          FROM $_searchProbesTable AS p
          CROSS JOIN $vectorLshBucketsTable AS b INDEXED BY $vectorLshLookupIndex
            ON b.project_id = ? AND b.tier IN ($tierPlaceholders)
            AND b.dimension = ?
            AND b.table_no = p.table_no AND b.bucket = p.bucket
          $admissionJoin
          WHERE 1 = 1 ${admissionClause.sql}
          GROUP BY b.vector_row_id
        )
        SELECT vector_row_id, collisions,
          COUNT(*) OVER () AS matched_rows,
          SUM(CASE WHEN collisions >= ? THEN 1 ELSE 0 END) OVER ()
            AS strong_matched_rows
        FROM collisions
        ORDER BY collisions DESC, vector_row_id
        LIMIT ?
      ''',
        [
          projectId,
          ...tierNames,
          dimension,
          ...admissionClause.parameters,
          strongCollisionsBeforeRadiusTwo,
          candidateLimit,
        ],
      );
      if (rows.isEmpty) {
        return const _ProbeCandidateSelection(
          rowIds: [],
          matchedRows: 0,
          strongMatchedRows: 0,
        );
      }
      return _ProbeCandidateSelection(
        rowIds: [for (final row in rows) row['vector_row_id'] as int],
        matchedRows: rows.first['matched_rows'] as int,
        strongMatchedRows: rows.first['strong_matched_rows'] as int,
      );
    } finally {
      _db.execute('DELETE FROM $_searchProbesTable');
    }
  }

  List<_ScoredVectorRow> _scoreTopRows(
    List<double> normalizedQuery,
    List<int> candidateRowIds,
    int limit,
  ) {
    final heap = _TopKHeap(limit);
    for (
      var offset = 0;
      offset < candidateRowIds.length;
      offset += selectBatchSize
    ) {
      final end = min(offset + selectBatchSize, candidateRowIds.length);
      final ids = candidateRowIds.sublist(offset, end);
      final placeholders = List.filled(ids.length, '?').join(', ');
      final rows = _db.select('''
        SELECT row_id, embedding_blob, dimension
        FROM $vectorEmbeddingsTable
        WHERE row_id IN ($placeholders)
      ''', ids);
      for (final row in rows) {
        final stored = decodeFloat32Vector(
          row['embedding_blob'],
          row['dimension'] as int,
        );
        heap.add(
          _ScoredVectorRow(
            rowId: row['row_id'] as int,
            score: cosineSimilarity(normalizedQuery, stored),
          ),
        );
      }
    }
    return heap.toSortedList();
  }

  List<VectorSearchHit> _loadHits(List<_ScoredVectorRow> scoredRows) {
    if (scoredRows.isEmpty) return const [];
    final ids = [for (final row in scoredRows) row.rowId];
    final placeholders = List.filled(ids.length, '?').join(', ');
    final rows = _db.select('''
      SELECT row_id, id, content, tier, metadata_json
      FROM $vectorEmbeddingsTable
      WHERE row_id IN ($placeholders)
    ''', ids);
    final rowsById = {for (final row in rows) row['row_id'] as int: row};
    return [
      for (final scored in scoredRows)
        if (rowsById[scored.rowId] case final row?)
          VectorSearchHit(
            id: row['id'] as String,
            score: scored.score,
            content: row['content'] as String,
            tier: _tierByName(row['tier'] as String),
            metadata: _metadataFromJson(row['metadata_json'] as String),
          ),
    ];
  }

  _SqlAdmissionClause _admissionClause(
    RagAdmission? admission, {
    required String alias,
  }) {
    if (admission == null) return const _SqlAdmissionClause('', []);
    final clauses = <String>[];
    final parameters = <Object?>[];
    final tiers = admission.allowedTiers.map((tier) => tier.name).toList()
      ..sort();
    if (tiers.isEmpty) return const _SqlAdmissionClause('AND 0', []);
    clauses.add(
      '$alias.tier IN (${List.filled(tiers.length, '?').join(', ')})',
    );
    parameters.addAll(tiers);
    clauses.add('''(
      $alias.visibility = 'publicObservable'
      OR ($alias.visibility = 'editorOnly' AND ? = 1)
      OR ($alias.visibility = 'agentPrivate' AND $alias.owner_id = ?)
    )''');
    parameters.add(admission.viewerRole == MemoryViewerRole.editor ? 1 : 0);
    parameters.add(admission.viewerId?.trim() ?? '');
    final scopes = {
      for (final scope in admission.allowedScopeIds)
        if (scope.trim().isNotEmpty) scope.trim(),
    }.toList()..sort();
    if (scopes.isNotEmpty) {
      clauses.add(
        '$alias.scope_id IN (${List.filled(scopes.length, '?').join(', ')})',
      );
      parameters.addAll(scopes);
    }
    for (final group in normalizeRequiredTagGroups(
      admission.requiredTagGroups,
    )) {
      clauses.add('''EXISTS (
        SELECT 1 FROM vector_embedding_tags AS vt
        WHERE vt.project_id = $alias.project_id
          AND vt.vector_row_id = $alias.row_id
          AND vt.tag IN (${List.filled(group.length, '?').join(', ')})
      )''');
      parameters.addAll(group);
    }
    return _SqlAdmissionClause('AND ${clauses.join(' AND ')}', parameters);
  }

  static String _requireProjectId(String projectId) {
    final normalized = projectId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(projectId, 'projectId', 'must not be empty');
    }
    return normalized;
  }

  static MemoryTier _tierByName(String name) {
    return MemoryTier.values.firstWhere(
      (tier) => tier.name == name,
      orElse: () => MemoryTier.scene,
    );
  }

  static MemoryVisibility _visibilityByName(Object? raw) =>
      MemoryVisibility.values.firstWhere(
        (visibility) => visibility.name == raw?.toString(),
        orElse: () => MemoryVisibility.publicObservable,
      );

  static List<String> _metadataTags(Object? raw) {
    if (raw is! List) return const [];
    return {
      for (final value in raw)
        if (value != null && value.toString().trim().isNotEmpty)
          value.toString().trim(),
    }.toList()..sort();
  }

  static Map<String, dynamic> _metadataFromJson(String value) {
    final decoded = jsonDecode(value);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : const {};
  }
}

/// Search-workspace counters used by the scale evaluator.
class SqliteVssSearchStats {
  const SqliteVssSearchStats.empty()
    : candidateLimit = 0,
      matchedRows = 0,
      materializedRows = 0,
      probeCount = 0,
      expandedRadiusTwo = false,
      usedFullScan = false;

  const SqliteVssSearchStats.fullScan({
    required this.candidateLimit,
    required this.materializedRows,
  }) : matchedRows = materializedRows,
       probeCount = 0,
       expandedRadiusTwo = false,
       usedFullScan = true;

  const SqliteVssSearchStats.indexed({
    required this.candidateLimit,
    required this.matchedRows,
    required this.materializedRows,
    required this.probeCount,
    required this.expandedRadiusTwo,
  }) : usedFullScan = false;

  /// Maximum number of ranked collision rows allowed to cross into Dart.
  final int candidateLimit;

  /// Rows matched by SQLite before its deterministic ORDER BY/LIMIT.
  final int matchedRows;

  /// Ranked collision rows actually materialized in Dart.
  final int materializedRows;
  final int probeCount;
  final bool expandedRadiusTwo;
  final bool usedFullScan;
}

class _AnnCandidateSelection {
  const _AnnCandidateSelection({
    required this.rowIds,
    required this.probeCount,
    required this.matchedRows,
    required this.materializedRows,
    required this.expandedRadiusTwo,
  });

  final List<int> rowIds;
  final int probeCount;
  final int matchedRows;
  final int materializedRows;
  final bool expandedRadiusTwo;
}

class _ProbeCandidateSelection {
  const _ProbeCandidateSelection({
    required this.rowIds,
    required this.matchedRows,
    required this.strongMatchedRows,
  });

  final List<int> rowIds;
  final int matchedRows;
  final int strongMatchedRows;
}

class _SqlAdmissionClause {
  const _SqlAdmissionClause(this.sql, this.parameters);

  final String sql;
  final List<Object?> parameters;
}

class _ScoredVectorRow {
  const _ScoredVectorRow({required this.rowId, required this.score});

  final int rowId;
  final double score;
}

class _TopKHeap {
  _TopKHeap(this.limit);

  final int limit;
  final List<_ScoredVectorRow> _items = [];

  void add(_ScoredVectorRow value) {
    if (limit <= 0) return;
    if (_items.length < limit) {
      _items.add(value);
      _siftUp(_items.length - 1);
      return;
    }
    if (!_isBetter(value, _items.first)) return;
    _items[0] = value;
    _siftDown(0);
  }

  List<_ScoredVectorRow> toSortedList() {
    return List<_ScoredVectorRow>.from(_items)..sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.rowId.compareTo(b.rowId);
    });
  }

  void _siftUp(int index) {
    var child = index;
    while (child > 0) {
      final parent = (child - 1) ~/ 2;
      if (!_isWorse(_items[child], _items[parent])) break;
      final value = _items[parent];
      _items[parent] = _items[child];
      _items[child] = value;
      child = parent;
    }
  }

  void _siftDown(int index) {
    var parent = index;
    while (true) {
      final left = parent * 2 + 1;
      if (left >= _items.length) return;
      final right = left + 1;
      var worse = left;
      if (right < _items.length && _isWorse(_items[right], _items[left])) {
        worse = right;
      }
      if (!_isWorse(_items[worse], _items[parent])) return;
      final value = _items[parent];
      _items[parent] = _items[worse];
      _items[worse] = value;
      parent = worse;
    }
  }

  static bool _isBetter(_ScoredVectorRow left, _ScoredVectorRow right) {
    if (left.score != right.score) return left.score > right.score;
    return left.rowId < right.rowId;
  }

  static bool _isWorse(_ScoredVectorRow left, _ScoredVectorRow right) {
    if (left.score != right.score) return left.score < right.score;
    return left.rowId > right.rowId;
  }
}
