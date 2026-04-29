import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/logging/app_event_log.dart';
import 'package:novel_writer/app/logging/app_event_log_storage.dart';

class _InMemoryEventLogStorage implements AppEventLogStorage {
  final List<AppEventLogEntry> entries = [];

  @override
  Future<void> write(AppEventLogEntry entry) async {
    entries.add(entry);
  }
}

class _RecordingFakeLlmClient implements AppLlmClient {
  final List<AppLlmChatResult> _queue = [];
  final List<AppLlmChatRequest> requests = [];
  bool throwOnNext = false;
  Object? throwError;

  void enqueue(List<AppLlmChatResult> results) {
    _queue.addAll(results);
  }

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    requests.add(request);
    if (throwOnNext) {
      throwOnNext = false;
      throw throwError ?? StateError('intentional');
    }
    if (_queue.isEmpty) {
      throw StateError('no results enqueued');
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
  List<AppLlmChatMessage> messages = const [
    AppLlmChatMessage(role: 'user', content: 'hello'),
  ],
}) {
  return AppLlmChatRequest(
    baseUrl: baseUrl,
    apiKey: apiKey,
    model: model,
    timeout: const AppLlmTimeoutConfig.uniform(30000),
    messages: messages,
  );
}

void main() {
  group('AppLlmLoggingMiddleware', () {
    test('passes through successful result unchanged', () async {
      final fake = _RecordingFakeLlmClient();
      fake.enqueue([
        const AppLlmChatResult.success(text: 'pong', latencyMs: 42),
      ]);

      final middleware = AppLlmLoggingMiddleware(delegate: fake);
      final result = await middleware.chat(_makeRequest());

      expect(result.succeeded, isTrue);
      expect(result.text, 'pong');
      expect(result.latencyMs, 42);
    });

    test('passes through failure result unchanged', () async {
      final fake = _RecordingFakeLlmClient();
      fake.enqueue([
        const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.unauthorized,
          statusCode: 401,
          detail: 'bad key',
        ),
      ]);

      final middleware = AppLlmLoggingMiddleware(delegate: fake);
      final result = await middleware.chat(_makeRequest());

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.unauthorized);
      expect(result.statusCode, 401);
      expect(result.detail, 'bad key');
    });

    test('delegates request to underlying client', () async {
      final fake = _RecordingFakeLlmClient();
      fake.enqueue([
        const AppLlmChatResult.success(text: 'ok'),
      ]);

      final middleware = AppLlmLoggingMiddleware(delegate: fake);
      await middleware.chat(_makeRequest(model: 'gpt-5.4'));

      expect(fake.requests, hasLength(1));
      expect(fake.requests.first.model, 'gpt-5.4');
    });

    test('rethrows when delegate throws', () async {
      final fake = _RecordingFakeLlmClient();
      fake.throwOnNext = true;
      fake.throwError = StateError('boom');

      final middleware = AppLlmLoggingMiddleware(delegate: fake);

      expect(
        () => middleware.chat(_makeRequest()),
        throwsStateError,
      );
    });

    test('works without event log', () async {
      final fake = _RecordingFakeLlmClient();
      fake.enqueue([
        const AppLlmChatResult.success(text: 'no-log'),
      ]);

      final middleware = AppLlmLoggingMiddleware(delegate: fake);
      final result = await middleware.chat(_makeRequest());

      expect(result.text, 'no-log');
    });

    test('writes success event to event log', () async {
      final fake = _RecordingFakeLlmClient();
      fake.enqueue([
        const AppLlmChatResult.success(text: 'logged', latencyMs: 100),
      ]);
      final storage = _InMemoryEventLogStorage();
      final eventLog = AppEventLog(
        storage: storage,
        sessionId: 'test-session',
      );

      final middleware = AppLlmLoggingMiddleware(
        delegate: fake,
        eventLog: eventLog,
      );
      await middleware.chat(_makeRequest());

      expect(storage.entries, hasLength(1));
      final entry = storage.entries.first;
      expect(entry.category, AppEventLogCategory.ai);
      expect(entry.action, 'llm.chat');
      expect(entry.status, AppEventLogStatus.succeeded);
      expect(entry.level, AppEventLogLevel.info);
      expect(entry.metadata['model'], 'gpt-4.1-mini');
      expect(entry.metadata['host'], 'api.example.com');
      expect(entry.metadata['latencyMs'], 100);
      expect(entry.metadata['messageCount'], 1);
    });

    test('writes failure event to event log with error info', () async {
      final fake = _RecordingFakeLlmClient();
      fake.enqueue([
        const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.server,
          statusCode: 500,
          detail: 'internal error',
        ),
      ]);
      final storage = _InMemoryEventLogStorage();
      final eventLog = AppEventLog(
        storage: storage,
        sessionId: 'test-session',
      );

      final middleware = AppLlmLoggingMiddleware(
        delegate: fake,
        eventLog: eventLog,
      );
      await middleware.chat(_makeRequest());

      expect(storage.entries, hasLength(1));
      final entry = storage.entries.first;
      expect(entry.status, AppEventLogStatus.failed);
      expect(entry.level, AppEventLogLevel.warn);
      expect(entry.errorCode, 'server');
      expect(entry.errorDetail, 'internal error');
      expect(entry.metadata['statusCode'], 500);
    });

    test('uses stopwatch latency when result has none', () async {
      final fake = _RecordingFakeLlmClient();
      fake.enqueue([
        const AppLlmChatResult.success(text: 'no-latency'),
      ]);
      final storage = _InMemoryEventLogStorage();
      final eventLog = AppEventLog(
        storage: storage,
        sessionId: 'test-session',
      );

      final middleware = AppLlmLoggingMiddleware(
        delegate: fake,
        eventLog: eventLog,
      );
      await middleware.chat(_makeRequest());

      final entry = storage.entries.first;
      expect(entry.metadata['latencyMs'], isA<int>());
      expect(entry.metadata['latencyMs'] as int, greaterThanOrEqualTo(0));
    });

    test('extracts host from base URL', () async {
      final fake = _RecordingFakeLlmClient();
      fake.enqueue([
        const AppLlmChatResult.success(text: 'ok'),
      ]);
      final storage = _InMemoryEventLogStorage();
      final eventLog = AppEventLog(
        storage: storage,
        sessionId: 'test-session',
      );

      final middleware = AppLlmLoggingMiddleware(
        delegate: fake,
        eventLog: eventLog,
      );
      await middleware.chat(
        _makeRequest(baseUrl: 'https://my-llm.host.io/v1'),
      );

      expect(storage.entries.first.metadata['host'], 'my-llm.host.io');
    });

    test('falls back to raw baseUrl when host is unparseable', () async {
      final fake = _RecordingFakeLlmClient();
      fake.enqueue([
        const AppLlmChatResult.success(text: 'ok'),
      ]);
      final storage = _InMemoryEventLogStorage();
      final eventLog = AppEventLog(
        storage: storage,
        sessionId: 'test-session',
      );

      final middleware = AppLlmLoggingMiddleware(
        delegate: fake,
        eventLog: eventLog,
      );
      await middleware.chat(
        _makeRequest(baseUrl: 'not-a-url'),
      );

      expect(storage.entries.first.metadata['host'], 'not-a-url');
    });

    test('multiple requests produce multiple event log entries', () async {
      final fake = _RecordingFakeLlmClient();
      fake.enqueue([
        const AppLlmChatResult.success(text: 'first'),
        const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.timeout,
          detail: 'timed out',
        ),
      ]);
      final storage = _InMemoryEventLogStorage();
      final eventLog = AppEventLog(
        storage: storage,
        sessionId: 'test-session',
      );

      final middleware = AppLlmLoggingMiddleware(
        delegate: fake,
        eventLog: eventLog,
      );
      await middleware.chat(_makeRequest());
      await middleware.chat(_makeRequest());

      expect(storage.entries, hasLength(2));
      expect(storage.entries[0].status, AppEventLogStatus.succeeded);
      expect(storage.entries[1].status, AppEventLogStatus.failed);
    });
  });
}
