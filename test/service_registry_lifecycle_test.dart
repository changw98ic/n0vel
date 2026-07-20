import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:novel_writer/app/di/service_registry.dart';
import 'package:novel_writer/app/state/app_store_listenable.dart';

class _FlushTrackingStore extends AppStoreListenable {
  _FlushTrackingStore(this.events);

  final List<String> events;

  @override
  Future<void> flushPersistence() async {
    events.add('flush');
  }

  @override
  void dispose() {
    events.add('dispose');
    super.dispose();
  }
}

class _EarlierLifecycleStore extends AppStoreListenable {
  _EarlierLifecycleStore(this.events);

  final List<String> events;

  @override
  Future<void> flushPersistence() async {
    events.add('flush:earlier');
  }

  @override
  void dispose() {
    events.add('dispose:earlier');
    super.dispose();
  }
}

class _FailingLifecycleStore extends AppStoreListenable {
  _FailingLifecycleStore(this.events);

  final List<String> events;

  @override
  Future<void> flushPersistence() async {
    events.add('flush:failing');
    throw StateError('flush-failure');
  }

  @override
  void dispose() {
    events.add('dispose:failing');
    super.dispose();
    throw StateError('dispose-failure');
  }
}

class _BorrowedLifecycleStore extends AppStoreListenable {
  _BorrowedLifecycleStore(this.events);

  final List<String> events;

  @override
  Future<void> flushPersistence() async {
    events.add('flush:borrowed');
  }

  @override
  void dispose() {
    events.add('dispose:borrowed');
    super.dispose();
  }
}

void main() {
  test('borrowed database remains usable after registry disposal', () {
    final database = sqlite3.sqlite3.openInMemory();
    addTearDown(database.dispose);
    final registry = ServiceRegistry()
      ..registerSingleton<sqlite3.Database>(database, owned: false);

    registry.disposeAll();

    expect(database.select('SELECT 1 AS value').single['value'], 1);
  });

  test('owned database is closed by registry disposal', () {
    final database = sqlite3.sqlite3.openInMemory();
    final registry = ServiceRegistry()
      ..registerSingleton<sqlite3.Database>(database);

    registry.disposeAll();

    expect(() => database.select('SELECT 1'), throwsStateError);
  });

  test('replacing an owned instance with a borrowed instance is rejected', () {
    final owned = sqlite3.sqlite3.openInMemory();
    final borrowed = sqlite3.sqlite3.openInMemory();
    addTearDown(borrowed.dispose);
    final registry = ServiceRegistry()
      ..registerSingleton<sqlite3.Database>(owned);

    expect(
      () =>
          registry.registerSingleton<sqlite3.Database>(borrowed, owned: false),
      throwsStateError,
    );
    registry.disposeAll();
    expect(() => owned.select('SELECT 1'), throwsStateError);
    expect(borrowed.select('SELECT 1').single.values.single, 1);
  });

  test('resolved factory instance cannot be replaced', () {
    final registry = ServiceRegistry()
      ..registerFactory<String>((_) => 'factory');
    expect(registry.resolve<String>(), 'factory');

    expect(
      () => registry.registerSingleton<String>('replacement'),
      throwsStateError,
    );
    registry.disposeAll();
    registry.disposeAll();
  });

  test('shutdown flushes stores before disposing them', () async {
    final events = <String>[];
    final registry = ServiceRegistry()
      ..registerSingleton<_FlushTrackingStore>(_FlushTrackingStore(events));

    await registry.shutdown();

    expect(events, ['flush', 'dispose']);
  });

  test(
    'shutdown disposes all owned services after flush failure and rethrows it',
    () async {
      final events = <String>[];
      final registry = ServiceRegistry()
        ..registerSingleton<_EarlierLifecycleStore>(
          _EarlierLifecycleStore(events),
        )
        ..registerSingleton<_FailingLifecycleStore>(
          _FailingLifecycleStore(events),
        );

      await expectLater(
        registry.shutdown(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'flush-failure',
          ),
        ),
      );

      expect(events, [
        'flush:failing',
        'flush:earlier',
        'dispose:failing',
        'dispose:earlier',
      ]);
    },
  );

  test('flushAll visits owned stores in reverse creation order', () async {
    final events = <String>[];
    final registry = ServiceRegistry()
      ..registerSingleton<_EarlierLifecycleStore>(
        _EarlierLifecycleStore(events),
      )
      ..registerSingleton<_BorrowedLifecycleStore>(
        _BorrowedLifecycleStore(events),
        owned: false,
      )
      ..registerSingleton<_FlushTrackingStore>(_FlushTrackingStore(events));

    await registry.flushAll();

    expect(events, ['flush', 'flush:earlier']);
    registry.disposeAll();
  });
}
