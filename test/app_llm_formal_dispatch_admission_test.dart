import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/llm/app_llm_canonical_hash.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/llm/app_product_prompt_registry.dart';
import 'package:novel_writer/app/llm/app_llm_prompt_release.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/features/story_generation/data/pipeline_event_log.dart';
import 'package:novel_writer/features/story_generation/data/story_generation_pass_retry.dart';
import 'package:novel_writer/features/story_generation/data/story_prompt_registry.dart';

import 'test_support/app_llm_authorized_request.dart';

void main() {
  test(
    'formal direct dispatch never invokes delayed/isolate attack wrapper and adaptive still does',
    () async {
      var originalCalls = 0;
      var attackCalls = 0;
      final originalServer = await _startJsonServer((_) {
        originalCalls += 1;
        return _successPayload('formal-ok');
      });
      final attackServer = await _startJsonServer((_) {
        attackCalls += 1;
        return _successPayload('must-not-run');
      });
      addTearDown(() => originalServer.close(force: true));
      addTearDown(() => attackServer.close(force: true));

      final probe = _DelayedAndIsolateAttackClient(
        delegate: createDefaultAppLlmClient(),
        attackBaseUrl: _baseUrl(attackServer),
      );
      final store = await _configuredStore(originalServer, probe);
      addTearDown(store.dispose);

      const originalMessages = <AppLlmChatMessage>[
        AppLlmChatMessage(role: 'user', content: 'one legal formal request'),
      ];
      const traceName = 'formal-private-dispatch-probe';
      final nonce = _nonce(traceName);
      final result = await requestAuthorizedAiCompletionForTest(
        store,
        messages: originalMessages,
        traceName: traceName,
        singlePhysicalDispatch: true,
        maxTokens: 4096,
        dispatchEvidenceNonce: nonce,
      );
      await probe.waitForScheduledAttacks();

      expect(result.succeeded, isTrue);
      expect(result.text, 'formal-ok');
      expect(originalCalls, 1);
      expect(attackCalls, 0);
      expect(probe.formalCalls, 0);

      final receipt = result.providerBoundaryReceipt;
      expect(receipt, isNotNull);
      final expectation = _workbenchExpectation(
        server: originalServer,
        originalMessages: originalMessages,
        traceName: traceName,
        nonce: nonce,
        maxTokens: 4096,
      );
      final witness = issueAppLlmFormalDispatchWitness(
        receipt: receipt!,
        expectation: expectation,
      );
      expect(witness, isNotNull);
      expect(await _isolateTransferRejected(witness!), isTrue);
      expect(
        issueAppLlmFormalDispatchWitness(
          receipt: receipt,
          expectation: expectation,
        ),
        isNull,
      );

      final adaptive = await requestAuthorizedAiCompletionForTest(
        store,
        messages: const <AppLlmChatMessage>[
          AppLlmChatMessage(role: 'user', content: 'normal adaptive request'),
        ],
        traceName: 'adaptive-wrapper-control',
      );
      expect(adaptive.succeeded, isTrue);
      expect(originalCalls, 2);
      expect(attackCalls, 0);
      expect(probe.adaptiveCalls, 1);
    },
  );

  test('wrong witness expectation burns genuine receipt issuance', () async {
    var calls = 0;
    final server = await _startJsonServer((_) {
      calls += 1;
      return _successPayload('witness-burn');
    });
    addTearDown(() => server.close(force: true));
    final store = await _configuredStore(server, createDefaultAppLlmClient());
    addTearDown(store.dispose);

    const originalMessages = <AppLlmChatMessage>[
      AppLlmChatMessage(role: 'user', content: 'witness expectation'),
    ];
    const traceName = 'formal-witness-burn';
    final nonce = _nonce(traceName);
    final result = await requestAuthorizedAiCompletionForTest(
      store,
      messages: originalMessages,
      traceName: traceName,
      singlePhysicalDispatch: true,
      maxTokens: 4096,
      dispatchEvidenceNonce: nonce,
    );
    final receipt = result.providerBoundaryReceipt!;
    final correct = _workbenchExpectation(
      server: server,
      originalMessages: originalMessages,
      traceName: traceName,
      nonce: nonce,
      maxTokens: 4096,
    );
    final wrong = AppLlmProviderBoundaryExpectation(
      baseUrl: correct.baseUrl,
      model: correct.model,
      provider: correct.provider,
      messages: const <AppLlmChatMessage>[
        AppLlmChatMessage(role: 'user', content: 'substituted expectation'),
      ],
      maxTokens: correct.normalizedMaxTokens,
      physicalDispatchPolicy: correct.physicalDispatchPolicy,
      dispatchEvidenceNonce: correct.dispatchEvidenceNonce,
    );

    expect(
      issueAppLlmFormalDispatchWitness(receipt: receipt, expectation: wrong),
      isNull,
    );
    expect(
      issueAppLlmFormalDispatchWitness(receipt: receipt, expectation: correct),
      isNull,
    );
    expect(calls, 1);
  });

  test('sealed provider failure is durably persisted before return', () async {
    var calls = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(
      server.forEach((request) async {
        calls += 1;
        await utf8.decoder.bind(request).join();
        request.response
          ..statusCode = HttpStatus.unauthorized
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode(<String, Object?>{
              'error': <String, Object?>{
                'message': 'credential rejected at provider boundary',
              },
            }),
          );
        await request.response.close();
      }),
    );
    addTearDown(() => server.close(force: true));

    final outcomeTamper = _FormalOutcomeTamperingClient(
      createDefaultAppLlmClient(),
    );
    final store = await _configuredStore(server, outcomeTamper);
    addTearDown(store.dispose);
    final tempDir = await Directory.systemTemp.createTemp(
      'novel-writer-failure-outcome-',
    );
    final eventLog = PipelineEventLogImpl(
      jsonlPath: '${tempDir.path}/evidence.jsonl',
    );
    addTearDown(() async {
      await eventLog.dispose();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });
    final preparedBriefDigest = AppLlmCanonicalHash.domainHash(
      'formal-failure-outcome-brief-test-v1',
      tempDir.path,
    );
    final journal = await eventLog.openStoryGenerationEvidenceJournal(
      evidenceRunId: 'failure-outcome-${DateTime.now().microsecondsSinceEpoch}',
      sceneId: 'provider-failure',
      preparedBriefDigest: preparedBriefDigest,
      generationArmPolicy: 'failure-outcome-test',
    );
    final capture = StoryGenerationAttemptEvidenceCapture();
    final invocation = StoryPromptRegistry.production.invocation(
      stageId: 'quality-gate',
      callSiteId: 'quality-scorer',
    );
    final variables = _fixtureVariables(invocation.release);
    final messages = invocation.render(variables).messages;
    final invocationEvidence = invocation.evidence(
      messages,
      resolvedVariables: variables,
    );

    final result = await StoryGenerationRetryScope.run(
      policy: const StoryGenerationRetryPolicy.experimentNoContentRedraw(
        maxTotalAttempts: 1,
      ),
      onAttemptEvidence: capture.record,
      persistAttemptIntent: journal.persistIntent,
      persistAttemptEvidence: journal.persistAttempt,
      generationArmPolicy: journal.generationArmPolicy,
      evidenceRunId: journal.evidenceRunId,
      evidenceSceneId: journal.sceneId,
      preparedBriefDigest: preparedBriefDigest,
      body: () => requestFormalStoryGenerationPassWithRetry(
        settingsStore: store,
        messages: messages,
        maxTransientRetries: 0,
        promptInvocation: invocation,
        promptInvocationEvidence: invocationEvidence,
      ),
    );

    expect(result.succeeded, isFalse);
    expect(result.failureKind, AppLlmFailureKind.unauthorized);
    expect(calls, 1);
    expect(outcomeTamper.formalCalls, 0);
    expect(journal.attemptCount, 1);
    expect(capture.attempts, hasLength(1));
    final attempt = capture.attempts.single;
    expect(attempt.evidenceComplete, isTrue);
    expect(attempt.providerBoundaryReceiptVerified, isTrue);
    expect(attempt.providerOutcomeSealHash, startsWith('sha256:'));
    expect(attempt.providerOutcomeSeal?['succeeded'], isFalse);
    expect(attempt.providerOutcomeSeal?['failureKind'], 'unauthorized');
    expect(attempt.providerOutcomeSeal?['statusCode'], 401);
    expect(
      attempt.providerOutcomeSeal.toString(),
      isNot(contains('credential rejected')),
    );
    final persisted = await eventLog.readPersistedEvents();
    expect(
      persisted.where(
        (event) =>
            event.eventType == storyGenerationAttemptEvidenceRecordedEventType,
      ),
      hasLength(1),
    );
  });
}

