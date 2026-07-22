import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_canonical_hash.dart';
import 'package:novel_writer/features/story_generation/data/generation_evidence_receipt.dart';

import 'test_support/generation_evidence_receipt_fixture.dart';

void main() {
  group('generation receipt final-prose source binding', () {
    late GenerationEvidenceReceipt receipt;

    setUpAll(() async {
      final fixture = await prepareGenerationEvidenceReceiptFixture(
        evidenceRunId: 'receipt-source-binding-run-v2',
        sceneId: 'receipt-source-binding-scene-v2',
        artifactText: '同一段正文必须保留确切来源。',
        evaluatedArtifactText: '同一段正文必须保留确切来源。',
      );
      receipt = fixture.issue();
    });

    test('v2 restart preserves the exact language-polish source', () {
      expect(
        receipt.toJson()['schemaVersion'],
        GenerationEvidenceReceipt.schemaVersion,
      );
      expect(GenerationEvidenceReceipt.schemaVersion, contains('v2'));
      expect(receipt.finalProseSource['callSiteId'], 'language-polish');
      expect(
        receipt.finalProseSource['logicalAttemptId'],
        matches(r'^sha256:[0-9a-f]{64}$'),
      );

      final reloaded = GenerationEvidenceReceipt.fromCanonicalJson(
        receipt.canonicalJson,
      );

      expect(reloaded.receiptHash, receipt.receiptHash);
      expect(reloaded.finalProseSource, receipt.finalProseSource);
      expect(
        reloaded.attemptEvidenceEnvelopeDigest,
        receipt.attemptEvidenceEnvelopeDigest,
      );
      expect(reloaded.proofAdmission, isNull);
      expect(
        () => reloaded.finalProseSource['callSiteId'] = 'judge',
        throwsUnsupportedError,
      );
    });

    test('source is covered by the receipt hash', () {
      final original = receipt.toJson();
      final originalPayload = Map<String, Object?>.from(original)
        ..remove('receiptHash');
      final relabeled = _deepCopy(original);
      (relabeled['finalProseSource']! as Map<String, Object?>)['callSiteId'] =
          'scene-editorial-generator';
      final relabeledPayload = Map<String, Object?>.from(relabeled)
        ..remove('receiptHash');

      expect(
        AppLlmCanonicalHash.domainHash(
          GenerationEvidenceReceipt.receiptDomainTag,
          originalPayload,
        ),
        receipt.receiptHash,
      );
      expect(
        AppLlmCanonicalHash.domainHash(
          GenerationEvidenceReceipt.receiptDomainTag,
          relabeledPayload,
        ),
        isNot(receipt.receiptHash),
      );
    });

    test('missing source and legacy v1 receipts cannot reload', () {
      final missing = _deepCopy(receipt.toJson())..remove('finalProseSource');
      expect(
        () => GenerationEvidenceReceipt.fromCanonicalJson(
          _resealCanonical(missing),
        ),
        throwsStateError,
      );

      final legacy = _deepCopy(receipt.toJson())
        ..['schemaVersion'] = 'story-generation-evidence-receipt-v1';
      expect(
        () => GenerationEvidenceReceipt.fromCanonicalJson(
          _resealCanonical(legacy),
        ),
        throwsStateError,
      );
    });

    test('source relabel and unknown source id cannot reload', () {
      final source = Map<String, Object?>.from(
        receipt.toJson()['finalProseSource']! as Map,
      );
      final relabeled = _deepCopy(receipt.toJson());
      relabeled['finalProseSource'] = <String, Object?>{
        'logicalAttemptId': source['logicalAttemptId'],
        'callSiteId': 'scene-editorial-generator',
      };
      expect(
        () => GenerationEvidenceReceipt.fromCanonicalJson(
          _resealCanonical(relabeled),
        ),
        throwsStateError,
      );

      final unknown = _deepCopy(receipt.toJson());
      unknown['finalProseSource'] = <String, Object?>{
        'logicalAttemptId': _hash('unknown-final-prose-source'),
        'callSiteId': 'language-polish',
      };
      expect(
        () => GenerationEvidenceReceipt.fromCanonicalJson(
          _resealCanonical(unknown),
        ),
        throwsStateError,
      );
    });

    test('quality scorer and review outputs cannot impersonate prose', () {
      final receiptJson = receipt.toJson();
      final privateRecord = Map<String, Object?>.from(
        receiptJson['private']! as Map,
      );
      final outcomes = (privateRecord['outcomes']! as List)
          .map((value) => Map<String, Object?>.from(value as Map))
          .toList(growable: false);
      final scorer = outcomes.singleWhere(
        (outcome) => outcome['callSiteId'] == 'quality-scorer',
      );

      final scorerImpostor = _deepCopy(receiptJson);
      scorerImpostor['finalProseSource'] = <String, Object?>{
        'logicalAttemptId': scorer['logicalAttemptId'],
        // Use an allowed label to prove that the parser also checks the
        // selected outcome's actual callsite, not only a top-level allowlist.
        'callSiteId': 'language-polish',
      };
      expect(
        () => GenerationEvidenceReceipt.fromCanonicalJson(
          _resealCanonical(scorerImpostor),
        ),
        throwsStateError,
      );

      final reviewImpostor = _deepCopy(receiptJson);
      reviewImpostor['finalProseSource'] = <String, Object?>{
        'logicalAttemptId': scorer['logicalAttemptId'],
        'callSiteId': 'judge',
      };
      expect(
        () => GenerationEvidenceReceipt.fromCanonicalJson(
          _resealCanonical(reviewImpostor),
        ),
        throwsStateError,
      );

      final scorerArtifactImpostor = _deepCopy(receiptJson);
      scorerArtifactImpostor['sealedArtifactDigest'] =
          Map<String, Object?>.from(scorer['artifactDigest']! as Map);
      expect(
        () => GenerationEvidenceReceipt.fromCanonicalJson(
          _resealCanonical(scorerArtifactImpostor),
        ),
        throwsStateError,
      );
    });

    test('duplicate logical outcome identity is rejected after restart', () {
      final duplicate = _deepCopy(receipt.toJson());
      final privateRecord = Map<String, Object?>.from(
        duplicate['private']! as Map,
      );
      duplicate['private'] = privateRecord;
      final intents = List<Object?>.from(privateRecord['intents']! as List);
      final outcomes = List<Object?>.from(privateRecord['outcomes']! as List);
      privateRecord['intents'] = intents;
      privateRecord['outcomes'] = outcomes;
      final duplicateIntent = Map<String, Object?>.from(intents.first! as Map)
        ..['sequenceNo'] = intents.length;
      final duplicateOutcome = Map<String, Object?>.from(outcomes.first! as Map)
        ..['sequenceNo'] = outcomes.length;
      intents.add(duplicateIntent);
      outcomes.add(duplicateOutcome);

      expect(
        () => GenerationEvidenceReceipt.fromCanonicalJson(
          _resealCanonical(duplicate),
        ),
        throwsStateError,
      );
    });
  });
}

Map<String, Object?> _deepCopy(Map<String, Object?> value) =>
    Map<String, Object?>.from(jsonDecode(jsonEncode(value))! as Map);

String _resealCanonical(Map<String, Object?> value) {
  final payload = Map<String, Object?>.from(value)..remove('receiptHash');
  return AppLlmCanonicalHash.canonicalJson(<String, Object?>{
    ...payload,
    'receiptHash': AppLlmCanonicalHash.domainHash(
      GenerationEvidenceReceipt.receiptDomainTag,
      payload,
    ),
  });
}

String _hash(String value) => AppLlmCanonicalHash.domainHash(
  'generation-receipt-source-binding-test-v1',
  <String, Object?>{'value': value},
);
