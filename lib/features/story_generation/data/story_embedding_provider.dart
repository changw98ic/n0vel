/// Optional embedding provider interface for semantic scoring.
///
/// When no provider is registered, lexical retrieval is the default.
abstract interface class StoryEmbeddingProvider {
  Future<List<double>> embedText(String text);
  Future<List<List<double>>> embedBatch(List<String> texts);
}
