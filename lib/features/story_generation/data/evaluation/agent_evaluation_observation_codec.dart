import 'dart:convert';

import 'agent_evaluation_manifest.dart';
import 'agent_evaluation_typed_evidence.dart';

class AgentEvaluationObservationCodecException implements Exception {
  const AgentEvaluationObservationCodecException(this.message);

  final String message;

  @override
  String toString() => 'AgentEvaluationObservationCodecException: $message';
}

final class AgentEvaluationDecodedObservation {
  const AgentEvaluationDecodedObservation({
    required this.type,
    required this.value,
  });

  final String type;
  final Map<String, Object?> value;
}

/// The only schema registry permitted at the evaluation observation sink.
///
/// Provider responses, prompts, private fixtures, and exception text are
/// tainted inputs. None of the registered schemas contains a raw-text field;
/// callers must project such material to a frozen code or digest first.
abstract final class AgentEvaluationObservationCodecRegistry {
  static const maximumObservationBytes = 64 * 1024;

  static const supportedTypes = <String>{
    'outcome/comparison',
    'quality/dimension',
    'quality/judge-injection',
    'performance/usage',
    'failure/taxonomy',
    'hard-gate/safety',
    'hard-gate/transaction',
    'production/receipt',
  };

  static AgentEvaluationDecodedObservation decode({
    required String stageId,
    required String kind,
    required String itemKey,
    required String valueJson,
    String? proseHash,
  }) {
    final type = '$stageId/$kind';
    if (!supportedTypes.contains(type)) {
      throw AgentEvaluationObservationCodecException(
        'unknown observation type: $type',
      );
    }
    if (utf8.encode(valueJson).length > maximumObservationBytes) {
      throw const AgentEvaluationObservationCodecException(
        'observation exceeds the frozen size limit',
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(valueJson);
    } on Object {
      throw const AgentEvaluationObservationCodecException(
        'observation is not valid JSON',
      );
    }
    if (decoded is! Map<String, Object?>) {
      throw const AgentEvaluationObservationCodecException(
        'observation must be a JSON object',
      );
    }
    if (AgentEvaluationHashes.canonicalJson(decoded) != valueJson) {
      throw const AgentEvaluationObservationCodecException(
        'observation JSON is not canonical',
      );
    }
    rejectSecretOrTainted(decoded);
    switch (type) {
      case 'outcome/comparison':
        _validateOutcome(decoded, itemKey: itemKey, proseHash: proseHash);
      case 'quality/dimension':
        _validateQuality(decoded, itemKey: itemKey, proseHash: proseHash);
      case 'quality/judge-injection':
        _validateJudgeInjectionReceipt(decoded, itemKey: itemKey);
      case 'performance/usage':
        _validateUsage(decoded, itemKey: itemKey);
      case 'failure/taxonomy':
        _validateFailure(decoded, itemKey: itemKey);
      case 'hard-gate/safety':
      case 'hard-gate/transaction':
        _validateHardGate(
          decoded,
          type: type,
          itemKey: itemKey,
          proseHash: proseHash,
        );
      case 'production/receipt':
        _validateProductionReceipt(
          decoded,
          itemKey: itemKey,
          proseHash: proseHash,
        );
    }
    return AgentEvaluationDecodedObservation(
      type: type,
      value: Map<String, Object?>.unmodifiable(decoded),
    );
  }

  static void rejectSecretOrTainted(Object? value) {
    const forbiddenKeys = <String>{
      'authorization',
      'apikey',
      'secret',
      'password',
      'cookie',
      'accesstoken',
      'rawresponse',
      'providerresponse',
      'rawerror',
      'exception',
      'stacktrace',
      'prompt',
      'prose',
      'content',
      'text',
      'memory',
      'privatememory',
      'taint',
      'tainted',
    };
    if (value is Map<Object?, Object?>) {
      for (final entry in value.entries) {
        final normalized = entry.key.toString().toLowerCase().replaceAll(
          RegExp('[^a-z0-9]'),
          '',
        );
        if (forbiddenKeys.contains(normalized)) {
          throw AgentEvaluationObservationCodecException(
            'secret or tainted field is forbidden: ${entry.key}',
          );
        }
        rejectSecretOrTainted(entry.value);
      }
      return;
    }
    if (value is Iterable<Object?>) {
      for (final item in value) {
        rejectSecretOrTainted(item);
      }
      return;
    }
    if (value is String &&
        (RegExp(r'\bauthorization\s*:', caseSensitive: false).hasMatch(value) ||
            RegExp(r'\bbearer\s+\S+', caseSensitive: false).hasMatch(value) ||
            RegExp(
              r'\b(?:api[-_ ]?key|password|secret)\s*[:=]\s*\S+',
              caseSensitive: false,
            ).hasMatch(value) ||
            RegExp(
              r'\bsk-[a-z0-9_-]{8,}',
              caseSensitive: false,
            ).hasMatch(value) ||
            RegExp(
              r'-----BEGIN [A-Z ]*PRIVATE KEY-----',
              caseSensitive: false,
            ).hasMatch(value))) {
      throw const AgentEvaluationObservationCodecException(
        'secret or tainted string is forbidden',
      );
    }
  }

  static void _validateOutcome(
    Map<String, Object?> value, {
    required String itemKey,
    required String? proseHash,
  }) {
    _requireSingleton(itemKey);
    _requireExactKeys(value, const <String>{
      'terminalState',
      'failureCodes',
      'accepted',
      'sideEffectCounts',
      'evidenceComplete',
      'contentDigest',
      'independence',
      'isolationTrialId',
      'cacheSourceTrialSlotId',
      'productionStoryRunId',
      'productionCandidateHash',
      'productionReceiptId',
      'violations',
    });
    _requireEnum(value['terminalState'], const <String>{
      'accepted',
      'blocked',
      'rejected',
      'conflict',
      'failed',
    }, 'terminalState');
    _requireBool(value['accepted'], 'accepted');
    _requireBool(value['evidenceComplete'], 'evidenceComplete');
    _requireCodeList(value['failureCodes'], 'failureCodes');
    _requireCodeList(value['violations'], 'violations');
    final sideEffects = value['sideEffectCounts'];
    if (sideEffects is! Map<String, Object?> || sideEffects.length > 64) {
      throw const AgentEvaluationObservationCodecException(
        'sideEffectCounts is invalid',
      );
    }
    for (final entry in sideEffects.entries) {
      _requireCode(entry.key, 'sideEffectCounts key');
      _requireNonNegativeInt(entry.value, 'sideEffectCounts value');
    }
    final contentDigest = value['contentDigest'];
    if (contentDigest != null) {
      _requireDigest(contentDigest, 'contentDigest');
      if (proseHash == null || proseHash != contentDigest) {
        throw const AgentEvaluationObservationCodecException(
          'outcome prose digest does not match its row',
        );
      }
    } else if (proseHash != null) {
      throw const AgentEvaluationObservationCodecException(
        'outcome row has prose without a content digest',
      );
    }
    _requireEnum(value['independence'], const <String>{
      'independent',
      'nonIndependent',
    }, 'independence');
    _requireIdentifier(value['isolationTrialId'], 'isolationTrialId');
    _requireNullableIdentifier(
      value['cacheSourceTrialSlotId'],
      'cacheSourceTrialSlotId',
    );
    _requireNullableIdentifier(
      value['productionStoryRunId'],
      'productionStoryRunId',
    );
    final candidateHash = value['productionCandidateHash'];
    if (candidateHash != null) {
      _requireDigest(
        candidateHash,
        'productionCandidateHash',
        allowPrefixed: true,
      );
    }
    _requireNullableIdentifier(
      value['productionReceiptId'],
      'productionReceiptId',
    );
  }

  static void _validateQuality(
    Map<String, Object?> value, {
    required String itemKey,
    required String? proseHash,
  }) {
    if (!AgentEvaluationQualityDimensions.values.contains(itemKey)) {
      throw const AgentEvaluationObservationCodecException(
        'unknown quality dimension',
      );
    }
    _requireExactKeys(
      value,
      const <String>{
        'schemaVersion',
        'scoreMicros',
        'judgePromptReleaseHash',
        'judgeModelRouteHash',
        'rubricReleaseHash',
        'aggregatorReleaseHash',
        'evaluatedContentHash',
        'externalJudgeOutputHash',
        'externalEvaluationEvidenceHash',
      },
      optional: const <String>{
        'deterministicQualityReceiptHash',
        'judgeInjectionSafetyReceipt',
      },
    );
    if (value['schemaVersion'] != 'eval-quality-dimension-v1') {
      throw const AgentEvaluationObservationCodecException(
        'quality schema version is invalid',
      );
    }
    final score = _requireNonNegativeInt(value['scoreMicros'], 'scoreMicros');
    if (score > 100000000) {
      throw const AgentEvaluationObservationCodecException(
        'quality score is out of range',
      );
    }
    for (final key in <String>[
      'judgePromptReleaseHash',
      'judgeModelRouteHash',
      'rubricReleaseHash',
      'aggregatorReleaseHash',
      'evaluatedContentHash',
      'externalJudgeOutputHash',
      'externalEvaluationEvidenceHash',
      if (value.containsKey('deterministicQualityReceiptHash'))
        'deterministicQualityReceiptHash',
    ]) {
      _requireDigest(value[key], key);
    }
    if (proseHash == null || value['evaluatedContentHash'] != proseHash) {
      throw const AgentEvaluationObservationCodecException(
        'quality evidence is not bound to its prose row',
      );
    }
    if (value['judgeInjectionSafetyReceipt']
        case final Map<String, Object?> receipt) {
      final decoded = AgentEvaluationJudgeInjectionSafetyReceipt.fromJson(
        receipt,
      );
      if (!decoded.passed ||
          decoded.evaluatedContentHash != proseHash ||
          decoded.judgePromptReleaseHash != value['judgePromptReleaseHash'] ||
          decoded.judgeModelRouteHash != value['judgeModelRouteHash'] ||
          decoded.rubricReleaseHash != value['rubricReleaseHash'] ||
          decoded.aggregatorReleaseHash != value['aggregatorReleaseHash']) {
        throw const AgentEvaluationObservationCodecException(
          'judge injection safety receipt contradicts quality evidence',
        );
      }
    } else if (value.containsKey('judgeInjectionSafetyReceipt')) {
      throw const AgentEvaluationObservationCodecException(
        'judge injection safety receipt is malformed',
      );
    }
  }

  static void _validateUsage(
    Map<String, Object?> value, {
    required String itemKey,
  }) {
    _requireSingleton(itemKey);
    final schema = value['schemaVersion'];
    if (schema == 'eval-attempt-usage-v1') {
      _requireExactKeys(value, const <String>{
        'schemaVersion',
        'promptTokens',
        'completionTokens',
        'costMicrousd',
      });
      _requireNonNegativeInt(value['promptTokens'], 'promptTokens');
      _requireNonNegativeInt(value['completionTokens'], 'completionTokens');
      _requireNonNegativeInt(value['costMicrousd'], 'costMicrousd');
      return;
    }
    if (schema != 'eval-attempt-usage-v2') {
      throw const AgentEvaluationObservationCodecException(
        'usage schema version is invalid',
      );
    }
    _requireExactKeys(value, const <String>{
      'schemaVersion',
      'promptTokens',
      'completionTokens',
      'costMicrousd',
      'priceTableHash',
      'providerCalls',
      'providerCallSetHash',
      'costEvidenceHash',
    });
    final promptTokens = _requireNonNegativeInt(
      value['promptTokens'],
      'promptTokens',
    );
    final completionTokens = _requireNonNegativeInt(
      value['completionTokens'],
      'completionTokens',
    );
    final costMicrousd = _requireNonNegativeInt(
      value['costMicrousd'],
      'costMicrousd',
    );
    final priceTableHash = _requireDigest(
      value['priceTableHash'],
      'priceTableHash',
    );
    final calls = value['providerCalls'];
    if (calls is! List<Object?> || calls.isEmpty || calls.length > 4096) {
      throw const AgentEvaluationObservationCodecException(
        'providerCalls is invalid',
      );
    }
    var callPromptTokens = 0;
    var callCompletionTokens = 0;
    var callCost = 0;
    for (var index = 0; index < calls.length; index += 1) {
      final call = calls[index];
      if (call is! Map<String, Object?>) {
        throw const AgentEvaluationObservationCodecException(
          'provider call is not an object',
        );
      }
      _requireExactKeys(call, const <String>{
        'sequenceNo',
        'modelRouteHash',
        'model',
        'promptTokens',
        'completionTokens',
        'succeeded',
        'costMicrousd',
        'purpose',
      });
      if (call['sequenceNo'] != index + 1) {
        throw const AgentEvaluationObservationCodecException(
          'provider call sequence is not contiguous',
        );
      }
      _requireDigest(call['modelRouteHash'], 'modelRouteHash');
      _requireIdentifier(call['model'], 'model', maximumLength: 128);
      callPromptTokens += _requireNonNegativeInt(
        call['promptTokens'],
        'provider promptTokens',
      );
      callCompletionTokens += _requireNonNegativeInt(
        call['completionTokens'],
        'provider completionTokens',
      );
      _requireBool(call['succeeded'], 'succeeded');
      callCost += _requireNonNegativeInt(
        call['costMicrousd'],
        'provider costMicrousd',
      );
      _requireEnum(call['purpose'], const <String>{
        'sut',
        'externalJudge',
      }, 'purpose');
    }
    if (promptTokens != callPromptTokens ||
        completionTokens != callCompletionTokens ||
        costMicrousd != callCost) {
      throw const AgentEvaluationObservationCodecException(
        'usage totals do not match provider calls',
      );
    }
    final callSetHash = AgentEvaluationHashes.domainHash(
      'eval-priced-provider-call-set-v1',
      calls,
    );
    if (value['providerCallSetHash'] != callSetHash) {
      throw const AgentEvaluationObservationCodecException(
        'provider call set hash is invalid',
      );
    }
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
    if (value['costEvidenceHash'] != costHash) {
      throw const AgentEvaluationObservationCodecException(
        'cost evidence hash is invalid',
      );
    }
  }

  static void _validateJudgeInjectionReceipt(
    Map<String, Object?> value, {
    required String itemKey,
  }) {
    _requireSingleton(itemKey);
    AgentEvaluationJudgeInjectionSafetyReceipt.fromJson(value);
  }

  static void _validateFailure(
    Map<String, Object?> value, {
    required String itemKey,
  }) {
    _requireSingleton(itemKey);
    _requireExactKeys(value, const <String>{'primary', 'labels'});
    _requireCode(value['primary'], 'primary');
    _requireCodeList(value['labels'], 'labels');
  }

  static void _validateHardGate(
    Map<String, Object?> value, {
    required String type,
    required String itemKey,
    required String? proseHash,
  }) {
    _requireSingleton(itemKey);
    _requireExactKeys(value, const <String>{
      'schemaVersion',
      'passed',
      'verifierReleaseHash',
      'verifierEvidenceHash',
    });
    final expectedSchema = type == 'hard-gate/safety'
        ? 'eval-safety-gate-v1'
        : 'eval-transaction-gate-v1';
    if (value['schemaVersion'] != expectedSchema) {
      throw const AgentEvaluationObservationCodecException(
        'hard-gate schema version is invalid',
      );
    }
    _requireBool(value['passed'], 'passed');
    _requireDigest(value['verifierReleaseHash'], 'verifierReleaseHash');
    _requireDigest(value['verifierEvidenceHash'], 'verifierEvidenceHash');
    if (proseHash == null) {
      throw const AgentEvaluationObservationCodecException(
        'hard-gate evidence requires a prose row',
      );
    }
    _requireDigest(proseHash, 'proseHash');
  }

  static void _validateProductionReceipt(
    Map<String, Object?> value, {
    required String itemKey,
    required String? proseHash,
  }) {
    _requireSingleton(itemKey);
    _requireExactKeys(value, const <String>{
      'schemaVersion',
      'authorityReceiptHash',
      'authorityReleaseHash',
      'executorReleaseHash',
      'attemptRunId',
      'storyRunId',
      'candidateHash',
      'receiptId',
      'transactionEvidenceHash',
      'proseHash',
      'generationBundleHash',
    });
    if (value['schemaVersion'] != 'eval-production-receipt-v2') {
      throw const AgentEvaluationObservationCodecException(
        'production receipt schema version is invalid',
      );
    }
    for (final key in <String>[
      'authorityReceiptHash',
      'authorityReleaseHash',
      'executorReleaseHash',
      'transactionEvidenceHash',
      'proseHash',
      'generationBundleHash',
    ]) {
      _requireDigest(value[key], key);
    }
    _requireDigest(
      value['candidateHash'],
      'candidateHash',
      allowPrefixed: true,
    );
    _requireIdentifier(value['attemptRunId'], 'attemptRunId');
    _requireIdentifier(value['storyRunId'], 'storyRunId');
    _requireIdentifier(value['receiptId'], 'receiptId');
    if (value['attemptRunId'] != value['storyRunId']) {
      throw const AgentEvaluationObservationCodecException(
        'production receipt run identity is inconsistent',
      );
    }
    if (proseHash == null || value['proseHash'] != proseHash) {
      throw const AgentEvaluationObservationCodecException(
        'production receipt is not bound to its prose row',
      );
    }
  }

  static void _requireExactKeys(
    Map<String, Object?> value,
    Set<String> required, {
    Set<String> optional = const <String>{},
  }) {
    final keys = value.keys.toSet();
    if (required.difference(keys).isNotEmpty ||
        keys.difference(<String>{...required, ...optional}).isNotEmpty) {
      throw const AgentEvaluationObservationCodecException(
        'observation fields do not match the frozen schema',
      );
    }
  }

  static void _requireSingleton(String itemKey) {
    if (itemKey != 'singleton') {
      throw const AgentEvaluationObservationCodecException(
        'observation requires singleton itemKey',
      );
    }
  }

  static int _requireNonNegativeInt(Object? value, String field) {
    if (value is! int || value < 0) {
      throw AgentEvaluationObservationCodecException('$field is invalid');
    }
    return value;
  }

  static void _requireBool(Object? value, String field) {
    if (value is! bool) {
      throw AgentEvaluationObservationCodecException('$field is invalid');
    }
  }

  static String _requireDigest(
    Object? value,
    String field, {
    bool allowPrefixed = false,
  }) {
    final pattern = allowPrefixed
        ? RegExp(r'^(?:sha256:)?[a-f0-9]{64}$')
        : RegExp(r'^[a-f0-9]{64}$');
    if (value is! String || !pattern.hasMatch(value)) {
      throw AgentEvaluationObservationCodecException('$field is not a digest');
    }
    return value;
  }

  static void _requireEnum(Object? value, Set<String> allowed, String field) {
    if (value is! String || !allowed.contains(value)) {
      throw AgentEvaluationObservationCodecException('$field is invalid');
    }
  }

  static void _requireIdentifier(
    Object? value,
    String field, {
    int maximumLength = 256,
  }) {
    if (value is! String ||
        value.isEmpty ||
        value.length > maximumLength ||
        !RegExp(r'^[A-Za-z0-9._:@/+\-=]+$').hasMatch(value)) {
      throw AgentEvaluationObservationCodecException('$field is invalid');
    }
  }

  static void _requireNullableIdentifier(Object? value, String field) {
    if (value != null) _requireIdentifier(value, field);
  }

  static void _requireCode(Object? value, String field) {
    if (value is! String ||
        value.isEmpty ||
        value.length > 128 ||
        !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(value)) {
      throw AgentEvaluationObservationCodecException('$field is invalid');
    }
  }

  static void _requireCodeList(Object? value, String field) {
    if (value is! List<Object?> || value.length > 64) {
      throw AgentEvaluationObservationCodecException('$field is invalid');
    }
    for (final item in value) {
      _requireCode(item, field);
    }
    if (value.toSet().length != value.length) {
      throw AgentEvaluationObservationCodecException('$field has duplicates');
    }
  }
}
