import 'package:novel_writer/app/state/app_storage_clone.dart';

import 'narrative_arc_models.dart';
import 'scene_context_models.dart';
import 'scene_pipeline_models.dart' show SceneDirectorPlan;

class SceneBrief {
  SceneBrief({
    required this.chapterId,
    required this.chapterTitle,
    required this.sceneId,
    required this.sceneTitle,
    required this.sceneSummary,
    this.projectId,
    this.targetLength = 400,
    this.targetBeat = '',
    List<String> worldNodeIds = const [],
    List<SceneCastCandidate> cast = const [],
    List<CharacterProfile> characterProfiles = const [],
    List<RelationshipState> relationshipStates = const [],
    List<SocialPositionState> socialPositions = const [],
    List<BeliefState> beliefStates = const [],
    List<PresentationState> presentationStates = const [],
    List<KnowledgeAtom> knowledgeAtoms = const [],
    this.narrativeArc,
    Map<String, Object?> metadata = const {},
  }) : worldNodeIds = immutableList(worldNodeIds),
       cast = immutableList(cast),
       characterProfiles = immutableList(characterProfiles),
       relationshipStates = immutableList(relationshipStates),
       socialPositions = immutableList(socialPositions),
       beliefStates = immutableList(beliefStates),
       presentationStates = immutableList(presentationStates),
       knowledgeAtoms = immutableList(knowledgeAtoms),
       metadata = immutableMap(metadata);

  final String? projectId;
  final String chapterId;
  final String chapterTitle;
  final String sceneId;
  final String sceneTitle;
  final String sceneSummary;
  final int targetLength;
  final String targetBeat;
  final List<String> worldNodeIds;
  final List<SceneCastCandidate> cast;
  final List<CharacterProfile> characterProfiles;
  final List<RelationshipState> relationshipStates;
  final List<SocialPositionState> socialPositions;
  final List<BeliefState> beliefStates;
  final List<PresentationState> presentationStates;
  final List<KnowledgeAtom> knowledgeAtoms;
  final NarrativeArcState? narrativeArc;
  final Map<String, Object?> metadata;

  SceneBrief copyWith({
    String? projectId,
    String? chapterId,
    String? chapterTitle,
    String? sceneId,
    String? sceneTitle,
    String? sceneSummary,
    int? targetLength,
    String? targetBeat,
    List<String>? worldNodeIds,
    List<SceneCastCandidate>? cast,
    List<CharacterProfile>? characterProfiles,
    List<RelationshipState>? relationshipStates,
    List<SocialPositionState>? socialPositions,
    List<BeliefState>? beliefStates,
    List<PresentationState>? presentationStates,
    List<KnowledgeAtom>? knowledgeAtoms,
    NarrativeArcState? narrativeArc,
    Map<String, Object?>? metadata,
  }) {
    return SceneBrief(
      projectId: projectId ?? this.projectId,
      chapterId: chapterId ?? this.chapterId,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      sceneId: sceneId ?? this.sceneId,
      sceneTitle: sceneTitle ?? this.sceneTitle,
      sceneSummary: sceneSummary ?? this.sceneSummary,
      targetLength: targetLength ?? this.targetLength,
      targetBeat: targetBeat ?? this.targetBeat,
      worldNodeIds: worldNodeIds ?? this.worldNodeIds,
      cast: cast ?? this.cast,
      characterProfiles: characterProfiles ?? this.characterProfiles,
      relationshipStates: relationshipStates ?? this.relationshipStates,
      socialPositions: socialPositions ?? this.socialPositions,
      beliefStates: beliefStates ?? this.beliefStates,
      presentationStates: presentationStates ?? this.presentationStates,
      knowledgeAtoms: knowledgeAtoms ?? this.knowledgeAtoms,
      narrativeArc: narrativeArc ?? this.narrativeArc,
      metadata: metadata ?? this.metadata,
    );
  }
}

class SceneTaskCard {
  SceneTaskCard({
    required this.sceneGoal,
    required this.blockingConflict,
    required this.progression,
    List<String> constraints = const [],
    List<String> requiredReveals = const [],
    List<String> requiredWithholds = const [],
    this.exitCondition = '',
  }) : constraints = immutableList(constraints),
       requiredReveals = immutableList(requiredReveals),
       requiredWithholds = immutableList(requiredWithholds);

  final String sceneGoal;
  final String blockingConflict;
  final String progression;
  final List<String> constraints;
  final List<String> requiredReveals;
  final List<String> requiredWithholds;
  final String exitCondition;

  String toPromptText() {
    return [
      '目标：$sceneGoal',
      '冲突：$blockingConflict',
      '推进：$progression',
      if (constraints.isNotEmpty) '约束：${constraints.join(' / ')}',
    ].join('\n');
  }
}

