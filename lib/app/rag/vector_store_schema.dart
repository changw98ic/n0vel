import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

// Bump whenever signatures, seeds, table count, or bits per table change.
const int vectorLshVersion = 2;
const int vectorLshTableCount = 16;
const int vectorLshBitsPerTable = 14;
const int vectorLshProbeRadius = 2;
const int vectorSchemaMigrationBatchSize = 256;
const String vectorAdmissionSchemaVersion = '1';

const String vectorEmbeddingsTable = 'vector_embeddings';
const String vectorLshBucketsTable = 'vector_lsh_buckets';
const String vectorLshLookupIndex = 'idx_vector_lsh_lookup';
const String legacyUnscopedVectorProjectId = '__legacy_unscoped__';
const String _vectorIndexMetaTable = 'vector_index_meta';

/// A single logical LSH table/bucket lookup.
class VectorLshProbe {
  const VectorLshProbe(this.tableNo, this.bucket);

  final int tableNo;
  final int bucket;
}

/// Creates the portable vector schema and upgrades the old JSON table in place.
///
/// This deliberately does not mutate `PRAGMA user_version`: authoring database
/// migrations own that value, while standalone/in-memory RAG databases may call
/// this helper directly.
void ensureVectorStoreSchema(Database db) {
  db.execute('SAVEPOINT vector_store_schema');
  try {
    final tableExists = _tableExists(db, vectorEmbeddingsTable);
    if (tableExists &&
        !_hasColumn(db, vectorEmbeddingsTable, 'embedding_blob')) {
      _migrateLegacyJsonTable(db);
    } else {
      _createVectorTables(db);
    }
    _ensureVectorAdmissionColumns(db);
    final hadAdmissionTags = _tableExists(db, 'vector_embedding_tags');
    _createVectorAdmissionTables(db);
    _createVectorIndexMeta(db);
    if (!hadAdmissionTags ||
        _vectorIndexMetaValue(db, 'admission_schema_version') !=
            vectorAdmissionSchemaVersion) {
      _backfillVectorAdmission(db);
      _setVectorIndexMeta(
        db,
        'admission_schema_version',
        vectorAdmissionSchemaVersion,
      );
    }
    _rebuildOutdatedLshBuckets(db);
    db.execute('RELEASE SAVEPOINT vector_store_schema');
  } catch (_) {
    db.execute('ROLLBACK TO SAVEPOINT vector_store_schema');
    db.execute('RELEASE SAVEPOINT vector_store_schema');
    rethrow;
  }
}

List<double> normalizeVector(List<double> embedding) {
  if (embedding.isEmpty) {
    throw ArgumentError.value(embedding, 'embedding', 'must not be empty');
  }
  var normSquared = 0.0;
  for (final value in embedding) {
    if (!value.isFinite) {
      throw ArgumentError.value(
        embedding,
        'embedding',
        'must contain only finite values',
      );
    }
    normSquared += value * value;
  }
  if (normSquared == 0) return List<double>.filled(embedding.length, 0);
  final inverseNorm = 1.0 / sqrt(normSquared);
  return [for (final value in embedding) value * inverseNorm];
}

Uint8List encodeFloat32Vector(List<double> normalizedEmbedding) {
  final bytes = ByteData(
    normalizedEmbedding.length * Float32List.bytesPerElement,
  );
  for (var i = 0; i < normalizedEmbedding.length; i++) {
    bytes.setFloat32(
      i * Float32List.bytesPerElement,
      normalizedEmbedding[i],
      Endian.little,
    );
  }
  return bytes.buffer.asUint8List();
}

List<double> decodeFloat32Vector(Object? blob, int dimension) {
  if (blob is! Uint8List) {
    throw const FormatException('Vector embedding is not a SQLite BLOB');
  }
  final expectedLength = dimension * Float32List.bytesPerElement;
  if (blob.lengthInBytes != expectedLength) {
    throw FormatException(
      'Vector BLOB length ${blob.lengthInBytes} does not match dimension $dimension',
    );
  }
  final bytes = ByteData.sublistView(blob);
  return [
    for (var i = 0; i < dimension; i++)
      bytes.getFloat32(i * Float32List.bytesPerElement, Endian.little),
  ];
}

