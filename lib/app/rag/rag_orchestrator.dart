import 'package:sqlite3/sqlite3.dart';

import 'local_rag_search.dart';
import 'local_rag_storage.dart';

/// A single search result from the local annotation RAG index.
class RagSearchResult {
  const RagSearchResult({
    required this.path,
    required this.content,
    required this.score,
    this.metadata = const {},
  });

  final String path;
  final String content;
  final double score;
  final Map<String, Object?> metadata;
}

/// Context retrieved from RAG for a scene.
class RagSceneContext {
  const RagSceneContext({
    required this.results,
    required this.formattedContext,
  });

  final List<RagSearchResult> results;
  final String formattedContext;

  bool get isEmpty => results.isEmpty;
}

/// Abstract interface for local annotation RAG operations.
abstract interface class RagService {
  Future<void> syncProject({
    required String projectId,
    required List<String> characterProfiles,
    required List<String> outlineBeats,
    required List<String> worldFacts,
    List<String> chapterContents = const [],
  });

  Future<RagSceneContext> retrieveForScene({
    required String projectId,
    required String sceneTitle,
    required String sceneSummary,
    List<String> castNames = const [],
    List<String> worldNodeIds = const [],
  });

  Future<void> pushChapter({
    required String projectId,
    required int chapterIndex,
    required String content,
  });
}

/// Orchestrates local RAG over LLM-parsed story annotations.
///
/// The authoritative RAG data is the structured annotation material already
/// extracted by the story pipeline, stored locally, and searched through FTS5.
class RagOrchestrator implements RagService {
  RagOrchestrator._({
    required LocalRagStorage storage,
    required LocalRagSearchEngine search,
  }) : _localStorage = storage,
       _localSearch = search;

  /// Creates a local (SQLite FTS5) backend.
  factory RagOrchestrator.local({
    required Database db,
    LocalRagSearchConfig? searchConfig,
  }) {
    final storage = LocalRagStorage(db: db);
    final search = LocalRagSearchEngine(
      storage: storage,
      config: searchConfig ?? const LocalRagSearchConfig(),
    );
    return RagOrchestrator._(storage: storage, search: search);
  }

  final LocalRagStorage _localStorage;
  final LocalRagSearchEngine _localSearch;

  @override
  Future<void> syncProject({
    required String projectId,
    required List<String> characterProfiles,
    required List<String> outlineBeats,
    required List<String> worldFacts,
    List<String> chapterContents = const [],
  }) async {
    await _localStorage.clearProject(projectId);

    for (var i = 0; i < characterProfiles.length; i++) {
      await _localStorage.indexDocument(
        projectId: projectId,
        path: '$projectId/characters/char_$i.md',
        content: characterProfiles[i],
        category: 'characters',
      );
    }
    for (var i = 0; i < outlineBeats.length; i++) {
      await _localStorage.indexDocument(
        projectId: projectId,
        path: '$projectId/outlines/beat_$i.md',
        content: outlineBeats[i],
        category: 'outlines',
      );
    }
    for (var i = 0; i < worldFacts.length; i++) {
      await _localStorage.indexDocument(
        projectId: projectId,
        path: '$projectId/worldbuilding/fact_$i.md',
        content: worldFacts[i],
        category: 'worldbuilding',
      );
    }
    for (var i = 0; i < chapterContents.length; i++) {
      await _localStorage.indexDocument(
        projectId: projectId,
        path: '$projectId/chapters/chapter_$i.md',
        content: chapterContents[i],
        category: 'chapters',
      );
    }
  }

  @override
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

    final allResults = <LocalRagSearchResult>[];
    for (final query in queries) {
      try {
        final results = await _localSearch.search(
          projectId: projectId,
          query: query,
          limit: 10,
        );
        allResults.addAll(results);
      } on Object {
        continue;
      }
    }

    final deduped = _deduplicate(allResults);
    deduped.sort((a, b) => b.score.compareTo(a.score));
    final converted = [
      for (final result in deduped)
        RagSearchResult(
          path: result.path,
          content: result.content,
          score: result.score,
          metadata: result.metadata,
        ),
    ];

    return RagSceneContext(
      results: converted,
      formattedContext: _formatContext(converted),
    );
  }

  @override
  Future<void> pushChapter({
    required String projectId,
    required int chapterIndex,
    required String content,
  }) async {
    await _localStorage.indexDocument(
      projectId: projectId,
      path: '$projectId/chapters/chapter_$chapterIndex.md',
      content: content,
      category: 'chapters',
    );
  }

  List<LocalRagSearchResult> _deduplicate(List<LocalRagSearchResult> results) {
    final seen = <String>{};
    return [
      for (final result in results)
        if (seen.add(result.path)) result,
    ];
  }

  String _formatContext(List<RagSearchResult> results) {
    if (results.isEmpty) return '';
    final buffer = StringBuffer('【RAG检索上下文】\n');
    for (final result in results) {
      final snippet = result.content.length > 200
          ? '${result.content.substring(0, 197)}...'
          : result.content;
      buffer.writeln(
        '- [${result.path}] ${result.score.toStringAsFixed(2)}: $snippet',
      );
    }
    return buffer.toString();
  }
}
