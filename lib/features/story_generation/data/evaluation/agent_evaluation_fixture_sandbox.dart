import 'dart:convert';
import 'dart:io';

import 'package:cryptography/dart.dart';
import 'package:sqlite3/sqlite3.dart';

import 'agent_evaluation_manifest.dart';
import 'agent_evaluation_production_side_effects.dart';
import 'agent_evaluation_sandbox_seal_verifier.dart';

enum AgentEvaluationIsolationMode { independent, episode }

enum AgentEvaluationRequiredEvidenceProfile { generic, productionExecutorV1 }

class AgentEvaluationSandboxRecoverySnapshot {
  const AgentEvaluationSandboxRecoverySnapshot({
    required this.databasePath,
    required this.databaseFileHash,
    required this.databaseFileSize,
    required this.stateProjectionHash,
  });

  final String databasePath;
  final String databaseFileHash;
  final int databaseFileSize;
  final String stateProjectionHash;
}

/// Chooses the only permitted verifier launch after bounded AOT compilation.
///
/// A source-based Dart process is useful for diagnostics, but its source and
/// package resolution are not a frozen release artifact. Release evidence must
/// therefore fail closed when the bound AOT verifier cannot be produced.
abstract final class AgentEvaluationSealVerifierLaunchPolicy {
  static ({String executable, List<String> arguments}) afterAotFailure({
    required bool releaseEvidence,
    required String dartExecutable,
    required String packageConfigPath,
    required String verifierPath,
  }) {
    if (releaseEvidence) {
      throw StateError(
        'release sandbox seal verifier AOT compilation failed closed',
      );
    }
    return (
      executable: dartExecutable,
      arguments: <String>['--packages=$packageConfigPath', verifierPath],
    );
  }
}

/// Owns one cloned SQLite namespace for a logical evaluation trial.
class AgentEvaluationTrialSandbox {
  AgentEvaluationTrialSandbox._({
    required this.armId,
    required this.trialId,
    required this.isolationMode,
    required this.databasePath,
    required Database database,
    required Set<String> terminalCleanupEpochPaths,
  }) : _database = database,
       _terminalCleanupEpochPaths = Set<String>.unmodifiable(
         terminalCleanupEpochPaths,
       );

  final String armId;
  final String trialId;
  final AgentEvaluationIsolationMode isolationMode;
  final String databasePath;
  Database? _database;
  String? _sealedDatabasePath;
  final Set<String> _terminalCleanupEpochPaths;
  final Set<String> _connectionOwners = <String>{'runner-main'};
  var _runtimeDisposedAcknowledged = false;
  var _requiredEvidenceProfile = AgentEvaluationRequiredEvidenceProfile.generic;

  String get namespaceId => '$armId/$trialId';

  bool get isDisposed => _database == null;

  void requireEvidenceProfile(AgentEvaluationRequiredEvidenceProfile profile) {
    if (isDisposed || _runtimeDisposedAcknowledged) {
      throw StateError('sandbox evidence profile is already frozen');
    }
    if (_requiredEvidenceProfile !=
            AgentEvaluationRequiredEvidenceProfile.generic &&
        _requiredEvidenceProfile != profile) {
      throw StateError('sandbox evidence profile cannot be weakened');
    }
    _requiredEvidenceProfile = profile;
  }

  String get sealedDatabasePath {
    final path = _sealedDatabasePath;
    if (path == null) {
      throw StateError('evaluation trial sandbox is not sealed');
    }
    return path;
  }

  Database get database {
    final current = _database;
    if (current == null) {
      throw StateError('evaluation trial sandbox is disposed');
    }
    return current;
  }

  int get connectionOwnerCount => _connectionOwners.length;

  void acquireConnectionOwner(String ownerId) {
    if (ownerId.trim().isEmpty ||
        isDisposed ||
        !_connectionOwners.add(ownerId)) {
      throw StateError('invalid or duplicate sandbox connection owner');
    }
  }

  void releaseConnectionOwner(String ownerId) {
    if (ownerId == 'runner-main' || !_connectionOwners.remove(ownerId)) {
      throw StateError('unknown sandbox connection owner release');
    }
  }

  void dispose() {
    _database?.dispose();
    _database = null;
    _connectionOwners.remove('runner-main');
  }

  /// Acknowledges that the production runtime released every borrowed owner.
  ///
  /// This does not create or claim a snapshot. The Runner closes the final
  /// authoritative connection and creates the immutable seal in [closeAndHash]
  /// only after this exact lifecycle boundary has succeeded.
  Future<String> acknowledgeRuntimeDisposed(
    Database authoritativeDatabase,
  ) async {
    final current = _database;
    if (current == null ||
        !identical(current, authoritativeDatabase) ||
        _runtimeDisposedAcknowledged ||
        !current.autocommit ||
        _connectionOwners.length != 1 ||
        !_connectionOwners.contains('runner-main')) {
      throw StateError('evaluation sandbox runtime disposal is incomplete');
    }
    _runtimeDisposedAcknowledged = true;
    return databasePath;
  }

