import 'app_auto_backup.dart';

class _NoopAutoBackupService implements AutoBackupService {
  @override
  Future<BackupEntry> createBackup() async {
    throw UnsupportedError('auto-backup requires dart:io');
  }

  @override
  Future<List<BackupEntry>> listBackups() async => const [];

  @override
  Future<void> restoreBackup(String id) async {
    throw UnsupportedError('auto-backup requires dart:io');
  }

  @override
  Future<void> deleteBackup(String id) async {}

  @override
  Future<int> pruneBackups({int keepCount = 10}) async => 0;
}

AutoBackupService createAutoBackupService() => _NoopAutoBackupService();