class SceneDirectorOutput {
  const SceneDirectorOutput({required this.text, this.taskCard, this.plan});

  final String text;
  final SceneTaskCard? taskCard;
  final SceneDirectorPlan? plan;
}

class DynamicRoleAgentOutput {
  const DynamicRoleAgentOutput({
    required this.characterId,
    required this.name,
    required this.text,
  });

  final String characterId;
  final String name;
  final String text;
}

enum SceneStateDeltaKind { control, locationExit, alliance, exposure, generic }

class SceneStateDelta {
  const SceneStateDelta({required this.kind, required this.value});

  final SceneStateDeltaKind kind;
  final String value;

  factory SceneStateDelta.inferKind(String value) {
    return SceneStateDelta(kind: inferDeltaKindFromValue(value), value: value);
  }

  static SceneStateDeltaKind inferDeltaKindFromValue(String value) {
    if (value.contains('主动权') ||
        value.contains('控制权') ||
        value.contains('主导权')) {
      return SceneStateDeltaKind.control;
    }
    if (value.contains('离开') ||
        value.contains('脱离') ||
        value.contains('撤出') ||
        value.contains('离场')) {
      return SceneStateDeltaKind.locationExit;
    }
    if (value.contains('合作') ||
        value.contains('联手') ||
        value.contains('同盟') ||
        value.contains('决裂')) {
      return SceneStateDeltaKind.alliance;
    }
    if (value.contains('暴露') || value.contains('交底') || value.contains('公开')) {
      return SceneStateDeltaKind.exposure;
    }
    return SceneStateDeltaKind.generic;
  }
}

class AgentToolIntent {
  AgentToolIntent({
    required this.toolName,
    required this.reason,
    List<String> targetIds = const [],
    this.question = '',
    this.priority = 0,
  }) : targetIds = immutableList(targetIds);

  final String toolName;
  final String reason;
  final List<String> targetIds;
  final String question;
  final int priority;
}

class ContextCapsule {
  ContextCapsule({
    required this.id,
    required this.capsuleType,
    required this.sourceTool,
    required this.summary,
    List<String> salientFacts = const [],
    List<String> uncertainties = const [],
    this.expiresAfterTurn = 1,
    this.priority = 0,
    List<String> visibilityScopes = const [],
  }) : salientFacts = immutableList(salientFacts),
       uncertainties = immutableList(uncertainties),
       visibilityScopes = immutableList(visibilityScopes);

  final String id;
  final String capsuleType;
  final String sourceTool;
  final String summary;
  final List<String> salientFacts;
  final List<String> uncertainties;
  final int expiresAfterTurn;
  final int priority;
  final List<String> visibilityScopes;

  String toPromptText() {
    final buffer = StringBuffer()
      ..writeln('来源：$sourceTool')
      ..writeln('摘要：$summary');
    if (salientFacts.isNotEmpty) {
      buffer.writeln('关键信息：${salientFacts.join('；')}');
    }
    if (uncertainties.isNotEmpty) {
      buffer.writeln('未确定：${uncertainties.join('；')}');
    }
    return buffer.toString().trimRight();
  }
}

class RolePlayTurnOutput {
  RolePlayTurnOutput({
    required this.characterId,
    required this.intent,
    required this.spokenLine,
    required this.physicalAction,
    required this.observation,
    required this.proposedStateChange,
    required this.riskTaken,
    List<SceneStateDelta> typedStateDeltas = const [],
    List<String> withheldInfo = const [],
    List<AgentToolIntent> requestedIntents = const [],
    List<ContextCapsule> capsulesUsed = const [],
  }) : typedStateDeltas = immutableList(typedStateDeltas),
       withheldInfo = immutableList(withheldInfo),
       requestedIntents = immutableList(requestedIntents),
       capsulesUsed = immutableList(capsulesUsed);

  final String characterId;
  final String intent;
  final String spokenLine;
  final String physicalAction;
  final String observation;
  final String proposedStateChange;
  final String riskTaken;
  final List<SceneStateDelta> typedStateDeltas;
  final List<String> withheldInfo;
  final List<AgentToolIntent> requestedIntents;
  final List<ContextCapsule> capsulesUsed;