  /// Publishes a transactionally consistent, immutable recovery source while
  /// keeping the authoritative runtime connection open.
  ///
  /// The caller must append the returned identity through the lease-fenced
  /// authority ledger before treating the file as recoverable. A crash before
  /// that append can leave an unreferenced file, but no successor will trust it.
  AgentEvaluationSandboxRecoverySnapshot createRecoverySnapshot({
    required String checkpointIdentity,
  }) {
    AgentEvaluationHashes.requireDigest(
      checkpointIdentity,
      'checkpointIdentity',
    );
    final current = _database;
    if (current == null || !current.autocommit) {
      throw StateError(
        'sandbox recovery snapshot requires an open autocommit connection',
      );
    }
    final canonicalSourcePath = _canonicalFilePath(databasePath);
    final snapshot = File(
      '$canonicalSourcePath.recovery.$checkpointIdentity.sqlite',
    );
    final staged = File(
      '${snapshot.path}.$pid.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    if (snapshot.existsSync()) {
      throw StateError('sandbox recovery snapshot identity already exists');
    }
    try {
      // VACUUM INTO reads one committed SQLite snapshot, including committed
      // WAL pages, without closing the runtime-owned source connection.
      current.execute('VACUUM INTO ?', <Object?>[staged.path]);
      final stagedDatabase = sqlite3.open(staged.path);
      try {
        final integrity = stagedDatabase
            .select('PRAGMA integrity_check')
            .single
            .values
            .single;
        if (integrity != 'ok') {
          throw StateError('sandbox recovery snapshot failed integrity check');
        }
        stagedDatabase.execute('PRAGMA journal_mode = DELETE');
        stagedDatabase.execute('PRAGMA synchronous = FULL');
      } finally {
        stagedDatabase.dispose();
      }
      staged.renameSync(snapshot.path);
      for (final suffix in <String>['-wal', '-shm', '-journal']) {
        final sidecar = File('${snapshot.path}$suffix');
        if (sidecar.existsSync() && sidecar.lengthSync() != 0) {
          throw StateError('sandbox recovery snapshot retained a sidecar');
        }
        if (sidecar.existsSync()) sidecar.deleteSync();
      }
      return _readRecoverySnapshotIdentity(snapshot.path);
    } catch (_) {
      if (staged.existsSync()) staged.deleteSync();
      if (snapshot.existsSync()) snapshot.deleteSync();
      rethrow;
    }
  }