List<int> vectorLshSignatures(List<double> normalizedEmbedding) {
  final hyperplanes = _hyperplanesForDimension(normalizedEmbedding.length);
  return [
    for (var table = 0; table < vectorLshTableCount; table++)
      _signatureForTable(normalizedEmbedding, hyperplanes, table),
  ];
}

List<VectorLshProbe> vectorLshProbes(
  List<double> normalizedEmbedding, {
  int radius = vectorLshProbeRadius,
}) {
  if (radius < 0 || radius > vectorLshProbeRadius) {
    throw RangeError.range(radius, 0, vectorLshProbeRadius, 'radius');
  }
  final signatures = vectorLshSignatures(normalizedEmbedding);
  final probes = <VectorLshProbe>[];
  for (var table = 0; table < signatures.length; table++) {
    final base = signatures[table];
    probes.add(VectorLshProbe(table, base));
    if (radius >= 1) {
      for (var first = 0; first < vectorLshBitsPerTable; first++) {
        probes.add(VectorLshProbe(table, base ^ (1 << first)));
      }
    }
    if (radius >= 2) {
      for (var first = 0; first < vectorLshBitsPerTable; first++) {
        for (var second = first + 1; second < vectorLshBitsPerTable; second++) {
          probes.add(
            VectorLshProbe(table, base ^ (1 << first) ^ (1 << second)),
          );
        }
      }
    }
  }
  return probes;
}

final Map<int, List<Int8List>> _hyperplanesByDimension = {};

List<Int8List> _hyperplanesForDimension(int dimension) {
  return _hyperplanesByDimension.putIfAbsent(dimension, () {
    final result = <Int8List>[];
    const count = vectorLshTableCount * vectorLshBitsPerTable;
    for (var plane = 0; plane < count; plane++) {
      var state = _mix32(
        0x6d2b79f5 ^ (dimension * 0x9e3779b9) ^ (plane * 0x85ebca6b),
      );
      final signs = Int8List(dimension);
      for (var component = 0; component < dimension; component++) {
        state = _xorshift32(state);
        signs[component] = (state & 1) == 0 ? -1 : 1;
      }
      result.add(signs);
    }
    return result;
  });
}

int _signatureForTable(
  List<double> embedding,
  List<Int8List> hyperplanes,
  int table,
) {
  var signature = 0;
  final offset = table * vectorLshBitsPerTable;
  for (var bit = 0; bit < vectorLshBitsPerTable; bit++) {
    final signs = hyperplanes[offset + bit];
    var projection = 0.0;
    for (var component = 0; component < embedding.length; component++) {
      projection += embedding[component] * signs[component];
    }
    if (projection >= 0) signature |= 1 << bit;
  }
  return signature;
}

int _xorshift32(int value) {
  var result = value & 0xffffffff;
  result ^= (result << 13) & 0xffffffff;
  result ^= result >>> 17;
  result ^= (result << 5) & 0xffffffff;
  return result & 0xffffffff;
}

int _mix32(int value) {
  var result = value & 0xffffffff;
  result ^= result >>> 16;
  result = (result * 0x7feb352d) & 0xffffffff;
  result ^= result >>> 15;
  result = (result * 0x846ca68b) & 0xffffffff;
  result ^= result >>> 16;
  return result & 0xffffffff;
}

