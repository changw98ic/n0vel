import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'app_auto_backup.dart';
import 'app_authoring_storage_io_support.dart';
import 'storage_lock.dart';

class FileAutoBackupService implements AutoBackupService {
  FileAutoBackupService({String? dbPath})
    : _dbPath = dbPath ?? resolveAuthoringDbPath();

  final String _dbPath;

  @override
  Future<BackupEntry> createBackup() =>
      StorageLock().synchronized(_dbPath, _createBackupLocked);

  Future<BackupEntry> _createBackupLocked() async {
    final source = File(_dbPath);
    if (!await source.exists()) {
      throw StateError('database file not found: $_dbPath');
    }

    final dir = _backupDirectory;
    await dir.create(recursive: true);

    final now = DateTime.now();
    final baseId = _formatTimestamp(now);
    var id = baseId;
    var target = File('${dir.path}/authoring_$id.db');
    var seq = 1;
    while (await target.exists()) {
      id = '${baseId}_$seq';
      target = File('${dir.path}/authoring_$id.db');
      seq++;
    }

    final temporary = File('${target.path}.tmp-$pid');
    if (await temporary.exists()) await temporary.delete();
    final sourceDb = sqlite3.open(source.path, mode: OpenMode.readOnly);
    try {
      // SQLite owns the snapshot so committed WAL pages are included.
      sourceDb.execute('VACUUM INTO ?', <Object?>[temporary.path]);
    } finally {
      sourceDb.dispose();
    }
    _validateSnapshot(temporary.path);
    await temporary.rename(target.path);

    final stat = await target.stat();
    return BackupEntry(
      id: id,
      sizeBytes: stat.size,
      createdAtMs: now.millisecondsSinceEpoch,
    );
  }

  @override
  Future<List<BackupEntry>> listBackups() =>
      StorageLock().synchronized(_dbPath, _listBackupsLocked);

  Future<List<BackupEntry>> _listBackupsLocked() async {
    // Complete or roll back an interrupted swap before exposing backup
    // metadata to the recovery UI. This runs before the app attempts to open
    // the authoring database again on the next startup.
    await _recoverInterruptedRestore();
    final dir = _backupDirectory;
    if (!await dir.exists()) {
      return const [];
    }

    final entries = <BackupEntry>[];
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (!_isBackupFile(name)) continue;

      final id = _extractId(name);
      final stat = await entity.stat();
      entries.add(
        BackupEntry(
          id: id,
          sizeBytes: stat.size,
          createdAtMs: stat.modified.millisecondsSinceEpoch,
        ),
      );
    }

