import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import 'vector_store_schema.dart';

const int vectorEmbeddingProfileSchemaVersion = 1;
const String vectorEmbeddingProfileMetaKey = 'embedding_profile_json';
const String _vectorIndexMetaTable = 'vector_index_meta';

/// Immutable identity of the embedding space stored in one vector database.
class VectorEmbeddingProfile {
  VectorEmbeddingProfile({
    required this.provider,
    required this.model,
    required String modelDigest,
    required this.dimension,
    this.normalization = 'l2',
    this.storageEncoding = 'float32-le',
    this.inputTransform = 'raw-text-v1',
  }) : modelDigest = _normalizeDigest(modelDigest) {
    if (provider.trim().isEmpty || model.trim().isEmpty) {
      throw ArgumentError('Embedding provider and model must not be empty');
    }
    if (dimension <= 0) {
      throw ArgumentError.value(dimension, 'dimension', 'must be positive');
    }
    if (normalization != 'l2' || storageEncoding != 'float32-le') {
      throw ArgumentError(
        'Only l2 normalization with float32-le storage is supported',
      );
    }
    if (inputTransform.trim().isEmpty) {
      throw ArgumentError.value(
        inputTransform,
        'inputTransform',
        'must not be empty',
      );
    }
  }

  factory VectorEmbeddingProfile.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != vectorEmbeddingProfileSchemaVersion) {
      throw const FormatException('Unsupported embedding profile schema');
    }
    final dimension = json['dimension'];
    if (dimension is! int) {
      throw const FormatException('Embedding profile dimension must be an int');
    }
    return VectorEmbeddingProfile(
      provider: json['provider']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      modelDigest: json['modelDigest']?.toString() ?? '',
      dimension: dimension,
      normalization: json['normalization']?.toString() ?? '',
      storageEncoding: json['storageEncoding']?.toString() ?? '',
      inputTransform: json['inputTransform']?.toString() ?? '',
    );
  }

  final String provider;
  final String model;
  final String modelDigest;
  final int dimension;
  final String normalization;
  final String storageEncoding;
  final String inputTransform;

  Map<String, Object> toJson() => {
    'schemaVersion': vectorEmbeddingProfileSchemaVersion,
    'provider': provider,
    'model': model,
    'modelDigest': modelDigest,
    'dimension': dimension,
    'normalization': normalization,
    'storageEncoding': storageEncoding,
    'inputTransform': inputTransform,
  };

  String get canonicalJson => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      other is VectorEmbeddingProfile && canonicalJson == other.canonicalJson;

  @override
  int get hashCode => canonicalJson.hashCode;

  static String _normalizeDigest(String value) {
    final normalized = value.trim().toLowerCase();
    final raw = normalized.startsWith('sha256:')
        ? normalized.substring('sha256:'.length)
        : normalized;
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(raw)) {
      throw ArgumentError.value(
        value,
        'modelDigest',
        'must be a SHA-256 digest',
      );
    }
    return 'sha256:$raw';
  }
}

/// Binds an empty vector database to [expected] or validates an existing bind.
///
/// A populated unbound database fails closed: dimension equality alone cannot
/// prove that its vectors came from the same model and input transform.
void bindOrValidateVectorEmbeddingProfile(
  Database db,
  VectorEmbeddingProfile expected, {
  bool allowLlamaCppModelDigestDrift = false,
}) {
  _ensureMetaTable(db);
  final rows = db.select(
    'SELECT value FROM $_vectorIndexMetaTable WHERE key = ?',
    [vectorEmbeddingProfileMetaKey],
  );
  final vectorCount =
      db
              .select('SELECT COUNT(*) AS count FROM $vectorEmbeddingsTable')
              .single['count']
          as int;
  if (rows.isEmpty) {
    if (vectorCount != 0) {
      throw StateError(
        'Refusing to bind a populated vector database without an embedding '
        'profile; rebuild it with the configured model',
      );
    }
    db.execute(
      'INSERT INTO $_vectorIndexMetaTable (key, value) VALUES (?, ?)',
      [vectorEmbeddingProfileMetaKey, expected.canonicalJson],
    );
    return;
  }

  final actual = _decodeProfile(rows.single['value'] as String);
  if (actual != expected &&
      !(allowLlamaCppModelDigestDrift &&
          embeddingProfilesCompatibleForLlamaCppDrift(actual, expected))) {
    throw StateError(
      'Embedding profile mismatch: database=${actual.canonicalJson}, '
      'runtime=${expected.canonicalJson}',
    );
  }
  _validateStoredDimensions(db, expected, vectorCount: vectorCount);
}