  String toLegacyRoleText() {
    return [
      '意图：$intent',
      if (spokenLine.trim().isNotEmpty) '对白：$spokenLine',
      if (physicalAction.trim().isNotEmpty) '动作：$physicalAction',
      if (observation.trim().isNotEmpty) '观察：$observation',
      if (proposedStateChange.trim().isNotEmpty) '变化：$proposedStateChange',
      if (typedStateDeltas.isNotEmpty)
        '结构变化：${typedStateDeltas.map((delta) => '${delta.kind.name}:${delta.value}').join(' / ')}',
      if (riskTaken.trim().isNotEmpty) '风险：$riskTaken',
      if (withheldInfo.isNotEmpty) '保留：${withheldInfo.join(' / ')}',
      if (capsulesUsed.isNotEmpty)
        '检索胶囊：${capsulesUsed.map((capsule) => capsule.summary).join(' / ')}',
    ].join('\n');
  }
}

class ResolvedBeat {
  ResolvedBeat({
    required this.beatIndex,
    required this.actorId,
    required this.actionAccepted,
    required this.acceptedSpeech,
    required this.acceptedAction,
    this.rejectionReason = '',
    List<SceneStateDelta> typedStateDeltas = const [],
    List<String> stateDelta = const [],
    List<String> newPublicFacts = const [],
    List<String> continuityNotes = const [],
  }) : typedStateDeltas = immutableList(typedStateDeltas),
       stateDelta = immutableList(stateDelta),
       newPublicFacts = immutableList(newPublicFacts),
       continuityNotes = immutableList(continuityNotes);

  final int beatIndex;
  final String actorId;
  final bool actionAccepted;
  final String acceptedSpeech;
  final String acceptedAction;
  final String rejectionReason;
  final List<SceneStateDelta> typedStateDeltas;
  final List<String> stateDelta;
  final List<String> newPublicFacts;
  final List<String> continuityNotes;
}

class SceneState {
  SceneState({
    required this.sceneId,
    this.turnIndex = 0,
    this.beatIndex = 0,
    Map<String, Object?> locationState = const {},
    Map<String, String> propOwnership = const {},
    Map<String, List<String>> knownFactsByCharacter = const {},
    List<String> openThreats = const [],
    List<String> acceptedStateChanges = const [],
    List<SceneStateDelta> acceptedStateDeltas = const [],
    this.lastResolvedBeat,
    this.tensionLevel = 0,
  }) : locationState = immutableMap(locationState),
       propOwnership = Map<String, String>.unmodifiable(propOwnership),
       knownFactsByCharacter = Map<String, List<String>>.unmodifiable({
         for (final entry in knownFactsByCharacter.entries)
           entry.key: immutableList(entry.value),
       }),
       openThreats = immutableList(openThreats),
       acceptedStateChanges = immutableList(acceptedStateChanges),
       acceptedStateDeltas = immutableList(acceptedStateDeltas);

  factory SceneState.initial({required String sceneId}) {
    return SceneState(sceneId: sceneId);
  }

  final String sceneId;
  final int turnIndex;
  final int beatIndex;
  final Map<String, Object?> locationState;
  final Map<String, String> propOwnership;
  final Map<String, List<String>> knownFactsByCharacter;
  final List<String> openThreats;
  final List<String> acceptedStateChanges;
  final List<SceneStateDelta> acceptedStateDeltas;
  final ResolvedBeat? lastResolvedBeat;
  final double tensionLevel;

  SceneState copyWith({
    int? turnIndex,
    int? beatIndex,
    Map<String, Object?>? locationState,
    Map<String, String>? propOwnership,
    Map<String, List<String>>? knownFactsByCharacter,
    List<String>? openThreats,
    List<String>? acceptedStateChanges,
    List<SceneStateDelta>? acceptedStateDeltas,
    ResolvedBeat? lastResolvedBeat,
    double? tensionLevel,
  }) {
    return SceneState(
      sceneId: sceneId,
      turnIndex: turnIndex ?? this.turnIndex,
      beatIndex: beatIndex ?? this.beatIndex,
      locationState: locationState ?? this.locationState,
      propOwnership: propOwnership ?? this.propOwnership,
      knownFactsByCharacter:
          knownFactsByCharacter ?? this.knownFactsByCharacter,
      openThreats: openThreats ?? this.openThreats,
      acceptedStateChanges: acceptedStateChanges ?? this.acceptedStateChanges,
      acceptedStateDeltas: acceptedStateDeltas ?? this.acceptedStateDeltas,
      lastResolvedBeat: lastResolvedBeat ?? this.lastResolvedBeat,
      tensionLevel: tensionLevel ?? this.tensionLevel,
    );
  }
}

class SceneEditorialDraft {
  SceneEditorialDraft({
    required this.text,
    List<int> beatOrder = const [],
    this.povStrategy = 'linear-scene',
  }) : beatOrder = immutableList(beatOrder);

  final String text;
  final List<int> beatOrder;
  final String povStrategy;
}

class SceneProseDraft {
  const SceneProseDraft({required this.text, required this.attempt});

  final String text;
  final int attempt;
}
