import 'package:novel_writer/domain/storage_utils.dart';

import '../domain/contracts/soul_contract.dart';
import '../domain/contracts/structured_profile.dart';
import '../domain/scene_models.dart' show ProjectMaterialSnapshot;
import 'narrative_arc_models.dart';
import 'scene_context_models.dart';
import 'scene_runtime_models.dart';

/// Builds the detached, deeply immutable scene input used at the provider
/// boundary.
///
/// [SceneBrief] protects its top-level collections, but several legacy value
/// objects deliberately retain caller-owned lists for const construction. A
/// generation identity therefore cannot safely seal the caller's object graph
/// directly: a nested mutation between admission and dispatch could change the
/// prompt without changing the recorded identity. This snapshot reconstructs
/// every provider-visible value object and recursively freezes metadata.
final class SceneBriefSnapshot {
  const SceneBriefSnapshot._();

  static SceneBrief freeze(SceneBrief source) {
    return SceneBrief(
      projectId: source.projectId,
      chapterId: source.chapterId,
      chapterTitle: source.chapterTitle,
      sceneId: source.sceneId,
      sceneIndex: source.sceneIndex,
      totalScenesInChapter: source.totalScenesInChapter,
      sceneTitle: source.sceneTitle,
      sceneSummary: source.sceneSummary,
      targetLength: source.targetLength,
      targetBeat: source.targetBeat,
      worldNodeIds: _strings(source.worldNodeIds),
      cast: [for (final value in source.cast) _cast(value)],
      characterProfiles: [
        for (final value in source.characterProfiles) _profile(value),
      ],
      relationshipStates: [
        for (final value in source.relationshipStates) _relationship(value),
      ],
      socialPositions: [
        for (final value in source.socialPositions) _socialPosition(value),
      ],
      beliefStates: [for (final value in source.beliefStates) _belief(value)],
      presentationStates: [
        for (final value in source.presentationStates) _presentation(value),
      ],
      knowledgeAtoms: [
        for (final value in source.knowledgeAtoms) _knowledge(value),
      ],
      narrativeArc: source.narrativeArc == null
          ? null
          : freezeNarrativeArc(source.narrativeArc!),
      formalExecution: source.formalExecution,
      metadata: immutableMap(source.metadata),
    );
  }

  static ProjectMaterialSnapshot freezeMaterials(
    ProjectMaterialSnapshot source,
  ) {
    return ProjectMaterialSnapshot(
      worldFacts: _strings(source.worldFacts),
      characterProfiles: _strings(source.characterProfiles),
      relationshipHints: _strings(source.relationshipHints),
      outlineBeats: _strings(source.outlineBeats),
      sceneSummaries: _strings(source.sceneSummaries),
      acceptedStates: _strings(source.acceptedStates),
      reviewFindings: _strings(source.reviewFindings),
    );
  }

  static NarrativeArcState freezeNarrativeArc(NarrativeArcState source) {
    return NarrativeArcState(
      activeThreads: [
        for (final value in source.activeThreads) _plotThread(value),
      ],
      closedThreads: [
        for (final value in source.closedThreads) _plotThread(value),
      ],
      pendingForeshadowing: [
        for (final value in source.pendingForeshadowing) _foreshadowing(value),
      ],
      thematicArcs: _strings(source.thematicArcs),
      chapterIndex: source.chapterIndex,
    );
  }

  static SceneCastCandidate _cast(SceneCastCandidate source) {
    return SceneCastCandidate(
      characterId: source.characterId,
      name: source.name,
      role: source.role,
      participation: SceneCastParticipation(
        action: source.participation.action,
        dialogue: source.participation.dialogue,
        interaction: source.participation.interaction,
      ),
      metadata: immutableMap(source.metadata),
    );
  }

