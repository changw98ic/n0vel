import 'package:sqlite3/sqlite3.dart';

import '../../features/story_generation/data/story_embedding_provider.dart';
import 'local_rag_search.dart';
import 'local_rag_storage.dart';
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

/// Abstract interface for RAG operations.
///
/// Implementations may use a remote server (OpenViking) or local storage (FTS5).
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

/// Orchestrates RAG operations with pluggable backends.
///
/// Use [RagOrchestrator.remote] for the legacy OpenViking server backend,
/// or [RagOrchestrator.local] for the on-device SQLite FTS5 backend.
class RagOrchestrator implements RagService {
  RagOrchestrator._remote({OpenVikingClient? client, required RagConfig config})
    : _mode = _BackendMode.remote,
      _remoteClient = client ?? OpenVikingClient(config: config),
      _localStorage = null,
      _localSearch = null;

  RagOrchestrator._local({
    required LocalRagStorage storage,
    LocalRagSearchEngine? search,
  }) : _mode = _BackendMode.local,
       _remoteClient = null,
       _localStorage = storage,
       _localSearch = search ?? LocalRagSearchEngine(storage: storage);

  /// Creates a remote (OpenViking) backend.
  factory RagOrchestrator.remote({
    OpenVikingClient? client,
    RagConfig config = const RagConfig(),
  }) {
    return RagOrchestrator._remote(client: client, config: config);
  }

  /// Creates a local (SQLite FTS5) backend.
  factory RagOrchestrator.local({
    required Database db,
    StoryEmbeddingProvider? embeddingProvider,
    LocalRagSearchConfig? searchConfig,
  }) {
    final storage = LocalRagStorage(db: db);
    final search = LocalRagSearchEngine(
      storage: storage,
      embeddingProvider: embeddingProvider,
      config: searchConfig ?? const LocalRagSearchConfig(),
    );
    return RagOrchestrator._local(storage: storage, search: search);
  }

  final _BackendMode _mode;
  final OpenVikingClient? _remoteClient;
  final LocalRagStorage? _localStorage;
  final LocalRagSearchEngine? _localSearch;

  // ── RagService interface ──────────────────────────────────────────

