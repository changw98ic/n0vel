import '../domain/literary_quality_models.dart';
import 'scene_pipeline_models.dart' as pipeline;
import 'scene_runtime_models.dart' as runtime;

/// One-way adapters from existing scene planning objects into the WP1
/// literary-quality contracts.
///
/// These adapters intentionally do not read `metadata`. Canonical parent
/// hashes, source-ledger hashes, POV policy, reader intent, and repair budgets
/// must be supplied by the caller so a fixture, outline merge, or generic
/// metadata field cannot silently become a quality-contract source of truth.
SceneNarrativeContract sceneNarrativeContractFromBrief(
  runtime.SceneBrief brief, {
  int schemaVersion = 1,
  required String sceneContractId,
  int revision = 1,
  required String projectCharterHash,
  required String arcContractHash,
  required String previousAcceptedSceneContractHash,
  required String corePromiseId,
  required String phaseGoalId,
  required String sceneContribution,
  required PovPolicy povPolicy,
  List<String> worldRuleRefs = const [],
  List<String> requiredFactRefs = const [],
  List<String> forbiddenContradictions = const [],
  List<String> activePromiseIds = const [],
  List<String> payoffWindowIds = const [],
  List<String> requiredStateChangeTypes = const [],
  List<String>? castIds,
  required String sourceLedgerHash,
  required int repairBudget,
  required int replanBudget,
}) {
  return SceneNarrativeContract.create(
    schemaVersion: schemaVersion,
    sceneContractId: sceneContractId,
    revision: revision,
    projectCharterHash: projectCharterHash,
    arcContractHash: arcContractHash,
    previousAcceptedSceneContractHash: previousAcceptedSceneContractHash,
    corePromiseId: corePromiseId,
    phaseGoalId: phaseGoalId,
    chapterId: brief.chapterId,
    sceneId: brief.sceneId,
    sceneIndex: brief.sceneIndex,
    sceneContribution: sceneContribution,
    povPolicy: povPolicy,
    worldRuleRefs: worldRuleRefs,
    requiredFactRefs: requiredFactRefs,
    forbiddenContradictions: forbiddenContradictions,
    activePromiseIds: activePromiseIds,
    payoffWindowIds: payoffWindowIds,
    requiredStateChangeTypes: requiredStateChangeTypes,
    castIds: castIds ?? _runtimeCastIds(brief),
    sourceLedgerHash: sourceLedgerHash,
    repairBudget: repairBudget,
    replanBudget: replanBudget,
  );
}

SceneCraftContract sceneCraftContractFromDirectorTaskCard(
  runtime.SceneTaskCard taskCard, {
  int schemaVersion = 1,
  required String craftId,
  required String sceneContractId,
  required String sceneContractHash,
  required String voiceProfileId,
  required String voiceProfileHash,
  int revision = 1,
  required SceneFunction primaryFunction,
  List<SceneFunction> secondaryFunctions = const [],
  List<String> plannedBeats = const [],
  List<StateChangeTarget> desiredStateChanges = const [],
  required String readerQuestionBefore,
  required String readerQuestionAfterTarget,
  required PressureCurve pressureCurve,
  required RhythmIntent rhythmIntent,
  List<String> invariantsToPreserve = const [],
  List<AllowedDeviation> allowedDeviations = const [],
  required int targetedRepairBudget,
  required int fullRewriteBudget,
}) {
  return SceneCraftContract.create(
    schemaVersion: schemaVersion,
    craftId: craftId,
    sceneContractId: sceneContractId,
    sceneContractHash: sceneContractHash,
    voiceProfileId: voiceProfileId,
    voiceProfileHash: voiceProfileHash,
    revision: revision,
    primaryFunction: primaryFunction,
    secondaryFunctions: secondaryFunctions,
    sceneGoal: taskCard.sceneGoal,
    blockingConflict: taskCard.blockingConflict,
    progression: taskCard.progression,
    exitCondition: taskCard.exitCondition,
    plannedBeats: plannedBeats,
    desiredStateChanges: desiredStateChanges,
    requiredReveals: taskCard.requiredReveals,
    requiredWithholds: taskCard.requiredWithholds,
    readerQuestionBefore: readerQuestionBefore,
    readerQuestionAfterTarget: readerQuestionAfterTarget,
    pressureCurve: pressureCurve,
    rhythmIntent: rhythmIntent,
    invariantsToPreserve: [
      ...invariantsToPreserve,
      ..._normalizedConstraints(taskCard.constraints),
    ],
    allowedDeviations: allowedDeviations,
    targetedRepairBudget: targetedRepairBudget,
    fullRewriteBudget: fullRewriteBudget,
  );
}

