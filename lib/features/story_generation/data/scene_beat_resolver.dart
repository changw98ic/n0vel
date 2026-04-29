import '../domain/roleplay_models.dart';

/// Resolves conflicting scene beats into an accepted/rejected state.
///
/// When multiple characters target the same entity, only the first action
/// (in submission order) is accepted. All conflicting actions are explicitly
/// accepted or rejected with a reason.
class SceneBeatResolver {
  SceneBeatResolver({this.maxTargetConflicts = 1});

  final int maxTargetConflicts;

  SceneStateDelta resolve(List<SceneBeat> beats) {
    final conflictGroups = _groupConflicts(beats);
    final resolved = <ResolvedBeat>[];

    for (final beat in beats) {
      final targetId = beat.targetId;
      if (targetId == null) {
        resolved.add(ResolvedBeat(
          beat: beat,
          resolution: BeatResolution.accepted,
          reason: 'No target conflict',
        ));
        continue;
      }

      final group = conflictGroups[targetId];
      if (group == null || group.length <= maxTargetConflicts) {
        resolved.add(ResolvedBeat(
          beat: beat,
          resolution: BeatResolution.accepted,
          reason: 'No conflict',
        ));
        continue;
      }

      final isFirstForTarget = group.first == beat;
      resolved.add(ResolvedBeat(
        beat: beat,
        resolution:
            isFirstForTarget ? BeatResolution.accepted : BeatResolution.rejected,
        reason: isFirstForTarget
            ? 'Accepted as primary action on target $targetId'
            : 'Rejected: conflicts with earlier action on target $targetId',
      ));
    }

    return SceneStateDelta(resolvedBeats: resolved);
  }

  /// Resolves beats and generates belief updates from rejected actions.
  ///
  /// When a character's action is rejected because another character acted
  /// first, a belief update may be generated reflecting the new information.
  SceneStateDelta resolveWithBeliefUpdates(
    List<SceneBeat> beats, {
    String Function(SceneBeat rejected, SceneBeat accepted)? updateReason,
  }) {
    final delta = resolve(beats);
    final beliefUpdates = <BeliefUpdate>[];

    for (final rb in delta.rejectedBeats) {
      final accepted = _findAcceptedCompetitor(delta, rb.beat);
      if (accepted != null && updateReason != null) {
        beliefUpdates.add(BeliefUpdate(
          characterId: rb.beat.characterId,
          targetId: rb.beat.targetId ?? accepted.beat.characterId,
          oldClaim: rb.beat.action,
          newClaim: accepted.beat.action,
          reason: updateReason(rb.beat, accepted.beat),
        ));
      }
    }

    return SceneStateDelta(
      resolvedBeats: delta.resolvedBeats,
      beliefUpdates: beliefUpdates,
    );
  }

  Map<String, List<SceneBeat>> _groupConflicts(List<SceneBeat> beats) {
    final groups = <String, List<SceneBeat>>{};
    for (final beat in beats) {
      final targetId = beat.targetId;
      if (targetId == null) continue;
      groups.putIfAbsent(targetId, () => []).add(beat);
    }
    return {
      for (final entry in groups.entries)
        if (entry.value.length > maxTargetConflicts) entry.key: entry.value,
    };
  }

  ResolvedBeat? _findAcceptedCompetitor(
    SceneStateDelta delta,
    SceneBeat rejectedBeat,
  ) {
    for (final rb in delta.acceptedBeats) {
      if (rb.beat.targetId == rejectedBeat.targetId &&
          rb.beat.characterId != rejectedBeat.characterId) {
        return rb;
      }
    }
    return null;
  }
}
