import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_canonical_hash.dart';
import 'package:novel_writer/app/llm/app_llm_client_contract.dart';
import 'package:novel_writer/app/llm/app_llm_client_types.dart';
import 'package:novel_writer/app/llm/app_llm_response_cache.dart';

void main() {
  test(
    'formal cache keys isolate execution, slot, run, stage, route, parser, and input',
    () async {
      final delegate = _CountingClient();
      final cache = AppLlmResponseCache(delegate: delegate);
      final request = _request();

      cache.beginEvaluationScope(_scope('execution-a', 'slot-1', 'run-1'));
      await cache.chat(request);
      final first = cache.finishEvaluationScope().single;
      expect(first.hit, isFalse);
      expect(first.sourceTrialSlotId, 'slot-1');

      cache.beginEvaluationScope(_scope('execution-a', 'slot-1', 'run-1'));
      await cache.chat(request);
      final sameTrial = cache.finishEvaluationScope().single;
      expect(sameTrial.hit, isTrue);
      expect(sameTrial.value['requestHash'], first.value['requestHash']);

      cache.beginEvaluationScope(_scope('execution-a', 'slot-2', 'run-2'));
      await cache.chat(request);
      final second = cache.finishEvaluationScope().single;
      expect(second.hit, isFalse);
      expect(second.sourceTrialSlotId, 'slot-2');
      expect(second.currentTrialSlotId, 'slot-2');
      expect(second.value['requestHash'], isNot(first.value['requestHash']));

      cache.beginEvaluationScope(_scope('execution-a', 'slot-1', 'run-2'));
      await cache.chat(request);
      final changedRun = cache.finishEvaluationScope().single;
      expect(changedRun.hit, isFalse);
      expect(
        changedRun.value['requestHash'],
        isNot(first.value['requestHash']),
      );

      cache.beginEvaluationScope(_scope('execution-b', 'slot-3', 'run-3'));
      await cache.chat(request);
      final third = cache.finishEvaluationScope().single;
      expect(third.hit, isFalse);
      expect(delegate.calls, 4);
      expect(third.toJson().toString(), isNot(contains(request.apiKey)));
    },
  );

  test('formal cache fails closed without exact call identity', () async {
    final cache = AppLlmResponseCache(delegate: _CountingClient());
    cache.beginEvaluationScope(_scope('execution-a', 'slot-1', 'run-1'));

    await expectLater(
      cache.chat(
        const AppLlmChatRequest(
          baseUrl: 'https://example.invalid/v1',
          apiKey: 'secret',
          model: 'frozen-model',
          messages: <AppLlmChatMessage>[
            AppLlmChatMessage(role: 'user', content: 'missing identity'),
          ],
        ),
      ),
      throwsStateError,
    );
  });

  test('formal call identity changes cannot reuse a response', () async {
    final delegate = _CountingClient();
    final cache = AppLlmResponseCache(delegate: delegate);

    Future<void> miss(
      AppLlmCacheEvaluationScope scope,
      AppLlmChatRequest request,
    ) async {
      cache.beginEvaluationScope(scope);
      await cache.chat(request);
      expect(cache.finishEvaluationScope().single.hit, isFalse);
    }

    await miss(_scope('execution-a', 'slot-1', 'run-1'), _request());
    await miss(
      _scope('execution-a', 'slot-1', 'run-1'),
      _request(stageId: 'different-stage'),
    );
    await miss(
      _scope('execution-a', 'slot-1', 'run-1'),
      _request(parserRelease: 'different-parser'),
    );
    await miss(
      _scope('execution-a', 'slot-1', 'run-1'),
      _request(content: 'different rendered input'),
    );
    const changedBundle =
        'sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
    await miss(
      _scope(
        'execution-a',
        'slot-1',
        'run-1',
        generationBundleHash: changedBundle,
      ),
      _request(generationBundleHash: changedBundle),
    );
    await miss(
      _scope(
        'execution-a',
        'slot-1',
        'run-1',
        modelRouteHash:
            'sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
      ),
      _request(),
    );
    await miss(
      _scope(
        'execution-a',
        'slot-1',
        'run-1',
        decodingConfigHash: 'different-decoding-release',
      ),
      _request(),
    );
    await miss(
      _scope(
        'execution-a',
        'slot-1',
        'run-1',
        outputSchemaHash: 'different-output-schema-release',
      ),
      _request(),
    );
    await miss(
      _scope(
        'execution-a',
        'slot-1',
        'run-1',
        promptReleaseHash: 'different-prompt-release',
      ),
      _request(),
    );

    expect(delegate.calls, 9);
  });

  test('formal persisted request hash is independent of API key', () async {
    Future<String> requestHash(String apiKey) async {
      final cache = AppLlmResponseCache(delegate: _CountingClient());
      cache.beginEvaluationScope(_scope('execution-a', 'slot-1', 'run-1'));
      await cache.chat(_request(apiKey: apiKey));
      return cache.finishEvaluationScope().single.value['requestHash']!
          as String;
    }

    final first = await requestHash('known-secret-a');
    final second = await requestHash('known-secret-b');
    expect(first, second);
  });

  test(
    'ordinary cache keeps credentials isolated without persisted receipts',
    () async {
      final delegate = _CountingClient();
      final cache = AppLlmResponseCache(delegate: delegate);

      await cache.chat(_request(apiKey: 'ordinary-secret-a', formal: false));
      await cache.chat(_request(apiKey: 'ordinary-secret-b', formal: false));

      expect(delegate.calls, 2);
    },
  );

  test(
    'receipt parser rejects a miss whose source is not exact-current',
    () async {
      final cache = AppLlmResponseCache(delegate: _CountingClient());
      cache.beginEvaluationScope(_scope('execution-a', 'slot-1', 'run-1'));
      await cache.chat(_request());
      final encoded = Map<String, Object?>.of(
        cache.finishEvaluationScope().single.toJson(),
      );
      encoded['sourceTrialSlotId'] = 'foreign-slot';
      final unsigned = Map<String, Object?>.of(encoded)..remove('receiptHash');
      encoded['receiptHash'] = AppLlmCanonicalHash.domainHash(
        'app-llm-cache-receipt-v1',
        unsigned,
      );

      expect(() => AppLlmCacheReceipt.fromJson(encoded), throwsFormatException);
    },
  );
}

