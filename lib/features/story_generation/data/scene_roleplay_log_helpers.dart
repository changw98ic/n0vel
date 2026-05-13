import 'scene_roleplay_session_models.dart';
import 'scene_roleplay_speaker_scheduler.dart';
import '../domain/scene_models.dart';

/// Structured log-line builders for the roleplay runtime.
///
/// Each method returns a single `|`-delimited log line that can be fed
/// directly to an `onStatus` callback.  All members are static so the
/// class never needs instantiation.
class SceneRoleplayLog {
  SceneRoleplayLog._();

  static String turnLogLine({
    required SceneBrief brief,
    required int round,
    required int turnOrder,
    required SceneRoleplayTurn turn,
  }) {
    final parts = <String>[
      '场景 ${brief.chapterId}/${brief.sceneId} · roleplay-log turn',
      'R$round#$turnOrder',
      turn.name,
      if (turn.skillId.isNotEmpty) 'skill=${turn.skillId}@${turn.skillVersion}',
      '意图=${compactLogValue(turn.intent)}',
      '公开动作=${compactLogValue(turn.visibleAction)}',
      '对白=${compactLogValue(turn.dialogue)}',
      '内心=${compactLogValue(turn.innerState)}',
      if (turn.proseFragment.trim().isNotEmpty)
        '正文片段=${compactLogValue(turn.proseFragment)}',
      if (turn.proposedMemoryDeltas.isNotEmpty)
        '记忆提案=${turn.proposedMemoryDeltas.length}',
    ];
    return parts.join(' | ');
  }

  static String speakerScheduleLogLine({
    required SceneBrief brief,
    required int round,
    required SceneRoleplaySpeakerPlan plan,
    required bool parallelTurns,
  }) {
    final order = plan.speakers.map((speaker) => speaker.name).join('>');
    final parts = <String>[
      '场景 ${brief.chapterId}/${brief.sceneId} · roleplay-log actor-schedule',
      'R$round',
      'strategy=${plan.strategy}',
      'mode=${parallelTurns ? 'parallel' : 'sequential'}',
      'actors=${order.isEmpty ? '-' : order}',
    ];
    return parts.join(' | ');
  }

  static String arbitrationLogLine({
    required SceneBrief brief,
    required int round,
    required SceneRoleplayArbitration arbitration,
    required int committedFactCount,
  }) {
    final parts = <String>[
      '场景 ${brief.chapterId}/${brief.sceneId} · roleplay-log arbitration',
      'R$round',
      if (arbitration.skillId.isNotEmpty)
        'skill=${arbitration.skillId}@${arbitration.skillVersion}',
      '事实=${compactLogValue(arbitration.fact)}',
      '局面=${compactLogValue(arbitration.nextPublicState)}',
      '压力=${compactLogValue(arbitration.pressure)}',
      'stop=${arbitration.shouldStop}',
      'acceptedMemory=${arbitration.acceptedMemoryDeltas.length}',
      'rejectedMemory=${arbitration.rejectedMemoryDeltas.length}',
      'committedFacts=$committedFactCount',
    ];
    return parts.join(' | ');
  }

  static String completeLogLine({
    required SceneBrief brief,
    required List<SceneRoleplayRound> rounds,
    required int committedFactCount,
    required String finalPublicState,
  }) {
    final turnCount = rounds.fold<int>(
      0,
      (total, round) => total + round.turns.length,
    );
    return [
      '场景 ${brief.chapterId}/${brief.sceneId} · roleplay-log complete',
      'rounds=${rounds.length}',
      'turns=$turnCount',
      'committedFacts=$committedFactCount',
      '最终局面=${compactLogValue(finalPublicState, maxChars: 160)}',
    ].join(' | ');
  }

  static String compactLogValue(String value, {int maxChars = 96}) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return '-';
    if (normalized.length <= maxChars) return normalized;
    return '${normalized.substring(0, maxChars - 3)}...';
  }
}
