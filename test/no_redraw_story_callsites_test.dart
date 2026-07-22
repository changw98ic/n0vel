import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/llm/app_llm_prompt_invocation.dart';
import 'package:novel_writer/app/llm/app_llm_prompt_release.dart';
import 'package:novel_writer/domain/prompt_language.dart';
import 'package:novel_writer/features/story_generation/data/character_visible_context_models.dart';
import 'package:novel_writer/features/story_generation/data/role_turn_skill.dart';
import 'package:novel_writer/features/story_generation/data/scene_arbiter_skill.dart';
import 'package:novel_writer/features/story_generation/data/scene_director_orchestrator.dart';
import 'package:novel_writer/features/story_generation/data/scene_pipeline_models.dart'
    as pipeline;
import 'package:novel_writer/features/story_generation/data/scene_polish_pass.dart';
import 'package:novel_writer/features/story_generation/data/scene_review_coordinator.dart';
import 'package:novel_writer/features/story_generation/data/scene_roleplay_session_models.dart';
import 'package:novel_writer/features/story_generation/data/scene_stage_narrator.dart';
import 'package:novel_writer/features/story_generation/data/scene_state_resolver.dart';
import 'package:novel_writer/features/story_generation/data/story_generation_pass_retry.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/settings_contract.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';

void main() {
  group('no-redraw story callsites', () {
    test(
      'severe polish keeps the first successful IO sample and ignores the outer timeout',
      () async {
        const sampled = '心中一紧，眼眶一热，喉头一紧，不由得心中暗叹。';
        final settings = await _startIoSettings(
          sampled,
          delay: const Duration(milliseconds: 20),
        );

        final result = await _runNoRedraw(
          () =>
              ScenePolishPass(
                settingsStore: settings,
                polishTimeout: const Duration(milliseconds: 1),
              ).polish(
                brief: _brief(),
                editorialDraft: const pipeline.SceneEditorialDraft(
                  text: '本地草稿不得替代已抽取样本。',
                  beatCount: 1,
                  attempt: 1,
                ),
                resolvedBeats: const [],
              ),
        );
        expect(result.text, sampled);
        expect(result.clicheReport.isSevere, isTrue);
        expect(result.usedLocalFallback, isFalse);
        expect(settings.calls, 1);
      },
    );

    test(
      'director waits for the live IO request instead of abandoning it at the outer timeout',
      () async {
        const response =
            '目标：保留活跃请求的完成结果\n'
            '冲突：外层时限不能伪造失败\n'
            '推进：等待唯一一次物理请求\n'
            '约束：不得发起第二次内容抽取';
        final settings = await _startIoSettings(
          response,
          delay: const Duration(milliseconds: 20),
        );

        final output = await _runNoRedraw(
          () => SceneDirectorOrchestrator(
            settingsStore: settings,
            requestTimeout: const Duration(milliseconds: 1),
          ).run(brief: _brief(), cast: const []),
        );
        expect(output.text, contains('保留活跃请求的完成结果'));
        expect(settings.calls, 1);
      },
    );

    test(
      'empty beat parsing waits for the live request then fails without redispatch',
      () async {
        final settings = await _startIoSettings(
          '这不是合法的场景拍格式',
          delay: const Duration(milliseconds: 20),
        );
        final resolver = SceneStateResolver(
          settingsStore: settings,
          formalRequestTimeout: const Duration(milliseconds: 1),
        );

        await expectLater(
          _runNoRedraw(
            () => resolver.resolve(
              taskCard: pipeline.SceneTaskCard(
                brief: _brief(formalExecution: true),
                cast: const [],
              ),
              roleTurns: const [],
              capsules: const [],
            ),
          ),
          throwsA(
            predicate<Object>(
              (error) => error.toString().contains('produced no valid beats'),
            ),
          ),
        );
        expect(settings.calls, 1);
      },
    );

    test(
      'malformed review output fails without remote format repair',
      () async {
        final settings = await _startIoSettings('决定：X\n原因：格式错误。');

        await expectLater(
          _runNoRedraw(
            () => SceneReviewCoordinator(settingsStore: settings).review(
              brief: _brief(),
              director: const SceneDirectorOutput(text: '导演计划'),
              roleOutputs: const [],
              prose: const SceneProseDraft(text: '原始正文', attempt: 1),
            ),
          ),
          throwsA(
            predicate<Object>(
              (error) => error.toString().contains(
                'format repair redispatch is forbidden',
              ),
            ),
          ),
        );
        expect(settings.calls, 1);
      },
    );

    test(
      'malformed role turn hard-fails after one sample without synthesized turn state',
      () async {
        final settings = await _startIoSettings(
          '意图：守住门口\n'
          '可见动作：柳溪按住门闩\n'
          '对白：先别开门\n'
          '内心：我必须确认门外是谁。',
        );
        SceneRoleplayTurn? returnedTurn;

        await expectLater(
          _runNoRedraw(() async {
            returnedTurn = await BasicRoleTurnSkill(
              settingsStore: settings,
            ).runTurn(context: _visibleContext(), round: 1);
            return returnedTurn!;
          }),
          throwsA(
            predicate<Object>(
              (error) => error.toString().contains(
                'no-redraw role turn output was malformed',
              ),
            ),
          ),
        );

        expect(settings.calls, 1);
        expect(returnedTurn, isNull);
      },
    );

    test(
      'malformed arbitration hard-fails after one sample without synthesized public state',
      () async {
        final settings = await _startIoSettings('仲裁：门外脚步继续逼近');
        const turn = SceneRoleplayTurn(
          round: 1,
          characterId: 'character-liuxi',
          name: '柳溪',
          intent: '守住门口',
          visibleAction: '按住门闩',
          dialogue: '先别开门',
          innerState: '必须确认门外是谁。',
          taboo: '',
          rawText: 'fixture turn',
          proseFragment: '柳溪按住门闩。',
        );
        SceneRoleplayArbitration? returnedArbitration;

        await expectLater(
          _runNoRedraw(() async {
            returnedArbitration =
                await BasicSceneArbiterSkill(settingsStore: settings).arbitrate(
                  sceneTitle: '仓库门外',
                  previousPublicState: '柳溪被困在仓库里',
                  round: 1,
                  roundTurns: const <SceneRoleplayTurn>[turn],
                  transcript: const <SceneRoleplayTurn>[turn],
                );
            return returnedArbitration!;
          }),
          throwsA(
            predicate<Object>(
              (error) => error.toString().contains(
                'no-redraw scene arbitration output was malformed',
              ),
            ),
          ),
        );

        expect(settings.calls, 1);
        expect(returnedArbitration, isNull);
      },
    );

    test('incomplete evidence is fatal at every no-redraw callsite', () async {
      final cases = <String, Future<Object?> Function(_TestSettings)>{
        'polish': (settings) => ScenePolishPass(settingsStore: settings).polish(
          brief: _brief(),
          editorialDraft: const pipeline.SceneEditorialDraft(
            text: '原稿',
            beatCount: 1,
            attempt: 1,
          ),
          resolvedBeats: const [],
        ),
        'director': (settings) => SceneDirectorOrchestrator(
          settingsStore: settings,
        ).run(brief: _brief(), cast: const []),
        'stage narrator': (settings) =>
            SceneStageNarrator(settingsStore: settings).generate(
              taskCard: pipeline.SceneTaskCard(brief: _brief(), cast: const []),
              director: const SceneDirectorOutput(text: '导演计划'),
              roleOutputs: const [],
              roleTurns: const [],
              retrievalCapsules: const [],
            ),
        'beat resolver': (settings) =>
            SceneStateResolver(settingsStore: settings).resolve(
              taskCard: pipeline.SceneTaskCard(brief: _brief(), cast: const []),
              roleTurns: const [],
              capsules: const [],
            ),
      };

      for (final entry in cases.entries) {
        final settings = _TestSettings((_) {
          // The missing provider echo makes the generation fingerprint
          // impossible to derive even though the completion itself succeeds.
          return switch (entry.key) {
            'director' => const AppLlmChatResult.success(
              text: '目标：a\n冲突：b\n推进：c\n约束：d',
            ),
            'beat resolver' => const AppLlmChatResult.success(
              text: '[动作] @actor 推门而入',
            ),
            _ => const AppLlmChatResult.success(text: '雨水沿着窗框落下。'),
          };
        });

        await expectLater(
          _runNoRedraw(() => entry.value(settings)),
          throwsA(isA<StoryGenerationEvidenceIntegrityFailure>()),
          reason: entry.key,
        );
        expect(settings.calls, 1, reason: entry.key);
      }
    });

    test(
      'route without provider-boundary receipt persists incomplete then fails',
      () async {
        final persisted = <StoryGenerationAttemptEvidence>[];
        final settings = _TestSettings(
          (_) => const AppLlmChatResult.success(
            text: '目标：a\n冲突：b\n推进：c\n约束：d',
            providerModel: 'test-model',
            providerResponseId: 'synthetic-wrapper-result',
          ),
          attachProviderBoundaryReceipt: false,
        );

        await expectLater(
          _runNoRedraw(
            () => SceneDirectorOrchestrator(
              settingsStore: settings,
            ).run(brief: _brief(), cast: const []),
            persistAttemptEvidence: (evidence) async {
              persisted.add(evidence);
            },
          ),
          throwsA(isA<StoryGenerationEvidenceIntegrityFailure>()),
        );

        expect(settings.calls, 1);
        expect(persisted, hasLength(1));
        expect(persisted.single.observedDispatchResolutionHash, isNotNull);
        expect(persisted.single.providerBoundaryReceiptHash, isNull);
        expect(persisted.single.providerBoundaryReceiptRequired, isTrue);
        expect(persisted.single.providerBoundaryReceiptVerified, isFalse);
        expect(persisted.single.evidenceComplete, isFalse);
      },
    );

    final mismatchedReceipts = <String, AppLlmProviderBoundaryReceipt>{
      'contract': const _TestProviderBoundaryReceipt(
        contractValue: 'app-llm-provider-boundary-receipt-v0',
      ),
      'count': const _TestProviderBoundaryReceipt(dispatchCount: 2),
      'base URL': const _TestProviderBoundaryReceipt(
        baseUrl: 'http://other-provider.local',
      ),
      'model': const _TestProviderBoundaryReceipt(model: 'other-model'),
      'provider': const _TestProviderBoundaryReceipt(
        provider: AppLlmProvider.anthropic,
      ),
      'transport origin': const _TestProviderBoundaryReceipt(
        endpoint: 'http://other-provider.local/chat/completions',
      ),
      'transport path': const _TestProviderBoundaryReceipt(
        endpoint: 'http://test-provider.local/v1/chat/completions',
      ),
    };
    for (final entry in mismatchedReceipts.entries) {
      test('provider receipt ${entry.key} mismatch fails closed', () async {
        final persisted = <StoryGenerationAttemptEvidence>[];
        final settings = _TestSettings(
          (_) => const AppLlmChatResult.success(
            text: '目标：a\n冲突：b\n推进：c\n约束：d',
            providerModel: 'test-model',
            providerResponseId: 'mismatched-receipt-result',
          ),
          providerBoundaryReceipt: entry.value,
        );

        await expectLater(
          _runNoRedraw(
            () => SceneDirectorOrchestrator(
              settingsStore: settings,
            ).run(brief: _brief(), cast: const []),
            persistAttemptEvidence: (evidence) async {
              persisted.add(evidence);
            },
          ),
          throwsA(isA<StoryGenerationEvidenceIntegrityFailure>()),
        );

        expect(settings.calls, 1);
        expect(persisted, hasLength(1));
        expect(persisted.single.providerBoundaryReceiptHash, isNotNull);
        expect(persisted.single.providerBoundaryReceiptVerified, isFalse);
        expect(persisted.single.evidenceComplete, isFalse);
      });
    }

    test(
      'evidence and prompt failures propagate even when formal evaluation is off',
      () async {
        final missingRoute = _MissingRouteSettings();
        await expectLater(
          _runNoRedraw(
            () => ScenePolishPass(settingsStore: missingRoute).polish(
              brief: _brief(),
              editorialDraft: const pipeline.SceneEditorialDraft(
                text: '原稿',
                beatCount: 1,
                attempt: 1,
              ),
              resolvedBeats: const [],
            ),
          ),
          throwsA(isA<StoryGenerationEvidencePreflightFailure>()),
        );
        expect(missingRoute.calls, 0);

        final promptFailure = _TestSettings(
          (_) => throw StateError('prompt authority preflight rejected'),
        );
        await expectLater(
          _runNoRedraw(
            () => SceneDirectorOrchestrator(
              settingsStore: promptFailure,
            ).run(brief: _brief(), cast: const []),
          ),
          throwsA(
            predicate<Object>(
              (error) => error.toString().contains(
                'prompt authority preflight rejected',
              ),
            ),
          ),
        );

        final persistenceFailure = _TestSettings(
          (_) => const AppLlmChatResult.success(
            text: '雨落在封闭的站台上。',
            providerModel: 'test-model',
          ),
        );
        await expectLater(
          _runNoRedraw(
            () =>
                SceneStageNarrator(settingsStore: persistenceFailure).generate(
                  taskCard: pipeline.SceneTaskCard(
                    brief: _brief(),
                    cast: const [],
                  ),
                  director: const SceneDirectorOutput(text: '导演计划'),
                  roleOutputs: const [],
                  roleTurns: const [],
                  retrievalCapsules: const [],
                ),
            persistAttemptEvidence: (_) async {
              throw StateError('durable evidence preflight rejected');
            },
          ),
          throwsA(
            predicate<Object>(
              (error) => error.toString().contains(
                'durable evidence preflight rejected',
              ),
            ),
          ),
        );
      },
    );

    test('local-only exits cannot masquerade as no-redraw evidence', () async {
      final settings = _TestSettings(
        (_) => throw StateError('provider must not be reached'),
      );

      final calls = <Future<Object?> Function()>[
        () => ScenePolishPass(settingsStore: settings).polish(
          brief: _brief(metadata: const {'localPolishOnly': true}),
          editorialDraft: const pipeline.SceneEditorialDraft(
            text: '原稿',
            beatCount: 1,
            attempt: 1,
          ),
          resolvedBeats: const [],
        ),
        () => SceneDirectorOrchestrator(settingsStore: settings).run(
          brief: _brief(metadata: const {'localDirectorOnly': true}),
          cast: const [],
        ),
        () => SceneStageNarrator(settingsStore: settings).generate(
          taskCard: pipeline.SceneTaskCard(
            brief: _brief(metadata: const {'disableStageNarrator': true}),
            cast: const [],
          ),
          director: const SceneDirectorOutput(text: '导演计划'),
          roleOutputs: const [],
          roleTurns: const [],
          retrievalCapsules: const [],
        ),
        () => SceneStateResolver(settingsStore: settings).resolve(
          taskCard: pipeline.SceneTaskCard(
            brief: _brief(
              metadata: const {'localStructuredRoleplayOnly': true},
            ),
            cast: const [],
          ),
          roleTurns: const [],
          capsules: const [],
        ),
      ];

      for (final call in calls) {
        await expectLater(
          _runNoRedraw(call),
          throwsA(isA<StoryGenerationEvidencePreflightFailure>()),
        );
      }
      expect(settings.calls, 0);
    });
  });
}

