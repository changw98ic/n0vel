import 'agent_evaluation_manifest.dart';

abstract final class AgentEvaluationQualityDimensions {
  static const values = <String>{
    'proseReadability',
    'plotCausality',
    'characterConsistency',
    'canonMemory',
    'robustness',
    'efficiency',
  };
}

/// Immutable proof that the independent judge treated candidate prose as
/// quoted, untrusted data and did not obey instructions embedded inside it.
final class AgentEvaluationJudgeInjectionSafetyReceipt {
  factory AgentEvaluationJudgeInjectionSafetyReceipt({
    required String evaluatedContentHash,
    required String candidateJsonDigest,
    required String renderedMessagesDigest,
    required String judgePromptReleaseHash,
    required String judgeModelRouteHash,
    required String rubricReleaseHash,
    required String parserReleaseHash,
    required String aggregatorReleaseHash,
    required String rawResponseHash,
    required Map<String, int> parsedScoreMicros,
    required String parsedSummaryHash,
    required Iterable<String> detectedInjectionMarkerHashes,
    required Iterable<String> guardFailureCodes,
    required String verifierReleaseHash,
  }) {
    final scores = Map<String, int>.unmodifiable(parsedScoreMicros);
    final markers = detectedInjectionMarkerHashes.toList()..sort();
    final failures = guardFailureCodes.toList()..sort();
    final canonical = <String, Object?>{
      'schemaVersion': 'eval-judge-injection-safety-receipt-v1',
      'evaluatedContentHash': evaluatedContentHash,
      'candidateJsonDigest': candidateJsonDigest,
      'renderedMessagesDigest': renderedMessagesDigest,
      'judgePromptReleaseHash': judgePromptReleaseHash,
      'judgeModelRouteHash': judgeModelRouteHash,
      'rubricReleaseHash': rubricReleaseHash,
      'parserReleaseHash': parserReleaseHash,
      'aggregatorReleaseHash': aggregatorReleaseHash,
      'rawResponseHash': rawResponseHash,
      'parsedScoreMicros': <String, int>{
        for (final key in scores.keys.toList()..sort()) key: scores[key]!,
      },
      'parsedSummaryHash': parsedSummaryHash,
      'detectedInjectionMarkerHashes': markers,
      'guardFailureCodes': failures,
      'verifierReleaseHash': verifierReleaseHash,
    };
    return AgentEvaluationJudgeInjectionSafetyReceipt._(
      value: Map<String, Object?>.unmodifiable(canonical),
      receiptHash: AgentEvaluationHashes.domainHash(
        'eval-judge-injection-safety-receipt-v1',
        canonical,
      ),
    );
  }

  factory AgentEvaluationJudgeInjectionSafetyReceipt.fromJson(
    Map<String, Object?> value,
  ) {
    const requiredKeys = <String>{
      'schemaVersion',
      'evaluatedContentHash',
      'candidateJsonDigest',
      'renderedMessagesDigest',
      'judgePromptReleaseHash',
      'judgeModelRouteHash',
      'rubricReleaseHash',
      'parserReleaseHash',
      'aggregatorReleaseHash',
      'rawResponseHash',
      'parsedScoreMicros',
      'parsedSummaryHash',
      'detectedInjectionMarkerHashes',
      'guardFailureCodes',
      'verifierReleaseHash',
      'receiptHash',
    };
    if (value.keys.toSet().length != requiredKeys.length ||
        !value.keys.toSet().containsAll(requiredKeys) ||
        value['schemaVersion'] != 'eval-judge-injection-safety-receipt-v1' ||
        value['parsedScoreMicros'] is! Map<String, Object?> ||
        value['detectedInjectionMarkerHashes'] is! List<Object?> ||
        value['guardFailureCodes'] is! List<Object?> ||
        value['receiptHash'] is! String) {
      throw ArgumentError('judge injection safety receipt is malformed');
    }
    final scores = <String, int>{};
    for (final entry
        in (value['parsedScoreMicros']! as Map<String, Object?>).entries) {
      if (entry.value is! int) {
        throw ArgumentError('judge injection scores are malformed');
      }
      scores[entry.key] = entry.value! as int;
    }
    final receipt = AgentEvaluationJudgeInjectionSafetyReceipt(
      evaluatedContentHash: value['evaluatedContentHash'] as String,
      candidateJsonDigest: value['candidateJsonDigest'] as String,
      renderedMessagesDigest: value['renderedMessagesDigest'] as String,
      judgePromptReleaseHash: value['judgePromptReleaseHash'] as String,
      judgeModelRouteHash: value['judgeModelRouteHash'] as String,
      rubricReleaseHash: value['rubricReleaseHash'] as String,
      parserReleaseHash: value['parserReleaseHash'] as String,
      aggregatorReleaseHash: value['aggregatorReleaseHash'] as String,
      rawResponseHash: value['rawResponseHash'] as String,
      parsedScoreMicros: scores,
      parsedSummaryHash: value['parsedSummaryHash'] as String,
      detectedInjectionMarkerHashes:
          (value['detectedInjectionMarkerHashes']! as List<Object?>)
              .cast<String>(),
      guardFailureCodes: (value['guardFailureCodes']! as List<Object?>)
          .cast<String>(),
      verifierReleaseHash: value['verifierReleaseHash'] as String,
    );
    if (receipt.receiptHash != value['receiptHash']) {
      throw StateError('judge injection safety receipt hash is invalid');
    }
    return receipt;
  }

