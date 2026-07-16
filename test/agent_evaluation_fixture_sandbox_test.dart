import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_fixture_sandbox.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory testRoot;
  late String fixturePath;
  late String productionPath;

  setUp(() {
    testRoot = Directory.systemTemp.createTempSync('agent-eval-sandbox-test-');
    fixturePath = '${testRoot.path}/fixture.sqlite';
    productionPath = '${testRoot.path}/production.sqlite';
    _seedAuthoringFixture(fixturePath);
    _seedAuthoringFixture(productionPath);
  });

  tearDown(() {
    if (testRoot.existsSync()) testRoot.deleteSync(recursive: true);
  });

  test('independent trials cannot see accept-like Canon or RAG writes', () {
    final sandbox = _sandbox(
      fixturePath: fixturePath,
      productionPath: productionPath,
      parent: testRoot,
    );
    addTearDown(sandbox.dispose);
    final trial1 = sandbox.openTrial(
      armId: 'champion',
      trialId: 'trial-1',
      isolationMode: AgentEvaluationIsolationMode.independent,
    );
    _acceptLikeWrite(trial1.database, suffix: 'trial-1');
    final production = sqlite3.open(productionPath, mode: OpenMode.readOnly);
    addTearDown(production.dispose);

    final trial2 = sandbox.openTrial(
      armId: 'champion',
      trialId: 'trial-2',
      isolationMode: AgentEvaluationIsolationMode.independent,
    );

    expect(_hasMemory(trial1.database, 'canon-trial-1'), isTrue);
    expect(_hasMemory(trial2.database, 'canon-trial-1'), isFalse);
    expect(_hasSource(trial2.database, 'rag-trial-1'), isFalse);
    expect(_hasMemory(trial2.database, 'fixture-canon'), isTrue);
    expect(File(trial1.databasePath).absolute.path, isNot(productionPath));
    expect(_hasMemory(production, 'canon-trial-1'), isFalse);
    expect(_hasSource(production, 'rag-trial-1'), isFalse);
  });

  test('episode steps in one trial share state, another trial does not', () {
    final sandbox = _sandbox(
      fixturePath: fixturePath,
      productionPath: productionPath,
      parent: testRoot,
    );
    addTearDown(sandbox.dispose);
    final step1 = sandbox.openTrial(
      armId: 'champion',
      trialId: 'episode-1',
      isolationMode: AgentEvaluationIsolationMode.episode,
    );
    _acceptLikeWrite(step1.database, suffix: 'episode-step-1');

    final step2 = sandbox.openTrial(
      armId: 'champion',
      trialId: 'episode-1',
      isolationMode: AgentEvaluationIsolationMode.episode,
    );
    final otherEpisode = sandbox.openTrial(
      armId: 'champion',
      trialId: 'episode-2',
      isolationMode: AgentEvaluationIsolationMode.episode,
    );

    expect(step2, same(step1));
    expect(_hasMemory(step2.database, 'canon-episode-step-1'), isTrue);
    expect(_hasMemory(otherEpisode.database, 'canon-episode-step-1'), isFalse);
  });

  test('challenger arm starts from the fixture, not champion state', () {
    final sandbox = _sandbox(
      fixturePath: fixturePath,
      productionPath: productionPath,
      parent: testRoot,
    );
    addTearDown(sandbox.dispose);
    final champion = sandbox.openTrial(
      armId: 'champion',
      trialId: 'trial-1',
      isolationMode: AgentEvaluationIsolationMode.independent,
    );
    _acceptLikeWrite(champion.database, suffix: 'champion');

    final challenger = sandbox.openTrial(
      armId: 'challenger',
      trialId: 'trial-1',
      isolationMode: AgentEvaluationIsolationMode.independent,
    );

    expect(_hasMemory(challenger.database, 'canon-champion'), isFalse);
    expect(_hasSource(challenger.database, 'rag-champion'), isFalse);
    expect(_hasMemory(challenger.database, 'fixture-canon'), isTrue);
  });

  test('dispose closes trial databases and removes the whole sandbox', () {
    final sandbox = _sandbox(
      fixturePath: fixturePath,
      productionPath: productionPath,
      parent: testRoot,
    );
    final trial = sandbox.openTrial(
      armId: 'champion',
      trialId: 'trial-1',
      isolationMode: AgentEvaluationIsolationMode.independent,
    );
    final sandboxPath = sandbox.sandboxPath;
    final trialPath = trial.databasePath;
    expect(Directory(sandboxPath).existsSync(), isTrue);
    expect(File(trialPath).existsSync(), isTrue);

    sandbox.dispose();

    expect(Directory(sandboxPath).existsSync(), isFalse);
    expect(() => trial.database, throwsStateError);
    expect(sandbox.dispose, returnsNormally);
  });

  test('refuses to use the production database as the fixture snapshot', () {
    expect(
      () => AgentEvaluationFixtureSandbox.create(
        fixtureDatabasePath: productionPath,
        productionDatabasePath: productionPath,
        temporaryParent: testRoot,
      ),
      throwsArgumentError,
    );
  });

  test('generic durable seal does not require production executor tables', () {
    final sandbox = AgentEvaluationFixtureSandbox.openOrCreate(
      executionId: 'generic-seal-execution',
      fixtureDatabasePath: fixturePath,
      productionDatabasePath: productionPath,
      durableParent: Directory('${testRoot.path}/generic-durable'),
    );
    addTearDown(sandbox.dispose);
    final trial = sandbox.openLeaseTrial(
      armId: 'champion',
      trialId: 'generic-trial',
      isolationMode: AgentEvaluationIsolationMode.independent,
      leaseEpoch: 1,
      leaseOwner: 'generic-owner',
      leaseTrialSlotId: 'generic-slot',
    );
    _acceptLikeWrite(trial.database, suffix: 'generic-seal');

    final hash = trial.closeAndHash();
    final sealed = sqlite3.open(
      trial.sealedDatabasePath,
      mode: OpenMode.readOnly,
    );
    try {
      expect(hash, hasLength(64));
      expect(_hasMemory(sealed, 'canon-generic-seal'), isTrue);
      expect(
        sealed.select(
          "SELECT 1 FROM sqlite_master WHERE name = 'eval_production_executor_results'",
        ),
        isEmpty,
      );
    } finally {
      sealed.dispose();
    }
  });

  test(
    'terminal cleanup retains one sealed generation and not another trial',
    () {
      final sandbox = AgentEvaluationFixtureSandbox.openOrCreate(
        executionId: 'terminal-cleanup-execution',
        fixtureDatabasePath: fixturePath,
        productionDatabasePath: productionPath,
        durableParent: Directory('${testRoot.path}/terminal-cleanup'),
      );
      addTearDown(sandbox.dispose);
      final predecessor = sandbox.openLeaseTrial(
        armId: 'champion',
        trialId: 'first-trial',
        isolationMode: AgentEvaluationIsolationMode.independent,
        leaseEpoch: 1,
        leaseOwner: 'predecessor-owner',
        leaseTrialSlotId: 'slot-a',
      );
      _acceptLikeWrite(predecessor.database, suffix: 'predecessor');
      final predecessorRecovery = predecessor.createRecoverySnapshot(
        checkpointIdentity: List<String>.filled(64, '9').join(),
      );
      predecessor.dispose();
      final first = sandbox.openLeaseTrial(
        armId: 'champion',
        trialId: 'first-trial',
        isolationMode: AgentEvaluationIsolationMode.independent,
        leaseEpoch: 2,
        leaseOwner: 'owner-a',
        leaseTrialSlotId: 'slot-a',
        sourceDatabasePath: predecessorRecovery.databasePath,
        expectedSourceFileHash: predecessorRecovery.databaseFileHash,
        expectedSourceFileSize: predecessorRecovery.databaseFileSize,
        expectedSourceStateProjectionHash:
            predecessorRecovery.stateProjectionHash,
      );
      final second = sandbox.openLeaseTrial(
        armId: 'champion',
        trialId: 'second-trial',
        isolationMode: AgentEvaluationIsolationMode.independent,
        leaseEpoch: 1,
        leaseOwner: 'owner-b',
        leaseTrialSlotId: 'slot-b',
      );
      _acceptLikeWrite(first.database, suffix: 'first');
      _acceptLikeWrite(second.database, suffix: 'second');
      final firstRecovery = first.createRecoverySnapshot(
        checkpointIdentity: List<String>.filled(64, 'a').join(),
      );
      final secondRecovery = second.createRecoverySnapshot(
        checkpointIdentity: List<String>.filled(64, 'b').join(),
      );

      first.closeAndHash();
      final retainedGeneration = first.sealedDatabasePath;
      // Closing and hashing is not authority publication. Every recovery file
      // remains until the Runner confirms the slot seal.
      expect(File(first.databasePath).existsSync(), isTrue);
      expect(File(firstRecovery.databasePath).existsSync(), isTrue);
      expect(File(predecessor.databasePath).existsSync(), isTrue);
      expect(File(predecessorRecovery.databasePath).existsSync(), isTrue);
      expect(File(retainedGeneration).existsSync(), isTrue);
      expect(File(second.databasePath).existsSync(), isTrue);
      expect(File(secondRecovery.databasePath).existsSync(), isTrue);

      first.cleanupAfterTerminalSealBestEffort(
        recoverySnapshotPaths: <String>[
          predecessorRecovery.databasePath,
          firstRecovery.databasePath,
        ],
      );

      expect(File(retainedGeneration).existsSync(), isTrue);
      expect(File(first.databasePath).existsSync(), isFalse);
      expect(File(firstRecovery.databasePath).existsSync(), isFalse);
      expect(File(predecessor.databasePath).existsSync(), isFalse);
      expect(File(predecessorRecovery.databasePath).existsSync(), isFalse);
      expect(File(second.databasePath).existsSync(), isTrue);
      expect(File(secondRecovery.databasePath).existsSync(), isTrue);
      expect(File('${sandbox.sandboxPath}/binding.json').existsSync(), isTrue);
      expect(
        File('${sandbox.sandboxPath}/fixture-snapshot.sqlite').existsSync(),
        isTrue,
      );
    },
  );

  test('terminal cleanup without a generation removes the trial family', () {
    final sandbox = AgentEvaluationFixtureSandbox.openOrCreate(
      executionId: 'terminal-insufficient-execution',
      fixtureDatabasePath: fixturePath,
      productionDatabasePath: productionPath,
      durableParent: Directory('${testRoot.path}/terminal-insufficient'),
    );
    addTearDown(sandbox.dispose);
    final trial = sandbox.openLeaseTrial(
      armId: 'champion',
      trialId: 'indeterminate-trial',
      isolationMode: AgentEvaluationIsolationMode.independent,
      leaseEpoch: 1,
      leaseOwner: 'owner-a',
      leaseTrialSlotId: 'indeterminate-slot',
    );
    final recovery = trial.createRecoverySnapshot(
      checkpointIdentity: List<String>.filled(64, 'c').join(),
    );

    trial.dispose();
    expect(File(trial.databasePath).existsSync(), isTrue);
    expect(File(recovery.databasePath).existsSync(), isTrue);

    trial.cleanupAfterTerminalSealBestEffort();

    expect(File(trial.databasePath).existsSync(), isFalse);
    expect(File(recovery.databasePath).existsSync(), isFalse);
    expect(File('${sandbox.sandboxPath}/binding.json').existsSync(), isTrue);
  });

  test('production seal refuses to close before runtime-disposed ack', () {
    final sandbox = AgentEvaluationFixtureSandbox.openOrCreate(
      executionId: 'production-seal-ack-execution',
      fixtureDatabasePath: fixturePath,
      productionDatabasePath: productionPath,
      durableParent: Directory('${testRoot.path}/production-seal-ack'),
    );
    addTearDown(sandbox.dispose);
    final trial = sandbox.openLeaseTrial(
      armId: 'champion',
      trialId: 'production-trial',
      isolationMode: AgentEvaluationIsolationMode.independent,
      leaseEpoch: 1,
      leaseOwner: 'production-owner',
      leaseTrialSlotId: 'production-slot',
    );
    trial.requireEvidenceProfile(
      AgentEvaluationRequiredEvidenceProfile.productionExecutorV1,
    );

    expect(trial.closeAndHash, throwsStateError);
    expect(trial.isDisposed, isFalse);
  });

  test('release verifier compile failure cannot use source fallback', () {
    expect(
      () => AgentEvaluationSealVerifierLaunchPolicy.afterAotFailure(
        releaseEvidence: true,
        dartExecutable: '/diagnostic/dart',
        packageConfigPath: '/diagnostic/package_config.json',
        verifierPath: '/diagnostic/verifier.dart',
      ),
      throwsStateError,
    );
    final diagnostic = AgentEvaluationSealVerifierLaunchPolicy.afterAotFailure(
      releaseEvidence: false,
      dartExecutable: '/diagnostic/dart',
      packageConfigPath: '/diagnostic/package_config.json',
      verifierPath: '/diagnostic/verifier.dart',
    );
    expect(diagnostic.executable, '/diagnostic/dart');
    expect(diagnostic.arguments, <String>[
      '--packages=/diagnostic/package_config.json',
      '/diagnostic/verifier.dart',
    ]);
  });

  test('durable binding recovers an interrupted metadata publish', () {
    final durableParent = Directory('${testRoot.path}/durable');
    final first = AgentEvaluationFixtureSandbox.openOrCreate(
      executionId: 'execution-binding-recovery',
      fixtureDatabasePath: fixturePath,
      productionDatabasePath: productionPath,
      durableParent: durableParent,
    );
    final sandboxPath = first.sandboxPath;
    first.dispose();
    final binding = File('$sandboxPath/binding.json');
    expect(binding.existsSync(), isTrue);
    binding.deleteSync();
    File('$sandboxPath/binding.crash.tmp').writeAsStringSync('{truncated');

    final recovered = AgentEvaluationFixtureSandbox.openOrCreate(
      executionId: 'execution-binding-recovery',
      fixtureDatabasePath: fixturePath,
      productionDatabasePath: productionPath,
      durableParent: durableParent,
    );
    addTearDown(recovered.dispose);

    expect(recovered.sandboxPath, sandboxPath);
    expect(binding.existsSync(), isTrue);
    expect(binding.readAsStringSync(), contains('fixtureFileHash'));
    expect(File('$sandboxPath/fixture-snapshot.sqlite').existsSync(), isTrue);
  });

  test(
    'two processes cannot bind one execution to different fixtures',
    () async {
      if (Platform.isWindows) return;
      final competingFixture = '${testRoot.path}/fixture-competing.sqlite';
      _seedAuthoringFixture(competingFixture);
      for (final entry in <(String, String)>[
        (fixturePath, 'fixture-A'),
        (competingFixture, 'fixture-B'),
      ]) {
        final fixture = sqlite3.open(entry.$1);
        fixture.execute(
          'UPDATE story_memory_sources SET raw_content = ?',
          <Object?>[entry.$2],
        );
        fixture.execute('CREATE TABLE binding_padding(data BLOB NOT NULL)');
        fixture.execute(
          'INSERT INTO binding_padding VALUES (zeroblob(8388608))',
        );
        fixture.dispose();
      }
      final script = File('${testRoot.path}/binding_race.dart');
      script.writeAsStringSync(r'''
import 'dart:io';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_fixture_sandbox.dart';
import 'package:sqlite3/sqlite3.dart';

Future<void> main(List<String> args) async {
  while (!File(args[4]).existsSync()) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  try {
    final sandbox = AgentEvaluationFixtureSandbox.openOrCreate(
      executionId: 'binding-race-execution',
      fixtureDatabasePath: args[0],
      productionDatabasePath: args[1],
      durableParent: Directory(args[2]),
    );
    final snapshot = sqlite3.open(
      '${sandbox.sandboxPath}/fixture-snapshot.sqlite',
      mode: OpenMode.readOnly,
    );
    final marker = snapshot
        .select("SELECT raw_content FROM story_memory_sources WHERE id = 'fixture-rag'")
        .single['raw_content'];
    snapshot.dispose();
    stdout.write('ok:${args[3]}:$marker');
    sandbox.dispose();
  } catch (_) {
    stdout.write('rejected:${args[3]}');
    exitCode = 2;
  }
}
''', flush: true);
      final durable = Directory('${testRoot.path}/race-durable')..createSync();
      final barrier = File('${testRoot.path}/race-start');
      Future<(int, String)> start(String fixture, String label) async {
        final process = await Process.start('dart', <String>[
          '--packages=.dart_tool/package_config.json',
          script.path,
          fixture,
          productionPath,
          durable.path,
          label,
          barrier.path,
        ], workingDirectory: Directory.current.path);
        final output = process.stdout.transform(utf8.decoder).join();
        final error = process.stderr.transform(utf8.decoder).join();
        final code = await process.exitCode;
        expect(await error, isEmpty);
        return (code, await output);
      }

      final first = start(fixturePath, 'A');
      final second = start(competingFixture, 'B');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      barrier.writeAsStringSync('go', flush: true);
      final results = await Future.wait(<Future<(int, String)>>[first, second]);

      expect(results.map((result) => result.$1).toList()..sort(), <int>[0, 2]);
      expect(
        results.singleWhere((result) => result.$1 == 0).$2,
        anyOf('ok:A:fixture-A', 'ok:B:fixture-B'),
      );
      expect(
        results.singleWhere((result) => result.$1 == 2).$2,
        startsWith('rejected:'),
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

AgentEvaluationFixtureSandbox _sandbox({
  required String fixturePath,
  required String productionPath,
  required Directory parent,
}) => AgentEvaluationFixtureSandbox.create(
  fixtureDatabasePath: fixturePath,
  productionDatabasePath: productionPath,
  temporaryParent: parent,
);

void _seedAuthoringFixture(String path) {
  final db = sqlite3.open(path);
  try {
    db.execute('''
      CREATE TABLE story_memory_sources (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        scope_id TEXT NOT NULL,
        source_kind TEXT NOT NULL,
        raw_content TEXT NOT NULL
      )
    ''');
    db.execute('''
      CREATE TABLE story_memory_chunks (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        scope_id TEXT NOT NULL,
        chunk_kind TEXT NOT NULL,
        content TEXT NOT NULL,
        tier TEXT NOT NULL,
        source_id TEXT NOT NULL
      )
    ''');
    db.execute('INSERT INTO story_memory_sources VALUES (?, ?, ?, ?, ?)', [
      'fixture-rag',
      'project-1',
      'scene-0',
      'fixture',
      '初始 RAG 事实',
    ]);
    db.execute('INSERT INTO story_memory_chunks VALUES (?, ?, ?, ?, ?, ?, ?)', [
      'fixture-canon',
      'project-1',
      'scene-0',
      'canon',
      '初始 Canon 事实',
      'canon',
      'fixture-rag',
    ]);
  } finally {
    db.dispose();
  }
}

void _acceptLikeWrite(Database db, {required String suffix}) {
  db.execute('INSERT INTO story_memory_sources VALUES (?, ?, ?, ?, ?)', [
    'rag-$suffix',
    'project-1',
    'scene-1',
    'acceptedScene',
    '新增 RAG 事实',
  ]);
  db.execute('INSERT INTO story_memory_chunks VALUES (?, ?, ?, ?, ?, ?, ?)', [
    'canon-$suffix',
    'project-1',
    'scene-1',
    'canon',
    '新增 Canon 事实',
    'canon',
    'rag-$suffix',
  ]);
}

bool _hasMemory(Database db, String id) => db.select(
  'SELECT 1 FROM story_memory_chunks WHERE id = ?',
  [id],
).isNotEmpty;

bool _hasSource(Database db, String id) => db.select(
  'SELECT 1 FROM story_memory_sources WHERE id = ?',
  [id],
).isNotEmpty;