  /// Closes every SQLite handle before hashing the immutable epoch copy.
  String closeAndHash() {
    final current = _database;
    if (current == null ||
        _connectionOwners.length != 1 ||
        !_connectionOwners.contains('runner-main')) {
      throw StateError('evaluation trial sandbox is already disposed');
    }
    if (_requiredEvidenceProfile ==
            AgentEvaluationRequiredEvidenceProfile.productionExecutorV1 &&
        !_runtimeDisposedAcknowledged) {
      throw StateError(
        'production sandbox seal requires runtime-disposed acknowledgement',
      );
    }
    final canonicalSourcePath = _canonicalFilePath(databasePath);
    final staged = File(
      '$canonicalSourcePath.seal.$pid.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    final sealed = File('$canonicalSourcePath.generation.sqlite');
    if (sealed.existsSync()) {
      throw StateError('sandbox generation seal already exists');
    }
    try {
      dispose();
      if (_connectionOwners.isNotEmpty) {
        throw StateError('sandbox connection owners remained after main close');
      }
      final source = sqlite3.open(canonicalSourcePath);
      try {
        final checkpoint = source
            .select('PRAGMA wal_checkpoint(TRUNCATE)')
            .single
            .values
            .toList(growable: false);
        if (checkpoint.length != 3 ||
            checkpoint[0] != 0 ||
            checkpoint[1] != checkpoint[2]) {
          throw StateError(
            'fresh sandbox source could not checkpoint WAL: $checkpoint',
          );
        }
        final journalMode = source
            .select('PRAGMA journal_mode = DELETE')
            .single
            .values
            .single
            .toString()
            .toLowerCase();
        if (journalMode != 'delete') {
          throw StateError(
            'fresh sandbox source retained journal mode $journalMode',
          );
        }
        if (_requiredEvidenceProfile ==
            AgentEvaluationRequiredEvidenceProfile.productionExecutorV1) {
          final physicalBoundary = source.select(
            '''SELECT
                 (SELECT COUNT(*) FROM main.story_generation_runs) AS runs,
                 (SELECT COUNT(*) FROM main.story_generation_candidate_proofs) AS proofs,
                 (SELECT COUNT(*) FROM main.story_generation_commit_receipts) AS receipts,
                 (SELECT COUNT(*) FROM main.eval_production_prepared_results) AS prepared,
                 (SELECT COUNT(*) FROM main.eval_production_executor_results) AS results,
                 (SELECT COUNT(*) FROM main.version_entries) AS versions''',
          ).single;
          if (physicalBoundary.values.any((value) => (value as int) < 1)) {
            throw StateError(
              'fresh sandbox source omitted physical production evidence: '
              '${AgentEvaluationHashes.canonicalJson(physicalBoundary)}',
            );
          }
        }
        source.execute('VACUUM INTO ?', <Object?>[staged.path]);
      } finally {
        source.dispose();
      }
      final destination = sqlite3.open(staged.path);
      try {
        destination.execute('PRAGMA journal_mode = DELETE');
        destination.execute('PRAGMA synchronous = FULL');
      } finally {
        destination.dispose();
      }
      if (!staged.existsSync()) {
        throw StateError('sandbox staged seal was not created');
      }
      staged.renameSync(sealed.path);
      for (final suffix in <String>['-wal', '-shm', '-journal']) {
        final sidecar = File('${sealed.path}$suffix');
        if (sidecar.existsSync() && sidecar.lengthSync() != 0) {
          throw StateError('sandbox final seal retained a journal sidecar');
        }
        if (sidecar.existsSync()) sidecar.deleteSync();
      }
      final sealedHash = _fileSha256(sealed.path);
      if (_requiredEvidenceProfile ==
          AgentEvaluationRequiredEvidenceProfile.productionExecutorV1) {
        final verification = _verifySealInIndependentProcess(sealed.path);
        if (verification['fileHash'] != sealedHash) {
          throw StateError('independent seal verifier file hash disagrees');
        }
      } else {
        _verifyGenericSeal(sealed.path);
      }
      _sealedDatabasePath = _canonicalFilePath(sealed.path);
      return sealedHash;
    } on Object {
      if (!isDisposed) dispose();
      if (staged.existsSync()) staged.deleteSync();
      if (sealed.existsSync()) sealed.deleteSync();
      _sealedDatabasePath = null;
      rethrow;
    }
  }

  /// Best-effort disk cleanup after the authority ledger sealed this slot.
  ///
  /// The Runner is the only production caller and invokes this strictly after
  /// `sealSlot` succeeds. Until then every epoch source, recovery checkpoint,
  /// and staged file remains available for a successor lease. Once terminal,
  /// only this epoch's verified generation is retained for audit. Cleanup is
  /// deliberately conservative: an I/O failure leaves files behind and must
  /// never turn an already-sealed slot into a failure or cause provider replay.
  void cleanupAfterTerminalSealBestEffort({
    Iterable<String> recoverySnapshotPaths = const <String>[],
  }) {
    if (!isDisposed) return;
    final retainedGenerationPath = _sealedDatabasePath;
    final epochPaths = <String>{..._terminalCleanupEpochPaths};
    final currentParent = File(databasePath).absolute.parent.path;
    for (final recoveryPath in recoverySnapshotPaths) {
      final recovery = File(recoveryPath).absolute;
      final epochPath = _recoveryEpochPath(recovery);
      if (recovery.parent.path == currentParent && epochPath != null) {
        epochPaths.add(epochPath);
      }
    }
    for (final epochPath in epochPaths) {
      final epochFile = File(epochPath).absolute;
      final parent = epochFile.parent;
      final epochName = epochFile.uri.pathSegments.last;
      List<FileSystemEntity> entities;
      try {
        entities = parent.listSync(followLinks: false);
      } on FileSystemException {
        continue;
      }
      for (final entity in entities) {
        final name = entity.uri.pathSegments
            .where((segment) => segment.isNotEmpty)
            .last;
        if (!_isTerminalEpochArtifact(name: name, epochName: epochName) ||
            (retainedGenerationPath != null &&
                File(entity.path).absolute.path == retainedGenerationPath)) {
          continue;
        }
        try {
          entity.deleteSync();
        } on FileSystemException {
          // Terminal cleanup is hygiene only. Retention is safer than
          // invalidating the committed slot or replaying a paid provider call.
        }
      }
    }
  }
}

bool _isTerminalEpochArtifact({
  required String name,
  required String epochName,
}) {
  if (name == epochName ||
      name == '$epochName-wal' ||
      name == '$epochName-shm' ||
      name == '$epochName-journal' ||
      name == '$epochName.generation.sqlite' ||
      name == '$epochName.generation.sqlite-wal' ||
      name == '$epochName.generation.sqlite-shm' ||
      name == '$epochName.generation.sqlite-journal') {
    return true;
  }
  return name.startsWith('$epochName.recovery.') ||
      name.startsWith('$epochName.seal.');
}

void _verifyGenericSeal(String path) {
  final uri = Uri.file(
    File(path).absolute.path,
  ).replace(queryParameters: const <String, String>{'immutable': '1'});
  final db = sqlite3.open(uri.toString(), mode: OpenMode.readOnly, uri: true);
  try {
    final integrity = db.select('PRAGMA integrity_check');
    if (integrity.length != 1 || integrity.single.values.single != 'ok') {
      throw StateError('generic sandbox seal failed integrity verification');
    }
    if (db.select('PRAGMA foreign_key_check').isNotEmpty) {
      throw StateError('generic sandbox seal failed foreign-key verification');
    }
  } finally {
    db.dispose();
  }
}

Map<String, Object?> _verifySealInIndependentProcess(String path) {
  final resolvedExecutable = File(Platform.resolvedExecutable).absolute;
  late final ({String executable, List<String> arguments}) command;
  String? workingDirectory;
  if (!_isDevelopmentRuntime(resolvedExecutable)) {
    command = (
      executable: resolvedExecutable.path,
      arguments: const <String>[agentEvaluationSealVerifierArgument],
    );
  } else {
    Directory? cursor = Directory.current.absolute;
    File? packageConfig;
    File? verifier;
    while (cursor != null) {
      final candidateConfig = File(
        '${cursor.path}/.dart_tool/package_config.json',
      );
      final candidateVerifier = File(
        '${cursor.path}/tool/agent_evaluation_sandbox_seal_verifier.dart',
      );
      if (candidateConfig.existsSync() && candidateVerifier.existsSync()) {
        packageConfig = candidateConfig;
        verifier = candidateVerifier;
        break;
      }
      final parent = cursor.parent;
      cursor = parent.path == cursor.path ? null : parent;
    }
    if (packageConfig == null || verifier == null) {
      throw StateError('independent sandbox seal verifier is unavailable');
    }
    command = _independentSealVerifierCommand(
      packageConfig: packageConfig,
      verifier: verifier,
      releaseEvidence: true,
    );
    workingDirectory = verifier.parent.parent.path;
  }
  _verifyCompiledVerifierBeforeExecution(command.executable);
  final result = Process.runSync(command.executable, <String>[
    ...command.arguments,
    _canonicalFilePath(path),
  ], workingDirectory: workingDirectory);
  if (result.exitCode != 0) {
    throw StateError(
      'independent sandbox seal verification failed: ${result.stderr}',
    );
  }
  final lines = result.stdout
      .toString()
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
  if (lines.length != 1) {
    throw StateError('independent sandbox seal verifier output is malformed');
  }
  final decoded = jsonDecode(lines.single);
  if (decoded is! Map<String, Object?> ||
      decoded.keys.toSet().difference(const <String>{
        'schemaVersion',
        'fileHash',
        'tables',
      }).isNotEmpty ||
      decoded.length != 3 ||
      decoded['schemaVersion'] != agentEvaluationSealVerificationSchema) {
    throw StateError('independent sandbox seal verifier result is invalid');
  }
  final tables = decoded['tables'];
  if (tables is! Map<String, Object?> ||
      tables.keys
          .toSet()
          .difference(agentEvaluationSealTableNames.toSet())
          .isNotEmpty ||
      tables.length != agentEvaluationSealTableNames.length ||
      tables.values.any(
        (value) =>
            value is! Map<String, Object?> ||
            value.length != 2 ||
            !value.containsKey('count') ||
            !value.containsKey('rowsHash') ||
            (value['count'] as int? ?? 0) < 1 ||
            !_isSha256(value['rowsHash']),
      ) ||
      !_isSha256(decoded['fileHash'])) {
    throw StateError(
      'independent sandbox seal omitted production evidence: '
      '${AgentEvaluationHashes.canonicalJson(decoded)}',
    );
  }
  return decoded;
}

void _verifyCompiledVerifierBeforeExecution(String executablePath) {
  final cached = _compiledSealVerifierCommand;
  if (cached == null || cached.executable != executablePath) return;
  final executable = File(executablePath);
  if (!executable.existsSync() ||
      !_hasOwnerOnlyPermissions(executable) ||
      !_hasOwnerOnlyPermissions(cached.cacheDirectory) ||
      _fileSha256(executable.path) != cached.binaryHash) {
    _discardVerifierCache(cached.cacheDirectory);
    _compiledSealVerifierCommand = null;
    throw StateError('compiled sandbox seal verifier identity changed');
  }
}

({
  String executable,
  List<String> arguments,
  String binaryHash,
  String inputIdentity,
  Directory cacheDirectory,
})?
_compiledSealVerifierCommand;

({String executable, List<String> arguments}) _independentSealVerifierCommand({
  required File packageConfig,
  required File verifier,
  required bool releaseEvidence,
}) {
  final resolved = File(Platform.resolvedExecutable).absolute;
  if (!_isDevelopmentRuntime(resolved)) {
    return (
      executable: resolved.path,
      arguments: const <String>[agentEvaluationSealVerifierArgument],
    );
  }
  final dart = _independentDartExecutable();
  final module = File(
    '${verifier.parent.parent.path}/lib/features/story_generation/data/'
    'evaluation/agent_evaluation_sandbox_seal_verifier.dart',
  );
  if (!module.existsSync()) {
    throw StateError('independent sandbox seal verifier module is unavailable');
  }
  final inputIdentity = _contentSha256(
    utf8.encode(
      <String>[
        _fileSha256(verifier.path),
        _fileSha256(module.path),
        _fileSha256(packageConfig.path),
        _fileSha256(dart),
      ].join('|'),
    ),
  );
  final cached = _compiledSealVerifierCommand;
  if (cached != null) {
    final executable = File(cached.executable);
    if (cached.inputIdentity == inputIdentity &&
        executable.existsSync() &&
        _hasOwnerOnlyPermissions(executable) &&
        _hasOwnerOnlyPermissions(cached.cacheDirectory) &&
        _fileSha256(executable.path) == cached.binaryHash) {
      return (executable: executable.path, arguments: const <String>[]);
    }
    _discardVerifierCache(cached.cacheDirectory);
    _compiledSealVerifierCommand = null;
  }

  _cleanExpiredVerifierCaches();
  for (var compileAttempt = 1; compileAttempt <= 2; compileAttempt += 1) {
    Directory? outputDirectory;
    try {
      outputDirectory = Directory.systemTemp.createTempSync(
        'novel-writer-seal-verifier-cache-${inputIdentity.substring(0, 16)}-',
      );
      _makeOwnerOnly(outputDirectory.path, executable: true);
      final executable = File(
        '${outputDirectory.path}${Platform.pathSeparator}seal-verifier'
        '${Platform.isWindows ? '.exe' : ''}',
      );
      final temporaryExecutable = File('${executable.path}.compile');
      final compilation = Process.runSync(dart, <String>[
        'compile',
        'exe',
        '--packages=${packageConfig.path}',
        '-o',
        temporaryExecutable.path,
        verifier.path,
      ], workingDirectory: verifier.parent.parent.path);
      if (compilation.exitCode == 0 && temporaryExecutable.existsSync()) {
        _makeOwnerOnly(temporaryExecutable.path, executable: true);
        temporaryExecutable.renameSync(executable.path);
        final cachedCommand = (
          executable: executable.path,
          arguments: const <String>[],
          binaryHash: _fileSha256(executable.path),
          inputIdentity: inputIdentity,
          cacheDirectory: outputDirectory,
        );
        _compiledSealVerifierCommand = cachedCommand;
        return (
          executable: cachedCommand.executable,
          arguments: cachedCommand.arguments,
        );
      }
      _discardVerifierCache(outputDirectory);
    } on Object {
      if (outputDirectory != null) _discardVerifierCache(outputDirectory);
    }
  }
  return AgentEvaluationSealVerifierLaunchPolicy.afterAotFailure(
    releaseEvidence: releaseEvidence,
    dartExecutable: dart,
    packageConfigPath: packageConfig.path,
    verifierPath: verifier.path,
  );
}

bool _isDevelopmentRuntime(File resolvedExecutable) {
  final name = resolvedExecutable.uri.pathSegments.last;
  return name == 'flutter_tester' ||
      name == 'dart' ||
      name == 'dart.exe' ||
      name == 'dart_precompiled_runtime';
}

void _makeOwnerOnly(String path, {required bool executable}) {
  if (Platform.isWindows) return;
  final result = Process.runSync('chmod', <String>[
    executable ? '700' : '600',
    path,
  ]);
  if (result.exitCode != 0) {
    throw StateError('could not restrict verifier cache permissions');
  }
}

bool _hasOwnerOnlyPermissions(FileSystemEntity entity) {
  if (Platform.isWindows) return true;
  try {
    return entity.statSync().mode & 0x3f == 0;
  } on FileSystemException {
    return false;
  }
}

void _discardVerifierCache(Directory directory) {
  try {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  } on FileSystemException {
    // A stale cache is never trusted again even if best-effort cleanup fails.
  }
}

void _cleanExpiredVerifierCaches() {
  final cutoff = DateTime.now().subtract(const Duration(hours: 24));
  try {
    for (final entity in Directory.systemTemp.listSync(followLinks: false)) {
      if (entity is! Directory ||
          !entity.uri.pathSegments
              .where((segment) => segment.isNotEmpty)
              .last
              .startsWith('novel-writer-seal-verifier-cache-')) {
        continue;
      }
      if (entity.statSync().modified.isBefore(cutoff)) {
        _discardVerifierCache(entity);
      }
    }
  } on FileSystemException {
    // Cleanup is hygiene only; identity and binary hashes remain mandatory.
  }
}

String _independentDartExecutable() {
  final resolved = File(Platform.resolvedExecutable).absolute;
  if (resolved.path.endsWith('${Platform.pathSeparator}flutter_tester')) {
    final cacheDirectory = resolved.parent.parent.parent.parent;
    final dart = File(
      '${cacheDirectory.path}${Platform.pathSeparator}dart-sdk'
      '${Platform.pathSeparator}bin${Platform.pathSeparator}dart',
    );
    if (dart.existsSync()) return dart.path;
  }
  return resolved.path;
}

bool _isSha256(Object? value) =>
    value is String && RegExp(r'^[a-f0-9]{64}$').hasMatch(value);

/// Creates trial-local databases from one immutable authoring fixture snapshot.
class AgentEvaluationFixtureSandbox {
  AgentEvaluationFixtureSandbox._({
    required this.sandboxPath,
    required String fixtureSnapshotPath,
    required String productionDatabasePath,
    required this.executionId,
    required bool deleteOnDispose,
  }) : _fixtureSnapshotPath = fixtureSnapshotPath,
       _productionDatabasePath = productionDatabasePath,
       _deleteOnDispose = deleteOnDispose;

