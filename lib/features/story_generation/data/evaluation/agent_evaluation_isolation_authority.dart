import 'dart:convert';
import 'dart:io';

import 'package:cryptography/dart.dart';
import 'package:sqlite3/sqlite3.dart';

import 'agent_evaluation_fixture_sandbox.dart';
import 'agent_evaluation_ledger.dart';
import 'agent_evaluation_manifest.dart';
import 'agent_evaluation_production_executor.dart';
import 'agent_evaluation_runner.dart';

/// Frozen authority for proving that production-pipeline side effects stayed
/// inside the Runner-owned trial sandbox namespace.
abstract final class AgentEvaluationIsolationAuthority {
  static String get releaseHash => AgentEvaluationHashes.domainHash(
    'agent-evaluation-isolation-authority-release-v1',
    <String, Object?>{
      'fixtureSandboxReleaseHash': AgentEvaluationFixtureSandbox.releaseHash,
      'ledgerReleaseHash': AgentEvaluationLedger.releaseHash,
      'productionExecutorReleaseHash':
          AgentEvaluationProductionExecutorPolicy.releaseHash,
      'projection': 'sealed-slot-generation-membership-v2',
      'providerClaim': 'purpose-transport-non-real-provider-v1',
    },
  );

  static AgentEvaluationIsolationProjection capture({
    required Database authorityDatabase,
    required AgentEvaluationRunReport report,
    required AgentEvaluationFixtureSandbox sandbox,
    required String fixtureDatabasePath,
    required String productionDatabasePath,
    required String productionDatabaseFileHashBefore,
  }) {
    if (!sandbox.isDurable || sandbox.executionId != report.executionId) {
      throw StateError('isolation authority requires the durable run sandbox');
    }
    final fixtureInput = File(fixtureDatabasePath).absolute;
    final productionInput = File(productionDatabasePath).absolute;
    final fixture = File(fixtureInput.resolveSymbolicLinksSync());
    final production = File(productionInput.resolveSymbolicLinksSync());
    final fixtureHash = _fileHash(fixture);
    final productionHashAfter = _fileHash(production);
    if (productionHashAfter != productionDatabaseFileHashBefore) {
      throw StateError('production source database changed during evaluation');
    }
    final binding = File('${sandbox.sandboxPath}/binding.json');
    final bindingSource = binding.readAsStringSync();
    final bindingValue = jsonDecode(bindingSource);
    if (bindingValue is! Map<String, Object?> ||
        AgentEvaluationHashes.canonicalJson(bindingValue) != bindingSource ||
        bindingValue['executionId'] != report.executionId ||
        bindingValue['fixtureFileHash'] !=
            _fileHash(File('${sandbox.sandboxPath}/fixture-snapshot.sqlite')) ||
        File(
              bindingValue['productionDatabasePath']! as String,
            ).resolveSymbolicLinksSync() !=
            production.path) {
      throw StateError('durable sandbox binding is not source-authoritative');
    }

    final slots = authorityDatabase.select(
      '''SELECT trial_slot_id, cell_id, status, sealed_evidence_hash
           FROM eval_trial_slots WHERE execution_id = ?
           ORDER BY trial_slot_id''',
      <Object?>[report.executionId],
    );
    final generations = authorityDatabase.select(
      '''SELECT generation_hash, isolation_trial_id, generation_no,
                source_trial_slot_id, base_generation_hash, isolation_mode,
                database_path, database_file_hash, lease_epoch, lease_owner
           FROM eval_sandbox_generations WHERE execution_id = ?
           ORDER BY source_trial_slot_id''',
      <Object?>[report.executionId],
    );
    if (slots.isEmpty ||
        slots.any(
          (row) =>
              row['status'] != 'sealed' ||
              !_isDigest(row['sealed_evidence_hash']),
        ) ||
        generations.length != slots.length) {
      throw StateError('sealed slots have incomplete sandbox membership');
    }
    final reportCellIds = report.cellPass3.map((cell) => cell.cellId).toSet();
    if (slots.any((row) => !reportCellIds.contains(row['cell_id']))) {
      throw StateError('run report omits a sealed isolation cell');
    }

    final projectionGenerations = <Map<String, Object?>>[];
    for (final slot in slots) {
      final slotId = slot['trial_slot_id']! as String;
      final generation = generations.singleWhere(
        (row) => row['source_trial_slot_id'] == slotId,
      );
      final observations = authorityDatabase.select(
        '''SELECT value_json FROM eval_observations
             WHERE trial_slot_id = ? AND stage_id = 'outcome'
               AND kind = 'comparison' ''',
        <Object?>[slotId],
      );
      if (observations.length != 1) {
        throw StateError('sealed slot has no unique outcome observation');
      }
      final outcome = jsonDecode(observations.single['value_json'] as String);
      if (outcome is! Map<String, Object?> ||
          outcome['isolationTrialId'] != generation['isolation_trial_id']) {
        throw StateError('outcome isolation identity is not generation-bound');
      }
      final generationFile = File(generation['database_path']! as String);
      if (_fileHash(generationFile) != generation['database_file_hash']) {
        throw StateError('sandbox generation file hash changed');
      }
      final generationUri = Uri.file(
        generationFile.absolute.path,
      ).replace(queryParameters: const <String, String>{'immutable': '1'});
      final generationDatabase = sqlite3.open(
        generationUri.toString(),
        mode: OpenMode.readOnly,
        uri: true,
      );
      try {
        int count(String table) =>
            generationDatabase
                    .select('SELECT COUNT(*) AS count FROM $table')
                    .single['count']
                as int;
        final storyRuns = count('story_generation_runs');
        final candidateProofs = count('story_generation_candidate_proofs');
        final commitReceipts = count('story_generation_commit_receipts');
        final preparedResults = count('eval_production_prepared_results');
        final executorResults = count('eval_production_executor_results');
        final versionEntries = count('version_entries');
        if (storyRuns < 1 ||
            candidateProofs < 1 ||
            commitReceipts < 1 ||
            preparedResults < 1 ||
            executorResults < 1 ||
            versionEntries < 1) {
          throw StateError(
            'sandbox generation $slotId omits production pipeline ledger evidence: '
            'runs=$storyRuns proofs=$candidateProofs receipts=$commitReceipts '
            'prepared=$preparedResults executor=$executorResults '
            'versions=$versionEntries',
          );
        }
        projectionGenerations.add(<String, Object?>{
          'trialSlotId': slotId,
          'cellId': slot['cell_id'],
          'sealedEvidenceHash': slot['sealed_evidence_hash'],
          'isolationTrialId': generation['isolation_trial_id'],
          'generationHash': generation['generation_hash'],
          'generationNo': generation['generation_no'],
          'baseGenerationHash': generation['base_generation_hash'],
          'isolationMode': generation['isolation_mode'],
          'databasePathHash': AgentEvaluationHashes.domainHash(
            'agent-evaluation-sandbox-path-v1',
            generationFile.absolute.path,
          ),
          'databaseFileHash': generation['database_file_hash'],
          'leaseEpoch': generation['lease_epoch'],
          'leaseOwnerHash': AgentEvaluationHashes.domainHash(
            'agent-evaluation-lease-owner-v1',
            generation['lease_owner'],
          ),
          'generationLedger': <String, Object?>{
            'storyRuns': storyRuns,
            'candidateProofs': candidateProofs,
            'commitReceipts': commitReceipts,
            'preparedResults': preparedResults,
            'executorResults': executorResults,
            'versionEntries': versionEntries,
          },
        });
      } finally {
        generationDatabase.dispose();
      }
    }
    final reportMembership = <String, Object?>{
      'executionId': report.executionId,
      'cellIds': report.cellPass3.map((cell) => cell.cellId).toList()..sort(),
      'scenarioReleaseHashes': report.scenarioPass3.keys.toList()..sort(),
      'cancelled': report.cancelled,
      'deadlineExceeded': report.deadlineExceeded,
      'sealedSlotIds': slots
          .map((row) => row['trial_slot_id']! as String)
          .toList(),
    };
    return AgentEvaluationIsolationProjection._(
      executionId: report.executionId,
      fixtureSourcePathHash: AgentEvaluationHashes.domainHash(
        'agent-evaluation-fixture-source-path-v1',
        fixture.path,
      ),
      fixtureSourceFileHash: fixtureHash,
      sandboxBindingHash: AgentEvaluationHashes.domainHash(
        'agent-evaluation-durable-sandbox-binding-v1',
        bindingValue,
      ),
      productionSourcePathHash: AgentEvaluationHashes.domainHash(
        'agent-evaluation-production-source-path-v1',
        production.path,
      ),
      productionSourceFileHashBefore: productionDatabaseFileHashBefore,
      productionSourceFileHashAfter: productionHashAfter,
      reportMembershipHash: AgentEvaluationHashes.domainHash(
        'agent-evaluation-isolation-report-membership-v1',
        reportMembership,
      ),
      generations: projectionGenerations,
    );
  }
}

