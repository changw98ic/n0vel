import 'scene_context_models.dart' show ResolvedSceneCastMember;
import 'scene_pipeline_models.dart' as pipeline show SceneTaskCard, KnowledgeSnippet;
import '../domain/character_cognition_models.dart' show CharacterBelief, RelationshipSlice, SocialPositionSlice;
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

  List<CharacterBelief> beliefsFromBrief(SceneBrief brief) {
    final beliefs = <CharacterBelief>[];
    void add({
      required String subjectId,
      required String targetId,
      required String claim,
      double confidence = 1.0,
      String source = '',
    }) {
      final trimmed = claim.trim();
      if (trimmed.isEmpty) return;
      beliefs.add(
        CharacterBelief(
          subjectId: subjectId,
          targetId: targetId,
          claim: trimmed,
          confidence: confidence,
          source: source,
        ),
      );
    }

    for (final belief in brief.beliefStates) {
      add(
        subjectId: belief.ownerCharacterId,
        targetId: belief.aboutCharacterId,
        claim: '感知目标：${belief.perceivedGoal}',
        source: 'beliefState',
      );
      add(
        subjectId: belief.ownerCharacterId,
        targetId: belief.aboutCharacterId,
        claim: '感知立场：${belief.perceivedLoyalty}',
        source: 'beliefState',
      );
      add(
        subjectId: belief.ownerCharacterId,
        targetId: belief.aboutCharacterId,
        claim: '感知能力：${belief.perceivedCompetence}',
        source: 'beliefState',
      );
      add(
        subjectId: belief.ownerCharacterId,
        targetId: belief.aboutCharacterId,
        claim: '感知风险：${belief.perceivedRisk}',
        source: 'beliefState',
      );
      add(
        subjectId: belief.ownerCharacterId,
        targetId: belief.aboutCharacterId,
        claim: '感知情绪：${belief.perceivedEmotionalState}',
        source: 'beliefState',
      );
      for (final item in belief.perceivedKnowledge) {
        add(
          subjectId: belief.ownerCharacterId,
          targetId: belief.aboutCharacterId,
          claim: '已形成认知：$item',
          source: 'beliefState',
        );
      }
      for (final item in belief.suspectedSecrets) {
        add(
          subjectId: belief.ownerCharacterId,
          targetId: belief.aboutCharacterId,
          claim: '怀疑内容：$item',
          source: 'beliefState',
        );
      }
    }
    return List<CharacterBelief>.unmodifiable(beliefs);
  }

  List<RelationshipSlice> relationshipsFromBrief(SceneBrief brief) {
    return [
      for (final relationship in brief.relationshipStates)
        RelationshipSlice(
          characterId: relationship.sourceCharacterId,
          otherId: relationship.targetCharacterId,
          kind: relationship.privateAlignment.trim().isNotEmpty
              ? relationship.privateAlignment.trim()
              : relationship.publicAlignment.trim(),
          tension: (relationship.fear + relationship.resentment) / 2,
          trust: relationship.trust,
          notes: '',
        ),
    ];
  }

  List<SocialPositionSlice> socialPositionsFromBrief(
    SceneBrief brief,
  ) {
    return [
      for (final position in brief.socialPositions)
        SocialPositionSlice(
          characterId: position.characterId,
          contextId: '',
          role: position.institution,
          rank: 0,
          notes: [
            '公开地位：${position.publicStatus}',
            ...position.currentLeverage,
            ...position.resources,
            if (position.legalExposure.trim().isNotEmpty)
              '法律风险：${position.legalExposure.trim()}',
          ].join('；'),
        ),
    ];
  }

  List<pipeline.KnowledgeSnippet> knowledgeFromBrief(SceneBrief brief) {
    return [
      for (final atom in brief.knowledgeAtoms)
        if (atom.visibility.name == 'publicObservable' ||
            atom.visibility.name == 'agentPrivate')
          pipeline.KnowledgeSnippet(
            id: atom.id,
            category: atom.type,
            content: atom.content,
            sourceId: atom.ownerScope,
          ),
    ];
  }
}