  AgentEvaluationJudgeInjectionSafetyReceipt._({
    required Map<String, Object?> value,
    required this.receiptHash,
  }) : _value = value {
    for (final key in const <String>[
      'evaluatedContentHash',
      'candidateJsonDigest',
      'renderedMessagesDigest',
      'judgePromptReleaseHash',
      'judgeModelRouteHash',
      'rubricReleaseHash',
      'parserReleaseHash',
      'aggregatorReleaseHash',
      'rawResponseHash',
      'parsedSummaryHash',
      'verifierReleaseHash',
    ]) {
      AgentEvaluationHashes.requireDigest(_value[key]! as String, key);
    }
    AgentEvaluationHashes.requireDigest(receiptHash, 'receiptHash');
    final scores = _value['parsedScoreMicros']! as Map<String, int>;
    if (scores.keys.toSet().difference(const <String>{
          'proseReadability',
          'plotCausality',
        }).isNotEmpty ||
        scores.length != 2 ||
        scores.values.any((score) => score < 0 || score > 100000000)) {
      throw ArgumentError('judge injection parsed scores are invalid');
    }
    for (final digest
        in _value['detectedInjectionMarkerHashes']! as List<String>) {
      AgentEvaluationHashes.requireDigest(digest, 'injectionMarkerHash');
    }
  }

  final Map<String, Object?> _value;
  final String receiptHash;

  String get evaluatedContentHash => _value['evaluatedContentHash']! as String;
  String get judgePromptReleaseHash =>
      _value['judgePromptReleaseHash']! as String;
  String get judgeModelRouteHash => _value['judgeModelRouteHash']! as String;
  String get rubricReleaseHash => _value['rubricReleaseHash']! as String;
  String get aggregatorReleaseHash =>
      _value['aggregatorReleaseHash']! as String;
  String get verifierReleaseHash => _value['verifierReleaseHash']! as String;
  List<String> get guardFailureCodes =>
      List<String>.unmodifiable(_value['guardFailureCodes']! as List<String>);
  bool get passed => guardFailureCodes.isEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
    ..._value,
    'receiptHash': receiptHash,
  };
}

final class AgentEvaluationPricedProviderCall {
  AgentEvaluationPricedProviderCall({
    required this.sequenceNo,
    required this.modelRouteHash,
    required this.model,
    required this.promptTokens,
    required this.completionTokens,
    required this.succeeded,
    required this.costMicrousd,
    this.purpose = 'sut',
  }) {
    AgentEvaluationHashes.requireDigest(modelRouteHash, 'modelRouteHash');
    if (sequenceNo <= 0 ||
        model.trim().isEmpty ||
        promptTokens < 0 ||
        completionTokens < 0 ||
        costMicrousd < 0 ||
        !<String>{'sut', 'externalJudge'}.contains(purpose)) {
      throw ArgumentError('priced provider call is invalid');
    }
  }

