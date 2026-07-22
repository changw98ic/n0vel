import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/features/story_generation/data/character_consistency_models.dart';
import 'package:novel_writer/features/story_generation/data/character_consistency_verifier.dart';
import 'package:novel_writer/features/story_generation/data/scene_context_models.dart';
import 'package:novel_writer/features/story_generation/data/scene_runtime_models.dart';
import 'package:novel_writer/features/story_generation/data/soul_contract_validator.dart';
import 'package:novel_writer/features/story_generation/data/story_generation_pass_retry.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/soul_contract.dart';

import 'test_support/fake_app_llm_client.dart';

void main() {
  test(
    'preGenerationCheck reports blocking soul contract violations',
    () async {
      final store = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: FakeAppLlmClient(
          responder: (_) => const AppLlmChatResult.success(text: 'PASS'),
        ),
      );
      addTearDown(store.dispose);
      final verifier = CharacterConsistencyVerifier(
        settingsStore: store,
        soulValidator: const SoulContractValidator(
          SoulContract(forbiddenActions: ['betray']),
        ),
      );

      final report = await verifier.preGenerationCheck(
        brief: SceneBrief(
          chapterId: 'chapter-01',
          chapterTitle: 'Chapter',
          sceneId: 'scene-01',
          sceneTitle: 'Crossroads',
          sceneSummary: 'Aki chooses to betray the crew at dawn.',
        ),
        cast: [
          ResolvedSceneCastMember(
            characterId: 'aki',
            name: 'Aki',
            role: 'lead',
            contributions: const [SceneCastContribution.action],
          ),
        ],
        allFacts: const [],
        policies: const [],
      );

      expect(report.hasBlockingIssues, isTrue);
      expect(report.issues.single.aspect, ConsistencyAspect.actionCapability);
      expect(report.issues.single.description, contains('Soul contract'));
    },
  );

  test(
    'postGenerationCheck preserves its legacy single dispatch budget',
    () async {
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
      final verifier = CharacterConsistencyVerifier(settingsStore: store);
      final cast = <ResolvedSceneCastMember>[
        ResolvedSceneCastMember(
          characterId: 'aki',
          name: 'Aki',
          role: 'lead',
          contributions: const [SceneCastContribution.action],
        ),
      ];

      final report = await verifier.postGenerationCheck(
        brief: SceneBrief(
          chapterId: 'chapter-01',
          chapterTitle: 'Chapter',
          sceneId: 'scene-01',
          sceneTitle: 'Crossroads',
          sceneSummary: 'Aki waits at the crossroads.',
        ),
        director: const SceneDirectorOutput(text: 'Aki must choose.'),
        roleOutputs: const [],
        prose: const SceneProseDraft(text: 'Aki waited.', attempt: 1),
        cast: cast,
      );

      expect(report.issues, isEmpty);
      expect(client.requests, hasLength(1));
      expect(client.requests.single.maxTokens, 4096);
    },
  );

  test('formal consistency provider failure result is fatal', () async {
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

    final future = CharacterConsistencyVerifier(settingsStore: store)
        .postGenerationCheck(
          brief: SceneBrief(
            chapterId: 'chapter-01',
            chapterTitle: 'Chapter',
            sceneId: 'scene-01',
            sceneTitle: 'Crossroads',
            sceneSummary: 'Aki waits at the crossroads.',
            formalExecution: true,
          ),
          director: const SceneDirectorOutput(text: 'Aki must choose.'),
          roleOutputs: const [],
          prose: const SceneProseDraft(text: 'Aki waited.', attempt: 1),
          cast: <ResolvedSceneCastMember>[
            ResolvedSceneCastMember(
              characterId: 'aki',
              name: 'Aki',
              role: 'lead',
              contributions: const [SceneCastContribution.action],
            ),
          ],
        );

    await expectLater(
      future,
      throwsA(
        isA<StateError>().having(
          (error) => error.toString(),
          'message',
          contains('formal character consistency provider failure'),
        ),
      ),
    );
    expect(client.requests, hasLength(1));
  });

  test(
    'no-redraw consistency failure result is fatal after complete evidence',
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

      final future = StoryGenerationRetryScope.run<Future<ConsistencyReport>>(
        policy: const StoryGenerationRetryPolicy.experimentNoContentRedraw(
          maxTotalAttempts: 1,
        ),
        onAttemptEvidence: recorded.add,
        persistAttemptEvidence: (evidence) async => durable.add(evidence),
        persistAttemptIntent: (intent) async => intents.add(intent),
        generationArmPolicy: 'character-consistency-no-redraw-test-v1',
        evidenceRunId: 'character-consistency-failure-run-v1',
        evidenceSceneId: 'scene-01',
        preparedBriefDigest:
            'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        body: () => CharacterConsistencyVerifier(settingsStore: store)
            .postGenerationCheck(
              brief: SceneBrief(
                chapterId: 'chapter-01',
                chapterTitle: 'Chapter',
                sceneId: 'scene-01',
                sceneTitle: 'Crossroads',
                sceneSummary: 'Aki waits at the crossroads.',
              ),
              director: const SceneDirectorOutput(text: 'Aki must choose.'),
              roleOutputs: const [],
              prose: const SceneProseDraft(text: 'Aki waited.', attempt: 1),
              cast: <ResolvedSceneCastMember>[
                ResolvedSceneCastMember(
                  characterId: 'aki',
                  name: 'Aki',
                  role: 'lead',
                  contributions: const [SceneCastContribution.action],
                ),
              ],
            ),
      );

      await expectLater(
        future,
        throwsA(
          isA<StateError>().having(
            (error) => error.toString(),
            'message',
            contains('formal character consistency provider failure'),
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
    'no-redraw consistency check cannot swallow evidence persistence failure',
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
              'id': 'character-consistency-response-1',
              'model': 'gpt-4.1-mini',
              'choices': <Object?>[
                <String, Object?>{
                  'message': <String, Object?>{'content': 'PASS'},
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
      final verifier = CharacterConsistencyVerifier(settingsStore: store);

      final future = StoryGenerationRetryScope.run<Future<ConsistencyReport>>(
        policy: const StoryGenerationRetryPolicy.experimentNoContentRedraw(
          maxTotalAttempts: 1,
        ),
        onAttemptEvidence: (_) {},
        persistAttemptEvidence: (_) async {
          throw StateError('evidence sink failed');
        },
        persistAttemptIntent: (_) async => null,
        generationArmPolicy: 'character-consistency-no-redraw-test-v1',
        evidenceRunId: 'character-consistency-evidence-failure-run-v1',
        evidenceSceneId: 'scene-01',
        preparedBriefDigest:
            'sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        body: () => verifier.postGenerationCheck(
          brief: SceneBrief(
            chapterId: 'chapter-01',
            chapterTitle: 'Chapter',
            sceneId: 'scene-01',
            sceneTitle: 'Crossroads',
            sceneSummary: 'Aki waits at the crossroads.',
          ),
          director: const SceneDirectorOutput(text: 'Aki must choose.'),
          roleOutputs: const [],
          prose: const SceneProseDraft(text: 'Aki waited.', attempt: 1),
          cast: <ResolvedSceneCastMember>[
            ResolvedSceneCastMember(
              characterId: 'aki',
              name: 'Aki',
              role: 'lead',
              contributions: const [SceneCastContribution.action],
            ),
          ],
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