Future<T> _runNoRedraw<T>(
  Future<T> Function() body, {
  StoryGenerationAttemptEvidencePersister? persistAttemptEvidence,
}) {
  final capture = StoryGenerationAttemptEvidenceCapture();
  return StoryGenerationRetryScope.run<Future<T>>(
    policy: const StoryGenerationRetryPolicy.experimentNoContentRedraw(
      maxTotalAttempts: 1,
    ),
    onAttemptEvidence: capture.record,
    persistAttemptEvidence:
        persistAttemptEvidence ?? (StoryGenerationAttemptEvidence _) async {},
    persistAttemptIntent: (StoryGenerationAttemptIntent _) async => null,
    generationArmPolicy: 'no-redraw-callsite-adversarial-test-v1',
    evidenceRunId: 'no-redraw-callsite-adversarial-run-v1',
    evidenceSceneId: 'scene-1',
    preparedBriefDigest:
        'sha256:0000000000000000000000000000000000000000000000000000000000000000',
    body: body,
  );
}

SceneBrief _brief({
  Map<String, Object?> metadata = const {},
  bool formalExecution = false,
}) => SceneBrief(
  chapterId: 'chapter-1',
  chapterTitle: '第一章',
  sceneId: 'scene-1',
  sceneTitle: '封闭站台',
  sceneSummary: '角色在封闭站台寻找出口。',
  targetBeat: '找到第一处可验证线索。',
  formalExecution: formalExecution,
  metadata: metadata,
);

