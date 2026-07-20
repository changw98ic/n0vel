import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/rag/hybrid_retriever.dart';
import 'package:novel_writer/app/rag/lm_studio_embedding_client.dart';
import 'package:novel_writer/app/rag/local_rag_storage.dart';
import 'package:novel_writer/app/rag/novel_corpus_importer.dart';
import 'package:novel_writer/app/rag/ollama_embedding_client.dart';
import 'package:novel_writer/app/rag/sqlite_vss_store.dart';
import 'package:novel_writer/app/rag/vector_embedding_profile.dart';
import 'package:novel_writer/app/rag/vector_store_schema.dart';
import 'package:novel_writer/features/story_generation/data/source_admission_resolver.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/memory_policy.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/rag_retrieval_policy.dart';
import 'package:novel_writer/features/story_generation/domain/memory_models.dart';
import 'package:sqlite3/sqlite3.dart';

const _argumentsEnvironmentKey = 'NOVEL_WRITER_CORPUS_IMPORT_ARGUMENTS';
const _resultEnvironmentKey = 'NOVEL_WRITER_CORPUS_IMPORT_RESULT';

void main() {
  test(
    'imports the real novel corpus into an isolated hybrid database',
    () async {
      final resultPath = Platform.environment[_resultEnvironmentKey];
      if (resultPath == null || resultPath.isEmpty) {
        throw StateError('Missing $_resultEnvironmentKey');
      }
      final arguments =
          (jsonDecode(Platform.environment[_argumentsEnvironmentKey] ?? '[]')
                  as List<dynamic>)
              .cast<String>();
      late Map<String, Object?> envelope;
      try {
        final output = await _run(arguments);
        envelope = {'exitCode': 0, 'output': output};
      } on FormatException catch (error) {
        envelope = {
          'exitCode': 64,
          'error': 'Invalid arguments: ${error.message}\n$_usage',
        };
      } catch (error, stackTrace) {
        envelope = {
          'exitCode': 1,
          'error': 'Novel corpus import failed: $error\n$stackTrace',
        };
      } finally {
        File(resultPath).writeAsStringSync(jsonEncode(envelope), flush: true);
      }
    },
    timeout: Timeout.none,
  );
}

Future<String> _run(List<String> arguments) async {
  final config = _Config.parse(arguments);
  if (config.showHelp) return _usage;

  final targetFile = _canonicalFile(File(config.databasePath));
  _rejectProductionDatabase(targetFile);
  if (config.profileOnly && (config.replace || config.resume)) {
    throw const FormatException(
      '--profile-only cannot be combined with --replace or --resume',
    );
  }
  if (config.profileOnly && !targetFile.existsSync()) {
    throw const FormatException('--profile-only requires an existing database');
  }
  if (config.profileOnly) return _profileExistingDatabase(targetFile, config);

  final usesStaging = config.embeddingProvider != 'local';
  final databaseFile = usesStaging
      ? File('${targetFile.path}.building')
      : targetFile;
  targetFile.parent.createSync(recursive: true);
  final publicationGuard = await _TargetPublicationGuard.acquire(
    targetFile,
    captureTargetIdentity: usesStaging && config.replace,
  );
  Database? db;
  _EmbeddingRuntime? embeddingRuntime;
  var published = false;
  try {
    if (usesStaging) {
      _validateStagingDatabaseFiles(databaseFile);
    }
    if (config.replace && usesStaging) {
      // Preserve the last completed target until the staged replacement passes
      // every audit and can be atomically renamed over it.
      _deleteDatabaseFiles(databaseFile);
    } else if (config.replace) {
      _deleteDatabaseFiles(targetFile);
    }
    if (targetFile.existsSync() && !config.replace) {
      throw const FormatException(
        'database already exists; pass --replace to rebuild it',
      );
    }
    if (databaseFile.existsSync() && !config.resume) {
      throw const FormatException(
        'staging database already exists; pass --resume or --replace',
      );
    }

    db = sqlite3.open(databaseFile.path);
    if (usesStaging) {
      // The staging file is private to this importer. Exclusive locking keeps
      // SQLite from leaving a shared-memory sidecar after a clean seal.
      final lockingMode = db
          .select('PRAGMA locking_mode = EXCLUSIVE')
          .single
          .values
          .single
          .toString()
          .toLowerCase();
      if (lockingMode != 'exclusive') {
        throw StateError(
          'Unable to lock staging database exclusively: $lockingMode',
        );
      }
      db.execute('PRAGMA journal_mode = WAL');
      db.execute('PRAGMA synchronous = NORMAL');
    } else {
      // The local-hash database is a replaceable, quick evaluation artifact.
      db.execute('PRAGMA journal_mode = MEMORY');
      db.execute('PRAGMA synchronous = OFF');
    }
    db.execute('PRAGMA temp_store = MEMORY');
    db.execute('PRAGMA cache_size = -65536');
    embeddingRuntime = await _EmbeddingRuntime.create(config);
    final retriever = HybridRetriever.local(
      db: db,
      embeddingForText: embeddingRuntime?.embed,
      embeddingForTexts: embeddingRuntime?.embedAll,
    );
    final embeddingProfile = embeddingRuntime?.profile;
    final storedEmbeddingProfile = embeddingProfile == null
        ? null
        : readVectorEmbeddingProfile(db);
    final allowLlamaCppBehaviorDrift = config.embeddingProvider == 'llamacpp';
    if (embeddingProfile != null &&
        storedEmbeddingProfile != null &&
        allowLlamaCppBehaviorDrift &&
        storedEmbeddingProfile != embeddingProfile &&
        embeddingProfilesCompatibleForLlamaCppDrift(
          storedEmbeddingProfile,
          embeddingProfile,
        )) {
      await _verifyLlamaCppStoredVectors(db, embeddingRuntime!);
    }
    if (embeddingProfile != null) {
      bindOrValidateVectorEmbeddingProfile(
        db,
        embeddingProfile,
        allowLlamaCppModelDigestDrift: allowLlamaCppBehaviorDrift,
      );
    }

    final importer = NovelCorpusImporter(
      retriever: retriever,
      corpusRootPath: config.corpusRootPath,
      sourceAdmissionResolver: SourceAdmissionResolver.fromDefaultManifest(),
      batchSize: config.batchSize,
    );
    // Resume-manifest preparation hashes atoms.jsonl. Admission must therefore
    // succeed before that preparation, not only inside importWorks().
    importer.assertWorksAdmitted(works: config.works);

    final importState = embeddingProfile == null
        ? null
        : await _prepareImportState(
            db,
            config: config,
            profile: embeddingProfile,
          );
    final report = await importer.importWorks(
      works: config.works,
      limitPerWork: config.limitPerWork,
      startOrdinalByWork: importState?.startOrdinalByWork ?? const {},
      onProgress: importState == null
          ? null
          : (progress) async {
              await embeddingRuntime!.verifyModelIdentity();
              _saveImportProgress(
                db!,
                manifestHash: importState.manifestHash,
                progress: progress,
              );
            },
    );
    final ragDocuments = _count(db, 'rag_documents');
    final vectorEmbeddings = _count(db, 'vector_embeddings');
    if (ragDocuments != report.indexedRecords ||
        vectorEmbeddings != report.indexedRecords) {
      throw StateError(
        'Index row mismatch: report=${report.indexedRecords}, '
        'rag=$ragDocuments, vector=$vectorEmbeddings',
      );
    }
    final retrievalSmoke = await _runRetrievalSmoke(retriever, config.works);
    _validateRetrievalSmoke(retrievalSmoke);
    if (embeddingProfile != null) {
      await embeddingRuntime!.verifyModelIdentity(deep: true);
      auditVectorEmbeddingIndex(
        db,
        embeddingProfile,
        allowLlamaCppModelDigestDrift: allowLlamaCppBehaviorDrift,
      );
      final integrity = db.select('PRAGMA integrity_check').single.values.first;
      if (integrity != 'ok') {
        throw StateError('SQLite integrity_check failed: $integrity');
      }
      _markImportComplete(db, importState!.manifestHash);
      _checkpointAndSealStagingDatabase(db);
    }
    final output = <String, Object?>{
      ...report.toJson(),
      'schemaVersion': 2,
      if (embeddingProfile != null)
        'embeddingProfile': embeddingProfile.toJson(),
      if (importState != null) 'manifestHash': importState.manifestHash,
      'tables': {
        'ragDocuments': ragDocuments,
        'vectorEmbeddings': vectorEmbeddings,
      },
      'retrievalSmoke': retrievalSmoke,
    };
    db.dispose();
    db = null;
    embeddingRuntime?.close();
    embeddingRuntime = null;
    if (usesStaging) {
      await publicationGuard.verifyBeforePublish(replace: config.replace);
      _rejectDatabaseSidecars(databaseFile, label: 'staging');
      databaseFile.renameSync(targetFile.path);
    }
    output['databasePath'] = targetFile.path;
    output['databaseBytes'] = targetFile.lengthSync();
    final encoded = config.jsonOutput
        ? jsonEncode(output)
        : const JsonEncoder.withIndent('  ').convert(output);
    published = true;
    return encoded;
  } finally {
    try {
      embeddingRuntime?.close();
      db?.dispose();
      if (!published && !usesStaging) _deleteDatabaseFiles(databaseFile);
    } finally {
      publicationGuard.close();
    }
  }
}

