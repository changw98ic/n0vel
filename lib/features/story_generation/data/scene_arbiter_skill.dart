import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';

import 'character_memory_delta_models.dart';
import 'character_visible_context_models.dart';
import 'scene_roleplay_session_models.dart';
import 'story_generation_pass_retry.dart';

abstract interface class SceneArbiterSkill {
  String get skillId;
  String get version;

  Future<SceneRoleplayArbitration> arbitrate({
    required String sceneTitle,
    required String previousPublicState,
    required int round,
    required List<SceneRoleplayTurn> roundTurns,
    required List<SceneRoleplayTurn> transcript,
  });
}

class BasicSceneArbiterSkill implements SceneArbiterSkill {
  BasicSceneArbiterSkill({required AppSettingsStore settingsStore})
    : _settingsStore = settingsStore;

  final AppSettingsStore _settingsStore;

  @override
  String get skillId => 'basic_scene_arbiter';

  @override
  String get version => '1.0.0';

  @override
  Future<SceneRoleplayArbitration> arbitrate({
    required String sceneTitle,
    required String previousPublicState,
    required int round,
    required List<SceneRoleplayTurn> roundTurns,
    required List<SceneRoleplayTurn> transcript,
  }) async {
    final result = await requestStoryGenerationPassWithRetry(
      settingsStore: _settingsStore,
      shouldRetryOutput: _shouldRetryMalformedArbitration,
      messages: [
        const AppLlmChatMessage(
          role: 'system',
          content:
              'You are a neutral scene arbiter. Resolve only public facts from '
              'visible actions and dialogue. Use this 4-line public summary:\n'
              '事实：...\n'
              '状态：...\n'
              '压力：...\n'
              '收束：是/否',
        ),
        AppLlmChatMessage(
          role: 'user',
          content: [
            '任务：scene_roleplay_arbitrate',
            'skill：$skillId@$version',
            '回合：$round',
            '场景：$sceneTitle',
            '上一局面：$previousPublicState',
            '本轮行动：${roundTurns.map(_publicTurnLine).join('；')}',
            '全部可见过程：${_compact(transcript.map(_publicTurnLine).join('；'), maxChars: 900)}',
            '判断：若核心冲突已推动到可写正文的阶段，收束为是；否则为否。',
          ].join('\n'),
        ),
      ],
    );
    if (!result.succeeded) {
      final nextState = _fallbackState(
        sceneState: previousPublicState,
        turns: roundTurns,
      );
      return SceneRoleplayArbitration(
        fact: '',
        state: '',
        pressure: '',
        nextPublicState: nextState,
        shouldStop: false,
        rawText: '',
        skillId: skillId,
        skillVersion: version,
      );
    }
    return _parseArbitration(
      raw: result.text!.trim(),
      previousState: previousPublicState,
      roundTurns: roundTurns,
    );
  }

