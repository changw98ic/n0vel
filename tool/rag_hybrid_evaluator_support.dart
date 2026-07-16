import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/rag/hybrid_retriever.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/memory_policy.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/rag_retrieval_policy.dart';
import 'package:novel_writer/features/story_generation/domain/memory_models.dart';
import 'package:sqlite3/sqlite3.dart';

const _argumentsEnvironmentKey = 'NOVEL_WRITER_RAG_HYBRID_ARGUMENTS';
const _resultEnvironmentKey = 'NOVEL_WRITER_RAG_HYBRID_RESULT';

void main() {
  test('runs the real local Hybrid RAG performance evaluator', () async {
    final resultPath = Platform.environment[_resultEnvironmentKey];
    if (resultPath == null || resultPath.isEmpty) {
      throw StateError('Missing $_resultEnvironmentKey');
    }
    final rawArguments = Platform.environment[_argumentsEnvironmentKey] ?? '[]';
    final arguments = (jsonDecode(rawArguments) as List<dynamic>)
        .cast<String>();
    late Map<String, Object?> envelope;
    try {
      final report = await _runEvaluator(arguments);
      envelope = {'exitCode': report['pass'] == true ? 0 : 1, 'report': report};
    } on FormatException catch (error) {
      envelope = {'exitCode': 64, 'argumentError': error.message};
    } catch (error, stackTrace) {
      envelope = {
        'exitCode': 1,
        'runtimeError': error.toString(),
        'stackTrace': stackTrace.toString(),
      };
      rethrow;
    } finally {
      File(resultPath).writeAsStringSync(jsonEncode(envelope), flush: true);
    }
  }, timeout: Timeout.none);
}

Future<Map<String, Object?>> _runEvaluator(List<String> arguments) async {
  final config = _Config.parse(arguments);

  final tempDirectory = await Directory.systemTemp.createTemp(
    'novel_writer_rag_hybrid_evaluator_',
  );
  final failures = <String>[];
  try {
    final workloads = <Map<String, Object?>>[];
    for (final kind in _CorpusKind.values) {
      stderr.writeln(
        'Evaluating ${kind.label} corpus: ${config.documents} documents, '
        '${config.queries} warm queries...',
      );
      final result = await _evaluateWorkload(
        config: config,
        kind: kind,
        directory: tempDirectory,
      );
      workloads.add(result);
      final warmP95 =
          (result['warm']! as Map<String, Object?>)['p95Ms']! as double;
      if (warmP95 > config.maxP95Ms) {
        failures.add(
          '${kind.label} warm p95 ${warmP95.toStringAsFixed(3)}ms exceeds '
          '${config.maxP95Ms.toStringAsFixed(3)}ms',
        );
      }
      final diagnostics = result['diagnostics']! as Map<String, Object?>;
      if ((diagnostics['maxExpansionRounds']! as int) > 2) {
        failures.add(
          '${kind.label} used ${diagnostics['maxExpansionRounds']} expansion '
          'rounds; acceptance maximum is 2',
        );
      }
      for (final phase in const ['cold', 'warm']) {
        final phaseResult = result[phase]! as Map<String, Object?>;
        final returnedHits =
            phaseResult['returnedHits']! as Map<String, Object>;
        final minimumReturnedHits = returnedHits['min']! as int;
        if (minimumReturnedHits < 10) {
          failures.add(
            '${kind.label} $phase returned only $minimumReturnedHits hits; '
            'acceptance minimum is 10',
          );
        }
      }
    }

    final coldLatencies = <double>[
      for (final workload in workloads)
        ...((workload['cold']! as Map<String, Object?>)['latenciesMs']!
                as List<Object?>)
            .cast<double>(),
    ];
    final warmLatencies = <double>[
      for (final workload in workloads)
        ...((workload['warm']! as Map<String, Object?>)['latenciesMs']!
                as List<Object?>)
            .cast<double>(),
    ];
    return <String, Object?>{
      'schemaVersion': 1,
      'pass': failures.isEmpty,
      'failures': failures,
      'config': config.toJson(),
      'environment': {
        'dart': Platform.version,
        'operatingSystem': Platform.operatingSystem,
        'operatingSystemVersion': Platform.operatingSystemVersion,
        'sqlite': sqlite3.version.libVersion,
      },
      'pipeline': const [
        'defaultLocalEmbedding',
        'FTS5/CJK',
        'SqliteVssStore',
        'hybridFusion',
        'nearDuplicateSuppression',
        'tokenBudget',
      ],
      'aggregate': {
        'cold': _latencySummary(coldLatencies),
        'warm': _latencySummary(warmLatencies),
      },
      'workloads': workloads,
    };
  } finally {
    if (tempDirectory.existsSync()) {
      await tempDirectory.delete(recursive: true);
    }
  }
}