AppLlmCacheEvaluationScope _scope(
  String executionId,
  String slotId,
  String runId, {
  String generationBundleHash =
      'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  String modelRouteHash =
      'sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
  String decodingConfigHash = 'decoding-release',
  String outputSchemaHash = 'schema-release',
  String promptReleaseHash = 'prompt-release',
}) => AppLlmCacheEvaluationScope(
  executionId: executionId,
  trialSlotId: slotId,
  attemptNo: 1,
  runId: runId,
  generationBundleHash: generationBundleHash,
  modelRouteHash: modelRouteHash,
  decodingConfigHash: decodingConfigHash,
  outputSchemaHash: outputSchemaHash,
  promptReleaseHash: promptReleaseHash,
);

AppLlmChatRequest _request({
  String apiKey = 'must-not-appear-in-receipt',
  bool formal = true,
  String stageId = 'scene-role-turn',
  String generationBundleHash =
      'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  String parserRelease = 'role-turn-parser-v2',
  String content = 'same frozen request',
}) => AppLlmChatRequest(
  baseUrl: 'https://example.invalid/v1',
  apiKey: apiKey,
  model: 'frozen-model',
  provider: AppLlmProvider.openaiCompatible,
  messages: <AppLlmChatMessage>[
    AppLlmChatMessage(role: 'user', content: content),
  ],
  formalCacheIdentity: formal
      ? AppLlmFormalCacheRequestIdentity(
          stageId: stageId,
          generationBundleHash: generationBundleHash,
          parserRelease: parserRelease,
        )
      : null,
);

final class _CountingClient implements AppLlmClient {
  var calls = 0;

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    calls += 1;
    return const AppLlmChatResult.success(
      text: 'cached response',
      promptTokens: 3,
      completionTokens: 2,
      totalTokens: 5,
    );
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) => const Stream.empty();
}
