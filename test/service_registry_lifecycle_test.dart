import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:novel_writer/app/di/service_registry.dart';

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
}