Future<Map<String, Object?>> _evaluateWorkload({
  required _Config config,
  required _CorpusKind kind,
  required Directory directory,
}) async {
  final databasePath = '${directory.path}/${kind.name}.db';
  final database = sqlite3.open(databasePath);
  try {
    final diagnosticsCapture = _DiagnosticsCapture();
    final retriever = HybridRetriever.local(
      db: database,
      onDiagnostics: diagnosticsCapture.record,
    );

    final indexWatch = Stopwatch()..start();
    for (
      var offset = 0;
      offset < config.documents;
      offset += config.batchSize
    ) {
      final end = math.min(offset + config.batchSize, config.documents);
      await retriever.indexChunks([
        for (var index = offset; index < end; index++)
          _chunk(kind: kind, index: index),
      ]);
    }
    indexWatch.stop();

    final coldSamples = <_Sample>[];
    coldSamples.add(
      await _measure(
        retriever: retriever,
        diagnosticsCapture: diagnosticsCapture,
        query: _query(kind: kind, ordinal: 0, documentCount: config.documents),
      ),
    );

    final warmSamples = <_Sample>[];
    for (var ordinal = 1; ordinal <= config.queries; ordinal++) {
      warmSamples.add(
        await _measure(
          retriever: retriever,
          diagnosticsCapture: diagnosticsCapture,
          query: _query(
            kind: kind,
            ordinal: ordinal,
            documentCount: config.documents,
          ),
        ),
      );
    }

    return {
      'name': kind.label,
      'documents': config.documents,
      'databaseBytes': File(databasePath).lengthSync(),
      'indexBuildMs': indexWatch.elapsedMicroseconds / 1000.0,
      'cold': _sampleSummary(coldSamples),
      'warm': _sampleSummary(warmSamples),
      'diagnostics': _diagnosticsSummary([...coldSamples, ...warmSamples]),
    };
  } finally {
    database.dispose();
  }
}

Future<_Sample> _measure({
  required HybridRetriever retriever,
  required _DiagnosticsCapture diagnosticsCapture,
  required StoryMemoryQuery query,
}) async {
  diagnosticsCapture.reset();
  final watch = Stopwatch()..start();
  final pack = await retriever.retrieve(query, _policy);
  watch.stop();
  final diagnostics = diagnosticsCapture.take();
  return _Sample(
    elapsedMs: watch.elapsedMicroseconds / 1000.0,
    returnedHits: pack.hits.length,
    deferredHits: pack.deferredHitCount,
    spentTokens: pack.spentTokenEstimate,
    diagnostics: diagnostics,
  );
}

Map<String, Object?> _sampleSummary(List<_Sample> samples) {
  final latency = _latencySummary([
    for (final sample in samples) sample.elapsedMs,
  ]);
  return {
    ...latency,
    'latenciesMs': [for (final sample in samples) sample.elapsedMs],
    'returnedHits': _integerSummary([
      for (final sample in samples) sample.returnedHits,
    ]),
    'deferredHits': _integerSummary([
      for (final sample in samples) sample.deferredHits,
    ]),
    'spentTokens': _integerSummary([
      for (final sample in samples) sample.spentTokens,
    ]),
    'diagnostics': _diagnosticsSummary(samples),
  };
}

