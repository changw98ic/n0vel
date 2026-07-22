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

/// The externally visible phases of a disaster-recovery attempt.
///
/// Recovery is intentionally modelled separately from [AutoBackupService] so
/// callers can quiesce their live stores before invoking a file replacement.
/// A failed attempt is a terminal state: the caller must not continue using a
/// registry whose database connections were closed for the swap.
enum BackupRecoveryPhase { idle, preparing, restoring, succeeded, failed }

/// Immutable state emitted by [BackupRecoveryCoordinator].
class BackupRecoveryState {
  const BackupRecoveryState({required this.phase, this.error, this.stackTrace});

  const BackupRecoveryState.idle() : this(phase: BackupRecoveryPhase.idle);

  final BackupRecoveryPhase phase;
  final Object? error;
  final StackTrace? stackTrace;

  bool get isTerminal =>
      phase == BackupRecoveryPhase.succeeded ||
      phase == BackupRecoveryPhase.failed;

  @override
  String toString() => 'BackupRecoveryState($phase, error: $error)';
}

typedef BackupRecoveryPreparation = Future<void> Function();
typedef BackupRecoveryRestore = Future<void> Function();

/// Coordinates the destructive part of backup recovery.
///
/// The preparation callback is called before the restore callback.  This is
/// where the app closes its stores and SQLite connections; recovery never
/// flushes pending writes because those writes may be the corrupted state the
/// user is trying to discard.  The coordinator catches failures and exposes a
/// terminal [BackupRecoveryState] so a UI can remain on a recovery screen
/// instead of silently returning to stale in-memory state.
class BackupRecoveryCoordinator {
  BackupRecoveryCoordinator({
    required BackupRecoveryPreparation prepare,
    required BackupRecoveryRestore restore,
    void Function(BackupRecoveryState state)? onStateChanged,
  }) : _prepare = prepare,
       _restore = restore,
       _onStateChanged = onStateChanged;

  final BackupRecoveryPreparation _prepare;
  final BackupRecoveryRestore _restore;
  final void Function(BackupRecoveryState state)? _onStateChanged;

  BackupRecoveryState _state = const BackupRecoveryState.idle();
  Future<BackupRecoveryState>? _inFlight;

  BackupRecoveryState get state => _state;

  /// Runs at most one recovery attempt for this coordinator instance.
  ///
  /// Concurrent callers observe the same Future, which prevents a double
  /// restore when a widget rebuilds while the first attempt is still active.
  Future<BackupRecoveryState> recover() {
    final existing = _inFlight;
    if (existing != null) return existing;

    final operation = _recover();
    _inFlight = operation;
    return operation;
  }

  Future<BackupRecoveryState> _recover() async {
    _emit(const BackupRecoveryState(phase: BackupRecoveryPhase.preparing));
    try {
      await _prepare();
      _emit(const BackupRecoveryState(phase: BackupRecoveryPhase.restoring));
      await _restore();
      const completed = BackupRecoveryState(
        phase: BackupRecoveryPhase.succeeded,
      );
      _emit(completed);
      return completed;
    } catch (error, stackTrace) {
      final failed = BackupRecoveryState(
        phase: BackupRecoveryPhase.failed,
        error: error,
        stackTrace: stackTrace,
      );
      _emit(failed);
      return failed;
    }
  }

  void _emit(BackupRecoveryState state) {
    _state = state;
    _onStateChanged?.call(state);
  }
}

AutoBackupService createDefaultAutoBackupService() => createAutoBackupService();