  factory AgentEvaluationFixtureSandbox.create({
    required String fixtureDatabasePath,
    required String productionDatabasePath,
    Directory? temporaryParent,
  }) {
    final fixtureFile = File(fixtureDatabasePath);
    if (!fixtureFile.existsSync()) {
      throw ArgumentError.value(
        fixtureDatabasePath,
        'fixtureDatabasePath',
        'fixture database does not exist',
      );
    }
    final canonicalFixturePath = _canonicalFilePath(fixtureDatabasePath);
    final canonicalProductionPath = _canonicalFilePath(productionDatabasePath);
    if (canonicalFixturePath == canonicalProductionPath) {
      throw ArgumentError(
        'evaluation fixture must not be the production database path',
      );
    }

    final parent = temporaryParent ?? Directory.systemTemp;
    parent.createSync(recursive: true);
    final createdRoot = parent.createTempSync('novel-writer-agent-eval-');
    final root = Directory(createdRoot.resolveSymbolicLinksSync());
    final snapshotPath = '${root.path}/fixture-snapshot.sqlite';
    try {
      final fixture = sqlite3.open(
        canonicalFixturePath,
        mode: OpenMode.readOnly,
      );
      try {
        // VACUUM INTO obtains a transactionally consistent, compact snapshot,
        // including committed WAL content, without writing to the source DB.
        fixture.execute('VACUUM INTO ?', [snapshotPath]);
      } finally {
        fixture.dispose();
      }
      if (!File(snapshotPath).existsSync()) {
        throw StateError('SQLite fixture snapshot was not created');
      }
      return AgentEvaluationFixtureSandbox._(
        sandboxPath: root.path,
        fixtureSnapshotPath: _canonicalFilePath(snapshotPath),
        productionDatabasePath: canonicalProductionPath,
        executionId: null,
        deleteOnDispose: true,
      );
    } catch (_) {
      if (root.existsSync()) root.deleteSync(recursive: true);
      rethrow;
    }
  }