class _EmbeddingRuntime {
  _EmbeddingRuntime({
    required this.profile,
    required this.maxBatchSize,
    required Future<List<double>> Function(String) embedOne,
    required Future<List<List<double>>> Function(List<String>) embedMany,
    required Future<VectorEmbeddingProfile> Function() fetchProfile,
    Future<void> Function()? verifyBehavior,
    required void Function() closeClient,
  }) : _embedOne = embedOne,
       _embedMany = embedMany,
       _fetchProfile = fetchProfile,
       _verifyBehavior = verifyBehavior,
       _closeClient = closeClient;

  static Future<_EmbeddingRuntime?> create(_Config config) async {
    if (config.embeddingProvider == 'local') return null;
    if (config.embeddingProvider == 'lmstudio' ||
        config.embeddingProvider == 'llamacpp') {
      final isLlamaCpp = config.embeddingProvider == 'llamacpp';
      final provider = isLlamaCpp ? 'llamacpp' : 'lmstudio';
      final client = LmStudioEmbeddingClient(
        model: config.embeddingModel,
        expectedDimensions: config.embeddingDimensions,
        baseUrl: isLlamaCpp ? config.llamaCppBaseUrl : config.lmStudioBaseUrl,
        requestTimeout: Duration(
          seconds: isLlamaCpp
              ? config.llamaCppTimeoutSeconds
              : config.lmStudioTimeoutSeconds,
        ),
        metadataApi: isLlamaCpp
            ? EmbeddingServerMetadataApi.llamaCpp
            : EmbeddingServerMetadataApi.lmStudio,
        allowBehaviorDrift: isLlamaCpp,
      );
      try {
        final modelInfo = await client.fetchModelInfo();
        final behaviorFingerprint = await client.fetchBehaviorFingerprint();
        final profile = VectorEmbeddingProfile(
          provider: provider,
          model: modelInfo.model,
          modelDigest: behaviorFingerprint,
          dimension: config.embeddingDimensions,
        );
        final probe = await client.embed(
          'novel-writer-embedding-profile-probe-v1',
        );
        validateEmbeddingBatch(profile, [probe], expectedCount: 1);
        Future<VectorEmbeddingProfile> fetchProfile() async {
          final current = await client.fetchModelInfo();
          if (isLlamaCpp && current.contextLength != modelInfo.contextLength) {
            throw StateError(
              'llama.cpp context length changed from '
              '${modelInfo.contextLength} to ${current.contextLength} '
              'during indexing',
            );
          }
          return VectorEmbeddingProfile(
            provider: provider,
            model: current.model,
            modelDigest: behaviorFingerprint,
            dimension: config.embeddingDimensions,
          );
        }

        return _EmbeddingRuntime(
          profile: profile,
          maxBatchSize: isLlamaCpp
              ? config.llamaCppBatchSize
              : config.lmStudioBatchSize,
          embedOne: client.embed,
          embedMany: (inputs) => client.embedAllVerifyingBehavior(
            inputs,
            expectedFingerprint: behaviorFingerprint,
          ),
          fetchProfile: fetchProfile,
          verifyBehavior: () async {
            final current = await client.fetchBehaviorFingerprint();
            if (current != behaviorFingerprint && !isLlamaCpp) {
              throw StateError(
                'Embedding server model behavior changed during indexing',
              );
            }
          },
          closeClient: () => client.close(force: true),
        );
      } catch (_) {
        client.close(force: true);
        rethrow;
      }
    }
    final client = OllamaEmbeddingClient(
      model: config.embeddingModel,
      expectedDimensions: config.embeddingDimensions,
      baseUrl: config.ollamaBaseUrl,
      requestTimeout: Duration(seconds: config.ollamaTimeoutSeconds),
    );
    try {
      final modelInfo = await client.fetchModelInfo();
      if (modelInfo.embeddingLength != config.embeddingDimensions) {
        throw StateError(
          'Ollama reports embedding_length=${modelInfo.embeddingLength}; '
          'expected ${config.embeddingDimensions}',
        );
      }
      final profile = VectorEmbeddingProfile(
        provider: 'ollama',
        model: modelInfo.model,
        modelDigest: modelInfo.digest,
        dimension: config.embeddingDimensions,
      );
      final probe = await client.embed(
        'novel-writer-embedding-profile-probe-v1',
      );
      validateEmbeddingBatch(profile, [probe], expectedCount: 1);
      return _EmbeddingRuntime(
        profile: profile,
        maxBatchSize: config.ollamaBatchSize,
        embedOne: client.embed,
        embedMany: client.embedAll,
        fetchProfile: () async {
          final current = await client.fetchModelInfo();
          if (current.embeddingLength == null) {
            throw StateError('Ollama model did not report embedding length');
          }
          return VectorEmbeddingProfile(
            provider: 'ollama',
            model: current.model,
            modelDigest: current.digest,
            dimension: current.embeddingLength!,
          );
        },
        closeClient: () => client.close(force: true),
      );
    } catch (_) {
      client.close(force: true);
      rethrow;
    }
  }

