import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import '../events/app_event_bus.dart';
import '../logging/app_event_log.dart';
import '../state/app_store_listenable.dart';

typedef ServiceFactory<T> = T Function(ServiceRegistry registry);

class _ServiceRegistration {
  final Function(ServiceRegistry) factory;

  const _ServiceRegistration(this.factory);
}

/// Type-keyed dependency injection container with lazy resolution and
/// cycle detection. Services are singletons within a registry instance.
class ServiceRegistry {
  final Map<Type, _ServiceRegistration> _registrations = {};
  final Map<Type, dynamic> _instances = {};
  final Set<Type> _resolving = {};
  final Set<Type> _borrowedInstances = {};
  final List<Type> _creationOrder = [];

  /// Register a factory that creates [T] on first [resolve].
  void registerFactory<T>(ServiceFactory<T> factory) {
    _registrations[T] = _ServiceRegistration(factory);
  }

  /// Register an already-created instance as [T].
  ///
  /// Borrowed instances remain owned by their caller and are not disposed by
  /// [disposeAll]. Factory-created services are always registry-owned.
  void registerSingleton<T>(T instance, {bool owned = true}) {
    if (_instances.containsKey(T)) {
      throw StateError(
        'ServiceRegistry: an instance for $T has already been created.',
      );
    }
    _instances[T] = instance;
    if (owned) {
      _borrowedInstances.remove(T);
    } else {
      _borrowedInstances.add(T);
    }
    _creationOrder.add(T);
  }

  /// Resolve and return the singleton instance of [T].
  T resolve<T>() {
    if (_instances.containsKey(T)) {
      return _instances[T] as T;
    }

    final registration = _registrations[T];
    if (registration == null) {
      throw StateError(
        'ServiceRegistry: no registration for $T. '
        'Did you forget to call registerFactory<$T>()?',
      );
    }

    if (_resolving.contains(T)) {
      throw StateError(
        'ServiceRegistry: circular dependency detected while resolving $T.',
      );
    }

    _resolving.add(T);
    try {
      final instance = (registration.factory as ServiceFactory<T>)(this);
      _instances[T] = instance;
      _creationOrder.add(T);
      return instance;
    } finally {
      _resolving.remove(T);
    }
  }

  /// Whether [T] has been registered (factory or singleton).
  bool isRegistered<T>() =>
      _registrations.containsKey(T) || _instances.containsKey(T);

  /// Dispose all registry-owned services in reverse creation order, then clear
  /// the registry.
  @mustCallSuper
  void disposeAll() {
    Object? firstError;
    StackTrace? firstStackTrace;
    for (final type in _creationOrder.reversed) {
      if (_borrowedInstances.contains(type)) {
        continue;
      }
      final instance = _instances[type];
      try {
        if (instance is AppStoreListenable) {
          instance.dispose();
        } else if (instance is sqlite3.Database) {
          instance.dispose();
        } else if (instance is AppEventBus) {
          instance.dispose();
        } else if (instance is AppEventLog) {
          instance.dispose();
        }
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }
    _instances.clear();
    _registrations.clear();
    _creationOrder.clear();
    _resolving.clear();
    _borrowedInstances.clear();
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }

  /// Wait for asynchronous persistence queues owned by resolved stores.
  ///
  /// This is deliberately separate from [disposeAll]: Flutter's synchronous
  /// `State.dispose` cannot await work, while closing the SQLite connection
  /// before a debounced write completes would strand the newest snapshot.
  /// Call [shutdown] from an app lifecycle boundary when the registry owns
  /// the stores being closed.
  Future<void> flushAll() async {
    Object? firstError;
    StackTrace? firstStackTrace;
    for (final type in _creationOrder.reversed) {
      if (_borrowedInstances.contains(type)) {
        continue;
      }
      final instance = _instances[type];
      if (instance is AppStoreListenable) {
        try {
          await instance.flushPersistence();
        } catch (error, stackTrace) {
          // Give every store a chance to persist before the shared database
          // is closed, while preserving the first actionable failure for the
          // lifecycle caller.
          firstError ??= error;
          firstStackTrace ??= stackTrace;
        }
      } else if (instance is AppEventLog) {
        try {
          await instance.flushPersistence();
        } catch (error, stackTrace) {
          firstError ??= error;
          firstStackTrace ??= stackTrace;
        }
      }
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }

  /// Quiesces stores for disaster recovery without flushing their pending
  /// snapshots. Debounced backends discard those snapshots only after any
  /// already-running delegate call has left the database critical section.
  Future<void> quiesceAll() async {
    Object? firstError;
    StackTrace? firstStackTrace;
    for (final type in _creationOrder.reversed) {
      if (_borrowedInstances.contains(type)) continue;
      final instance = _instances[type];
      if (instance is AppStoreListenable) {
        try {
          await instance.quiescePersistence();
        } catch (error, stackTrace) {
          firstError ??= error;
          firstStackTrace ??= stackTrace;
        }
      } else if (instance is AppEventLog) {
        try {
          await instance.flushPersistence();
        } catch (error, stackTrace) {
          firstError ??= error;
          firstStackTrace ??= stackTrace;
        }
      }
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }

  /// Flush pending store writes, then release registry-owned resources.
  ///
  /// The resource cleanup runs even when a write fails.  The error is
  /// rethrown to the caller so a clean-shutdown marker is not written for a
  /// session whose latest edit was not durable.
  Future<void> shutdown() async {
    Object? firstError;
    StackTrace? firstStackTrace;
    try {
      await flushAll();
    } catch (error, stackTrace) {
      firstError = error;
      firstStackTrace = stackTrace;
    }
    try {
      disposeAll();
    } catch (error, stackTrace) {
      firstError ??= error;
      firstStackTrace ??= stackTrace;
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }
}