  final int sequenceNo;
  final String modelRouteHash;
  final String model;
  final int promptTokens;
  final int completionTokens;
  final bool succeeded;
  final int costMicrousd;
  final String purpose;

  Map<String, Object?> toJson() => <String, Object?>{
    'sequenceNo': sequenceNo,
    'modelRouteHash': modelRouteHash,
    'model': model,
    'promptTokens': promptTokens,
    'completionTokens': completionTokens,
    'succeeded': succeeded,
    'costMicrousd': costMicrousd,
    'purpose': purpose,
  };
}

final class AgentEvaluationAttemptUsage {
  AgentEvaluationAttemptUsage({
    required this.promptTokens,
    required this.completionTokens,
    required this.costMicrousd,
  }) : priceTableHash = null,
       providerCalls = const <AgentEvaluationPricedProviderCall>[],
       providerCallSetHash = null,
       costEvidenceHash = null {
    if (promptTokens < 0 || completionTokens < 0 || costMicrousd < 0) {
      throw ArgumentError('evaluation usage values must be non-negative');
    }
  }

  factory AgentEvaluationAttemptUsage.frozen({
    required String priceTableHash,
    required Iterable<AgentEvaluationPricedProviderCall> providerCalls,
  }) {
    AgentEvaluationHashes.requireDigest(priceTableHash, 'priceTableHash');
    final calls = providerCalls.toList(growable: false);
    if (calls.isEmpty) {
      throw ArgumentError('frozen usage requires provider calls');
    }
    for (var index = 0; index < calls.length; index += 1) {
      if (calls[index].sequenceNo != index + 1) {
        throw ArgumentError('provider call sequence is not contiguous');
      }
    }
    final promptTokens = calls.fold<int>(
      0,
      (sum, call) => sum + call.promptTokens,
    );
    final completionTokens = calls.fold<int>(
      0,
      (sum, call) => sum + call.completionTokens,
    );
    final costMicrousd = calls.fold<int>(
      0,
      (sum, call) => sum + call.costMicrousd,
    );
    final callSetHash = AgentEvaluationHashes.domainHash(
      'eval-priced-provider-call-set-v1',
      <Object?>[for (final call in calls) call.toJson()],
    );
    final costHash = AgentEvaluationHashes.domainHash(
      'eval-attempt-cost-evidence-v1',
      <String, Object?>{
        'priceTableHash': priceTableHash,
        'providerCallSetHash': callSetHash,
        'promptTokens': promptTokens,
        'completionTokens': completionTokens,
        'costMicrousd': costMicrousd,
      },
    );
    return AgentEvaluationAttemptUsage._frozen(
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      costMicrousd: costMicrousd,
      priceTableHash: priceTableHash,
      providerCalls: List<AgentEvaluationPricedProviderCall>.unmodifiable(
        calls,
      ),
      providerCallSetHash: callSetHash,
      costEvidenceHash: costHash,
    );
  }

  const AgentEvaluationAttemptUsage._frozen({
    required this.promptTokens,
    required this.completionTokens,
    required this.costMicrousd,
    required this.priceTableHash,
    required this.providerCalls,
    required this.providerCallSetHash,
    required this.costEvidenceHash,
  });

  final int promptTokens;
  final int completionTokens;
  final int costMicrousd;
  final String? priceTableHash;
  final List<AgentEvaluationPricedProviderCall> providerCalls;
  final String? providerCallSetHash;
  final String? costEvidenceHash;

  bool get hasFrozenCostEvidence =>
      priceTableHash != null &&
      providerCalls.isNotEmpty &&
      providerCallSetHash != null &&
      costEvidenceHash != null;

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': hasFrozenCostEvidence
        ? 'eval-attempt-usage-v2'
        : 'eval-attempt-usage-v1',
    'promptTokens': promptTokens,
    'completionTokens': completionTokens,
    'costMicrousd': costMicrousd,
    if (hasFrozenCostEvidence) ...<String, Object?>{
      'priceTableHash': priceTableHash,
      'providerCalls': <Object?>[
        for (final call in providerCalls) call.toJson(),
      ],
      'providerCallSetHash': providerCallSetHash,
      'costEvidenceHash': costEvidenceHash,
    },
  };
}

