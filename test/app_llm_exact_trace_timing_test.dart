import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/llm/app_llm_request_pool.dart';
import 'package:novel_writer/app/llm/app_llm_trace_summary.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';

import 'test_support/app_llm_authorized_request.dart';

void main() {
  test('central request trace records an exact pool-slot interval', () async {
    final client = _DelayedResultClient(
      const AppLlmChatResult.success(text: 'ok', latencyMs: 1),
    );
    final sink = _RecordingTraceSink();
    final store = AppSettingsStore(
      storage: InMemoryAppSettingsStorage(),
      llmClient: client,
      requestPool: AppLlmRequestPool(maxConcurrent: 1),
      llmTraceSink: sink,
    );
    addTearDown(store.dispose);

    final future = requestAuthorizedAiCompletionForTest(
      store,
      messages: const <AppLlmChatMessage>[
        AppLlmChatMessage(role: 'user', content: 'trace exact timing'),
      ],
      traceName: 'exact_timing_test',
    );
    await client.started.future;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    client.complete();
    await future;

    final json = sink.entries.single.toJson();
    final summary = AppLlmTraceSummary.fromJsonEntries(
      <Map<String, Object?>>[json],
      configuredSceneConcurrency: 3,
      configuredRequestConcurrency: 1,
    );

    expect(json['startedAtMs'], isA<int>());
    expect(json['completedAtMs'], isA<int>());
    expect(json['timestampMs'], json['completedAtMs']);
    expect(json['metadata'], containsPair('poolActiveAtDispatch', 1));
    expect(json['metadata'], containsPair('poolLimitAtDispatch', 1));
    expect(summary.timingEvidence, AppLlmTraceTimingEvidence.exact);
    expect(summary.exactTimingCalls, 1);
    expect(summary.inferredTimingCalls, 0);
    expect(summary.configuredSceneConcurrency, 3);
    expect(summary.observedMaxConcurrency, 1);
  });

  test('timeout failure closes the exact dispatch interval', () async {
    final client = _DelayedResultClient(
      const AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.timeout,
        detail: 'receive timeout',
      ),
    );
    final sink = _RecordingTraceSink();
    final store = AppSettingsStore(
      storage: InMemoryAppSettingsStorage(),
      llmClient: client,
      requestPool: AppLlmRequestPool(maxConcurrent: 1),
      llmTraceSink: sink,
    );
    addTearDown(store.dispose);

    final future = requestAuthorizedAiCompletionForTest(
      store,
      messages: const <AppLlmChatMessage>[
        AppLlmChatMessage(role: 'user', content: 'timeout trace'),
      ],
      traceName: 'timeout_timing_test',
    );
    await client.started.future;
    await Future<void>.delayed(const Duration(milliseconds: 2));
    client.complete();
    final result = await future;

    expect(result.failureKind, AppLlmFailureKind.timeout);
    final entry = sink.entries.single;
    expect(entry.succeeded, isFalse);
    expect(entry.failureKind, AppLlmFailureKind.timeout.name);
    expect(entry.completedAtMs, greaterThan(entry.startedAtMs!));
    expect(entry.timestampMs, entry.completedAtMs);
  });

  test(
    'thrown client error is traced with a closed interval then rethrown',
    () async {
      final sink = _RecordingTraceSink();
      final store = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: const _ThrowingClient(),
        requestPool: AppLlmRequestPool(maxConcurrent: 1),
        llmTraceSink: sink,
      );
      addTearDown(store.dispose);

      await expectLater(
        requestAuthorizedAiCompletionForTest(
          store,
          messages: const <AppLlmChatMessage>[
            AppLlmChatMessage(role: 'user', content: 'throw trace'),
          ],
          traceName: 'throw_timing_test',
        ),
        throwsStateError,
      );

      final entry = sink.entries.single;
      expect(entry.succeeded, isFalse);
      expect(entry.failureKind, AppLlmFailureKind.server.name);
      expect(entry.completedAtMs, greaterThan(entry.startedAtMs!));
    },
  );

  test('legacy trace JSON remains inferred when exact fields are absent', () {
    final entry = AppLlmCallTraceEntry.fromRequestResult(
      request: const AppLlmChatRequest(
        baseUrl: 'https://example.test/v1',
        apiKey: 'secret',
        model: 'legacy-model',
        messages: <AppLlmChatMessage>[
          AppLlmChatMessage(role: 'user', content: 'legacy'),
        ],
      ),
      result: const AppLlmChatResult.success(text: 'ok', latencyMs: 7),
      traceName: 'legacy_trace',
    );
    final json = entry.toJson();
    final summary = AppLlmTraceSummary.fromJsonEntries(
      <Map<String, Object?>>[json],
      configuredSceneConcurrency: 3,
      configuredRequestConcurrency: 1,
    );

    expect(json, isNot(contains('startedAtMs')));
    expect(json, isNot(contains('completedAtMs')));
    expect(summary.timingEvidence, AppLlmTraceTimingEvidence.inferred);
    expect(summary.exactTimingCalls, 0);
    expect(summary.inferredTimingCalls, 1);
  });

  test('two occupied pool slots produce observed concurrency of two', () async {
    final client = _ControlledConcurrentClient(callCount: 2);
    final sink = _RecordingTraceSink();
    final store = AppSettingsStore(
      storage: InMemoryAppSettingsStorage(),
      llmClient: client,
      requestPool: AppLlmRequestPool(maxConcurrent: 2),
      llmTraceSink: sink,
    );
    addTearDown(store.dispose);
    await _setRequestConcurrency(store, 2);

    final requests = <Future<AppLlmChatResult>>[
      requestAuthorizedAiCompletionForTest(
        store,
        messages: const <AppLlmChatMessage>[
          AppLlmChatMessage(role: 'user', content: 'parallel one'),
        ],
        traceName: 'parallel_one',
      ),
      requestAuthorizedAiCompletionForTest(
        store,
        messages: const <AppLlmChatMessage>[
          AppLlmChatMessage(role: 'user', content: 'parallel two'),
        ],
        traceName: 'parallel_two',
      ),
    ];
    await Future.wait<void>(
      client.started.map((completer) => completer.future),
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    client.release(0);
    client.release(1);
    await Future.wait(requests);

    final summary = _summary(sink.entries, configuredRequestConcurrency: 2);
    expect(summary.timingEvidence, AppLlmTraceTimingEvidence.exact);
    expect(summary.exactTimingCalls, 2);
    expect(summary.observedMaxConcurrency, 2);
    expect(
      sink.entries
          .map((entry) => entry.metadata['poolActiveAtDispatch'])
          .toSet(),
      <Object?>{1, 2},
    );
  });

  test('queued wait is excluded from exact dispatch intervals', () async {
    final client = _ControlledConcurrentClient(callCount: 2);
    final sink = _RecordingTraceSink();
    final store = AppSettingsStore(
      storage: InMemoryAppSettingsStorage(),
      llmClient: client,
      requestPool: AppLlmRequestPool(maxConcurrent: 1),
      llmTraceSink: sink,
    );
    addTearDown(store.dispose);
    await _setRequestConcurrency(store, 1);

    final requests = <Future<AppLlmChatResult>>[
      requestAuthorizedAiCompletionForTest(
        store,
        messages: const <AppLlmChatMessage>[
          AppLlmChatMessage(role: 'user', content: 'queued one'),
        ],
        traceName: 'queued_one',
      ),
      requestAuthorizedAiCompletionForTest(
        store,
        messages: const <AppLlmChatMessage>[
          AppLlmChatMessage(role: 'user', content: 'queued two'),
        ],
        traceName: 'queued_two',
      ),
    ];
    await client.started.first.future;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(client.started[1].isCompleted, isFalse);

    client.release(0);
    await client.started[1].future;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    client.release(1);
    await Future.wait(requests);

    final entries = sink.entries.toList()
      ..sort((left, right) => left.startedAtMs!.compareTo(right.startedAtMs!));
    final summary = _summary(entries, configuredRequestConcurrency: 1);
    expect(summary.exactTimingCalls, 2);
    expect(summary.observedMaxConcurrency, 1);
    expect(
      entries[1].startedAtMs,
      greaterThanOrEqualTo(entries[0].completedAtMs!),
    );
    expect(
      entries.map((entry) => entry.metadata['poolActiveAtDispatch']),
      everyElement(1),
    );
  });
}