CharacterVisibleContext _visibleContext() => CharacterVisibleContext(
  characterId: 'character-liuxi',
  characterName: '柳溪',
  role: '调查记者',
  privateBriefing: '确认门外来人的身份。',
  publicSceneState: const PublicSceneState(summary: '柳溪被困在仓库里。'),
);

typedef _Responder = FutureOr<AppLlmChatResult> Function(int call);

final class _TestSettings
    implements
        StoryGenerationSettingsContract,
        StoryGenerationModelRouteIdentityProvider,
        StoryGenerationSinglePhysicalDispatchSettingsContract {
  _TestSettings(
    this._responder, {
    this.attachProviderBoundaryReceipt = true,
    this.providerBoundaryReceipt = const _TestProviderBoundaryReceipt(),
  });

  final _Responder _responder;
  final bool attachProviderBoundaryReceipt;
  final AppLlmProviderBoundaryReceipt providerBoundaryReceipt;
  static const AppLlmDispatchResolution _singleDispatchResolution =
      AppLlmDispatchResolution(
        endpointId: 'primary',
        baseUrl: 'http://test-provider.local',
        model: 'test-model',
        provider: AppLlmProvider.openaiCompatible,
        isLocal: true,
        physicalDispatchPolicy: AppLlmPhysicalDispatchPolicy.single,
      );
  var calls = 0;

  @override
  PromptLanguage get promptLanguage => PromptLanguage.zh;

  @override
  Object storyGenerationModelRouteIdentity({required String traceName}) =>
      <String, Object?>{
        'contract': 'no-redraw-callsite-test-route-v1',
        'traceName': traceName,
        'primary': const <String, Object?>{
          'provider': 'test-provider',
          'model': 'test-model',
        },
        'failover': const <Object?>[],
      };

  @override
  StoryGenerationSinglePhysicalDispatchRouteLease
  prepareStoryGenerationSinglePhysicalDispatchRoute({
    required String traceName,
  }) => _TestRouteLease(traceName);

  @override
  Future<AppLlmChatResult> requestAiCompletion({
    required List<AppLlmChatMessage> messages,
    int? maxTokens,
    String? traceName,
    Map<String, Object?> traceMetadata = const {},
    PromptReleaseRef? promptReleaseRef,
    PromptInvocationEvidence? promptInvocationEvidence,
    PromptVersion? promptVersion,
    String? stageId,
    String? callSiteId,
    String? variantId,
    String? generationBundleHash,
  }) => _dispatch();

  @override
  Future<AppLlmChatResult> requestAiCompletionSinglePhysicalDispatch({
    required List<AppLlmChatMessage> messages,
    int? maxTokens,
    required String dispatchEvidenceNonce,
    required Map<String, Object?> formalDispatchIntent,
    required Object committedIntentAuthority,
    String? traceName,
    Map<String, Object?> traceMetadata = const {},
    PromptReleaseRef? promptReleaseRef,
    PromptInvocationEvidence? promptInvocationEvidence,
    PromptVersion? promptVersion,
    String? stageId,
    String? callSiteId,
    String? variantId,
    String? generationBundleHash,
    required StoryGenerationSinglePhysicalDispatchRouteLease routeLease,
  }) async {
    final result = (await _dispatch()).withDispatchResolution(
      _singleDispatchResolution,
    );
    return attachProviderBoundaryReceipt
        ? result.withProviderBoundaryReceipt(providerBoundaryReceipt)
        : result;
  }

  Future<AppLlmChatResult> _dispatch() async {
    calls += 1;
    return _responder(calls);
  }
}

