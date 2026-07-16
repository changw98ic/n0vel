import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/features/story_generation/data/formal_evaluation_policy.dart';
import 'package:novel_writer/features/story_generation/data/scene_director_orchestrator.dart';
import 'package:novel_writer/features/story_generation/data/scene_pipeline_models.dart'
    as pipeline;
import 'package:novel_writer/features/story_generation/data/scene_polish_pass.dart';
import 'package:novel_writer/features/story_generation/data/scene_roleplay_runtime.dart';
import 'package:novel_writer/features/story_generation/data/scene_stage_narrator.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';

import 'test_support/fake_app_llm_client.dart';

void main() {
  group('formal evaluation local fallback policy', () {
    test('runtime metadata overwrites every fixture local-only flag', () {
      final merged = <String, Object?>{
        for (final flag in FormalEvaluationPolicy.localFallbackFlags)
          flag: true,
        ...FormalEvaluationPolicy.runtimeMetadata(),
      };

      expect(
        merged[FormalEvaluationPolicy.metadataKey],
        FormalEvaluationPolicy.metadataValue,
      );
      for (final flag in FormalEvaluationPolicy.localFallbackFlags) {
        expect(merged[flag], isFalse, reason: flag);
      }
    });

    test('typed formal execution latch cannot be removed by metadata copy', () {
      final formal = _brief(
        metadata: const <String, Object?>{
          FormalEvaluationPolicy.metadataKey: 'fixture-overwrite',
        },
        formalExecution: true,
      );
      final replaced = formal.copyWith(
        formalExecution: false,
        metadata: const <String, Object?>{},
      );

      expect(replaced.formalExecution, isTrue);
      expect(
        FormalEvaluationPolicy.isActive(
          replaced.metadata,
          formalExecution: replaced.formalExecution,
        ),
        isTrue,
      );
    });

    test('formal execution rejects future local-only flags generically', () {
      expect(
        () => FormalEvaluationPolicy.rejectLocalFallbackRequest(
          const <String, Object?>{'localFutureStageOnly': true},
          formalExecution: true,
        ),
        throwsStateError,
      );
      expect(
        () => FormalEvaluationPolicy.rejectLocalFallbackRequest(
          const <String, Object?>{'localFutureStageOnly': true},
        ),
        returnsNormally,
      );
    });

    test(
      'injected director local-only flag is rejected before dispatch',
      () async {
        final client = FakeAppLlmClient(
          responder: (_) => const AppLlmChatResult.success(text: 'unused'),
        );
        final settings = _settings(client);
        addTearDown(settings.dispose);

        await expectLater(
          SceneDirectorOrchestrator(settingsStore: settings).run(
            brief: _brief(
              metadata: <String, Object?>{
                ...FormalEvaluationPolicy.runtimeMetadata(),
                'localDirectorOnly': true,
              },
            ),
            cast: const [],
          ),
          throwsStateError,
        );
        expect(client.requests, isEmpty);
      },
    );

    test(
      'typed formal latch rejects local director when metadata marker is gone',
      () async {
        final client = FakeAppLlmClient(
          responder: (_) => const AppLlmChatResult.success(text: 'unused'),
        );
        final settings = _settings(client);
        addTearDown(settings.dispose);

        await expectLater(
          SceneDirectorOrchestrator(settingsStore: settings).run(
            brief: _brief(
              metadata: const <String, Object?>{'localDirectorOnly': true},
              formalExecution: true,
            ),
            cast: const [],
          ),
          throwsStateError,
        );
        expect(client.requests, isEmpty);
      },
    );

    test(
      'provider failure cannot become a formal local director plan',
      () async {
        final client = FakeAppLlmClient(
          responder: (_) => const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.unauthorized,
            detail: 'denied',
          ),
        );
        final settings = _settings(client);
        addTearDown(settings.dispose);

        await expectLater(
          SceneDirectorOrchestrator(settingsStore: settings).run(
            brief: _brief(metadata: FormalEvaluationPolicy.runtimeMetadata()),
            cast: const [],
          ),
          throwsStateError,
        );
      },
    );

    test('malformed provider output cannot become formal evidence', () async {
      final client = FakeAppLlmClient(
        responder: (_) => const AppLlmChatResult.success(
          text: 'not a structured director plan',
        ),
      );
      final settings = _settings(client);
      addTearDown(settings.dispose);

      await expectLater(
        SceneDirectorOrchestrator(settingsStore: settings).run(
          brief: _brief(metadata: FormalEvaluationPolicy.runtimeMetadata()),
          cast: const [],
        ),
        throwsStateError,
      );
    });

    test('thrown timeout cannot become a formal local director plan', () async {
      final client = FakeAppLlmClient(
        responder: (_) => throw TimeoutException('provider deadline'),
      );
      final settings = _settings(client);
      addTearDown(settings.dispose);

      await expectLater(
        SceneDirectorOrchestrator(settingsStore: settings).run(
          brief: _brief(metadata: FormalEvaluationPolicy.runtimeMetadata()),
          cast: const [],
        ),
        throwsStateError,
      );
    });

    test(
      'stage narrator provider failure cannot degrade to an empty capsule',
      () async {
        final client = FakeAppLlmClient(
          responder: (_) => const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.unauthorized,
            detail: 'denied',
          ),
        );
        final settings = _settings(client);
        addTearDown(settings.dispose);
        final brief = _brief(
          metadata: FormalEvaluationPolicy.runtimeMetadata(),
        );

        await expectLater(
          SceneStageNarrator(settingsStore: settings).generate(
            taskCard: pipeline.SceneTaskCard(brief: brief, cast: const []),
            director: const SceneDirectorOutput(text: 'sealed plan'),
            roleOutputs: const [],
            roleTurns: const [],
            retrievalCapsules: const [],
          ),
          throwsStateError,
        );
      },
    );

    test(
      'typed latch makes stage narration malformed, provider, and timeout failures fatal',
      () async {
        final failures = <(String, AppLlmChatResult Function())>[
          (
            'malformed non-empty output',
            () => const AppLlmChatResult.success(text: 'ok'),
          ),
          (
            'provider failure',
            () => const AppLlmChatResult.failure(
              failureKind: AppLlmFailureKind.unauthorized,
              detail: 'denied',
            ),
          ),
          ('timeout', () => throw TimeoutException('provider deadline')),
        ];

        for (final (name, response) in failures) {
          final client = FakeAppLlmClient(responder: (_) => response());
          final settings = _settings(client);
          await expectLater(
            SceneStageNarrator(settingsStore: settings).generate(
              taskCard: pipeline.SceneTaskCard(
                brief: _brief(
                  metadata: const <String, Object?>{},
                  formalExecution: true,
                ),
                cast: const [],
              ),
              director: const SceneDirectorOutput(text: 'sealed plan'),
              roleOutputs: const [],
              roleTurns: const [],
              retrievalCapsules: const [],
            ),
            throwsStateError,
            reason: name,
          );
          if (name == 'malformed non-empty output') {
            expect(
              client.requests,
              hasLength(3),
              reason: 'formal exact parsing permits two bounded model retries',
            );
          }
          settings.dispose();
        }
      },
    );

    test(
      'formal stage narration preserves the exact four-line record',
      () async {
        const exact =
            '舞台事实：谐振器已停止震动\n'
            '环境氛围：灯管仍在轻微闪烁\n'
            '可见证据：闸刀停在最低位\n'
            '边界：不替角色决定下一步';
        final client = FakeAppLlmClient(
          responder: (_) => const AppLlmChatResult.success(text: exact),
        );
        final settings = _settings(client);
        addTearDown(settings.dispose);

        final capsule = await SceneStageNarrator(settingsStore: settings)
            .generate(
              taskCard: pipeline.SceneTaskCard(
                brief: _brief(
                  metadata: const <String, Object?>{},
                  formalExecution: true,
                ),
                cast: const [],
              ),
              director: const SceneDirectorOutput(text: 'sealed plan'),
              roleOutputs: const [],
              roleTurns: const [],
              retrievalCapsules: const [],
            );

        expect(capsule?.summary, exact);
      },
    );

    test(
      'typed latch makes role turn malformed, provider, and timeout failures fatal',
      () async {
        final failures = <(String, AppLlmChatResult Function())>[
          (
            'missing prose line must not be synthesized',
            () => const AppLlmChatResult.success(
              text:
                  '意图：稳住局面\n'
                  '可见动作：陆沉按住谐振器\n'
                  '对白：先别动\n'
                  '内心：先锁住频率。',
            ),
          ),
          (
            'provider failure',
            () => const AppLlmChatResult.failure(
              failureKind: AppLlmFailureKind.unauthorized,
              detail: 'denied',
            ),
          ),
          ('timeout', () => throw TimeoutException('provider deadline')),
        ];

        for (final (name, response) in failures) {
          final client = FakeAppLlmClient(responder: (_) => response());
          final settings = _settings(client);
          await expectLater(
            _runFormalRoleplay(settings),
            throwsStateError,
            reason: name,
          );
          settings.dispose();
        }
      },
    );

    test(
      'typed latch makes arbiter malformed, provider, and timeout failures fatal',
      () async {
        final failures = <(String, AppLlmChatResult Function())>[
          (
            'invalid closure token',
            () => const AppLlmChatResult.success(
              text:
                  '事实：闸刀已落下\n'
                  '状态：谐振器停止震动\n'
                  '压力：追兵正在靠近\n'
                  '收束：是啊',
            ),
          ),
          (
            'provider failure',
            () => const AppLlmChatResult.failure(
              failureKind: AppLlmFailureKind.unauthorized,
              detail: 'denied',
            ),
          ),
          ('timeout', () => throw TimeoutException('provider deadline')),
        ];

        for (final (name, response) in failures) {
          var requestCount = 0;
          final client = FakeAppLlmClient(
            responder: (_) {
              requestCount += 1;
              if (requestCount == 1) {
                return const AppLlmChatResult.success(text: _exactRoleTurn);
              }
              return response();
            },
          );
          final settings = _settings(client);
          await expectLater(
            _runFormalRoleplay(settings),
            throwsStateError,
            reason: name,
          );
          settings.dispose();
        }
      },
    );

    test(
      'formal role turn preserves exact five-line fields without repair',
      () async {
        var requestCount = 0;
        final client = FakeAppLlmClient(
          responder: (_) {
            requestCount += 1;
            if (requestCount == 1) {
              return const AppLlmChatResult.success(
                text:
                    '意图：他上前逼对方停手\n'
                    '可见动作：紧张地握紧拳头\n'
                    '对白：停下\n'
                    '内心：先锁住频率。\n'
                    '正文片段：陆沉上前一步，握紧了拳头。',
              );
            }
            return const AppLlmChatResult.success(text: _exactArbitration);
          },
        );
        final settings = _settings(client);
        addTearDown(settings.dispose);

        final result = await _runFormalRoleplay(settings);
        final turn = result.session.rounds.single.turns.single;

        expect(turn.intent, '他上前逼对方停手');
        expect(turn.visibleAction, '紧张地握紧拳头');
        expect(turn.proseFragment, '陆沉上前一步，握紧了拳头。');
      },
    );

    test(
      'typed latch rejects whitespace-normalized structured values',
      () async {
        final stageClient = FakeAppLlmClient(
          responder: (_) => const AppLlmChatResult.success(
            text:
                '舞台事实： 谐振器已停止震动\n'
                '环境氛围：灯管轻微闪烁\n'
                '可见证据：闸刀在最低位\n'
                '边界：只记录环境',
          ),
        );
        final stageSettings = _settings(stageClient);
        await expectLater(
          SceneStageNarrator(settingsStore: stageSettings).generate(
            taskCard: pipeline.SceneTaskCard(
              brief: _brief(
                metadata: const <String, Object?>{},
                formalExecution: true,
              ),
              cast: const [],
            ),
            director: const SceneDirectorOutput(text: 'sealed plan'),
            roleOutputs: const [],
            roleTurns: const [],
            retrievalCapsules: const [],
          ),
          throwsStateError,
        );
        expect(stageClient.requests, hasLength(3));
        stageSettings.dispose();

        final roleClient = FakeAppLlmClient(
          responder: (_) => const AppLlmChatResult.success(
            text:
                '意图： 稳住局面\n'
                '可见动作：陆沉按住谐振器\n'
                '对白：先别动\n'
                '内心：先锁住频率。\n'
                '正文片段：陆沉按住谐振器。',
          ),
        );
        final roleSettings = _settings(roleClient);
        await expectLater(_runFormalRoleplay(roleSettings), throwsStateError);
        expect(roleClient.requests, hasLength(3));
        roleSettings.dispose();

        var arbiterCalls = 0;
        final arbiterClient = FakeAppLlmClient(
          responder: (_) {
            arbiterCalls += 1;
            if (arbiterCalls == 1) {
              return const AppLlmChatResult.success(text: _exactRoleTurn);
            }
            return const AppLlmChatResult.success(
              text:
                  '事实： 闸刀已落下\n'
                  '状态：谐振器停止震动\n'
                  '压力：追兵正在靠近\n'
                  '收束：否',
            );
          },
        );
        final arbiterSettings = _settings(arbiterClient);
        await expectLater(
          _runFormalRoleplay(arbiterSettings),
          throwsStateError,
        );
        expect(arbiterClient.requests, hasLength(4));
        arbiterSettings.dispose();
      },
    );

    test(
      'final severe-cliche exhaustion cannot reuse the local draft',
      () async {
        final client = FakeAppLlmClient(
          responder: (_) =>
              const AppLlmChatResult.success(text: '心中一紧，眼眶一热，喉头一紧，不由得心中暗叹。'),
        );
        final settings = _settings(client);
        addTearDown(settings.dispose);

        await expectLater(
          ScenePolishPass(settingsStore: settings).polish(
            brief: _brief(metadata: FormalEvaluationPolicy.runtimeMetadata()),
            editorialDraft: const pipeline.SceneEditorialDraft(
              text: 'authoritative editorial draft',
              beatCount: 1,
              attempt: 1,
            ),
            resolvedBeats: const [],
          ),
          throwsStateError,
        );
        expect(client.requests, hasLength(2));
      },
    );

    test(
      'formal final polish rejects provider failure and empty output',
      () async {
        for (final response in <AppLlmChatResult>[
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.timeout,
            detail: 'deadline',
          ),
          const AppLlmChatResult.success(text: '   '),
        ]) {
          final client = FakeAppLlmClient(responder: (_) => response);
          final settings = _settings(client);
          await expectLater(
            ScenePolishPass(settingsStore: settings).polish(
              brief: _brief(
                metadata: const <String, Object?>{},
                formalExecution: true,
              ),
              editorialDraft: const pipeline.SceneEditorialDraft(
                text: 'authoritative editorial draft',
                beatCount: 1,
                attempt: 1,
              ),
              resolvedBeats: const [],
            ),
            throwsStateError,
          );
          settings.dispose();
        }
      },
    );
  });
}

