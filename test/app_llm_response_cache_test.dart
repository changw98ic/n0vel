import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';

class _CountingFakeLlmClient implements AppLlmClient {
  int callCount = 0;
  final List<AppLlmChatResult> _queue = [];

  void enqueue(List<AppLlmChatResult> results) {
    _queue.addAll(results);
  }

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    callCount++;
    if (_queue.isEmpty) {
      throw StateError('no more results enqueued');
    }
    return _queue.removeAt(0);
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) {
    throw UnimplementedError('chatStream');
  }
}

AppLlmChatRequest _makeRequest({
  String baseUrl = 'https://api.example.com/v1',
  String apiKey = 'sk-test',
  String model = 'gpt-4.1-mini',
  AppLlmTimeoutConfig timeout = const AppLlmTimeoutConfig.uniform(30000),
  List<AppLlmChatMessage> messages = const [
    AppLlmChatMessage(role: 'user', content: 'hello'),
  ],
}) {
  return AppLlmChatRequest(
    baseUrl: baseUrl,
    apiKey: apiKey,
    model: model,
    timeout: timeout,
    messages: messages,
  );
}

void main() {
  group('AppLlmResponseCache', () {
    late _CountingFakeLlmClient fake;
    late AppLlmResponseCache cache;

    setUp(() {
      fake = _CountingFakeLlmClient();
      cache = AppLlmResponseCache(delegate: fake);
    });

    test('delegates to underlying client on cache miss', () async {
      fake.enqueue([
        const AppLlmChatResult.success(text: 'response'),
      ]);

      final result = await cache.chat(_makeRequest());

      expect(result.succeeded, isTrue);
      expect(result.text, 'response');
      expect(fake.callCount, 1);
      expect(cache.misses, 1);
      expect(cache.hits, 0);
    });

    test('returns cached response on cache hit', () async {
      fake.enqueue([
        const AppLlmChatResult.success(text: 'cached'),
      ]);

      final request = _makeRequest();
      final result1 = await cache.chat(request);
      final result2 = await cache.chat(request);

      expect(result1.text, 'cached');
      expect(result2.text, 'cached');
      expect(fake.callCount, 1);
      expect(cache.hits, 1);
      expect(cache.misses, 1);
      expect(cache.size, 1);
    });

    test('does not cache failed responses', () async {
      fake.enqueue([
        const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.server,
          statusCode: 500,
          detail: 'error',
        ),
        const AppLlmChatResult.success(text: 'ok'),
      ]);

      final request = _makeRequest();
      final result1 = await cache.chat(request);
      final result2 = await cache.chat(request);

      expect(result1.succeeded, isFalse);
      expect(result2.succeeded, isTrue);
      expect(fake.callCount, 2);
      expect(cache.size, 1);
    });

    test('cache misses when messages differ', () async {
      fake.enqueue([
        const AppLlmChatResult.success(text: 'first'),
        const AppLlmChatResult.success(text: 'second'),
      ]);

      final request1 = _makeRequest(
        messages: const [AppLlmChatMessage(role: 'user', content: 'hello')],
      );
      final request2 = _makeRequest(
        messages: const [AppLlmChatMessage(role: 'user', content: 'world')],
      );

      final result1 = await cache.chat(request1);
      final result2 = await cache.chat(request2);

      expect(result1.text, 'first');
      expect(result2.text, 'second');
      expect(fake.callCount, 2);
      expect(cache.misses, 2);
    });

    test('cache misses when model differs', () async {
      fake.enqueue([
        const AppLlmChatResult.success(text: 'model-a'),
        const AppLlmChatResult.success(text: 'model-b'),
      ]);

      final request1 = _makeRequest(model: 'gpt-4.1-mini');
      final request2 = _makeRequest(model: 'gpt-5.4');

      final result1 = await cache.chat(request1);
      final result2 = await cache.chat(request2);

      expect(result1.text, 'model-a');
      expect(result2.text, 'model-b');
      expect(fake.callCount, 2);
    });

    test('cache misses when baseUrl differs', () async {
      fake.enqueue([
        const AppLlmChatResult.success(text: 'url-a'),
        const AppLlmChatResult.success(text: 'url-b'),
      ]);

      final request1 = _makeRequest(baseUrl: 'https://a.example.com/v1');
      final request2 = _makeRequest(baseUrl: 'https://b.example.com/v1');

      await cache.chat(request1);
      await cache.chat(request2);

      expect(fake.callCount, 2);
    });

    test('cache misses when apiKey differs', () async {
      fake.enqueue([
        const AppLlmChatResult.success(text: 'key-a'),
        const AppLlmChatResult.success(text: 'key-b'),
      ]);

      final request1 = _makeRequest(apiKey: 'sk-aaa');
      final request2 = _makeRequest(apiKey: 'sk-bbb');

      await cache.chat(request1);
      await cache.chat(request2);

      expect(fake.callCount, 2);
    });

    test('timeout config does not affect cache key', () async {
      fake.enqueue([
        const AppLlmChatResult.success(text: 'same'),
      ]);

      final request1 = _makeRequest(
        timeout: const AppLlmTimeoutConfig.uniform(10000),
      );
      final request2 = _makeRequest(
        timeout: const AppLlmTimeoutConfig.uniform(60000),
      );

      await cache.chat(request1);
      final result2 = await cache.chat(request2);

      expect(result2.text, 'same');
      expect(fake.callCount, 1);
      expect(cache.hits, 1);
    });

    test('expires entries after TTL', () async {
      final shortTtlCache = AppLlmResponseCache(
        delegate: fake,
        defaultTtlMs: 100,
      );
      fake.enqueue([
        const AppLlmChatResult.success(text: 'expired'),
        const AppLlmChatResult.success(text: 'fresh'),
      ]);

      final request = _makeRequest();
      await shortTtlCache.chat(request);

      // Wait for TTL to expire
      await Future<void>.delayed(const Duration(milliseconds: 150));

      final result = await shortTtlCache.chat(request);
      expect(result.text, 'fresh');
      expect(fake.callCount, 2);
    });

    test('evicts oldest entries when maxEntries exceeded', () async {
      final smallCache = AppLlmResponseCache(
        delegate: fake,
        maxEntries: 2,
      );

      for (var i = 0; i < 3; i++) {
        fake.enqueue([
          AppLlmChatResult.success(text: 'response-$i'),
        ]);
        await smallCache.chat(
          _makeRequest(
            messages: [AppLlmChatMessage(role: 'user', content: 'prompt-$i')],
          ),
        );
      }

      expect(smallCache.size, 2);

      // First entry should be evicted; second and third should remain
      fake.enqueue([
        const AppLlmChatResult.success(text: 're-fetched'),
      ]);
      final result = await smallCache.chat(
        _makeRequest(
          messages: const [AppLlmChatMessage(role: 'user', content: 'prompt-0')],
        ),
      );
      expect(result.text, 're-fetched');
      expect(fake.callCount, 4);
    });

    test('clearAll removes entries and resets counters', () async {
      fake.enqueue([
        const AppLlmChatResult.success(text: 'hello'),
      ]);

      await cache.chat(_makeRequest());
      expect(cache.size, 1);
      expect(cache.misses, 1);

      cache.clearAll();

      expect(cache.size, 0);
      expect(cache.hits, 0);
      expect(cache.misses, 0);
    });

    test('overwrites entry when same request is cached again', () async {
      fake.enqueue([
        const AppLlmChatResult.success(text: 'first'),
        const AppLlmChatResult.success(text: 'second'),
      ]);

      final request = _makeRequest();

      // First call caches "first"
      await cache.chat(request);

      // Simulate TTL expiry by clearing and re-requesting
      cache.clearAll();
      fake.enqueue([
        const AppLlmChatResult.success(text: 'second'),
      ]);
      await cache.chat(request);

      expect(cache.size, 1);
    });

    test('cache hit returns same latency as original', () async {
      fake.enqueue([
        const AppLlmChatResult.success(text: 'measured', latencyMs: 42),
      ]);

      final request = _makeRequest();
      await cache.chat(request);
      final cached = await cache.chat(request);

      expect(cached.latencyMs, 42);
    });

    test('different message order produces different cache key', () async {
      fake.enqueue([
        const AppLlmChatResult.success(text: 'ordered-a'),
        const AppLlmChatResult.success(text: 'ordered-b'),
      ]);

      final request1 = _makeRequest(
        messages: const [
          AppLlmChatMessage(role: 'system', content: 'sys'),
          AppLlmChatMessage(role: 'user', content: 'usr'),
        ],
      );
      final request2 = _makeRequest(
        messages: const [
          AppLlmChatMessage(role: 'user', content: 'usr'),
          AppLlmChatMessage(role: 'system', content: 'sys'),
        ],
      );

      await cache.chat(request1);
      await cache.chat(request2);

      expect(fake.callCount, 2);
    });

    test('same messages in same order produces cache hit', () async {
      fake.enqueue([
        const AppLlmChatResult.success(text: 'match'),
      ]);

      final messages = [
        const AppLlmChatMessage(role: 'system', content: 'sys'),
        const AppLlmChatMessage(role: 'user', content: 'usr'),
      ];

      final request1 = _makeRequest(messages: messages);
      final request2 = _makeRequest(messages: messages);

      await cache.chat(request1);
      final result2 = await cache.chat(request2);

      expect(result2.text, 'match');
      expect(fake.callCount, 1);
      expect(cache.hits, 1);
    });
  });
}