void _createVectorTables(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS $vectorEmbeddingsTable (
      row_id INTEGER PRIMARY KEY,
      project_id TEXT NOT NULL CHECK (length(trim(project_id)) > 0),
      id TEXT NOT NULL,
      content TEXT NOT NULL,
      embedding_blob BLOB NOT NULL,
      dimension INTEGER NOT NULL CHECK (dimension > 0),
      tier TEXT NOT NULL,
      scope_id TEXT NOT NULL DEFAULT '',
      visibility TEXT NOT NULL DEFAULT 'publicObservable'
        CHECK (visibility IN ('publicObservable', 'agentPrivate', 'editorOnly')),
      owner_id TEXT NOT NULL DEFAULT ''
        CHECK (visibility != 'agentPrivate' OR length(trim(owner_id)) > 0),
      metadata_json TEXT NOT NULL DEFAULT '{}',
      lsh_version INTEGER NOT NULL DEFAULT $vectorLshVersion,
      UNIQUE (project_id, id)
    )
  ''');
  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_vector_embeddings_scope
    ON $vectorEmbeddingsTable (project_id, tier, dimension)
  ''');
  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_vector_embeddings_lsh_version
    ON $vectorEmbeddingsTable (lsh_version)
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS $vectorLshBucketsTable (
      vector_row_id INTEGER NOT NULL
        REFERENCES $vectorEmbeddingsTable(row_id) ON DELETE CASCADE,
      project_id TEXT NOT NULL,
      tier TEXT NOT NULL,
      dimension INTEGER NOT NULL,
      table_no INTEGER NOT NULL,
      bucket INTEGER NOT NULL,
      PRIMARY KEY (vector_row_id, table_no)
    ) WITHOUT ROWID
  ''');
  db.execute('''
    CREATE INDEX IF NOT EXISTS $vectorLshLookupIndex
    ON $vectorLshBucketsTable
      (project_id, tier, dimension, table_no, bucket, vector_row_id)
  ''');
}

void _ensureVectorAdmissionColumns(Database db) {
  final additions = <String, String>{
    'scope_id': "TEXT NOT NULL DEFAULT ''",
    'visibility': "TEXT NOT NULL DEFAULT 'publicObservable'",
    'owner_id': "TEXT NOT NULL DEFAULT ''",
  };
  for (final entry in additions.entries) {
    if (!_hasColumn(db, vectorEmbeddingsTable, entry.key)) {
      db.execute(
        'ALTER TABLE $vectorEmbeddingsTable ADD COLUMN ${entry.key} ${entry.value}',
      );
    }
  }
  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_vector_embeddings_admission
    ON $vectorEmbeddingsTable (project_id, tier, visibility, owner_id, scope_id, dimension)
  ''');
}

void _createVectorAdmissionTables(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS vector_embedding_tags (
      project_id TEXT NOT NULL,
      vector_row_id INTEGER NOT NULL
        REFERENCES $vectorEmbeddingsTable(row_id) ON DELETE CASCADE,
      tag TEXT NOT NULL CHECK (length(trim(tag)) > 0),
      PRIMARY KEY (project_id, vector_row_id, tag)
    ) WITHOUT ROWID
  ''');
  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_vector_embedding_tags_lookup
    ON vector_embedding_tags (project_id, tag, vector_row_id)
  ''');
}

