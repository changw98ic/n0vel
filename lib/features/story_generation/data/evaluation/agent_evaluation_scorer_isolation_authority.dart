import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../../../../app/llm/app_llm_canonical_hash.dart';
import '../../../../app/llm/app_llm_prompt_release_store.dart';
import '../generation_ledger_digest.dart';
import 'agent_evaluation_manifest.dart';
import 'agent_evaluation_production_authorities.dart';
import 'agent_evaluation_typed_evidence.dart';

class AgentEvaluationScorerIsolationAuthorityException implements Exception {
  const AgentEvaluationScorerIsolationAuthorityException(this.message);

  final String message;

  @override
  String toString() =>
      'AgentEvaluationScorerIsolationAuthorityException: $message';
}

abstract final class AgentEvaluationScorerIsolationAuthority {
  static String get releaseHash => AgentEvaluationHashes.domainHash(
    'agent-evaluation-scorer-isolation-authority-v1',
    <String, Object?>{
      'candidate': 'real-candidate-quality-payload-v3-and-proof',
      'sutClaim': 'quality-score-hash-bound-but-not-judge-input',
      'judgeAuthority':
          AgentEvaluationFrozenJudgeQualityAuthority.judgeAuthorityReleaseHash,
      'judgeInput': 'exact-opaque-untrusted-quoted-candidate',
      'decision': 'frozen-judge-subjective-scores-threshold-95-v1',
    },
  );

