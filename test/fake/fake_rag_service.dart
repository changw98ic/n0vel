import 'dart:math';

import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/app/rag/hybrid_retriever.dart';
import 'package:novel_writer/app/rag/local_rag_storage.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/rag_retrieval_policy.dart';
import 'package:novel_writer/features/story_generation/domain/memory_models.dart';

import 'fake_vector_store.dart';

/// Lightweight test helper wrapping [HybridRetriever] with in-memory sqlite3
/// and [FakeVectorStore] using deterministic embeddings.
class FakeRagService {
  FakeRagService() {
    db = sqlite3.openInMemory();
    ftsStorage = LocalRagStorage(db: db);
    vectorStore = FakeVectorStore();
    retriever = HybridRetriever(
      ftsStorage: ftsStorage,
      vectorStore: vectorStore,
      embeddingForText: _deterministicEmbedding,
    );
  }

  late final Database db;
  late final LocalRagStorage ftsStorage;
  late final FakeVectorStore vectorStore;
  late final HybridRetriever retriever;

  Future<void> indexChunks(List<StoryMemoryChunk> chunks) =>
      retriever.indexChunks(chunks);

  Future<StoryRetrievalPack> retrieve(
    StoryMemoryQuery query,
    RagRetrievalPolicy policy,
  ) =>
      retriever.retrieve(query, policy);

  void dispose() => db.dispose();

  /// 8-dim normalised embedding derived from character code sums.
  static Future<List<double>> _deterministicEmbedding(String text) async {
    const dims = 8;
    final vec = List<double>.filled(dims, 0.0);
    for (var i = 0; i < text.length; i++) {
      vec[i % dims] += text.codeUnitAt(i).toDouble();
    }
    final norm = sqrt(vec.fold(0.0, (s, v) => s + v * v));
    if (norm > 0) {
      for (var i = 0; i < dims; i++) {
        vec[i] /= norm;
      }
    }
    return vec;
  }
}