  static StructuredProfile _profile(StructuredProfile source) {
    return StructuredProfile(
      id: source.id,
      name: source.name,
      personality: PersonalityVector(
        openness: source.personality.openness,
        conscientiousness: source.personality.conscientiousness,
        extraversion: source.personality.extraversion,
        agreeableness: source.personality.agreeableness,
        neuroticism: source.personality.neuroticism,
      ),
      voicePrint: VoicePrint(
        vocabularyLevel: source.voicePrint.vocabularyLevel,
        sentenceLength: source.voicePrint.sentenceLength,
        speakingPatterns: _strings(source.voicePrint.speakingPatterns),
        catchphrases: _strings(source.voicePrint.catchphrases),
        toneModifiers: _strings(source.voicePrint.toneModifiers),
      ),
      behaviorBounds: BehaviorBounds(
        forbiddenActions: _strings(source.behaviorBounds.forbiddenActions),
        mandatoryResponses: _strings(source.behaviorBounds.mandatoryResponses),
        emotionalRange: EmotionalRange(
          maxIntensity: source.behaviorBounds.emotionalRange.maxIntensity,
          forbiddenEmotions: _strings(
            source.behaviorBounds.emotionalRange.forbiddenEmotions,
          ),
          defaultState: source.behaviorBounds.emotionalRange.defaultState,
        ),
      ),
      soul: SoulContract(
        coreValues: _strings(source.soul.coreValues),
        forbiddenActions: _strings(source.soul.forbiddenActions),
        emotionalRange: EmotionalContract(
          maxIntensity: source.soul.emotionalRange.maxIntensity,
          forbiddenEmotions: _strings(
            source.soul.emotionalRange.forbiddenEmotions,
          ),
          defaultState: source.soul.emotionalRange.defaultState,
        ),
        decisionPattern: source.soul.decisionPattern,
        unbreakablePromises: _strings(source.soul.unbreakablePromises),
        identityAnchors: _strings(source.soul.identityAnchors),
      ),
      backstory: source.backstory,
      relationships: List<RelationshipEdge>.unmodifiable([
        for (final value in source.relationships)
          RelationshipEdge(
            targetId: value.targetId,
            type: value.type,
            strength: value.strength,
          ),
      ]),
      metadata: immutableMap(source.metadata),
    );
  }

  static RelationshipState _relationship(RelationshipState source) {
    return RelationshipState(
      sourceCharacterId: source.sourceCharacterId,
      targetCharacterId: source.targetCharacterId,
      trust: source.trust,
      dependence: source.dependence,
      fear: source.fear,
      resentment: source.resentment,
      desire: source.desire,
      powerGap: source.powerGap,
      publicAlignment: source.publicAlignment,
      privateAlignment: source.privateAlignment,
      sharedSecrets: _strings(source.sharedSecrets),
      recentTriggers: _strings(source.recentTriggers),
    );
  }

  static SocialPositionState _socialPosition(SocialPositionState source) {
    return SocialPositionState(
      characterId: source.characterId,
      institution: source.institution,
      publicStatus: source.publicStatus,
      legalExposure: source.legalExposure,
      resources: _strings(source.resources),
      activeConstraints: _strings(source.activeConstraints),
      currentLeverage: _strings(source.currentLeverage),
      watchers: _strings(source.watchers),
    );
  }

  static BeliefState _belief(BeliefState source) {
    return BeliefState(
      ownerCharacterId: source.ownerCharacterId,
      aboutCharacterId: source.aboutCharacterId,
      perceivedGoal: source.perceivedGoal,
      perceivedLoyalty: source.perceivedLoyalty,
      perceivedCompetence: source.perceivedCompetence,
      perceivedRisk: source.perceivedRisk,
      perceivedEmotionalState: source.perceivedEmotionalState,
      perceivedKnowledge: _strings(source.perceivedKnowledge),
      suspectedSecrets: _strings(source.suspectedSecrets),
      misreadPoints: _strings(source.misreadPoints),
      confidence: source.confidence,
    );
  }

  static ContextPresentationState _presentation(
    ContextPresentationState source,
  ) {
    return ContextPresentationState(
      characterId: source.characterId,
      projectedPersona: source.projectedPersona,
      concealments: _strings(source.concealments),
      deceptionGoals: _strings(source.deceptionGoals),
    );
  }

  static KnowledgeAtom _knowledge(KnowledgeAtom source) {
    return KnowledgeAtom(
      id: source.id,
      type: source.type,
      content: source.content,
      ownerScope: source.ownerScope,
      visibility: source.visibility,
      priority: source.priority,
      tokenCostEstimate: source.tokenCostEstimate,
      tags: _strings(source.tags),
      unlockCondition: immutableMap(source.unlockCondition),
    );
  }

  static PlotThread _plotThread(PlotThread source) {
    return PlotThread(
      id: source.id,
      description: source.description,
      status: source.status,
      involvedCharacters: _strings(source.involvedCharacters),
      introducedInScene: source.introducedInScene,
      resolvedInScene: source.resolvedInScene,
    );
  }

  static Foreshadowing _foreshadowing(Foreshadowing source) {
    return Foreshadowing(
      id: source.id,
      hint: source.hint,
      plannedPayoff: source.plannedPayoff,
      plantedInScene: source.plantedInScene,
      resolvedInScene: source.resolvedInScene,
      urgency: source.urgency,
    );
  }

  static List<String> _strings(List<String> source) =>
      List<String>.unmodifiable(source);
}