  /// Opens a deterministic, process-recoverable sandbox namespace.
  ///
  /// Unlike [create], closing this object never removes durable trial files.
  /// A terminal release executor must call [purge] only after all evidence it
  /// needs has been archived. The immutable fixture binding prevents a new
  /// process from silently resuming an execution against a different source.
  factory AgentEvaluationFixtureSandbox.openOrCreate({
    required String executionId,
    required String fixtureDatabasePath,
    required String productionDatabasePath,
    required Directory durableParent,
  }) {
    if (executionId.trim().isEmpty) {
      throw ArgumentError.value(executionId, 'executionId', 'is required');
    }
    final fixtureFile = File(fixtureDatabasePath);
    if (!fixtureFile.existsSync()) {
      throw ArgumentError.value(
        fixtureDatabasePath,
        'fixtureDatabasePath',
        'fixture database does not exist',
      );
    }
    final canonicalFixturePath = _canonicalFilePath(fixtureDatabasePath);
    final canonicalProductionPath = _canonicalFilePath(productionDatabasePath);
    if (canonicalFixturePath == canonicalProductionPath) {
      throw ArgumentError(
        'evaluation fixture must not be the production database path',
      );
    }
    durableParent.createSync(recursive: true);
    final namespace = AgentEvaluationHashes.domainHash(
      'eval-durable-sandbox-namespace-v1',
      executionId,
    );
    final createdRoot = Directory('${durableParent.path}/agent-eval-$namespace')
      ..createSync(recursive: true);
    final root = Directory(createdRoot.resolveSymbolicLinksSync());
    final snapshotPath = '${root.path}/fixture-snapshot.sqlite';
    final metadataFile = File('${root.path}/binding.json');
    final lock = File(
      '${root.path}/binding.lock',
    ).openSync(mode: FileMode.append);
    try {
      lock.lockSync(FileLock.exclusive);
      final candidateSnapshot =
          '${root.path}/fixture-snapshot.$pid.${DateTime.now().microsecondsSinceEpoch}.tmp';
      try {
        final fixture = sqlite3.open(
          canonicalFixturePath,
          mode: OpenMode.readOnly,
        );
        try {
          fixture.execute('VACUUM INTO ?', <Object?>[candidateSnapshot]);
        } finally {
          fixture.dispose();
        }
        final fixtureHash = _fileSha256(candidateSnapshot);
        final expectedBinding = <String, Object?>{
          'schemaVersion': 'eval-durable-sandbox-binding-v1',
          'executionId': executionId,
          'fixtureFileHash': fixtureHash,
          'productionDatabasePath': canonicalProductionPath,
        };
        final expectedBindingJson = AgentEvaluationHashes.canonicalJson(
          expectedBinding,
        );
        if (metadataFile.existsSync()) {
          final decoded = jsonDecode(metadataFile.readAsStringSync());
          if (decoded is! Map ||
              AgentEvaluationHashes.canonicalJson(decoded) !=
                  expectedBindingJson ||
              !File(snapshotPath).existsSync() ||
              _fileSha256(snapshotPath) != fixtureHash) {
            throw StateError(
              'durable evaluation sandbox binding or snapshot is inconsistent',
            );
          }
        } else {
          if (File(snapshotPath).existsSync() &&
              _fileSha256(snapshotPath) != fixtureHash) {
            throw StateError(
              'durable evaluation sandbox snapshot is already bound differently',
            );
          }
          if (!File(snapshotPath).existsSync()) {
            File(candidateSnapshot).renameSync(snapshotPath);
          }
          final bindingTemp = File(
            '${root.path}/binding.$pid.${DateTime.now().microsecondsSinceEpoch}.tmp',
          );
          bindingTemp.writeAsStringSync(expectedBindingJson, flush: true);
          bindingTemp.renameSync(metadataFile.path);
        }
      } finally {
        final candidate = File(candidateSnapshot);
        if (candidate.existsSync()) candidate.deleteSync();
      }
    } finally {
      try {
        lock.unlockSync();
      } on FileSystemException {
        // Closing releases the lock even when the platform already dropped it.
      }
      lock.closeSync();
    }
    return AgentEvaluationFixtureSandbox._(
      sandboxPath: root.path,
      fixtureSnapshotPath: _canonicalFilePath(snapshotPath),
      productionDatabasePath: canonicalProductionPath,
      executionId: executionId,
      deleteOnDispose: false,
    );
  }