/// A real IO transport fixture: the local server gives the app client a
/// platform-private receipt, so no-redraw positive paths cannot be proven by
/// a hand-written implementation of the public receipt interface.
Future<_IoTestSettings> _startIoSettings(
  String responseText, {
  Duration delay = Duration.zero,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  unawaited(
    server.forEach((request) async {
      await utf8.decoder.bind(request).join();
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode(<String, Object?>{
            'id': 'no-redraw-io-test',
            'model': 'test-model',
            'choices': <Object?>[
              <String, Object?>{
                'message': <String, Object?>{'content': responseText},
              },
            ],
          }),
        );
      await request.response.close();
    }),
  );
  addTearDown(() => server.close(force: true));
  return _IoTestSettings('http://${server.address.host}:${server.port}/v1');
}

final class _IoTestSettings
    implements
        StoryGenerationSettingsContract,
        StoryGenerationModelRouteIdentityProvider,
        StoryGenerationSinglePhysicalDispatchSettingsContract {
  _IoTestSettings(this._baseUrl);

  final String _baseUrl;
  late final AppLlmDispatchResolution _resolution = AppLlmDispatchResolution(
    endpointId: 'io-local-primary',
    baseUrl: _baseUrl,
    model: 'test-model',
    provider: AppLlmProvider.openaiCompatible,
    isLocal: true,
    physicalDispatchPolicy: AppLlmPhysicalDispatchPolicy.single,
  );
  var calls = 0;

  @override
  PromptLanguage get promptLanguage => PromptLanguage.zh;

  @override
  Object storyGenerationModelRouteIdentity({required String traceName}) =>
      _IoTestRouteLease(traceName, _resolution).credentialFreeIdentity;

  @override
  StoryGenerationSinglePhysicalDispatchRouteLease
  prepareStoryGenerationSinglePhysicalDispatchRoute({
    required String traceName,
  }) => _IoTestRouteLease(traceName, _resolution);

  @override
  Future<AppLlmChatResult> requestAiCompletion({
    required List<AppLlmChatMessage> messages,
    int? maxTokens,
    String? traceName,
    Map<String, Object?> traceMetadata = const {},
    PromptReleaseRef? promptReleaseRef,
    PromptInvocationEvidence? promptInvocationEvidence,
    PromptVersion? promptVersion,
    String? stageId,
    String? callSiteId,
    String? variantId,
    String? generationBundleHash,
  }) => _request(messages: messages, maxTokens: maxTokens, single: false);

  @override
  Future<AppLlmChatResult> requestAiCompletionSinglePhysicalDispatch({
    required List<AppLlmChatMessage> messages,
    int? maxTokens,
    required String dispatchEvidenceNonce,
    required Map<String, Object?> formalDispatchIntent,
    required Object committedIntentAuthority,
    String? traceName,
    Map<String, Object?> traceMetadata = const {},
    PromptReleaseRef? promptReleaseRef,
    PromptInvocationEvidence? promptInvocationEvidence,
    PromptVersion? promptVersion,
    String? stageId,
    String? callSiteId,
    String? variantId,
    String? generationBundleHash,
    required StoryGenerationSinglePhysicalDispatchRouteLease routeLease,
  }) async {
    if (routeLease is! _IoTestRouteLease ||
        routeLease.traceName != traceName ||
        routeLease.resolution.endpointId != _resolution.endpointId) {
      throw StateError('unexpected single-dispatch route lease');
    }
    return _request(
      messages: messages,
      maxTokens: maxTokens,
      single: true,
      dispatchEvidenceNonce: dispatchEvidenceNonce,
    );
  }

  Future<AppLlmChatResult> _request({
    required List<AppLlmChatMessage> messages,
    required int? maxTokens,
    required bool single,
    String? dispatchEvidenceNonce,
  }) async {
    calls += 1;
    final result = await createDefaultAppLlmClient().chat(
      AppLlmChatRequest(
        baseUrl: _baseUrl,
        apiKey: '',
        model: 'test-model',
        messages: messages,
        maxTokens: maxTokens ?? AppLlmChatRequest.unlimitedMaxTokens,
        provider: AppLlmProvider.openaiCompatible,
        preferStreaming: false,
        timeout: const AppLlmTimeoutConfig.uniform(1000),
        physicalDispatchPolicy: single
            ? AppLlmPhysicalDispatchPolicy.single
            : AppLlmPhysicalDispatchPolicy.adaptive,
        dispatchEvidenceNonce: dispatchEvidenceNonce,
      ),
    );
    return result.withDispatchResolution(_resolution);
  }
}

