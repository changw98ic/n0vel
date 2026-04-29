// ---------------------------------------------------------------------------
// Enumerations
// ---------------------------------------------------------------------------

enum MemorySourceKind {
  worldNode,
  characterRecord,
  relationship,
  outlineBeat,
  sceneContext,
  generatedScene,
  reviewFinding,
  thoughtAtom;

  static MemorySourceKind fromJson(String value) {
    return MemorySourceKind.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MemorySourceKind.worldNode,
    );
  }
}

enum MemoryChunkKind {
  worldFact,
  characterProfile,
  relationshipHint,
  outlineBeat,
  sceneSummary,
  acceptedState,
  reviewFinding,
  thoughtContent;

  static MemoryChunkKind fromJson(String value) {
    return MemoryChunkKind.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MemoryChunkKind.worldFact,
    );
  }
}

enum ThoughtType {
  persona,
  plotCausality,
  stateChange,
  foreshadowing,
  style,
  worldConsistency;

  static ThoughtType fromJson(String value) {
    return ThoughtType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ThoughtType.persona,
    );
  }
}

enum MemoryQueryKind {
  concreteFact,
  sceneContinuity,
  persona,
  causality,
  foreshadowing,
  style;

  static MemoryQueryKind fromJson(String value) {
    return MemoryQueryKind.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MemoryQueryKind.concreteFact,
    );
  }
}

enum KnowledgeVisibility {
  publicObservable,
  agentPrivate,
}

// ---------------------------------------------------------------------------
// Source reference
// ---------------------------------------------------------------------------

class MemorySourceRef {
  const MemorySourceRef({
    required this.sourceId,
    required this.sourceType,
  });

  final String sourceId;
  final String sourceType;

  Map<String, Object?> toJson() => {
    'sourceId': sourceId,
    'sourceType': sourceType,
  };

  factory MemorySourceRef.fromJson(Map<String, Object?> json) {
    return MemorySourceRef(
      sourceId: json['sourceId'] as String? ?? '',
      sourceType: json['sourceType'] as String? ?? '',
    );
  }
}

// ---------------------------------------------------------------------------
// Story memory source
// ---------------------------------------------------------------------------

class StoryMemorySource {
  const StoryMemorySource({
    required this.id,
    required this.projectId,
    required this.scopeId,
    required this.sourceKind,
    required this.rawContent,
    this.metadata = const {},
    this.createdAtMs = 0,
  });

  final String id;
  final String projectId;
  final String scopeId;
  final MemorySourceKind sourceKind;
  final String rawContent;
  final Map<String, Object?> metadata;
  final int createdAtMs;

  Map<String, Object?> toJson() => {
    'id': id,
    'projectId': projectId,
    'scopeId': scopeId,
    'sourceKind': sourceKind.name,
    'rawContent': rawContent,
    'metadata': metadata,
    'createdAtMs': createdAtMs,
  };

  factory StoryMemorySource.fromJson(Map<String, Object?> json) {
    return StoryMemorySource(
      id: json['id'] as String? ?? '',
      projectId: json['projectId'] as String? ?? '',
      scopeId: json['scopeId'] as String? ?? '',
      sourceKind: MemorySourceKind.fromJson(
        json['sourceKind'] as String? ?? 'worldNode',
      ),
      rawContent: json['rawContent'] as String? ?? '',
      metadata: json['metadata'] as Map<String, Object?>? ?? {},
      createdAtMs: json['createdAtMs'] as int? ?? 0,
    );
  }
}

// ---------------------------------------------------------------------------
// Story memory chunk
// ---------------------------------------------------------------------------

class StoryMemoryChunk {
  const StoryMemoryChunk({
    required this.id,
    required this.projectId,
    required this.scopeId,
    required this.chunkKind,
    required this.content,
    required this.sourceRefs,
    required this.rootSourceIds,
    this.visibility = KnowledgeVisibility.publicObservable,
    this.tags = const [],
    this.priority = 0,
    this.tokenCostEstimate = 0,
    this.createdAtMs = 0,
  });

  final String id;
  final String projectId;
  final String scopeId;
  final MemoryChunkKind chunkKind;
  final String content;
  final List<MemorySourceRef> sourceRefs;
  final List<String> rootSourceIds;
  final KnowledgeVisibility visibility;
  final List<String> tags;
  final int priority;
  final int tokenCostEstimate;
  final int createdAtMs;

  Map<String, Object?> toJson() => {
    'id': id,
    'projectId': projectId,
    'scopeId': scopeId,
    'chunkKind': chunkKind.name,
    'content': content,
    'sourceRefs': [for (final ref in sourceRefs) ref.toJson()],
    'rootSourceIds': rootSourceIds,
    'visibility': visibility.name,
    'tags': tags,
    'priority': priority,
    'tokenCostEstimate': tokenCostEstimate,
    'createdAtMs': createdAtMs,
  };

