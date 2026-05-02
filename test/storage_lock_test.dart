import 'dart:math';

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

  group('regression: same-key serialization', () {
    test('serializes 3+ operations with interleaved scheduling', () async {
      final lock = StorageLock();
      var concurrent = 0;
      var maxConcurrent = 0;
      final order = <int>[];

      Future<void> op(int id) {
        return lock.synchronized('key', () async {
          concurrent++;
          maxConcurrent = max(maxConcurrent, concurrent);
          order.add(id);
          await Future<void>.delayed(const Duration(milliseconds: 5));
          concurrent--;
        });
      }

      // Queue Op1, Op2, Op3 synchronously
      final f1 = op(1);
      final f2 = op(2);
      final f3 = op(3);

      // After Op1 completes, immediately queue Op4 and Op5.
      // With the buggy implementation, _pending is null at this point
      // because Op1's finally cleared it, allowing Op4 to bypass the queue.
      await f1;
      final f4 = op(4);
      final f5 = op(5);

      await Future.wait([f2, f3, f4, f5]);

      expect(
        maxConcurrent,
        1,
        reason: 'Operations must be strictly serialized',
      );
      expect(order, [
        1,
        2,
        3,
        4,
        5,
      ], reason: 'Operations must execute in FIFO order');
    });

    test('serializes 10+ operations arriving in overlapping waves', () async {
      final lock = StorageLock();
      var concurrent = 0;
      var maxConcurrent = 0;
      final order = <int>[];

      Future<void> op(int id) {
        return lock.synchronized('key', () async {
          concurrent++;
          maxConcurrent = max(maxConcurrent, concurrent);
          order.add(id);
          await Future<void>.delayed(const Duration(milliseconds: 2));
          concurrent--;
        });
      }

      // Wave 1: 5 operations queued synchronously
      final wave1 = List<Future<void>>.generate(5, (i) => op(i));

      // After the first operation completes, queue wave 2
      await wave1.first;
      final wave2 = List<Future<void>>.generate(5, (i) => op(i + 5));

      await Future.wait([...wave1, ...wave2]);

      expect(
        maxConcurrent,
        1,
        reason: 'All 10 operations must be strictly serialized',
      );
      expect(order.length, 10);
      for (var i = 0; i < 10; i++) {
        expect(
          order[i],
          i,
          reason: 'Operation $i should execute at position $i',
        );
      }
    });
  });

  group('regression: cross-key independence', () {
    test('allows different keys to progress concurrently', () async {
      final lock = StorageLock();
      var concurrentA = 0;
      var maxConcurrentA = 0;
      var concurrentB = 0;
      var maxConcurrentB = 0;
      var crossKeyOverlap = false;

      Future<void> opA() => lock.synchronized('key-a', () async {
        concurrentA++;
        maxConcurrentA = max(maxConcurrentA, concurrentA);
        if (concurrentB > 0) crossKeyOverlap = true;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        concurrentA--;
      });

      Future<void> opB() => lock.synchronized('key-b', () async {
        concurrentB++;
        maxConcurrentB = max(maxConcurrentB, concurrentB);
        if (concurrentA > 0) crossKeyOverlap = true;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        concurrentB--;
      });

      await Future.wait([opA(), opA(), opA(), opB(), opB(), opB()]);

      expect(maxConcurrentA, 1, reason: 'key-a must serialize internally');
      expect(maxConcurrentB, 1, reason: 'key-b must serialize internally');
      expect(
        crossKeyOverlap,
        isTrue,
        reason: 'different keys must run concurrently',
      );
    });
  });
}
