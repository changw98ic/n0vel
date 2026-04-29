import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/storage_lock.dart';

void main() {
  group('StorageLock', () {
    test('serializes operations on the same key', () async {
      final lock = StorageLock();
      final results = <int>[];

      final futures = <Future<void>>[
        for (var i = 0; i < 5; i++)
          lock.synchronized('same-key', () async {
            results.add(i);
            await Future<void>.delayed(const Duration(milliseconds: 10));
            results.add(i);
          }),
      ];

      await Future.wait(futures);

      // Each operation should append its index twice consecutively.
      for (var i = 0; i < 5; i++) {
        expect(results[i * 2], i);
        expect(results[i * 2 + 1], i);
      }
    });

    test('allows concurrent operations on different keys', () async {
      final lock = StorageLock();
      final activeKeys = <String>{};
      final maxConcurrentSameKey = <String, int>{};

      final futures = <Future<void>>[
        for (var i = 0; i < 3; i++)
          lock.synchronized('key-a', () async {
            activeKeys.add('key-a');
            maxConcurrentSameKey['key-a'] =
                (maxConcurrentSameKey['key-a'] ?? 0) + 1;
            await Future<void>.delayed(const Duration(milliseconds: 50));
            maxConcurrentSameKey['key-a'] =
                (maxConcurrentSameKey['key-a'] ?? 0) - 1;
          }),
        for (var i = 0; i < 3; i++)
          lock.synchronized('key-b', () async {
            activeKeys.add('key-b');
            maxConcurrentSameKey['key-b'] =
                (maxConcurrentSameKey['key-b'] ?? 0) + 1;
            await Future<void>.delayed(const Duration(milliseconds: 50));
            maxConcurrentSameKey['key-b'] =
                (maxConcurrentSameKey['key-b'] ?? 0) - 1;
          }),
      ];

      await Future.wait(futures);

      expect(activeKeys, contains('key-a'));
      expect(activeKeys, contains('key-b'));
    });

    test('returns the value produced by the action', () async {
      final lock = StorageLock();
      final result = await lock.synchronized('key', () async => 42);
      expect(result, 42);
    });

    test('propagates exceptions without deadlocking', () async {
      final lock = StorageLock();
      var reached = false;

      await expectLater(
        lock.synchronized('key', () async {
          throw StateError('expected failure');
        }),
        throwsA(isA<StateError>()),
      );

      await lock.synchronized('key', () async {
        reached = true;
      });

      expect(reached, isTrue);
    });

    test('is a singleton', () {
      expect(identical(StorageLock(), StorageLock()), isTrue);
    });
  });
}