final class AgentEvaluationQualityEvidence {
  AgentEvaluationQualityEvidence({
    required Map<String, int> scoreMicrosByDimension,
    required this.judgePromptReleaseHash,
    required this.judgeModelRouteHash,
    required this.rubricReleaseHash,
    required this.aggregatorReleaseHash,
    required this.evaluatedContentHash,
    required this.externalJudgeOutputHash,
    required this.externalEvaluationEvidenceHash,
    this.deterministicQualityReceiptHash,
    this.judgeInjectionSafetyReceipt,
  }) : scoreMicrosByDimension = Map.unmodifiable(scoreMicrosByDimension) {
    if (this.scoreMicrosByDimension.keys
            .toSet()
            .difference(AgentEvaluationQualityDimensions.values)
            .isNotEmpty ||
        AgentEvaluationQualityDimensions.values
            .difference(this.scoreMicrosByDimension.keys.toSet())
            .isNotEmpty ||
        this.scoreMicrosByDimension.values.any(
          (score) => score < 0 || score > 100000000,
        )) {
      throw ArgumentError(
        'quality evidence must contain exactly the six frozen dimensions',
      );
    }
    for (final entry in <(String, String)>[
      (judgePromptReleaseHash, 'judgePromptReleaseHash'),
      (judgeModelRouteHash, 'judgeModelRouteHash'),
      (rubricReleaseHash, 'rubricReleaseHash'),
      (aggregatorReleaseHash, 'aggregatorReleaseHash'),
      (evaluatedContentHash, 'evaluatedContentHash'),
      (externalJudgeOutputHash, 'externalJudgeOutputHash'),
      (externalEvaluationEvidenceHash, 'externalEvaluationEvidenceHash'),
      if (deterministicQualityReceiptHash != null)
        (deterministicQualityReceiptHash!, 'deterministicQualityReceiptHash'),
    ]) {
      AgentEvaluationHashes.requireDigest(entry.$1, entry.$2);
    }
    final expectedEvidenceHash = calculateExternalEvidenceHash(
      scoreMicrosByDimension: this.scoreMicrosByDimension,
      judgePromptReleaseHash: judgePromptReleaseHash,
      judgeModelRouteHash: judgeModelRouteHash,
      rubricReleaseHash: rubricReleaseHash,
      aggregatorReleaseHash: aggregatorReleaseHash,
      evaluatedContentHash: evaluatedContentHash,
      externalJudgeOutputHash: externalJudgeOutputHash,
      deterministicQualityReceiptHash: deterministicQualityReceiptHash,
      judgeInjectionSafetyReceiptHash: judgeInjectionSafetyReceipt?.receiptHash,
    );
    if (externalEvaluationEvidenceHash != expectedEvidenceHash) {
      throw StateError(
        'external evaluation evidence does not bind the frozen scores and prose',
      );
    }
    final injectionReceipt = judgeInjectionSafetyReceipt;
    if (injectionReceipt != null &&
        (injectionReceipt.evaluatedContentHash != evaluatedContentHash ||
            injectionReceipt.judgePromptReleaseHash != judgePromptReleaseHash ||
            injectionReceipt.judgeModelRouteHash != judgeModelRouteHash ||
            injectionReceipt.rubricReleaseHash != rubricReleaseHash ||
            injectionReceipt.aggregatorReleaseHash != aggregatorReleaseHash ||
            !injectionReceipt.passed)) {
      throw StateError(
        'judge injection safety receipt contradicts quality evidence',
      );
    }
  }

  final Map<String, int> scoreMicrosByDimension;
  final String judgePromptReleaseHash;
  final String judgeModelRouteHash;
  final String rubricReleaseHash;
  final String aggregatorReleaseHash;
  final String evaluatedContentHash;
  final String externalJudgeOutputHash;
  final String externalEvaluationEvidenceHash;
  final String? deterministicQualityReceiptHash;
  final AgentEvaluationJudgeInjectionSafetyReceipt? judgeInjectionSafetyReceipt;