Map<String, Object?> _diagnosticsSummary(List<_Sample> samples) {
  final diagnostics = [for (final sample in samples) sample.diagnostics];
  return {
    'maxExpansionRounds': diagnostics
        .map((value) => value.expansionRounds)
        .reduce(math.max),
    'expansionRounds': [for (final value in diagnostics) value.expansionRounds],
    'candidateLimitsByQuery': [
      for (final value in diagnostics) value.candidateLimits,
    ],
    'maxFtsSearches': diagnostics
        .map((value) => value.ftsSearches)
        .reduce(math.max),
    'maxVectorSearches': diagnostics
        .map((value) => value.vectorSearches)
        .reduce(math.max),
    'maxNearDuplicateComparisons': diagnostics
        .map((value) => value.nearDuplicateComparisons)
        .reduce(math.max),
  };
}

Map<String, Object> _latencySummary(List<double> values) => {
  'samples': values.length,
  'p50Ms': _percentile(values, 0.50),
  'p95Ms': _percentile(values, 0.95),
  'minMs': values.reduce(math.min),
  'maxMs': values.reduce(math.max),
};

Map<String, Object> _integerSummary(List<int> values) => {
  'min': values.reduce(math.min),
  'max': values.reduce(math.max),
  'mean': values.reduce((left, right) => left + right) / values.length,
};

double _percentile(List<double> values, double percentile) {
  final sorted = [...values]..sort();
  final rank = math.max(1, (percentile * sorted.length).ceil());
  return sorted[rank - 1];
}

StoryMemoryChunk _chunk({required _CorpusKind kind, required int index}) {
  final content = switch (kind) {
    _CorpusKind.diverse => _diverseContent(index),
    _CorpusKind.nearDuplicate => _nearDuplicateContent(index),
  };
  return StoryMemoryChunk(
    id: '${kind.name}/memory_$index.md',
    projectId: kind.projectId,
    scopeId: kind.projectId,
    kind: MemorySourceKind.sceneSummary,
    content: content,
    tier: MemoryTier.scene,
    producer: 'rag-hybrid-evaluator',
    tags: const ['benchmark', 'scene'],
    tokenCostEstimate: 64,
    createdAtMs: index,
  );
}

String _diverseContent(int index) {
  const actors = ['银月骑士', '赤羽医师', '玄水商人', '青铜守卫', '白塔学者', '星港领航员'];
  const places = ['霜港', '雾城', '黑塔', '风谷', '月湖', '赤原', '深林'];
  const actions = ['发现密信', '修复航标', '追踪叛徒', '守护遗迹', '记录星象', '交换地图'];
  final actor = actors[index % actors.length];
  final place = places[(index ~/ actors.length) % places.length];
  final action =
      actions[(index ~/ (actors.length * places.length)) % actions.length];
  return '$actor在$place$action。档案编号 archive_key_$index，'
      '当夜风向为${index % 8}级，线索序列${index % 997}。';
}

String _nearDuplicateContent(int index) {
  // Keep every row distinct so this exercises near-duplicate suppression,
  // rather than collapsing to a handful of exact-content representatives.
  return '银月骑士在雾城北门发现同一封密信，守卫报告钟声响了三次。'
      '他把密信交给白塔学者，等待黎明议会核验。记录编号$index。';
}

StoryMemoryQuery _query({
  required _CorpusKind kind,
  required int ordinal,
  required int documentCount,
}) {
  final index = (ordinal * 7919 + 17) % documentCount;
  final text = switch (kind) {
    _CorpusKind.diverse => 'archive_key_$index 银月 档案线索',
    _CorpusKind.nearDuplicate => '银月骑士 雾城北门 密信 黎明议会',
  };
  return StoryMemoryQuery(
    projectId: kind.projectId,
    queryType: StoryMemoryQueryType.sceneContinuity,
    text: text,
    maxResults: 10,
    tokenBudget: 1024,
  );
}

