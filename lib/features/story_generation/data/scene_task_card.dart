part of 'scene_pipeline_models.dart';

// ---------------------------------------------------------------------------
// Scene task card
// ---------------------------------------------------------------------------

class SceneTaskCard {
  SceneTaskCard({
    required this.brief,
    required List<ResolvedSceneCastMember> cast,
    this.directorPlan = '',
    this.directorPlanParsed,
    List<CharacterBelief> beliefs = const [],
    List<RelationshipSlice> relationships = const [],
    List<SocialPositionSlice> socialPositions = const [],
    List<KnowledgeAtom> knowledge = const [],
    Map<String, Object?> metadata = const {},
  }) : cast = _immutableList(cast),
       beliefs = _immutableList(beliefs),
       relationships = _immutableList(relationships),
       socialPositions = _immutableList(socialPositions),
       knowledge = _immutableList(knowledge),
       metadata = _immutableMap(metadata);

  final SceneBrief brief;
  final List<ResolvedSceneCastMember> cast;
  final String directorPlan;
  final SceneDirectorPlan? directorPlanParsed;
  final List<CharacterBelief> beliefs;
  final List<RelationshipSlice> relationships;
  final List<SocialPositionSlice> socialPositions;
  final List<KnowledgeAtom> knowledge;
  final Map<String, Object?> metadata;

  /// Beliefs held by [characterId] about others.
  List<CharacterBelief> beliefsFor(String characterId) => [
    for (final b in beliefs)
      if (b.holderId == characterId) b,
  ];

  /// Relationship slices involving [characterId].
  List<RelationshipSlice> relationshipsFor(String characterId) => [
    for (final r in relationships)
      if (r.characterA == characterId || r.characterB == characterId) r,
  ];

  /// Social position for [characterId], if any.
  SocialPositionSlice? socialPositionFor(String characterId) {
    for (final sp in socialPositions) {
      if (sp.characterId == characterId) return sp;
    }
    return null;
  }
}
