import 'package:flutter/foundation.dart';

/// Minimal listener surface for legacy mutable stores during the Riverpod
/// migration.
///
/// Riverpod owns widget rebuilds through NotifierProvider. The stores keep this
/// small Listenable bridge so existing imperative APIs and scoped stores can be
/// migrated without depending on Flutter's framework notifier implementation.
abstract class AppStoreListenable implements Listenable {
  final List<VoidCallback> _listeners = <VoidCallback>[];
  bool _disposed = false;
  int _version = 0;

  int get version => _version;

  @override
  void addListener(VoidCallback listener) {
    if (_disposed) {
      throw FlutterError('Cannot add a listener after the store is disposed.');
    }
    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  @protected
  @visibleForTesting
  void notifyListeners() {
    if (_disposed) {
      return;
    }
    _version++;
    final listeners = List<VoidCallback>.of(_listeners);
    for (final listener in listeners) {
      if (_listeners.contains(listener)) {
        listener();
      }
    }
  }

  /// Waits for any asynchronous persistence queue owned by this store.
  ///
  /// Stores backed by synchronous persistence keep the default no-op.  The
  /// app lifecycle and [ServiceRegistry] use this hook before closing shared
  /// resources so debounced writes are not stranded by widget disposal.
  Future<void> flushPersistence() async {}

  /// Quiesces this store for disaster recovery without flushing pending edits.
  /// Debounced project stores override this hook to wait for in-flight backend
  /// calls before their owning database is replaced.
  Future<void> quiescePersistence() async {}

  @mustCallSuper
  void dispose() {
    _disposed = true;
    _listeners.clear();
  }
}