final class _IoTestRouteLease
    implements StoryGenerationSinglePhysicalDispatchRouteLease {
  const _IoTestRouteLease(this.traceName, this.resolution);

  final String traceName;
  final AppLlmDispatchResolution resolution;

  @override
  Object get credentialFreeIdentity => <String, Object?>{
    'contract': 'no-redraw-io-test-single-route-v1',
    'traceName': traceName,
    'physicalDispatchPolicy': AppLlmPhysicalDispatchPolicy.single.name,
    'selectedEndpoint': resolution.toCredentialFreeJson(),
  };
}

final class _TestRouteLease
    implements StoryGenerationSinglePhysicalDispatchRouteLease {
  const _TestRouteLease(this.traceName);

  final String traceName;

  @override
  Object get credentialFreeIdentity => <String, Object?>{
    'contract': 'no-redraw-callsite-test-single-route-v1',
    'traceName': traceName,
    'physicalDispatchPolicy': AppLlmPhysicalDispatchPolicy.single.name,
    'selectedEndpoint': _TestSettings._singleDispatchResolution
        .toCredentialFreeJson(),
  };
}

final class _TestProviderBoundaryReceipt
    implements AppLlmProviderBoundaryReceipt {
  const _TestProviderBoundaryReceipt({
    this.contractValue = 'app-llm-provider-boundary-receipt-v1',
    this.dispatchCount = 1,
    this.baseUrl = 'http://test-provider.local',
    this.model = 'test-model',
    this.provider = AppLlmProvider.openaiCompatible,
    this.endpoint = 'http://test-provider.local/chat/completions',
  });

  final String contractValue;
  final int dispatchCount;
  final String baseUrl;
  final String model;
  final AppLlmProvider provider;
  final String endpoint;

  @override
  String get contract => contractValue;

  @override
  int get physicalDispatchCount => dispatchCount;

  @override
  String get requestedBaseUrl => baseUrl;

  @override
  String get requestedModel => model;

  @override
  AppLlmProvider get requestedProvider => provider;

  @override
  String get dispatchEvidenceNonce =>
      'sha256:0000000000000000000000000000000000000000000000000000000000000000';

  @override
  String get transportEndpoint => endpoint;

  @override
  Map<String, Object?> toCredentialFreeJson() => <String, Object?>{
    'contract': contract,
    'physicalDispatchCount': physicalDispatchCount,
    'requestedBaseUrl': requestedBaseUrl,
    'requestedModel': requestedModel,
    'requestedProvider': requestedProvider.name,
    'transportEndpoint': transportEndpoint,
    'dispatchEvidenceNonce': dispatchEvidenceNonce,
  };
}