void _createVectorIndexMeta(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS $_vectorIndexMetaTable (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    ) WITHOUT ROWID
  ''');
}

String? _vectorIndexMetaValue(Database db, String key) {
  final rows = db.select(
    'SELECT value FROM $_vectorIndexMetaTable WHERE key = ?',
    <Object?>[key],
  );
  return rows.isEmpty ? null : rows.single['value'] as String;
}

void _setVectorIndexMeta(Database db, String key, String value) {
  db.execute(
    '''
    INSERT INTO $_vectorIndexMetaTable (key, value) VALUES (?, ?)
    ON CONFLICT(key) DO UPDATE SET value = excluded.value
    ''',
    <Object?>[key, value],
  );
}

void _backfillVectorAdmission(Database db) {
  final update = db.prepare('''
    UPDATE $vectorEmbeddingsTable
    SET scope_id = ?, visibility = ?, owner_id = ? WHERE row_id = ?
  ''');
  final deleteTags = db.prepare(
    'DELETE FROM vector_embedding_tags WHERE vector_row_id = ?',
  );
  final insertTag = db.prepare('''
    INSERT INTO vector_embedding_tags (project_id, vector_row_id, tag)
    VALUES (?, ?, ?)
  ''');
  try {
    var lastRowId = -1;
    while (true) {
      final rows = db.select(
        '''
        SELECT row_id, project_id, metadata_json, scope_id, visibility, owner_id
        FROM $vectorEmbeddingsTable WHERE row_id > ? ORDER BY row_id
        LIMIT $vectorSchemaMigrationBatchSize
        ''',
        <Object?>[lastRowId],
      );
      if (rows.isEmpty) return;
      for (final row in rows) {
        final metadata = _decodeMetadata(
          row['metadata_json']?.toString() ?? '{}',
        );
        final scopeId = row['scope_id']?.toString().trim().isNotEmpty == true
            ? row['scope_id']!.toString()
            : metadata['scopeId']?.toString() ?? '';
        final visibility = row['visibility']?.toString() == 'publicObservable'
            ? metadata['visibility']?.toString() ?? 'publicObservable'
            : row['visibility']?.toString() ?? 'publicObservable';
        final ownerId = row['owner_id']?.toString().trim().isNotEmpty == true
            ? row['owner_id']!.toString()
            : metadata['ownerId']?.toString() ?? '';
        if (visibility == 'agentPrivate' && ownerId.trim().isEmpty) {
          throw FormatException(
            'Agent-private vector row ${row['row_id']} has no ownerId',
          );
        }
        final rowId = row['row_id'] as int;
        update.execute([scopeId, visibility, ownerId, rowId]);
        deleteTags.execute([rowId]);
        final rawTags = metadata['tags'];
        if (rawTags is List) {
          final tags = {
            for (final tag in rawTags)
              if (tag != null && tag.toString().trim().isNotEmpty)
                tag.toString().trim(),
          };
          for (final tag in tags) {
            insertTag.execute([row['project_id'], rowId, tag]);
          }
        }
        lastRowId = rowId;
      }
    }
  } finally {
    update.dispose();
    deleteTags.dispose();
    insertTag.dispose();
  }
}

void _rebuildOutdatedLshBuckets(Database db) {
  final deleteBuckets = db.prepare(
    'DELETE FROM $vectorLshBucketsTable WHERE vector_row_id = ?',
  );
  final insertBucket = db.prepare('''
    INSERT INTO $vectorLshBucketsTable (
      vector_row_id, project_id, tier, dimension, table_no, bucket
    ) VALUES (?, ?, ?, ?, ?, ?)
  ''');
  final updateVersion = db.prepare('''
    UPDATE $vectorEmbeddingsTable SET lsh_version = ? WHERE row_id = ?
  ''');
  try {
    var lastRowId = -1;
    while (true) {
      final rows = db.select(
        '''
        SELECT e.row_id, e.project_id, e.tier, e.dimension, e.embedding_blob
        FROM $vectorEmbeddingsTable AS e
        WHERE e.row_id > ? AND (
          e.lsh_version <> ?
          OR (SELECT COUNT(*) FROM $vectorLshBucketsTable AS b
              WHERE b.vector_row_id = e.row_id) <> $vectorLshTableCount
          OR EXISTS (SELECT 1 FROM $vectorLshBucketsTable AS b
              WHERE b.vector_row_id = e.row_id
                AND (b.table_no < 0 OR b.table_no >= $vectorLshTableCount))
        )
        ORDER BY e.row_id LIMIT $vectorSchemaMigrationBatchSize
        ''',
        <Object?>[lastRowId, vectorLshVersion],
      );
      if (rows.isEmpty) return;
      for (final row in rows) {
        final rowId = row['row_id'] as int;
        final dimension = row['dimension'] as int;
        final embedding = normalizeVector(
          decodeFloat32Vector(row['embedding_blob'], dimension),
        );
        deleteBuckets.execute([rowId]);
        final signatures = vectorLshSignatures(embedding);
        for (var table = 0; table < signatures.length; table++) {
          insertBucket.execute([
            rowId,
            row['project_id'] as String,
            row['tier'] as String,
            dimension,
            table,
            signatures[table],
          ]);
        }
        updateVersion.execute([vectorLshVersion, rowId]);
        lastRowId = rowId;
      }
    }
  } finally {
    deleteBuckets.dispose();
    insertBucket.dispose();
    updateVersion.dispose();
  }
}

void _migrateLegacyJsonTable(Database db) {
  const legacyTable = 'vector_embeddings_legacy_json';
  if (_tableExists(db, legacyTable)) {
    db.execute('DROP TABLE $legacyTable');
  }
  db.execute('ALTER TABLE $vectorEmbeddingsTable RENAME TO $legacyTable');
  _createVectorTables(db);

  final entryStatement = db.prepare('''
    INSERT INTO $vectorEmbeddingsTable (
      project_id, id, content, embedding_blob, dimension, tier,
      scope_id, visibility, owner_id, metadata_json, lsh_version
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  ''');
  final bucketStatement = db.prepare('''
    INSERT INTO $vectorLshBucketsTable (
      vector_row_id, project_id, tier, dimension, table_no, bucket
    ) VALUES (?, ?, ?, ?, ?, ?)
  ''');
  try {
    var lastRowId = -1;
    while (true) {
      final rows = db.select(
        '''SELECT rowid, id, content, embedding, tier, metadata
           FROM $legacyTable WHERE rowid > ? ORDER BY rowid
           LIMIT $vectorSchemaMigrationBatchSize''',
        <Object?>[lastRowId],
      );
      if (rows.isEmpty) break;
      for (final row in rows) {
        final metadataJson = row['metadata']?.toString() ?? '{}';
        final metadata = _decodeMetadata(metadataJson);
        final id = row['id']?.toString() ?? '';
        final projectId = _legacyProjectId(metadata, id);
        final decoded = jsonDecode(row['embedding'] as String);
        if (decoded is! List) {
          throw FormatException(
            'Legacy vector $id has a non-list embedding; migration aborted',
          );
        }
        final embedding = <double>[
          for (final value in decoded)
            if (value is num) value.toDouble() else double.nan,
        ];
        final normalized = normalizeVector(embedding);
        final tier = row['tier']?.toString() ?? 'scene';
        entryStatement.execute([
          projectId,
          id,
          row['content']?.toString() ?? '',
          encodeFloat32Vector(normalized),
          normalized.length,
          tier,
          metadata['scopeId']?.toString() ?? '',
          metadata['visibility']?.toString() ?? 'publicObservable',
          metadata['ownerId']?.toString() ?? '',
          metadataJson,
          vectorLshVersion,
        ]);
        final vectorRowId = db.lastInsertRowId;
        final signatures = vectorLshSignatures(normalized);
        for (var table = 0; table < signatures.length; table++) {
          bucketStatement.execute([
            vectorRowId,
            projectId,
            tier,
            normalized.length,
            table,
            signatures[table],
          ]);
        }
        lastRowId = row['rowid'] as int;
      }
    }
  } finally {
    entryStatement.dispose();
    bucketStatement.dispose();
  }
  db.execute('DROP TABLE $legacyTable');
}

Map<String, dynamic> _decodeMetadata(String value) {
  try {
    final decoded = jsonDecode(value);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {
    // Metadata is auxiliary; preserve its raw value while isolating the row.
  }
  return const {};
}

String _projectIdFromLegacyId(String id) {
  final separator = id.indexOf('/');
  return separator > 0
      ? id.substring(0, separator)
      : legacyUnscopedVectorProjectId;
}

String _legacyProjectId(Map<String, dynamic> metadata, String id) {
  final metadataProjectId = metadata['projectId']?.toString().trim() ?? '';
  return metadataProjectId.isNotEmpty
      ? metadataProjectId
      : _projectIdFromLegacyId(id);
}

bool _tableExists(Database db, String table) => db.select(
  "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
  [table],
).isNotEmpty;

bool _hasColumn(Database db, String table, String column) =>
    db.select('PRAGMA table_info($table)').any((row) => row['name'] == column);
