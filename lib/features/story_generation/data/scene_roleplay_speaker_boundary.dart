import 'character_memory_delta_models.dart';
import 'scene_roleplay_session_models.dart';
import '../domain/scene_models.dart';

/// Ensures each character's turn content stays within its speaker boundary:
/// strips self-prefix (e.g. "阿岚：...") and truncates at the first line
/// that begins with another character's name followed by a colon.
class SceneRoleplaySpeakerBoundary {
  const SceneRoleplaySpeakerBoundary();

  SceneRoleplayTurn apply({
    required SceneRoleplayTurn turn,
    required ResolvedSceneCastMember speaker,
    required List<ResolvedSceneCastMember> cast,
  }) {
    final otherNames = [
      for (final member in cast)
        if (member.characterId != speaker.characterId) member.name,
    ];
    final intent = boundedField(
      turn.intent,
      speakerName: speaker.name,
      otherNames: otherNames,
    );
    final visibleAction = boundedField(
      turn.visibleAction,
      speakerName: speaker.name,
      otherNames: otherNames,
    );
    final dialogue = boundedField(
      turn.dialogue,
      speakerName: speaker.name,
      otherNames: otherNames,
    );
    final innerState = boundedField(
      turn.innerState,
      speakerName: speaker.name,
      otherNames: otherNames,
    );
    final taboo = boundedField(
      turn.taboo,
      speakerName: speaker.name,
      otherNames: otherNames,
    );
    final proseFragment = boundedField(
      turn.proseFragment,
      speakerName: speaker.name,
      otherNames: otherNames,
    );
    final proposedMemoryDeltas = boundedMemoryDeltas(
      turn.proposedMemoryDeltas,
      speakerName: speaker.name,
      otherNames: otherNames,
    );
    if (intent == turn.intent &&
        visibleAction == turn.visibleAction &&
        dialogue == turn.dialogue &&
        innerState == turn.innerState &&
        taboo == turn.taboo &&
        proseFragment == turn.proseFragment &&
        identical(proposedMemoryDeltas, turn.proposedMemoryDeltas)) {
      return turn;
    }
    return SceneRoleplayTurn(
      round: turn.round,
      characterId: turn.characterId,
      name: turn.name,
      intent: intent,
      visibleAction: visibleAction,
      dialogue: dialogue,
      innerState: innerState,
      taboo: taboo,
      rawText: turn.rawText,
      proseFragment: proseFragment,
      skillId: turn.skillId,
      skillVersion: turn.skillVersion,
      proposedMemoryDeltas: proposedMemoryDeltas,
    );
  }

  List<CharacterMemoryDelta> boundedMemoryDeltas(
    List<CharacterMemoryDelta> deltas, {
    required String speakerName,
    required List<String> otherNames,
  }) {
    var changed = false;
    final bounded = <CharacterMemoryDelta>[];
    for (final delta in deltas) {
      final content = boundedField(
        delta.content,
        speakerName: speakerName,
        otherNames: otherNames,
      );
      if (content != delta.content) changed = true;
      if (content.isEmpty) {
        changed = true;
        continue;
      }
      bounded.add(
        CharacterMemoryDelta(
          deltaId: delta.deltaId,
          characterId: delta.characterId,
          kind: delta.kind,
          content: content,
          acl: delta.acl,
          sourceRound: delta.sourceRound,
          sourceTurnId: delta.sourceTurnId,
          confidence: delta.confidence,
          accepted: delta.accepted,
          rejectionReason: delta.rejectionReason,
        ),
      );
    }
    return changed ? List<CharacterMemoryDelta>.unmodifiable(bounded) : deltas;
  }

  String boundedField(
    String value, {
    required String speakerName,
    required List<String> otherNames,
  }) {
    var result = value.trim();
    if (result.isEmpty) return '';
    result = result.replaceFirst(
      RegExp('^\\s*${RegExp.escape(speakerName)}\\s*[:：]\\s*'),
      '',
    );
    var earliestOtherPrefix = -1;
    for (final name in otherNames) {
      if (name.trim().isEmpty) continue;
      final match = RegExp(
        '(^|\\n)\\s*${RegExp.escape(name)}\\s*[:：]',
      ).firstMatch(result);
      if (match == null) continue;
      if (earliestOtherPrefix < 0 || match.start < earliestOtherPrefix) {
        earliestOtherPrefix = match.start;
      }
    }
    if (earliestOtherPrefix >= 0) {
      result = result.substring(0, earliestOtherPrefix).trimRight();
    }
    return result.trim();
  }
}
