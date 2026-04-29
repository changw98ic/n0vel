import 'dart:io';

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

    await source.copy(target.path);

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
      entries.add(BackupEntry(
        id: id,
        sizeBytes: stat.size,
        createdAtMs: stat.modified.millisecondsSinceEpoch,
      ));
    }

    entries.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    return entries;
  }

  @override
  Future<void> restoreBackup(String id) async {
    final dir = _backupDirectory;
    final backupFile = File('${dir.path}/authoring_$id.db');
    if (!await backupFile.exists()) {
      throw StateError('backup not found: $id');
    }

    final target = File(_dbPath);
    await target.parent.create(recursive: true);
    await backupFile.copy(target.path);
  }

  @override
  Future<void> deleteBackup(String id) async {
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
    return '$y$m$d' '_$h$min${s}_$ms';
  }

  static bool _isBackupFile(String name) {
    return name.startsWith('authoring_') &&
        name.endsWith('.db') &&
        name != 'authoring.db';
  }

  static String _extractId(String name) {
    return name.replaceAll('authoring_', '').replaceAll('.db', '');
  }
}

AutoBackupService createAutoBackupService() => FileAutoBackupService();
