import 'package:flutter/foundation.dart';

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
  final List<Type> _creationOrder = [];

  /// Register a factory that creates [T] on first [resolve].
  void registerFactory<T>(ServiceFactory<T> factory) {
    _registrations[T] = _ServiceRegistration(factory);
  }

  /// Register an already-created instance as [T].
  void registerSingleton<T>(T instance) {
    _instances[T] = instance;
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

  /// Dispose all [ChangeNotifier] instances in reverse creation order,
  /// then clear the registry.
  @mustCallSuper
  void disposeAll() {
    for (final type in _creationOrder.reversed) {
      final instance = _instances[type];
      if (instance is ChangeNotifier) {
        instance.dispose();
      }
    }
    _instances.clear();
    _registrations.clear();
    _creationOrder.clear();
    _resolving.clear();
  }
}
