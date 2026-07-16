import 'dart:math' as math;
import 'dart:typed_data';

import 'package:novel_writer/features/story_generation/domain/contracts/memory_policy.dart';

const int defaultVectorEvaluatorSeed = 20260710;

class RagVectorEvaluatorConfig {
  const RagVectorEvaluatorConfig({
    required this.vectorCount,
    required this.dimensions,
    required this.seed,
    required this.recallQueries,
    required this.latencyQueries,
    required this.warmupQueries,
    required this.latencyRounds,
    required this.limit,
    required this.maxCandidates,
    required this.minRecallAt10,
    required this.maxP95Ms,
    required this.maxReopenMs,
    required this.jsonOutput,
    required this.outputPath,
  });

  factory RagVectorEvaluatorConfig.parse(List<String> arguments) {
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

      final equalsIndex = argument.indexOf('=');
      if (equalsIndex >= 0) {
        values[argument.substring(2, equalsIndex)] = argument.substring(
          equalsIndex + 1,
        );
        continue;
      }
      if (index + 1 >= arguments.length ||
          arguments[index + 1].startsWith('--')) {
        throw FormatException('Missing value for $argument');
      }
      values[argument.substring(2)] = arguments[++index];
    }

    const knownKeys = {
      'vectors',
      'dimensions',
      'seed',
      'recall-queries',
      'latency-queries',
      'warmup-queries',
      'latency-rounds',
      'limit',
      'max-candidates',
      'min-recall-at-10',
      'max-p95-ms',
      'max-reopen-ms',
      'output',
    };
    final unknownKeys = values.keys.where((key) => !knownKeys.contains(key));
    if (unknownKeys.isNotEmpty) {
      throw FormatException('Unknown option: --${unknownKeys.first}');
    }

