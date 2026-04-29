import 'dart:async';

import 'app_domain_events.dart';

/// Lightweight typed event bus for decoupling module communication.
///
/// Usage:
/// ```dart
/// final bus = AppEventBus();
///
/// // Subscribe to specific event types
/// final sub = bus.on<ProjectScopeChangedEvent>().listen((event) {
///   print('project changed: ${event.projectId}');
/// });
///
/// // Publish events
/// bus.publish(const ProjectScopeChangedEvent(
///   projectId: 'p1',
///   sceneScopeId: 'p1::s1',
/// ));
///
/// // Clean up
/// sub.cancel();
/// bus.dispose();
/// ```
///
/// The bus uses Dart Streams internally — no external dependencies.
/// Each event type gets its own [StreamController] to avoid type casting
/// overhead on the hot path.
class AppEventBus {
  AppEventBus() {
    current = this;
  }

  static AppEventBus? current;

  final Map<Type, StreamController<AppDomainEvent>> _controllers = {};
  bool _disposed = false;

  /// Returns a typed broadcast stream for [E].
  ///
  /// Lazily creates a sync broadcast [StreamController] per event type.
  /// Safe to call multiple times — always returns the same controller's stream.
  Stream<E> on<E extends AppDomainEvent>() {
    _checkDisposed();
    return _controllerFor(E).stream.cast<E>();
  }

  /// Publishes an event to all subscribers of its runtime type.
  ///
  /// Listeners receive the event synchronously (sync broadcast controller).
  void publish(AppDomainEvent event) {
    _checkDisposed();
    _controllerFor(event.runtimeType).add(event);
  }

  /// Convenience: subscribe with a callback, returns a [StreamSubscription].
  ///
  /// Useful in [ChangeNotifier] subclasses that want to react to events
  /// without managing [Stream] directly.
  StreamSubscription<E> listen<E extends AppDomainEvent>(
    void Function(E) onEvent,
  ) {
    return on<E>().listen(onEvent);
  }

  /// Releases all stream controllers.
  ///
  /// After disposal, [publish] and [on] will throw [StateError].
  void dispose() {
    _disposed = true;
    if (identical(current, this)) {
      current = null;
    }
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
  }

  StreamController<AppDomainEvent> _controllerFor(Type type) {
    return _controllers.putIfAbsent(
      type,
      () => StreamController<AppDomainEvent>.broadcast(sync: true),
    );
  }

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('AppEventBus has been disposed.');
    }
  }
}