Future<AppSettingsStore> _configuredStore(
  HttpServer server,
  AppLlmClient client,
) async {
  final store = AppSettingsStore(
    storage: InMemoryAppSettingsStorage(),
    llmClient: client,
  );
  await store.save(
    providerName: 'Local Test',
    baseUrl: _baseUrl(server),
    model: 'formal-model',
    apiKey: '',
    timeout: const AppLlmTimeoutConfig.uniform(2000),
    maxTokens: 4096,
  );
  return store;
}

AppLlmProviderBoundaryExpectation _workbenchExpectation({
  required HttpServer server,
  required List<AppLlmChatMessage> originalMessages,
  required String traceName,
  required String nonce,
  required int maxTokens,
}) {
  final invocation = AppProductPromptRegistry.current.invocation(
    stageId: 'workbench',
    callSiteId: 'rewrite',
  );
  final originalText = originalMessages
      .map((message) => message.content)
      .join('\n');
  final authorizedMessages = invocation.render(<String, Object?>{
    'taskType': traceName,
    'effectivePrompt': 'verify settings routing',
    'providerSummary': 'test provider',
    'endpointLabel': 'test endpoint',
    'styleSummary': 'none',
    'sceneSummary': 'test scene',
    'characterSummary': '',
    'worldSummary': '',
    'simulationSummary': 'none',
    'previousText': '',
    'originalText': originalText,
    'nextText': '',
  }).messages;
  return AppLlmProviderBoundaryExpectation(
    baseUrl: _baseUrl(server),
    model: 'formal-model',
    provider: AppLlmProvider.openaiCompatible,
    messages: authorizedMessages,
    maxTokens: maxTokens,
    physicalDispatchPolicy: AppLlmPhysicalDispatchPolicy.single,
    dispatchEvidenceNonce: nonce,
  );
}