  final VectorEmbeddingProfile profile;
  final int maxBatchSize;
  final Future<List<double>> Function(String) _embedOne;
  final Future<List<List<double>>> Function(List<String>) _embedMany;
  final Future<VectorEmbeddingProfile> Function() _fetchProfile;
  final Future<void> Function()? _verifyBehavior;
  final void Function() _closeClient;

  Future<List<double>> embed(String text) async {
    final result = await _embedOne(text);
    validateEmbeddingBatch(profile, [result], expectedCount: 1);
    return result;
  }

  Future<List<List<double>>> embedAll(List<String> texts) async {
    if (texts.isEmpty) return const [];
    final result = <List<double>>[];
    for (var offset = 0; offset < texts.length; offset += maxBatchSize) {
      final proposedEnd = offset + maxBatchSize;
      final end = proposedEnd < texts.length ? proposedEnd : texts.length;
      final inputBatch = texts.sublist(offset, end);
      final embeddingBatch = await _embedMany(inputBatch);
      validateEmbeddingBatch(
        profile,
        embeddingBatch,
        expectedCount: inputBatch.length,
      );
      result.addAll(embeddingBatch);
    }
    return List<List<double>>.unmodifiable(result);
  }

  Future<void> verifyModelIdentity({bool deep = false}) async {
    final currentProfile = await _fetchProfile();
    if (currentProfile != profile) {
      throw StateError(
        'Embedding model identity changed during indexing; refusing to publish '
        'mixed embeddings',
      );
    }
    if (deep) await _verifyBehavior?.call();
  }

  void close() => _closeClient();
}

class _PreparedImportState {
  const _PreparedImportState({
    required this.manifestHash,
    required this.startOrdinalByWork,
  });

  final String manifestHash;
  final Map<String, int> startOrdinalByWork;
}

Future<void> _verifyLlamaCppStoredVectors(
  Database db,
  _EmbeddingRuntime runtime,
) async {
  final rows = db.select('''
    SELECT content, embedding_blob, dimension
    FROM vector_embeddings
    ORDER BY row_id
    LIMIT 8
  ''');
  if (rows.isEmpty) return;
  final current = await runtime.embedAll([
    for (final row in rows) row['content'] as String,
  ]);
  var minimumCosine = 1.0;
  for (var index = 0; index < rows.length; index++) {
    final row = rows[index];
    final stored = decodeFloat32Vector(
      row['embedding_blob'],
      row['dimension'] as int,
    );
    final candidate = current[index];
    var dot = 0.0;
    var storedNorm = 0.0;
    var candidateNorm = 0.0;
    for (var component = 0; component < stored.length; component++) {
      dot += stored[component] * candidate[component];
      storedNorm += stored[component] * stored[component];
      candidateNorm += candidate[component] * candidate[component];
    }
    final cosine = dot / (math.sqrt(storedNorm) * math.sqrt(candidateNorm));
    if (!cosine.isFinite) {
      throw StateError('Stored llama.cpp embedding compatibility probe failed');
    }
    if (cosine < minimumCosine) minimumCosine = cosine;
  }
  if (minimumCosine < 0.995) {
    throw StateError(
      'llama.cpp embedding model changed during resume; minimum sample '
      'cosine=$minimumCosine',
    );
  }
}

