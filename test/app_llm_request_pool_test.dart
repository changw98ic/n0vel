import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_request_pool.dart';
import 'package:novel_writer/app/llm/app_llm_execution_policy.dart';

void main() {
  group('AppLlmRequestPool', () {
    test(
      'holds new requests during cooldown without changing the concurrency cap',
      () async {
        final pool = AppLlmRequestPool(maxConcurrent: 2);
        var started = false;
        final stopwatch = Stopwatch()..start();

        pool.coolDownFor(const Duration(milliseconds: 50));
        final future = pool.run(() async {
          started = true;
          return stopwatch.elapsedMilliseconds;
        });

        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(started, isFalse);

        final elapsedMs = await future;
        expect(elapsedMs, greaterThanOrEqualTo(45));
        expect(pool.maxConcurrent, 2);
      },
    );

    test('executionPolicy.maxConcurrent is actually applied', () {
      final pool = AppLlmRequestPool(
        executionPolicy: const AppLlmRequestExecutionPolicy(maxConcurrent: 5),
      );

      expect(pool.maxConcurrent, 5);
      expect(pool.executionPolicy.maxConcurrent, 5);
    });

    test(
      'legacy maxConcurrent parameter is preserved when no executionPolicy',
      () {
        final pool = AppLlmRequestPool(maxConcurrent: 7);

        expect(pool.maxConcurrent, 7);
        expect(pool.executionPolicy.maxConcurrent, 7);
      },
    );

    test('executionPolicy overrides legacy maxConcurrent parameter', () {
      final pool = AppLlmRequestPool(
        maxConcurrent: 3, // Legacy argument
        executionPolicy: const AppLlmRequestExecutionPolicy(maxConcurrent: 10),
      );

      // executionPolicy.maxConcurrent should take precedence
      expect(pool.maxConcurrent, 10);
      expect(pool.executionPolicy.maxConcurrent, 10);
    });

    test('maxConcurrent setter updates observable execution policy', () {
      final pool = AppLlmRequestPool(maxConcurrent: 2);

      pool.maxConcurrent = 5;

      expect(pool.maxConcurrent, 5);
      expect(pool.executionPolicy.maxConcurrent, 5);
    });

    test(
      'applyExecutionPolicy updates concurrency and rate-limit settings',
      () {
        final pool = AppLlmRequestPool(maxConcurrent: 1);

        pool.applyExecutionPolicy(
          const AppLlmRequestExecutionPolicy(
            maxConcurrent: 4,
            minStartIntervalMs: 25,
          ),
        );

        expect(pool.maxConcurrent, 4);
        expect(pool.executionPolicy.maxConcurrent, 4);
        expect(pool.executionPolicy.minStartIntervalMs, 25);
      },
    );

    test(
      'rate-limit spacing delays starts without reducing concurrency cap',
      () async {
        final pool = AppLlmRequestPool(
          executionPolicy: const AppLlmRequestExecutionPolicy(
            maxConcurrent: 2,
            minStartIntervalMs: 50,
          ),
        );
        final firstStarted = Completer<void>();
        final releaseFirst = Completer<void>();
        final stopwatch = Stopwatch()..start();
        final startedAt = <int>[];
        var secondStarted = false;

        final first = pool.run(() async {
          startedAt.add(stopwatch.elapsedMilliseconds);
          firstStarted.complete();
          await releaseFirst.future;
          return 1;
        });

        await firstStarted.future;
        final second = pool.run(() async {
          secondStarted = true;
          startedAt.add(stopwatch.elapsedMilliseconds);
          return 2;
        });

        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(secondStarted, isFalse);
        expect(pool.maxConcurrent, 2);
        expect(pool.active, 1);

        expect(await second, 2);
        releaseFirst.complete();
        expect(await first, 1);

        expect(startedAt, hasLength(2));
        expect(startedAt[1] - startedAt[0], greaterThanOrEqualTo(45));
      },
    );

    test('applyExecutionPolicy reschedules pending rate-limit waits', () async {
      final pool = AppLlmRequestPool(
        executionPolicy: const AppLlmRequestExecutionPolicy(
          maxConcurrent: 2,
          minStartIntervalMs: 200,
        ),
      );
      final firstStarted = Completer<void>();
      final releaseFirst = Completer<void>();
      var secondStarted = false;

      final first = pool.run(() async {
        firstStarted.complete();
        await releaseFirst.future;
        return 1;
      });

      await firstStarted.future;
      final second = pool.run(() async {
        secondStarted = true;
        return 2;
      });

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(secondStarted, isFalse);

      pool.applyExecutionPolicy(
        const AppLlmRequestExecutionPolicy(
          maxConcurrent: 2,
          minStartIntervalMs: 50,
        ),
      );

      expect(await second.timeout(const Duration(milliseconds: 120)), 2);
      releaseFirst.complete();
      expect(await first, 1);
    });
  });
}
