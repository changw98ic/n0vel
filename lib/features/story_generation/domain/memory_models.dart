/// Visibility scope for memory records.
enum MemoryVisibility {
  /// Visible to all agents and review passes.
  publicObservable,

  /// Visible only to the agent that created it.
  agentPrivate,
}

/// Kind of source material a memory record was derived from.
enum MemorySourceKind {
  worldFact,
  characterProfile,
  relationshipHint,
  outlineBeat,
  sceneSummary,
  acceptedState,
  reviewFinding,
}

/// Types of thought atoms extracted after scene acceptance.
enum ThoughtType {
  persona,
  plotCausality,
  state,
  foreshadowing,
  style,
}

/// Query types that control retrieval ranking behavior.
enum StoryMemoryQueryType {
  concreteFact,
  sceneContinuity,
  persona,
  causality,
  foreshadowing,
  style,
}

/// A reference back to the source material that produced a memory record.
class MemorySourceRef {
  const MemorySourceRef({
    required this.sourceId,
    required this.sourceType,
  });

  final String sourceId;
  final MemorySourceKind sourceType;

  Map<String, Object?> toJson() => {
    'sourceId': sourceId,
    'sourceType': sourceType.name,
  };

  static MemorySourceRef fromJson(Map<String, Object?> json) {
    return MemorySourceRef(
      sourceId: json['sourceId']?.toString() ?? '',
      sourceType: _parseSourceKind(json['sourceType']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemorySourceRef &&
          other.sourceId == sourceId &&
          other.sourceType == sourceType;

  @override
  int get hashCode => Object.hash(sourceId, sourceType);
}

/// A raw source document persisted in the memory store.
class StoryMemorySource {
  const StoryMemorySource({
    required this.id,
    required this.projectId,
    required this.scopeId,
    required this.kind,
    required this.content,
    this.sourceRefs = const [],
    this.rootSourceIds = const [],
    this.visibility = MemoryVisibility.publicObservable,
    this.tags = const [],
    this.priority = 0,
    this.tokenCostEstimate = 0,
    this.createdAtMs = 0,
  });

  final String id;
  final String projectId;
  final String scopeId;
  final MemorySourceKind kind;
  final String content;
  final List<MemorySourceRef> sourceRefs;
  final List<String> rootSourceIds;
  final MemoryVisibility visibility;
  final List<String> tags;
  final int priority;
  final int tokenCostEstimate;
  final int createdAtMs;

  Map<String, Object?> toJson() => {
    'id': id,
    'projectId': projectId,
    'scopeId': scopeId,
    'kind': kind.name,
    'content': content,
    'sourceRefs': [for (final r in sourceRefs) r.toJson()],
    'rootSourceIds': rootSourceIds,
    'visibility': visibility.name,
    'tags': tags,
    'priority': priority,
    'tokenCostEstimate': tokenCostEstimate,
    'createdAtMs': createdAtMs,
  };

  static StoryMemorySource fromJson(Map<String, Object?> json) {
    return StoryMemorySource(
      id: json['id']?.toString() ?? '',
      projectId: json['projectId']?.toString() ?? '',
      scopeId: json['scopeId']?.toString() ?? '',
      kind: _parseSourceKind(json['kind']),
      content: json['content']?.toString() ?? '',
      sourceRefs: _parseSourceRefs(json['sourceRefs']),
      rootSourceIds: _parseStringList(json['rootSourceIds']),
      visibility: _parseVisibility(json['visibility']),
      tags: _parseStringList(json['tags']),
      priority: _parseInt(json['priority']),
      tokenCostEstimate: _parseInt(json['tokenCostEstimate']),
      createdAtMs: _parseInt(json['createdAtMs']),
    );
  }
}

/// A normalized chunk derived from a source document, optimized for retrieval.
class StoryMemoryChunk {
  const StoryMemoryChunk({
    required this.id,
    required this.projectId,
    required this.scopeId,
    required this.kind,
    required this.content,
    this.sourceRefs = const [],
    this.rootSourceIds = const [],
    this.visibility = MemoryVisibility.publicObservable,
    this.tags = const [],
    this.priority = 0,
    this.tokenCostEstimate = 0,
    this.createdAtMs = 0,
  });

  final String id;
  final String projectId;
  final String scopeId;
  final MemorySourceKind kind;
  final String content;
  final List<MemorySourceRef> sourceRefs;
  final List<String> rootSourceIds;
  final MemoryVisibility visibility;
  final List<String> tags;
  final int priority;
  final int tokenCostEstimate;
  final int createdAtMs;

  Map<String, Object?> toJson() => {
    'id': id,
    'projectId': projectId,
    'scopeId': scopeId,
    'kind': kind.name,
    'content': content,
    'sourceRefs': [for (final r in sourceRefs) r.toJson()],
    'rootSourceIds': rootSourceIds,
    'visibility': visibility.name,
    'tags': tags,
    'priority': priority,
    'tokenCostEstimate': tokenCostEstimate,
    'createdAtMs': createdAtMs,
  };

  static StoryMemoryChunk fromJson(Map<String, Object?> json) {
    return StoryMemoryChunk(
      id: json['id']?.toString() ?? '',
      projectId: json['projectId']?.toString() ?? '',
      scopeId: json['scopeId']?.toString() ?? '',
      kind: _parseSourceKind(json['kind']),
      content: json['content']?.toString() ?? '',
      sourceRefs: _parseSourceRefs(json['sourceRefs']),
      rootSourceIds: _parseStringList(json['rootSourceIds']),
      visibility: _parseVisibility(json['visibility']),
      tags: _parseStringList(json['tags']),
      priority: _parseInt(json['priority']),
      tokenCostEstimate: _parseInt(json['tokenCostEstimate']),
      createdAtMs: _parseInt(json['createdAtMs']),
    );
  }
}

/// A high-level thought atom extracted after scene acceptance.
///
/// Thought-Retriever-style reusable memory that captures persona insights,
/// plot causality, state changes, foreshadowing, and style observations.
class ThoughtAtom {
  const ThoughtAtom({
    required this.id,
    required this.projectId,
    required this.scopeId,
    required this.thoughtType,
    required this.content,
    this.confidence = 0.0,
    this.abstractionLevel = 1.0,
    this.sourceRefs = const [],
    this.rootSourceIds = const [],
    this.tags = const [],
    this.priority = 0,
    this.tokenCostEstimate = 0,
    this.createdAtMs = 0,
  });

  final String id;
  final String projectId;
  final String scopeId;
  final ThoughtType thoughtType;
  final String content;
  final double confidence;
  final double abstractionLevel;
  final List<MemorySourceRef> sourceRefs;
  final List<String> rootSourceIds;
  final List<String> tags;
  final int priority;
  final int tokenCostEstimate;
  final int createdAtMs;

  Map<String, Object?> toJson() => {
    'id': id,
    'projectId': projectId,
    'scopeId': scopeId,
    'thoughtType': thoughtType.name,
    'content': content,
    'confidence': confidence,
    'abstractionLevel': abstractionLevel,
    'sourceRefs': [for (final r in sourceRefs) r.toJson()],
    'rootSourceIds': rootSourceIds,
    'tags': tags,
    'priority': priority,
    'tokenCostEstimate': tokenCostEstimate,
    'createdAtMs': createdAtMs,
  };

  static ThoughtAtom fromJson(Map<String, Object?> json) {
    return ThoughtAtom(
      id: json['id']?.toString() ?? '',
      projectId: json['projectId']?.toString() ?? '',
      scopeId: json['scopeId']?.toString() ?? '',
      thoughtType: _parseThoughtType(json['thoughtType']),
      content: json['content']?.toString() ?? '',
      confidence: _parseDouble(json['confidence']),
      abstractionLevel: _parseDouble(json['abstractionLevel']),
      sourceRefs: _parseSourceRefs(json['sourceRefs']),
      rootSourceIds: _parseStringList(json['rootSourceIds']),
      tags: _parseStringList(json['tags']),
      priority: _parseInt(json['priority']),
      tokenCostEstimate: _parseInt(json['tokenCostEstimate']),
      createdAtMs: _parseInt(json['createdAtMs']),
    );
  }
}

/// A query against the memory store.
class StoryMemoryQuery {
  const StoryMemoryQuery({
    required this.projectId,
    required this.queryType,
    required this.text,
    this.tags = const [],
    this.viewerId,
    this.maxResults = 10,
    this.tokenBudget = 500,
    this.scopeId,
  });

  final String projectId;
  final StoryMemoryQueryType queryType;
  final String text;
  final List<String> tags;
  final String? viewerId;
  final int maxResults;
  final int tokenBudget;
  final String? scopeId;
}

/// A scored hit from the memory store matching a query.
class StoryMemoryHit {
  const StoryMemoryHit({
    required this.chunk,
    required this.score,
    this.isThought = false,
    this.thoughtAtom,
  });

  final StoryMemoryChunk chunk;
  final double score;
  final bool isThought;
  final ThoughtAtom? thoughtAtom;

  StoryMemoryHit copyWith({double? score}) {
    return StoryMemoryHit(
      chunk: chunk,
      score: score ?? this.score,
      isThought: isThought,
      thoughtAtom: thoughtAtom,
    );
  }
}

/// A compact retrieval result ready for prompt injection.
class StoryRetrievalPack {
  const StoryRetrievalPack({
    required this.query,
    required this.hits,
    this.sourceRefs = const [],
    this.summary = '',
    this.tokenBudget = 0,
    this.spentTokenEstimate = 0,
    this.deferredHitCount = 0,
  });

  final StoryMemoryQuery query;
  final List<StoryMemoryHit> hits;
  final List<MemorySourceRef> sourceRefs;
  final String summary;
  final int tokenBudget;
  final int spentTokenEstimate;
  final int deferredHitCount;
}

/// Trace record for retrieval audit.
class RetrievalTrace {
  const RetrievalTrace({
    required this.query,
    required this.selectedHitCount,
    required this.deferredHitCount,
    required this.thoughtCreationCount,
    required this.rejectedThoughtCount,
    required this.indexedChunkCount,
    this.sourceRefIds = const [],
  });

  final StoryMemoryQuery query;
  final int selectedHitCount;
  final int deferredHitCount;
  final int thoughtCreationCount;
  final int rejectedThoughtCount;
  final int indexedChunkCount;
  final List<String> sourceRefIds;

  Map<String, Object?> toJson() => {
    'queryType': query.queryType.name,
    'queryText': query.text,
    'selectedHitCount': selectedHitCount,
    'deferredHitCount': deferredHitCount,
    'thoughtCreationCount': thoughtCreationCount,
    'rejectedThoughtCount': rejectedThoughtCount,
    'indexedChunkCount': indexedChunkCount,
    'sourceRefIds': sourceRefIds,
  };
}

/// Result of thought extraction after scene acceptance.
class ThoughtUpdateResult {
  const ThoughtUpdateResult({
    required this.accepted,
    required this.rejected,
  });

  final List<ThoughtAtom> accepted;
  final List<ThoughtAtom> rejected;
}

/// Compressed summary of a completed chapter for cross-chapter context passing.
class ChapterSummary {
  const ChapterSummary({
    required this.chapterId,
    required this.chapterTitle,
    required this.sceneCount,
    required this.plotProgress,
    this.characterStateChanges = const [],
    this.unresolvedThreads = const [],
    this.createdAtMs = 0,
  });

  final String chapterId;
  final String chapterTitle;
  final int sceneCount;
  final String plotProgress;
  final List<String> characterStateChanges;
  final List<String> unresolvedThreads;
  final int createdAtMs;

  Map<String, Object?> toJson() => {
    'chapterId': chapterId,
    'chapterTitle': chapterTitle,
    'sceneCount': sceneCount,
    'plotProgress': plotProgress,
    'characterStateChanges': characterStateChanges,
    'unresolvedThreads': unresolvedThreads,
    'createdAtMs': createdAtMs,
  };

  static ChapterSummary fromJson(Map<String, Object?> json) => ChapterSummary(
    chapterId: json['chapterId']?.toString() ?? '',
    chapterTitle: json['chapterTitle']?.toString() ?? '',
    sceneCount: _parseInt(json['sceneCount']),
    plotProgress: json['plotProgress']?.toString() ?? '',
    characterStateChanges: _parseStringList(json['characterStateChanges']),
    unresolvedThreads: _parseStringList(json['unresolvedThreads']),
    createdAtMs: _parseInt(json['createdAtMs']),
  );
}

/// Cross-chapter context injected into a new chapter's scene generation.
class CrossChapterContext {
  const CrossChapterContext({
    required this.previousSummaries,
    required this.carryOverThoughts,
  });

  final List<ChapterSummary> previousSummaries;
  final List<ThoughtAtom> carryOverThoughts;

  bool get isEmpty =>
      previousSummaries.isEmpty && carryOverThoughts.isEmpty;
}

// -- Parse helpers ------------------------------------------------------------

final _sourceKindByName = {
  for (final v in MemorySourceKind.values) v.name: v,
};

MemorySourceKind _parseSourceKind(Object? raw) =>
    _sourceKindByName[raw?.toString()] ?? MemorySourceKind.worldFact;

final _thoughtTypeByName = {
  for (final v in ThoughtType.values) v.name: v,
};

ThoughtType _parseThoughtType(Object? raw) =>
    _thoughtTypeByName[raw?.toString()] ?? ThoughtType.persona;

final _visibilityByName = {
  for (final v in MemoryVisibility.values) v.name: v,
};

MemoryVisibility _parseVisibility(Object? raw) =>
    _visibilityByName[raw?.toString()] ??
    MemoryVisibility.publicObservable;

List<MemorySourceRef> _parseSourceRefs(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is Map)
        MemorySourceRef.fromJson(
          Map<String, Object?>.from(item),
        ),
  ];
}

List<String> _parseStringList(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item != null && item.toString().trim().isNotEmpty) item.toString(),
  ];
}

int _parseInt(Object? raw) {
  if (raw is int) return raw;
  return int.tryParse(raw?.toString() ?? '') ?? 0;
}

double _parseDouble(Object? raw) {
  if (raw is double) return raw;
  if (raw is int) return raw.toDouble();
  return double.tryParse(raw?.toString() ?? '') ?? 0.0;
}
