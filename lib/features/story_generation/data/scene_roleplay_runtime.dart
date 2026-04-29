import 'package:novel_writer/app/state/app_settings_store.dart';

import 'character_visible_context_builder.dart';
import 'role_skill_registry.dart';
import 'scene_arbiter_skill.dart';
import 'scene_pipeline_models.dart' show SceneTaskCard;
import 'scene_roleplay_session_models.dart';
import '../domain/scene_models.dart';

class SceneRoleplayRuntimeResult {
  SceneRoleplayRuntimeResult({
    required List<DynamicRoleAgentOutput> outputs,
    required this.session,
  }) : outputs = List.unmodifiable(outputs);

  final List<DynamicRoleAgentOutput> outputs;
  final SceneRoleplaySession session;
}

class SceneRoleplayRuntime {
  SceneRoleplayRuntime({
    required AppSettingsStore settingsStore,
    this.defaultMaxRounds = 3,
    CharacterVisibleContextBuilder? visibleContextBuilder,
    RoleSkillRegistry? roleSkillRegistry,
    SceneArbiterSkill? arbiterSkill,
  }) : _visibleContextBuilder =
           visibleContextBuilder ?? const CharacterVisibleContextBuilder(),
       _roleSkillRegistry =
           roleSkillRegistry ?? RoleSkillRegistry(settingsStore: settingsStore),
       _arbiterSkill =
           arbiterSkill ?? BasicSceneArbiterSkill(settingsStore: settingsStore);

  final CharacterVisibleContextBuilder _visibleContextBuilder;
  final RoleSkillRegistry _roleSkillRegistry;
  final SceneArbiterSkill _arbiterSkill;
  final int defaultMaxRounds;

  Future<List<DynamicRoleAgentOutput>> run({
    required SceneBrief brief,
    required List<ResolvedSceneCastMember> cast,
    required SceneDirectorOutput director,
    SceneTaskCard? taskCard,
    String? ragContext,
    void Function(String message)? onStatus,
  }) async {
    final result = await runSession(
      brief: brief,
      cast: cast,
      director: director,
      taskCard: taskCard,
      ragContext: ragContext,
      onStatus: onStatus,
    );
    return result.outputs;
  }

  Future<SceneRoleplayRuntimeResult> runSession({
    required SceneBrief brief,
    required List<ResolvedSceneCastMember> cast,
    required SceneDirectorOutput director,
    SceneTaskCard? taskCard,
    String? ragContext,
    void Function(String message)? onStatus,
  }) async {
    if (cast.isEmpty) {
      return SceneRoleplayRuntimeResult(
        outputs: const <DynamicRoleAgentOutput>[],
        session: SceneRoleplaySession(
          chapterId: brief.chapterId,
          sceneId: brief.sceneId,
          sceneTitle: brief.sceneTitle,
          rounds: const <SceneRoleplayRound>[],
        ),
      );
    }

    final maxRounds = _roundCount(brief: brief, taskCard: taskCard);
    var sceneState = _initialSceneState(brief: brief, director: director);
    final transcript = <SceneRoleplayTurn>[];
    final rounds = <SceneRoleplayRound>[];
    final committedFacts = <SceneRoleplayCommittedFact>[];
    final turnsByCharacter = <String, List<SceneRoleplayTurn>>{
      for (final member in cast) member.characterId: <SceneRoleplayTurn>[],
    };

    for (var round = 1; round <= maxRounds; round += 1) {
      onStatus?.call(
        '场景 ${brief.chapterId}/${brief.sceneId} · roleplay round $round',
      );
      final roundTurns = <SceneRoleplayTurn>[];

      for (final member in cast) {
        onStatus?.call(
          '场景 ${brief.chapterId}/${brief.sceneId} · role ${member.name}',
        );
        final turn = await _runCharacterTurn(
          brief: brief,
          director: director,
          member: member,
          taskCard: taskCard,
          round: round,
          sceneState: sceneState,
          transcript: transcript,
        );
        transcript.add(turn);
        roundTurns.add(turn);
        turnsByCharacter[member.characterId]!.add(turn);
      }

      final arbitration = await _arbitrateRound(
        brief: brief,
        round: round,
        sceneState: sceneState,
        roundTurns: roundTurns,
        transcript: transcript,
      );
      sceneState = arbitration.nextPublicState;
      committedFacts.addAll(
        _commitArbitrationFacts(
          arbitration,
          round: round,
          existingFacts: committedFacts,
        ),
      );
      rounds.add(
        SceneRoleplayRound(
          round: round,
          turns: roundTurns,
          arbitration: arbitration,
        ),
      );
      if (round >= 2 && arbitration.shouldStop) {
        break;
      }
    }

    return SceneRoleplayRuntimeResult(
      outputs: [
        for (final member in cast)
          _memberOutput(
            member: member,
            turns:
                turnsByCharacter[member.characterId] ??
                const <SceneRoleplayTurn>[],
            sceneState: sceneState,
          ),
      ],
      session: SceneRoleplaySession(
        chapterId: brief.chapterId,
        sceneId: brief.sceneId,
        sceneTitle: brief.sceneTitle,
        rounds: rounds,
        committedFacts: committedFacts,
        finalPublicState: sceneState,
      ),
    );
  }