  SceneRoleplayArbitration _parseArbitration({
    required String raw,
    required String previousState,
    required List<SceneRoleplayTurn> roundTurns,
  }) {
    String fact = '';
    String state = '';
    String pressure = '';
    var shouldStop = false;

    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('事实：')) {
        fact = trimmed.substring('事实：'.length).trim();
      } else if (trimmed.startsWith('状态：')) {
        state = trimmed.substring('状态：'.length).trim();
      } else if (trimmed.startsWith('压力：')) {
        pressure = trimmed.substring('压力：'.length).trim();
      } else if (trimmed.startsWith('收束：')) {
        final value = trimmed.substring('收束：'.length).trim();
        shouldStop = value.startsWith('是') || value.toLowerCase() == 'true';
      }
    }

    final nextState = [
      if (previousState.isNotEmpty) previousState,
      if (fact.isNotEmpty) '事实：$fact',
      if (state.isNotEmpty) '状态：$state',
      if (pressure.isNotEmpty) '压力：$pressure',
    ].join(' / ');
    final resolvedState = nextState.isEmpty
        ? _fallbackState(sceneState: previousState, turns: roundTurns)
        : _compact(nextState, maxChars: 700);

    return SceneRoleplayArbitration(
      fact: fact,
      state: state,
      pressure: pressure,
      nextPublicState: resolvedState,
      shouldStop: shouldStop,
      rawText: raw,
      skillId: skillId,
      skillVersion: version,
      acceptedMemoryDeltas: [
        if (fact.isNotEmpty)
          _publicFactDelta(
            round: roundTurns.isEmpty ? 0 : roundTurns.first.round,
            fact: fact,
          ),
        ..._acceptedPrivateDeltas(roundTurns),
      ],
    );
  }

  bool _shouldRetryMalformedArbitration(String raw) {
    var hasFact = false;
    var hasState = false;
    var hasPressure = false;
    var hasClosure = false;
    var fact = '';
    var state = '';
    var pressure = '';

    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('事实：')) {
        hasFact = true;
        fact = trimmed.substring('事实：'.length).trim();
      } else if (trimmed.startsWith('状态：')) {
        hasState = true;
        state = trimmed.substring('状态：'.length).trim();
      } else if (trimmed.startsWith('压力：')) {
        hasPressure = true;
        pressure = trimmed.substring('压力：'.length).trim();
      } else if (trimmed.startsWith('收束：')) {
        hasClosure = true;
      }
    }

    if (!hasFact || !hasState || !hasPressure || !hasClosure) {
      return true;
    }
    return _isPlaceholder(fact) ||
        _isPlaceholder(state) ||
        _isPlaceholder(pressure);
  }

  bool _isPlaceholder(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ||
        normalized == '-' ||
        normalized == '—' ||
        normalized == '...' ||
        normalized == '…' ||
        normalized == '……';
  }

  List<CharacterMemoryDelta> _acceptedPrivateDeltas(
    List<SceneRoleplayTurn> roundTurns,
  ) {
    final seen = <String>{};
    final accepted = <CharacterMemoryDelta>[];
    for (final turn in roundTurns) {
      for (final delta in turn.proposedMemoryDeltas) {
        final content = _normalizeMemoryContent(delta.content);
        if (content.length < 2) continue;
        if (delta.characterId.isEmpty) continue;
        if (!delta.acl.canSee(delta.characterId)) continue;
        if (delta.confidence < 0.45) continue;
        final key = '${delta.characterId}|${delta.kind.name}|$content';
        if (!seen.add(key)) continue;
        accepted.add(delta.accept());
      }
    }
    return accepted;
  }

  String _normalizeMemoryContent(String value) {
    return value.replaceAll(RegExp(r'\s+'), '').trim();
  }

  String _fallbackState({
    required String sceneState,
    required List<SceneRoleplayTurn> turns,
  }) {
    final actions = turns
        .map(_visibleAction)
        .where((value) => value.isNotEmpty)
        .join('；');
    if (actions.isEmpty) return sceneState;
    return _compact('$sceneState / 本轮推进：$actions', maxChars: 700);
  }

  String _visibleAction(SceneRoleplayTurn turn) {
    final parts = <String>[
      if (turn.visibleAction.trim().isNotEmpty) turn.visibleAction.trim(),
      if (turn.dialogue.trim().isNotEmpty) '说“${turn.dialogue.trim()}”',
    ];
    return parts.join('，');
  }

  String _publicTurnLine(SceneRoleplayTurn turn) {
    final parts = <String>[
      'R${turn.round}',
      turn.name,
      if (turn.visibleAction.trim().isNotEmpty)
        '动作=${turn.visibleAction.trim()}',
      if (turn.dialogue.trim().isNotEmpty) '对白=${turn.dialogue.trim()}',
    ];
    return parts.join('/');
  }

  String _compact(String value, {required int maxChars}) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxChars) return normalized;
    return '${normalized.substring(0, maxChars - 3)}...';
  }

  CharacterMemoryDelta _publicFactDelta({
    required int round,
    required String fact,
  }) {
    final id = 'fact-$round-${_stableHash(fact)}';
    return CharacterMemoryDelta(
      deltaId: id,
      kind: CharacterMemoryDeltaKind.observation,
      content: fact,
      acl: VisibilityAcl.public(),
      sourceRound: round,
      sourceTurnId: 'arbiter:$round',
      accepted: true,
    );
  }

  String _stableHash(String input) {
    var hash = 0x811c9dc5;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
