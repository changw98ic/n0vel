import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../../domain/evaluation/pass3_evaluation.dart';
import 'agent_evaluation_manifest.dart';

class AgentEvaluationPass3Projection {
  const AgentEvaluationPass3Projection({
    required this.trialResults,
    required this.result,
    required this.allSlotsSealed,
  });

  final Map<int, String> trialResults;
  final Pass3Result result;
  final bool allSlotsSealed;
}

/// Reconstructs Pass³ exclusively from sealed canonical slots and their
/// hash-bound outcome observations. Both runner and public report use this
/// projection so a hand-written `result = pass` row is never sufficient.
class AgentEvaluationPass3ProjectionReader {
  const AgentEvaluationPass3ProjectionReader(this.db);

  final Database db;

  AgentEvaluationPass3Projection readCell({
    required String executionId,
    required String cellId,
    required String evaluationBundleHash,
    int requiredTrials = 3,
  }) {
    final slots = db.select(
      '''SELECT trial_slot_id, trial_no, status, result
         FROM eval_trial_slots
         WHERE execution_id = ? AND cell_id = ?
         ORDER BY trial_no''',
      <Object?>[executionId, cellId],
    );
    final outcomes = <TrialSlotOutcome>[];
    final trialResults = <int, String>{};
    for (final slot in slots) {
      final trialNo = slot['trial_no'] as int;
      final sealed = slot['status'] == 'sealed';
      trialResults[trialNo] = sealed
          ? slot['result'] as String? ?? 'incomplete'
          : 'incomplete';
      final observations = db.select(
        '''SELECT * FROM eval_observations
           WHERE trial_slot_id = ? AND stage_id = 'outcome'
             AND kind = 'comparison' ''',
        <Object?>[slot['trial_slot_id']],
      );
      var evidenceComplete = false;
      var contentDigest = '';
      var independence = TrialIndependence.nonIndependent;
      if (observations.length == 1) {
        final observation = observations.single;
        try {
          final value = jsonDecode(observation['value_json'] as String);
          final expectedEvidenceHash = AgentEvaluationHashes.domainHash(
            'eval-outcome-observation-v1',
            value,
          );
          if (value is Map &&
              observation['evidence_hash'] == expectedEvidenceHash &&
              observation['evaluation_bundle_hash'] == evaluationBundleHash) {
            final decoded = value.cast<String, Object?>();
            final rawDigest = decoded['contentDigest'];
            if (rawDigest is String &&
                RegExp(r'^[a-f0-9]{64}$').hasMatch(rawDigest) &&
                observation['prose_hash'] == rawDigest) {
              contentDigest = rawDigest;
            }
            if (decoded['independence'] == TrialIndependence.independent.name) {
              independence = TrialIndependence.independent;
            }
            evidenceComplete =
                decoded['evidenceComplete'] == true && contentDigest.isNotEmpty;
          }
        } on Object {
          evidenceComplete = false;
        }
      }
      outcomes.add(
        TrialSlotOutcome(
          trialNo: trialNo,
          hardPass: sealed && slot['result'] == 'pass',
          evidenceComplete: evidenceComplete,
          contentDigest: contentDigest,
          independence: independence,
        ),
      );
    }
    final result = Pass3Evaluator(
      requiredTrials: requiredTrials,
    ).evaluate(outcomes);
    return AgentEvaluationPass3Projection(
      trialResults: Map<int, String>.unmodifiable(trialResults),
      result: result,
      allSlotsSealed:
          slots.length == requiredTrials &&
          slots.every((slot) => slot['status'] == 'sealed'),
    );
  }
}
