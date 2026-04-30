import 'package:novel_writer/app/state/app_settings_store.dart';

import 'retrieval_controller.dart';
import 'scene_cast_resolver.dart';
import 'scene_director_orchestrator.dart';
import 'scene_editorial_generator.dart';
import 'scene_polish_pass.dart';
import 'scene_pipeline_models.dart';
import 'scene_review_coordinator.dart';
import 'scene_state_resolver.dart';
import 'story_generation_models.dart';
import 'dynamic_role_agent_runner.dart';

// ---------------------------------------------------------------------------
// Replan routing (Task 11)
// ---------------------------------------------------------------------------

/// Deterministic route after a scene review decision.
enum ReplanRoute {
  /// Scene passed review — accept as final.
  pass,

  /// Rewrite prose only (no structural replan needed).
  rewrite,

  /// Route back to scene planning with incremented round counter.
  replan,

  /// Max replan rounds exhausted — unrecoverable.
  blocked,
}

/// Outcome of a replan routing decision, carrying the resolved route,
/// a human-readable message, and the updated [DirectorRoundState].
class ReplanOutcome {
  const ReplanOutcome({
    required this.route,
    required this.message,
    required this.updatedRoundState,
  });

  final ReplanRoute route;
  final String message;
  final DirectorRoundState updatedRoundState;
}

/// Pure-function router that maps a [SceneReviewDecision] + current round
/// state into a deterministic [ReplanOutcome].
///
/// No side effects. All replan boundary logic lives here so callers only
/// need to switch on the route.
class ReplanRouter {
  static const int defaultMaxRetries = 3;

  /// Resolve the next action for a scene after review.
  ///
  /// [decision] — the review verdict.
  /// [currentRoundState] — tracks round / maxRounds for the current scene.
  static ReplanOutcome resolve({
    required SceneReviewDecision decision,
    required DirectorRoundState currentRoundState,
    int? maxRetries,
  }) {
    final max = maxRetries ?? defaultMaxRetries;

    switch (decision) {
      case SceneReviewDecision.pass:
        return ReplanOutcome(
          route: ReplanRoute.pass,
          message: 'Scene passed review.',
          updatedRoundState: currentRoundState,
        );

      case SceneReviewDecision.rewriteProse:
        return ReplanOutcome(
          route: ReplanRoute.rewrite,
          message: 'Scene needs prose rewrite.',
          updatedRoundState: currentRoundState,
        );

      case SceneReviewDecision.replanScene:
        final nextRound = currentRoundState.round + 1;
        final exhausted = nextRound > max;

        final updated = currentRoundState.copyWith(
          round: nextRound,
          maxRounds: max,
          outcome: exhausted ? 'blocked' : 'replan',
        );

        if (exhausted) {
          return ReplanOutcome(
            route: ReplanRoute.blocked,
            message:
                'Scene blocked after $max replan rounds: '
                '${currentRoundState.sceneId}. '
                'Review feedback could not be satisfied within budget.',
            updatedRoundState: updated,
          );
        }

        return ReplanOutcome(
          route: ReplanRoute.replan,
          message: 'Replanning scene (round $nextRound/$max).',
          updatedRoundState: updated,
        );
    }
  }
}

/// Orchestrates the new scene pipeline:
///
/// 1. Build [SceneTaskCard] from brief + resolved cast + director plan
/// 2. Run role agents → [RolePlayTurnOutput]s (with retrieval intents)
/// 3. Controller resolves retrieval intents → [ContextCapsule]s
/// 4. Resolver turns role turns + capsules → [SceneBeat]s
/// 5. Editorial generator stitches beats → [SceneEditorialDraft]
/// 6. Review loop on editorial draft (same review coordinator)
class ScenePipelineOrchestrator {
  ScenePipelineOrchestrator({
    required AppSettingsStore settingsStore,
    this.maxProseRetries = 1,
    this.maxReplanRetries = ReplanRouter.defaultMaxRetries,
    this.onStatus,
    SceneCastResolver? castResolver,
    SceneDirectorOrchestrator? directorOrchestrator,
    DynamicRoleAgentRunner? dynamicRoleAgentRunner,
    SceneStateResolver? stateResolver,
    SceneEditorialGenerator? editorialGenerator,
    SceneReviewCoordinator? reviewCoordinator,
    ScenePolishPass? polishPass,
    RetrievalController? retrievalController,
    RoleplaySessionStore? roleplaySessionStore,
    CharacterMemoryStore? characterMemoryStore,
  }) : _castResolver = castResolver ?? SceneCastResolver(),
       _directorOrchestrator =
           directorOrchestrator ??
           SceneDirectorOrchestrator(settingsStore: settingsStore),
       _dynamicRoleAgentRunner =
           dynamicRoleAgentRunner ??
           DynamicRoleAgentRunner(settingsStore: settingsStore),
       _stateResolver =
           stateResolver ?? SceneStateResolver(settingsStore: settingsStore),
       _editorialGenerator =
           editorialGenerator ??
           SceneEditorialGenerator(settingsStore: settingsStore),
       _reviewCoordinator =
           reviewCoordinator ??
           SceneReviewCoordinator(settingsStore: settingsStore),
       _polishPass =
           polishPass ?? ScenePolishPass(settingsStore: settingsStore),
       _retrievalController =
           retrievalController ?? const RetrievalController(),
       _roleplaySessionStore = roleplaySessionStore,
       _characterMemoryStore = characterMemoryStore;