  static AgentEvaluationScorerIsolationProjection read({
    required Database db,
    required String runId,
    required String evaluatorBundleId,
    required String sutModelRouteHash,
    required String sutQualityScorerReleaseHash,
    required String judgeCandidateJson,
    required AgentEvaluationQualityEvidence qualityEvidence,
  }) {
    AgentEvaluationHashes.requireDigest(sutModelRouteHash, 'sutModelRouteHash');
    AgentEvaluationHashes.requireDigest(
      sutQualityScorerReleaseHash,
      'sutQualityScorerReleaseHash',
    );
    final rows = db.select(
      '''SELECT p.final_prose_hash, p.quality_evidence_hash,
                payload.final_prose, payload.quality_payload_json
         FROM story_generation_candidate_proofs p
         JOIN story_generation_candidate_payloads payload
           ON payload.run_id = p.run_id
          AND payload.candidate_revision = p.candidate_revision
         WHERE p.run_id = ?''',
      <Object?>[runId],
    );
    if (rows.length != 1) {
      throw const AgentEvaluationScorerIsolationAuthorityException(
        'SUT candidate proof is missing or ambiguous',
      );
    }
    final row = rows.single;
    final qualityPayload = _object(
      jsonDecode(row['quality_payload_json'] as String),
      'candidate quality payload',
    );
    final sutScore = _object(qualityPayload['qualityScore'], 'SUT score');
    if (qualityPayload['schemaVersion'] != 'candidate-quality-payload-v3' ||
        sutScore['overall'] is! num ||
        row['quality_evidence_hash'] !=
            GenerationLedgerDigest.object(<String, Object?>{
              'finalProseHash': row['final_prose_hash'],
              'score': sutScore,
            })) {
      throw const AgentEvaluationScorerIsolationAuthorityException(
        'SUT scorer output is not bound by the candidate proof',
      );
    }
    final candidate = _object(
      jsonDecode(judgeCandidateJson),
      'judge candidate JSON',
    );
    if (candidate.keys.toSet().difference(const <String>{
          'opaqueCandidateLabel',
          'contentType',
          'quotedContent',
        }).isNotEmpty ||
        candidate.length != 3 ||
        candidate['contentType'] != 'untrusted_quoted_candidate' ||
        candidate['quotedContent'] != row['final_prose'] ||
        qualityEvidence.evaluatedContentHash !=
            AgentEvaluationHashes.domainHash(
              'eval-trial-content-v1',
              row['final_prose'],
            ) ||
        qualityEvidence.judgeModelRouteHash == sutModelRouteHash) {
      throw const AgentEvaluationScorerIsolationAuthorityException(
        'judge input is not isolated from the SUT scorer',
      );
    }
    final bundle = AppLlmPromptReleaseStore(
      db: db,
    ).getEvaluationBundle(evaluatorBundleId);
    final promptStore = AppLlmPromptReleaseStore(db: db);
    final prompt = promptStore.getPromptRelease(
      bundle.judgePromptReleases.single,
    );
    final verifierHashes = bundle.deterministicVerifierReleases
        .map(_raw)
        .toSet();
    if (!verifierHashes.contains(
          AgentEvaluationFrozenJudgeQualityAuthority.judgeAuthorityReleaseHash,
        ) ||
        _raw(bundle.judgeModelRoutes.single) !=
            qualityEvidence.judgeModelRouteHash ||
        _raw(prompt.contentHash) != qualityEvidence.judgePromptReleaseHash ||
        _raw(bundle.rubricReleaseHash) != qualityEvidence.rubricReleaseHash ||
        _raw(bundle.aggregatorReleaseHash) !=
            qualityEvidence.aggregatorReleaseHash ||
        qualityEvidence.judgeInjectionSafetyReceipt == null ||
        !qualityEvidence.judgeInjectionSafetyReceipt!.passed) {
      throw const AgentEvaluationScorerIsolationAuthorityException(
        'independent judge authority is outside frozen bundle membership',
      );
    }
    final serializedCandidate = AppLlmCanonicalHash.canonicalJson(candidate);
    if (serializedCandidate.contains(sutQualityScorerReleaseHash) ||
        candidate.containsKey('qualityScore') ||
        candidate.containsKey('sutScore') ||
        candidate.containsKey('scorerReleaseHash')) {
      throw const AgentEvaluationScorerIsolationAuthorityException(
        'SUT scorer claim contaminated the independent judge input',
      );
    }
    final judgeSubjectiveMicros = <String, int>{
      'proseReadability':
          qualityEvidence.scoreMicrosByDimension['proseReadability']!,
      'plotCausality': qualityEvidence.scoreMicrosByDimension['plotCausality']!,
    };
    final judgeAccepted = judgeSubjectiveMicros.values.every(
      (score) => score >= 95000000,
    );
    return AgentEvaluationScorerIsolationProjection._(
      sutQualityScorerReleaseHash: sutQualityScorerReleaseHash,
      sutQualityEvidenceHash: row['quality_evidence_hash'] as String,
      sutOverallMicros: ((sutScore['overall'] as num) * 1000000).round(),
      judgeAuthorityReleaseHash:
          AgentEvaluationFrozenJudgeQualityAuthority.judgeAuthorityReleaseHash,
      judgeCandidateHash: AgentEvaluationHashes.domainHash(
        'eval-scorer-isolation-judge-candidate-v1',
        candidate,
      ),
      judgePromptReleaseHash: qualityEvidence.judgePromptReleaseHash,
      judgeModelRouteHash: qualityEvidence.judgeModelRouteHash,
      rubricReleaseHash: qualityEvidence.rubricReleaseHash,
      aggregatorReleaseHash: qualityEvidence.aggregatorReleaseHash,
      externalJudgeOutputHash: qualityEvidence.externalJudgeOutputHash,
      externalEvaluationEvidenceHash:
          qualityEvidence.externalEvaluationEvidenceHash,
      judgeInjectionReceiptHash:
          qualityEvidence.judgeInjectionSafetyReceipt!.receiptHash,
      judgeSubjectiveMicros: judgeSubjectiveMicros,
      judgeAccepted: judgeAccepted,
    );
  }

  static Map<String, Object?> _object(Object? value, String label) {
    if (value is Map<String, Object?>) return value;
    throw AgentEvaluationScorerIsolationAuthorityException(
      '$label is not an object',
    );
  }

