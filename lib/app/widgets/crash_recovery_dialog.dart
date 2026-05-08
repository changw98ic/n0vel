import 'package:flutter/material.dart';

import '../state/app_auto_backup.dart';
import 'desktop_status_modal.dart';

/// Shows a dialog offering to restore the most recent backup after a crash.
///
/// Returns `true` if the user chose to restore, `false` otherwise.
Future<bool> showCrashRecoveryDialog(
  BuildContext context, {
  required List<BackupEntry> backups,
}) async {
  if (backups.isEmpty) return false;
  final latest = backups.first;

  final result = await showDialog<bool>(
    context: context,
    barrierLabel: '关闭',
    barrierDismissible: false,
    builder: (dialogContext) {
      return DesktopModalDialog(
        title: '检测到异常退出',
        description: '上次应用未正常关闭，可能存在数据丢失。',
        body: Text(
          '发现最近一次备份：${_formatBackupTime(latest.createdAtMs)}'
          '（${_formatSize(latest.sizeBytes)}）。\n'
          '是否恢复该备份？',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('跳过'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('恢复备份'),
          ),
        ],
      );
    },
  );

  return result == true;
}

String _formatBackupTime(int millis) {
  final dt = DateTime.fromMillisecondsSinceEpoch(millis);
  return '${dt.year}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';
}

String _formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
