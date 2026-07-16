import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/rag/sqlite_vss_store.dart';
import 'package:novel_writer/app/rag/vector_embedding_profile.dart';
import 'package:novel_writer/app/rag/vector_store_schema.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/memory_policy.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Database db;

  setUp(() {
    db = sqlite3.openInMemory();
    ensureVectorStoreSchema(db);
  });

  tearDown(() => db.dispose());

  test('binds an empty database and preserves canonical model identity', () {
    final profile = _profile();

    bindOrValidateVectorEmbeddingProfile(db, profile);

    expect(readVectorEmbeddingProfile(db), profile);
    expect(readVectorEmbeddingProfile(db)!.modelDigest, startsWith('sha256:'));
  });

  test('refuses to infer a profile for populated legacy vectors', () {
    db.execute(
      '''
      INSERT INTO vector_embeddings (
        project_id, id, content, embedding_blob, dimension, tier,
        metadata_json, lsh_version
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''',
      [
        'project',
        'legacy',
        'legacy vector',
        encodeFloat32Vector(const [1.0, 0.0]),
        2,
        MemoryTier.scene.name,
        '{}',
        vectorLshVersion,
      ],
    );

    expect(
      () => bindOrValidateVectorEmbeddingProfile(db, _profile()),
      throwsStateError,
    );
  });

  test('rejects a runtime model digest mismatch', () {
    bindOrValidateVectorEmbeddingProfile(db, _profile());

    expect(
      () => bindOrValidateVectorEmbeddingProfile(
        db,
        _profile(digest: List.filled(64, 'b').join()),
      ),
      throwsStateError,
    );
  });

  test('audits dimensions, blob encoding, and LSH buckets', () async {
    final profile = _profile(dimension: 4);
    bindOrValidateVectorEmbeddingProfile(db, profile);
    final store = SqliteVssStore(db);
    await store.upsert(
      id: 'vector',
      projectId: 'project',
      content: 'content',
      embedding: const [1.0, 0.0, 0.0, 0.0],
      tier: MemoryTier.scene,
    );

    expect(() => auditVectorEmbeddingIndex(db, profile), returnsNormally);
  });

  test('rejects zero and wrong-dimensional embedding batches', () {
    final profile = _profile(dimension: 4);

    expect(
      () => validateEmbeddingBatch(profile, const [
        [0.0, 0.0, 0.0, 0.0],
      ], expectedCount: 1),
      throwsStateError,
    );
    expect(
      () => validateEmbeddingBatch(profile, const [
        [1.0, 0.0],
      ], expectedCount: 1),
      throwsStateError,
    );
  });
}

VectorEmbeddingProfile _profile({int dimension = 4096, String? digest}) =>
    VectorEmbeddingProfile(
      provider: 'ollama',
      model: 'qwen3-embedding:latest',
      modelDigest: digest ?? List.filled(64, 'a').join(),
      dimension: dimension,
    );
