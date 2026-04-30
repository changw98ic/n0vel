import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_request_pool.dart';

void main() {
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
}