  Future<SceneRoleplayTurn> _runCharacterTurn({
    required SceneBrief brief,
    required SceneDirectorOutput director,
    required ResolvedSceneCastMember member,
    required int round,
    required String sceneState,
    required List<SceneRoleplayTurn> transcript,
    SceneTaskCard? taskCard,
  }) async {
    final visibleContext = _visibleContextBuilder.build(
      brief: brief,
      member: member,
      director: director,
      publicSceneState: sceneState,
      transcript: transcript,
      taskCard: taskCard,
    );
    final skill = _roleSkillRegistry.resolve(
      member: member,
      metadata: brief.metadata,
    );
    return skill.runTurn(context: visibleContext, round: round);
  }

  Future<SceneRoleplayArbitration> _arbitrateRound({
    required SceneBrief brief,
    required int round,
    required String sceneState,
    required List<SceneRoleplayTurn> roundTurns,
    required List<SceneRoleplayTurn> transcript,
  }) async {
    return _arbiterSkill.arbitrate(
      sceneTitle: brief.sceneTitle,
      previousPublicState: sceneState,
      round: round,
      roundTurns: roundTurns,
      transcript: transcript,
    );
  }

  List<SceneRoleplayCommittedFact> _commitArbitrationFacts(
    SceneRoleplayArbitration arbitration, {
    required int round,
    required List<SceneRoleplayCommittedFact> existingFacts,
  }) {
    final fact = arbitration.fact.trim();
    if (fact.isEmpty) return const <SceneRoleplayCommittedFact>[];

    final sequenceId = existingFacts.length + 1;
    final previousHash = existingFacts.isEmpty
        ? 'root'
        : existingFacts.last.contentHash;
    final source = arbitration.skillId.isEmpty
        ? 'arbiter'
        : arbitration.skillId;
    final hashInput = [sequenceId, round, source, previousHash, fact].join('|');
    return [
      SceneRoleplayCommittedFact(
        sequenceId: sequenceId,
        round: round,
        source: source,
        content: fact,
        previousHash: previousHash,
        contentHash: _stableHash(hashInput),
      ),
    ];
  }

  DynamicRoleAgentOutput _memberOutput({
    required ResolvedSceneCastMember member,
    required List<SceneRoleplayTurn> turns,
    required String sceneState,
  }) {
    final last = turns.isNotEmpty ? turns.last : null;
    final stance = _firstNonEmpty([
      last?.intent,
      turns.map((t) => t.intent).where((v) => v.isNotEmpty).join('；'),
      '${member.name}维持${member.role}的场内立场',
    ]);
    final action = _firstNonEmpty([
      last == null ? '' : _visibleAction(last),
      turns.map(_visibleAction).where((v) => v.isNotEmpty).join('；'),
      '参与场景冲突推进',
    ]);
    final taboo = _firstNonEmpty([
      last?.taboo,
      turns.map((t) => t.taboo).where((v) => v.isNotEmpty).join('；'),
      '脱离角色当前认知边界',
    ]);
    final process = turns
        .map(
          (turn) =>
              'R${turn.round}:${_compact(_visibleAction(turn), maxChars: 64)}',
        )
        .where((line) => !line.endsWith(':'))
        .join(' / ');

    return DynamicRoleAgentOutput(
      characterId: member.characterId,
      name: member.name,
      text: [
        '立场：$stance',
        '动作：$action',
        '禁忌：$taboo',
        if (process.isNotEmpty) '过程：$process',
        '局面：${_compact(sceneState, maxChars: 120)}',
      ].join('\n'),
    );
  }