final class _MissingRouteSettings
    implements
        StoryGenerationSettingsContract,
        StoryGenerationSinglePhysicalDispatchSettingsContract {
  var calls = 0;

  @override
  PromptLanguage get promptLanguage => PromptLanguage.zh;

  @override
  StoryGenerationSinglePhysicalDispatchRouteLease?
  prepareStoryGenerationSinglePhysicalDispatchRoute({
    required String traceName,
  }) => null;

  @override
  Future<AppLlmChatResult> requestAiCompletion({
    required List<AppLlmChatMessage> messages,
    int? maxTokens,
    String? traceName,
    Map<String, Object?> traceMetadata = const {},
    PromptReleaseRef? promptReleaseRef,
    PromptInvocationEvidence? promptInvocationEvidence,
    PromptVersion? promptVersion,
    String? stageId,
    String? callSiteId,
    String? variantId,
    String? generationBundleHash,
  }) async {
    calls += 1;
    return const AppLlmChatResult.success(text: 'unexpected');
  }

  @override
  Future<AppLlmChatResult> requestAiCompletionSinglePhysicalDispatch({
    required List<AppLlmChatMessage> messages,
    int? maxTokens,
    required String dispatchEvidenceNonce,
    required Map<String, Object?> formalDispatchIntent,
    required Object committedIntentAuthority,
    String? traceName,
    Map<String, Object?> traceMetadata = const {},
    PromptReleaseRef? promptReleaseRef,
    PromptInvocationEvidence? promptInvocationEvidence,
    PromptVersion? promptVersion,
    String? stageId,
    String? callSiteId,
    String? variantId,
    String? generationBundleHash,
    required StoryGenerationSinglePhysicalDispatchRouteLease routeLease,
  }) async {
    calls += 1;
    return const AppLlmChatResult.success(text: 'unexpected');
  }
}