VectorEmbeddingProfile? readVectorEmbeddingProfile(Database db) {
  _ensureMetaTable(db);
  final rows = db.select(
    'SELECT value FROM $_vectorIndexMetaTable WHERE key = ?',
    [vectorEmbeddingProfileMetaKey],
  );
  return rows.isEmpty ? null : _decodeProfile(rows.single['value'] as String);
}

/// Rejects malformed, non-finite, zero, or wrong-dimensional model output.
void validateEmbeddingBatch(
  VectorEmbeddingProfile profile,
  List<List<double>> embeddings, {
  required int expectedCount,
}) {
  if (embeddings.length != expectedCount) {
    throw StateError(
      'Embedding provider returned ${embeddings.length} vectors for '
      '$expectedCount inputs',
    );
  }
  for (
    var embeddingIndex = 0;
    embeddingIndex < embeddings.length;
    embeddingIndex++
  ) {
    final embedding = embeddings[embeddingIndex];
    if (embedding.length != profile.dimension) {
      throw StateError(
        'Embedding $embeddingIndex has ${embedding.length} dimensions; '
        'expected ${profile.dimension}',
      );
    }
    var normSquared = 0.0;
    for (final value in embedding) {
      if (!value.isFinite) {
        throw StateError(
          'Embedding $embeddingIndex contains a non-finite value',
        );
      }
      normSquared += value * value;
    }
    if (normSquared == 0) {
      throw StateError('Embedding $embeddingIndex is a zero vector');
    }
  }
}

/// Full acceptance audit for a completed external-embedding vector index.
void auditVectorEmbeddingIndex(
  Database db,
  VectorEmbeddingProfile expected, {
  bool allowLlamaCppModelDigestDrift = false,
}) {
  bindOrValidateVectorEmbeddingProfile(
    db,
    expected,
    allowLlamaCppModelDigestDrift: allowLlamaCppModelDigestDrift,
  );
  final vectorCount =
      db
              .select('SELECT COUNT(*) AS count FROM $vectorEmbeddingsTable')
              .single['count']
          as int;
  _validateStoredDimensions(db, expected, vectorCount: vectorCount);
  final invalidBucketRows =
      db.select('''
        SELECT COUNT(*) AS count FROM (
          SELECT e.row_id
          FROM $vectorEmbeddingsTable AS e
          LEFT JOIN $vectorLshBucketsTable AS b
            ON b.vector_row_id = e.row_id
          GROUP BY e.row_id
          HAVING COUNT(b.table_no) != $vectorLshTableCount
        )
      ''').single['count']
          as int;
  if (invalidBucketRows != 0) {
    throw StateError(
      '$invalidBucketRows vectors do not have exactly '
      '$vectorLshTableCount LSH buckets',
    );
  }
}

/// Returns true when two llama.cpp profiles describe the same vector contract
/// and only the slot-dependent behavior fingerprint differs.
bool embeddingProfilesCompatibleForLlamaCppDrift(
  VectorEmbeddingProfile actual,
  VectorEmbeddingProfile expected,
) {
  return actual.provider == 'llamacpp' &&
      expected.provider == 'llamacpp' &&
      actual.model == expected.model &&
      actual.dimension == expected.dimension &&
      actual.normalization == expected.normalization &&
      actual.storageEncoding == expected.storageEncoding &&
      actual.inputTransform == expected.inputTransform;
}

void _validateStoredDimensions(
  Database db,
  VectorEmbeddingProfile expected, {
  required int vectorCount,
}) {
  if (vectorCount == 0) return;
  final row = db.select('''
    SELECT MIN(dimension) AS minimum_dimension,
      MAX(dimension) AS maximum_dimension,
      SUM(CASE WHEN length(embedding_blob) != dimension * 4 THEN 1 ELSE 0 END)
        AS invalid_blob_count
    FROM $vectorEmbeddingsTable
  ''').single;
  final minimum = row['minimum_dimension'] as int;
  final maximum = row['maximum_dimension'] as int;
  final invalidBlobCount = row['invalid_blob_count'] as int;
  if (minimum != expected.dimension ||
      maximum != expected.dimension ||
      invalidBlobCount != 0) {
    throw StateError(
      'Stored vector contract mismatch: dimensions=$minimum..$maximum, '
      'expected=${expected.dimension}, invalidBlobs=$invalidBlobCount',
    );
  }
}

VectorEmbeddingProfile _decodeProfile(String value) {
  final decoded = jsonDecode(value);
  if (decoded is! Map) {
    throw const FormatException('Embedding profile must be a JSON object');
  }
  return VectorEmbeddingProfile.fromJson(Map<String, Object?>.from(decoded));
}

void _ensureMetaTable(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS $_vectorIndexMetaTable (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    ) WITHOUT ROWID
  ''');
}
