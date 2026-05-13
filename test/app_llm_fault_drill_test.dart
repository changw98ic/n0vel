import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/llm/app_llm_client.dart';

import 'test_support/fake_faulty_client.dart';

// ---------------------------------------------------------------------------
// Circuit Breaker 故障演练
// ---------------------------------------------------------------------------

/// 构建一个使用 [FakeFaultyClient] 作为 delegate 的 gateway，
/// 配置极短的恢复超时以加速测试。
AppLlmClientGateway _drillGateway({
  required FakeFaultyClient fake,
  int maxRetries = 1,
  int failureThreshold = 5,
  Duration recoveryTimeout = const Duration(milliseconds: 50),
}) {
  final cb = AppLlmCircuitBreaker(
    failureThreshold: failureThreshold,
    recoveryTimeout: recoveryTimeout,
    halfOpenMaxRequests: 1,
  );
  return AppLlmClientGateway(
    delegate: fake,
    maxRetries: maxRetries,
    baseDelayMs: 1,
    circuitBreaker: cb,
  );
}

void main() {
  // ==========================================================================
  // 1. 超时场景
  // ==========================================================================
  group('超时场景', () {
    test('连续超时触发 circuit breaker open', () async {
      final fake = FakeFaultyClient(
        failCountBeforeSuccess: 10,
        failureKind: AppLlmFailureKind.timeout,
      );
      final gateway = _drillGateway(
        fake: fake,
        maxRetries: 1,
        failureThreshold: 3,
      );
      addTearDown(gateway.dispose);

      // 发送 3 轮请求，每轮 gateway 内重试 1 次 = 6 次底层调用
      for (var i = 0; i < 3; i++) {
        final result = await gateway.chat(testChatRequest());
        expect(result.succeeded, isFalse);
        expect(result.failureKind, AppLlmFailureKind.timeout);
      }

      // circuit breaker 应该已经 open
      expect(gateway.circuitBreaker.state, AppLlmCircuitState.open);
      expect(
        gateway.circuitBreaker.consecutiveFailures,
        greaterThanOrEqualTo(3),
      );
    });

    test('open 状态下请求被立即拒绝（不执行实际调用）', () async {
      final fake = FakeFaultyClient(
        failCountBeforeSuccess: 10,
        failureKind: AppLlmFailureKind.timeout,
      );
      final gateway = _drillGateway(
        fake: fake,
        maxRetries: 1,
        failureThreshold: 3,
      );
      addTearDown(gateway.dispose);

      // 触发 circuit open
      for (var i = 0; i < 3; i++) {
        await gateway.chat(testChatRequest());
      }

      final callsBeforeRejection = fake.callCount;

      // open 状态下的请求应立即被拒绝
      final result = await gateway.chat(testChatRequest());

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.server);
      expect(result.detail, contains('Circuit breaker is open'));

      // 底层 client 不应被再次调用
      expect(fake.callCount, callsBeforeRejection);
    });

    test('恢复超时后 halfOpen 探测成功则 circuit 回到 closed', () async {
      final fake = FakeFaultyClient(
        failCountBeforeSuccess: 3,
        failureKind: AppLlmFailureKind.timeout,
      );
      final gateway = _drillGateway(
        fake: fake,
        maxRetries: 1,
        failureThreshold: 3,
        recoveryTimeout: const Duration(milliseconds: 30),
      );
      addTearDown(gateway.dispose);

      // 触发 circuit open
      for (var i = 0; i < 3; i++) {
        await gateway.chat(testChatRequest());
      }
      expect(gateway.circuitBreaker.state, AppLlmCircuitState.open);

      // 等待恢复超时
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // circuit 应转为 halfOpen
      expect(gateway.circuitBreaker.state, AppLlmCircuitState.halfOpen);

      // 探测请求应成功（failCountBeforeSuccess=3，第 4 次开始成功）
      final result = await gateway.chat(testChatRequest());
      expect(result.succeeded, isTrue);

      // 成功后 circuit 应回到 closed
      expect(gateway.circuitBreaker.state, AppLlmCircuitState.closed);
    });
  });

  // ==========================================================================
  // 2. Circuit Breaker 短路场景
  // ==========================================================================
  group('Circuit Breaker 短路场景', () {
    test('连续 server error 达到阈值后 circuit open', () async {
      final fake = FakeFaultyClient(
        failCountBeforeSuccess: 10,
        failureKind: AppLlmFailureKind.server,
      );
      final gateway = _drillGateway(
        fake: fake,
        maxRetries: 1,
        failureThreshold: 5,
      );
      addTearDown(gateway.dispose);

      // 5 轮请求触发 threshold
      for (var i = 0; i < 5; i++) {
        await gateway.chat(testChatRequest());
      }

      expect(gateway.circuitBreaker.state, AppLlmCircuitState.open);
    });

    test('open 期间所有请求直接返回失败（底层无调用）', () async {
      final fake = FakeFaultyClient(
        failCountBeforeSuccess: 10,
        failureKind: AppLlmFailureKind.server,
      );
      final gateway = _drillGateway(
        fake: fake,
        maxRetries: 1,
        failureThreshold: 3,
      );
      addTearDown(gateway.dispose);

      // 触发 open
      for (var i = 0; i < 3; i++) {
        await gateway.chat(testChatRequest());
      }

      final callsBefore = fake.callCount;

      // 连续发送 5 个请求
      for (var i = 0; i < 5; i++) {
        final result = await gateway.chat(testChatRequest());
        expect(result.succeeded, isFalse);
        expect(result.failureKind, AppLlmFailureKind.server);
      }

      // 底层调用次数不应增加
      expect(fake.callCount, callsBefore);
    });

    test('恢复超时后 circuit 转为 halfOpen', () async {
      final fake = FakeFaultyClient(
        failCountBeforeSuccess: 10,
        failureKind: AppLlmFailureKind.server,
      );
      final gateway = _drillGateway(
        fake: fake,
        maxRetries: 1,
        failureThreshold: 3,
        recoveryTimeout: const Duration(milliseconds: 30),
      );
      addTearDown(gateway.dispose);

      // 触发 open
      for (var i = 0; i < 3; i++) {
        await gateway.chat(testChatRequest());
      }
      expect(gateway.circuitBreaker.state, AppLlmCircuitState.open);

      // 等待恢复超时
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(gateway.circuitBreaker.state, AppLlmCircuitState.halfOpen);
    });

    test('halfOpen 探测失败则回到 open', () async {
      // 所有调用都失败
      final fake = FakeFaultyClient(
        failCountBeforeSuccess: 999,
        failureKind: AppLlmFailureKind.server,
      );
      final gateway = _drillGateway(
        fake: fake,
        maxRetries: 1,
        failureThreshold: 3,
        recoveryTimeout: const Duration(milliseconds: 30),
      );
      addTearDown(gateway.dispose);

      // 触发 open
      for (var i = 0; i < 3; i++) {
        await gateway.chat(testChatRequest());
      }

      // 等待恢复
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(gateway.circuitBreaker.state, AppLlmCircuitState.halfOpen);

      // halfOpen 探测失败
      final result = await gateway.chat(testChatRequest());
      expect(result.succeeded, isFalse);

      // 应回到 open
      expect(gateway.circuitBreaker.state, AppLlmCircuitState.open);
    });
  });

  // ==========================================================================
  // 3. 异常 Payload 场景
  // ==========================================================================
  group('异常 Payload 场景', () {
    test('返回空字符串 → prose schema 校验失败', () {
      final schema = AppLlmOutputSchema.prose(minProseLength: 50);
      final result = schema.validate('');
      expect(result.isValid, isFalse);
      expect(result.violations, isNotEmpty);
      expect(result.violations.first, contains('too short'));
    });

    test('返回带 markdown fence 的散文 → prose schema 校验失败', () {
      final schema = AppLlmOutputSchema.prose();
      const text = '```markdown\n这是正文内容，但被包裹在 fence 里了\n```';
      final result = schema.validate(text);
      expect(result.isValid, isFalse);
      expect(
        result.violations.any((v) => v.contains('Forbidden pattern')),
        isTrue,
      );
    });

    test('返回带前言的散文 → prose schema 校验失败', () {
      final schema = AppLlmOutputSchema.prose();
      const text = '好的，这是你要的内容。他走在黄昏的街道上，秋风卷起落叶。';
      final result = schema.validate(text);
      expect(result.isValid, isFalse);
      expect(
        result.violations.any((v) => v.contains('Forbidden pattern')),
        isTrue,
      );
    });

    test('返回缺少必要字段的 review → review schema 校验失败', () {
      final schema = AppLlmOutputSchema.review();
      final result = schema.validate('这段文字写得不错，可以接受。');
      expect(result.isValid, isFalse);
      expect(result.violations.any((v) => v.contains('决定')), isTrue);
      expect(result.violations.any((v) => v.contains('原因')), isTrue);
    });

    test('schema 校验失败后自动重试，第二次返回正确格式', () async {
      // 第一次返回畸形数据，第二次返回正确数据
      final fake = FakeFaultyClient();
      fake.malformedResponse = '好的，以下是内容。';

      // 第一次 chat 返回畸形文本，validatedChat 应重试
      // 但 FakeFaultyClient 的 malformedResponse 是静态的，
      // 所以这里用一个可变的 responder 来控制。
      final mutableClient = _MutableResponseClient(
        responses: ['好的，以下是内容。', '决定：通过\n原因：文笔流畅，情节自然，符合整体叙事风格。'],
      );

      final validating = AppLlmSchemaValidatingClient(
        delegate: mutableClient,
        maxValidationRetries: 1,
      );

      final schema = AppLlmOutputSchema.review();
      final result = await validating.validatedChat(
        testChatRequest(),
        schema: schema,
      );

      expect(result.succeeded, isTrue);
      expect(result.text, contains('决定'));
      expect(result.text, contains('原因'));
      // 底层应该被调用了 2 次（第一次畸形 + 重试）
      expect(mutableClient.calls, 2);
    });

    test('schema 校验重试耗尽后返回最后的结果', () async {
      final mutableClient = _MutableResponseClient(
        responses: ['畸形回复一', '畸形回复二'],
      );

      final validating = AppLlmSchemaValidatingClient(
        delegate: mutableClient,
        maxValidationRetries: 1,
      );

      final schema = AppLlmOutputSchema.review();
      final result = await validating.validatedChat(
        testChatRequest(),
        schema: schema,
      );

      // 即使 schema 不通过，也应该返回最后的结果（成功状态）
      expect(result.succeeded, isTrue);
      expect(result.text, '畸形回复二');
      expect(mutableClient.calls, 2);
    });

    test('correct prose passes validation', () {
      final schema = AppLlmOutputSchema.prose(minProseLength: 10);
      const text = '他走在黄昏的街道上，秋风卷起落叶，远处传来教堂的钟声。';
      final result = schema.validate(text);
      expect(result.isValid, isTrue);
    });

    test('correct review passes validation', () {
      final schema = AppLlmOutputSchema.review();
      const text = '决定：通过\n原因：文笔流畅，情节连贯。';
      final result = schema.validate(text);
      expect(result.isValid, isTrue);
    });
  });

  // ==========================================================================
  // 4. 混合故障场景
  // ==========================================================================
  group('混合故障场景', () {
    test('先超时后 server error 混合故障累积触发 circuit open', () async {
      // 用一个可编程的 client 模拟混合故障序列
      final client = _ProgrammableClient([
        // 第 1 轮：timeout（gateway maxRetries=1 → 1 次底层调用）
        const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.timeout,
          detail: 'timeout 1',
        ),
        // 第 2 轮：timeout
        const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.timeout,
          detail: 'timeout 2',
        ),
        // 第 3 轮：server error
        const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.server,
          detail: 'server 500',
        ),
        // 第 4 轮：server error
        const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.server,
          detail: 'server 500 again',
        ),
        // 第 5 轮：server error → 达到 threshold
        const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.server,
          detail: 'server 500 third',
        ),
      ]);

      final cb = AppLlmCircuitBreaker(
        failureThreshold: 5,
        recoveryTimeout: const Duration(milliseconds: 50),
      );
      final gateway = AppLlmClientGateway(
        delegate: client,
        maxRetries: 1,
        baseDelayMs: 1,
        circuitBreaker: cb,
      );
      addTearDown(gateway.dispose);

      // 5 轮请求
      for (var i = 0; i < 5; i++) {
        await gateway.chat(testChatRequest());
      }

      // 混合故障累积，circuit 应 open
      expect(cb.state, AppLlmCircuitState.open);
      expect(cb.consecutiveFailures, greaterThanOrEqualTo(5));
    });

    test('circuit open 后 gateway chatStream 返回错误 stream', () async {
      final fake = FakeFaultyClient(
        failCountBeforeSuccess: 10,
        failureKind: AppLlmFailureKind.server,
      );
      final gateway = _drillGateway(
        fake: fake,
        maxRetries: 1,
        failureThreshold: 3,
      );
      addTearDown(gateway.dispose);

      // 触发 circuit open
      for (var i = 0; i < 3; i++) {
        await gateway.chat(testChatRequest());
      }
      expect(gateway.circuitBreaker.state, AppLlmCircuitState.open);

      // chatStream 也应被拒绝
      final stream = gateway.chatStream(testChatRequest());
      final error = await stream
          .drain<Object?>(null)
          .catchError((Object? e) => e);

      expect(error, isA<AppLlmStreamException>());
      final ex = error as AppLlmStreamException;
      expect(ex.failureKind, AppLlmFailureKind.server);
      expect(ex.detail, contains('Circuit breaker is open'));
    });

    test('网络恢复后 circuit breaker 自动恢复', () async {
      // 前 3 次失败，之后成功
      final fake = FakeFaultyClient(
        failCountBeforeSuccess: 3,
        failureKind: AppLlmFailureKind.server,
      );
      final gateway = _drillGateway(
        fake: fake,
        maxRetries: 1,
        failureThreshold: 3,
        recoveryTimeout: const Duration(milliseconds: 30),
      );
      addTearDown(gateway.dispose);

      // 触发 open
      for (var i = 0; i < 3; i++) {
        await gateway.chat(testChatRequest());
      }
      expect(gateway.circuitBreaker.state, AppLlmCircuitState.open);

      // 等待恢复超时 → halfOpen
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(gateway.circuitBreaker.state, AppLlmCircuitState.halfOpen);

      // 探测成功（第 4 次调用，failCountBeforeSuccess=3，所以成功）
      final result = await gateway.chat(testChatRequest());
      expect(result.succeeded, isTrue);

      // circuit 恢复 closed
      expect(gateway.circuitBreaker.state, AppLlmCircuitState.closed);

      // 后续请求正常工作
      final result2 = await gateway.chat(testChatRequest());
      expect(result2.succeeded, isTrue);
    });

    test('circuit breaker reset 手动恢复', () async {
      final fake = FakeFaultyClient(
        failCountBeforeSuccess: 10,
        failureKind: AppLlmFailureKind.server,
      );
      final gateway = _drillGateway(
        fake: fake,
        maxRetries: 1,
        failureThreshold: 3,
      );
      addTearDown(gateway.dispose);

      // 触发 open
      for (var i = 0; i < 3; i++) {
        await gateway.chat(testChatRequest());
      }
      expect(gateway.circuitBreaker.state, AppLlmCircuitState.open);

      // 手动 reset
      gateway.circuitBreaker.reset();
      expect(gateway.circuitBreaker.state, AppLlmCircuitState.closed);
      expect(gateway.circuitBreaker.consecutiveFailures, 0);

      // 重置后请求仍然会失败（底层还是 server error），
      // 但至少会执行实际调用而不是被 circuit 拦截
      final callsBefore = fake.callCount;
      await gateway.chat(testChatRequest());
      expect(fake.callCount, greaterThan(callsBefore));
    });
  });

  // ==========================================================================
  // 5. Schema 独立校验演练
  // ==========================================================================
  group('Schema 独立校验', () {
    test('generic schema 只要求非空', () {
      const schema = AppLlmOutputSchema.generic;
      expect(schema.validate('任何文本').isValid, isTrue);
      expect(schema.validate('').isValid, isFalse);
    });

    test('director schema 要求四个字段', () {
      final schema = AppLlmOutputSchema.director();
      // 缺少字段
      expect(schema.validate('目标：写一段打斗').isValid, isFalse);
      // 全部字段
      const full = '目标：推进冲突\n冲突：内心挣扎\n推进：角色觉醒\n约束：不超过500字';
      expect(schema.validate(full).isValid, isTrue);
    });

    test('maxLength 超限校验', () {
      const schema = AppLlmOutputSchema(minLength: 1, maxLength: 10);
      expect(schema.validate('short').isValid, isTrue);
      expect(schema.validate('this is way too long').isValid, isFalse);
    });

    test('requiredPatterns 必须全部匹配', () {
      final schema = AppLlmOutputSchema(
        requiredPatterns: [RegExp(r'AAA'), RegExp(r'BBB')],
      );
      expect(schema.validate('AAA only').isValid, isFalse);
      expect(schema.validate('AAA and BBB').isValid, isTrue);
    });

    test('forbiddenPatterns 任一匹配即失败', () {
      final schema = AppLlmOutputSchema(forbiddenPatterns: [RegExp(r'密码是\d+')]);
      expect(schema.validate('你好世界').isValid, isTrue);
      expect(schema.validate('我的密码是123456').isValid, isFalse);
    });
  });

  // ==========================================================================
  // 6. FakeFaultyClient 自身行为验证
  // ==========================================================================
  group('FakeFaultyClient 基础行为', () {
    test('默认配置总是返回成功', () async {
      final fake = FakeFaultyClient();
      final result = await fake.chat(testChatRequest());
      expect(result.succeeded, isTrue);
      expect(result.text, fake.successText);
    });

    test('failCountBeforeSuccess 控制失败次数', () async {
      final fake = FakeFaultyClient(
        failCountBeforeSuccess: 2,
        failureKind: AppLlmFailureKind.timeout,
      );

      // 前 2 次失败
      final r1 = await fake.chat(testChatRequest());
      expect(r1.succeeded, isFalse);
      expect(fake.callCount, 1);

      final r2 = await fake.chat(testChatRequest());
      expect(r2.succeeded, isFalse);
      expect(fake.callCount, 2);

      // 第 3 次成功
      final r3 = await fake.chat(testChatRequest());
      expect(r3.succeeded, isTrue);
      expect(fake.callCount, 3);
    });

    test('simulateDelay 增加调用延迟', () async {
      final fake = FakeFaultyClient(
        simulateDelay: const Duration(milliseconds: 50),
      );

      final sw = Stopwatch()..start();
      await fake.chat(testChatRequest());
      sw.stop();

      expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(40));
    });

    test('malformedResponse 返回成功但内容异常', () async {
      final fake = FakeFaultyClient(malformedResponse: '');
      final result = await fake.chat(testChatRequest());
      expect(result.succeeded, isTrue);
      expect(result.text, isEmpty);
    });

    test('chatStream 成功时产出 chunks', () async {
      final fake = FakeFaultyClient(
        streamChunks: ['chunk1', 'chunk2', 'chunk3'],
      );
      final chunks = await fake.chatStream(testChatRequest()).toList();
      expect(chunks, ['chunk1', 'chunk2', 'chunk3']);
    });

    test('chatStream 失败时产出错误', () async {
      final fake = FakeFaultyClient(
        failCountBeforeSuccess: 1,
        failureKind: AppLlmFailureKind.server,
      );

      final stream = fake.chatStream(testChatRequest());
      final error = await stream
          .drain<Object?>(null)
          .catchError((Object? e) => e);

      expect(error, isA<AppLlmStreamException>());
    });

    test('callLog 记录所有请求', () async {
      final fake = FakeFaultyClient();
      final req1 = testChatRequest();
      final req2 = testChatRequest(
        messages: const [AppLlmChatMessage(role: 'user', content: '第二条')],
      );

      await fake.chat(req1);
      await fake.chat(req2);

      expect(fake.callLog.length, 2);
      expect(fake.callLog[0], same(req1));
      expect(fake.callLog[1], same(req2));
    });

    test('reset 清除计数和日志', () async {
      final fake = FakeFaultyClient(
        failCountBeforeSuccess: 1,
        failureKind: AppLlmFailureKind.timeout,
      );

      await fake.chat(testChatRequest());
      expect(fake.callCount, 1);
      expect(fake.callLog, isNotEmpty);

      fake.reset();
      expect(fake.callCount, 0);
      expect(fake.callLog, isEmpty);

      // reset 后重新计数
      final r = await fake.chat(testChatRequest());
      expect(r.succeeded, isFalse); // 又从 1 开始
    });
  });
}

// ---------------------------------------------------------------------------
// 辅助类：可编程的顺序返回 client
// ---------------------------------------------------------------------------

class _ProgrammableClient implements AppLlmClient {
  _ProgrammableClient(this._results);

  final List<AppLlmChatResult> _results;
  int _index = 0;

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    return _results[_index++];
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) async* {
    final result = _results[_index++];
    if (result.succeeded) {
      yield result.text ?? '';
    } else {
      yield* Stream.error(
        AppLlmStreamException(
          failureKind: result.failureKind!,
          detail: result.detail,
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// 辅助类：可变响应 client（第一次调用返回第一个，第二次返回第二个，...）
// ---------------------------------------------------------------------------

class _MutableResponseClient implements AppLlmClient {
  _MutableResponseClient({required this.responses});

  final List<String> responses;
  int calls = 0;

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    final text = responses[calls];
    calls++;
    return AppLlmChatResult.success(text: text);
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) async* {
    final text = responses[calls];
    calls++;
    yield text;
  }
}
