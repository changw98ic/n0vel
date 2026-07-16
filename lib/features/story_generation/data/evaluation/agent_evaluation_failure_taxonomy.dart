import 'agent_evaluation_manifest.dart';

enum AgentEvaluationRepairMode {
  localizedPatch,
  beatReplan,
  sceneRewrite,
  reviewArbitration,
  retrievalReplay,
  checkpointResume,
  transportRetry,
  terminalNoRepair,
}

final class AgentEvaluationFailureDefinition {
  const AgentEvaluationFailureDefinition({
    required this.code,
    required this.priority,
    required this.repairPolicyId,
    required this.mode,
    required this.allowedScopes,
    required this.requiredPreservations,
    required this.maxAttempts,
    required this.revalidationStages,
  });

  final String code;
  final int priority;
  final String repairPolicyId;
  final AgentEvaluationRepairMode mode;
  final List<String> allowedScopes;
  final List<String> requiredPreservations;
  final int maxAttempts;
  final List<String> revalidationStages;

  Map<String, Object?> toCanonicalMap() => <String, Object?>{
    'code': code,
    'priority': priority,
    'repairPolicyId': repairPolicyId,
    'mode': mode.name,
    'allowedScopes': allowedScopes,
    'requiredPreservations': requiredPreservations,
    'maxAttempts': maxAttempts,
    'revalidationStages': revalidationStages,
  };
}

final class AgentEvaluationFailureFinding {
  AgentEvaluationFailureFinding._({
    required this.taxonomyReleaseHash,
    required this.primaryCode,
    required this.secondaryCodes,
  }) {
    findingHash = AgentEvaluationHashes.domainHash(
      'eval-failure-finding-v1',
      toCanonicalMap(),
    );
  }

  final String taxonomyReleaseHash;
  final String primaryCode;
  final List<String> secondaryCodes;
  late final String findingHash;

  List<String> get allCodes => <String>[primaryCode, ...secondaryCodes];

  Map<String, Object?> toCanonicalMap() => <String, Object?>{
    'taxonomyReleaseHash': taxonomyReleaseHash,
    'primaryCode': primaryCode,
    'secondaryCodes': secondaryCodes,
  };
}

final class AgentEvaluationRepairPlan {
  AgentEvaluationRepairPlan._({
    required this.taxonomyReleaseHash,
    required this.findingHash,
    required this.primaryCode,
    required this.repairPolicyId,
    required this.mode,
    required this.allowedScopes,
    required this.requiredPreservations,
    required this.maxAttempts,
    required this.revalidationStages,
  }) {
    planHash = AgentEvaluationHashes.domainHash(
      'eval-failure-repair-plan-v1',
      toCanonicalMap(),
    );
  }

  final String taxonomyReleaseHash;
  final String findingHash;
  final String primaryCode;
  final String repairPolicyId;
  final AgentEvaluationRepairMode mode;
  final List<String> allowedScopes;
  final List<String> requiredPreservations;
  final int maxAttempts;
  final List<String> revalidationStages;
  late final String planHash;

  Map<String, Object?> toCanonicalMap() => <String, Object?>{
    'taxonomyReleaseHash': taxonomyReleaseHash,
    'findingHash': findingHash,
    'primaryCode': primaryCode,
    'repairPolicyId': repairPolicyId,
    'mode': mode.name,
    'allowedScopes': allowedScopes,
    'requiredPreservations': requiredPreservations,
    'maxAttempts': maxAttempts,
    'revalidationStages': revalidationStages,
  };
}

/// Immutable failure classification and repair-policy release.
///
/// Priority is list order and therefore deterministic. Unknown codes fail
/// closed; callers cannot silently collapse a multi-label failure into a more
/// convenient primary explanation.
abstract final class AgentEvaluationFailureTaxonomy {
  static const releaseId = 'agent-evaluation-failure-taxonomy-v1';

