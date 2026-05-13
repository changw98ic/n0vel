import '../scene_pipeline_models.dart' as pipeline
    show SceneBeat, SceneBeatKind, LightContextCapsule;
import '../scene_runtime_models.dart'
    show ResolvedBeat, SceneBrief, SceneState, SceneStateDelta, SceneStateDeltaKind;
import '../scene_state_resolver.dart' show SceneStateResolver;
import '../step_io.dart';

/// Step 5: resolve beats, convert to runtime beats, build scene state.
class BeatResolutionStep {
  BeatResolutionStep({required SceneStateResolver stateResolver})
      : _stateResolver = stateResolver;

  final SceneStateResolver _stateResolver;

  Future<BeatResolutionOutput> execute(
    BeatResolutionInput input, {
    void Function(String)? onStatus,
  }) async {
    final sceneCapsules = <pipeline.LightContextCapsule>[
      ...input.stage.capsules,
      if (input.stage.stageCapsule != null) input.stage.stageCapsule!,
    ];

    final resolvedBeats = await _stateResolver.resolve(
      taskCard: input.plan.taskCard,
      roleTurns: input.roleplay.roleTurns,
      capsules: sceneCapsules,
      roleplaySession: input.roleplay.session,
      onStatus: onStatus,
    );

    final runtimeBeats = _runtimeBeatsFromResolved(resolvedBeats);
    final sceneState = _sceneStateFromRuntimeBeats(
      brief: input.brief,
      runtimeBeats: runtimeBeats,
    );

    return BeatResolutionOutput(
      resolvedBeats: resolvedBeats,
      runtimeBeats: runtimeBeats,
      sceneState: sceneState,
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers (faithfully extracted from ChapterGenerationOrchestrator)
  // ---------------------------------------------------------------------------

  List<ResolvedBeat> _runtimeBeatsFromResolved(
    List<pipeline.SceneBeat> resolvedBeats,
  ) {
    return [
      for (var i = 0; i < resolvedBeats.length; i++)
        _runtimeBeatFromResolved(resolvedBeats[i], i),
    ];
  }

  ResolvedBeat _runtimeBeatFromResolved(
      pipeline.SceneBeat beat, int index) {
    final typedDeltas = _stateDeltasFromText(beat.content);
    return ResolvedBeat(
      beatIndex: index,
      actorId: beat.sourceCharacterId,
      actionAccepted: true,
      acceptedSpeech:
          beat.kind == pipeline.SceneBeatKind.dialogue ? beat.content : '',
      acceptedAction:
          beat.kind == pipeline.SceneBeatKind.dialogue ? '' : beat.content,
      typedStateDeltas: typedDeltas,
      stateDelta: [for (final delta in typedDeltas) delta.value],
      newPublicFacts: beat.kind == pipeline.SceneBeatKind.fact
          ? [beat.content]
          : const [],
    );
  }

  SceneState _sceneStateFromRuntimeBeats({
    required SceneBrief brief,
    required List<ResolvedBeat> runtimeBeats,
  }) {
    final acceptedChanges = <String>[];
    final acceptedDeltas = <SceneStateDelta>[];
    final seen = <String>{};
    for (final beat in runtimeBeats) {
      for (final delta in beat.typedStateDeltas) {
        final key = '${delta.kind.name}:${delta.value}';
        if (seen.add(key)) {
          acceptedDeltas.add(delta);
          acceptedChanges.add(delta.value);
        }
      }
    }
    for (final delta in _narrativeDeltasFromBrief(brief)) {
      final key = '${delta.kind.name}:${delta.value}';
      if (seen.add(key)) {
        acceptedDeltas.add(delta);
        acceptedChanges.add(delta.value);
      }
    }
    return SceneState(
      sceneId: brief.sceneId,
      beatIndex: runtimeBeats.length,
      acceptedStateChanges: acceptedChanges,
      acceptedStateDeltas: acceptedDeltas,
      lastResolvedBeat: runtimeBeats.isEmpty ? null : runtimeBeats.last,
    );
  }

  List<SceneStateDelta> _narrativeDeltasFromBrief(SceneBrief brief) {
    final deltas = <SceneStateDelta>[];
    for (final value in [brief.targetBeat, brief.sceneSummary]) {
      deltas.addAll(_stateDeltasFromText(value));
    }
    return deltas;
  }

  List<SceneStateDelta> _stateDeltasFromText(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return const [];
    }
    final delta = SceneStateDelta.inferKind(trimmed);
    if (delta.kind == SceneStateDeltaKind.generic) {
      return const [];
    }
    return [delta];
  }
}
