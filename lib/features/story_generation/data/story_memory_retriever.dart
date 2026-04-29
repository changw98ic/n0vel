import 'dart:math';

import '../domain/memory_models.dart';
import 'story_memory_storage.dart';
import 'story_embedding_provider.dart';
import '../domain/story_pipeline_interfaces.dart';

/// Weight applied to semantic cosine similarity when embeddings are present.
const double _semanticWeight = 5.0;

/// Tag value marking a chunk as private/internal to a character.
const String _privateTag = 'private';

/// Tag value marking a chunk as a self-state observation belonging to a character.
const String _selfStateTag = 'selfstate';

/// Captures the active viewer context for role-based retrieval filtering.
///
/// Every viewer-scoped retrieval must provide a valid [ViewerContext] to
/// receive results. An invalid context (empty IDs) causes fail-fast
/// empty results, preventing accidental information leaks across characters.
class ViewerContext {
  const ViewerContext({
    required this.viewerId,
    required this.characterId,
  });

  /// The project-scoped viewer identifier (e.g. scene cast member ID).
  final String viewerId;

  /// The character this viewer is acting as (e.g. 'char-liuxi').
  final String characterId;

  /// A context is valid only when both identifiers are non-empty.
  bool get isValid => viewerId.isNotEmpty && characterId.isNotEmpty;

  @override
  String toString() => 'ViewerContext(viewerId: $viewerId, characterId: $characterId)';
}

/// Runs lexical scoring, optional semantic scoring, and returns compact
/// retrieval packs.
class StoryMemoryRetriever implements StoryMemoryRetrieverService {
  StoryMemoryRetriever({
    required this.storage,
    this.embeddingProvider,
    this.maxResults = 10,
  });

  final StoryMemoryStorage storage;
  final StoryEmbeddingProvider? embeddingProvider;
  final int maxResults;

  /// Retrieves memory chunks and thoughts matching the given query.
  @override
  Future<StoryRetrievalPack> retrieve(StoryMemoryQuery query) async {
    final chunks = await storage.loadChunks(query.projectId);
    final thoughts = await storage.loadThoughts(query.projectId);

    // Convert thoughts to hits for unified scoring
    final thoughtHits = thoughts.map((t) {
      final chunk = StoryMemoryChunk(
        id: t.id,
        projectId: t.projectId,
        scopeId: t.scopeId,
        kind: _thoughtTypeToKind(t.thoughtType),
        content: t.content,
        sourceRefs: t.sourceRefs,
        rootSourceIds: t.rootSourceIds,
        tags: t.tags,
        priority: t.priority,
        tokenCostEstimate: t.tokenCostEstimate,
        createdAtMs: t.createdAtMs,
      );
      return StoryMemoryHit(
        chunk: chunk,
        score: 0.0,
        isThought: true,
        thoughtAtom: t,
      );
    }).toList();

    final chunkHits = chunks.map((c) {
      return StoryMemoryHit(chunk: c, score: 0.0);
    }).toList();

    final allHits = [...chunkHits, ...thoughtHits];

    // Optionally compute embeddings for semantic scoring
    List<double>? semanticScores;
    if (embeddingProvider != null && allHits.isNotEmpty) {
      final queryVec = await embeddingProvider!.embedText(query.text);
      final texts = allHits.map((h) => h.chunk.content).toList();
      final chunkVecs = await embeddingProvider!.embedBatch(texts);
      semanticScores = [
        for (int i = 0; i < chunkVecs.length; i++)
          _cosineSimilarity(queryVec, chunkVecs[i]),
      ];
    }

    // Score each hit
    final scored = <StoryMemoryHit>[];
    for (int i = 0; i < allHits.length; i++) {
      final hit = allHits[i];
      var score = _lexicalScore(hit, query);
      if (semanticScores != null) {
        score += semanticScores[i] * _semanticWeight;
      }
      scored.add(hit.copyWith(score: score));
    }

    // Sort by score descending
    scored.sort((a, b) => b.score.compareTo(a.score));

    // Filter by visibility
    final visible = scored.where((h) {
      if (h.chunk.visibility == MemoryVisibility.publicObservable) return true;
      if (query.viewerId == null) return false;
      return h.chunk.scopeId == query.viewerId;
    }).toList();

    // Apply token budget
    final selected = <StoryMemoryHit>[];
    final deferred = <StoryMemoryHit>[];
    var spent = 0;

    for (final hit in visible) {
      if (selected.length >= query.maxResults) {
        deferred.add(hit);
        continue;
      }
      final cost = hit.chunk.tokenCostEstimate;
      if (spent + cost > query.tokenBudget && selected.isNotEmpty) {
        deferred.add(hit);
        continue;
      }
      spent += cost;
      selected.add(hit);
    }

    final sourceRefs = <MemorySourceRef>[
      for (final hit in selected) ...hit.chunk.sourceRefs,
    ];

    return StoryRetrievalPack(
      query: query,
      hits: List.unmodifiable(selected),
      sourceRefs: sourceRefs,
      summary: _buildSummary(selected),
      tokenBudget: query.tokenBudget,
      spentTokenEstimate: spent,
      deferredHitCount: deferred.length,
    );
  }