  static String calculateExternalEvidenceHash({
    required Map<String, int> scoreMicrosByDimension,
    required String judgePromptReleaseHash,
    required String judgeModelRouteHash,
    required String rubricReleaseHash,
    required String aggregatorReleaseHash,
    required String evaluatedContentHash,
    required String externalJudgeOutputHash,
    String? deterministicQualityReceiptHash,
    String? judgeInjectionSafetyReceiptHash,
  }) => AgentEvaluationHashes.domainHash(
    judgeInjectionSafetyReceiptHash != null
        ? 'eval-external-quality-evidence-v3'
        : deterministicQualityReceiptHash == null
        ? 'eval-external-quality-evidence-v1'
        : 'eval-external-quality-evidence-v2',
    <String, Object?>{
      'scoreMicrosByDimension': <String, int>{
        for (final dimension
            in AgentEvaluationQualityDimensions.values.toList()..sort())
          dimension: scoreMicrosByDimension[dimension]!,
      },
      'judgePromptReleaseHash': judgePromptReleaseHash,
      'judgeModelRouteHash': judgeModelRouteHash,
      'rubricReleaseHash': rubricReleaseHash,
      'aggregatorReleaseHash': aggregatorReleaseHash,
      'evaluatedContentHash': evaluatedContentHash,
      'externalJudgeOutputHash': externalJudgeOutputHash,
      'deterministicQualityReceiptHash': ?deterministicQualityReceiptHash,
      'judgeInjectionSafetyReceiptHash': ?judgeInjectionSafetyReceiptHash,
    },
  );

  Map<String, Object?> valueFor(String dimensionId) => <String, Object?>{
    'schemaVersion': 'eval-quality-dimension-v1',
    'scoreMicros': scoreMicrosByDimension[dimensionId],
    'judgePromptReleaseHash': judgePromptReleaseHash,
    'judgeModelRouteHash': judgeModelRouteHash,
    'rubricReleaseHash': rubricReleaseHash,
    'aggregatorReleaseHash': aggregatorReleaseHash,
    'evaluatedContentHash': evaluatedContentHash,
    'externalJudgeOutputHash': externalJudgeOutputHash,
    'externalEvaluationEvidenceHash': externalEvaluationEvidenceHash,
    if (deterministicQualityReceiptHash != null)
      'deterministicQualityReceiptHash': deterministicQualityReceiptHash,
    if (judgeInjectionSafetyReceipt != null)
      'judgeInjectionSafetyReceipt': judgeInjectionSafetyReceipt!.toJson(),
  };
}

final class AgentEvaluationHardGateEvidence {
  AgentEvaluationHardGateEvidence({
    required this.safetyPassed,
    required this.transactionPassed,
    required this.safetyVerifierReleaseHash,
    required this.transactionVerifierReleaseHash,
    required this.safetyEvidenceHash,
    required this.transactionEvidenceHash,
  }) {
    AgentEvaluationHashes.requireDigest(
      safetyVerifierReleaseHash,
      'safetyVerifierReleaseHash',
    );
    AgentEvaluationHashes.requireDigest(
      transactionVerifierReleaseHash,
      'transactionVerifierReleaseHash',
    );
    AgentEvaluationHashes.requireDigest(
      safetyEvidenceHash,
      'safetyEvidenceHash',
    );
    AgentEvaluationHashes.requireDigest(
      transactionEvidenceHash,
      'transactionEvidenceHash',
    );
  }

  final bool safetyPassed;
  final bool transactionPassed;
  final String safetyVerifierReleaseHash;
  final String transactionVerifierReleaseHash;
  final String safetyEvidenceHash;
  final String transactionEvidenceHash;

  Map<String, Object?> valueFor(String gateKind) {
    switch (gateKind) {
      case 'safety':
        return <String, Object?>{
          'schemaVersion': 'eval-safety-gate-v1',
          'passed': safetyPassed,
          'verifierReleaseHash': safetyVerifierReleaseHash,
          'verifierEvidenceHash': safetyEvidenceHash,
        };
      case 'transaction':
        return <String, Object?>{
          'schemaVersion': 'eval-transaction-gate-v1',
          'passed': transactionPassed,
          'verifierReleaseHash': transactionVerifierReleaseHash,
          'verifierEvidenceHash': transactionEvidenceHash,
        };
      default:
        throw ArgumentError.value(gateKind, 'gateKind', 'unsupported gate');
    }
  }
}