  final int maxProseRetries;
  final int maxReplanRetries;
  final void Function(String message)? onStatus;
  final SceneCastResolver _castResolver;
  final SceneDirectorOrchestrator _directorOrchestrator;
  final DynamicRoleAgentRunner _dynamicRoleAgentRunner;
  final SceneStateResolver _stateResolver;
  final SceneEditorialGenerator _editorialGenerator;
  final SceneReviewCoordinator _reviewCoordinator;
  final ScenePolishPass _polishPass;
  final RetrievalController _retrievalController;
  final RoleplaySessionStore? _roleplaySessionStore;
  final CharacterMemoryStore? _characterMemoryStore;
  DirectorMemory _directorMemory = DirectorMemory();

  /// Run the full pipeline for a single scene.
  Future<ScenePipelineOutput> runScene(
    SceneBrief brief, {
    List<CharacterBelief> beliefs = const [],
    List<RelationshipSlice> relationships = const [],
    List<SocialPositionSlice> socialPositions = const [],
    List<KnowledgeAtom> knowledge = const [],
    void Function(String message)? onStatus,
  }) async {
    final statusCallback = onStatus ?? this.onStatus;
    _directorMemory = _directorMemory.withActiveRoundState(
      DirectorRoundState(sceneId: brief.sceneId, maxRounds: maxReplanRetries),
    );

    // 1. Resolve cast
    final resolvedCast = _castResolver.resolve(brief);

    // 2. Director plan
    statusCallback?.call('场景 ${brief.chapterId}/${brief.sceneId} · director');
    final directorContext = _directorMemory.toPromptText();
    final director = await _directorOrchestrator.run(
      brief: brief,
      cast: resolvedCast,
      ragContext: directorContext.isEmpty ? null : directorContext,
    );

    // 3. Build task card
    final taskCard = SceneTaskCard(
      brief: brief,
      cast: resolvedCast,
      directorPlan: director.text,
      directorPlanParsed: director.plan,
      beliefs: beliefs,
      relationships: relationships,
      socialPositions: socialPositions,
      knowledge: knowledge,
      metadata: brief.metadata,
    );

    // 4. Run role agents (existing runner, convert outputs)
    statusCallback?.call(
      '场景 ${brief.chapterId}/${brief.sceneId} · role agents',
    );
    final rawRoleOutputs = await _dynamicRoleAgentRunner.run(
      brief: brief,
      cast: resolvedCast,
      director: director,
      taskCard: taskCard,
      onStatus: statusCallback,
    );
    final roleplaySession = _dynamicRoleAgentRunner.lastRoleplaySession;
    await _persistRoleplaySession(
      projectId: brief.projectId ?? brief.chapterId,
      brief: brief,
      session: roleplaySession,
    );

    final roleTurns = [
      for (final raw in rawRoleOutputs)
        RolePlayTurnOutput.fromDynamicAgentOutput(raw),
    ];

    // 5. Retrieval: resolve intents into capsules
    final capsules = _retrievalController.resolve(
      taskCard: taskCard,
      turns: roleTurns,
    );

    // 6. Resolve beats
    final resolvedBeats = await _stateResolver.resolve(
      taskCard: taskCard,
      roleTurns: roleTurns,
      capsules: capsules,
      onStatus: statusCallback,
    );

    // 7. Editorial + review loop (with replan routing)
    var attempt = 1;
    var softFailureCount = 0;
    String? reviewFeedback;
    var roundState = DirectorRoundState(
      sceneId: brief.sceneId,
      maxRounds: maxReplanRetries,
    );

    while (true) {
      statusCallback?.call(
        '场景 ${brief.chapterId}/${brief.sceneId} · editorial attempt $attempt',
      );

      final editorialDraft = await _editorialGenerator.generate(
        taskCard: taskCard,
        resolvedBeats: resolvedBeats,
        capsules: capsules,
        attempt: attempt,
        roleplaySession: roleplaySession,
        reviewFeedback: reviewFeedback,
      );

      // Wrap as SceneProseDraft for review coordinator compatibility
      final proseDraft = SceneProseDraft(
        text: editorialDraft.text,
        attempt: editorialDraft.attempt,
      );

      final review = await _reviewCoordinator.review(
        brief: brief,
        director: director,
        roleOutputs: rawRoleOutputs,
        prose: proseDraft,
        roleplaySession: roleplaySession,
        onStatus: statusCallback,
      );
      _directorMemory = _directorMemory
          .incorporate(
            SceneReviewDigest(
              sceneId: brief.sceneId,
              decision: review.decision,
              issues: review.extractIssues(),
              strengths: review.extractStrengths(),
              proseAttempts: attempt,
            ),
          )
          .withActiveRoundState(roundState);

      final replanOutcome = ReplanRouter.resolve(
        decision: review.decision,
        currentRoundState: roundState,
        maxRetries: maxReplanRetries,
      );
      roundState = replanOutcome.updatedRoundState;
      _directorMemory = _directorMemory.withActiveRoundState(roundState);

      switch (replanOutcome.route) {
        case ReplanRoute.pass:
          return ScenePipelineOutput(
            taskCard: taskCard,
            roleTurns: roleTurns,
            capsules: capsules,
            resolvedBeats: resolvedBeats,
            editorialDraft: editorialDraft,
            review: review,
            proseAttempts: attempt,
            softFailureCount: softFailureCount,
          );

        case ReplanRoute.rewrite:
          softFailureCount += 1;
          if (softFailureCount <= maxProseRetries) {
            attempt += 1;
            reviewFeedback = review.editorialFeedback;
            continue;
          }
          final polishedDraftForRetry = await _refineDraftIfNeeded(
            brief: brief,
            draft: editorialDraft,
            resolvedBeats: resolvedBeats,
            review: review,
          );
          // Prose retries exhausted — return as-is
          return ScenePipelineOutput(
            taskCard: taskCard,
            roleTurns: roleTurns,
            capsules: capsules,
            resolvedBeats: resolvedBeats,
            editorialDraft: polishedDraftForRetry,
            review: review,
            proseAttempts: attempt,
            softFailureCount: softFailureCount,
          );

        case ReplanRoute.replan:
          statusCallback?.call(replanOutcome.message);
          final polishedDraftForRetry = await _refineDraftIfNeeded(
            brief: brief,
            draft: editorialDraft,
            resolvedBeats: resolvedBeats,
            review: review,
          );
          return ScenePipelineOutput(
            taskCard: taskCard,
            roleTurns: roleTurns,
            capsules: capsules,
            resolvedBeats: resolvedBeats,
            editorialDraft: polishedDraftForRetry,
            review: review,
            proseAttempts: attempt,
            softFailureCount: softFailureCount,
          );

        case ReplanRoute.blocked:
          statusCallback?.call(replanOutcome.message);
          final polishedDraftForRetry = await _refineDraftIfNeeded(
            brief: brief,
            draft: editorialDraft,
            resolvedBeats: resolvedBeats,
            review: review,
          );
          return ScenePipelineOutput(
            taskCard: taskCard,
            roleTurns: roleTurns,
            capsules: capsules,
            resolvedBeats: resolvedBeats,
            editorialDraft: polishedDraftForRetry,
            review: review,
            proseAttempts: attempt,
            softFailureCount: softFailureCount,
          );
      }
    }
  }

