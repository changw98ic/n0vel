import '../logging/app_log.dart';
import 'storage_fingerprint.dart';

/// Thrown when write-after-verification fails after all retry attempts.
///
/// Callers can catch this exception to handle data persistence failures
/// explicitly (e.g. notify the user, fall back to a backup, etc.).
class StorageWriteVerificationException implements Exception {
  StorageWriteVerificationException({
    required this.label,
    required this.attempts,
    required this.snapshotFingerprint,
    required this.verifyFingerprint,
  });

  /// Human-readable label identifying which storage operation failed.
  final String label;

  /// Number of save attempts made (including the initial write).
  final int attempts;

  /// Fingerprint of the data read back immediately after save.
  final int snapshotFingerprint;

  /// Fingerprint of the data read back during the verification read.
  final int verifyFingerprint;

  @override
  String toString() =>
      'StorageWriteVerificationException($label): '
      'verification failed after $attempts attempt(s) '
      '(snapshot=$snapshotFingerprint, verify=$verifyFingerprint)';
}

/// Executes a save operation with write-after-verification and one retry.
///
/// [label] is a human-readable tag for logging (e.g. "workspace", "outline").
/// [save] performs the actual write to the persistent store.
/// [reload] reads the data back from the persistent store.
/// [data] is the payload to persist.
///
/// Flow:
/// 1. Call [save] with [data].
/// 2. Call [reload] to capture a "snapshot" fingerprint right after the write.
/// 3. Call [reload] again and compare the fingerprint.
/// 4. On match, return.
/// 5. On mismatch: log warning, retry once (steps 1-4).
/// 6. On second mismatch: throw [StorageWriteVerificationException].
///
/// This two-read approach is necessary because the storage layer transforms
/// data during save/load (column renames, default values, etc.), so the
/// input [data] cannot be compared directly to the loaded result.
Future<void> verifyAfterWrite({
  required String label,
  required Future<void> Function(Map<String, Object?> data) save,
  required Future<Map<String, Object?>?> Function() reload,
  required Map<String, Object?> data,
}) async {
  const maxAttempts = 2;

  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    await save(data);

    final snapshot = await reload();
    if (snapshot == null) {
      AppLog.w(
        '$label write verification: snapshot reload returned null '
        '(attempt $attempt)',
        tag: 'StorageVerify',
      );
      if (attempt < maxAttempts) continue;
      throw StorageWriteVerificationException(
        label: label,
        attempts: attempt,
        snapshotFingerprint: 0,
        verifyFingerprint: 0,
      );
    }
    final snapshotFp = storageFingerprint(snapshot);

    // Read a second time to confirm the data is durably on disk.
    final verify = await reload();
    if (verify == null) {
      AppLog.w(
        '$label write verification: verify reload returned null '
        '(attempt $attempt)',
        tag: 'StorageVerify',
      );
      if (attempt < maxAttempts) continue;
      throw StorageWriteVerificationException(
        label: label,
        attempts: attempt,
        snapshotFingerprint: snapshotFp,
        verifyFingerprint: 0,
      );
    }
    final verifyFp = storageFingerprint(verify);

    if (verifyFp == snapshotFp) return;

    AppLog.w(
      '$label write verification: fingerprint mismatch '
      '(attempt $attempt, snapshot=$snapshotFp, verify=$verifyFp)',
      tag: 'StorageVerify',
    );

    if (attempt < maxAttempts) continue;

    throw StorageWriteVerificationException(
      label: label,
      attempts: attempt,
      snapshotFingerprint: snapshotFp,
      verifyFingerprint: verifyFp,
    );
  }
}