  @override
  Future<void> syncProject({
    required String projectId,
    required List<String> characterProfiles,
    required List<String> outlineBeats,
    required List<String> worldFacts,
    List<String> chapterContents = const [],
  }) async {
    switch (_mode) {
      case _BackendMode.remote:
        await _remoteSyncProject(
          projectId: projectId,
          characterProfiles: characterProfiles,
          outlineBeats: outlineBeats,
          worldFacts: worldFacts,
          chapterContents: chapterContents,
        );
      case _BackendMode.local:
        await _localSyncProject(
          projectId: projectId,
          characterProfiles: characterProfiles,
          outlineBeats: outlineBeats,
          worldFacts: worldFacts,
          chapterContents: chapterContents,
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
    switch (_mode) {
      case _BackendMode.remote:
        return _remoteRetrieveForScene(
          projectId: projectId,
          sceneTitle: sceneTitle,
          sceneSummary: sceneSummary,
          castNames: castNames,
          worldNodeIds: worldNodeIds,
        );
      case _BackendMode.local:
        return _localRetrieveForScene(
          projectId: projectId,
          sceneTitle: sceneTitle,
          sceneSummary: sceneSummary,
          castNames: castNames,
          worldNodeIds: worldNodeIds,
        );
    }
  }

  @override
  Future<void> pushChapter({
    required String projectId,
    required int chapterIndex,
    required String content,
  }) async {
    switch (_mode) {
      case _BackendMode.remote:
        await _remoteClient!.addResource(
          path: '$projectId/chapters/chapter_$chapterIndex.md',
          content: content,
        );
      case _BackendMode.local:
        await _localStorage!.indexDocument(
          projectId: projectId,
          path: '$projectId/chapters/chapter_$chapterIndex.md',
          content: content,
          category: 'chapters',
        );
    }
  }

  // ── Remote (OpenViking) implementation ─────────────────────────────

  Future<void> _remoteSyncProject({
    required String projectId,
    required List<String> characterProfiles,
    required List<String> outlineBeats,
    required List<String> worldFacts,
    List<String> chapterContents = const [],
  }) async {
    final client = _remoteClient!;
    await _ensureDir(client, '$projectId/characters');
    await _ensureDir(client, '$projectId/outlines');
    await _ensureDir(client, '$projectId/worldbuilding');
    await _ensureDir(client, '$projectId/chapters');

    await _pushItems(
      client,
      projectId,
      'characters',
      'char',
      characterProfiles,
    );
    await _pushItems(client, projectId, 'outlines', 'beat', outlineBeats);
    await _pushItems(client, projectId, 'worldbuilding', 'fact', worldFacts);
    await _pushItems(client, projectId, 'chapters', 'chapter', chapterContents);
  }

  Future<RagSceneContext> _remoteRetrieveForScene({
    required String projectId,
    required String sceneTitle,
    required String sceneSummary,
    List<String> castNames = const [],
    List<String> worldNodeIds = const [],
  }) async {
    final client = _remoteClient!;
    final queries = <String>[
      '$sceneTitle $sceneSummary',
      if (castNames.isNotEmpty) '${castNames.join(' ')} 角色关系 性格',
      if (worldNodeIds.isNotEmpty) '${worldNodeIds.join(' ')} 世界观 规则',
    ];

    final allResults = <OpenVikingSearchResult>[];
    for (final query in queries) {
      try {
        final response = await client.find(query: query, pathPrefix: projectId);
        allResults.addAll(response.results);
      } on Object {
        continue;
      }
    }

    final deduped = _remoteDeduplicate(allResults);
    deduped.sort((a, b) => b.score.compareTo(a.score));
    final selected = _remoteTrimToBudget(deduped, client.config.tokenBudget);

    return RagSceneContext(
      results: selected,
      formattedContext: _formatContext(selected),
    );
  }

  // ── Local (SQLite FTS5) implementation ─────────────────────────────

  Future<void> _localSyncProject({
    required String projectId,
    required List<String> characterProfiles,
    required List<String> outlineBeats,
    required List<String> worldFacts,
    List<String> chapterContents = const [],
  }) async {
    final storage = _localStorage!;
    await storage.clearProject(projectId);

    for (var i = 0; i < characterProfiles.length; i++) {
      await storage.indexDocument(
        projectId: projectId,
        path: '$projectId/characters/char_$i.md',
        content: characterProfiles[i],
        category: 'characters',
      );
    }
    for (var i = 0; i < outlineBeats.length; i++) {
      await storage.indexDocument(
        projectId: projectId,
        path: '$projectId/outlines/beat_$i.md',
        content: outlineBeats[i],
        category: 'outlines',
      );
    }
    for (var i = 0; i < worldFacts.length; i++) {
      await storage.indexDocument(
        projectId: projectId,
        path: '$projectId/worldbuilding/fact_$i.md',
        content: worldFacts[i],
        category: 'worldbuilding',
      );
    }
    for (var i = 0; i < chapterContents.length; i++) {
      await storage.indexDocument(
        projectId: projectId,
        path: '$projectId/chapters/chapter_$i.md',
        content: chapterContents[i],
        category: 'chapters',
      );
    }
  }

  Future<RagSceneContext> _localRetrieveForScene({
    required String projectId,
    required String sceneTitle,
    required String sceneSummary,
    List<String> castNames = const [],
    List<String> worldNodeIds = const [],
  }) async {
    final search = _localSearch!;
    final queries = <String>[
      '$sceneTitle $sceneSummary',
      if (castNames.isNotEmpty) '${castNames.join(' ')} 角色关系 性格',
      if (worldNodeIds.isNotEmpty) '${worldNodeIds.join(' ')} 世界观 规则',
    ];

    final allResults = <LocalRagSearchResult>[];
    for (final query in queries) {
      try {
        final results = await search.search(
          projectId: projectId,
          query: query,
          limit: 10,
        );
        allResults.addAll(results);
      } on Object {
        continue;
      }
    }

    // Deduplicate by path
    final seen = <String>{};
    final deduped = <LocalRagSearchResult>[];
    for (final r in allResults) {
      if (seen.add(r.path)) deduped.add(r);
    }
    deduped.sort((a, b) => b.score.compareTo(a.score));

    // Convert to OpenVikingSearchResult for compatibility
    final converted = deduped
        .map(
          (r) => OpenVikingSearchResult(
            path: r.path,
            content: r.content,
            score: r.score,
            metadata: r.metadata,
          ),
        )
        .toList();

    return RagSceneContext(
      results: converted,
      formattedContext: _formatContext(converted),
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────

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

  // ── Remote-only helpers ────────────────────────────────────────────

  Future<void> _ensureDir(OpenVikingClient client, String path) async {
    try {
      await client.mkdir(path);
    } on Object {
      // Directory may already exist
    }
  }

  Future<void> _pushItems(
    OpenVikingClient client,
    String projectId,
    String subdir,
    String prefix,
    List<String> items,
  ) async {
    for (var i = 0; i < items.length; i++) {
      await client.addResource(
        path: '$projectId/$subdir/${prefix}_$i.md',
        content: items[i],
      );
    }
  }

  List<OpenVikingSearchResult> _remoteDeduplicate(
    List<OpenVikingSearchResult> results,
  ) {
    final seen = <String>{};
    return [
      for (final r in results)
        if (seen.add(r.path)) r,
    ];
  }

  List<OpenVikingSearchResult> _remoteTrimToBudget(
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
}

enum _BackendMode { remote, local }
