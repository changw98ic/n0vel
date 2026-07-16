import 'package:novel_writer/app/llm/app_llm_client.dart';

import '../domain/contracts/settings_contract.dart';

import 'character_memory_delta_models.dart';
import 'character_visible_context_models.dart';
import 'scene_roleplay_session_models.dart';
import 'story_generation_pass_retry.dart';
import 'story_prompt_registry.dart';
import 'formal_evaluation_policy.dart';

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
  BasicSceneArbiterSkill({
    required StoryGenerationSettingsContract settingsStore,
  }) : _settingsStore = settingsStore;

  final StoryGenerationSettingsContract _settingsStore;

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
    final formalEvaluation = FormalEvaluationPolicy.isActive(
      const <String, Object?>{},
    );
    final promptIdentity = StoryPromptRegistry.production.invocation(
      stageId: 'roleplay',
      callSiteId: 'arbiter',
    );
    final resolvedVariables = <String, Object?>{
      'skillId': skillId,
      'skillVersion': version,
      'round': round,
      'sceneTitle': sceneTitle,
      'previousState': previousPublicState,
      'roundTurns': roundTurns.map(_publicTurnLine).join('；'),
      'transcript': _compact(
        transcript.map(_publicTurnLine).join('；'),
        maxChars: 900,
      ),
    };
    final messages = promptIdentity.render(resolvedVariables).messages;
    late final AppLlmChatResult result;
    try {
      result = await requestFormalStoryGenerationPassWithRetry(
        settingsStore: _settingsStore,
        promptInvocation: promptIdentity,
        promptInvocationEvidence: promptIdentity.evidence(
          messages,
          resolvedVariables: resolvedVariables,
        ),
        shouldRetryOutput: formalEvaluation
            ? _shouldRejectExactArbitration
            : _shouldRetryMalformedArbitration,
        traceName: 'scene_roleplay_arbitrate',
        traceMetadata: <String, Object?>{
          'agentId': 'scene-arbiter',
          'agentRole': 'arbiter',
          'round': round,
          'skillId': skillId,
          'skillVersion': version,
        },
        messages: messages,
      );
    } on Object catch (error) {
      if (formalEvaluation) {
        throw StateError(
          'formal scene arbitration provider call failed: $error',
        );
      }
      rethrow;
    }
    if (!result.succeeded) {
      if (formalEvaluation) {
        throw StateError(
          result.detail ?? 'formal scene arbitration provider call failed',
        );
      }
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
    final raw = formalEvaluation ? result.text! : result.text!.trim();
    if (formalEvaluation && _shouldRejectExactArbitration(raw)) {
      throw StateError('formal scene arbitration output was malformed');
    }
    return _parseArbitration(
      raw: raw,
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

  bool _shouldRejectExactArbitration(String raw) {
    if (raw.isEmpty || raw != raw.trim()) return true;
    const labels = <String>['事实', '状态', '压力', '收束'];
    final lines = raw.split('\n');
    if (lines.length != labels.length) return true;
    final values = <String>[];
    for (var index = 0; index < labels.length; index += 1) {
      final line = lines[index];
      final prefix = '${labels[index]}：';
      if (line != line.trim() || !line.startsWith(prefix)) return true;
      final value = line.substring(prefix.length);
      if (value != value.trim()) return true;
      values.add(value);
    }
    if (_isPlaceholder(values[0]) ||
        _isPlaceholder(values[1]) ||
        _isPlaceholder(values[2])) {
      return true;
    }
    return values[3] != '是' && values[3] != '否';
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
