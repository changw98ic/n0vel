import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/domain/evaluation/holdout_access.dart';

void main() {
  group('ExperimentFamilyHoldoutAccess', () {
    test('grants the preregistered challenger one confirmation token', () {
      final access = _access();

      final grant = access.requestConfirmation('challenger-a');

      expect(grant.status, HoldoutAccessStatus.granted);
      expect(grant.confirmationToken, 'confirmation-token-1');
      expect(access.remainingBudget, 0);
    });

    test('rejects repeated holdout probing by the same challenger', () {
      final access = _access();
      expect(
        access.requestConfirmation('challenger-a').status,
        HoldoutAccessStatus.granted,
      );

      final repeated = access.requestConfirmation('challenger-a');

      expect(repeated.status, HoldoutAccessStatus.denied);
      expect(repeated.denialReason, HoldoutDenialReason.repeatedProbe);
      expect(repeated.confirmationToken, isNull);
    });

    test('rejects a non-preregistered challenger', () {
      final access = _access();

      final result = access.requestConfirmation('challenger-b');

      expect(result.status, HoldoutAccessStatus.denied);
      expect(result.denialReason, HoldoutDenialReason.unregisteredChallenger);
      expect(access.remainingBudget, 1);
    });

    test('public confirmation report contains no diagnostic evidence', () {
      final access = _access();
      final grant = access.requestConfirmation('challenger-a');

      final report = access.publishConfirmation(
        confirmationToken: grant.confirmationToken!,
        passed: false,
      );
      final publicJson = report.toPublicJson();

      expect(publicJson['status'], 'fail');
      expect(publicJson.keys, {
        'familyId',
        'challengerId',
        'confirmationId',
        'status',
      });
      expect(publicJson, isNot(contains('scenarios')));
      expect(publicJson, isNot(contains('failureDetails')));
      expect(publicJson, isNot(contains('evidence')));
    });
  });
}

ExperimentFamilyHoldoutAccess _access() => ExperimentFamilyHoldoutAccess(
  familyId: 'family-1',
  preregisteredChallengerId: 'challenger-a',
  confirmationTokens: const ['confirmation-token-1'],
);