SceneCraftContract sceneCraftContractFromPipelineTaskCard(
  pipeline.SceneTaskCard taskCard, {
  pipeline.SceneDirectorPlan? parsedPlan,
  int schemaVersion = 1,
  required String craftId,
  required String sceneContractId,
  required String sceneContractHash,
  required String voiceProfileId,
  required String voiceProfileHash,
  int revision = 1,
  required SceneFunction primaryFunction,
  List<SceneFunction> secondaryFunctions = const [],
  List<String> plannedBeats = const [],
  List<StateChangeTarget> desiredStateChanges = const [],
  List<String> requiredReveals = const [],
  List<String> requiredWithholds = const [],
  required String exitCondition,
  required String readerQuestionBefore,
  required String readerQuestionAfterTarget,
  required PressureCurve pressureCurve,
  required RhythmIntent rhythmIntent,
  List<String> invariantsToPreserve = const [],
  List<AllowedDeviation> allowedDeviations = const [],
  required int targetedRepairBudget,
  required int fullRewriteBudget,
}) {
  final plan = parsedPlan ?? taskCard.directorPlanParsed;
  if (plan == null) {
    throw ArgumentError(
      'pipeline SceneTaskCard requires an explicit or parsed director plan',
    );
  }
  return sceneCraftContractFromDirectorPlan(
    plan,
    schemaVersion: schemaVersion,
    craftId: craftId,
    sceneContractId: sceneContractId,
    sceneContractHash: sceneContractHash,
    voiceProfileId: voiceProfileId,
    voiceProfileHash: voiceProfileHash,
    revision: revision,
    primaryFunction: primaryFunction,
    secondaryFunctions: secondaryFunctions,
    plannedBeats: plannedBeats,
    desiredStateChanges: desiredStateChanges,
    requiredReveals: requiredReveals,
    requiredWithholds: requiredWithholds,
    exitCondition: exitCondition,
    readerQuestionBefore: readerQuestionBefore,
    readerQuestionAfterTarget: readerQuestionAfterTarget,
    pressureCurve: pressureCurve,
    rhythmIntent: rhythmIntent,
    invariantsToPreserve: invariantsToPreserve,
    allowedDeviations: allowedDeviations,
    targetedRepairBudget: targetedRepairBudget,
    fullRewriteBudget: fullRewriteBudget,
  );
}

SceneCraftContract sceneCraftContractFromDirectorPlan(
  pipeline.SceneDirectorPlan plan, {
  int schemaVersion = 1,
  required String craftId,
  required String sceneContractId,
  required String sceneContractHash,
  required String voiceProfileId,
  required String voiceProfileHash,
  int revision = 1,
  required SceneFunction primaryFunction,
  List<SceneFunction> secondaryFunctions = const [],
  List<String> plannedBeats = const [],
  List<StateChangeTarget> desiredStateChanges = const [],
  List<String> requiredReveals = const [],
  List<String> requiredWithholds = const [],
  required String exitCondition,
  required String readerQuestionBefore,
  required String readerQuestionAfterTarget,
  required PressureCurve pressureCurve,
  required RhythmIntent rhythmIntent,
  List<String> invariantsToPreserve = const [],
  List<AllowedDeviation> allowedDeviations = const [],
  required int targetedRepairBudget,
  required int fullRewriteBudget,
}) {
  return SceneCraftContract.create(
    schemaVersion: schemaVersion,
    craftId: craftId,
    sceneContractId: sceneContractId,
    sceneContractHash: sceneContractHash,
    voiceProfileId: voiceProfileId,
    voiceProfileHash: voiceProfileHash,
    revision: revision,
    primaryFunction: primaryFunction,
    secondaryFunctions: secondaryFunctions,
    sceneGoal: plan.target,
    blockingConflict: plan.conflict,
    progression: plan.progression,
    exitCondition: exitCondition,
    plannedBeats: plannedBeats,
    desiredStateChanges: desiredStateChanges,
    requiredReveals: requiredReveals,
    requiredWithholds: requiredWithholds,
    readerQuestionBefore: readerQuestionBefore,
    readerQuestionAfterTarget: readerQuestionAfterTarget,
    pressureCurve: pressureCurve,
    rhythmIntent: rhythmIntent,
    invariantsToPreserve: [
      ...invariantsToPreserve,
      ..._splitDirectorConstraints(plan.constraints),
    ],
    allowedDeviations: allowedDeviations,
    targetedRepairBudget: targetedRepairBudget,
    fullRewriteBudget: fullRewriteBudget,
  );
}

List<String> _runtimeCastIds(runtime.SceneBrief brief) => [
  for (final member in brief.cast)
    if (member.characterId.trim().isNotEmpty) member.characterId.trim(),
];

List<String> _normalizedConstraints(Iterable<String> constraints) => [
  for (final value in constraints)
    if (value.trim().isNotEmpty) value.trim(),
];

List<String> _splitDirectorConstraints(String constraints) => constraints
    .split(RegExp(r'[/；;、\n]'))
    .map((value) => value.trim())
    .where((value) => value.isNotEmpty)
    .toList(growable: false);