Future<_PreparedImportState> _prepareImportState(
  Database db, {
  required _Config config,
  required VectorEmbeddingProfile profile,
}) async {
  db.execute('''
    CREATE TABLE IF NOT EXISTS novel_corpus_import_meta (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    ) WITHOUT ROWID
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS novel_corpus_import_progress (
      work TEXT PRIMARY KEY,
      manifest_hash TEXT NOT NULL,
      next_ordinal INTEGER NOT NULL,
      selected_records INTEGER NOT NULL,
      status TEXT NOT NULL,
      updated_at_ms INTEGER NOT NULL
    ) WITHOUT ROWID
  ''');
  var manifestHash = await _buildImportManifestHash(config, profile);
  final manifestRows = db.select(
    "SELECT value FROM novel_corpus_import_meta WHERE key = 'manifest_hash'",
  );
  if (manifestRows.isEmpty) {
    if (_count(db, 'vector_embeddings') != 0) {
      throw StateError(
        'Cannot resume populated staging data without an import manifest',
      );
    }
    db.execute(
      "INSERT INTO novel_corpus_import_meta (key, value) VALUES ('manifest_hash', ?)",
      [manifestHash],
    );
    db.execute(
      "INSERT INTO novel_corpus_import_meta (key, value) VALUES ('state', 'building')",
    );
  } else if (manifestRows.single['value'] != manifestHash) {
    final storedProfile = readVectorEmbeddingProfile(db);
    final storedManifestHash = manifestRows.single['value'] as String;
    final storedProfileForManifest = storedProfile;
    if (storedProfileForManifest == null ||
        !embeddingProfilesCompatibleForLlamaCppDrift(
          storedProfileForManifest,
          profile,
        )) {
      throw StateError(
        'Staging import manifest does not match the corpus, model, or options; '
        'use --replace to start a new build',
      );
    }
    if (await _buildImportManifestHash(config, storedProfileForManifest) !=
        storedManifestHash) {
      throw StateError(
        'Staging import manifest does not match the corpus, model, or options; '
        'use --replace to start a new build',
      );
    }
    // Keep the original manifest as the resume identity. Only the
    // slot-dependent llama.cpp behavior digest changed.
    manifestHash = storedManifestHash;
  }

  final startOrdinals = <String, int>{};
  for (final work in config.works) {
    final rows = db.select(
      '''
      SELECT next_ordinal FROM novel_corpus_import_progress
      WHERE work = ? AND manifest_hash = ?
      ''',
      [work, manifestHash],
    );
    startOrdinals[work] = rows.isEmpty ? 0 : rows.single['next_ordinal'] as int;
  }
  return _PreparedImportState(
    manifestHash: manifestHash,
    startOrdinalByWork: Map.unmodifiable(startOrdinals),
  );
}

void _saveImportProgress(
  Database db, {
  required String manifestHash,
  required NovelCorpusImportProgress progress,
}) {
  db.execute(
    '''
    INSERT INTO novel_corpus_import_progress (
      work, manifest_hash, next_ordinal, selected_records, status, updated_at_ms
    ) VALUES (?, ?, ?, ?, ?, ?)
    ON CONFLICT(work) DO UPDATE SET
      manifest_hash = excluded.manifest_hash,
      next_ordinal = excluded.next_ordinal,
      selected_records = excluded.selected_records,
      status = excluded.status,
      updated_at_ms = excluded.updated_at_ms
    ''',
    [
      progress.work,
      manifestHash,
      progress.nextOrdinal,
      progress.selectedRecords,
      progress.complete ? 'complete' : 'building',
      DateTime.now().millisecondsSinceEpoch,
    ],
  );
}

void _markImportComplete(Database db, String manifestHash) {
  final incomplete =
      db
              .select(
                '''
        SELECT COUNT(*) AS count FROM novel_corpus_import_progress
        WHERE manifest_hash = ? AND status != 'complete'
      ''',
                [manifestHash],
              )
              .single['count']
          as int;
  if (incomplete != 0) {
    throw StateError('$incomplete corpus works are not completely indexed');
  }
  db.execute(
    "UPDATE novel_corpus_import_meta SET value = 'complete' WHERE key = 'state'",
  );
}

Future<String> _buildImportManifestHash(
  _Config config,
  VectorEmbeddingProfile profile,
) async {
  final sourceDigests = <String, String>{};
  for (final work in config.works.toList()..sort()) {
    final file = File('${config.corpusRootPath}/$work/atoms.jsonl');
    if (!file.existsSync()) {
      throw FileSystemException('Missing novel corpus atoms', file.path);
    }
    sourceDigests[work] = await _sha256File(file);
  }
  final manifest = jsonEncode({
    'schemaVersion': 1,
    'importer': NovelCorpusImporter.producer,
    'sourceFileName': 'atoms.jsonl',
    'sourceDigests': sourceDigests,
    'works': config.works.toList()..sort(),
    'limitPerWork': config.limitPerWork,
    'embeddingProfile': profile.toJson(),
  });
  return _sha256Bytes(utf8.encode(manifest));
}

Future<String> _sha256File(File file) async {
  final sink = const DartSha256().newHashSink();
  await for (final chunk in file.openRead()) {
    sink.add(chunk);
  }
  sink.close();
  return sink
      .hashSync()
      .bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}

String _sha256Bytes(List<int> bytes) => const DartSha256()
    .hashSync(bytes)
    .bytes
    .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
    .join();

String _truncateRunes(String value, int maximum) {
  final runes = value.runes;
  if (runes.length <= maximum) return value;
  return '${String.fromCharCodes(runes.take(maximum - 1))}…';
}

