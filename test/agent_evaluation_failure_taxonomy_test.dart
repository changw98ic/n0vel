import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_failure_taxonomy.dart';

void main() {
  const requiredCodes = <String>{
    'mechanical.dialogue_ratio',
    'mechanical.opening_hook',
    'mechanical.ending_hook',
    'continuity.physical_impossibility',
    'continuity.prop_violation',
    'character.power_inversion',
    'character.voice_or_knowledge',
    'planner.missing_required_beat',
    'review.disagreement',
    'quality.repetition',
    'quality.expository_dialogue',
    'quality.causal_gap',
    'quality.faithfulness_gap',
    'rag.visibility_or_scope',
    'recovery.checkpoint_or_cas',
    'budget.exceeded',
    'provider.transport',
    'provider.indeterminate_completion',
    'harness.invalid_fixture',
  };

  test('taxonomy has exact required coverage and complete repair bindings', () {
    expect(
      AgentEvaluationFailureTaxonomy.definitions
          .map((definition) => definition.code)
          .toSet(),
      requiredCodes,
    );
    expect(
      AgentEvaluationFailureTaxonomy.definitions
          .map((definition) => definition.priority)
          .toSet(),
      hasLength(requiredCodes.length),
    );
    for (final definition in AgentEvaluationFailureTaxonomy.definitions) {
      expect(definition.repairPolicyId, isNotEmpty);
      expect(definition.requiredPreservations, isNotEmpty);
      expect(definition.revalidationStages, isNotEmpty);
      expect(definition.maxAttempts, greaterThanOrEqualTo(0));
      final finding = AgentEvaluationFailureTaxonomy.classify(<String>{
        definition.code,
      });
      final plan = AgentEvaluationFailureTaxonomy.repairPlanFor(finding);
      expect(plan.primaryCode, definition.code);
      expect(plan.repairPolicyId, definition.repairPolicyId);
      expect(
        plan.taxonomyReleaseHash,
        AgentEvaluationFailureTaxonomy.releaseHash,
      );
    }
  });

  test('primary priority is deterministic and keeps secondary failures', () {
    final finding = AgentEvaluationFailureTaxonomy.classify(const <String>{
      'quality.repetition',
      'provider.transport',
      'character.power_inversion',
    });

    expect(finding.primaryCode, 'provider.transport');
    expect(finding.secondaryCodes, <String>[
      'character.power_inversion',
      'quality.repetition',
    ]);
    expect(finding.findingHash, hasLength(64));
    expect(
      AgentEvaluationFailureTaxonomy.repairPlanFor(finding).planHash,
      hasLength(64),
    );
  });

  test('unknown, empty, and non-canonical failure codes fail closed', () {
    expect(
      () => AgentEvaluationFailureTaxonomy.classify(const <String>{
        'quality.unknown',
      }),
      throwsArgumentError,
    );
    expect(
      () => AgentEvaluationFailureTaxonomy.classify(const <String>{}),
      throwsArgumentError,
    );
    expect(
      () => AgentEvaluationFailureTaxonomy.classify(const <String>{
        ' quality.repetition',
      }),
      throwsArgumentError,
    );
  });

  test('terminal failures cannot authorize a content rewrite', () {
    for (final code in const <String>[
      'harness.invalid_fixture',
      'provider.indeterminate_completion',
      'budget.exceeded',
    ]) {
      final plan = AgentEvaluationFailureTaxonomy.repairPlanFor(
        AgentEvaluationFailureTaxonomy.classify(<String>{code}),
      );
      expect(plan.mode, AgentEvaluationRepairMode.terminalNoRepair);
      expect(plan.allowedScopes, isEmpty);
      expect(plan.maxAttempts, 0);
    }
  });
}