  final String sandboxPath;
  final String? executionId;
  final String _fixtureSnapshotPath;
  final String _productionDatabasePath;
  final bool _deleteOnDispose;
  final Map<String, AgentEvaluationTrialSandbox> _trials = {};
  var _nextDatabaseId = 0;
  var _disposed = false;

  static const String releaseDomain = 'eval-fixture-sandbox-release-v7';

  static String
  get releaseHash => AgentEvaluationHashes.domainHash(releaseDomain, const <
    String,
    Object?
  >{
    'fixture': 'vacuum-into-immutable-snapshot',
    'generationSeal':
        'close-authoritative-checkpoint-truncate-delete-vacuum-rename-v3',
    'verifierProjection': <String>[
      'story_generation_runs',
      'story_generation_candidate_proofs',
      'story_generation_commit_receipts',
      'eval_production_prepared_results',
      'eval_production_executor_results',
      'version_entries',
    ],
    'verifierProcess':
        'pure-lib-pre-ui-signed-self-app-release-or-bound-aot-dev-release-fail-closed-v4',
    'verifierCache':
        'source-package-dart-binary-hash-owner-only-reverify-retry-diagnostic-source-only-v2',
    'connectionPolicy':
        'long-lived-authoritative-plus-owner-fenced-awaited-short-path-handles-runtime-ack-runner-close-v3',
    'snapshotClaim':
        'runner-owned-vacuum-into-file-hash-integrity-projection-authority-chain-v2',
    'releaseHarnessBusyTimeoutOverride': 'none',
    'independent': 'fresh-copy-per-logical-trial',
    'episode': 'same-open-handle-per-episode-id',
    'connectionBusyTimeoutMs': 5000,
    'production': 'canonical-path-excluded',
    'productionSideEffectCounters': <String, Object?>{
      'contractVersion':
          AgentEvaluationProductionSideEffectKeys.contractVersion,
      'supported': AgentEvaluationProductionSideEffectKeys.supportedList,
      'authoritativeWriteTables': <String>[
        'story_generation_commit_receipts',
        'story_generation_outbox',
        'draft_documents',
        'version_entries',
      ],
    },
  });

  bool get isDisposed => _disposed;
  bool get isDurable => !_deleteOnDispose;

  void verifyRecoverySnapshot({
    required String databasePath,
    required String databaseFileHash,
    required int databaseFileSize,
    required String stateProjectionHash,
  }) {
    if (!isDurable || _disposed) {
      throw StateError('durable recovery verification is unavailable');
    }
    final canonicalPath = _canonicalFilePath(databasePath);
    final canonicalRoot = Directory(sandboxPath).resolveSymbolicLinksSync();
    if (!canonicalPath.startsWith('$canonicalRoot${Platform.pathSeparator}')) {
      throw StateError('sandbox recovery source escaped durable namespace');
    }
    final identity = _readRecoverySnapshotIdentity(canonicalPath);
    if (identity.databaseFileHash != databaseFileHash ||
        identity.databaseFileSize != databaseFileSize ||
        identity.stateProjectionHash != stateProjectionHash) {
      throw StateError('sandbox recovery source projection mismatch');
    }
  }

