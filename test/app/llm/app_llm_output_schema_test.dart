import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_client_contract.dart';
import 'package:novel_writer/app/llm/app_llm_client_types.dart';
import 'package:novel_writer/app/llm/app_llm_output_schema.dart';

void main() {
  // =========================================================================
  // prose schema
  // =========================================================================
  group('prose schema', () {
    late AppLlmOutputSchema schema;

    setUp(() {
      schema = AppLlmOutputSchema.prose();
    });

    test('正常散文通过（>50 chars，无 forbidden pattern）', () {
      const text = '这是一段正常的散文输出，包含足够的字符数量来满足最小长度要求。'
          '它没有任何 markdown fence 或者 preamble 开头。';
      final result = schema.validate(text);
      expect(result.isValid, isTrue);
      expect(result.violations, isEmpty);
    });

    test('空字符串失败', () {
      final result = schema.validate('');
      expect(result.isValid, isFalse);
      expect(result.violations, isNotEmpty);
    });

    test('恰好 50 chars 通过（边界）', () {
      // 构造恰好 50 个字符的文本
      final text = '一' * 50;
      expect(text.length, 50);
      final result = schema.validate(text);
      expect(result.isValid, isTrue);
    });

    test('49 chars 失败（边界）', () {
      final text = '一' * 49;
      expect(text.length, 49);
      final result = schema.validate(text);
      expect(result.isValid, isFalse);
      expect(
        result.violations,
        contains(contains('too short')),
      );
    });

    test('包含 ``` markdown fence 失败', () {
      final text = '${'一' * 50}\n```\nsome code\n```';
      final result = schema.validate(text);
      expect(result.isValid, isFalse);
      expect(
        result.violations,
        anyElement(contains('Forbidden pattern')),
      );
    });

    test('包含 "好的" preamble 失败', () {
      const text = '好的，这是你要的散文内容，加上足够的后续文字来超过五十个字符的限制要求。';
      final result = schema.validate(text);
      expect(result.isValid, isFalse);
    });

    test('包含 "以下是" preamble 失败', () {
      const text = '以下是生成的散文内容，这段文字足够长来满足最小长度限制。';
      final result = schema.validate(text);
      expect(result.isValid, isFalse);
    });

    test('包含 "Here is" preamble 失败', () {
      const text =
          'Here is the prose output that is long enough to pass the minimum length requirement.';
      final result = schema.validate(text);
      expect(result.isValid, isFalse);
    });

    test('包含 "Sure," preamble 失败', () {
      const text =
          'Sure, here is the prose output that is long enough to pass the minimum length requirement.';
      final result = schema.validate(text);
      expect(result.isValid, isFalse);
    });

    test('自定义 minProseLength 生效', () {
      final customSchema = AppLlmOutputSchema.prose(minProseLength: 100);
      final text = '一' * 80;
      final result = customSchema.validate(text);
      expect(result.isValid, isFalse);
      expect(result.violations.first, contains('100'));
    });
  });

  // =========================================================================
  // review schema
  // =========================================================================
  group('review schema', () {
    late AppLlmOutputSchema schema;

    setUp(() {
      schema = AppLlmOutputSchema.review();
    });

    test('正常 review 输出通过（包含 决定：和 原因：）', () {
      const text = '经过审查，决定：通过。原因：文字流畅，符合情节发展需要。';
      final result = schema.validate(text);
      expect(result.isValid, isTrue);
      expect(result.violations, isEmpty);
    });

    test('缺少 决定：失败', () {
      const text = '经过审查，原因：文字流畅，符合情节发展需要，这是一个很好的段落。';
      final result = schema.validate(text);
      expect(result.isValid, isFalse);
      expect(
        result.violations,
        anyElement(contains('决定')),
      );
    });

    test('缺少 原因：失败', () {
      const text = '经过审查，决定：通过。这段文字非常好。';
      final result = schema.validate(text);
      expect(result.isValid, isFalse);
      expect(
        result.violations,
        anyElement(contains('原因')),
      );
    });

    test('使用半角冒号通过（决定: 原因:）', () {
      const text = '决定: 通过。原因: 文字流畅，符合情节发展需要。';
      final result = schema.validate(text);
      expect(result.isValid, isTrue);
    });

    test('太短失败（<10 chars）', () {
      const text = '决定：好';
      expect(text.length, lessThan(10));
      final result = schema.validate(text);
      expect(result.isValid, isFalse);
      expect(
        result.violations,
        anyElement(contains('too short')),
      );
    });
  });

  // =========================================================================
  // director schema
  // =========================================================================
  group('director schema', () {
    late AppLlmOutputSchema schema;

    setUp(() {
      schema = AppLlmOutputSchema.director();
    });

    test('正常 director 输出通过（包含全部 4 个字段）', () {
      const text = '目标：推动情节发展。冲突：角色间的矛盾。推进：揭示真相。约束：保持节奏。';
      final result = schema.validate(text);
      expect(result.isValid, isTrue);
      expect(result.violations, isEmpty);
    });

    test('缺少 目标：失败', () {
      const text = '冲突：角色矛盾。推进：揭示真相。约束：保持节奏。还需要补充更多内容。';
      final result = schema.validate(text);
      expect(result.isValid, isFalse);
      expect(
        result.violations,
        anyElement(contains('目标')),
      );
    });

    test('缺少 冲突：失败', () {
      const text = '目标：推动情节发展。推进：揭示真相。约束：保持节奏。需要更多内容。';
      final result = schema.validate(text);
      expect(result.isValid, isFalse);
      expect(
        result.violations,
        anyElement(contains('冲突')),
      );
    });

    test('缺少 推进：失败', () {
      const text = '目标：推动情节发展。冲突：角色矛盾。约束：保持节奏。需要更多内容。';
      final result = schema.validate(text);
      expect(result.isValid, isFalse);
      expect(
        result.violations,
        anyElement(contains('推进')),
      );
    });

    test('缺少 约束：失败', () {
      const text = '目标：推动情节发展。冲突：角色矛盾。推进：揭示真相。需要更多内容。';
      final result = schema.validate(text);
      expect(result.isValid, isFalse);
      expect(
        result.violations,
        anyElement(contains('约束')),
      );
    });

    test('太短失败（<20 chars）', () {
      const text = '目标：短';
      expect(text.length, lessThan(20));
      final result = schema.validate(text);
      expect(result.isValid, isFalse);
      expect(
        result.violations,
        anyElement(contains('too short')),
      );
    });

    test('半角冒号也通过', () {
      const text = '目标: push. 冲突: conflict. 推进: advance. 约束: constraint.';
      final result = schema.validate(text);
      expect(result.isValid, isTrue);
    });
  });

  // =========================================================================
  // generic schema
  // =========================================================================
  group('generic schema', () {
    test('非空文本通过', () {
      const text = 'some output';
      final result = AppLlmOutputSchema.generic.validate(text);
      expect(result.isValid, isTrue);
      expect(result.violations, isEmpty);
    });

    test('空字符串失败', () {
      final result = AppLlmOutputSchema.generic.validate('');
      expect(result.isValid, isFalse);
      expect(result.violations, isNotEmpty);
    });

    test('单字符通过（边界）', () {
      final result = AppLlmOutputSchema.generic.validate('x');
      expect(result.isValid, isTrue);
    });
  });

  // =========================================================================
  // 自定义 schema
  // =========================================================================
  group('自定义 schema', () {
    test('maxLength 限制生效', () {
      const schema = AppLlmOutputSchema(
        minLength: 1,
        maxLength: 10,
      );
      final result = schema.validate('这是一个超过十个字符的文本');
      expect(result.isValid, isFalse);
      expect(
        result.violations,
        anyElement(contains('too long')),
      );
    });

    test('恰好 maxLength 边界通过', () {
      const schema = AppLlmOutputSchema(
        minLength: 1,
        maxLength: 5,
      );
      final result = schema.validate('12345');
      expect(result.isValid, isTrue);
    });

    test('maxLength + 1 失败', () {
      const schema = AppLlmOutputSchema(
        minLength: 1,
        maxLength: 5,
      );
      final result = schema.validate('123456');
      expect(result.isValid, isFalse);
    });

    test('多个 requiredPatterns 全部缺失', () {
      final schema = AppLlmOutputSchema(
        minLength: 1,
        requiredPatterns: [
          RegExp(r'alpha'),
          RegExp(r'beta'),
          RegExp(r'gamma'),
        ],
      );
      final result = schema.validate('no keywords here at all');
      expect(result.isValid, isFalse);
      expect(result.violations.length, 3);
    });

    test('多个 requiredPatterns 部分缺失', () {
      final schema = AppLlmOutputSchema(
        minLength: 1,
        requiredPatterns: [
          RegExp(r'alpha'),
          RegExp(r'beta'),
          RegExp(r'gamma'),
        ],
      );
      final result = schema.validate('alpha and beta present');
      expect(result.isValid, isFalse);
      expect(result.violations.length, 1);
      expect(result.violations.first, contains('gamma'));
    });

    test('多个 forbiddenPatterns 同时命中', () {
      final schema = AppLlmOutputSchema(
        forbiddenPatterns: [
          RegExp(r'BAD'),
          RegExp(r'WORSE'),
        ],
      );
      final result = schema.validate('This is BAD and WORSE');
      expect(result.isValid, isFalse);
      // 至少报告一个 forbidden pattern violation
      expect(
        result.violations.where((v) => v.contains('Forbidden pattern')).length,
        greaterThanOrEqualTo(1),
      );
    });

    test('violations 列表内容准确描述每种违规', () {
      final schema = AppLlmOutputSchema(
        minLength: 100,
        requiredPatterns: [RegExp(r'MISSING')],
      );
      final result = schema.validate('short');
      expect(result.isValid, isFalse);
      expect(result.violations.length, 2);
      expect(
        result.violations,
        contains(contains('too short')),
      );
      expect(
        result.violations,
        contains(contains('Required pattern not found')),
      );
    });
  });

  // =========================================================================
  // AppLlmSchemaValidatingClient
  // =========================================================================
  group('AppLlmSchemaValidatingClient', () {
    late _FakeLlmClient fakeClient;

    setUp(() {
      fakeClient = _FakeLlmClient();
    });

    test('schema null 时直接透传', () async {
      fakeClient.nextResult = const AppLlmChatResult.success(
        text: 'raw output',
      );

      final client = AppLlmSchemaValidatingClient(delegate: fakeClient);
      final request = _makeRequest();
      final result = await client.validatedChat(request, schema: null);

      expect(result.succeeded, isTrue);
      expect(result.text, 'raw output');
      expect(fakeClient.callCount, 1);
    });

    test('校验通过直接返回', () async {
      fakeClient.nextResult = AppLlmChatResult.success(
        text: '一' * 60,
      );

      final client = AppLlmSchemaValidatingClient(delegate: fakeClient);
      final request = _makeRequest();
      final schema = AppLlmOutputSchema.prose();
      final result = await client.validatedChat(request, schema: schema);

      expect(result.succeeded, isTrue);
      expect(result.text, '一' * 60);
      expect(fakeClient.callCount, 1);
    });

    test('校验失败自动重试（验证 retry 时 messages 包含 violation feedback）', () async {
      // 第一次返回不合规的输出，第二次返回合规的
      fakeClient.results = [
        const AppLlmChatResult.success(text: 'short'),
        AppLlmChatResult.success(text: '一' * 60),
      ];

      final client = AppLlmSchemaValidatingClient(
        delegate: fakeClient,
        maxValidationRetries: 1,
      );
      final request = _makeRequest();
      final schema = AppLlmOutputSchema.prose();
      final result = await client.validatedChat(request, schema: schema);

      expect(result.succeeded, isTrue);
      expect(result.text, '一' * 60);
      // 第一次调用 + 一次重试 = 2
      expect(fakeClient.callCount, 2);
      // 第二次调用的 messages 应包含 violation feedback
      final retryMessages = fakeClient.capturedMessages[1];
      expect(
        retryMessages.any((m) => m.content.contains('未满足格式要求')),
        isTrue,
      );
    });

    test('重试次数耗尽返回最后结果', () async {
      // 连续返回不合规的输出
      fakeClient.results = [
        const AppLlmChatResult.success(text: 'short1'),
        const AppLlmChatResult.success(text: 'short2'),
      ];

      final client = AppLlmSchemaValidatingClient(
        delegate: fakeClient,
        maxValidationRetries: 1,
      );
      final request = _makeRequest();
      final schema = AppLlmOutputSchema.prose();
      final result = await client.validatedChat(request, schema: schema);

      // 返回最后一次的结果
      expect(result.text, 'short2');
      expect(fakeClient.callCount, 2);
    });

    test('delegate 返回 transport failure 时不重试', () async {
      fakeClient.nextResult = const AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.network,
        detail: 'connection refused',
      );

      final client = AppLlmSchemaValidatingClient(
        delegate: fakeClient,
        maxValidationRetries: 3,
      );
      final request = _makeRequest();
      final schema = AppLlmOutputSchema.prose();
      final result = await client.validatedChat(request, schema: schema);

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.network);
      expect(fakeClient.callCount, 1);
    });

    test('chat() 方法直接透传不做校验', () async {
      fakeClient.nextResult = const AppLlmChatResult.success(
        text: 'anything',
      );

      final client = AppLlmSchemaValidatingClient(delegate: fakeClient);
      final request = _makeRequest();
      final result = await client.chat(request);

      expect(result.succeeded, isTrue);
      expect(result.text, 'anything');
      expect(fakeClient.callCount, 1);
    });
  });
}

// =============================================================================
// Test helpers
// =============================================================================

/// A simple fake LLM client for testing, with controllable responses.
class _FakeLlmClient implements AppLlmClient {
  int callCount = 0;
  List<List<AppLlmChatMessage>> capturedMessages = [];

  /// Single result mode: if [results] is not set, [nextResult] is returned
  /// for every call.
  AppLlmChatResult nextResult = const AppLlmChatResult.success(text: '');

  /// Multi-result mode: results are consumed in order.
  List<AppLlmChatResult>? results;

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    capturedMessages.add(List.of(request.messages));
    callCount++;
    if (results != null && results!.isNotEmpty) {
      return results!.removeAt(0);
    }
    return nextResult;
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) async* {
    yield 'fake stream';
  }
}

AppLlmChatRequest _makeRequest() {
  return const AppLlmChatRequest(
    baseUrl: 'https://example.com',
    apiKey: 'test-key',
    model: 'test-model',
    messages: [
      AppLlmChatMessage(role: 'user', content: 'hello'),
    ],
  );
}