    final config = RagVectorEvaluatorConfig(
      vectorCount: _intOption(values, 'vectors', 100000),
      dimensions: _intOption(values, 'dimensions', 64),
      seed: _intOption(values, 'seed', defaultVectorEvaluatorSeed),
      recallQueries: _intOption(values, 'recall-queries', 16),
      latencyQueries: _intOption(values, 'latency-queries', 64),
      warmupQueries: _intOption(values, 'warmup-queries', 16),
      latencyRounds: _intOption(values, 'latency-rounds', 3),
      limit: _intOption(values, 'limit', 10),
      maxCandidates: _intOption(values, 'max-candidates', 8192),
      minRecallAt10: _doubleOption(values, 'min-recall-at-10', 0.80),
      maxP95Ms: _doubleOption(values, 'max-p95-ms', 250),
      maxReopenMs: _doubleOption(values, 'max-reopen-ms', 2000),
      jsonOutput: jsonOutput,
      outputPath: values['output'],
    );
    config.validate();
    return config;
  }

  final int vectorCount;
  final int dimensions;
  final int seed;
  final int recallQueries;
  final int latencyQueries;
  final int warmupQueries;
  final int latencyRounds;
  final int limit;
  final int maxCandidates;
  final double minRecallAt10;
  final double maxP95Ms;
  final double maxReopenMs;
  final bool jsonOutput;
  final String? outputPath;

  void validate() {
    if (vectorCount < 100) {
      throw const FormatException('--vectors must be at least 100');
    }
    if (dimensions < 16) {
      throw const FormatException('--dimensions must be at least 16');
    }
    if (recallQueries <= 0 || latencyQueries <= 0 || warmupQueries < 0) {
      throw const FormatException('Query counts must be positive');
    }
    if (latencyRounds <= 0 || limit <= 0 || maxCandidates < limit) {
      throw const FormatException('Invalid rounds, limit, or candidate budget');
    }
    if (minRecallAt10 < 0 ||
        minRecallAt10 > 1 ||
        maxP95Ms <= 0 ||
        maxReopenMs <= 0 ||
        outputPath?.trim().isEmpty == true) {
      throw const FormatException('Invalid recall or latency threshold');
    }
  }

  Map<String, Object> toJson() => {
    'vectors': vectorCount,
    'dimensions': dimensions,
    'seed': seed,
    'recallQueries': recallQueries,
    'latencyQueries': latencyQueries,
    'warmupQueries': warmupQueries,
    'latencyRounds': latencyRounds,
    'limit': limit,
    'maxCandidates': maxCandidates,
    'minRecallAt10': minRecallAt10,
    'maxP95Ms': maxP95Ms,
    'maxReopenMs': maxReopenMs,
  };

  static int _intOption(Map<String, String> values, String name, int fallback) {
    final raw = values[name];
    if (raw == null) return fallback;
    final parsed = int.tryParse(raw);
    if (parsed == null) throw FormatException('--$name must be an integer');
    return parsed;
  }

  static double _doubleOption(
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

class DeterministicVectorCorpus {
  DeterministicVectorCorpus._({
    required this.vectorCount,
    required this.dimensions,
    required this.seed,
    required this.values,
  });

  factory DeterministicVectorCorpus.generate({
    required int vectorCount,
    required int dimensions,
    required int seed,
  }) {
    const clusterCount = 257;
    const noiseScale = 0.035;
    final random = FixedXorShift32(seed);
    final centers = List<Float32List>.generate(clusterCount, (_) {
      final center = Float32List(dimensions);
      for (var dimension = 0; dimension < dimensions; dimension++) {
        center[dimension] = random.nextSignedDouble();
      }
      _normalize(center);
      return center;
    }, growable: false);

    final values = Float32List(vectorCount * dimensions);
    for (var vectorIndex = 0; vectorIndex < vectorCount; vectorIndex++) {
      final center = centers[vectorIndex % clusterCount];
      final offset = vectorIndex * dimensions;
      var squaredNorm = 0.0;
      for (var dimension = 0; dimension < dimensions; dimension++) {
        final value =
            center[dimension] + random.nextSignedDouble() * noiseScale;
        values[offset + dimension] = value;
        squaredNorm += value * value;
      }
      final norm = math.sqrt(squaredNorm);
      for (var dimension = 0; dimension < dimensions; dimension++) {
        values[offset + dimension] /= norm;
      }
    }

    return DeterministicVectorCorpus._(
      vectorCount: vectorCount,
      dimensions: dimensions,
      seed: seed,
      values: values,
    );
  }

  final int vectorCount;
  final int dimensions;
  final int seed;
  final Float32List values;

  String idAt(int index) => 'vector-$index';

  /// Keeps 90% of the corpus in one production-like scope while retaining
  /// cross-project and wrong-tier distractors to prove filter pushdown.
  String projectAt(int index) =>
      index % 20 == 0 ? 'project-distractor' : 'project-main';

  MemoryTier tierAt(int index) =>
      index % 20 == 1 ? MemoryTier.draft : MemoryTier.scene;

  int eligibleRowCount(String projectId, Set<MemoryTier> tiers) {
    var count = 0;
    for (var index = 0; index < vectorCount; index++) {
      if (projectAt(index) == projectId && tiers.contains(tierAt(index))) {
        count++;
      }
    }
    return count;
  }

  Float32List vectorAt(int index) {
    final offset = index * dimensions;
    return Float32List.sublistView(values, offset, offset + dimensions);
  }

  Float32List queryForOrdinal(int ordinal) {
    final vectorIndex = queryVectorIndex(ordinal);
    final query = Float32List.fromList(vectorAt(vectorIndex));
    final random = FixedXorShift32(seed ^ vectorIndex ^ (ordinal * 7919));
    for (var dimension = 0; dimension < dimensions; dimension++) {
      query[dimension] += random.nextSignedDouble() * 0.006;
    }
    _normalize(query);
    return query;
  }

  int queryVectorIndex(int ordinal) {
    final stride = math.max(1, vectorCount ~/ 97);
    var index = (ordinal * stride + 37) % vectorCount;
    while (projectAt(index) != 'project-main' ||
        tierAt(index) != MemoryTier.scene) {
      index = (index + 1) % vectorCount;
    }
    return index;
  }

  List<ExactVectorNeighbor> exactTopK({
    required List<double> query,
    required String projectId,
    required Set<MemoryTier> tiers,
    required int limit,
  }) {
    final best = <ExactVectorNeighbor>[];
    var queryNormSquared = 0.0;
    for (final value in query) {
      queryNormSquared += value * value;
    }
    final queryNorm = math.sqrt(queryNormSquared);

    for (var index = 0; index < vectorCount; index++) {
      if (projectAt(index) != projectId || !tiers.contains(tierAt(index))) {
        continue;
      }
      final offset = index * dimensions;
      var dot = 0.0;
      var rowNormSquared = 0.0;
      for (var dimension = 0; dimension < dimensions; dimension++) {
        final value = values[offset + dimension];
        dot += query[dimension] * value;
        rowNormSquared += value * value;
      }
      final denominator = queryNorm * math.sqrt(rowNormSquared);
      final score = denominator == 0 ? 0.0 : dot / denominator;
      final neighbor = ExactVectorNeighbor(id: idAt(index), score: score);
      _insertTopK(best, neighbor, limit);
    }
    return best;
  }

  static void _insertTopK(
    List<ExactVectorNeighbor> best,
    ExactVectorNeighbor candidate,
    int limit,
  ) {
    var insertionIndex = best.length;
    for (var index = 0; index < best.length; index++) {
      if (_compareNeighbors(candidate, best[index]) < 0) {
        insertionIndex = index;
        break;
      }
    }
    if (insertionIndex >= limit) return;
    best.insert(insertionIndex, candidate);
    if (best.length > limit) best.removeLast();
  }

  static int _compareNeighbors(
    ExactVectorNeighbor left,
    ExactVectorNeighbor right,
  ) {
    final scoreOrder = right.score.compareTo(left.score);
    if (scoreOrder != 0) return scoreOrder;
    return left.id.compareTo(right.id);
  }
}

class ExactVectorNeighbor {
  const ExactVectorNeighbor({required this.id, required this.score});

  final String id;
  final double score;
}

class FixedXorShift32 {
  FixedXorShift32(int seed) : _state = seed == 0 ? 0x6d2b79f5 : seed;

  int _state;

  int nextUint32() {
    var value = _state & 0xffffffff;
    value ^= (value << 13) & 0xffffffff;
    value ^= value >> 17;
    value ^= (value << 5) & 0xffffffff;
    _state = value & 0xffffffff;
    return _state;
  }

  double nextSignedDouble() => (nextUint32() / 0xffffffff) * 2.0 - 1.0;
}

double recallAtK(
  Iterable<String> actualIds,
  Iterable<String> expectedIds,
  int k,
) {
  if (k <= 0) throw ArgumentError.value(k, 'k', 'must be positive');
  final actual = actualIds.take(k).toSet();
  final expected = expectedIds.take(k).toSet();
  if (expected.isEmpty) return 1.0;
  return actual.intersection(expected).length / math.min(k, expected.length);
}

double nearestRankPercentile(List<double> samples, double percentile) {
  if (samples.isEmpty) {
    throw ArgumentError.value(samples, 'samples', 'must not be empty');
  }
  if (percentile <= 0 || percentile > 1) {
    throw ArgumentError.value(percentile, 'percentile', 'must be in (0, 1]');
  }
  final sorted = List<double>.from(samples)..sort();
  final rank = (percentile * sorted.length).ceil();
  return sorted[rank - 1];
}

double median(List<double> samples) => nearestRankPercentile(samples, 0.5);

void _normalize(Float32List vector) {
  var squaredNorm = 0.0;
  for (final value in vector) {
    squaredNorm += value * value;
  }
  final norm = math.sqrt(squaredNorm);
  if (norm == 0) return;
  for (var index = 0; index < vector.length; index++) {
    vector[index] /= norm;
  }
}
