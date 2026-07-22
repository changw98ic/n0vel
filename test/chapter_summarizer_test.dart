import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/features/story_generation/data/chapter_summarizer.dart';
import 'package:novel_writer/features/story_generation/data/scene_review_models.dart';
import 'package:novel_writer/features/story_generation/data/scene_runtime_models.dart';
import 'package:novel_writer/features/story_generation/data/story_generation_pass_retry.dart';
import 'package:novel_writer/features/story_generation/domain/memory_models.dart';

import 'test_support/fake_app_llm_client.dart';

void main() {
  test('chapter summary preserves its legacy single dispatch budget', () async {
    final client = FakeAppLlmClient(
      responder: (_) => const AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.server,
        statusCode: 503,
        detail: 'retryable upstream failure',
      ),
    );
    final store = AppSettingsStore(
      storage: InMemoryAppSettingsStorage(),
      llmClient: client,
    );
    addTearDown(store.dispose);

    final summary = await ChapterSummarizer(settingsStore: store)
        .summarizeChapter(
          chapterId: 'chapter-01',
          chapterTitle: '第一章',
          outputs: [_sceneOutput()],
          nowMs: 1,
        );

    expect(summary, isNull);
    expect(client.requests, hasLength(1));
    expect(client.requests.single.maxTokens, 4096);
  });

  test('formal chapter summary provider failure result is fatal', () async {
    final client = FakeAppLlmClient(
      responder: (_) => const AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.server,
        statusCode: 503,
        detail: 'classified provider failure',
      ),
    );
    final store = AppSettingsStore(
      storage: InMemoryAppSettingsStorage(),
      llmClient: client,
    );
    addTearDown(store.dispose);

    final future = ChapterSummarizer(settingsStore: store).summarizeChapter(
      chapterId: 'chapter-01',
      chapterTitle: '第一章',
      outputs: [_sceneOutput(formalExecution: true)],
      nowMs: 1,
    );

    await expectLater(
      future,
      throwsA(
        isA<StateError>().having(
          (error) => error.toString(),
          'message',
          contains('formal chapter summary provider failure'),
        ),
      ),
    );
    expect(client.requests, hasLength(1));
  });

  test(
    'no-redraw chapter summary failure is fatal after complete evidence',
    () async {
      var providerCalls = 0;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        providerCalls += 1;
        await utf8.decoder.bind(request).join();
        request.response
          ..statusCode = HttpStatus.serviceUnavailable
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode(<String, Object?>{
              'error': <String, Object?>{
                'message': 'classified provider failure',
              },
            }),
          );
        await request.response.close();
      });
      final store = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: createDefaultAppLlmClient(),
      );
      addTearDown(store.dispose);
      await store.save(
        providerName: 'test',
        baseUrl: 'http://${server.address.host}:${server.port}/v1',
        model: 'gpt-4.1-mini',
        apiKey: '',
        timeout: const AppLlmTimeoutConfig.uniform(5000),
      );
      final recorded = <StoryGenerationAttemptEvidence>[];
      final durable = <StoryGenerationAttemptEvidence>[];
      final intents = <StoryGenerationAttemptIntent>[];

      final future = StoryGenerationRetryScope.run<Future<ChapterSummary?>>(
        policy: const StoryGenerationRetryPolicy.experimentNoContentRedraw(
          maxTotalAttempts: 1,
        ),
        onAttemptEvidence: recorded.add,
        persistAttemptEvidence: (evidence) async => durable.add(evidence),
        persistAttemptIntent: (intent) async => intents.add(intent),
        generationArmPolicy: 'chapter-summary-no-redraw-test-v1',
        evidenceRunId: 'chapter-summary-failure-run-v1',
        evidenceSceneId: 'chapter-01-summary',
        preparedBriefDigest:
            'sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        body: () => ChapterSummarizer(settingsStore: store).summarizeChapter(
          chapterId: 'chapter-01',
          chapterTitle: '第一章',
          outputs: [_sceneOutput()],
          nowMs: 1,
        ),
      );

      await expectLater(
        future,
        throwsA(
          isA<StateError>().having(
            (error) => error.toString(),
            'message',
            contains('formal chapter summary provider failure'),
          ),
        ),
      );
      expect(providerCalls, 1);
      expect(intents, hasLength(1));
      expect(durable, hasLength(1));
      expect(recorded, hasLength(1));
      expect(durable.single.succeeded, isFalse);
      expect(durable.single.evidenceComplete, isTrue);
      expect(
        durable.single.privateEvidenceDigest,
        recorded.single.privateEvidenceDigest,
      );
    },
  );

  test(
    'no-redraw chapter summary cannot swallow evidence persistence failure',
    () async {
      var providerCalls = 0;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        providerCalls += 1;
        await utf8.decoder.bind(request).join();
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode(<String, Object?>{
              'id': 'chapter-summary-response-1',
              'model': 'gpt-4.1-mini',
              'choices': <Object?>[
                <String, Object?>{
                  'message': <String, Object?>{'content': '剧情：柳溪等到了线人。'},
                },
              ],
            }),
          );
        await request.response.close();
      });
      final store = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: createDefaultAppLlmClient(),
      );
      addTearDown(store.dispose);
      await store.save(
        providerName: 'test',
        baseUrl: 'http://${server.address.host}:${server.port}/v1',
        model: 'gpt-4.1-mini',
        apiKey: '',
        timeout: const AppLlmTimeoutConfig.uniform(5000),
      );

      final future = StoryGenerationRetryScope.run<Future<ChapterSummary?>>(
        policy: const StoryGenerationRetryPolicy.experimentNoContentRedraw(
          maxTotalAttempts: 1,
        ),
        onAttemptEvidence: (_) {},
        persistAttemptEvidence: (_) async {
          throw StateError('evidence sink failed');
        },
        persistAttemptIntent: (_) async => null,
        generationArmPolicy: 'chapter-summary-no-redraw-test-v1',
        evidenceRunId: 'chapter-summary-no-redraw-run-v1',
        evidenceSceneId: 'chapter-01-summary',
        preparedBriefDigest:
            'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        body: () => ChapterSummarizer(settingsStore: store).summarizeChapter(
          chapterId: 'chapter-01',
          chapterTitle: '第一章',
          outputs: [_sceneOutput()],
          nowMs: 1,
        ),
      );

      await expectLater(
        future,
        throwsA(
          isA<StateError>().having(
            (error) => error.toString(),
            'message',
            contains('evidence sink failed'),
          ),
        ),
      );
      expect(providerCalls, 1);
    },
  );
}

SceneRuntimeOutput _sceneOutput({bool formalExecution = false}) =>
    SceneRuntimeOutput(
      brief: SceneBrief(
        chapterId: 'chapter-01',
        chapterTitle: '第一章',
        sceneId: 'scene-01',
        sceneTitle: '雨站',
        sceneSummary: '柳溪在雨站等人。',
        formalExecution: formalExecution,
      ),
      resolvedCast: const [],
      director: const SceneDirectorOutput(text: '目标：等到线人。'),
      roleOutputs: const [],
      prose: const SceneProseDraft(text: '雨下了一夜。', attempt: 1),
      review: const SceneReviewResult(
        judge: SceneReviewPassResult(
          status: SceneReviewStatus.pass,
          reason: 'pass',
          rawText: 'PASS',
        ),
        consistency: SceneReviewPassResult(
          status: SceneReviewStatus.pass,
          reason: 'pass',
          rawText: 'PASS',
        ),
        decision: SceneReviewDecision.pass,
      ),
      proseAttempts: 1,
      softFailureCount: 0,
    );