  static const definitions = <AgentEvaluationFailureDefinition>[
    AgentEvaluationFailureDefinition(
      code: 'harness.invalid_fixture',
      priority: 1,
      repairPolicyId: 'terminal-invalid-fixture-v1',
      mode: AgentEvaluationRepairMode.terminalNoRepair,
      allowedScopes: <String>[],
      requiredPreservations: <String>['provider-not-dispatched'],
      maxAttempts: 0,
      revalidationStages: <String>['fixture-preflight'],
    ),
    AgentEvaluationFailureDefinition(
      code: 'recovery.checkpoint_or_cas',
      priority: 2,
      repairPolicyId: 'same-attempt-checkpoint-resume-v1',
      mode: AgentEvaluationRepairMode.checkpointResume,
      allowedScopes: <String>['checkpoint', 'lease', 'outbox'],
      requiredPreservations: <String>[
        'provider-call-set',
        'candidate-hash',
        'original-attempt-identity',
      ],
      maxAttempts: 0,
      revalidationStages: <String>[
        'lease-fence',
        'checkpoint-hash',
        'transaction-proof',
      ],
    ),
    AgentEvaluationFailureDefinition(
      code: 'provider.indeterminate_completion',
      priority: 3,
      repairPolicyId: 'terminal-indeterminate-provider-v1',
      mode: AgentEvaluationRepairMode.terminalNoRepair,
      allowedScopes: <String>[],
      requiredPreservations: <String>[
        'provider-not-replayed',
        'conservative-budget-charge',
        'original-attempt-identity',
      ],
      maxAttempts: 0,
      revalidationStages: <String>['budget-ledger', 'checkpoint-authority'],
    ),
    AgentEvaluationFailureDefinition(
      code: 'budget.exceeded',
      priority: 4,
      repairPolicyId: 'terminal-budget-block-v1',
      mode: AgentEvaluationRepairMode.terminalNoRepair,
      allowedScopes: <String>[],
      requiredPreservations: <String>['charged-reservations'],
      maxAttempts: 0,
      revalidationStages: <String>['budget-ledger'],
    ),
    AgentEvaluationFailureDefinition(
      code: 'provider.transport',
      priority: 5,
      repairPolicyId: 'bounded-transport-retry-v1',
      mode: AgentEvaluationRepairMode.transportRetry,
      allowedScopes: <String>['transport-dispatch'],
      requiredPreservations: <String>['prompt-release', 'request-identity'],
      maxAttempts: 2,
      revalidationStages: <String>['usage', 'provider-receipt'],
    ),
    AgentEvaluationFailureDefinition(
      code: 'rag.visibility_or_scope',
      priority: 6,
      repairPolicyId: 'scoped-retrieval-replay-v1',
      mode: AgentEvaluationRepairMode.retrievalReplay,
      allowedScopes: <String>['retrieval-query', 'retrieval-context'],
      requiredPreservations: <String>['workspace-scope', 'canon-roots'],
      maxAttempts: 1,
      revalidationStages: <String>[
        'retrieval-authority',
        'generation',
        'hard-gate',
        'review',
        'quality',
        'candidate-proof',
      ],
    ),
    AgentEvaluationFailureDefinition(
      code: 'continuity.physical_impossibility',
      priority: 7,
      repairPolicyId: 'physical-beat-replan-v1',
      mode: AgentEvaluationRepairMode.beatReplan,
      allowedScopes: <String>['violating-beat', 'dependent-beats'],
      requiredPreservations: <String>['prior-canon', 'scene-objective'],
      maxAttempts: 1,
      revalidationStages: <String>[
        'planner',
        'hard-gate',
        'review',
        'quality',
        'candidate-proof',
      ],
    ),
    AgentEvaluationFailureDefinition(
      code: 'continuity.prop_violation',
      priority: 8,
      repairPolicyId: 'prop-state-patch-v1',
      mode: AgentEvaluationRepairMode.localizedPatch,
      allowedScopes: <String>['prop-mention', 'dependent-action'],
      requiredPreservations: <String>['prop-ledger', 'prior-canon'],
      maxAttempts: 1,
      revalidationStages: <String>[
        'hard-gate',
        'review',
        'quality',
        'candidate-proof',
      ],
    ),
    AgentEvaluationFailureDefinition(
      code: 'planner.missing_required_beat',
      priority: 9,
      repairPolicyId: 'required-beat-replan-v1',
      mode: AgentEvaluationRepairMode.sceneRewrite,
      allowedScopes: <String>['scene-plan', 'dependent-prose'],
      requiredPreservations: <String>[
        'input-facts',
        'canon',
        'character-state',
      ],
      maxAttempts: 1,
      revalidationStages: <String>[
        'planner',
        'generation',
        'hard-gate',
        'review',
        'quality',
        'candidate-proof',
      ],
    ),
    AgentEvaluationFailureDefinition(
      code: 'character.power_inversion',
      priority: 10,
      repairPolicyId: 'power-boundary-patch-v1',
      mode: AgentEvaluationRepairMode.localizedPatch,
      allowedScopes: <String>['violating-dialogue-turn', 'dependent-reaction'],
      requiredPreservations: <String>['character-state', 'scene-facts'],
      maxAttempts: 1,
      revalidationStages: <String>[
        'character-gate',
        'review',
        'quality',
        'candidate-proof',
      ],
    ),
    AgentEvaluationFailureDefinition(
      code: 'character.voice_or_knowledge',
      priority: 11,
      repairPolicyId: 'voice-knowledge-patch-v1',
      mode: AgentEvaluationRepairMode.localizedPatch,
      allowedScopes: <String>['violating-dialogue-turn', 'internal-thought'],
      requiredPreservations: <String>['known-facts', 'character-voice'],
      maxAttempts: 1,
      revalidationStages: <String>[
        'character-gate',
        'review',
        'quality',
        'candidate-proof',
      ],
    ),
    AgentEvaluationFailureDefinition(
      code: 'review.disagreement',
      priority: 12,
      repairPolicyId: 'independent-review-arbitration-v1',
      mode: AgentEvaluationRepairMode.reviewArbitration,
      allowedScopes: <String>['disputed-findings'],
      requiredPreservations: <String>['both-review-records'],
      maxAttempts: 1,
      revalidationStages: <String>['review', 'quality', 'candidate-proof'],
    ),
    AgentEvaluationFailureDefinition(
      code: 'mechanical.dialogue_ratio',
      priority: 13,
      repairPolicyId: 'dialogue-ratio-patch-v1',
      mode: AgentEvaluationRepairMode.localizedPatch,
      allowedScopes: <String>['dialogue-paragraphs', 'adjacent-action'],
      requiredPreservations: <String>['facts', 'causal-order'],
      maxAttempts: 1,
      revalidationStages: <String>['mechanical', 'review', 'quality'],
    ),
    AgentEvaluationFailureDefinition(
      code: 'mechanical.opening_hook',
      priority: 14,
      repairPolicyId: 'opening-hook-patch-v1',
      mode: AgentEvaluationRepairMode.localizedPatch,
      allowedScopes: <String>['opening-paragraphs'],
      requiredPreservations: <String>['first-beat-facts'],
      maxAttempts: 1,
      revalidationStages: <String>['mechanical', 'review', 'quality'],
    ),
    AgentEvaluationFailureDefinition(
      code: 'mechanical.ending_hook',
      priority: 15,
      repairPolicyId: 'ending-hook-patch-v1',
      mode: AgentEvaluationRepairMode.localizedPatch,
      allowedScopes: <String>['ending-paragraphs'],
      requiredPreservations: <String>['scene-outcome', 'next-pressure'],
      maxAttempts: 1,
      revalidationStages: <String>['mechanical', 'review', 'quality'],
    ),
    AgentEvaluationFailureDefinition(
      code: 'quality.causal_gap',
      priority: 16,
      repairPolicyId: 'causal-gap-patch-v1',
      mode: AgentEvaluationRepairMode.localizedPatch,
      allowedScopes: <String>['weak-transition', 'dependent-reaction'],
      requiredPreservations: <String>['passed-facts', 'character-state'],
      maxAttempts: 1,
      revalidationStages: <String>['hard-gate', 'review', 'quality'],
    ),
    AgentEvaluationFailureDefinition(
      code: 'quality.expository_dialogue',
      priority: 17,
      repairPolicyId: 'exposition-to-action-patch-v1',
      mode: AgentEvaluationRepairMode.localizedPatch,
      allowedScopes: <String>['expository-dialogue', 'adjacent-action'],
      requiredPreservations: <String>['revealed-facts', 'speaker-knowledge'],
      maxAttempts: 1,
      revalidationStages: <String>['review', 'quality'],
    ),
    AgentEvaluationFailureDefinition(
      code: 'quality.repetition',
      priority: 18,
      repairPolicyId: 'repetition-delete-or-merge-v1',
      mode: AgentEvaluationRepairMode.localizedPatch,
      allowedScopes: <String>['repeated-sentences', 'adjacent-transitions'],
      requiredPreservations: <String>['unique-facts', 'causal-order'],
      maxAttempts: 1,
      revalidationStages: <String>['review', 'quality'],
    ),
    AgentEvaluationFailureDefinition(
      code: 'quality.faithfulness_gap',
      priority: 19,
      repairPolicyId: 'faithfulness-source-boundary-patch-v1',
      mode: AgentEvaluationRepairMode.localizedPatch,
      allowedScopes: <String>['unsupported-claim', 'contradictory-claim'],
      requiredPreservations: <String>[
        'accepted-beats',
        'character-knowledge',
        'world-facts',
      ],
      maxAttempts: 1,
      revalidationStages: <String>['canon', 'review', 'quality'],
    ),
  ];

