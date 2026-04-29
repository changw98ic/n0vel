import 'memory_models.dart';

import '../data/scene_runtime_models.dart' show SceneBrief;

export '../data/scene_context_models.dart'
    show
        SceneCastContribution,
        SceneCastParticipation,
        SceneCastCandidate,
        ResolvedSceneCastMember;
export '../data/scene_runtime_models.dart'
    show
        SceneBrief,
        SceneDirectorOutput,
        DynamicRoleAgentOutput,
        SceneProseDraft;
export '../data/scene_review_models.dart'
    show
        SceneReviewStatus,
        SceneReviewCategory,
        SceneReviewDecision,
        SceneReviewPassResult,
        SceneReviewResult,
        SceneRuntimeOutput;

/// Multi-dimensional quality score for a generated scene.
class SceneQualityScore {
  const SceneQualityScore({
    required this.overall,
    required this.prose,
    required this.coherence,
    required this.character,
    required this.completeness,
    this.summary = '',
  });

  final double overall;
  final double prose;
  final double coherence;
  final double character;
  final double completeness;
  final String summary;

  Map<String, Object?> toJson() {
    return {
      'overall': overall,
      'prose': prose,
      'coherence': coherence,
      'character': character,
      'completeness': completeness,
      'summary': summary,
    };
  }

  static SceneQualityScore fromJson(Map<Object?, Object?> json) {
    return SceneQualityScore(
      overall: _parseDouble(json['overall']),
      prose: _parseDouble(json['prose']),
      coherence: _parseDouble(json['coherence']),
      character: _parseDouble(json['character']),
      completeness: _parseDouble(json['completeness']),
      summary: json['summary']?.toString() ?? '',
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SceneQualityScore &&
        other.overall == overall &&
        other.prose == prose &&
        other.coherence == coherence &&
        other.character == character &&
        other.completeness == completeness &&
        other.summary == summary;
  }

  @override
  int get hashCode =>
      Object.hash(overall, prose, coherence, character, completeness, summary);
}

double _parseDouble(Object? raw) {
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw?.toString() ?? '') ?? 0.0;
}

/// Raw project materials available for scene context assembly.
class ProjectMaterialSnapshot {
  const ProjectMaterialSnapshot({
    this.worldFacts = const [],
    this.characterProfiles = const [],
    this.relationshipHints = const [],
    this.outlineBeats = const [],
    this.sceneSummaries = const [],
    this.acceptedStates = const [],
    this.reviewFindings = const [],
  });

  final List<String> worldFacts;
  final List<String> characterProfiles;
  final List<String> relationshipHints;
  final List<String> outlineBeats;
  final List<String> sceneSummaries;
  final List<String> acceptedStates;
  final List<String> reviewFindings;

  bool get isEmpty =>
      worldFacts.isEmpty &&
      characterProfiles.isEmpty &&
      relationshipHints.isEmpty &&
      outlineBeats.isEmpty &&
      sceneSummaries.isEmpty &&
      acceptedStates.isEmpty &&
      reviewFindings.isEmpty;
}

/// Assembled context for a scene generation pass.
class SceneContextAssembly {
  const SceneContextAssembly({
    required this.brief,
    required this.materialSnapshot,
    this.retrievalRequirements = const [],
    this.memoryChunks = const [],
    this.retrievalPack,
  });

  final SceneBrief brief;
  final ProjectMaterialSnapshot materialSnapshot;
  final List<String> retrievalRequirements;
  final List<StoryMemoryChunk> memoryChunks;
  final StoryRetrievalPack? retrievalPack;

  SceneContextAssembly copyWith({
    SceneBrief? brief,
    ProjectMaterialSnapshot? materialSnapshot,
    List<String>? retrievalRequirements,
    List<StoryMemoryChunk>? memoryChunks,
    StoryRetrievalPack? retrievalPack,
  }) {
    return SceneContextAssembly(
      brief: brief ?? this.brief,
      materialSnapshot: materialSnapshot ?? this.materialSnapshot,
      retrievalRequirements:
          retrievalRequirements ?? this.retrievalRequirements,
      memoryChunks: memoryChunks ?? this.memoryChunks,
      retrievalPack: retrievalPack ?? this.retrievalPack,
    );
  }
}
