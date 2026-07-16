import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'app_auto_backup.dart';
import 'app_authoring_storage_io_support.dart';

class FileAutoBackupService implements AutoBackupService {
  FileAutoBackupService({String? dbPath})
    : _dbPath = dbPath ?? resolveAuthoringDbPath();

  final String _dbPath;

  @override
  Future<BackupEntry> createBackup() async {
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
  Future<List<BackupEntry>> listBackups() async {
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
  Future<void> restoreBackup(String id) async {
    _requireValidId(id);
    final dir = _backupDirectory;
    final backupFile = File('${dir.path}/authoring_$id.db');
    if (!await backupFile.exists()) {
      throw StateError('backup not found: $id');
    }

    _validateSnapshot(backupFile.path);
    final target = File(_dbPath).absolute;
    await target.parent.create(recursive: true);
    final stage = File('${target.path}.restore-$pid.tmp');
    if (await stage.exists()) await stage.delete();
    final backupDb = sqlite3.open(backupFile.path, mode: OpenMode.readOnly);
    try {
      backupDb.execute('VACUUM INTO ?', <Object?>[stage.path]);
    } finally {
      backupDb.dispose();
    }
    _validateSnapshot(stage.path);

    // Refuse to replace a busy live database, and checkpoint its WAL before
    // the atomic rename. Callers must release application-owned handles first.
    var targetIsCorrupt = false;
    if (await target.exists()) {
      Database? live;
      try {
        live = sqlite3.open(target.path);
        live.execute('PRAGMA busy_timeout = 1');
        live.execute('PRAGMA wal_checkpoint(TRUNCATE)');
        live.execute('BEGIN EXCLUSIVE');
        live.execute('COMMIT');
      } on SqliteException catch (error) {
        if (_isCorruptDatabaseError(error)) {
          targetIsCorrupt = true;
        } else {
          if (live?.autocommit == false) live!.execute('ROLLBACK');
          if (await stage.exists()) await stage.delete();
          rethrow;
        }
      } on Object {
        if (live?.autocommit == false) live!.execute('ROLLBACK');
        if (await stage.exists()) await stage.delete();
        rethrow;
      } finally {
        live?.dispose();
      }
    }
    try {
      if (targetIsCorrupt) {
        await _replaceCorruptTarget(stage: stage, target: target);
      } else {
        await stage.rename(target.path);
      }
    } on Object {
      if (await stage.exists()) await stage.delete();
      rethrow;
    }
    for (final suffix in const <String>['-wal', '-shm']) {
      final sidecar = File('${target.path}$suffix');
      if (await sidecar.exists()) await sidecar.delete();
    }
  }

  @override
  Future<void> deleteBackup(String id) async {
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

  static bool _isCorruptDatabaseError(SqliteException error) {
    return error.resultCode == SqlError.SQLITE_CORRUPT ||
        error.resultCode == SqlError.SQLITE_NOTADB;
  }

  static Future<void> _replaceCorruptTarget({
    required File stage,
    required File target,
  }) async {
    final quarantineSuffix =
        '.corrupt-$pid-'
        '${DateTime.now().microsecondsSinceEpoch}';
    final displaced = <({File original, File quarantine})>[];

    Future<void> displace(File original) async {
      if (!await original.exists()) return;
      final quarantine = File('${original.path}$quarantineSuffix');
      await original.rename(quarantine.path);
      displaced.add((original: original, quarantine: quarantine));
    }

    try {
      await displace(target);
      await displace(File('${target.path}-wal'));
      await displace(File('${target.path}-shm'));
      await stage.rename(target.path);
    } on Object {
      for (final entry in displaced.reversed) {
        if (await entry.quarantine.exists() && !await entry.original.exists()) {
          await entry.quarantine.rename(entry.original.path);
        }
      }
      rethrow;
    }

    for (final entry in displaced) {
      try {
        if (await entry.quarantine.exists()) {
          await entry.quarantine.delete();
        }
      } on FileSystemException {
        // The restored database is already active at the canonical path.
        // A quarantined corrupt file can be cleaned up on a later startup.
      }
    }
  }
}

AutoBackupService createAutoBackupService() => FileAutoBackupService();
