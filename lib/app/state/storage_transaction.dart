import 'package:sqlite3/sqlite3.dart';

/// Executes [work] inside a SQLite transaction.
///
/// Begins a transaction, runs [work], and commits on success.  If [work]
/// throws, the transaction is rolled back and the error re-thrown.
void runInTransaction(Database database, void Function() work) {
  database.execute('BEGIN TRANSACTION');
  try {
    work();
    database.execute('COMMIT');
  } catch (_) {
    database.execute('ROLLBACK');
    rethrow;
  }
}
