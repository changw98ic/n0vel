import 'local_rag_storage.dart';

/// Configuration for the local annotation search engine.
class LocalRagSearchConfig {
  const LocalRagSearchConfig({
    this.scoreThreshold = 0.3,
    this.defaultLimit = 10,
  });

  final double scoreThreshold;
  final int defaultLimit;
}

/// BM25 full-text search over the local annotation index.
class LocalRagSearchEngine {
  LocalRagSearchEngine({
    required this.storage,
    this.config = const LocalRagSearchConfig(),
  });

  final LocalRagStorage storage;
  final LocalRagSearchConfig config;

  Future<List<LocalRagSearchResult>> search({
    required String projectId,
    required String query,
    List<String>? categories,
    int? limit,
    double? scoreThreshold,
  }) async {
    final effectiveLimit = limit ?? config.defaultLimit;
    final effectiveThreshold = scoreThreshold ?? config.scoreThreshold;

    if (categories != null && categories.length == 1) {
      final results = await storage.searchFts(
        projectId: projectId,
        query: query,
        limit: effectiveLimit,
        category: categories.first,
      );
      return results.where((r) => r.score >= effectiveThreshold).toList();
    }

    if (categories != null && categories.length > 1) {
      final allResults = <LocalRagSearchResult>[];
      for (final category in categories) {
        final results = await storage.searchFts(
          projectId: projectId,
          query: query,
          limit: effectiveLimit,
          category: category,
        );
        allResults.addAll(results);
      }
      allResults.sort((a, b) => b.score.compareTo(a.score));
      return _deduplicate(allResults)
          .where((r) => r.score >= effectiveThreshold)
          .take(effectiveLimit)
          .toList();
    }

    final results = await storage.searchFts(
      projectId: projectId,
      query: query,
      limit: effectiveLimit,
    );
    return results.where((r) => r.score >= effectiveThreshold).toList();
  }

  List<LocalRagSearchResult> _deduplicate(List<LocalRagSearchResult> results) {
    final seen = <String>{};
    return [
      for (final result in results)
        if (seen.add(result.path)) result,
    ];
  }
}