Future<void> _setRequestConcurrency(
  AppSettingsStore store,
  int maxConcurrentRequests,
) async {
  await store.save(
    providerName: 'Trace test',
    baseUrl: 'https://example.test/v1',
    model: 'trace-model',
    apiKey: 'secret',
    maxConcurrentRequests: maxConcurrentRequests,
  );
}

AppLlmTraceSummary _summary(
  Iterable<AppLlmCallTraceEntry> entries, {
  required int configuredRequestConcurrency,
}) => AppLlmTraceSummary.fromJsonEntries(
  entries.map((entry) => entry.toJson()),
  configuredSceneConcurrency: 3,
  configuredRequestConcurrency: configuredRequestConcurrency,
);

final class _DelayedResultClient implements AppLlmClient {
  _DelayedResultClient(this.result);

  final AppLlmChatResult result;
  final Completer<void> started = Completer<void>();
  final Completer<void> _release = Completer<void>();

  void complete() => _release.complete();

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    if (!started.isCompleted) started.complete();
    await _release.future;
    return result;
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) =>
      const Stream<String>.empty();
}

final class _RecordingTraceSink implements AppLlmCallTraceSink {
  final List<AppLlmCallTraceEntry> entries = <AppLlmCallTraceEntry>[];

  @override
  Future<void> record(AppLlmCallTraceEntry entry) async {
    entries.add(entry);
  }
}

final class _ThrowingClient implements AppLlmClient {
  const _ThrowingClient();

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    throw StateError('transport escaped its adapter');
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) =>
      const Stream<String>.empty();
}

final class _ControlledConcurrentClient implements AppLlmClient {
  _ControlledConcurrentClient({required int callCount})
    : started = List<Completer<void>>.generate(
        callCount,
        (_) => Completer<void>(),
      ),
      _releases = List<Completer<void>>.generate(
        callCount,
        (_) => Completer<void>(),
      );

  final List<Completer<void>> started;
  final List<Completer<void>> _releases;
  int _nextCall = 0;

  void release(int index) => _releases[index].complete();

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    final index = _nextCall++;
    started[index].complete();
    await _releases[index].future;
    return AppLlmChatResult.success(text: 'ok-$index');
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) =>
      const Stream<String>.empty();
}