const _exactRoleTurn =
    '意图：稳住局面\n'
    '可见动作：陆沉按住谐振器\n'
    '对白：先别动\n'
    '内心：先锁住频率。\n'
    '正文片段：陆沉按住谐振器，说：“先别动。”';

const _exactArbitration =
    '事实：闸刀已落下\n'
    '状态：谐振器停止震动\n'
    '压力：追兵正在靠近\n'
    '收束：否';

Future<SceneRoleplayRuntimeResult> _runFormalRoleplay(
  AppSettingsStore settings,
) => SceneRoleplayRuntime(settingsStore: settings, defaultMaxRounds: 1)
    .runSession(
      brief: _brief(metadata: const <String, Object?>{}, formalExecution: true),
      cast: [
        ResolvedSceneCastMember(
          characterId: 'luchen',
          name: '陆沉',
          role: '调音师',
          contributions: [SceneCastContribution.action],
        ),
      ],
      director: const SceneDirectorOutput(text: 'sealed plan'),
    );

AppSettingsStore _settings(FakeAppLlmClient client) =>
    AppSettingsStore(storage: InMemoryAppSettingsStorage(), llmClient: client);

SceneBrief _brief({
  required Map<String, Object?> metadata,
  bool formalExecution = false,
}) => SceneBrief(
  chapterId: 'chapter-1',
  chapterTitle: 'Chapter',
  sceneId: 'scene-1',
  sceneTitle: 'Scene',
  sceneSummary: 'A sealed evaluation scene.',
  targetBeat: 'Produce a structured plan.',
  formalExecution: formalExecution,
  metadata: metadata,
);