  factory StoryMemoryChunk.fromJson(Map<String, Object?> json) {
    final sourceRefsRaw = json['sourceRefs'] as List? ?? [];
    return StoryMemoryChunk(
      id: json['id'] as String? ?? '',
      projectId: json['projectId'] as String? ?? '',
      scopeId: json['scopeId'] as String? ?? '',
      chunkKind: MemoryChunkKind.fromJson(
        json['chunkKind'] as String? ?? 'worldFact',
      ),
      content: json['content'] as String? ?? '',
      sourceRefs: [
        for (final ref in sourceRefsRaw)
          MemorySourceRef.fromJson(ref as Map<String, Object?>),
      ],
      rootSourceIds: (json['rootSourceIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      visibility: json['visibility'] == 'agentPrivate'
          ? KnowledgeVisibility.agentPrivate
          : KnowledgeVisibility.publicObservable,
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      priority: json['priority'] as int? ?? 0,
      tokenCostEstimate: json['tokenCostEstimate'] as int? ?? 0,
      createdAtMs: json['createdAtMs'] as int? ?? 0,
    );
  }

  StoryMemoryChunk copyWith({int? priority, int? createdAtMs}) {
    return StoryMemoryChunk(
      id: id,
      projectId: projectId,
      scopeId: scopeId,
      chunkKind: chunkKind,
      content: content,
      sourceRefs: sourceRefs,
      rootSourceIds: rootSourceIds,
      visibility: visibility,
      tags: tags,
      priority: priority ?? this.priority,
      tokenCostEstimate: tokenCostEstimate,
      createdAtMs: createdAtMs ?? this.createdAtMs,
    );
  }
}

// ---------------------------------------------------------------------------
// Thought atom
// ---------------------------------------------------------------------------

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
    'sourceRefs': [for (final ref in sourceRefs) ref.toJson()],
    'rootSourceIds': rootSourceIds,
    'tags': tags,
    'priority': priority,
    'tokenCostEstimate': tokenCostEstimate,
    'createdAtMs': createdAtMs,
  };

  factory ThoughtAtom.fromJson(Map<String, Object?> json) {
    final sourceRefsRaw = json['sourceRefs'] as List? ?? [];
    return ThoughtAtom(
      id: json['id'] as String? ?? '',
      projectId: json['projectId'] as String? ?? '',
      scopeId: json['scopeId'] as String? ?? '',
      thoughtType: ThoughtType.fromJson(
        json['thoughtType'] as String? ?? 'persona',
      ),
      content: json['content'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      abstractionLevel: (json['abstractionLevel'] as num?)?.toDouble() ?? 1.0,
      sourceRefs: [
        for (final ref in sourceRefsRaw)
          MemorySourceRef.fromJson(ref as Map<String, Object?>),
      ],
      rootSourceIds: (json['rootSourceIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      priority: json['priority'] as int? ?? 0,
      tokenCostEstimate: json['tokenCostEstimate'] as int? ?? 0,
      createdAtMs: json['createdAtMs'] as int? ?? 0,
    );
  }
}

// ---------------------------------------------------------------------------
// Memory query
// ---------------------------------------------------------------------------

class StoryMemoryQuery {
  const StoryMemoryQuery({
    required this.projectId,
    required this.keywords,
    required this.queryKind,
    this.tags = const [],
    this.viewerRole,
    this.tokenBudget = 800,
    this.scopeId,
  });

  final String projectId;
  final List<String> keywords;
  final MemoryQueryKind queryKind;
  final List<String> tags;
  final String? viewerRole;
  final int tokenBudget;
  final String? scopeId;
}

// ---------------------------------------------------------------------------
// Retrieval hit
// ---------------------------------------------------------------------------

class StoryMemoryHit {
  const StoryMemoryHit({
    required this.chunk,
    required this.score,
    required this.scoreBreakdown,
  });

  final StoryMemoryChunk chunk;
  final double score;
  final Map<String, double> scoreBreakdown;
}

// ---------------------------------------------------------------------------
// Retrieval pack
// ---------------------------------------------------------------------------

class StoryRetrievalPack {
  const StoryRetrievalPack({
    required this.query,
    required this.hits,
    required this.sourceRefs,
    required this.summary,
    required this.tokenBudget,
    required this.spentTokenEstimate,
    required this.deferredHitCount,
  });

  final StoryMemoryQuery query;
  final List<StoryMemoryHit> hits;
  final List<MemorySourceRef> sourceRefs;
  final String summary;
  final int tokenBudget;
  final int spentTokenEstimate;
  final int deferredHitCount;
}