Future<String> _profileExistingDatabase(
  File databaseFile,
  _Config config,
) async {
  final db = sqlite3.open(databaseFile.path);
  _EmbeddingRuntime? embeddingRuntime;
  try {
    embeddingRuntime = await _EmbeddingRuntime.create(config);
    final storedProfile = readVectorEmbeddingProfile(db);
    final embeddingProfile = embeddingRuntime?.profile;
    if (storedProfile != null && embeddingProfile == null) {
      throw const FormatException(
        'This database requires its external embedding model; pass '
        'the matching --embedding-provider and --embedding-model '
        '(or use an explicit FTS-only tool)',
      );
    }
    if (storedProfile == null && embeddingProfile != null) {
      throw StateError(
        'Existing database has no embedding profile; refusing to infer one',
      );
    }
    if (embeddingProfile != null) {
      bindOrValidateVectorEmbeddingProfile(
        db,
        embeddingProfile,
        allowLlamaCppModelDigestDrift: config.embeddingProvider == 'llamacpp',
      );
    }
    HybridRetrievalDiagnostics? lastHybridDiagnostics;
    final retriever = HybridRetriever.local(
      db: db,
      embeddingForText: embeddingRuntime?.embed,
      embeddingForTexts: embeddingRuntime?.embedAll,
      onDiagnostics: (diagnostics) => lastHybridDiagnostics = diagnostics,
    );
    final profiles = <Map<String, Object?>>[];
    for (final work in config.works) {
      final query = config.profileQueries[work]!;
      final projectId = NovelCorpusImporter.projectIdForWork(work);
      const admission = RagAdmission(allowedTiers: {MemoryTier.scene});

      final embeddingWatch = Stopwatch()..start();
      final embedding = await retriever.embeddingForText(query);
      embeddingWatch.stop();

      final ftsWatch = Stopwatch()..start();
      final ftsHits = await retriever.ftsStorage.searchFts(
        projectId: projectId,
        query: query,
        limit: 15,
        admission: admission,
      );
      ftsWatch.stop();

      final vectorStore = retriever.vectorStore as SqliteVssStore;
      final vectorWatch = Stopwatch()..start();
      final vectorResult = await vectorStore.searchDetailed(
        embedding: embedding,
        projectId: projectId,
        tiers: const {MemoryTier.scene},
        limit: 15,
        admission: admission,
      );
      vectorWatch.stop();

      lastHybridDiagnostics = null;
      final hybridWatch = Stopwatch()..start();
      final hybridPack = await retriever.retrieve(
        StoryMemoryQuery(
          projectId: projectId,
          queryType: StoryMemoryQueryType.style,
          text: query,
          maxResults: 5,
          tokenBudget: 2000,
        ),
        const RagRetrievalPolicy(
          roleId: 'novel-corpus-profile',
          allowedTiers: [MemoryTier.scene],
          rankingStrategy: RankingStrategy.hybrid,
          maxTokens: 2000,
        ),
      );
      hybridWatch.stop();
      final diagnostics = lastHybridDiagnostics;
      final vectorDiagnostics = vectorResult.diagnostics;
      profiles.add({
        'work': work,
        'query': query,
        'embeddingMs': embeddingWatch.elapsedMicroseconds / 1000.0,
        'ftsMs': ftsWatch.elapsedMicroseconds / 1000.0,
        'ftsHits': ftsHits.length,
        'vectorMs': vectorWatch.elapsedMicroseconds / 1000.0,
        'vectorHits': vectorResult.hits.length,
        'vectorTopHits': [
          for (final hit in vectorResult.hits.take(5))
            {
              'id': hit.id,
              'score': hit.score,
              'excerpt': _truncateRunes(hit.content, 220),
            },
        ],
        'vectorDiagnostics': {
          'totalRows': vectorDiagnostics.totalRows,
          'eligibleRows': vectorDiagnostics.eligibleRows,
          'candidateRows': vectorDiagnostics.candidateRows,
          'candidateLimit': vectorDiagnostics.candidateLimit,
          'probeCount': vectorDiagnostics.probeCount,
          'usedFullScan': vectorDiagnostics.usedFullScan,
        },
        'hybridMs': hybridWatch.elapsedMicroseconds / 1000.0,
        'hybridHits': hybridPack.hits.length,
        'hybridTopHits': [
          for (final hit in hybridPack.hits)
            {
              'id': hit.chunk.id,
              'score': hit.score,
              'excerpt': _truncateRunes(hit.chunk.content, 220),
            },
        ],
        if (diagnostics != null)
          'hybridDiagnostics': {
            'expansionRounds': diagnostics.expansionRounds,
            'candidateLimits': diagnostics.candidateLimits,
            'ftsSearches': diagnostics.ftsSearches,
            'vectorSearches': diagnostics.vectorSearches,
            'nearDuplicateComparisons': diagnostics.nearDuplicateComparisons,
          },
      });
    }
    final output = <String, Object?>{
      'schemaVersion': 1,
      'mode': 'profile-only',
      'databasePath': databaseFile.path,
      'databaseBytes': databaseFile.lengthSync(),
      'tables': {
        'ragDocuments': _count(db, 'rag_documents'),
        'vectorEmbeddings': _count(db, 'vector_embeddings'),
      },
      if (embeddingProfile != null)
        'embeddingProfile': embeddingProfile.toJson(),
      'profiles': profiles,
    };
    return config.jsonOutput
        ? jsonEncode(output)
        : const JsonEncoder.withIndent('  ').convert(output);
  } finally {
    embeddingRuntime?.close();
    db.dispose();
  }
}

Future<List<Map<String, Object?>>> _runRetrievalSmoke(
  HybridRetriever retriever,
  List<String> works,
) async {
  const policy = RagRetrievalPolicy(
    roleId: 'novel-corpus-import-smoke',
    allowedTiers: [MemoryTier.scene],
    rankingStrategy: RankingStrategy.hybrid,
    maxTokens: 2000,
  );
  final results = <Map<String, Object?>>[];
  for (final work in works) {
    final queryText = _smokeQueries[work];
    if (queryText == null) continue;
    final watch = Stopwatch()..start();
    final pack = await retriever.retrieve(
      StoryMemoryQuery(
        projectId: NovelCorpusImporter.projectIdForWork(work),
        queryType: StoryMemoryQueryType.style,
        text: queryText,
        maxResults: 5,
        tokenBudget: 2000,
      ),
      policy,
    );
    watch.stop();
    final ids = [for (final hit in pack.hits) hit.chunk.id];
    final normalizedContents = {
      for (final hit in pack.hits)
        hit.chunk.content.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' '),
    };
    results.add({
      'work': work,
      'query': queryText,
      'elapsedMs': watch.elapsedMicroseconds / 1000.0,
      'returnedHits': pack.hits.length,
      'uniqueHitIds': ids.toSet().length,
      'exactDuplicateHitCount': pack.hits.length - normalizedContents.length,
      'projectLeakCount': pack.hits
          .where(
            (hit) =>
                hit.chunk.projectId !=
                NovelCorpusImporter.projectIdForWork(work),
          )
          .length,
      'topHitIds': ids,
    });
  }
  return results;
}

