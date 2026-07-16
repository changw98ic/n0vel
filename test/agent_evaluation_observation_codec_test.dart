import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_manifest.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_observation_codec.dart';

void main() {
  group('AgentEvaluationObservationCodecRegistry', () {
    test('accepts canonical frozen usage v2 evidence', () {
      final value = _usageV2();

      final decoded = AgentEvaluationObservationCodecRegistry.decode(
        stageId: 'performance',
        kind: 'usage',
        itemKey: 'singleton',
        valueJson: AgentEvaluationHashes.canonicalJson(value),
      );

      expect(decoded.type, 'performance/usage');
      expect(decoded.value, value);
    });

    test('accepts a canonical production receipt', () {
      final value = _productionReceipt();

      final decoded = AgentEvaluationObservationCodecRegistry.decode(
        stageId: 'production',
        kind: 'receipt',
        itemKey: 'singleton',
        proseHash: _digest('9'),
        valueJson: AgentEvaluationHashes.canonicalJson(value),
      );

      expect(decoded.type, 'production/receipt');
      expect(decoded.value, value);
    });

    test('rejects an unknown observation type', () {
      expect(
        () => AgentEvaluationObservationCodecRegistry.decode(
          stageId: 'provider',
          kind: 'raw-response',
          itemKey: 'singleton',
          valueJson: '{}',
        ),
        throwsA(isA<AgentEvaluationObservationCodecException>()),
      );
    });

    test('rejects extra fields in an otherwise valid DTO', () {
      final value = <String, Object?>{
        ..._usageV1(),
        'rawResponse': 'provider-body',
      };

      expect(
        () => AgentEvaluationObservationCodecRegistry.decode(
          stageId: 'performance',
          kind: 'usage',
          itemKey: 'singleton',
          valueJson: AgentEvaluationHashes.canonicalJson(value),
        ),
        throwsA(isA<AgentEvaluationObservationCodecException>()),
      );
    });

    test('rejects non-canonical JSON', () {
      expect(
        () => AgentEvaluationObservationCodecRegistry.decode(
          stageId: 'performance',
          kind: 'usage',
          itemKey: 'singleton',
          valueJson:
              '{"schemaVersion":"eval-attempt-usage-v1", '
              '"promptTokens":1,"completionTokens":2,"costMicrousd":0}',
        ),
        throwsA(isA<AgentEvaluationObservationCodecException>()),
      );
    });

    test('rejects observations larger than 64 KiB', () {
      final oversized = <String, Object?>{
        'primary': 'provider.failure',
        'labels': <String>['x' * 65536],
      };

      expect(
        () => AgentEvaluationObservationCodecRegistry.decode(
          stageId: 'failure',
          kind: 'taxonomy',
          itemKey: 'singleton',
          valueJson: AgentEvaluationHashes.canonicalJson(oversized),
        ),
        throwsA(isA<AgentEvaluationObservationCodecException>()),
      );
    });

    test('rejects secret or tainted material before persistence', () {
      final tainted = <String, Object?>{
        ..._usageV1(),
        'authorization': 'Bearer private-token',
      };

      expect(
        () => AgentEvaluationObservationCodecRegistry.decode(
          stageId: 'performance',
          kind: 'usage',
          itemKey: 'singleton',
          valueJson: AgentEvaluationHashes.canonicalJson(tainted),
        ),
        throwsA(isA<AgentEvaluationObservationCodecException>()),
      );
    });
  });
}

Map<String, Object?> _usageV1() => <String, Object?>{
  'schemaVersion': 'eval-attempt-usage-v1',
  'promptTokens': 1,
  'completionTokens': 2,
  'costMicrousd': 0,
};

Map<String, Object?> _usageV2() {
  final calls = <Object?>[
    <String, Object?>{
      'sequenceNo': 1,
      'modelRouteHash': _digest('1'),
      'model': 'glm-4.7-flash',
      'promptTokens': 10,
      'completionTokens': 5,
      'succeeded': true,
      'costMicrousd': 0,
      'purpose': 'sut',
    },
  ];
  final callSetHash = AgentEvaluationHashes.domainHash(
    'eval-priced-provider-call-set-v1',
    calls,
  );
  return <String, Object?>{
    'schemaVersion': 'eval-attempt-usage-v2',
    'promptTokens': 10,
    'completionTokens': 5,
    'costMicrousd': 0,
    'priceTableHash': _digest('2'),
    'providerCalls': calls,
    'providerCallSetHash': callSetHash,
    'costEvidenceHash': AgentEvaluationHashes.domainHash(
      'eval-attempt-cost-evidence-v1',
      <String, Object?>{
        'priceTableHash': _digest('2'),
        'providerCallSetHash': callSetHash,
        'promptTokens': 10,
        'completionTokens': 5,
        'costMicrousd': 0,
      },
    ),
  };
}

Map<String, Object?> _productionReceipt() => <String, Object?>{
  'schemaVersion': 'eval-production-receipt-v2',
  'authorityReceiptHash': _digest('1'),
  'authorityReleaseHash': _digest('2'),
  'executorReleaseHash': _digest('3'),
  'attemptRunId': 'attempt-run-1',
  'storyRunId': 'attempt-run-1',
  'candidateHash': _digest('4'),
  'receiptId': 'receipt-1',
  'transactionEvidenceHash': _digest('5'),
  'proseHash': _digest('9'),
  'generationBundleHash': _digest('6'),
};

String _digest(String character) => List<String>.filled(64, character).join();