  static final Map<String, AgentEvaluationFailureDefinition> _byCode =
      Map<String, AgentEvaluationFailureDefinition>.unmodifiable(
        <String, AgentEvaluationFailureDefinition>{
          for (final definition in definitions) definition.code: definition,
        },
      );

  static final String releaseHash = AgentEvaluationHashes.domainHash(
    'eval-failure-taxonomy-release-v1',
    <String, Object?>{
      'releaseId': releaseId,
      'definitions': <Object?>[
        for (final definition in definitions) definition.toCanonicalMap(),
      ],
    },
  );

  static AgentEvaluationFailureDefinition requireDefinition(String code) {
    final definition = _byCode[code];
    if (definition == null) {
      throw ArgumentError.value(code, 'code', 'unknown failure code');
    }
    return definition;
  }

  static AgentEvaluationFailureFinding classify(Iterable<String> codes) {
    final unique = codes.toSet();
    if (unique.isEmpty || unique.any((code) => code.trim() != code)) {
      throw ArgumentError('failure code set is empty or non-canonical');
    }
    final ordered = unique.map(requireDefinition).toList()
      ..sort((left, right) {
        final priority = left.priority.compareTo(right.priority);
        return priority != 0 ? priority : left.code.compareTo(right.code);
      });
    return AgentEvaluationFailureFinding._(
      taxonomyReleaseHash: releaseHash,
      primaryCode: ordered.first.code,
      secondaryCodes: List<String>.unmodifiable(
        ordered.skip(1).map((definition) => definition.code),
      ),
    );
  }

  static AgentEvaluationRepairPlan repairPlanFor(
    AgentEvaluationFailureFinding finding,
  ) {
    if (finding.taxonomyReleaseHash != releaseHash) {
      throw ArgumentError('failure finding belongs to another taxonomy');
    }
    final definition = requireDefinition(finding.primaryCode);
    for (final code in finding.secondaryCodes) {
      requireDefinition(code);
    }
    return AgentEvaluationRepairPlan._(
      taxonomyReleaseHash: releaseHash,
      findingHash: finding.findingHash,
      primaryCode: definition.code,
      repairPolicyId: definition.repairPolicyId,
      mode: definition.mode,
      allowedScopes: definition.allowedScopes,
      requiredPreservations: definition.requiredPreservations,
      maxAttempts: definition.maxAttempts,
      revalidationStages: definition.revalidationStages,
    );
  }
}