  SceneRoleplayTurn _parseTurn({
    required String raw,
    required int round,
    required ResolvedSceneCastMember member,
  }) {
    final values = <String, String>{};
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      final colon = trimmed.indexOf('：');
      if (colon <= 0) continue;
      values[trimmed.substring(0, colon)] = trimmed.substring(colon + 1).trim();
    }
    return SceneRoleplayTurn(
      round: round,
      characterId: member.characterId,
      name: member.name,
      intent: values['意图'] ?? '',
      visibleAction: values['可见动作'] ?? '',
      dialogue: values['对白'] ?? '',
      innerState: values['内心'] ?? '',
      taboo: values['禁忌'] ?? '',
      rawText: raw,
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
    );
  }

  String _fallbackState({
    required String sceneState,
    required List<SceneRoleplayTurn> turns,
  }) {
    final actions = turns
        .map(_visibleAction)
        .where((v) => v.isNotEmpty)
        .join('；');
    if (actions.isEmpty) return sceneState;
    return _compact('$sceneState / 本轮推进：$actions', maxChars: 700);
  }

  String _initialSceneState({
    required SceneBrief brief,
    required SceneDirectorOutput director,
  }) {
    final explicitPublicState =
        _metadataString(brief.metadata['publicSceneState']) ??
        _metadataString(brief.metadata['publicSceneSetup']) ??
        _metadataString(brief.metadata['publicOpening']);
    if (explicitPublicState != null && explicitPublicState.isNotEmpty) {
      return _compact(explicitPublicState, maxChars: 240);
    }
    return '场景：${brief.sceneTitle}';
  }

  String _characterBriefing({
    required SceneBrief brief,
    required SceneDirectorOutput director,
    required ResolvedSceneCastMember member,
  }) {
    final explicitPrivate = _privateBriefing(brief, member.characterId);
    if (explicitPrivate != null && explicitPrivate.isNotEmpty) {
      return _compact(explicitPrivate, maxChars: 240);
    }
    final note = director.plan?.noteFor(member.characterId);
    final parts = <String>[
      if (member.role.trim().isNotEmpty) '身份=${member.role.trim()}',
      if (note != null && note.motivation.trim().isNotEmpty)
        '动机=${note.motivation.trim()}',
      if (note != null && note.emotionalArc.trim().isNotEmpty)
        '情绪=${note.emotionalArc.trim()}',
      if (note != null && note.keyAction.trim().isNotEmpty)
        '当前冲动=${note.keyAction.trim()}',
      if (partsForContributions(member).isNotEmpty)
        '参与=${partsForContributions(member)}',
    ];
    if (parts.isNotEmpty) {
      return parts.join('；');
    }
    return member.role.trim().isEmpty ? member.name : member.role.trim();
  }

  String? _privateBriefing(SceneBrief brief, String characterId) {
    final raw =
        brief.metadata['privateRoleBriefings'] ??
        brief.metadata['characterPrivateBriefings'];
    if (raw is Map) {
      return _metadataString(raw[characterId]);
    }
    return null;
  }

  String? _metadataString(Object? raw) {
    if (raw is String) {
      final trimmed = raw.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }

  int _roundCount({
    required SceneBrief brief,
    required SceneTaskCard? taskCard,
  }) {
    final raw =
        taskCard?.metadata['roleplayRounds'] ??
        brief.metadata['roleplayRounds'];
    final parsed = switch (raw) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value.trim()),
      _ => null,
    };
    return (parsed ?? defaultMaxRounds).clamp(2, 5).toInt();
  }

  List<String> _directorNoteLines({
    required SceneDirectorOutput director,
    required ResolvedSceneCastMember member,
  }) {
    final note = director.plan?.noteFor(member.characterId);
    return [
      if (note != null && note.motivation.trim().isNotEmpty)
        '角色动机：${note.motivation.trim()}',
      if (note != null && note.emotionalArc.trim().isNotEmpty)
        '情绪弧线：${note.emotionalArc.trim()}',
      if (note != null && note.keyAction.trim().isNotEmpty)
        '关键动作：${note.keyAction.trim()}',
    ];
  }

  List<String> _cognitionLines({
    required SceneTaskCard? taskCard,
    required ResolvedSceneCastMember member,
  }) {
    if (taskCard == null) return const <String>[];
    final beliefs = taskCard.beliefsFor(member.characterId);
    final relationships = taskCard.relationshipsFor(member.characterId);
    final socialPosition = taskCard.socialPositionFor(member.characterId);
    return [
      if (beliefs.isNotEmpty)
        '信念：${beliefs.map((belief) {
          final target = _memberName(taskCard, belief.targetId);
          return '$target/${belief.aspect}=${belief.value}';
        }).join('；')}',
      if (relationships.isNotEmpty)
        '关系：${relationships.map((relationship) {
          final a = _memberName(taskCard, relationship.characterA);
          final b = _memberName(taskCard, relationship.characterB);
          return '$a↔$b：${relationship.label}（张力${relationship.tension}/信任${relationship.trust}）';
        }).join('；')}',
      if (socialPosition != null)
        '社会地位：${socialPosition.role}/${socialPosition.formalRank}/影响力${socialPosition.actualInfluence}',
    ];
  }

  String _memberName(SceneTaskCard taskCard, String characterId) {
    for (final member in taskCard.cast) {
      if (member.characterId == characterId) return member.name;
    }
    return characterId;
  }

  String _publicTranscriptSection(List<SceneRoleplayTurn> transcript) {
    final recent = transcript.length <= 8
        ? transcript
        : transcript.sublist(transcript.length - 8);
    return '已发生：${recent.map(_publicTurnLine).join('；')}';
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

  String _visibleAction(SceneRoleplayTurn turn) {
    final parts = <String>[
      if (turn.visibleAction.trim().isNotEmpty) turn.visibleAction.trim(),
      if (turn.dialogue.trim().isNotEmpty) '说“${turn.dialogue.trim()}”',
    ];
    return parts.join('，');
  }

  String _contributionLabel(SceneCastContribution contribution) {
    return switch (contribution) {
      SceneCastContribution.action => '行动',
      SceneCastContribution.dialogue => '对白',
      SceneCastContribution.interaction => '互动',
    };
  }

  String partsForContributions(ResolvedSceneCastMember member) {
    if (member.contributions.isEmpty) return '';
    return member.contributions.map(_contributionLabel).join('/');
  }

  String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim() ?? '';
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }

  String _compact(String value, {required int maxChars}) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxChars) return normalized;
    return '${normalized.substring(0, maxChars - 3)}...';
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
