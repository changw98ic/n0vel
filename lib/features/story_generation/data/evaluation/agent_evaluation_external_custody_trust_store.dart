import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'agent_evaluation_manifest.dart';

/// Compile-time trust anchors for release-authoritative external custody.
///
/// This list is intentionally empty. A deployment does not become trusted by
/// supplying environment variables; an independently reviewed provider/root/
/// resource/principal entry must be pinned here and shipped in a new binary.
const List<AgentEvaluationExternalCustodyTrustEntry> _productionPinnedEntries =
    <AgentEvaluationExternalCustodyTrustEntry>[];

/// Versioned policy for routes whose provider contract is genuinely free.
///
/// The production list is intentionally empty. A zero-valued prompt or
/// completion price is never inferred from caller input; it must be pinned in
/// a reviewed trust entry and therefore requires a new signed application
/// release.
const agentEvaluationTrustedFreeRoutePolicyVersion =
    'agent-evaluation-trusted-free-routes-v1';

final class AgentEvaluationExternalCustodyTrustEntry {
  const AgentEvaluationExternalCustodyTrustEntry({
    required this.rootKeyId,
    required this.rootPublicKeyBase64,
    required this.kmsProviderReleaseHash,
    required this.kmsKeyResourceHash,
    required this.allowedRunnerPrincipalHashes,
    required this.allowedSigningKeyIds,
    required this.macTeamIdentifier,
    required this.macDesignatedRequirement,
    required this.macCdHash,
    required this.runtimeAppTeamIdentifier,
    required this.runtimeAppDesignatedRequirement,
    required this.runtimeAppCdHash,
    required this.runtimeAppAuthorityChain,
    this.approvedProviderPriceTableReleaseHashes = const <String>[],
    this.trustedFreeModelRouteHashes = const <String>[],
    this.freeRoutePolicyVersion = agentEvaluationTrustedFreeRoutePolicyVersion,
  });

  final String rootKeyId;
  final String rootPublicKeyBase64;
  final String kmsProviderReleaseHash;
  final String kmsKeyResourceHash;
  final List<String> allowedRunnerPrincipalHashes;
  final List<String> allowedSigningKeyIds;
  final String macTeamIdentifier;
  final String macDesignatedRequirement;
  final String macCdHash;
  final String runtimeAppTeamIdentifier;
  final String runtimeAppDesignatedRequirement;
  final String runtimeAppCdHash;
  final List<String> runtimeAppAuthorityChain;
  final List<String> approvedProviderPriceTableReleaseHashes;
  final List<String> trustedFreeModelRouteHashes;
  final String freeRoutePolicyVersion;

  SimplePublicKey validateAndExtractRoot() {
    if (!RegExp(r'^[A-Za-z0-9_.:-]{1,128}$').hasMatch(rootKeyId) ||
        allowedRunnerPrincipalHashes.isEmpty ||
        allowedSigningKeyIds.isEmpty ||
        allowedSigningKeyIds.any(
          (value) => !RegExp(r'^[A-Za-z0-9_.:-]{1,128}$').hasMatch(value),
        ) ||
        !RegExp(r'^[A-Z0-9]{10}$').hasMatch(macTeamIdentifier) ||
        macDesignatedRequirement.trim().isEmpty ||
        macDesignatedRequirement.length > 4096 ||
        !RegExp(r'^[A-F0-9]{40,64}$').hasMatch(macCdHash) ||
        !RegExp(r'^[A-Z0-9]{10}$').hasMatch(runtimeAppTeamIdentifier) ||
        runtimeAppDesignatedRequirement.trim().isEmpty ||
        runtimeAppDesignatedRequirement.length > 4096 ||
        !RegExp(r'^[A-F0-9]{40,64}$').hasMatch(runtimeAppCdHash) ||
        runtimeAppAuthorityChain.isEmpty ||
        runtimeAppAuthorityChain.length > 8 ||
        runtimeAppAuthorityChain.toSet().length !=
            runtimeAppAuthorityChain.length ||
        runtimeAppAuthorityChain.any(
          (value) =>
              value.trim() != value || value.isEmpty || value.length > 1024,
        ) ||
        freeRoutePolicyVersion !=
            agentEvaluationTrustedFreeRoutePolicyVersion ||
        approvedProviderPriceTableReleaseHashes.toSet().length !=
            approvedProviderPriceTableReleaseHashes.length ||
        trustedFreeModelRouteHashes.toSet().length !=
            trustedFreeModelRouteHashes.length) {
      throw const FormatException('external custody trust entry is invalid');
    }
    AgentEvaluationHashes.requireDigest(
      kmsProviderReleaseHash,
      'kmsProviderReleaseHash',
    );
    AgentEvaluationHashes.requireDigest(
      kmsKeyResourceHash,
      'kmsKeyResourceHash',
    );
    for (final principal in allowedRunnerPrincipalHashes) {
      AgentEvaluationHashes.requireDigest(principal, 'runnerPrincipalHash');
    }
    for (final priceTableHash in approvedProviderPriceTableReleaseHashes) {
      AgentEvaluationHashes.requireDigest(
        priceTableHash,
        'approvedProviderPriceTableReleaseHash',
      );
    }
    for (final routeHash in trustedFreeModelRouteHashes) {
      AgentEvaluationHashes.requireDigest(
        routeHash,
        'trustedFreeModelRouteHash',
      );
    }
    late final List<int> bytes;
    try {
      bytes = base64Decode(rootPublicKeyBase64);
    } on FormatException {
      throw const FormatException('external custody trust root is invalid');
    }
    if (bytes.length != 32 || base64Encode(bytes) != rootPublicKeyBase64) {
      throw const FormatException('external custody trust root is invalid');
    }
    return SimplePublicKey(bytes, type: KeyPairType.ed25519);
  }