const _smokeQueries = <String, String>{
  'jianlai': '陈平安 泥瓶巷',
  'guimi': '克莱恩 灰雾 塔罗会',
  'tigui': '乔汨 马氏集团',
};

void _validateRetrievalSmoke(List<Map<String, Object?>> results) {
  for (final result in results) {
    if ((result['returnedHits'] as int) == 0) {
      throw StateError('Smoke query returned no hits for ${result['work']}');
    }
    if ((result['projectLeakCount'] as int) != 0) {
      throw StateError('Smoke query leaked projects for ${result['work']}');
    }
    if ((result['exactDuplicateHitCount'] as int) != 0) {
      throw StateError('Smoke query returned duplicates for ${result['work']}');
    }
  }
}

int _count(Database db, String table) =>
    db.select('SELECT count(*) AS count FROM $table').single['count'] as int;

void _rejectProductionDatabase(File candidate) {
  final home = Platform.environment['HOME'] ?? '';
  final forbidden = <File>[
    if (home.isNotEmpty)
      _canonicalFile(
        File('$home/Library/Application Support/NovelWriter/authoring.db'),
      ),
    if (home.isNotEmpty)
      _canonicalFile(
        File(
          '$home/Library/Containers/com.example.novelWriter/Data/Library/'
          'Application Support/NovelWriter/authoring.db',
        ),
      ),
  ];
  for (final production in forbidden) {
    final samePath = production.path == candidate.path;
    var sameFile = false;
    if (!samePath && production.existsSync() && candidate.existsSync()) {
      sameFile = FileSystemEntity.identicalSync(
        production.path,
        candidate.path,
      );
    }
    if (samePath || sameFile) {
      throw const FormatException(
        'refusing to import a reference corpus into the production authoring.db',
      );
    }
  }
}

void _validateStagingDatabaseFiles(File databaseFile) {
  for (final suffix in const ['', '-wal', '-shm']) {
    final path = '${databaseFile.path}$suffix';
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) continue;
    if (type != FileSystemEntityType.file) {
      throw FormatException(
        'refusing to use non-regular staging database file: $path',
      );
    }
    _rejectProductionDatabase(_canonicalFile(File(path)));
  }
}

File _canonicalFile(File file) {
  final normalized = File.fromUri(file.absolute.uri.normalizePath());
  if (normalized.existsSync()) {
    return File(normalized.resolveSymbolicLinksSync());
  }
  final parent = normalized.parent;
  if (!parent.existsSync()) return normalized;
  final canonicalParent = Directory(parent.resolveSymbolicLinksSync());
  final name = normalized.uri.pathSegments.lastWhere(
    (segment) => segment.isNotEmpty,
  );
  return File('${canonicalParent.path}/$name');
}

class _TargetPublicationGuard {
  _TargetPublicationGuard._({
    required this.targetFile,
    required RandomAccessFile lockHandle,
    required _TargetIdentity? initialIdentity,
  }) : _lockHandle = lockHandle,
       _initialIdentity = initialIdentity;

  static Future<_TargetPublicationGuard> acquire(
    File targetFile, {
    required bool captureTargetIdentity,
  }) async {
    final lockFile = File('${targetFile.path}.import.lock');
    final lockType = FileSystemEntity.typeSync(
      lockFile.path,
      followLinks: false,
    );
    if (lockType != FileSystemEntityType.notFound &&
        lockType != FileSystemEntityType.file) {
      throw FormatException(
        'refusing to use non-regular import lock file: ${lockFile.path}',
      );
    }
    final handle = lockFile.openSync(mode: FileMode.append);
    try {
      handle.lockSync(FileLock.exclusive);
      final identity = captureTargetIdentity
          ? await _TargetIdentity.capture(targetFile)
          : null;
      return _TargetPublicationGuard._(
        targetFile: targetFile,
        lockHandle: handle,
        initialIdentity: identity,
      );
    } catch (_) {
      handle.closeSync();
      rethrow;
    }
  }

  final File targetFile;
  final RandomAccessFile _lockHandle;
  final _TargetIdentity? _initialIdentity;
  var _closed = false;

  Future<void> verifyBeforePublish({required bool replace}) async {
    _rejectDatabaseSidecars(targetFile, label: 'target');
    if (!replace) {
      if (targetFile.existsSync()) {
        throw StateError(
          'target database appeared during import; refusing to overwrite it',
        );
      }
      return;
    }
    final currentIdentity = await _TargetIdentity.capture(targetFile);
    if (currentIdentity != _initialIdentity) {
      throw StateError(
        'target database changed during import; refusing to overwrite it: '
        '${targetFile.path}',
      );
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    try {
      _lockHandle.unlockSync();
    } finally {
      _lockHandle.closeSync();
    }
  }
}

class _TargetIdentity {
  const _TargetIdentity({
    required this.length,
    required this.modifiedMilliseconds,
    required this.sha256,
  });

  static Future<_TargetIdentity?> capture(File file) async {
    if (!file.existsSync()) return null;
    final stat = file.statSync();
    if (stat.type != FileSystemEntityType.file) {
      throw FormatException(
        'refusing to publish over a non-regular target: ${file.path}',
      );
    }
    return _TargetIdentity(
      length: stat.size,
      modifiedMilliseconds: stat.modified.millisecondsSinceEpoch,
      sha256: await _sha256File(file),
    );
  }

