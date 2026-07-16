import 'dart:async';

import 'package:sqlite3/sqlite3.dart';

/// Serializes asynchronous writers that share one sqlite3 [Database] object.
///
/// SQLite calls are synchronous, but an async operation can yield while a
/// SAVEPOINT is open. Without a connection-scoped queue, another operation can
/// interleave its own SAVEPOINT and release or roll back the wrong transaction
/// frame.
class SqliteWriteCoordinator {
  SqliteWriteCoordinator._(this.database);

  static final Expando<SqliteWriteCoordinator> _byDatabase =
      Expando<SqliteWriteCoordinator>('sqlite-write-coordinator');

  /// Returns the one coordinator associated with [database]'s object identity.
  factory SqliteWriteCoordinator.forDatabase(Database database) =>
      _byDatabase[database] ??= SqliteWriteCoordinator._(database);

  final Database database;
  Future<void> _tail = Future<void>.value();

  /// Runs [operation] after every previously queued writer for this connection.
  ///
  /// Callers already holding this coordinator's [lease] must pass it
  /// explicitly. Omitting it from a nested acquisition fails fast instead of
  /// waiting on itself. The zone marker is diagnostic only; lease validation is
  /// always based on object identity and active lifetime.
  Future<T> synchronized<T>(
    FutureOr<T> Function(SqliteWriteLease lease) operation, {
    SqliteWriteLease? lease,
  }) {
    if (lease != null) {
      _validateLease(lease);
      return Future<T>.sync(() => operation(lease));
    }

    final inheritedLease = Zone.current[this];
    if (inheritedLease is SqliteWriteLease && inheritedLease.active) {
      return Future<T>.error(
        StateError(
          'Nested SQLite write acquisition on the same connection requires '
          'the active SqliteWriteLease',
        ),
      );
    }

    final result = Completer<T>();
    final released = Completer<void>();
    final predecessor = _tail;
    _tail = released.future;
    predecessor.whenComplete(() {
      final activeLease = SqliteWriteLease._(this, database);
      runZoned<Future<void>>(() async {
        try {
          result.complete(await operation(activeLease));
        } catch (error, stackTrace) {
          result.completeError(error, stackTrace);
        } finally {
          activeLease._active = false;
          released.complete();
        }
      }, zoneValues: <Object?, Object?>{this: activeLease});
    });
    return result.future;
  }

  void _validateLease(SqliteWriteLease lease) {
    if (!lease.active ||
        !identical(lease.coordinator, this) ||
        !identical(lease.database, database)) {
      throw StateError(
        'SQLite write lease is expired or belongs to another connection',
      );
    }
  }
}

/// A capability proving that the caller owns one connection's write queue.
///
/// Instances can only be created by [SqliteWriteCoordinator].
class SqliteWriteLease {
  SqliteWriteLease._(this.coordinator, this.database);

  final SqliteWriteCoordinator coordinator;
  final Database database;
  bool _active = true;

  bool get active => _active;
}
