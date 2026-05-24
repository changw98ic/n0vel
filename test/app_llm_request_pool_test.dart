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

    test('legacy maxConcurrent parameter is preserved when no executionPolicy',
        () {
      final pool = AppLlmRequestPool(maxConcurrent: 7);

      expect(pool.maxConcurrent, 7);
      expect(pool.executionPolicy.maxConcurrent, 7);
    });

    test('executionPolicy overrides legacy maxConcurrent parameter', () {
      final pool = AppLlmRequestPool(
        maxConcurrent: 3, // Legacy argument
        executionPolicy: const AppLlmRequestExecutionPolicy(maxConcurrent: 10),
      );

      // executionPolicy.maxConcurrent should take precedence
      expect(pool.maxConcurrent, 10);
      expect(pool.executionPolicy.maxConcurrent, 10);
    });
  });
}