String _nonce(String label) => AppLlmCanonicalHash.domainHash(
  'formal-dispatch-admission-test-v1',
  <String, Object?>{
    'label': label,
    'time': DateTime.now().microsecondsSinceEpoch,
  },
);

Map<String, Object?> _fixtureVariables(PromptRelease release) {
  final schema = release.variablesSchemaSnapshot as Map<String, Object?>;
  final properties = schema['properties']! as Map<String, Object?>;
  return <String, Object?>{
    for (final entry in properties.entries)
      entry.key: switch ((entry.value as Map<String, Object?>)['type']) {
        'string' => 'fixture=${entry.key}',
        'integer' => 1,
        'number' => 1.0,
        'boolean' => true,
        _ => throw StateError('unsupported fixture variable: ${entry.key}'),
      },
  };
}

Future<bool> _isolateTransferRejected(Object value) async {
  try {
    await Isolate.run<Object>(() => value);
    return false;
  } on Object {
    return true;
  }
}

abstract class _SingleDispatchDecorator
    implements AppLlmClient, AppLlmSinglePhysicalDispatchCapability {
  _SingleDispatchDecorator(this.delegate);

  final AppLlmClient delegate;

  @override
  bool get supportsSinglePhysicalDispatch => true;

  @override
  Stream<String> chatStream(AppLlmChatRequest request) =>
      delegate.chatStream(request);
}

final class _DelayedAndIsolateAttackClient extends _SingleDispatchDecorator {
  _DelayedAndIsolateAttackClient({
    required AppLlmClient delegate,
    required this.attackBaseUrl,
  }) : super(delegate);

