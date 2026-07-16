import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_external_custody_trust_store.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_production_authorities.dart';

void main() {
  group('reviewed provider price authority', () {
    test(
      'exact reviewed table is bound but audit registries cannot release',
      () {
        final table = _priceTable(promptPrice: 400000, completionPrice: 800000);
        final entry = _trustEntry(
          approvedPriceTableHashes: <String>[table.releaseHash],
        );
        final authority =
            AgentEvaluationExternalCustodyTrustRegistry.auditOnly(
              entries: <AgentEvaluationExternalCustodyTrustEntry>[entry],
            ).authorizeProviderPriceTable(
              rootKeyId: entry.rootKeyId,
              priceTableReleaseHash: table.releaseHash,
              zeroPricedModelRouteHashes: const <String>[],
            );

        expect(authority.priceTableReleaseHash, table.releaseHash);
        expect(authority.trustEntryHash, entry.entryHash);
        expect(
          authority.freeRoutePolicyVersion,
          agentEvaluationTrustedFreeRoutePolicyVersion,
        );
        expect(authority.freeRoutePolicyHash, entry.freeRoutePolicyHash);
        expect(authority.productionAuthorityEligible, isFalse);
      },
    );

    test('caller-declared tiny prices change the release and fail closed', () {
      final reviewed = _priceTable(
        promptPrice: 400000,
        completionPrice: 800000,
      );
      final attacker = _priceTable(promptPrice: 1, completionPrice: 1);
      final entry = _trustEntry(
        approvedPriceTableHashes: <String>[reviewed.releaseHash],
      );
      final registry = AgentEvaluationExternalCustodyTrustRegistry.auditOnly(
        entries: <AgentEvaluationExternalCustodyTrustEntry>[entry],
      );

      expect(attacker.releaseHash, isNot(reviewed.releaseHash));
      expect(
        () => registry.authorizeProviderPriceTable(
          rootKeyId: entry.rootKeyId,
          priceTableReleaseHash: attacker.releaseHash,
          zeroPricedModelRouteHashes: const <String>[],
        ),
        throwsFormatException,
      );
    });

    test('reviewed zero table still requires versioned free-route policy', () {
      final zero = _priceTable(promptPrice: 0, completionPrice: 0);
      final routeHash = zero.entries.single.modelRouteHash;
      final paidEntry = _trustEntry(
        approvedPriceTableHashes: <String>[zero.releaseHash],
      );
      final paidRegistry =
          AgentEvaluationExternalCustodyTrustRegistry.auditOnly(
            entries: <AgentEvaluationExternalCustodyTrustEntry>[paidEntry],
          );

      expect(
        () => paidRegistry.authorizeProviderPriceTable(
          rootKeyId: paidEntry.rootKeyId,
          priceTableReleaseHash: zero.releaseHash,
          zeroPricedModelRouteHashes: <String>[routeHash],
        ),
        throwsFormatException,
      );

      final freeEntry = _trustEntry(
        approvedPriceTableHashes: <String>[zero.releaseHash],
        freeRouteHashes: <String>[routeHash],
      );
      final authority =
          AgentEvaluationExternalCustodyTrustRegistry.auditOnly(
            entries: <AgentEvaluationExternalCustodyTrustEntry>[freeEntry],
          ).authorizeProviderPriceTable(
            rootKeyId: freeEntry.rootKeyId,
            priceTableReleaseHash: zero.releaseHash,
            zeroPricedModelRouteHashes: <String>[routeHash],
          );

      expect(
        freeEntry.freeRoutePolicyVersion,
        agentEvaluationTrustedFreeRoutePolicyVersion,
      );
      expect(authority.freeRoutePolicyHash, freeEntry.freeRoutePolicyHash);
      expect(
        freeEntry.freeRoutePolicyHash,
        isNot(paidEntry.freeRoutePolicyHash),
      );
      expect(freeEntry.entryHash, isNot(paidEntry.entryHash));
    });

    test('production registry has no implicit prices or free routes', () {
      final attacker = _priceTable(promptPrice: 0, completionPrice: 0);
      expect(
        () => AgentEvaluationExternalCustodyTrustRegistry.production()
            .authorizeProviderPriceTable(
              rootKeyId: 'caller-controlled-root',
              priceTableReleaseHash: attacker.releaseHash,
              zeroPricedModelRouteHashes: <String>[
                attacker.entries.single.modelRouteHash,
              ],
            ),
        throwsFormatException,
      );
    });
  });
}

AgentEvaluationFrozenProviderPriceTable _priceTable({
  required int promptPrice,
  required int completionPrice,
}) => AgentEvaluationFrozenProviderPriceTable(
  tableId: 'reviewed-price-test-v1',
  entries: <AgentEvaluationPriceEntry>[
    AgentEvaluationPriceEntry(
      modelRouteHash: 'a' * 64,
      model: 'glm-reviewed-route',
      promptMicrousdPerMillionTokens: promptPrice,
      completionMicrousdPerMillionTokens: completionPrice,
    ),
  ],
);

AgentEvaluationExternalCustodyTrustEntry _trustEntry({
  required List<String> approvedPriceTableHashes,
  List<String> freeRouteHashes = const <String>[],
}) => AgentEvaluationExternalCustodyTrustEntry(
  rootKeyId: 'price-root-v1',
  rootPublicKeyBase64: base64Encode(List<int>.generate(32, (index) => index)),
  kmsProviderReleaseHash: 'b' * 64,
  kmsKeyResourceHash: 'c' * 64,
  allowedRunnerPrincipalHashes: <String>['d' * 64],
  allowedSigningKeyIds: const <String>['price-signing-key-v1'],
  macTeamIdentifier: 'ABCDE12345',
  macDesignatedRequirement: 'identifier "price-signer"',
  macCdHash: 'A' * 40,
  runtimeAppTeamIdentifier: 'ABCDE12345',
  runtimeAppDesignatedRequirement: 'identifier "price-runtime"',
  runtimeAppCdHash: 'B' * 40,
  runtimeAppAuthorityChain: const <String>['Developer ID Application: Test'],
  approvedProviderPriceTableReleaseHashes: approvedPriceTableHashes,
  trustedFreeModelRouteHashes: freeRouteHashes,
);