    entries.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    return entries;
  }

  @override
  Future<void> restoreBackup(String id) =>
      StorageLock().synchronized(_dbPath, () => _restoreBackupLocked(id));

  Future<void> _restoreBackupLocked(String id) async {
    await _recoverInterruptedRestore();
    _requireValidId(id);
    final dir = _backupDirectory;
    final backupFile = File('${dir.path}/authoring_$id.db');
    if (!await backupFile.exists()) {
      throw StateError('backup not found: $id');
    }

    final target = File(_dbPath).absolute;
    await target.parent.create(recursive: true);
    _validateSnapshot(backupFile.path);

    final operationId = '$pid-${DateTime.now().toUtc().microsecondsSinceEpoch}';
    final stage = File('${target.path}.restore-$operationId.tmp');
    final previous = File('${target.path}.restore-$operationId.previous');
    final journal = _RestoreJournal(
      targetPath: target.path,
      operationId: operationId,
      phase: _RestorePhase.prepared,
    );
    if (await stage.exists()) await stage.delete();
    if (await previous.exists()) await previous.delete();
    final backupDb = sqlite3.open(backupFile.path, mode: OpenMode.readOnly);
    try {
      backupDb.execute('VACUUM INTO ?', <Object?>[stage.path]);
    } finally {
      backupDb.dispose();
    }
    _validateSnapshot(stage.path);

    var oldMoved = false;
    var newInstalled = false;
    var verified = false;
    try {
      await _writeRestoreJournal(journal);
      // The app-level coordinator closes its registry before entering this
      // method. Renaming the live inode (instead of deleting it) preserves a
      // byte-for-byte rollback source if the staged backup cannot be
      // installed or validated.
      oldMoved = await _moveLiveDatabaseAside(target, previous);
      await _writeRestoreJournal(journal.withPhase(_RestorePhase.oldRenamed));

      await stage.rename(target.path);
      newInstalled = true;
      await _writeRestoreJournal(journal.withPhase(_RestorePhase.newInstalled));

      _validateSnapshot(target.path);
      verified = true;
      await _writeRestoreJournal(journal.withPhase(_RestorePhase.verified));

      await _deleteIfExists(previous);
      await _deleteSidecars(previous.path);
      await _deleteRestoreJournal();
    } catch (error, stackTrace) {
      // Once the new database has passed integrity_check, a cleanup failure
      // should leave the verified database and journal for the next startup;
      // rolling back a valid restore would make recovery less reliable.
      if (!verified &&
          (oldMoved || newInstalled || await _hasPreviousArtifacts(previous))) {
        try {
          await _rollbackRestore(target, previous);
          await _deleteRestoreJournal();
        } catch (rollbackError, rollbackStackTrace) {
          throw StateError(
            'backup restore failed and rollback failed: '
            '$error; rollback=$rollbackError\n$rollbackStackTrace',
          );
        }
      }
      Error.throwWithStackTrace(error, stackTrace);
    } finally {
      // A stage that was never installed is safe to discard. A previous file
      // is intentionally retained when verified cleanup failed; the journal
      // recovery path will remove it only after re-validating the target.
      if (await stage.exists()) await stage.delete();
    }
  }

  @override
  Future<void> deleteBackup(String id) =>
      StorageLock().synchronized(_dbPath, () => _deleteBackupLocked(id));

  Future<void> _deleteBackupLocked(String id) async {
    if (!RegExp(r'^\d{8}_\d{6}_\d{3}(?:_\d+)?$').hasMatch(id)) return;
    final dir = _backupDirectory;
    final backupFile = File('${dir.path}/authoring_$id.db');
    if (await backupFile.exists()) {
      await backupFile.delete();
    }
  }

  @override
  Future<int> pruneBackups({int keepCount = 10}) async {
    final entries = await listBackups();
    if (entries.length <= keepCount) return 0;

    var deleted = 0;
    for (var i = keepCount; i < entries.length; i++) {
      await deleteBackup(entries[i].id);
      deleted++;
    }
    return deleted;
  }

  Directory get _backupDirectory {
    final parent = File(_dbPath).parent;
    return Directory('${parent.path}/backups');
  }

  String get _restoreJournalPath =>
      '${File(_dbPath).absolute.path}.restore-journal.json';

  Future<void> _recoverInterruptedRestore() async {
    final journalFile = File(_restoreJournalPath);
    if (!await journalFile.exists()) return;

    final journal = await _readRestoreJournal(journalFile);
    final target = File(journal.targetPath);
    final previous = journal.previousFile;
    final stage = journal.stageFile;
    final targetIsValid = await _isValidSnapshot(target.path);

    if (targetIsValid) {
      // A crash after installation (including after the `verified` journal
      // write) can safely commit the new target and remove the old inode.
      await _deleteIfExists(previous);
      await _deleteSidecars(previous.path);
      await _deleteIfExists(stage);
      await _deleteRestoreJournal();
      return;
    }

    final hasPrevious = await _hasPreviousArtifacts(previous);
    if (hasPrevious) {
      // The old inode is the only safe source when the target is absent or
      // fails integrity_check. Restore it before clearing the journal.
      await _rollbackRestore(target, previous);
      await _deleteIfExists(stage);
      await _deleteRestoreJournal();
      return;
    }

    if (journal.phase == _RestorePhase.prepared && !await target.exists()) {
      // The process crashed before moving the original target. There is no
      // previous inode to restore; discard the uninstalled stage.
      await _deleteIfExists(stage);
      await _deleteRestoreJournal();
      return;
    }

    throw StateError(
      'restore journal cannot recover ${target.path}; '
      'target is invalid and no rollback source exists',
    );
  }

  Future<_RestoreJournal> _readRestoreJournal(File file) async {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw StateError('restore journal is not an object');
    }
    final journal = _RestoreJournal.fromJson(decoded);
    final expectedTarget = File(_dbPath).absolute.path;
    if (journal.targetPath != expectedTarget) {
      throw StateError('restore journal target does not match database path');
    }
    return journal;
  }

  Future<void> _writeRestoreJournal(_RestoreJournal journal) async {
    final file = File(_restoreJournalPath);
    final temporary = File('${file.path}.tmp-$pid');
    await temporary.writeAsString(jsonEncode(journal.toJson()), flush: true);
    try {
      await temporary.rename(file.path);
    } on FileSystemException {
      // Windows cannot always replace an existing file with rename. The
      // journal is advisory, so fall back to a flushed replacement while
      // keeping the operation itself recoverable by the previous inode.
      if (await file.exists()) await file.delete();
      await temporary.rename(file.path);
    }
  }

  Future<void> _deleteRestoreJournal() async {
    await _deleteIfExists(File(_restoreJournalPath));
  }

  Future<bool> _moveLiveDatabaseAside(File target, File previous) async {
    var moved = false;
    if (await target.exists()) {
      await _deleteIfExists(previous);
      await target.rename(previous.path);
      moved = true;
    }
    for (final suffix in const <String>['-wal', '-shm']) {
      final liveSidecar = File('${target.path}$suffix');
      if (!await liveSidecar.exists()) continue;
      final previousSidecar = File('${previous.path}$suffix');
      await _deleteIfExists(previousSidecar);
      await liveSidecar.rename(previousSidecar.path);
      moved = true;
    }
    return moved;
  }

  Future<void> _rollbackRestore(File target, File previous) async {
    await _deleteIfExists(target);
    await _deleteSidecars(target.path);
    if (await previous.exists()) {
      await previous.rename(target.path);
    }
    for (final suffix in const <String>['-wal', '-shm']) {
      final previousSidecar = File('${previous.path}$suffix');
      if (!await previousSidecar.exists()) continue;
      await previousSidecar.rename('${target.path}$suffix');
    }
  }

  Future<bool> _hasPreviousArtifacts(File previous) async {
    if (await previous.exists()) return true;
    for (final suffix in const <String>['-wal', '-shm']) {
      if (await File('${previous.path}$suffix').exists()) return true;
    }
    return false;
  }

  Future<void> _deleteSidecars(String path) async {
    for (final suffix in const <String>['-wal', '-shm']) {
      await _deleteIfExists(File('$path$suffix'));
    }
  }

  static Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) await file.delete();
  }

  static Future<bool> _isValidSnapshot(String path) async {
    final file = File(path);
    if (!await file.exists()) return false;
    try {
      _validateSnapshot(path);
      return true;
    } on Object {
      return false;
    }
  }

  static String _formatTimestamp(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    final ms = dt.millisecond.toString().padLeft(3, '0');
    return '$y$m$d'
        '_$h$min${s}_$ms';
  }

  static bool _isBackupFile(String name) {
    return name.startsWith('authoring_') &&
        name.endsWith('.db') &&
        name != 'authoring.db';
  }

  static String _extractId(String name) {
    return name.replaceAll('authoring_', '').replaceAll('.db', '');
  }

  static void _requireValidId(String id) {
    if (!RegExp(r'^\d{8}_\d{6}_\d{3}(?:_\d+)?$').hasMatch(id)) {
      throw StateError('invalid backup id');
    }
  }

  static void _validateSnapshot(String path) {
    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    try {
      final result = db.select('PRAGMA integrity_check').single.values.single;
      if (result != 'ok') throw StateError('backup integrity check failed');
    } finally {
      db.dispose();
    }
  }
}