  Future<SceneEditorialDraft> _refineDraftIfNeeded({
    required SceneBrief brief,
    required SceneEditorialDraft draft,
    required List<SceneBeat> resolvedBeats,
    required SceneReviewResult review,
  }) async {
    if (review.decision != SceneReviewDecision.rewriteProse) {
      return draft;
    }
    final polishResult = await _polishPass.polish(
      brief: brief,
      editorialDraft: draft,
      resolvedBeats: resolvedBeats,
      reviewFeedback: review.editorialFeedback,
      refinementGuidance:
          review.refinementGuidance ?? review.synthesizeGuidance(),
    );
    if (polishResult.text.trim().isEmpty) {
      return draft;
    }
    return SceneEditorialDraft(
      text: polishResult.text,
      beatCount: draft.beatCount,
      attempt: draft.attempt,
    );
  }

  Future<void> _persistRoleplaySession({
    required String projectId,
    required SceneBrief brief,
    required SceneRoleplaySession? session,
  }) async {
    if (session == null || session.isEmpty) {
      return;
    }
    await _roleplaySessionStore?.saveSession(
      projectId: projectId,
      session: session,
    );
    final acceptedDeltas = session.acceptedMemoryDeltas
        .where((delta) => delta.accepted)
        .toList(growable: false);
    if (acceptedDeltas.isEmpty) {
      return;
    }
    await _characterMemoryStore?.saveAcceptedDeltas(
      projectId: projectId,
      chapterId: brief.chapterId,
      sceneId: brief.sceneId,
      deltas: acceptedDeltas,
    );
  }
}