  final String attackBaseUrl;
  final List<Future<void>> _scheduledAttacks = <Future<void>>[];
  int formalCalls = 0;
  int adaptiveCalls = 0;

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    if (request.physicalDispatchPolicy ==
        AppLlmPhysicalDispatchPolicy.adaptive) {
      adaptiveCalls += 1;
      return delegate.chat(request);
    }

    formalCalls += 1;
    final delayedFinished = Completer<void>();
    _scheduledAttacks.add(delayedFinished.future);
    Timer.run(() async {
      try {
        await delegate.chat(
          AppLlmChatRequest(
            baseUrl: attackBaseUrl,
            apiKey: '',
            model: request.model,
            timeout: request.timeout,
            maxTokens: request.maxTokens,
            provider: request.provider,
            messages: const <AppLlmChatMessage>[
              AppLlmChatMessage(
                role: 'user',
                content: 'delayed adaptive downgrade attack',
              ),
            ],
          ),
        );
      } finally {
        delayedFinished.complete();
      }
    });

    final isolatedAttackBaseUrl = attackBaseUrl;
    _scheduledAttacks.add(
      Future<void>.microtask(() async {
        try {
          await delegate
              .chatStream(
                AppLlmChatRequest(
                  baseUrl: isolatedAttackBaseUrl,
                  apiKey: '',
                  model: request.model,
                  timeout: request.timeout,
                  maxTokens: request.maxTokens,
                  provider: request.provider,
                  messages: const <AppLlmChatMessage>[
                    AppLlmChatMessage(
                      role: 'user',
                      content: 'microtask adaptive stream downgrade attack',
                    ),
                  ],
                ),
              )
              .toList();
        } on Object {
          // Reaching the server is the security failure under test; response
          // decoding is deliberately irrelevant to this attack probe.
        }
      }),
    );
    _scheduledAttacks.add(
      Isolate.run<void>(() async {
        final reconstructed = AppLlmChatRequest(
          baseUrl: isolatedAttackBaseUrl,
          apiKey: '',
          model: 'formal-model',
          timeout: const AppLlmTimeoutConfig.uniform(2000),
          maxTokens: 4096,
          provider: AppLlmProvider.openaiCompatible,
          messages: const <AppLlmChatMessage>[
            AppLlmChatMessage(
              role: 'user',
              content: 'isolate primitive reconstruction attack',
            ),
          ],
        );
        await createDefaultAppLlmClient().chat(reconstructed);
      }),
    );
    return delegate.chat(request);
  }

  Future<void> waitForScheduledAttacks() async {
    if (_scheduledAttacks.isEmpty) return;
    await Future.wait<void>(List<Future<void>>.of(_scheduledAttacks));
  }
}

final class _FormalOutcomeTamperingClient extends _SingleDispatchDecorator {
  _FormalOutcomeTamperingClient(super.delegate);

  int formalCalls = 0;

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    if (request.physicalDispatchPolicy == AppLlmPhysicalDispatchPolicy.single) {
      formalCalls += 1;
      return const AppLlmChatResult.success(
        text: 'wrapper-forged-success-must-not-be-observed',
      );
    }
    return delegate.chat(request);
  }
}

Future<HttpServer> _startJsonServer(
  Map<String, Object?> Function(Map<String, Object?> body) response,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  unawaited(
    server.forEach((request) async {
      final body =
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, Object?>;
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(response(body)));
      await request.response.close();
    }),
  );
  return server;
}

Map<String, Object?> _successPayload(String text) => <String, Object?>{
  'id': 'response-$text',
  'model': 'formal-model',
  'choices': <Object?>[
    <String, Object?>{
      'message': <String, Object?>{'content': text},
      'finish_reason': 'stop',
    },
  ],
  'usage': <String, Object?>{
    'prompt_tokens': 12,
    'completion_tokens': 4,
    'total_tokens': 16,
  },
};

String _baseUrl(HttpServer server) =>
    'http://${server.address.host}:${server.port}/v1';
