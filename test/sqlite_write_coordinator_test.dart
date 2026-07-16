import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/sqlite_write_coordinator.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Database firstDb;
  late Database secondDb;

  setUp(() {
    firstDb = sqlite3.openInMemory();
    secondDb = sqlite3.openInMemory();
  });

  tearDown(() {
    firstDb.dispose();
    secondDb.dispose();
  });

  test('same database writes run FIFO', () async {
    final coordinator = SqliteWriteCoordinator.forDatabase(firstDb);
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    final order = <String>[];

    final first = coordinator.synchronized<void>((_) async {
      order.add('first-start');
      firstStarted.complete();
      await releaseFirst.future;
      order.add('first-end');
    });
    await firstStarted.future;
    final second = coordinator.synchronized<void>((_) {
      order.add('second');
    });

    await Future<void>.delayed(Duration.zero);
    expect(order, <String>['first-start']);
    releaseFirst.complete();
    await Future.wait(<Future<void>>[first, second]);
    expect(order, <String>['first-start', 'first-end', 'second']);
  });

  test('different database writes can overlap', () async {
    final firstCoordinator = SqliteWriteCoordinator.forDatabase(firstDb);
    final secondCoordinator = SqliteWriteCoordinator.forDatabase(secondDb);
    final releaseFirst = Completer<void>();
    final secondStarted = Completer<void>();

    final first = firstCoordinator.synchronized<void>((_) async {
      await releaseFirst.future;
    });
    final second = secondCoordinator.synchronized<void>((_) {
      secondStarted.complete();
    });

    await secondStarted.future;
    releaseFirst.complete();
    await Future.wait(<Future<void>>[first, second]);
  });

  test('failed writer releases queue for the next writer', () async {
    final coordinator = SqliteWriteCoordinator.forDatabase(firstDb);
    final failure = coordinator.synchronized<void>((_) {
      throw StateError('expected');
    });
    final following = coordinator.synchronized<int>((_) => 42);

    await expectLater(failure, throwsStateError);
    await expectLater(following, completion(42));
  });

  test('expired and foreign leases are rejected', () async {
    final firstCoordinator = SqliteWriteCoordinator.forDatabase(firstDb);
    final secondCoordinator = SqliteWriteCoordinator.forDatabase(secondDb);
    late SqliteWriteLease expired;
    await firstCoordinator.synchronized<void>((lease) {
      expired = lease;
      expect(
        () => secondCoordinator.synchronized<void>((_) {}, lease: lease),
        throwsStateError,
      );
    });

    expect(expired.active, isFalse);
    expect(
      () => firstCoordinator.synchronized<void>((_) {}, lease: expired),
      throwsStateError,
    );
  });

  test('nested acquisition without the active lease fails fast', () async {
    final coordinator = SqliteWriteCoordinator.forDatabase(firstDb);
    await coordinator.synchronized<void>((_) async {
      await expectLater(
        coordinator.synchronized<void>((_) {}),
        throwsStateError,
      );
    });
  });

  test('explicit active lease executes without reacquiring', () async {
    final coordinator = SqliteWriteCoordinator.forDatabase(firstDb);
    await coordinator.synchronized<void>((lease) async {
      await coordinator.synchronized<void>((sameLease) {
        expect(identical(sameLease, lease), isTrue);
        firstDb.execute('CREATE TABLE nested_write (value INTEGER)');
      }, lease: lease);
    });

    expect(
      firstDb.select("SELECT 1 FROM sqlite_master WHERE name = 'nested_write'"),
      isNotEmpty,
    );
  });
}