  /// Reads forbidden side effects from the excluded production database.
  ///
  /// Trial-local commits are expected evidence. These counts instead prove
  /// that the production database which the sandbox excludes was untouched.
  Map<String, int> readProductionSideEffectCounts() {
    final file = File(_productionDatabasePath);
    if (!file.existsSync()) {
      throw StateError('evaluation production database is missing');
    }
    final db = sqlite3.open(_productionDatabasePath, mode: OpenMode.readOnly);
    try {
      int count(String table) {
        final exists = db.select(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
          <Object?>[table],
        );
        if (exists.isEmpty) return 0;
        return db.select('SELECT COUNT(*) AS count FROM $table').single['count']
            as int;
      }

      final commitReceipts = count('story_generation_commit_receipts');
      final outbox = count('story_generation_outbox');
      final drafts = count('draft_documents');
      final versions = count('version_entries');
      return Map<String, int>.unmodifiable(<String, int>{
        AgentEvaluationProductionSideEffectKeys.commitReceipt: commitReceipts,
        AgentEvaluationProductionSideEffectKeys.outbox: outbox,
        AgentEvaluationProductionSideEffectKeys.authoritativeWrite:
            commitReceipts + outbox + drafts + versions,
      });
    } finally {
      db.dispose();
    }
  }

  AgentEvaluationTrialSandbox openTrial({
    required String armId,
    required String trialId,
    required AgentEvaluationIsolationMode isolationMode,
  }) {
    if (_disposed) throw StateError('evaluation fixture sandbox is disposed');
    if (isDurable) {
      throw StateError(
        'durable evaluation sandboxes require an epoch-fenced trial copy',
      );
    }
    if (armId.trim().isEmpty || trialId.trim().isEmpty) {
      throw ArgumentError('armId and trialId must be non-empty');
    }

    final key = '$armId\u0000$trialId';
    final existing = _trials[key];
    if (existing != null) {
      if (isolationMode == AgentEvaluationIsolationMode.episode &&
          existing.isolationMode == isolationMode &&
          !existing.isDisposed) {
        return existing;
      }
      throw StateError('logical evaluation trial was already opened');
    }

    _nextDatabaseId += 1;
    final trialPath = '$sandboxPath/trial-$_nextDatabaseId.sqlite';
    File(_fixtureSnapshotPath).copySync(trialPath);
    final canonicalTrialPath = _canonicalFilePath(trialPath);
    if (canonicalTrialPath == _productionDatabasePath) {
      throw StateError('trial database resolved to the production DB path');
    }
    final database = sqlite3.open(canonicalTrialPath);
    try {
      database.execute('PRAGMA busy_timeout = 5000');
      database.execute('PRAGMA foreign_keys = ON');
      database.execute('PRAGMA journal_mode = WAL');
      database.execute('PRAGMA synchronous = FULL');
      database.execute('PRAGMA wal_autocheckpoint = 1');
      database.execute('PRAGMA checkpoint_fullfsync = ON');
      final trial = AgentEvaluationTrialSandbox._(
        armId: armId,
        trialId: trialId,
        isolationMode: isolationMode,
        databasePath: canonicalTrialPath,
        database: database,
        terminalCleanupEpochPaths: const <String>{},
      );
      _trials[key] = trial;
      return trial;
    } catch (_) {
      database.dispose();
      final trialFile = File(trialPath);
      if (trialFile.existsSync()) trialFile.deleteSync();
      rethrow;
    }
  }

  /// Creates an epoch-local copy. It can be mutated freely by the owning
  /// process, but it is not visible to any successor until the authority DB
  /// commits it as a sandbox generation in the same transaction as slot seal.
  AgentEvaluationTrialSandbox openLeaseTrial({
    required String armId,
    required String trialId,
    required AgentEvaluationIsolationMode isolationMode,
    required int leaseEpoch,
    required String leaseOwner,
    required String leaseTrialSlotId,
    String? sourceDatabasePath,
    String? expectedSourceFileHash,
    int? expectedSourceFileSize,
    String? expectedSourceStateProjectionHash,
  }) {
    if (_disposed) throw StateError('evaluation fixture sandbox is disposed');
    if (!isDurable) {
      throw StateError('epoch-fenced trial copies require a durable sandbox');
    }
    if (armId.trim().isEmpty ||
        trialId.trim().isEmpty ||
        leaseEpoch <= 0 ||
        leaseOwner.trim().isEmpty ||
        leaseTrialSlotId.trim().isEmpty) {
      throw ArgumentError('invalid epoch-fenced sandbox identity');
    }
    final key =
        '$trialId\u0000$leaseTrialSlotId\u0000$leaseEpoch\u0000$leaseOwner';
    final existing = _trials[key];
    if (existing != null && !existing.isDisposed) return existing;
    final sourcePath = sourceDatabasePath ?? _fixtureSnapshotPath;
    final canonicalSource = _canonicalFilePath(sourcePath);
    final rootDirectory = Directory(sandboxPath).absolute;
    final canonicalRoot = rootDirectory.existsSync()
        ? rootDirectory.resolveSymbolicLinksSync()
        : rootDirectory.path;
    if (canonicalSource != _canonicalFilePath(_fixtureSnapshotPath) &&
        !canonicalSource.startsWith(
          '$canonicalRoot${Platform.pathSeparator}',
        )) {
      throw StateError('sandbox generation source escaped durable namespace');
    }
    if (!File(canonicalSource).existsSync()) {
      throw StateError('sandbox generation source is missing');
    }
    if (expectedSourceFileHash != null &&
        _fileSha256(canonicalSource) != expectedSourceFileHash) {
      throw StateError('sandbox generation source hash mismatch');
    }
    if (expectedSourceStateProjectionHash != null) {
      final identity = _readRecoverySnapshotIdentity(canonicalSource);
      if (expectedSourceFileHash == null ||
          expectedSourceFileSize == null ||
          identity.databaseFileHash != expectedSourceFileHash ||
          identity.databaseFileSize != expectedSourceFileSize ||
          identity.stateProjectionHash != expectedSourceStateProjectionHash) {
        throw StateError('sandbox recovery source projection mismatch');
      }
    }
    final pathHash = AgentEvaluationHashes.domainHash(
      'eval-sandbox-epoch-file-v1',
      <String, Object?>{
        'executionId': executionId,
        'armId': armId,
        'trialId': trialId,
        'trialSlotId': leaseTrialSlotId,
        'leaseEpoch': leaseEpoch,
        'leaseOwner': leaseOwner,
      },
    );
    final trialPath = '$sandboxPath/epoch-$pathHash.sqlite';
    final file = File(trialPath);
    if (file.existsSync()) {
      throw StateError('epoch-local sandbox path already exists');
    }
    File(canonicalSource).copySync(trialPath);
    final canonicalTrialPath = _canonicalFilePath(trialPath);
    final database = sqlite3.open(canonicalTrialPath);
    try {
      database.execute('PRAGMA busy_timeout = 5000');
      database.execute('PRAGMA foreign_keys = ON');
      database.execute('PRAGMA journal_mode = WAL');
      database.execute('PRAGMA synchronous = FULL');
      database.execute('PRAGMA wal_autocheckpoint = 1');
      database.execute('PRAGMA checkpoint_fullfsync = ON');
      final trial = AgentEvaluationTrialSandbox._(
        armId: armId,
        trialId: trialId,
        isolationMode: isolationMode,
        databasePath: canonicalTrialPath,
        database: database,
        terminalCleanupEpochPaths: _terminalCleanupEpochPaths(
          currentEpochPath: canonicalTrialPath,
          sourceDatabasePath: sourceDatabasePath,
        ),
      );
      _trials[key] = trial;
      return trial;
    } catch (_) {
      database.dispose();
      if (file.existsSync()) file.deleteSync();
      rethrow;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final trial in _trials.values) {
      trial.dispose();
    }
    _trials.clear();
    if (_deleteOnDispose) {
      final root = Directory(sandboxPath);
      if (root.existsSync()) root.deleteSync(recursive: true);
    }
  }