  /// Retrieves memory chunks filtered for the given [ViewerContext].
  ///
  /// Returns an empty list if [context] is invalid (fail-fast).
  /// Privacy rules:
  /// - Viewer can always see public observable atoms.
  /// - Viewer can see own `selfState` atoms.
  /// - Viewer **cannot** see `selfState` atoms belonging to other characters.
  /// - Viewer **cannot** see atoms tagged as `private` belonging to other
  ///   characters.
  /// - Viewer can see perceived/reported atoms about other characters (e.g.
  ///   `perceivedEvent`).
  Future<List<StoryMemoryChunk>> retrieveForViewer({
    required ViewerContext context,
    required String query,
    int maxResults = 10,
  }) async {
    if (!context.isValid) return const [];

    final allChunks = await storage.loadChunks(context.viewerId);

    final filtered = allChunks.where((chunk) {
      return _isVisibleToViewer(chunk, context.characterId);
    }).toList();

    // Simple relevance scoring and sort by token cost efficiency
    filtered.sort((a, b) {
      final scoreA = _viewerRelevanceScore(a, query);
      final scoreB = _viewerRelevanceScore(b, query);
      return scoreB.compareTo(scoreA);
    });

    return filtered.take(maxResults).toList();
  }

  /// Determines whether a [chunk] is visible to the character with
  /// [viewerCharacterId].
  ///
  /// Rules:
  /// 1. Public observable chunks are always visible.
  /// 2. Chunks scoped to the viewer's own character are always visible.
  /// 3. Chunks with `selfState` tag are only visible to the owning character.
  /// 4. Chunks tagged `private` are only visible to the owning character.
  static bool _isVisibleToViewer(StoryMemoryChunk chunk, String viewerCharacterId) {
    // Rule 1: public observable is always visible
    if (chunk.visibility == MemoryVisibility.publicObservable) {
      // But selfState-tagged public chunks are still restricted
      if (_isSelfState(chunk) && chunk.scopeId != viewerCharacterId) {
        return false;
      }
      // Private-tagged public chunks are restricted to owner
      if (_isPrivate(chunk) && chunk.scopeId != viewerCharacterId) {
        return false;
      }
      return true;
    }

    // Rule 2: viewer sees their own scoped chunks
    if (chunk.scopeId == viewerCharacterId) return true;

    // Rule 3 & 4: other characters' private/selfState chunks are hidden
    if (_isSelfState(chunk) || _isPrivate(chunk)) return false;

    // Agent-private chunks not belonging to viewer are hidden
    return false;
  }

  /// Whether the chunk carries the `selfState` tag.
  static bool _isSelfState(StoryMemoryChunk chunk) {
    return chunk.tags.any((t) => t.toLowerCase() == _selfStateTag);
  }

  /// Whether the chunk carries the `private` tag.
  static bool _isPrivate(StoryMemoryChunk chunk) {
    return chunk.tags.any((t) => t.toLowerCase() == _privateTag);
  }

