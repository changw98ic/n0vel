import 'app_auto_backup_stub.dart'
    if (dart.library.io) 'app_auto_backup_io.dart';

class BackupEntry {
  const BackupEntry({
    required this.id,
    required this.sizeBytes,
    required this.createdAtMs,
  });

  final String id;
  final int sizeBytes;
  final int createdAtMs;

  @override
  String toString() => 'BackupEntry($id, ${sizeBytes}B, $createdAtMs)';
}

abstract class AutoBackupService {
  Future<BackupEntry> createBackup();

  Future<List<BackupEntry>> listBackups();

  Future<void> restoreBackup(String id);

  Future<void> deleteBackup(String id);

  Future<int> pruneBackups({int keepCount = 10});
}

AutoBackupService createDefaultAutoBackupService() => createAutoBackupService();