  String get freeRoutePolicyHash => AgentEvaluationHashes.domainHash(
    'agent-evaluation-trusted-free-route-policy-v1',
    <String, Object?>{
      'version': freeRoutePolicyVersion,
      'modelRouteHashes': <String>[...trustedFreeModelRouteHashes]..sort(),
    },
  );

  String get entryHash => AgentEvaluationHashes.domainHash(
    'agent-evaluation-external-custody-trust-entry-v3',
    <String, Object?>{
      'rootKeyId': rootKeyId,
      'rootPublicKeyBase64': rootPublicKeyBase64,
      'kmsProviderReleaseHash': kmsProviderReleaseHash,
      'kmsKeyResourceHash': kmsKeyResourceHash,
      'allowedRunnerPrincipalHashes': <String>[...allowedRunnerPrincipalHashes]
        ..sort(),
      'allowedSigningKeyIds': <String>[...allowedSigningKeyIds]..sort(),
      'macTeamIdentifier': macTeamIdentifier,
      'macDesignatedRequirement': macDesignatedRequirement,
      'macCdHash': macCdHash,
      'runtimeAppTeamIdentifier': runtimeAppTeamIdentifier,
      'runtimeAppDesignatedRequirement': runtimeAppDesignatedRequirement,
      'runtimeAppCdHash': runtimeAppCdHash,
      'runtimeAppAuthorityChain': runtimeAppAuthorityChain,
      'approvedProviderPriceTableReleaseHashes': <String>[
        ...approvedProviderPriceTableReleaseHashes,
      ]..sort(),
      'freeRoutePolicyVersion': freeRoutePolicyVersion,
      'freeRoutePolicyHash': freeRoutePolicyHash,
      'trustedFreeModelRouteHashes': <String>[...trustedFreeModelRouteHashes]
        ..sort(),
    },
  );
}

/// Non-serializable proof that a complete route-to-price table was reviewed
/// in the same compile-time trust entry that governs external custody.
final class AgentEvaluationVerifiedProviderPriceAuthority {
  const AgentEvaluationVerifiedProviderPriceAuthority._({
    required this.priceTableReleaseHash,
    required this.trustEntryHash,
    required this.freeRoutePolicyVersion,
    required this.freeRoutePolicyHash,
    required this.productionAuthorityEligible,
  });

  final String priceTableReleaseHash;
  final String trustEntryHash;
  final String freeRoutePolicyVersion;
  final String freeRoutePolicyHash;
  final bool productionAuthorityEligible;
}

final class AgentEvaluationExternalCustodyTrustRegistry {
  AgentEvaluationExternalCustodyTrustRegistry._({
    required List<AgentEvaluationExternalCustodyTrustEntry> entries,
    required this.productionPinned,
  }) : _entries =
           Map<String, AgentEvaluationExternalCustodyTrustEntry>.unmodifiable(
             <String, AgentEvaluationExternalCustodyTrustEntry>{
               for (final entry in entries) entry.rootKeyId: entry,
             },
           ) {
    if (_entries.length != entries.length) {
      throw ArgumentError('external custody trust root is duplicated');
    }
    for (final entry in entries) {
      entry.validateAndExtractRoot();
    }
  }

  factory AgentEvaluationExternalCustodyTrustRegistry.production() =>
      AgentEvaluationExternalCustodyTrustRegistry._(
        entries: _productionPinnedEntries,
        productionPinned: true,
      );

  /// Test/audit registries can exercise the protocol but never authorize a
  /// release, even when their signatures are cryptographically valid.
  factory AgentEvaluationExternalCustodyTrustRegistry.auditOnly({
    required List<AgentEvaluationExternalCustodyTrustEntry> entries,
  }) => AgentEvaluationExternalCustodyTrustRegistry._(
    entries: entries,
    productionPinned: false,
  );

  final Map<String, AgentEvaluationExternalCustodyTrustEntry> _entries;
  final bool productionPinned;

  AgentEvaluationExternalCustodyTrustEntry resolve(String rootKeyId) {
    final entry = _entries[rootKeyId];
    if (entry == null) {
      throw const FormatException('external custody root is not registered');
    }
    return entry;
  }

  AgentEvaluationVerifiedProviderPriceAuthority authorizeProviderPriceTable({
    required String rootKeyId,
    required String priceTableReleaseHash,
    required Iterable<String> zeroPricedModelRouteHashes,
  }) {
    AgentEvaluationHashes.requireDigest(
      priceTableReleaseHash,
      'priceTableReleaseHash',
    );
    final entry = resolve(rootKeyId);
    final zeroRoutes = zeroPricedModelRouteHashes.toSet();
    for (final routeHash in zeroRoutes) {
      AgentEvaluationHashes.requireDigest(
        routeHash,
        'zeroPricedModelRouteHash',
      );
    }
    if (!entry.approvedProviderPriceTableReleaseHashes.contains(
          priceTableReleaseHash,
        ) ||
        !entry.trustedFreeModelRouteHashes.toSet().containsAll(zeroRoutes)) {
      throw const FormatException(
        'provider price table is not approved by the production trust entry',
      );
    }
    return AgentEvaluationVerifiedProviderPriceAuthority._(
      priceTableReleaseHash: priceTableReleaseHash,
      trustEntryHash: entry.entryHash,
      freeRoutePolicyVersion: entry.freeRoutePolicyVersion,
      freeRoutePolicyHash: entry.freeRoutePolicyHash,
      productionAuthorityEligible: productionPinned,
    );
  }

  bool get isEmpty => _entries.isEmpty;
}