final class AgentEvaluationIsolationProjection {
  AgentEvaluationIsolationProjection._({
    required this.executionId,
    required this.fixtureSourcePathHash,
    required this.fixtureSourceFileHash,
    required this.sandboxBindingHash,
    required this.productionSourcePathHash,
    required this.productionSourceFileHashBefore,
    required this.productionSourceFileHashAfter,
    required this.reportMembershipHash,
    required List<Map<String, Object?>> generations,
  }) : generations = List.unmodifiable(generations);

  final String executionId;
  final String fixtureSourcePathHash;
  final String fixtureSourceFileHash;
  final String sandboxBindingHash;
  final String productionSourcePathHash;
  final String productionSourceFileHashBefore;
  final String productionSourceFileHashAfter;
  final String reportMembershipHash;
  final List<Map<String, Object?>> generations;

  Map<String, Object?> toCanonicalMap() => <String, Object?>{
    'schemaVersion': 'agent-evaluation-isolation-projection-v1',
    'authorityReleaseHash': AgentEvaluationIsolationAuthority.releaseHash,
    'realProviderEvidence': false,
    'executionId': executionId,
    'fixtureSourcePathHash': fixtureSourcePathHash,
    'fixtureSourceFileHash': fixtureSourceFileHash,
    'sandboxBindingHash': sandboxBindingHash,
    'productionSourcePathHash': productionSourcePathHash,
    'productionSourceFileHashBefore': productionSourceFileHashBefore,
    'productionSourceFileHashAfter': productionSourceFileHashAfter,
    'reportMembershipHash': reportMembershipHash,
    'generations': generations,
  };

  String get projectionHash => AgentEvaluationHashes.domainHash(
    'agent-evaluation-isolation-projection-v1',
    toCanonicalMap(),
  );
}

String agentEvaluationIsolationFileHash(String path) => _fileHash(File(path));

bool _isDigest(Object? value) =>
    value is String && RegExp(r'^[a-f0-9]{64}$').hasMatch(value);

String _fileHash(File file) {
  if (FileSystemEntity.typeSync(file.path, followLinks: false) !=
      FileSystemEntityType.file) {
    throw StateError('isolation authority source is not a regular file');
  }
  final digest = const DartSha256().hashSync(file.readAsBytesSync());
  return digest.bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}