  static String _raw(String value) =>
      value.startsWith('sha256:') ? value.substring(7) : value;
}

final class AgentEvaluationScorerIsolationProjection {
  AgentEvaluationScorerIsolationProjection._({
    required this.sutQualityScorerReleaseHash,
    required this.sutQualityEvidenceHash,
    required this.sutOverallMicros,
    required this.judgeAuthorityReleaseHash,
    required this.judgeCandidateHash,
    required this.judgePromptReleaseHash,
    required this.judgeModelRouteHash,
    required this.rubricReleaseHash,
    required this.aggregatorReleaseHash,
    required this.externalJudgeOutputHash,
    required this.externalEvaluationEvidenceHash,
    required this.judgeInjectionReceiptHash,
    required this.judgeSubjectiveMicros,
    required this.judgeAccepted,
  });

  final String sutQualityScorerReleaseHash;
  final String sutQualityEvidenceHash;
  final int sutOverallMicros;
  final String judgeAuthorityReleaseHash;
  final String judgeCandidateHash;
  final String judgePromptReleaseHash;
  final String judgeModelRouteHash;
  final String rubricReleaseHash;
  final String aggregatorReleaseHash;
  final String externalJudgeOutputHash;
  final String externalEvaluationEvidenceHash;
  final String judgeInjectionReceiptHash;
  final Map<String, int> judgeSubjectiveMicros;
  final bool judgeAccepted;

  Map<String, Object?> toReportMap() => <String, Object?>{
    'schemaVersion': 'agent-evaluation-scorer-isolation-projection-v1',
    'authorityReleaseHash': AgentEvaluationScorerIsolationAuthority.releaseHash,
    'sutQualityScorerReleaseHash': sutQualityScorerReleaseHash,
    'sutQualityEvidenceHash': sutQualityEvidenceHash,
    'sutOverallMicros': sutOverallMicros,
    'judgeAuthorityReleaseHash': judgeAuthorityReleaseHash,
    'judgeCandidateHash': judgeCandidateHash,
    'judgePromptReleaseHash': judgePromptReleaseHash,
    'judgeModelRouteHash': judgeModelRouteHash,
    'rubricReleaseHash': rubricReleaseHash,
    'aggregatorReleaseHash': aggregatorReleaseHash,
    'externalJudgeOutputHash': externalJudgeOutputHash,
    'externalEvaluationEvidenceHash': externalEvaluationEvidenceHash,
    'judgeInjectionReceiptHash': judgeInjectionReceiptHash,
    'judgeSubjectiveMicros': judgeSubjectiveMicros,
    'judgeAccepted': judgeAccepted,
    'projectionHash': projectionHash,
  };

  String get projectionHash => AgentEvaluationHashes.domainHash(
    'agent-evaluation-scorer-isolation-projection-v1',
    <String, Object?>{
      'sutQualityScorerReleaseHash': sutQualityScorerReleaseHash,
      'sutQualityEvidenceHash': sutQualityEvidenceHash,
      'sutOverallMicros': sutOverallMicros,
      'judgeAuthorityReleaseHash': judgeAuthorityReleaseHash,
      'judgeCandidateHash': judgeCandidateHash,
      'judgePromptReleaseHash': judgePromptReleaseHash,
      'judgeModelRouteHash': judgeModelRouteHash,
      'rubricReleaseHash': rubricReleaseHash,
      'aggregatorReleaseHash': aggregatorReleaseHash,
      'externalJudgeOutputHash': externalJudgeOutputHash,
      'externalEvaluationEvidenceHash': externalEvaluationEvidenceHash,
      'judgeInjectionReceiptHash': judgeInjectionReceiptHash,
      'judgeSubjectiveMicros': judgeSubjectiveMicros,
      'judgeAccepted': judgeAccepted,
    },
  );
}