  final int length;
  final int modifiedMilliseconds;
  final String sha256;

  @override
  bool operator ==(Object other) =>
      other is _TargetIdentity &&
      other.length == length &&
      other.modifiedMilliseconds == modifiedMilliseconds &&
      other.sha256 == sha256;

  @override
  int get hashCode => Object.hash(length, modifiedMilliseconds, sha256);
}

void _rejectDatabaseSidecars(File databaseFile, {required String label}) {
  for (final suffix in const ['-wal', '-shm']) {
    final sidecar = File('${databaseFile.path}$suffix');
    if (FileSystemEntity.typeSync(sidecar.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw StateError(
        '$label database has an active or stale $suffix sidecar; refusing '
        'to publish: ${sidecar.path}',
      );
    }
  }
}

void _checkpointAndSealStagingDatabase(Database db) {
  final checkpoint = db.select('PRAGMA wal_checkpoint(TRUNCATE)');
  if (checkpoint.length != 1 || checkpoint.single.values.length < 3) {
    throw StateError('SQLite returned an invalid WAL checkpoint result');
  }
  final values = checkpoint.single.values;
  final busy = values[0] as int;
  final logFrames = values[1] as int;
  final checkpointedFrames = values[2] as int;
  if (busy != 0 || checkpointedFrames != logFrames) {
    throw StateError(
      'WAL checkpoint did not complete: busy=$busy, log=$logFrames, '
      'checkpointed=$checkpointedFrames',
    );
  }
  final journalMode = db.select('PRAGMA journal_mode = DELETE');
  final mode = journalMode.single.values.single.toString().toLowerCase();
  if (mode != 'delete') {
    throw StateError('Unable to seal staging database: journal_mode=$mode');
  }
}

void _deleteDatabaseFiles(File databaseFile) {
  for (final suffix in const ['', '-wal', '-shm']) {
    final file = File('${databaseFile.path}$suffix');
    if (file.existsSync()) file.deleteSync();
  }
}

class _Config {
  const _Config({
    required this.databasePath,
    required this.corpusRootPath,
    required this.works,
    required this.limitPerWork,
    required this.batchSize,
    required this.replace,
    required this.resume,
    required this.jsonOutput,
    required this.showHelp,
    required this.profileOnly,
    required this.embeddingProvider,
    required this.embeddingModel,
    required this.embeddingDimensions,
    required this.ollamaBaseUrl,
    required this.ollamaBatchSize,
    required this.ollamaTimeoutSeconds,
    required this.lmStudioBaseUrl,
    required this.lmStudioBatchSize,
    required this.lmStudioTimeoutSeconds,
    required this.llamaCppBaseUrl,
    required this.llamaCppBatchSize,
    required this.llamaCppTimeoutSeconds,
    required this.profileQueries,
  });

  factory _Config.parse(List<String> arguments) {
    final values = <String, String>{};
    var replace = false;
    var resume = false;
    var jsonOutput = false;
    var showHelp = false;
    var profileOnly = false;
    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];
      if (argument == '--replace') {
        replace = true;
        continue;
      }
      if (argument == '--resume') {
        resume = true;
        continue;
      }
      if (argument == '--json') {
        jsonOutput = true;
        continue;
      }
      if (argument == '--help' || argument == '-h') {
        showHelp = true;
        continue;
      }
      if (argument == '--profile-only') {
        profileOnly = true;
        continue;
      }
      if (!argument.startsWith('--')) {
        throw FormatException('unexpected argument: $argument');
      }
      final equals = argument.indexOf('=');
      if (equals >= 0) {
        values[argument.substring(2, equals)] = argument.substring(equals + 1);
        continue;
      }
      if (index + 1 >= arguments.length ||
          arguments[index + 1].startsWith('--')) {
        throw FormatException('missing value for $argument');
      }
      values[argument.substring(2)] = arguments[++index];
    }
    const known = {
      'database',
      'corpus-root',
      'works',
      'limit-per-work',
      'batch-size',
      'embedding-provider',
      'embedding-model',
      'embedding-dimensions',
      'ollama-base-url',
      'ollama-batch-size',
      'ollama-timeout-seconds',
      'lmstudio-base-url',
      'lmstudio-batch-size',
      'lmstudio-timeout-seconds',
      'llamacpp-base-url',
      'llamacpp-batch-size',
      'llamacpp-timeout-seconds',
      'query-jianlai',
      'query-guimi',
      'query-tigui',
    };
    final unknown = values.keys.where((key) => !known.contains(key));
    if (unknown.isNotEmpty) {
      throw FormatException('unknown option: --${unknown.first}');
    }
    final databasePath = values['database']?.trim() ?? '';
    if (!showHelp && databasePath.isEmpty) {
      throw const FormatException('--database is required');
    }
    final works = (values['works'] ?? 'jianlai,guimi,tigui')
        .split(',')
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (works.isEmpty ||
        works.any((work) => !NovelCorpusImporter.defaultWorks.contains(work))) {
      throw const FormatException(
        '--works must contain only jianlai, guimi, or tigui',
      );
    }
    final embeddingProvider =
        values['embedding-provider']?.trim().toLowerCase() ?? 'local';
    if (embeddingProvider != 'local' &&
        embeddingProvider != 'ollama' &&
        embeddingProvider != 'lmstudio' &&
        embeddingProvider != 'llamacpp') {
      throw const FormatException(
        '--embedding-provider must be local, ollama, lmstudio, or llamacpp',
      );
    }
    if (resume && (replace || embeddingProvider == 'local')) {
      throw const FormatException(
        '--resume requires an external embedding provider and cannot be '
        'combined with --replace',
      );
    }
    final configuredModel = values['embedding-model']?.trim() ?? '';
    if ((embeddingProvider == 'lmstudio' || embeddingProvider == 'llamacpp') &&
        configuredModel.isEmpty) {
      throw const FormatException(
        '--embedding-model is required for lmstudio and llamacpp providers',
      );
    }
    final limitPerWork = _int(values, 'limit-per-work', 0);
    final embeddingDimensions = _int(values, 'embedding-dimensions', 4096);
    final ollamaBatchSize = _int(values, 'ollama-batch-size', 32);
    final ollamaTimeoutSeconds = _int(values, 'ollama-timeout-seconds', 600);
    final lmStudioBatchSize = _int(values, 'lmstudio-batch-size', 64);
    final lmStudioTimeoutSeconds = _int(
      values,
      'lmstudio-timeout-seconds',
      600,
    );
    final llamaCppBatchSize = _int(values, 'llamacpp-batch-size', 128);
    final llamaCppTimeoutSeconds = _int(
      values,
      'llamacpp-timeout-seconds',
      600,
    );
    final batchSize = _int(
      values,
      'batch-size',
      embeddingProvider == 'local'
          ? 500
          : embeddingProvider == 'llamacpp'
          ? llamaCppBatchSize
          : 64,
    );
    if (limitPerWork < 0 ||
        batchSize < 1 ||
        embeddingDimensions < 1 ||
        ollamaBatchSize < 1 ||
        ollamaTimeoutSeconds < 1 ||
        lmStudioBatchSize < 1 ||
        lmStudioTimeoutSeconds < 1 ||
        llamaCppBatchSize < 1 ||
        llamaCppTimeoutSeconds < 1) {
      throw const FormatException(
        'limits, dimensions, batch sizes, and timeout must be positive '
        '(limit-per-work may be zero)',
      );
    }
    return _Config(
      databasePath: databasePath,
      corpusRootPath: values['corpus-root'] ?? 'artifacts/writing_reference',
      works: works,
      limitPerWork: limitPerWork,
      batchSize: batchSize,
      replace: replace,
      resume: resume,
      jsonOutput: jsonOutput,
      showHelp: showHelp,
      profileOnly: profileOnly,
      embeddingProvider: embeddingProvider,
      embeddingModel: configuredModel.isNotEmpty
          ? configuredModel
          : 'qwen3-embedding:latest',
      embeddingDimensions: embeddingDimensions,
      ollamaBaseUrl:
          values['ollama-base-url']?.trim() ?? 'http://127.0.0.1:11434',
      ollamaBatchSize: ollamaBatchSize,
      ollamaTimeoutSeconds: ollamaTimeoutSeconds,
      lmStudioBaseUrl:
          values['lmstudio-base-url']?.trim() ?? 'http://127.0.0.1:1234',
      lmStudioBatchSize: lmStudioBatchSize,
      lmStudioTimeoutSeconds: lmStudioTimeoutSeconds,
      llamaCppBaseUrl:
          values['llamacpp-base-url']?.trim() ?? 'http://127.0.0.1:1235',
      llamaCppBatchSize: llamaCppBatchSize,
      llamaCppTimeoutSeconds: llamaCppTimeoutSeconds,
      profileQueries: {
        for (final work in NovelCorpusImporter.defaultWorks)
          work: values['query-$work']?.trim().isNotEmpty == true
              ? values['query-$work']!.trim()
              : _smokeQueries[work]!,
      },
    );
  }

