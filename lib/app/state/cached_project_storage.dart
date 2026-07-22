import 'dart:async';

import 'app_storage_clone.dart';
import 'project_storage.dart';

/// Error reported when a debounced project write cannot be persisted.
///
/// The original delegate error is kept in [cause] and [causeStackTrace],
/// while [revision] identifies the edit that was waiting for durability.  A
/// failed write remains queued in [CachedProjectStorage] so a later explicit
/// [flush] (or a newer edit) can retry it without losing the latest snapshot.
class CachedProjectStorageWriteException implements Exception {
  CachedProjectStorageWriteException({
    required this.projectId,
    required this.revision,
    required this.cause,
    required this.causeStackTrace,
  });

  final String projectId;
  final int revision;
  final Object cause;
  final StackTrace causeStackTrace;

  @override
  String toString() =>
      'CachedProjectStorageWriteException($projectId, revision $revision): '
      '$cause';
}

/// Caching decorator for [ProjectStorage] that reduces redundant disk I/O.
///
/// Reads are served from an in-memory clone after the first successful load.
/// Saves are debounced per project/scope and return a Future that completes
/// only after the requested revision is durably written by the delegate.  A
/// rapid sequence of saves can therefore share one final delegate write while
/// every caller still gets an honest completion signal.
class CachedProjectStorage
    implements
        ProjectStorage,
        ProjectStorageFlushable,
        ProjectStorageDiscardable,
        ProjectStorageQuiesceable {
  CachedProjectStorage(
    this._delegate, {
    Duration writeDelay = const Duration(milliseconds: 100),
    int maxRetries = 1,
    Duration retryDelay = Duration.zero,
  }) : _writeDelay = writeDelay,
       _maxRetries = maxRetries,
       _retryDelay = retryDelay {
    if (maxRetries < 0) {
      throw ArgumentError.value(maxRetries, 'maxRetries', 'must be >= 0');
    }
    if (writeDelay.isNegative) {
      throw ArgumentError.value(writeDelay, 'writeDelay', 'must be >= 0');
    }
    if (retryDelay.isNegative) {
      throw ArgumentError.value(retryDelay, 'retryDelay', 'must be >= 0');
    }
  }

  final ProjectStorage _delegate;
  final Duration _writeDelay;
  final int _maxRetries;
  final Duration _retryDelay;

  /// In-memory read cache keyed by projectId.
  /// Missing rows are intentionally not cached, so imports or external writes
  /// can become visible the next time a store restores the active project.
  final Map<String, Map<String, Object?>> _cache = {};

  final Map<String, _ProjectWriteState> _states = {};
  bool _disposed = false;

  /// Returns the most recent revision requested for [projectId].
  ///
  /// This is intentionally diagnostic; callers should use the Future returned
  /// by [save] when they need to await durability.
  int requestedRevisionFor(String projectId) =>
      _states[projectId]?.requestedRevision ?? 0;

  /// Returns the latest revision confirmed by the delegate for [projectId].
  int durableRevisionFor(String projectId) =>
      _states[projectId]?.durableRevision ?? 0;

  /// Whether [projectId] currently has a write waiting for persistence.
  bool hasPendingWriteFor(String projectId) {
    final state = _states[projectId];
    return state != null && (state.pending != null || state.inFlight != null);
  }

  @override
  Future<Map<String, Object?>?> load({required String projectId}) async {
    if (_cache.containsKey(projectId)) {
      final cached = _cache[projectId]!;
      return cloneStorageMap(cached);
    }
    final data = await _delegate.load(projectId: projectId);
    if (data == null) {
      return null;
    }
    _cache[projectId] = cloneStorageMap(data);
    return cloneStorageMap(data);
  }

  @override
  Future<void> save(Map<String, Object?> data, {required String projectId}) {
    if (_disposed) {
      return Future<void>.error(
        StateError('CachedProjectStorage has already been disposed'),
      );
    }

    final state = _states.putIfAbsent(projectId, _ProjectWriteState.new);
    if (state.clearing) {
      return Future<void>.error(
        StateError('Project $projectId is being cleared'),
      );
    }

    final cloned = cloneStorageMap(data);
    final revision = ++state.requestedRevision;
    state.pending = _PendingProjectWrite(
      projectId: projectId,
      revision: revision,
      data: cloned,
      generation: state.generation,
    );
    state.lastFailure = null;
    // A new revision starts a fresh bounded retry budget.  This also makes a
    // user edit an implicit retry after a previous failed flush.
    state.retryCount = 0;
    _cache[projectId] = cloneStorageMap(cloned);

    final waiter = _RevisionWaiter(revision);
    state.waiters.add(waiter);
    _scheduleFlush(state);
    return waiter.future;
  }

  @override
  Future<void> clear({String? projectId}) async {
    final states = projectId == null
        ? _states.values.toList(growable: false)
        : <_ProjectWriteState>[
            if (_states.containsKey(projectId)) _states[projectId]!,
          ];
    Object? firstError;
    StackTrace? firstStackTrace;
    try {
      await _clearStates(states);
    } catch (error, stackTrace) {
      firstError = error;
      firstStackTrace = stackTrace;
    }

    if (projectId == null) {
      _cache.clear();
    } else {
      _cache.remove(projectId);
    }
    try {
      await _delegate.clear(projectId: projectId);
    } catch (error, stackTrace) {
      firstError ??= error;
      firstStackTrace ??= stackTrace;
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }

  @override
  Future<void> clearProject(String projectId) async {
    final sceneScopePrefix = '$projectId::';
    final states = _states.entries
        .where(
          (entry) =>
              entry.key == projectId || entry.key.startsWith(sceneScopePrefix),
        )
        .map((entry) => entry.value)
        .toList(growable: false);
    Object? firstError;
    StackTrace? firstStackTrace;
    try {
      await _clearStates(states);
    } catch (error, stackTrace) {
      firstError = error;
      firstStackTrace = stackTrace;
    }

    _cache.removeWhere(
      (key, _) => key == projectId || key.startsWith(sceneScopePrefix),
    );
    try {
      await _delegate.clearProject(projectId);
    } catch (error, stackTrace) {
      firstError ??= error;
      firstStackTrace ??= stackTrace;
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }

  /// Forces all pending writes to disk immediately.
  ///
  /// A failed flush keeps its newest snapshot queued and throws a
  /// [CachedProjectStorageWriteException].  Calling [flush] again retries the
  /// retained snapshot with a fresh bounded retry budget.
  @override
  Future<void> flush() async {
    if (_disposed) return;

    for (final state in _states.values) {
      state.timer?.cancel();
      state.timer = null;
    }

    final states = _states.values
        .where((state) => state.pending != null || state.inFlight != null)
        .toList(growable: false);
    await Future.wait(states.map(_flushState));

    for (final state in states) {
      final failure = state.lastFailure;
      if (failure != null) {
        Error.throwWithStackTrace(failure.exception, failure.stackTrace);
      }
    }
  }

  /// Flushes any pending writes to disk, then releases the timer.
  Future<void> dispose() async {
    if (_disposed) return;
    try {
      await flush();
    } finally {
      discard();
    }
  }

  /// Discards pending snapshots and waits for an already-running delegate
  /// call to leave the backend before recovery replaces its database file.
  /// No newly queued snapshot is flushed.
  @override
  Future<void> quiesce() async {
    if (_disposed) return;
    final activeFlushes = <Future<void>>[];
    for (final state in _states.values) {
      final active = state.flushFuture;
      if (active != null) activeFlushes.add(active);
    }
    discard();
    if (activeFlushes.isEmpty) return;
    await Future.wait(
      activeFlushes.map((future) => future.catchError((Object _) {})),
    );
  }

  /// Stops deferred writes without flushing them.
  ///
  /// A delegate call that is already inside SQLite cannot be cancelled, but
  /// bumping the generation prevents it from scheduling or committing any
  /// follow-up batch after the owning registry has been closed.
  @override
  void discard() {
    if (_disposed) return;
    _disposed = true;
    for (final state in _states.values) {
      state.generation++;
      state.clearing = true;
      state.timer?.cancel();
      state.timer = null;
      state.pending = null;
      state.lastFailure = null;
      for (final waiter in state.waiters) {
        if (!waiter.completer.isCompleted) {
          waiter.completer.completeError(
            StateError('Pending project write was discarded'),
          );
        }
      }
      state.waiters.clear();
    }
  }

  void _scheduleFlush(_ProjectWriteState state) {
    if (state.timer != null || state.flushFuture != null || state.clearing) {
      return;
    }
    state.timer = Timer(_writeDelay, () {
      state.timer = null;
      unawaited(_flushState(state));
    });
  }

  Future<void> _flushState(_ProjectWriteState state) {
    final active = state.flushFuture;
    if (active != null) return active;

    state.retryCount = 0;
    state.lastFailure = null;
    final future = _drainState(state);
    state.flushFuture = future;
    unawaited(
      future.then((_) {
        if (identical(state.flushFuture, future)) {
          state.flushFuture = null;
        }
        // A save may race the final delegate completion.  The drain loop
        // normally observes it, but this guard covers an event-loop turn added
        // after the loop's last null check.
        if (state.pending != null &&
            state.lastFailure == null &&
            !state.clearing) {
          _scheduleFlush(state);
        }
      }),
    );
    return future;
  }

  Future<void> _drainState(_ProjectWriteState state) async {
    while (true) {
      final batch = state.pending;
      if (batch == null) return;

      state.pending = null;
      var attempts = 0;
      while (true) {
        if (batch.generation != state.generation) return;
        state.inFlight = batch;
        try {
          await _delegate.save(
            cloneStorageMap(batch.data),
            projectId: batch.projectId,
          );
          state.inFlight = null;
          if (batch.generation == state.generation) {
            if (batch.revision > state.durableRevision) {
              state.durableRevision = batch.revision;
            }
            _completeSuccessfulWaiters(state);
          }
          state.retryCount = 0;
          state.lastFailure = null;
          break;
        } catch (error, stackTrace) {
          state.inFlight = null;
          final generationStillActive = batch.generation == state.generation;
          attempts++;
          state.retryCount = attempts;
          if (!generationStillActive) return;

          if (attempts > _maxRetries) {
            // The error belongs to the batch that actually failed.  A newer
            // pending revision must not be failed merely because it was
            // queued while this older batch was in flight.
            final pending = state.pending;
            if (pending == null || pending.revision < batch.revision) {
              state.pending = batch;
            }
            final failure = _DrainFailure(
              exception: CachedProjectStorageWriteException(
                projectId: batch.projectId,
                revision: batch.revision,
                cause: error,
                causeStackTrace: stackTrace,
              ),
              stackTrace: stackTrace,
            );
            state.lastFailure = failure;
            _completeFailedWaitersThrough(state, failure, batch.revision);
            return;
          }

          if (_retryDelay > Duration.zero) {
            await Future<void>.delayed(_retryDelay);
          }
        }
      }
    }
  }

  Future<void> _clearStates(List<_ProjectWriteState> states) async {
    if (states.isEmpty) return;

    final activeFlushes = <Future<void>>[];
    for (final state in states) {
      state.clearing = true;
      state.generation++;
      state.timer?.cancel();
      state.timer = null;
      state.pending = null;
      state.lastFailure = null;
      for (final waiter in state.waiters) {
        if (!waiter.completer.isCompleted) {
          waiter.completer.completeError(
            StateError('Pending project write was cleared'),
          );
        }
      }
      state.waiters.clear();
      final active = state.flushFuture;
      if (active != null) activeFlushes.add(active);
    }

    try {
      if (activeFlushes.isNotEmpty) {
        await Future.wait(activeFlushes, eagerError: false);
      }
    } finally {
      for (final state in states) {
        state.clearing = false;
      }
    }
  }

  void _completeSuccessfulWaiters(_ProjectWriteState state) {
    final remaining = <_RevisionWaiter>[];
    for (final waiter in state.waiters) {
      if (waiter.revision <= state.durableRevision) {
        waiter.completer.complete();
      } else {
        remaining.add(waiter);
      }
    }
    state.waiters
      ..clear()
      ..addAll(remaining);
  }

  void _completeFailedWaitersThrough(
    _ProjectWriteState state,
    _DrainFailure failure,
    int failedRevision,
  ) {
    final remaining = <_RevisionWaiter>[];
    for (final waiter in state.waiters) {
      if (waiter.revision <= failedRevision) {
        waiter.completer.completeError(
          CachedProjectStorageWriteException(
            projectId: failure.exception.projectId,
            revision: failedRevision,
            cause: failure.exception.cause,
            causeStackTrace: failure.exception.causeStackTrace,
          ),
          failure.stackTrace,
        );
      } else {
        remaining.add(waiter);
      }
    }
    state.waiters
      ..clear()
      ..addAll(remaining);
  }
}

class _ProjectWriteState {
  int requestedRevision = 0;
  int durableRevision = 0;
  int generation = 0;
  int retryCount = 0;
  bool clearing = false;
  _PendingProjectWrite? pending;
  _PendingProjectWrite? inFlight;
  Timer? timer;
  Future<void>? flushFuture;
  _DrainFailure? lastFailure;
  final List<_RevisionWaiter> waiters = [];
}

class _PendingProjectWrite {
  _PendingProjectWrite({
    required this.projectId,
    required this.revision,
    required this.data,
    required this.generation,
  });

  final String projectId;
  final int revision;
  final Map<String, Object?> data;
  final int generation;
}

class _RevisionWaiter {
  _RevisionWaiter(this.revision);

  final int revision;
  final Completer<void> completer = Completer<void>();

  Future<void> get future => completer.future;
}

class _DrainFailure {
  _DrainFailure({required this.exception, required this.stackTrace});

  final CachedProjectStorageWriteException exception;
  final StackTrace stackTrace;
}
