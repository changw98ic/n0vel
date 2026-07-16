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
        SceneReviewPhase,
        SceneReviewAttempt,
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
    this.style,
    this.imagery,
    this.rhythm,
    this.faithfulness,
    this.summary = '',
    this.warning,
  });

  final double overall;
  final double prose;
  final double coherence;
  final double character;
  final double completeness;

  /// Extended rubric dimensions used by formal production runs.
  /// Legacy scorecards remain readable; formal runs require all four.
  final double? style;
  final double? imagery;
  final double? rhythm;
  final double? faithfulness;
  final String summary;
  final String? warning;

  double get styleScore => style ?? prose;
  double get imageryScore => imagery ?? prose;
  double get rhythmScore => rhythm ?? prose;
  double get faithfulnessScore => faithfulness ?? completeness;

  bool get hasExtendedRubric =>
      style != null &&
      imagery != null &&
      rhythm != null &&
      faithfulness != null;

  Map<String, Object?> toJson() {
    return {
      'overall': overall,
      'prose': prose,
      'coherence': coherence,
      'character': character,
      'completeness': completeness,
      if (style != null) 'style': style,
      if (imagery != null) 'imagery': imagery,
      if (rhythm != null) 'rhythm': rhythm,
      if (faithfulness != null) 'faithfulness': faithfulness,
      'summary': summary,
      if (warning != null && warning!.isNotEmpty) 'warning': warning,
    };
  }

  static SceneQualityScore fromJson(Map<Object?, Object?> json) {
    return SceneQualityScore(
      overall: _parseDouble(json['overall']),
      prose: _parseDouble(json['prose']),
      coherence: _parseDouble(json['coherence']),
      character: _parseDouble(json['character']),
      completeness: _parseDouble(json['completeness']),
      style: _parseOptionalDouble(json['style']),
      imagery: _parseOptionalDouble(json['imagery']),
      rhythm: _parseOptionalDouble(json['rhythm']),
      faithfulness: _parseOptionalDouble(json['faithfulness']),
      summary: json['summary']?.toString() ?? '',
      warning: json['warning']?.toString(),
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
        other.style == style &&
        other.imagery == imagery &&
        other.rhythm == rhythm &&
        other.faithfulness == faithfulness &&
        other.summary == summary &&
        other.warning == warning;
  }

  @override
  int get hashCode => Object.hash(
    overall,
    prose,
    coherence,
    character,
    completeness,
    style,
    imagery,
    rhythm,
    faithfulness,
    summary,
    warning,
  );
}

double _parseDouble(Object? raw) {
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw?.toString() ?? '') ?? 0.0;
}

double? _parseOptionalDouble(Object? raw) {
  if (raw == null) return null;
  final parsed = raw is num ? raw.toDouble() : double.tryParse(raw.toString());
  return parsed?.isFinite == true ? parsed : null;
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