  final String databasePath;
  final String corpusRootPath;
  final List<String> works;
  final int limitPerWork;
  final int batchSize;
  final bool replace;
  final bool resume;
  final bool jsonOutput;
  final bool showHelp;
  final bool profileOnly;
  final String embeddingProvider;
  final String embeddingModel;
  final int embeddingDimensions;
  final String ollamaBaseUrl;
  final int ollamaBatchSize;
  final int ollamaTimeoutSeconds;
  final String lmStudioBaseUrl;
  final int lmStudioBatchSize;
  final int lmStudioTimeoutSeconds;
  final String llamaCppBaseUrl;
  final int llamaCppBatchSize;
  final int llamaCppTimeoutSeconds;
  final Map<String, String> profileQueries;

  static int _int(Map<String, String> values, String name, int fallback) {
    final raw = values[name];
    if (raw == null) return fallback;
    final parsed = int.tryParse(raw);
    if (parsed == null) throw FormatException('--$name must be an integer');
    return parsed;
  }
}

const _usage = '''
Usage: dart run tool/novel_corpus_import.dart --database PATH [options]

Options:
  --corpus-root PATH       Corpus root (default: artifacts/writing_reference)
  --works LIST             Comma-separated slugs (default: jianlai,guimi,tigui)
  --limit-per-work N       Deterministic whole-book sample; 0 imports all (default: 0)
  --batch-size N           Checkpoint/write batch (local: 500, external: 64)
  --embedding-provider P   local, ollama, lmstudio, or llamacpp (default: local)
  --embedding-model NAME   External model (default: qwen3-embedding:latest)
  --embedding-dimensions N Expected dimensions (default: 4096)
  --ollama-base-url URL    Ollama endpoint (default: http://127.0.0.1:11434)
  --ollama-batch-size N    Inputs per Ollama request (default: 32)
  --ollama-timeout-seconds N  Per-request timeout (default: 600)
  --lmstudio-base-url URL  LM Studio endpoint (default: http://127.0.0.1:1234)
  --lmstudio-batch-size N  Application inputs per request (default: 64; two identity probes are appended)
  --lmstudio-timeout-seconds N  Per-request timeout (default: 600)
  --llamacpp-base-url URL  llama.cpp endpoint (default: http://127.0.0.1:1235)
  --llamacpp-batch-size N  Application inputs per request (default: 128; two identity probes are appended)
  --llamacpp-timeout-seconds N  Per-request timeout (default: 600)
  --query-jianlai TEXT     Override Jianlai profile query
  --query-guimi TEXT       Override Guimi profile query
  --query-tigui TEXT       Override Tigui profile query
  --replace                Replace the explicitly supplied isolated database
  --resume                 Resume a matching external-model .building database
  --profile-only           Profile FTS/vector/hybrid on an existing database
  --json                   Emit compact JSON
  --help, -h               Show this help
''';
