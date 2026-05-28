import '../domain/contracts/settings_contract.dart';

import 'character_memory_delta_models.dart';
import 'character_visible_context_builder.dart';
import 'role_skill_registry.dart';
import 'scene_arbiter_skill.dart';
import 'scene_pipeline_models.dart' show SceneTaskCard;
import 'scene_roleplay_session_models.dart';
import 'scene_roleplay_output_builder.dart';
import 'scene_roleplay_log_helpers.dart';
import 'scene_roleplay_speaker_boundary.dart';
import 'scene_roleplay_speaker_scheduler.dart';
import '../domain/contracts/event_log.dart';
import '../domain/contracts/stage_runner.dart';
import '../domain/scene_models.dart';

// Barrel exports — external consumers import only this file.
export 'scene_roleplay_speaker_boundary.dart';
export 'scene_roleplay_speaker_scheduler.dart';

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
    required StoryGenerationSettingsContract settingsStore,
    this.defaultMaxRounds = 1,
    PipelineEventLog? eventLog,
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
           speakerScheduler ?? const SceneRoleplaySpeakerScheduler(),
       _boundary = const SceneRoleplaySpeakerBoundary(),
       _eventLog = eventLog;

  final CharacterVisibleContextBuilder _visibleContextBuilder;
  final RoleSkillRegistry _roleSkillRegistry;
  final SceneArbiterSkill _arbiterSkill;
  final SceneRoleplaySpeakerScheduler _speakerScheduler;
  final SceneRoleplaySpeakerBoundary _boundary;
  final PipelineEventLog? _eventLog;
  final int defaultMaxRounds;

  Future<List<DynamicRoleAgentOutput>> run({
    required SceneBrief brief,
    required List<ResolvedSceneCastMember> cast,
    required SceneDirectorOutput director,
    SceneTaskCard? taskCard,
    String? ragContext,
    Map<String, List<CharacterMemoryDelta>> memoryDeltasByCharacter = const {},
  }) async {
    final result = await runSession(
      brief: brief,
      cast: cast,
      director: director,
      taskCard: taskCard,
      ragContext: ragContext,
      memoryDeltasByCharacter: memoryDeltasByCharacter,
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
        SceneRoleplayOutputBuilder.metadataInt(
          taskCard?.metadata['roleplayVisibleEventWindow'] ??
              brief.metadata['roleplayVisibleEventWindow'],
        ) ??
        _defaultVisibleTranscriptWindow;
    final parallelRoleplayTurns =
        SceneRoleplayOutputBuilder.metadataBool(
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
      _emitStatus(
        '${brief.chapterId}/${brief.sceneId}',
        'roleplay round $round',
      );
      final speakerPlan = _speakerScheduler.planRound(
        brief: brief,
        taskCard: taskCard,
        cast: cast,
        round: round,
        transcript: transcript,
      );
      _emitLog(SceneRoleplayLog.speakerScheduleLogLine(
        brief: brief,
        round: round,
        plan: speakerPlan,
        parallelTurns: parallelRoleplayTurns,
      ));

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
      _emitLog(SceneRoleplayLog.arbitrationLogLine(
        brief: brief,
        round: round,
        arbitration: arbitration,
        committedFactCount: committedFacts.length,
      ));
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
        _emitStatus(
          '${brief.chapterId}/${brief.sceneId}',
          'round $round 未产生新公开内容，提前结束',
        );
        break;
      }
    }

    _emitLog(SceneRoleplayLog.completeLogLine(
      brief: brief,
      rounds: rounds,
      committedFactCount: committedFacts.length,
      finalPublicState: sceneState,
    ));

    return SceneRoleplayRuntimeResult(
      outputs: [
        for (final member in cast)
          const SceneRoleplayOutputBuilder().build(
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

  // ---------------------------------------------------------------------------
  // Turn execution
  // ---------------------------------------------------------------------------

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
    return _boundary.apply(turn: turn, speaker: member, cast: cast);
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
        _emitStatus(
          '${brief.chapterId}/${brief.sceneId}',
          'roleplay-log actor-start | ${member.name}',
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
        _emitLog(SceneRoleplayLog.turnLogLine(
          brief: brief,
          round: round,
          turnOrder: turnOrder + 1,
          turn: turns[turnOrder],
        ));
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
      _emitStatus(
        '${brief.chapterId}/${brief.sceneId}',
        'roleplay-log actor-start | ${member.name}',
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
      _emitLog(SceneRoleplayLog.turnLogLine(
        brief: brief,
        round: round,
        turnOrder: turnOrder + 1,
        turn: turn,
      ));
      localTranscript.add(turn);
      turns.add(turn);
    }
    return turns;
  }

  // ---------------------------------------------------------------------------
  // Arbitration
  // ---------------------------------------------------------------------------

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
        contentHash: SceneRoleplayOutputBuilder.stableHash(hashInput),
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  void _emitStatus(String sceneId, String message) {
    _eventLog?.emit(PipelineEvent(
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      stageId: 'roleplay',
      eventType: 'status',
      metadata: {'sceneId': sceneId, 'message': message},
    ));
  }

  void _emitLog(String line) {
    _eventLog?.emit(PipelineEvent(
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      stageId: 'roleplay',
      eventType: 'log',
      metadata: {'line': line},
    ));
  }

  String _initialSceneState({
    required SceneBrief brief,
    required SceneDirectorOutput director,
  }) {
    final explicitPublicState =
        SceneRoleplayOutputBuilder.metadataString(brief.metadata['publicSceneState']) ??
        SceneRoleplayOutputBuilder.metadataString(brief.metadata['publicSceneSetup']) ??
        SceneRoleplayOutputBuilder.metadataString(brief.metadata['publicOpening']);
    if (explicitPublicState != null && explicitPublicState.isNotEmpty) {
      return SceneRoleplayOutputBuilder.compact(explicitPublicState, maxChars: 240);
    }
    return '场景：${brief.sceneTitle}';
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

  int _roundCount({
    required SceneBrief brief,
    required SceneTaskCard? taskCard,
  }) {
    final raw =
        taskCard?.metadata['roleplayRounds'] ??
        brief.metadata['roleplayRounds'];
    final parsed = SceneRoleplayOutputBuilder.metadataInt(raw);
    return (parsed ?? defaultMaxRounds).clamp(1, 5).toInt();
  }
}
