import 'openviking_client.dart';
import 'openviking_models.dart';
import 'rag_config.dart';

/// Context retrieved from RAG for a scene.
class RagSceneContext {
  const RagSceneContext({
    required this.results,
    required this.formattedContext,
  });

  final List<OpenVikingSearchResult> results;
  final String formattedContext;

  bool get isEmpty => results.isEmpty;
}

/// Orchestrates data synchronization with OpenViking RAG server
/// and retrieval of context for scene generation.
///
/// Works as a complementary layer to the existing KnowledgeToolRegistry:
/// RAG provides macro semantic context, tools give precise structured data.
class RagOrchestrator {
  RagOrchestrator({
    OpenVikingClient? client,
    RagConfig config = const RagConfig(),
  }) : _client = client ?? OpenVikingClient(config: config);

  final OpenVikingClient _client;

  /// Syncs project materials to OpenViking under `viking://resources/{projectId}/`.
  ///
  /// Creates directory structure and pushes character profiles, outline beats,
  /// world facts, and completed chapters.
  Future<void> syncProject({
    required String projectId,
    required List<String> characterProfiles,
    required List<String> outlineBeats,
    required List<String> worldFacts,
    List<String> chapterContents = const [],
  }) async {
    await _ensureDir('$projectId/characters');
    await _ensureDir('$projectId/outlines');
    await _ensureDir('$projectId/worldbuilding');
    await _ensureDir('$projectId/chapters');

    await _pushItems(
      projectId,
      'characters',
      'char',
      characterProfiles,
    );
    await _pushItems(
      projectId,
      'outlines',
      'beat',
      outlineBeats,
    );
    await _pushItems(
      projectId,
      'worldbuilding',
      'fact',
      worldFacts,
    );
    await _pushItems(
      projectId,
      'chapters',
      'chapter',
      chapterContents,
    );
  }

  /// Retrieves RAG context for a specific scene.
  ///
  /// Queries for scene-specific, character, and world-building context.
  /// Returns a [RagSceneContext] with formatted output ready for prompt injection.
  /// Failures are non-blocking: returns empty context on error.
  Future<RagSceneContext> retrieveForScene({
    required String projectId,
    required String sceneTitle,
    required String sceneSummary,
    List<String> castNames = const [],
    List<String> worldNodeIds = const [],
  }) async {
    final queries = <String>[
      '$sceneTitle $sceneSummary',
      if (castNames.isNotEmpty) '${castNames.join(' ')} 角色关系 性格',
      if (worldNodeIds.isNotEmpty) '${worldNodeIds.join(' ')} 世界观 规则',
    ];

    final allResults = <OpenVikingSearchResult>[];
    for (final query in queries) {
      try {
        final response = await _client.find(
          query: query,
          pathPrefix: projectId,
        );
        allResults.addAll(response.results);
      } on Object {
        continue;
      }
    }

    final deduped = _deduplicate(allResults);
    deduped.sort((a, b) => b.score.compareTo(a.score));

    final selected = _trimToBudget(deduped, _client.config.tokenBudget);

    return RagSceneContext(
      results: selected,
      formattedContext: _formatContext(selected),
    );
  }

  /// Pushes a single chapter content update (incremental sync).
  Future<void> pushChapter({
    required String projectId,
    required int chapterIndex,
    required String content,
  }) async {
    await _client.addResource(
      path: '$projectId/chapters/chapter_$chapterIndex.md',
      content: content,
    );
  }

  Future<void> _ensureDir(String path) async {
    try {
      await _client.mkdir(path);
    } on Object {
      // Directory may already exist
    }
  }

  Future<void> _pushItems(
    String projectId,
    String subdir,
    String prefix,
    List<String> items,
  ) async {
    for (var i = 0; i < items.length; i++) {
      await _client.addResource(
        path: '$projectId/$subdir/${prefix}_$i.md',
        content: items[i],
      );
    }
  }

  List<OpenVikingSearchResult> _deduplicate(
    List<OpenVikingSearchResult> results,
  ) {
    final seen = <String>{};
    return [
      for (final r in results)
        if (seen.add(r.path)) r,
    ];
  }

  List<OpenVikingSearchResult> _trimToBudget(
    List<OpenVikingSearchResult> results,
    int budget,
  ) {
    final selected = <OpenVikingSearchResult>[];
    var charCount = 0;
    for (final r in results) {
      if (charCount + r.content.length > budget) break;
      selected.add(r);
      charCount += r.content.length;
    }
    return selected;
  }

  String _formatContext(List<OpenVikingSearchResult> results) {
    if (results.isEmpty) return '';
    final buffer = StringBuffer('【RAG检索上下文】\n');
    for (final r in results) {
      final snippet = r.content.length > 200
          ? '${r.content.substring(0, 197)}...'
          : r.content;
      buffer.writeln('- [${r.path}] ${r.score.toStringAsFixed(2)}: $snippet');
    }
    return buffer.toString();
  }
}
