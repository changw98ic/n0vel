import 'package:novel_writer/app/state/app_settings_store.dart';

import 'character_memory_delta_models.dart';
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
  static const int _defaultVisibleTranscriptWindow = 1000;

  SceneRoleplayRuntime({
    required AppSettingsStore settingsStore,
    this.defaultMaxRounds = 1,
    CharacterVisibleContextBuilder? visibleContextBuilder,
    RoleSkillRegistry? roleSkillRegistry,
    SceneArbiterSkill? arbiterSkill,
    SceneRoleplaySpeakerScheduler? speakerScheduler,
  }) : _visibleContextBuilder =
           visibleContextBuilder ?? const CharacterVisibleContextBuilder(),
       _roleSkillRegistry =
           roleSkillRegistry ?? RoleSkillRegistry(settingsStore: settingsStore),
       _arbiterSkill =
           arbiterSkill ?? BasicSceneArbiterSkill(settingsStore: settingsStore),
       _speakerScheduler =
           speakerScheduler ?? const SceneRoleplaySpeakerScheduler();

  final CharacterVisibleContextBuilder _visibleContextBuilder;
  final RoleSkillRegistry _roleSkillRegistry;
  final SceneArbiterSkill _arbiterSkill;
  final SceneRoleplaySpeakerScheduler _speakerScheduler;
  final int defaultMaxRounds;

  Future<List<DynamicRoleAgentOutput>> run({
    required SceneBrief brief,
    required List<ResolvedSceneCastMember> cast,
    required SceneDirectorOutput director,
    SceneTaskCard? taskCard,
    String? ragContext,
    Map<String, List<CharacterMemoryDelta>> memoryDeltasByCharacter = const {},
    void Function(String message)? onStatus,
  }) async {
    final result = await runSession(
      brief: brief,
      cast: cast,
      director: director,
      taskCard: taskCard,
      ragContext: ragContext,
      memoryDeltasByCharacter: memoryDeltasByCharacter,
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
    Map<String, List<CharacterMemoryDelta>> memoryDeltasByCharacter = const {},
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
    final visibleTranscriptWindow =
        _metadataInt(
          taskCard?.metadata['roleplayVisibleEventWindow'] ??
              brief.metadata['roleplayVisibleEventWindow'],
        ) ??
        _defaultVisibleTranscriptWindow;
    final parallelRoleplayTurns =
        _metadataBool(
          taskCard?.metadata['parallelRoleplayTurns'] ??
              brief.metadata['parallelRoleplayTurns'],
        ) ??
        true;
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
      final speakerPlan = _speakerScheduler.planRound(
        brief: brief,
        taskCard: taskCard,
        cast: cast,
        round: round,
        transcript: transcript,
      );
      onStatus?.call(
        _roleplaySpeakerScheduleLogLine(
          brief: brief,
          round: round,
          plan: speakerPlan,
          parallelTurns: parallelRoleplayTurns,
        ),
      );

      final roundTurns = await _runRoundTurns(
        brief: brief,
        director: director,
        cast: cast,
        taskCard: taskCard,
        round: round,
        sceneState: sceneState,
        transcript: transcript,
        committedFacts: committedFacts,
        memoryDeltasByCharacter: memoryDeltasByCharacter,
        visibleTranscriptWindow: visibleTranscriptWindow,
        speakerPlan: speakerPlan,
        parallelTurns: parallelRoleplayTurns,
        onStatus: onStatus,
      );

      for (final turn in roundTurns) {
        transcript.add(turn);
        turnsByCharacter[turn.characterId]!.add(turn);
      }

      if (roundTurns.isEmpty) {
        break;
      }

      final arbitration = await _arbitrateRound(
        brief: brief,
        round: round,
        sceneState: sceneState,
        roundTurns: roundTurns,
        transcript: _trimTranscript(
          transcript: transcript,
          maxTurns: visibleTranscriptWindow,
        ),
      );
      sceneState = arbitration.nextPublicState;
      committedFacts.addAll(
        _commitArbitrationFacts(
          arbitration,
          round: round,
          existingFacts: committedFacts,
        ),
      );
      onStatus?.call(
        _roleplayArbitrationLogLine(
          brief: brief,
          round: round,
          arbitration: arbitration,
          committedFactCount: committedFacts.length,
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
      if (round < maxRounds &&
          !_hasPublicProgress(
            roundTurns: roundTurns,
            arbitrationFact: arbitration.fact,
          )) {
        onStatus?.call(
          '场景 ${brief.chapterId}/${brief.sceneId} · round $round '
          '未产生新公开内容，提前结束',
        );
        break;
      }
    }

    onStatus?.call(
      _roleplayCompleteLogLine(
        brief: brief,
        rounds: rounds,
        committedFactCount: committedFacts.length,
        finalPublicState: sceneState,
      ),
    );

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

  String _roleplayTurnLogLine({
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
      '意图=${_compactLogValue(turn.intent)}',
      '公开动作=${_compactLogValue(turn.visibleAction)}',
      '对白=${_compactLogValue(turn.dialogue)}',
      '内心=${_compactLogValue(turn.innerState)}',
      if (turn.proseFragment.trim().isNotEmpty)
        '正文片段=${_compactLogValue(turn.proseFragment)}',
      if (turn.proposedMemoryDeltas.isNotEmpty)
        '记忆提案=${turn.proposedMemoryDeltas.length}',
    ];
    return parts.join(' | ');
  }

  String _roleplaySpeakerScheduleLogLine({
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

  String _roleplayArbitrationLogLine({
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
      '事实=${_compactLogValue(arbitration.fact)}',
      '局面=${_compactLogValue(arbitration.nextPublicState)}',
      '压力=${_compactLogValue(arbitration.pressure)}',
      'stop=${arbitration.shouldStop}',
      'acceptedMemory=${arbitration.acceptedMemoryDeltas.length}',
      'rejectedMemory=${arbitration.rejectedMemoryDeltas.length}',
      'committedFacts=$committedFactCount',
    ];
    return parts.join(' | ');
  }

  String _roleplayCompleteLogLine({
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
      '最终局面=${_compactLogValue(finalPublicState, maxChars: 160)}',
    ].join(' | ');
  }

  String _compactLogValue(String value, {int maxChars = 96}) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return '-';
    if (normalized.length <= maxChars) return normalized;
    return '${normalized.substring(0, maxChars - 3)}...';
  }

  Future<SceneRoleplayTurn> _runCharacterTurn({
    required SceneBrief brief,
    required SceneDirectorOutput director,
    required ResolvedSceneCastMember member,
    required List<ResolvedSceneCastMember> cast,
    required int round,
    required String sceneState,
    required List<SceneRoleplayTurn> transcript,
    required List<SceneRoleplayCommittedFact> committedFacts,
    required List<CharacterMemoryDelta> memoryDeltas,
    SceneTaskCard? taskCard,
  }) async {
    final visibleContext = _visibleContextBuilder.build(
      brief: brief,
      member: member,
      director: director,
      publicSceneState: sceneState,
      transcript: transcript,
      committedFacts: committedFacts,
      memoryDeltas: memoryDeltas,
      taskCard: taskCard,
    );
    final skill = _roleSkillRegistry.resolve(
      member: member,
      metadata: brief.metadata,
    );
    final turn = await skill.runTurn(context: visibleContext, round: round);
    return _applySpeakerBoundary(turn: turn, speaker: member, cast: cast);
  }

  Future<List<SceneRoleplayTurn>> _runRoundTurns({
    required SceneBrief brief,
    required SceneDirectorOutput director,
    required List<ResolvedSceneCastMember> cast,
    required int round,
    required String sceneState,
    required List<SceneRoleplayTurn> transcript,
    required List<SceneRoleplayCommittedFact> committedFacts,
    required Map<String, List<CharacterMemoryDelta>> memoryDeltasByCharacter,
    required int visibleTranscriptWindow,
    required SceneRoleplaySpeakerPlan speakerPlan,
    required bool parallelTurns,
    SceneTaskCard? taskCard,
    void Function(String message)? onStatus,
  }) async {
    if (parallelTurns) {
      final visibleTranscript = List<SceneRoleplayTurn>.unmodifiable(
        _trimTranscript(
          transcript: transcript,
          maxTurns: visibleTranscriptWindow,
        ),
      );
      final factSnapshot = List<SceneRoleplayCommittedFact>.unmodifiable(
        committedFacts,
      );
      final futures = <Future<SceneRoleplayTurn>>[];
      for (final member in speakerPlan.speakers) {
        onStatus?.call(
          '场景 ${brief.chapterId}/${brief.sceneId} · roleplay-log actor-start | ${member.name}',
        );
        futures.add(
          _runCharacterTurn(
            brief: brief,
            director: director,
            member: member,
            cast: cast,
            taskCard: taskCard,
            round: round,
            sceneState: sceneState,
            transcript: visibleTranscript,
            committedFacts: factSnapshot,
            memoryDeltas:
                memoryDeltasByCharacter[member.characterId] ??
                const <CharacterMemoryDelta>[],
          ),
        );
      }
      final turns = await Future.wait(futures);
      for (var turnOrder = 0; turnOrder < turns.length; turnOrder += 1) {
        onStatus?.call(
          _roleplayTurnLogLine(
            brief: brief,
            round: round,
            turnOrder: turnOrder + 1,
            turn: turns[turnOrder],
          ),
        );
      }
      return turns;
    }

    final localTranscript = List<SceneRoleplayTurn>.of(transcript);
    final turns = <SceneRoleplayTurn>[];
    for (
      var turnOrder = 0;
      turnOrder < speakerPlan.speakers.length;
      turnOrder += 1
    ) {
      final member = speakerPlan.speakers[turnOrder];
      onStatus?.call(
        '场景 ${brief.chapterId}/${brief.sceneId} · roleplay-log actor-start | ${member.name}',
      );
      final turn = await _runCharacterTurn(
        brief: brief,
        director: director,
        member: member,
        cast: cast,
        taskCard: taskCard,
        round: round,
        sceneState: sceneState,
        transcript: _trimTranscript(
          transcript: localTranscript,
          maxTurns: visibleTranscriptWindow,
        ),
        committedFacts: committedFacts,
        memoryDeltas:
            memoryDeltasByCharacter[member.characterId] ??
            const <CharacterMemoryDelta>[],
      );
      onStatus?.call(
        _roleplayTurnLogLine(
          brief: brief,
          round: round,
          turnOrder: turnOrder + 1,
          turn: turn,
        ),
      );
      localTranscript.add(turn);
      turns.add(turn);
    }
    return turns;
  }

  SceneRoleplayTurn _applySpeakerBoundary({
    required SceneRoleplayTurn turn,
    required ResolvedSceneCastMember speaker,
    required List<ResolvedSceneCastMember> cast,
  }) {
    final otherNames = [
      for (final member in cast)
        if (member.characterId != speaker.characterId) member.name,
    ];
    final intent = _speakerBoundedField(
      turn.intent,
      speakerName: speaker.name,
      otherNames: otherNames,
    );
    final visibleAction = _speakerBoundedField(
      turn.visibleAction,
      speakerName: speaker.name,
      otherNames: otherNames,
    );
    final dialogue = _speakerBoundedField(
      turn.dialogue,
      speakerName: speaker.name,
      otherNames: otherNames,
    );
    final innerState = _speakerBoundedField(
      turn.innerState,
      speakerName: speaker.name,
      otherNames: otherNames,
    );
    final taboo = _speakerBoundedField(
      turn.taboo,
      speakerName: speaker.name,
      otherNames: otherNames,
    );
    final proseFragment = _speakerBoundedField(
      turn.proseFragment,
      speakerName: speaker.name,
      otherNames: otherNames,
    );
    final proposedMemoryDeltas = _speakerBoundedMemoryDeltas(
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

  List<CharacterMemoryDelta> _speakerBoundedMemoryDeltas(
    List<CharacterMemoryDelta> deltas, {
    required String speakerName,
    required List<String> otherNames,
  }) {
    var changed = false;
    final bounded = <CharacterMemoryDelta>[];
    for (final delta in deltas) {
      final content = _speakerBoundedField(
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

  String _speakerBoundedField(
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
        if (turns.map((t) => t.proseFragment).any((v) => v.trim().isNotEmpty))
          '正文片段：${turns.map((t) => t.proseFragment.trim()).where((v) => v.isNotEmpty).join('\n\n')}',
        if (process.isNotEmpty) '过程：$process',
        '局面：${_compact(sceneState, maxChars: 120)}',
      ].join('\n'),
    );
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

  String? _metadataString(Object? raw) {
    if (raw is String) {
      final trimmed = raw.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }

  List<SceneRoleplayTurn> _trimTranscript({
    required List<SceneRoleplayTurn> transcript,
    required int maxTurns,
  }) {
    if (maxTurns <= 0 || transcript.length <= maxTurns) {
      return transcript;
    }
    return transcript.sublist(transcript.length - maxTurns);
  }

  bool _hasPublicProgress({
    required List<SceneRoleplayTurn> roundTurns,
    required String arbitrationFact,
  }) {
    if (arbitrationFact.trim().isNotEmpty) {
      return true;
    }
    return roundTurns.any(
      (turn) =>
          turn.visibleAction.trim().isNotEmpty ||
          turn.dialogue.trim().isNotEmpty,
    );
  }

  int? _metadataInt(Object? raw) {
    return switch (raw) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value.trim()),
      _ => null,
    };
  }

  bool? _metadataBool(Object? raw) {
    if (raw is bool) {
      return raw;
    }
    if (raw is int) {
      return raw != 0;
    }
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      return switch (normalized) {
        '1' => true,
        'true' => true,
        'yes' => true,
        'on' => true,
        '0' => false,
        'false' => false,
        'no' => false,
        'off' => false,
        _ => null,
      };
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
    return (parsed ?? defaultMaxRounds).clamp(1, 5).toInt();
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

class SceneRoleplaySpeakerPlan {
  SceneRoleplaySpeakerPlan({
    required this.strategy,
    required List<ResolvedSceneCastMember> speakers,
  }) : speakers = List.unmodifiable(speakers);

  final String strategy;
  final List<ResolvedSceneCastMember> speakers;
}

class SceneRoleplaySpeakerScheduler {
  const SceneRoleplaySpeakerScheduler();

  SceneRoleplaySpeakerPlan planRound({
    required SceneBrief brief,
    required SceneTaskCard? taskCard,
    required List<ResolvedSceneCastMember> cast,
    required int round,
    required List<SceneRoleplayTurn> transcript,
  }) {
    final metadata = _mergedMetadata(brief: brief, taskCard: taskCard);
    final strategy =
        (_metadataString(metadata['roleplaySpeakerStrategy']) ??
                _metadataString(metadata['groupReplyStrategy']) ??
                'list')
            .toLowerCase()
            .replaceAll(RegExp(r'[\s_-]+'), '');
    final muted = _stringSet(
      metadata['roleplayMutedCharacterIds'] ??
          metadata['mutedRoleIds'] ??
          metadata['disabledRoleIds'],
    );
    final maxSpeakers = _metadataInt(metadata['roleplayMaxSpeakersPerRound']);
    final enabled = [
      for (final member in cast)
        if (!muted.contains(member.characterId) && !muted.contains(member.name))
          member,
    ];
    final explicitlyOrdered = _applyExplicitOrder(
      enabled,
      metadata['roleplaySpeakerOrder'] ?? metadata['speakerOrder'],
    );
    final scheduled = switch (strategy) {
      'pooled' => _pooledOrder(explicitlyOrdered, transcript),
      'single' => explicitlyOrdered.take(1).toList(),
      'manual' => explicitlyOrdered.take(1).toList(),
      'naturalorder' => explicitlyOrdered,
      'listorder' => explicitlyOrdered,
      _ => explicitlyOrdered,
    };
    final limited = maxSpeakers == null || maxSpeakers <= 0
        ? scheduled
        : scheduled.take(maxSpeakers).toList();
    return SceneRoleplaySpeakerPlan(strategy: strategy, speakers: limited);
  }

  Map<String, Object?> _mergedMetadata({
    required SceneBrief brief,
    required SceneTaskCard? taskCard,
  }) {
    return <String, Object?>{
      ...brief.metadata,
      if (taskCard != null) ...taskCard.metadata,
    };
  }

  List<ResolvedSceneCastMember> _applyExplicitOrder(
    List<ResolvedSceneCastMember> cast,
    Object? rawOrder,
  ) {
    final order = _stringList(rawOrder);
    if (order.isEmpty) return cast;
    final remaining = [...cast];
    final ordered = <ResolvedSceneCastMember>[];
    for (final key in order) {
      final index = remaining.indexWhere(
        (member) => member.characterId == key || member.name == key,
      );
      if (index < 0) continue;
      ordered.add(remaining.removeAt(index));
    }
    ordered.addAll(remaining);
    return ordered;
  }

  List<ResolvedSceneCastMember> _pooledOrder(
    List<ResolvedSceneCastMember> cast,
    List<SceneRoleplayTurn> transcript,
  ) {
    if (cast.isEmpty) return const <ResolvedSceneCastMember>[];
    final turnCounts = <String, int>{
      for (final member in cast) member.characterId: 0,
    };
    for (final turn in transcript) {
      if (turnCounts.containsKey(turn.characterId)) {
        turnCounts[turn.characterId] = turnCounts[turn.characterId]! + 1;
      }
    }
    final leastTurns = turnCounts.values.fold<int?>(
      null,
      (least, value) => least == null || value < least ? value : least,
    );
    return [
      for (final member in cast)
        if (turnCounts[member.characterId] == leastTurns) member,
    ].take(1).toList();
  }

  String? _metadataString(Object? raw) {
    if (raw is String) {
      final trimmed = raw.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }

  int? _metadataInt(Object? raw) {
    return switch (raw) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value.trim()),
      _ => null,
    };
  }

  Set<String> _stringSet(Object? raw) => _stringList(raw).toSet();

  List<String> _stringList(Object? raw) {
    if (raw is String) {
      return raw
          .split(RegExp(r'[,，\n]'))
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
    }
    if (raw is List) {
      return [
        for (final value in raw)
          if (value is String && value.trim().isNotEmpty) value.trim(),
      ];
    }
    return const <String>[];
  }
}
