import 'scene_context_models.dart';
import 'scene_runtime_models.dart'
    show ResolvedBeat, RolePlayTurnOutput, SceneState;
import 'story_generation_models.dart';

class SceneCognitionUpdater {
  List<BeliefState> updateBeliefStates({
    required List<BeliefState> beliefStates,
    required List<ResolvedBeat> resolvedBeats,
    required SceneState sceneState,
  }) {
    if (beliefStates.isEmpty || resolvedBeats.isEmpty) {
      return beliefStates;
    }

    final updated = <BeliefState>[];
    for (final belief in beliefStates) {
      var nextGoal = belief.perceivedGoal;
      var nextRisk = belief.perceivedRisk;
      var nextEmotion = belief.perceivedEmotionalState;
      var nextConfidence = belief.confidence;
      final nextKnowledge = List<String>.from(belief.perceivedKnowledge);

      for (final beat in resolvedBeats) {
        if (!beat.actionAccepted || beat.actorId != belief.aboutCharacterId) {
          continue;
        }
        if (beat.newPublicFacts.isNotEmpty) {
          nextGoal = beat.newPublicFacts.last;
          nextKnowledge.addAll(beat.newPublicFacts);
          nextConfidence = (nextConfidence + 0.15).clamp(0.0, 1.0);
        }
        if (beat.acceptedSpeech.trim().isNotEmpty) {
          nextKnowledge.add(beat.acceptedSpeech.trim());
        }
        if (beat.acceptedAction.trim().isNotEmpty) {
          nextKnowledge.add(beat.acceptedAction.trim());
        }
      }

      if (sceneState.openThreats.isNotEmpty) {
        nextRisk = sceneState.openThreats.last;
        nextEmotion = _emotionFromThreat(sceneState.openThreats.last);
      }

      updated.add(
        BeliefState(
          ownerCharacterId: belief.ownerCharacterId,
          aboutCharacterId: belief.aboutCharacterId,
          perceivedGoal: nextGoal,
          perceivedLoyalty: belief.perceivedLoyalty,
          perceivedCompetence: belief.perceivedCompetence,
          perceivedRisk: nextRisk,
          perceivedEmotionalState: nextEmotion,
          perceivedKnowledge: _dedupe(nextKnowledge),
          suspectedSecrets: belief.suspectedSecrets,
          misreadPoints: belief.misreadPoints,
          confidence: nextConfidence,
        ),
      );
    }
    return updated;
  }

  List<PresentationState> updatePresentationStates({
    required List<PresentationState> presentationStates,
    required List<RolePlayTurnOutput> roleTurns,
    required List<ResolvedBeat> resolvedBeats,
    required SceneState sceneState,
  }) {
    if (presentationStates.isEmpty || roleTurns.isEmpty) {
      return presentationStates;
    }

    final updated = <PresentationState>[];
    for (final state in presentationStates) {
      var projectedPersona = state.projectedPersona;
      final concealments = List<String>.from(state.concealments);
      final deceptionGoals = List<String>.from(state.deceptionGoals);

      final latestTurn = _latestTurn(roleTurns, state.characterId);
      if (latestTurn != null) {
        if (latestTurn.intent.trim().isNotEmpty) {
          projectedPersona = latestTurn.intent.trim();
          deceptionGoals.add('维持${latestTurn.intent.trim()}的表象');
        }
        concealments.addAll(latestTurn.withheldInfo);
      }

      final acceptedBeat = resolvedBeats
          .where(
            (beat) => beat.actorId == state.characterId && beat.actionAccepted,
          )
          .toList(growable: false)
          .lastOrNull;
      if (acceptedBeat != null && acceptedBeat.stateDelta.isNotEmpty) {
        deceptionGoals.addAll(acceptedBeat.stateDelta);
      }
      if (sceneState.openThreats.isNotEmpty) {
        deceptionGoals.add(sceneState.openThreats.last);
      }

      updated.add(
        PresentationState(
          characterId: state.characterId,
          projectedPersona: projectedPersona,
          concealments: _dedupe(concealments),
          deceptionGoals: _dedupe(deceptionGoals),
        ),
      );
    }
    return updated;
  }

  String _emotionFromThreat(String threat) {
    if (threat.contains('急迫') ||
        threat.contains('提前') ||
        threat.contains('暴露')) {
      return '急迫';
    }
    if (threat.contains('冷静')) {
      return '冷静';
    }
    return '紧绷';
  }

  List<String> _dedupe(List<String> values) {
    final seen = <String>{};
    final ordered = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || seen.contains(trimmed)) {
        continue;
      }
      seen.add(trimmed);
      ordered.add(trimmed);
    }
    return ordered;
  }

  RolePlayTurnOutput? _latestTurn(
    List<RolePlayTurnOutput> roleTurns,
    String characterId,
  ) {
    for (var index = roleTurns.length - 1; index >= 0; index -= 1) {
      final turn = roleTurns[index];
      if (turn.characterId == characterId) {
        return turn;
      }
    }
    return null;
  }
}

extension<T> on List<T> {
  T? get lastOrNull => isEmpty ? null : last;
}