  /// Quick keyword-relevance score for viewer-scoped retrieval.
  double _viewerRelevanceScore(StoryMemoryChunk chunk, String query) {
    return _keywordOverlap(chunk.content, query) * 4.0 +
        chunk.priority.toDouble() * 2.0 +
        _recencyBoost(chunk.createdAtMs);
  }

  double _lexicalScore(StoryMemoryHit hit, StoryMemoryQuery query) {
    final chunk = hit.chunk;
    final keywordOverlap = _keywordOverlap(chunk.content, query.text);
    final tagOverlap = _tagOverlap(chunk.tags, query.tags);
    final priority = chunk.priority.toDouble();
    final recencyBoost = _recencyBoost(chunk.createdAtMs);
    final tokenPenalty = chunk.tokenCostEstimate > query.tokenBudget
        ? (chunk.tokenCostEstimate - query.tokenBudget) * 0.1
        : 0.0;

    var score = keywordOverlap * 4.0 +
        tagOverlap * 6.0 +
        priority * 2.0 +
        recencyBoost -
        tokenPenalty;

    // Abstraction preference by query type
    if (hit.isThought && hit.thoughtAtom != null) {
      final abstraction = hit.thoughtAtom!.abstractionLevel;
      score += _abstractionBonus(query.queryType, abstraction);
    }

    return score;
  }

  double _abstractionBonus(StoryMemoryQueryType queryType, double abstraction) {
    return switch (queryType) {
      StoryMemoryQueryType.concreteFact => abstraction < 1.5 ? 2.0 : 0.0,
      StoryMemoryQueryType.sceneContinuity => 1.0,
      StoryMemoryQueryType.persona => abstraction * 0.5,
      StoryMemoryQueryType.causality => abstraction > 1.5 ? 3.0 : 0.0,
      StoryMemoryQueryType.foreshadowing => abstraction > 1.5 ? 3.0 : 0.0,
      StoryMemoryQueryType.style => abstraction * 0.3,
    };
  }

  double _keywordOverlap(String content, String query) {
    final contentLower = content.toLowerCase();
    var count = 0;
    for (final word in query.toLowerCase().split(RegExp(r'\s+'))) {
      if (word.isNotEmpty && contentLower.contains(word)) count++;
    }
    return count.toDouble();
  }

  double _tagOverlap(List<String> chunkTags, List<String> queryTags) {
    if (queryTags.isEmpty || chunkTags.isEmpty) return 0.0;
    var matches = 0;
    for (final qt in queryTags) {
      if (chunkTags.any((ct) => ct.toLowerCase() == qt.toLowerCase())) {
        matches++;
      }
    }
    return matches.toDouble();
  }

  double _recencyBoost(int createdAtMs) {
    if (createdAtMs <= 0) return 0.0;
    final ageMs = DateTime.now().millisecondsSinceEpoch - createdAtMs;
    if (ageMs < 0) return 1.0;
    final ageHours = ageMs / (1000 * 60 * 60);
    if (ageHours < 1) return 2.0;
    if (ageHours < 24) return 1.0;
    if (ageHours < 168) return 0.5;
    return 0.0;
  }

  String _buildSummary(List<StoryMemoryHit> hits) {
    if (hits.isEmpty) return '';
    final parts = hits
        .take(3)
        .map((h) => h.chunk.content.length > 80
            ? '${h.chunk.content.substring(0, 77)}...'
            : h.chunk.content)
        .toList();
    return parts.join(' | ');
  }

  MemorySourceKind _thoughtTypeToKind(ThoughtType type) {
    return switch (type) {
      ThoughtType.persona => MemorySourceKind.characterProfile,
      ThoughtType.plotCausality => MemorySourceKind.outlineBeat,
      ThoughtType.state => MemorySourceKind.acceptedState,
      ThoughtType.foreshadowing => MemorySourceKind.outlineBeat,
      ThoughtType.style => MemorySourceKind.reviewFinding,
    };
  }

  /// Cosine similarity between two equal-length vectors.
  static double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0.0;
    double dot = 0, magA = 0, magB = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      magA += a[i] * a[i];
      magB += b[i] * b[i];
    }
    if (magA == 0 || magB == 0) return 0.0;
    return dot / (sqrt(magA) * sqrt(magB));
  }
}