const _policy = RagRetrievalPolicy(
  roleId: 'rag-hybrid-evaluator',
  allowedTiers: [MemoryTier.scene],
  maxTokens: 1024,
  excludeDraftTier: true,
  rankingStrategy: RankingStrategy.hybrid,
  semanticWeight: 0.6,
  keywordWeight: 0.4,
);

enum _CorpusKind {
  diverse('diverse', 'rag-eval-diverse'),
  nearDuplicate('near-duplicate', 'rag-eval-near-duplicate');

  const _CorpusKind(this.label, this.projectId);

  final String label;
  final String projectId;
}

class _Sample {
  const _Sample({
    required this.elapsedMs,
    required this.returnedHits,
    required this.deferredHits,
    required this.spentTokens,
    required this.diagnostics,
  });

  final double elapsedMs;
  final int returnedHits;
  final int deferredHits;
  final int spentTokens;
  final HybridRetrievalDiagnostics diagnostics;
}

class _DiagnosticsCapture {
  HybridRetrievalDiagnostics? _last;

  void reset() => _last = null;

  void record(HybridRetrievalDiagnostics diagnostics) => _last = diagnostics;

  HybridRetrievalDiagnostics take() {
    final value = _last;
    if (value == null) {
      throw StateError('HybridRetriever did not emit retrieval diagnostics');
    }
    return value;
  }
}

class _Config {
  const _Config({
    required this.documents,
    required this.queries,
    required this.maxP95Ms,
    required this.jsonOutput,
    required this.batchSize,
  });

  factory _Config.parse(List<String> arguments) {
    final values = <String, String>{};
    var jsonOutput = false;
    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];
      if (argument == '--json') {
        jsonOutput = true;
        continue;
      }
      if (!argument.startsWith('--')) {
        throw FormatException('Unexpected argument: $argument');
      }
      final equals = argument.indexOf('=');
      if (equals >= 0) {
        values[argument.substring(2, equals)] = argument.substring(equals + 1);
        continue;
      }
      if (index + 1 >= arguments.length ||
          arguments[index + 1].startsWith('--')) {
        throw FormatException('Missing value for $argument');
      }
      values[argument.substring(2)] = arguments[++index];
    }
    const known = {'documents', 'queries', 'max-p95-ms', 'batch-size'};
    final unknown = values.keys.where((name) => !known.contains(name));
    if (unknown.isNotEmpty) {
      throw FormatException('Unknown option: --${unknown.first}');
    }
    final config = _Config(
      documents: _int(values, 'documents', 100000),
      queries: _int(values, 'queries', 20),
      maxP95Ms: _double(values, 'max-p95-ms', 1000),
      jsonOutput: jsonOutput,
      batchSize: _int(values, 'batch-size', 500),
    );
    if (config.documents < 10) {
      throw const FormatException('--documents must be at least 10');
    }
    if (config.queries < 1) {
      throw const FormatException('--queries must be at least 1');
    }
    if (config.maxP95Ms <= 0 || config.batchSize < 1) {
      throw const FormatException(
        '--max-p95-ms and --batch-size must be positive',
      );
    }
    return config;
  }

  final int documents;
  final int queries;
  final double maxP95Ms;
  final bool jsonOutput;
  final int batchSize;

  Map<String, Object> toJson() => {
    'documentsPerCorpus': documents,
    'queriesPerCorpus': queries,
    'maxP95Ms': maxP95Ms,
    'batchSize': batchSize,
  };

  static int _int(Map<String, String> values, String name, int fallback) {
    final raw = values[name];
    if (raw == null) return fallback;
    final parsed = int.tryParse(raw);
    if (parsed == null) throw FormatException('--$name must be an integer');
    return parsed;
  }

  static double _double(
    Map<String, String> values,
    String name,
    double fallback,
  ) {
    final raw = values[name];
    if (raw == null) return fallback;
    final parsed = double.tryParse(raw);
    if (parsed == null) throw FormatException('--$name must be a number');
    return parsed;
  }
}
