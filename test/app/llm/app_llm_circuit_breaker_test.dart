import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_circuit_breaker.dart';
import 'package:novel_writer/app/llm/app_llm_client_types.dart';

void main() {
  // =========================================================================
  // Circuit breaker 状态机测试
  // =========================================================================
  group('AppLlmCircuitBreaker', () {
    test('closed 状态正常放行', () async {
      final breaker = AppLlmCircuitBreaker();
      expect(breaker.state, AppLlmCircuitState.closed);

      final result = await breaker.guard(
        () async => const AppLlmChatResult.success(text: 'ok'),
      );

      expect(result.succeeded, isTrue);
      expect(result.text, 'ok');
      expect(breaker.state, AppLlmCircuitState.closed);
    });

    test('连续失败达到阈值转为 open', () async {
      final breaker = AppLlmCircuitBreaker(failureThreshold: 3);

      // 连续 3 次失败
      for (var i = 0; i < 3; i++) {
        await breaker.guard(
          () async => const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.server,
          ),
        );
      }

      expect(breaker.state, AppLlmCircuitState.open);
      expect(breaker.consecutiveFailures, 3);
    });

    test('open 状态直接拒绝', () async {
      final breaker = AppLlmCircuitBreaker(failureThreshold: 1);

      // 触发 open
      await breaker.guard(
        () async => const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.server,
        ),
      );
      expect(breaker.state, AppLlmCircuitState.open);

      // open 状态下的调用应被拒绝，action 不执行
      var actionCalled = false;
      final result = await breaker.guard(() async {
        actionCalled = true;
        return const AppLlmChatResult.success(text: 'never');
      });

      expect(actionCalled, isFalse);
      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.server);
      expect(result.detail, contains('Circuit breaker is open'));
    });

    test('recovery timeout 后转为 halfOpen', () async {
      final breaker = AppLlmCircuitBreaker(
        failureThreshold: 1,
        recoveryTimeout: const Duration(milliseconds: 50),
      );

      // 触发 open
      await breaker.guard(
        () async => const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.server,
        ),
      );
      expect(breaker.state, AppLlmCircuitState.open);

      // 等待 recovery timeout
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(breaker.state, AppLlmCircuitState.halfOpen);
    });

    test('halfOpen 探测成功转回 closed', () async {
      final breaker = AppLlmCircuitBreaker(
        failureThreshold: 1,
        recoveryTimeout: const Duration(milliseconds: 50),
      );

      // 触发 open
      await breaker.guard(
        () async => const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.server,
        ),
      );

      // 等待进入 halfOpen
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(breaker.state, AppLlmCircuitState.halfOpen);

      // 探测成功 → 回到 closed
      final result = await breaker.guard(
        () async => const AppLlmChatResult.success(text: 'recovered'),
      );
      expect(result.succeeded, isTrue);
      expect(breaker.state, AppLlmCircuitState.closed);
      expect(breaker.consecutiveFailures, 0);
    });

    test('halfOpen 探测失败转回 open', () async {
      final breaker = AppLlmCircuitBreaker(
        failureThreshold: 1,
        recoveryTimeout: const Duration(milliseconds: 50),
      );

      // 触发 open
      await breaker.guard(
        () async => const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.server,
        ),
      );

      // 等待进入 halfOpen
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(breaker.state, AppLlmCircuitState.halfOpen);

      // 探测失败 → 回到 open
      await breaker.guard(
        () async => const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.server,
        ),
      );
      expect(breaker.state, AppLlmCircuitState.open);
    });

    test('reset() 重置所有状态', () async {
      final breaker = AppLlmCircuitBreaker(failureThreshold: 1);

      // 触发 open
      await breaker.guard(
        () async => const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.server,
        ),
      );
      expect(breaker.state, AppLlmCircuitState.open);
      expect(breaker.consecutiveFailures, 1);

      // reset
      breaker.reset();
      expect(breaker.state, AppLlmCircuitState.closed);
      expect(breaker.consecutiveFailures, 0);
      expect(breaker.lastFailureTime, isNull);
    });

    test('closed 状态成功调用重置 consecutiveFailures', () async {
      final breaker = AppLlmCircuitBreaker(failureThreshold: 3);

      // 2 次失败
      await breaker.guard(
        () async => const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.server,
        ),
      );
      await breaker.guard(
        () async => const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.server,
        ),
      );
      expect(breaker.consecutiveFailures, 2);

      // 成功一次 → 重置
      await breaker.guard(
        () async => const AppLlmChatResult.success(text: 'ok'),
      );
      expect(breaker.consecutiveFailures, 0);
      expect(breaker.state, AppLlmCircuitState.closed);
    });

    test('recordStreamSuccess 在 halfOpen 状态下推进恢复', () async {
      final breaker = AppLlmCircuitBreaker(
        failureThreshold: 1,
        recoveryTimeout: const Duration(milliseconds: 50),
      );

      // 触发 open
      await breaker.guard(
        () async => const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.server,
        ),
      );

      // 等待进入 halfOpen
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(breaker.state, AppLlmCircuitState.halfOpen);

      // 模拟流式成功
      breaker.recordStreamSuccess();
      expect(breaker.state, AppLlmCircuitState.closed);
    });

    test('recordStreamFailure 在 closed 状态下累计失败', () async {
      final breaker = AppLlmCircuitBreaker(failureThreshold: 2);

      breaker.recordStreamFailure();
      expect(breaker.consecutiveFailures, 1);
      expect(breaker.state, AppLlmCircuitState.closed);

      breaker.recordStreamFailure();
      expect(breaker.consecutiveFailures, 2);
      expect(breaker.state, AppLlmCircuitState.open);
    });

    test('halfOpen 探测名额限制生效', () async {
      final breaker = AppLlmCircuitBreaker(
        failureThreshold: 1,
        recoveryTimeout: const Duration(milliseconds: 50),
        halfOpenMaxRequests: 1,
      );

      // 触发 open
      await breaker.guard(
        () async => const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.server,
        ),
      );

      // 等待进入 halfOpen
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(breaker.state, AppLlmCircuitState.halfOpen);

      // 第一次探测放行
      final result1 = await breaker.guard(
        () async => const AppLlmChatResult.success(text: 'probe'),
      );
      expect(result1.succeeded, isTrue);

      // halfOpenMaxRequests=1，成功后应该已经回到 closed
      expect(breaker.state, AppLlmCircuitState.closed);
    });
  });
}
