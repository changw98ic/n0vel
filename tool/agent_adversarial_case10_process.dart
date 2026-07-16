import 'dart:convert';
import 'dart:io';

import 'package:novel_writer/app/llm/app_llm_canonical_hash.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_fixture_sandbox.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger_models.dart';

Future<void> main(List<String> arguments) async {
  final args = _arguments(arguments);
  final phase = args['phase'];
  if (phase == 'episode-n') {
    await _runEpisodeN(args);
    return;
  }
  if (phase == 'episode-n-plus-one') {
    _runEpisodeNPlusOne(args);
    return;
  }
  stderr.writeln('unknown case10 helper phase');
  exitCode = 64;
}

Future<void> _runEpisodeN(Map<String, String> args) async {
  final sandbox = _openSandbox(args);
  try {
    final trial = sandbox.openLeaseTrial(
      armId: 'primary',
      trialId: 'case-10-${args['variant']}',
      isolationMode: AgentEvaluationIsolationMode.episode,
      leaseEpoch: 1,
      leaseOwner: 'episode-n-process',
      leaseTrialSlotId: 'case-10-${args['variant']}-slot',
    );
    final store = GenerationLedgerSqliteStore(db: trial.database)
      ..ensureTables();
    store.createRun(
      GenerationRunRecord(
        runId: 'case-10-${args['variant']}-run',
        requestId: 'case-10-${args['variant']}-request',
        projectId: 'case-10-project',
        chapterId: 'case-10-chapter',
        sceneId: 'case-10-scene',
        sceneScopeId: 'case-10-project::case-10-scene',
        status: 'running',
        phase: 'editorial',
        schemaVersion: 9,
        createdAtMs: 1,
        updatedAtMs: 1,
      ),
    );
    store.createWorkingProseRevision(
      WorkingProseRevisionRecord(
        runId: 'case-10-${args['variant']}-run',
        proseRevision: 0,
        proseHash: AppLlmCanonicalHash.domainHash(
          'case-10-working-prose-v1',
          args['variant'],
        ).substring('sha256:'.length),
        proseText: 'case10 durable working state',
        sourceKind: 'editorial',
        createdAtMs: 1,
      ),
    );
    store.saveStageCheckpoint(_checkpoint(args['variant']!, ordinal: 0));
    final databaseHash = trial.closeAndHash();
    final databasePath = trial.sealedDatabasePath;
    sandbox.dispose();
    _writeJsonAtomically(File(args['receipt']!), <String, Object?>{
      'schemaVersion': 'agent-adversarial-case10-process-v1',
      'phase': 'episode-n',
      'variant': args['variant'],
      'processId': pid,
      'databasePath': databasePath,
      'databaseHash': databaseHash,
      'completedOrdinals': const <int>[0],
    });
    // The parent deliberately kills this process after the committed receipt
    // becomes visible, reproducing process loss between episode N and N+1.
    while (true) {
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  } finally {
    if (!sandbox.isDisposed) sandbox.dispose();
  }
}

void _runEpisodeNPlusOne(Map<String, String> args) {
  final sandbox = _openSandbox(args);
  try {
    final trial = sandbox.openLeaseTrial(
      armId: 'primary',
      trialId: 'case-10-${args['variant']}',
      isolationMode: AgentEvaluationIsolationMode.episode,
      leaseEpoch: 2,
      leaseOwner: 'episode-n-plus-one-process',
      leaseTrialSlotId: 'case-10-${args['variant']}-slot',
      sourceDatabasePath: args['source'],
      expectedSourceFileHash: args['source-hash'],
    );
    final store = GenerationLedgerSqliteStore(db: trial.database)
      ..ensureTables();
    final before = store.loadStageCheckpoints(
      runId: 'case-10-${args['variant']}-run',
    );
    final recoveredOrdinalZero =
        before.length == 1 &&
        before.single.ordinal == 0 &&
        before.single.status == 'completed' &&
        before.single.artifactJson ==
            _checkpoint(args['variant']!, ordinal: 0).artifactJson;
    var conflictingReplayRejected = false;
    if (args['variant'] == 'attack') {
      try {
        store.saveStageCheckpoint(
          _checkpoint(
            args['variant']!,
            ordinal: 0,
            artifactLabel: 'rewritten-after-crash',
          ),
        );
      } on GenerationLedgerInvariantViolation {
        conflictingReplayRejected = true;
      }
    }
    if (!recoveredOrdinalZero ||
        (args['variant'] == 'attack' && !conflictingReplayRejected)) {
      stderr.writeln('episode N checkpoint recovery failed');
      exitCode = 2;
      return;
    }
    store.saveStageCheckpoint(_checkpoint(args['variant']!, ordinal: 1));
    final completed = store.loadStageCheckpoints(
      runId: 'case-10-${args['variant']}-run',
    );
    final databaseHash = trial.closeAndHash();
    final databasePath = trial.sealedDatabasePath;
    sandbox.dispose();
    _writeJsonAtomically(File(args['receipt']!), <String, Object?>{
      'schemaVersion': 'agent-adversarial-case10-process-v1',
      'phase': 'episode-n-plus-one',
      'variant': args['variant'],
      'processId': pid,
      'sourceDatabaseHash': args['source-hash'],
      'databasePath': databasePath,
      'databaseHash': databaseHash,
      'recoveredOrdinalZero': recoveredOrdinalZero,
      'conflictingReplayRejected': conflictingReplayRejected,
      'completedOrdinals': <int>[
        for (final checkpoint in completed) checkpoint.ordinal,
      ],
    });
  } finally {
    if (!sandbox.isDisposed) sandbox.dispose();
  }
}

AgentEvaluationFixtureSandbox _openSandbox(Map<String, String> args) =>
    AgentEvaluationFixtureSandbox.openOrCreate(
      executionId: 'case-10-${args['variant']}-execution',
      fixtureDatabasePath: args['fixture']!,
      productionDatabasePath: args['production']!,
      durableParent: Directory(args['durable-parent']!),
    );

GenerationStageCheckpointRecord _checkpoint(
  String variant, {
  required int ordinal,
  String? artifactLabel,
}) {
  final label = artifactLabel ?? (ordinal == 0 ? 'episode-n' : 'episode-n+1');
  String digest(String domain, Object value) => AppLlmCanonicalHash.domainHash(
    domain,
    <Object?>[variant, ordinal, value],
  ).substring('sha256:'.length);
  return GenerationStageCheckpointRecord(
    runId: 'case-10-$variant-run',
    ordinal: ordinal,
    stageId: ordinal == 0 ? 'editorial' : 'council',
    stageAttempt: 1,
    codecVersion: 1,
    status: 'completed',
    inputDigest: digest('case-10-input-v1', label),
    artifactDigest: digest('case-10-artifact-v1', label),
    upstreamChainDigest: digest('case-10-chain-v1', label),
    provenance: GenerationCheckpointProvenance(
      baseDraftDigest: digest('case-10-base-draft-v1', 'base'),
      materialDigest: digest('case-10-material-v1', 'material'),
      promptDigest: digest('case-10-prompt-v1', label),
      modelDigest: digest('case-10-model-v1', 'model'),
    ),
    artifactType: 'episode-state',
    artifactJson: jsonEncode(<String, Object?>{
      'episode': ordinal == 0 ? 'N' : 'N+1',
      'ordinal': ordinal,
      'state': label,
    }),
    createdAtMs: ordinal == 0 ? 10 : 20,
    completedAtMs: ordinal == 0 ? 11 : 21,
  );
}

Map<String, String> _arguments(List<String> arguments) {
  final result = <String, String>{};
  for (final argument in arguments) {
    final separator = argument.indexOf('=');
    if (!argument.startsWith('--') || separator <= 2) continue;
    result[argument.substring(2, separator)] = argument.substring(
      separator + 1,
    );
  }
  for (final required in <String>[
    'phase',
    'variant',
    'fixture',
    'production',
    'durable-parent',
    'receipt',
  ]) {
    if ((result[required] ?? '').isEmpty) {
      throw ArgumentError('missing --$required');
    }
  }
  return result;
}

void _writeJsonAtomically(File target, Map<String, Object?> value) {
  target.parent.createSync(recursive: true);
  final temporary = File('${target.path}.$pid.tmp');
  temporary.writeAsStringSync(jsonEncode(value), flush: true);
  temporary.renameSync(target.path);
}