  /// Explicit terminal cleanup for a durable namespace.
  void purge() {
    if (!isDurable) return;
    if (!_disposed) {
      throw StateError('durable sandbox must be disposed before purge');
    }
    final root = Directory(sandboxPath);
    if (root.existsSync()) root.deleteSync(recursive: true);
  }
}

String _canonicalFilePath(String path) {
  final file = File(path).absolute;
  if (file.existsSync()) return file.resolveSymbolicLinksSync();
  return file.path;
}

Set<String> _terminalCleanupEpochPaths({
  required String currentEpochPath,
  required String? sourceDatabasePath,
}) {
  final result = <String>{currentEpochPath};
  if (sourceDatabasePath == null) return result;
  final source = File(sourceDatabasePath).absolute;
  final recoveryEpochPath = _recoveryEpochPath(source);
  if (recoveryEpochPath != null) result.add(recoveryEpochPath);
  return result;
}

String? _recoveryEpochPath(File source) {
  final name = source.uri.pathSegments.last;
  final recovery = RegExp(
    r'^(epoch-[a-f0-9]{64}\.sqlite)\.recovery\.[a-f0-9]{64}\.sqlite$',
  ).firstMatch(name);
  return recovery == null
      ? null
      : '${source.parent.path}${Platform.pathSeparator}${recovery[1]}';
}

String _fileSha256(String path) {
  return _contentSha256(File(path).readAsBytesSync());
}

AgentEvaluationSandboxRecoverySnapshot _readRecoverySnapshotIdentity(
  String path,
) {
  final canonicalPath = _canonicalFilePath(path);
  final file = File(canonicalPath);
  if (!file.existsSync()) {
    throw StateError('sandbox recovery snapshot is missing');
  }
  final databaseFileHash = _fileSha256(canonicalPath);
  final databaseFileSize = file.lengthSync();
  if (databaseFileSize <= 0) {
    throw StateError('sandbox recovery snapshot is empty');
  }
  final database = sqlite3.open(canonicalPath, mode: OpenMode.readOnly);
  try {
    final integrity = database
        .select('PRAGMA integrity_check')
        .single
        .values
        .single;
    if (integrity != 'ok') {
      throw StateError('sandbox recovery snapshot failed integrity check');
    }
    final userVersion =
        database.select('PRAGMA user_version').single['user_version'] as int;
    final schemaRows = database.select('''SELECT type, name, tbl_name, sql
         FROM sqlite_schema
         WHERE name NOT LIKE 'sqlite_%'
         ORDER BY type, name, tbl_name''');
    final schemaProjection = schemaRows
        .map(
          (row) => <String, Object?>{
            'type': row['type'],
            'name': row['name'],
            'table': row['tbl_name'],
            'sql': row['sql'],
          },
        )
        .toList(growable: false);
    final stateProjectionHash = AgentEvaluationHashes.domainHash(
      'eval-sandbox-recovery-state-v1',
      <String, Object?>{
        'databaseFileHash': databaseFileHash,
        'databaseFileSize': databaseFileSize,
        'integrity': integrity,
        'userVersion': userVersion,
        'schemaHash': AgentEvaluationHashes.domainHash(
          'eval-sandbox-recovery-schema-v1',
          schemaProjection,
        ),
      },
    );
    return AgentEvaluationSandboxRecoverySnapshot(
      databasePath: canonicalPath,
      databaseFileHash: databaseFileHash,
      databaseFileSize: databaseFileSize,
      stateProjectionHash: stateProjectionHash,
    );
  } finally {
    database.dispose();
  }
}

String _contentSha256(List<int> bytes) {
  final digest = const DartSha256().hashSync(bytes);
  return digest.bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}
