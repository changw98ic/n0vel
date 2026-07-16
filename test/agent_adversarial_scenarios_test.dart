import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/domain/evaluation/agent_adversarial_scenarios.dart';
import 'package:novel_writer/features/story_generation/domain/evaluation/outcome_evaluation.dart';

void main() {
  group('AgentAdversarialScenarioCatalog', () {
    test('contains immutable attack/control pairs for all 25 spec cases', () {
      final catalog = AgentAdversarialScenarioCatalog.specV1();

      expect(catalog.scenarios, hasLength(50));
      expect(catalog.version, '1.0.0');
      expect(catalog.catalogHash, startsWith('sha256:'));
      expect(
        catalog.scenarios.map((scenario) => scenario.scenarioId).toSet(),
        hasLength(50),
      );

      for (var caseNumber = 1; caseNumber <= 25; caseNumber += 1) {
        final pair = catalog.scenarios
            .where((scenario) => scenario.caseNumber == caseNumber)
            .toList();
        expect(pair, hasLength(2), reason: 'case $caseNumber must be paired');
        expect(pair.map((scenario) => scenario.variant).toSet(), {
          AdversarialScenarioVariant.attack,
          AdversarialScenarioVariant.control,
        });
        for (final scenario in pair) {
          expect(scenario.fixtureHash, startsWith('sha256:'));
          expect(scenario.verifierReleaseRefs, isNotEmpty);
          expect(scenario.rubricReleaseRef, isNotEmpty);
          expect(scenario.requiredCapabilities, isNotEmpty);
          expect(scenario.adversarialMutations, isNotEmpty);
          expect(scenario.maxBudget.maxCalls, greaterThan(0));
          expect(scenario.maxBudget.maxTokens, greaterThan(0));
          expect(scenario.maxBudget.maxCostMicrousd, greaterThan(0));
        }
      }

      expect(
        () => catalog.scenarios.add(catalog.scenarios.first),
        throwsUnsupportedError,
      );
      expect(
        () => catalog.scenarios.first.requiredFailureCodes.add('tamper'),
        throwsUnsupportedError,
      );
    });

    test('catalog hash is canonical and reproducible', () {
      final first = AgentAdversarialScenarioCatalog.specV1();
      final second = AgentAdversarialScenarioCatalog.specV1();

      expect(first.catalogHash, second.catalogHash);
      expect(
        first.scenarios.map((scenario) => scenario.fixtureHash),
        second.scenarios.map((scenario) => scenario.fixtureHash),
      );
    });

    test('typed deterministic verifier executes every attack and control', () {
      final catalog = AgentAdversarialScenarioCatalog.specV1();
      const verifier = AgentAdversarialFixtureVerifier();
      final verifiedCases = <int>{};

      for (final scenario in catalog.scenarios) {
        final result = verifier.verify(scenario);
        expect(
          result.isHardPass,
          isTrue,
          reason: '${scenario.scenarioId}: ${result.violations}',
        );
        verifiedCases.add(scenario.caseNumber);
        expect(
          scenario.expectedTerminalState,
          scenario.variant == AdversarialScenarioVariant.attack
              ? TrialTerminalState.blocked
              : TrialTerminalState.accepted,
        );
        expect(
          scenario.acceptExpected,
          scenario.variant == AdversarialScenarioVariant.control,
        );
      }

      expect(verifiedCases, {
        for (var index = 1; index <= 25; index += 1) index,
      });
    });

    test('wrong expected outcome for an attack is detected', () {
      final attack = AgentAdversarialScenarioCatalog.specV1().scenarios.first;
      final corrupted = attack.copyWith(
        expectedTerminalState: TrialTerminalState.accepted,
        requiredFailureCodes: const {},
        acceptExpected: true,
      );

      final result = const AgentAdversarialFixtureVerifier().verify(corrupted);

      expect(result.isHardPass, isFalse);
      expect(
        result.violations,
        contains(OutcomeViolation.terminalStateMismatch),
      );
      expect(result.violations, contains(OutcomeViolation.acceptMismatch));
    });

    test('missing verifier and duplicate IDs fail closed', () {
      final valid = AgentAdversarialScenarioCatalog.specV1();
      final missingVerifier = [
        valid.scenarios.first.copyWith(verifierReleaseRefs: const []),
        ...valid.scenarios.skip(1),
      ];
      final duplicateId = [
        valid.scenarios.first,
        valid.scenarios[1].copyWith(
          scenarioId: valid.scenarios.first.scenarioId,
        ),
        ...valid.scenarios.skip(2),
      ];

      expect(
        () => AgentAdversarialScenarioCatalog(
          version: '1.0.0',
          scenarios: missingVerifier,
        ),
        throwsStateError,
      );
      expect(
        () => AgentAdversarialScenarioCatalog(
          version: '1.0.0',
          scenarios: duplicateId,
        ),
        throwsStateError,
      );
    });

    test('duplicate attack cannot substitute for the legal control', () {
      final valid = AgentAdversarialScenarioCatalog.specV1();
      final duplicateAttackPair = [
        valid.scenarios.first,
        valid.scenarios[1].copyWith(
          scenarioId: '${valid.scenarios[1].scenarioId}-attack',
          variant: AdversarialScenarioVariant.attack,
        ),
        ...valid.scenarios.skip(2),
      ];

      expect(
        () => AgentAdversarialScenarioCatalog(
          version: '1.0.0',
          scenarios: duplicateAttackPair,
        ),
        throwsStateError,
      );
    });
  });
}
