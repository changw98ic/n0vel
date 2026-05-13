import 'scene_context_models.dart' show ResolvedSceneCastMember;
import 'scene_pipeline_models.dart' as pipeline
    show
        SceneTaskCard,
        CharacterBelief,
        RelationshipSlice,
        SocialPositionSlice,
        KnowledgeAtom;
import 'scene_runtime_models.dart' show SceneBrief, SceneDirectorOutput;

/// Builds a [pipeline.SceneTaskCard] from a scene brief, resolved cast, and
/// director output. Extracted from ChapterGenerationOrchestrator to isolate
/// the data transformation logic.
class SceneTaskCardBuilder {
  const SceneTaskCardBuilder();

  pipeline.SceneTaskCard build({
    required SceneBrief brief,
    required List<ResolvedSceneCastMember> cast,
    required SceneDirectorOutput director,
  }) {
    return pipeline.SceneTaskCard(
      brief: brief,
      cast: cast,
      directorPlan: director.text,
      directorPlanParsed: director.plan,
      beliefs: beliefsFromBrief(brief),
      relationships: relationshipsFromBrief(brief),
      socialPositions: socialPositionsFromBrief(brief),
      knowledge: knowledgeFromBrief(brief),
      metadata: brief.metadata,
    );
  }

  List<pipeline.CharacterBelief> beliefsFromBrief(SceneBrief brief) {
    final beliefs = <pipeline.CharacterBelief>[];
    void add({
      required String holderId,
      required String targetId,
      required String aspect,
      required String value,
    }) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      beliefs.add(
        pipeline.CharacterBelief(
          holderId: holderId,
          targetId: targetId,
          aspect: aspect,
          value: trimmed,
        ),
      );
    }

    for (final belief in brief.beliefStates) {
      add(
        holderId: belief.ownerCharacterId,
        targetId: belief.aboutCharacterId,
        aspect: '感知目标',
        value: belief.perceivedGoal,
      );
      add(
        holderId: belief.ownerCharacterId,
        targetId: belief.aboutCharacterId,
        aspect: '感知立场',
        value: belief.perceivedLoyalty,
      );
      add(
        holderId: belief.ownerCharacterId,
        targetId: belief.aboutCharacterId,
        aspect: '感知能力',
        value: belief.perceivedCompetence,
      );
      add(
        holderId: belief.ownerCharacterId,
        targetId: belief.aboutCharacterId,
        aspect: '感知风险',
        value: belief.perceivedRisk,
      );
      add(
        holderId: belief.ownerCharacterId,
        targetId: belief.aboutCharacterId,
        aspect: '感知情绪',
        value: belief.perceivedEmotionalState,
      );
      for (final item in belief.perceivedKnowledge) {
        add(
          holderId: belief.ownerCharacterId,
          targetId: belief.aboutCharacterId,
          aspect: '已形成认知',
          value: item,
        );
      }
      for (final item in belief.suspectedSecrets) {
        add(
          holderId: belief.ownerCharacterId,
          targetId: belief.aboutCharacterId,
          aspect: '怀疑内容',
          value: item,
        );
      }
    }
    return List<pipeline.CharacterBelief>.unmodifiable(beliefs);
  }

  List<pipeline.RelationshipSlice> relationshipsFromBrief(SceneBrief brief) {
    return [
      for (final relationship in brief.relationshipStates)
        pipeline.RelationshipSlice(
          characterA: relationship.sourceCharacterId,
          characterB: relationship.targetCharacterId,
          label: relationship.privateAlignment.trim().isNotEmpty
              ? relationship.privateAlignment.trim()
              : relationship.publicAlignment.trim(),
          tension:
              ((relationship.fear + relationship.resentment) * 5).round().clamp(0, 10),
          trust: (relationship.trust * 10).round().clamp(0, 10),
        ),
    ];
  }

  List<pipeline.SocialPositionSlice> socialPositionsFromBrief(
    SceneBrief brief,
  ) {
    return [
      for (final position in brief.socialPositions)
        pipeline.SocialPositionSlice(
          characterId: position.characterId,
          role: position.institution,
          formalRank: position.publicStatus,
          actualInfluence: [
            ...position.currentLeverage,
            ...position.resources,
            if (position.legalExposure.trim().isNotEmpty)
              position.legalExposure.trim(),
          ].join('；'),
        ),
    ];
  }

  List<pipeline.KnowledgeAtom> knowledgeFromBrief(SceneBrief brief) {
    return [
      for (final atom in brief.knowledgeAtoms)
        if (atom.visibility.name == 'publicObservable' ||
            atom.visibility.name == 'agentPrivate')
          pipeline.KnowledgeAtom(
            id: atom.id,
            category: atom.type,
            content: atom.content,
            sourceId: atom.ownerScope,
          ),
    ];
  }
}