abstract final class _RestorePhase {
  static const prepared = 'prepared';
  static const oldRenamed = 'old-renamed';
  static const newInstalled = 'new-installed';
  static const verified = 'verified';

  static bool isKnown(String value) => const <String>{
    prepared,
    oldRenamed,
    newInstalled,
    verified,
  }.contains(value);
}

class _RestoreJournal {
  const _RestoreJournal({
    required this.targetPath,
    required this.operationId,
    required this.phase,
  });

  final String targetPath;
  final String operationId;
  final String phase;

  File get stageFile => File('$targetPath.restore-$operationId.tmp');

  File get previousFile => File('$targetPath.restore-$operationId.previous');

  _RestoreJournal withPhase(String nextPhase) => _RestoreJournal(
    targetPath: targetPath,
    operationId: operationId,
    phase: nextPhase,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'targetPath': targetPath,
    'operationId': operationId,
    'phase': phase,
  };

  factory _RestoreJournal.fromJson(Map<dynamic, dynamic> json) {
    final targetPath = json['targetPath'];
    final operationId = json['operationId'];
    final phase = json['phase'];
    if (targetPath is! String ||
        operationId is! String ||
        phase is! String ||
        operationId.isEmpty ||
        !RegExp(r'^[0-9]+-[0-9]+$').hasMatch(operationId) ||
        !_RestorePhase.isKnown(phase)) {
      throw StateError('restore journal fields are invalid');
    }
    return _RestoreJournal(
      targetPath: targetPath,
      operationId: operationId,
      phase: phase,
    );
  }
}

AutoBackupService createAutoBackupService() => FileAutoBackupService();
