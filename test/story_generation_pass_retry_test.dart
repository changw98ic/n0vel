import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/llm/app_llm_canonical_hash.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/llm/app_llm_prompt_invocation.dart';
import 'package:novel_writer/app/llm/app_llm_prompt_release.dart';
import 'package:novel_writer/app/logging/app_event_log.dart';
import 'package:novel_writer/app/logging/app_event_log_storage.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/domain/prompt_language.dart';
import 'package:novel_writer/features/story_generation/data/generation_evidence_fingerprints.dart';
import 'package:novel_writer/features/story_generation/data/story_generation_pass_retry.dart';
import 'package:novel_writer/features/story_generation/data/story_prompt_registry.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/settings_contract.dart';

void main() {
  group('isRetryableStoryGenerationTransportFailure', () {
    test('returns false for successful results', () {
      const result = AppLlmChatResult.success(text: 'hello');
      expect(isRetryableStoryGenerationTransportFailure(result), isFalse);
    });

    test('returns true for network failures', () {
      const result = AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.network,
        detail: 'connection refused',
      );
      expect(isRetryableStoryGenerationTransportFailure(result), isTrue);
    });

    test('returns true for timeout failures', () {
      const result = AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.timeout,
        detail: 'timed out',
      );
      expect(isRetryableStoryGenerationTransportFailure(result), isTrue);
    });

    test('returns true for rate limited failures', () {
      const result = AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.rateLimited,
        statusCode: 429,
        detail: 'too many requests',
      );
      expect(isRetryableStoryGenerationTransportFailure(result), isTrue);
    });

    test('returns false for unauthorized failures', () {
      const result = AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.unauthorized,
        statusCode: 401,
        detail: 'bad key',
      );
      expect(isRetryableStoryGenerationTransportFailure(result), isFalse);
    });

    test('returns false for model-not-found failures', () {
      const result = AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.modelNotFound,
        statusCode: 404,
        detail: 'model missing',
      );
      expect(isRetryableStoryGenerationTransportFailure(result), isFalse);
    });

    test('returns true for server failures with retryable detail', () {
      final retryableDetails = [
        'Connection closed before full header was received',
        'Connection reset by peer',
        'Broken pipe',
        'Software caused connection abort',
        'Connection terminated',
        'Temporarily unavailable',
        'Server overloaded, please retry shortly',
        'Server error. Please try again in 30 seconds.',
        'Too many requests',
        'Rate limit exceeded',
        'Timed out',
      ];
      for (final detail in retryableDetails) {
        final result = AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.server,
          statusCode: 500,
          detail: detail,
        );
        expect(
          isRetryableStoryGenerationTransportFailure(result),
          isTrue,
          reason: 'should be retryable: "$detail"',
        );
      }
    });

    test('returns false for server failures with non-retryable detail', () {
      const result = AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.server,
        statusCode: 500,
        detail: 'internal server error',
      );
      expect(isRetryableStoryGenerationTransportFailure(result), isFalse);
    });

    test('returns true for invalid-response with retryable detail', () {
      const result = AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.invalidResponse,
        detail: 'Connection reset by peer',
      );
      expect(isRetryableStoryGenerationTransportFailure(result), isTrue);
    });

    test('returns false for invalid-response with non-retryable detail', () {
      const result = AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.invalidResponse,
        detail: 'empty body',
      );
      expect(isRetryableStoryGenerationTransportFailure(result), isFalse);
    });

    test('retryable detail matching is case-insensitive', () {
      const result = AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.server,
        statusCode: 502,
        detail: 'BROKEN PIPE',
      );
      expect(isRetryableStoryGenerationTransportFailure(result), isTrue);
    });
  });

  group('requestStoryGenerationPassWithRetry', () {
    late _SequencedFakeLlmClient fakeLlm;
    late StoryGenerationAttemptDispatcher dispatch;

    setUp(() {
      fakeLlm = _SequencedFakeLlmClient();
      dispatch = _retryDispatcher(fakeLlm, const <AppLlmChatMessage>[
        AppLlmChatMessage(role: 'user', content: 'test'),
      ]);
    });

    test('returns successful result immediately without retry', () async {
      fakeLlm.enqueue([const AppLlmChatResult.success(text: 'good result')]);

      final result = await requestStoryGenerationPassWithRetry(
        dispatch: dispatch,
        maxTransientRetries: 2,
      );

      expect(result.succeeded, isTrue);
      expect(result.text, 'good result');
      expect(fakeLlm.callCount, 1);
      expect(fakeLlm.maxTokensSeen, [AppLlmChatRequest.unlimitedMaxTokens]);
    });

    test(
      'escalates empty output but retries semantic output at the same token budget',
      () async {
        fakeLlm.enqueue([
          const AppLlmChatResult.success(text: ''),
          const AppLlmChatResult.success(text: 'still malformed'),
          const AppLlmChatResult.success(text: 'usable result'),
        ]);

        final result = await requestStoryGenerationPassWithRetry(
          dispatch: dispatch,
          initialMaxTokens: storyGenerationEditorialMaxTokens,
          shouldRetryOutput: (text) => text.contains('malformed'),
        );

        expect(result.text, 'usable result');
        expect(fakeLlm.maxTokensSeen, [4096, 8192, 8192]);
      },
    );

    test('stops semantic output retries at maxOutputRetries', () async {
      fakeLlm.enqueue([
        const AppLlmChatResult.success(text: 'still malformed 1'),
        const AppLlmChatResult.success(text: 'still malformed 2'),
        const AppLlmChatResult.success(text: 'still malformed 3'),
      ]);

      final result = await requestStoryGenerationPassWithRetry(
        dispatch: dispatch,
        shouldRetryOutput: (text) => text.contains('malformed'),
        maxOutputRetries: 2,
      );

      expect(result.text, 'still malformed 3');
      expect(fakeLlm.maxTokensSeen, [0, 0, 0]);
    });

    test('experiment no-redraw returns empty output without replay', () async {
      final evidence = <StoryGenerationAttemptEvidence>[];
      fakeLlm.enqueue([
        const AppLlmChatResult.success(
          text: '',
          providerModel: 'provider-model',
          providerResponseId: 'resp-empty',
        ),
        const AppLlmChatResult.success(text: 'would redraw content'),
      ]);

      final result = await requestStoryGenerationPassWithRetry(
        dispatch: dispatch,
        initialMaxTokens: storyGenerationEditorialMaxTokens,
        retryPolicy:
            const StoryGenerationRetryPolicy.experimentNoContentRedraw(),
        onAttemptEvidence: evidence.add,
        persistAttemptEvidence: _discardAttemptEvidence,
      );

      expect(result.succeeded, isTrue);
      expect(result.text, '');
      expect(fakeLlm.callCount, 1);
      expect(evidence, hasLength(1));
      expect(
        evidence.single.disposition,
        StoryGenerationRetryDisposition.returned,
      );
      expect(evidence.single.providerModel, 'provider-model');
      expect(evidence.single.providerResponseId, 'resp-empty');
      expect(evidence.single.responseDigest, startsWith('sha256:'));
      expect(
        evidence.single.evidenceComplete,
        isFalse,
        reason: 'the pure retry helper has no formal prompt/model identity',
      );
      expect(
        evidence.single.toBlindReviewJson(),
        isNot(contains('providerModel')),
      );
      expect(
        evidence.single.toBlindReviewJson(),
        isNot(contains('providerResponseId')),
      );
      expect(
        evidence.single.toJson().toString(),
        isNot(contains('would redraw')),
      );
    });

    test(
      'experiment no-redraw returns semantic retry output without replay',
      () async {
        final evidence = <StoryGenerationAttemptEvidence>[];
        fakeLlm.enqueue([
          const AppLlmChatResult.success(text: 'still malformed'),
          const AppLlmChatResult.success(text: 'would redraw semantics'),
        ]);

        final result = await requestStoryGenerationPassWithRetry(
          dispatch: dispatch,
          shouldRetryOutput: (text) => text.contains('malformed'),
          retryPolicy:
              const StoryGenerationRetryPolicy.experimentNoContentRedraw(),
          onAttemptEvidence: evidence.add,
          persistAttemptEvidence: _discardAttemptEvidence,
        );

        expect(result.text, 'still malformed');
        expect(fakeLlm.callCount, 1);
        expect(evidence, hasLength(1));
      },
    );

    test(
      'experiment no-redraw does not replay indeterminate failures',
      () async {
        final evidence = <StoryGenerationAttemptEvidence>[];
        fakeLlm.enqueue([
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.timeout,
            detail: 'timed out after provider may have generated text',
          ),
          const AppLlmChatResult.success(text: 'would be duplicate content'),
        ]);

        final result = await requestStoryGenerationPassWithRetry(
          dispatch: dispatch,
          maxTransientRetries: 2,
          retryPolicy:
              const StoryGenerationRetryPolicy.experimentNoContentRedraw(),
          onAttemptEvidence: evidence.add,
          persistAttemptEvidence: _discardAttemptEvidence,
        );

        expect(result.succeeded, isFalse);
        expect(result.failureKind, AppLlmFailureKind.timeout);
        expect(fakeLlm.callCount, 1);
        expect(evidence, hasLength(1));
      },
    );

    test(
      'experiment no-redraw rejects generic typed no-completion claims',
      () async {
        final evidence = <StoryGenerationAttemptEvidence>[];
        fakeLlm.enqueue([
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.rateLimited,
            statusCode: 429,
            detail: 'no provider completion was created',
            dispatchFailureDisposition:
                AppLlmDispatchFailureDisposition.confirmedNoCompletion,
          ),
          const AppLlmChatResult.success(text: 'first actual completion'),
        ]);

        final result = await requestStoryGenerationPassWithRetry(
          dispatch: dispatch,
          retryPolicy:
              const StoryGenerationRetryPolicy.experimentNoContentRedraw(
                maxNoProviderCompletionRetries: 1,
              ),
          onAttemptEvidence: evidence.add,
          persistAttemptEvidence: _discardAttemptEvidence,
        );

        expect(result.succeeded, isFalse);
        expect(result.failureKind, AppLlmFailureKind.rateLimited);
        expect(fakeLlm.callCount, 1);
        expect(evidence.map((entry) => entry.disposition), [
          StoryGenerationRetryDisposition.returned,
        ]);
        expect(
          evidence.first.dispatchFailureDisposition,
          AppLlmDispatchFailureDisposition.confirmedNoCompletion,
        );
        expect(
          evidence.first.toJson()['dispatchFailureDisposition'],
          'confirmedNoCompletion',
        );
      },
    );

    test(
      'awaits durable failure before returning a no-redraw result',
      () async {
        final evidence = <StoryGenerationAttemptEvidence>[];
        final failedPersistenceStarted = Completer<void>();
        final releaseFailedPersistence = Completer<void>();
        fakeLlm.enqueue([
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.server,
            statusCode: 503,
            detail: 'provider boundary proved no completion',
            dispatchFailureDisposition:
                AppLlmDispatchFailureDisposition.confirmedNoCompletion,
          ),
        ]);

        var returned = false;
        final future = requestStoryGenerationPassWithRetry(
          dispatch: dispatch,
          retryPolicy:
              const StoryGenerationRetryPolicy.experimentNoContentRedraw(
                maxNoProviderCompletionRetries: 1,
              ),
          onAttemptEvidence: evidence.add,
          persistAttemptEvidence: (attempt) async {
            if (attempt.attempt == 0) {
              failedPersistenceStarted.complete();
              await releaseFailedPersistence.future;
              return;
            }
          },
        )..then((_) => returned = true);

        await failedPersistenceStarted.future;
        expect(fakeLlm.callCount, 1);
        expect(evidence, isEmpty);
        expect(returned, isFalse);

        releaseFailedPersistence.complete();
        final result = await future;
        expect(result.succeeded, isFalse);
        expect(result.failureKind, AppLlmFailureKind.server);
        expect(fakeLlm.callCount, 1);
        expect(returned, isTrue);
        expect(evidence, hasLength(1));
        expect(evidence.single.succeeded, isFalse);
      },
    );

    test(
      'free-form detail and callback cannot forge no-completion proof',
      () async {
        final evidence = <StoryGenerationAttemptEvidence>[];
        fakeLlm.enqueue([
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.invalidResponse,
            detail: 'no provider completion was created',
          ),
          const AppLlmChatResult.success(text: 'must not be requested'),
        ]);

        final result = await requestStoryGenerationPassWithRetry(
          dispatch: dispatch,
          retryPolicy:
              const StoryGenerationRetryPolicy.experimentNoContentRedraw(
                maxNoProviderCompletionRetries: 1,
              ),
          provesNoProviderCompletion: (_) => true,
          onAttemptEvidence: evidence.add,
          persistAttemptEvidence: _discardAttemptEvidence,
        );

        expect(result.succeeded, isFalse);
        expect(fakeLlm.callCount, 1);
        expect(evidence, hasLength(1));
      },
    );

    for (final statusCode in <int>[300, 400, 413]) {
      test(
        'typed no-completion does not retry ineligible HTTP $statusCode',
        () async {
          final evidence = <StoryGenerationAttemptEvidence>[];
          fakeLlm.enqueue([
            AppLlmChatResult.failure(
              failureKind: AppLlmFailureKind.server,
              statusCode: statusCode,
              detail: 'provider returned a definite non-2xx response',
              dispatchFailureDisposition:
                  AppLlmDispatchFailureDisposition.confirmedNoCompletion,
            ),
            const AppLlmChatResult.success(text: 'must not be requested'),
          ]);

          final result = await requestStoryGenerationPassWithRetry(
            dispatch: dispatch,
            retryPolicy:
                const StoryGenerationRetryPolicy.experimentNoContentRedraw(
                  maxNoProviderCompletionRetries: 1,
                ),
            provesNoProviderCompletion: (_) => true,
            onAttemptEvidence: evidence.add,
            persistAttemptEvidence: _discardAttemptEvidence,
          );

          expect(result.statusCode, statusCode);
          expect(fakeLlm.callCount, 1);
          expect(evidence, hasLength(1));
          expect(
            evidence.single.disposition,
            StoryGenerationRetryDisposition.returned,
          );
        },
      );
    }

    test('retry policy enforces a shared total attempt cap', () async {
      fakeLlm.enqueue([
        const AppLlmChatResult.success(text: ''),
        const AppLlmChatResult.success(text: 'still malformed'),
        const AppLlmChatResult.success(text: 'would exceed cap'),
      ]);

      final result = await requestStoryGenerationPassWithRetry(
        dispatch: dispatch,
        initialMaxTokens: storyGenerationEditorialMaxTokens,
        shouldRetryOutput: (text) => text.contains('malformed'),
        retryPolicy: const StoryGenerationRetryPolicy.productionAdaptive(
          maxTotalAttempts: 2,
        ),
      );

      expect(result.text, 'still malformed');
      expect(fakeLlm.maxTokensSeen, [4096, 8192]);
    });

    test('retry scope applies policy across nested callsites', () async {
      final scopedEvidence = <StoryGenerationAttemptEvidence>[];
      fakeLlm.enqueue([
        const AppLlmChatResult.success(text: 'still malformed'),
        const AppLlmChatResult.success(text: 'would redraw from nested call'),
      ]);

      final result = await StoryGenerationRetryScope.run(
        policy: const StoryGenerationRetryPolicy.experimentNoContentRedraw(),
        onAttemptEvidence: scopedEvidence.add,
        persistAttemptEvidence: _discardAttemptEvidence,
        body: () => requestStoryGenerationPassWithRetry(
          dispatch: dispatch,
          shouldRetryOutput: (text) => text.contains('malformed'),
        ),
      );

      expect(result.text, 'still malformed');
      expect(fakeLlm.callCount, 1);
      expect(scopedEvidence, hasLength(1));
    });

    test('nested callsite cannot weaken a no-redraw scope', () async {
      final scopedEvidence = <StoryGenerationAttemptEvidence>[];
      fakeLlm.enqueue([
        const AppLlmChatResult.success(text: 'still malformed'),
        const AppLlmChatResult.success(text: 'must not be redrawn'),
      ]);

      final result = await StoryGenerationRetryScope.run(
        policy: const StoryGenerationRetryPolicy.experimentNoContentRedraw(),
        onAttemptEvidence: scopedEvidence.add,
        persistAttemptEvidence: _discardAttemptEvidence,
        body: () => requestStoryGenerationPassWithRetry(
          dispatch: dispatch,
          shouldRetryOutput: (text) => text.contains('malformed'),
          retryPolicy: const StoryGenerationRetryPolicy.productionAdaptive(),
        ),
      );

      expect(result.text, 'still malformed');
      expect(fakeLlm.callCount, 1);
      expect(scopedEvidence, hasLength(1));
    });

    test(
      'no-redraw policy fails closed before dispatch without evidence',
      () async {
        fakeLlm.enqueue([
          const AppLlmChatResult.success(text: 'must not call'),
        ]);

        await expectLater(
          requestStoryGenerationPassWithRetry(
            dispatch: dispatch,
            retryPolicy:
                const StoryGenerationRetryPolicy.experimentNoContentRedraw(),
          ),
          throwsStateError,
        );

        expect(fakeLlm.callCount, 0);
      },
    );

    test(
      'caller recorder cannot replace scoped no-redraw evidence recorder',
      () async {
        final callerEvidence = <StoryGenerationAttemptEvidence>[];
        fakeLlm.enqueue([
          const AppLlmChatResult.success(text: 'must not call'),
        ]);

        await expectLater(
          StoryGenerationRetryScope.run(
            policy:
                const StoryGenerationRetryPolicy.experimentNoContentRedraw(),
            body: () => requestStoryGenerationPassWithRetry(
              dispatch: dispatch,
              onAttemptEvidence: callerEvidence.add,
            ),
          ),
          throwsStateError,
        );

        expect(fakeLlm.callCount, 0);
        expect(callerEvidence, isEmpty);
      },
    );

    test(
      'no-redraw policy fails closed without durable attempt persistence',
      () async {
        final evidence = <StoryGenerationAttemptEvidence>[];
        fakeLlm.enqueue([
          const AppLlmChatResult.success(text: 'must not call'),
        ]);

        await expectLater(
          requestStoryGenerationPassWithRetry(
            dispatch: dispatch,
            retryPolicy:
                const StoryGenerationRetryPolicy.experimentNoContentRedraw(),
            onAttemptEvidence: evidence.add,
          ),
          throwsA(
            isA<StoryGenerationEvidencePreflightFailure>().having(
              (error) => error.message,
              'message',
              contains('durable attempt evidence persister'),
            ),
          ),
        );

        expect(fakeLlm.callCount, 0);
        expect(evidence, isEmpty);
      },
    );

    test(
      'scoped and caller evidence recorders both receive attempts',
      () async {
        final scopedEvidence = <StoryGenerationAttemptEvidence>[];
        final callerEvidence = <StoryGenerationAttemptEvidence>[];
        fakeLlm.enqueue([const AppLlmChatResult.success(text: 'sampled')]);

        final result = await StoryGenerationRetryScope.run(
          policy: const StoryGenerationRetryPolicy.experimentNoContentRedraw(),
          onAttemptEvidence: scopedEvidence.add,
          persistAttemptEvidence: _discardAttemptEvidence,
          body: () => requestStoryGenerationPassWithRetry(
            dispatch: dispatch,
            onAttemptEvidence: callerEvidence.add,
          ),
        );

        expect(result.text, 'sampled');
        expect(scopedEvidence, hasLength(1));
        expect(callerEvidence, hasLength(1));
      },
    );

    test('starts editorial retries at 4096 and can escalate to 8192', () async {
      fakeLlm.enqueue([
        const AppLlmChatResult.success(text: 'draft truncated，'),
        const AppLlmChatResult.success(text: 'complete draft'),
      ]);

      final result = await requestStoryGenerationPassWithRetry(
        dispatch: dispatch,
        initialMaxTokens: storyGenerationEditorialMaxTokens,
      );

      expect(result.text, 'complete draft');
      expect(fakeLlm.maxTokensSeen, [4096, 8192]);
    });

    test(
      'retries on retryable failure and succeeds on second attempt',
      () async {
        fakeLlm.enqueue([
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.network,
            detail: 'connection refused',
          ),
          const AppLlmChatResult.success(text: 'recovered'),
        ]);

        final result = await requestStoryGenerationPassWithRetry(
          dispatch: dispatch,
          maxTransientRetries: 2,
        );

        expect(result.succeeded, isTrue);
        expect(result.text, 'recovered');
        expect(fakeLlm.callCount, 2);
      },
    );

    test('retries up to max retries then returns last failure', () async {
      fakeLlm.enqueue([
        const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.timeout,
          detail: 'timed out',
        ),
        const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.network,
          detail: 'connection reset',
        ),
        const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.timeout,
          detail: 'timed out again',
        ),
      ]);

      final result = await requestStoryGenerationPassWithRetry(
        dispatch: dispatch,
        maxTransientRetries: 2,
      );

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.timeout);
      expect(result.detail, 'timed out again');
      expect(fakeLlm.callCount, 3);
    });

    test('does not retry on non-retryable failure', () async {
      fakeLlm.enqueue([
        const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.unauthorized,
          statusCode: 401,
          detail: 'bad key',
        ),
      ]);

      final result = await requestStoryGenerationPassWithRetry(
        dispatch: dispatch,
        maxTransientRetries: 2,
      );

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.unauthorized);
      expect(fakeLlm.callCount, 1);
    });

    test('does not retry on model-not-found failure', () async {
      fakeLlm.enqueue([
        const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.modelNotFound,
          statusCode: 404,
          detail: 'model missing',
        ),
      ]);

      final result = await requestStoryGenerationPassWithRetry(
        dispatch: dispatch,
        maxTransientRetries: 2,
      );

      expect(result.succeeded, isFalse);
      expect(result.failureKind, AppLlmFailureKind.modelNotFound);
      expect(fakeLlm.callCount, 1);
    });

    test('retries on server failure with retryable detail', () async {
      fakeLlm.enqueue([
        const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.server,
          statusCode: 502,
          detail: 'Connection reset by peer',
        ),
        const AppLlmChatResult.success(text: 'ok after retry'),
      ]);

      final result = await requestStoryGenerationPassWithRetry(
        dispatch: dispatch,
        maxTransientRetries: 2,
      );

      expect(result.succeeded, isTrue);
      expect(result.text, 'ok after retry');
      expect(fakeLlm.callCount, 2);
    });

    test(
      'does not retry on server failure with non-retryable detail',
      () async {
        fakeLlm.enqueue([
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.server,
            statusCode: 500,
            detail: 'internal server error',
          ),
        ]);

        final result = await requestStoryGenerationPassWithRetry(
          dispatch: dispatch,
          maxTransientRetries: 2,
        );

        expect(result.succeeded, isFalse);
        expect(result.failureKind, AppLlmFailureKind.server);
        expect(fakeLlm.callCount, 1);
      },
    );

    test('respects maxConcurrentRequests from settings', () async {
      final completers = <Completer<AppLlmChatResult>>[
        Completer(),
        Completer(),
      ];
      var callIndex = 0;

      final blockingClient = _BlockingFakeLlmClient(() {
        final index = callIndex++;
        return completers[index].future;
      });

      final gateSettingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: blockingClient,
        eventLog: AppEventLog(storage: _DiscardingAppEventLogStorage()),
      );
      addTearDown(gateSettingsStore.dispose);
      await gateSettingsStore.save(
        providerName: 'test',
        baseUrl: 'http://localhost',
        model: 'test-model',
        apiKey: 'sk-test',
        timeout: const AppLlmTimeoutConfig.uniform(5000),
        maxConcurrentRequests: 1,
      );
      final invocation = StoryPromptRegistry.production.invocation(
        stageId: 'quality-gate',
        callSiteId: 'quality-scorer',
      );
      final resolvedVariables = _resolvedVariables(invocation.release);
      final messages = invocation.render(resolvedVariables).messages;
      final invocationEvidence = invocation.evidence(
        messages,
        resolvedVariables: resolvedVariables,
      );

      final future1 = requestFormalStoryGenerationPassWithRetry(
        settingsStore: gateSettingsStore,
        messages: messages,
        maxTransientRetries: 0,
        promptInvocation: invocation,
        promptInvocationEvidence: invocationEvidence,
      );
      final future2 = requestFormalStoryGenerationPassWithRetry(
        settingsStore: gateSettingsStore,
        messages: messages,
        maxTransientRetries: 0,
        promptInvocation: invocation,
        promptInvocationEvidence: invocationEvidence,
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(blockingClient.activeCalls, 1);

      completers[0].complete(
        const AppLlmChatResult.success(text: 'first done'),
      );
      final result1 = await future1;
      expect(result1.text, 'first done');

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(blockingClient.activeCalls, 1);

      completers[1].complete(
        const AppLlmChatResult.success(text: 'second done'),
      );
      final result2 = await future2;
      expect(result2.text, 'second done');
    });

    test('formal pass records private and blind attempt evidence', () async {
      const rawJudgeSentinel = 'RAW-JUDGE-SEED-MUST-NOT-PERSIST';
      final evaluatedArtifact = ArtifactDigest.fromUtf8String('被评价的最终正文');
      final evidence = StoryGenerationAttemptEvidenceCapture();
      fakeLlm.enqueue([
        const AppLlmChatResult.success(
          text: '正式输出',
          providerModel: 'provider-model-release',
          providerResponseId: 'resp-formal-1',
          promptTokens: 11,
          completionTokens: 7,
          totalTokens: 18,
        ),
      ]);
      final settingsStore = await _settingsStore(fakeLlm);
      addTearDown(settingsStore.dispose);
      final invocation = StoryPromptRegistry.production.invocation(
        stageId: 'quality-gate',
        callSiteId: 'quality-scorer',
      );
      final resolvedVariables = _resolvedVariables(invocation.release);
      final messages = invocation.render(resolvedVariables).messages;
      final invocationEvidence = invocation.evidence(
        messages,
        resolvedVariables: resolvedVariables,
      );

      final result = await StoryGenerationEvaluationScope.run(
        phase: StoryGenerationEvaluationPhase.quality,
        artifactText: '被评价的最终正文',
        body: () => requestFormalStoryGenerationPassWithRetry(
          settingsStore: settingsStore,
          messages: messages,
          promptInvocation: invocation,
          promptInvocationEvidence: invocationEvidence,
          evaluationFingerprintSeed: StoryGenerationEvaluationFingerprintSeed(
            artifactDigest: evaluatedArtifact,
            evaluationBundleHash: _evidenceHash('evaluation-bundle'),
            judgeInput: const <String, Object?>{
              'privatePrompt': rawJudgeSentinel,
              'rubricFocus': 'reader-agency',
            },
            rubricHash: _evidenceHash('rubric'),
            blindingPolicy: 'blind-arm-labels-v1',
          ),
          onAttemptEvidence: evidence.record,
        ),
      );

      expect(result.text, '正式输出');
      final attempt = evidence.attempts.single;
      expect(attempt.stageId, 'quality-gate');
      expect(attempt.callSiteId, 'quality-scorer');
      expect(attempt.variantId, 'zh');
      expect(attempt.generationBundleHash, invocation.generationBundleHash);
      expect(attempt.promptReleaseContentHash, invocation.release.contentHash);
      expect(
        attempt.renderedMessagesDigest,
        invocationEvidence.renderedMessagesDigest,
      );
      expect(
        attempt.resolvedVariablesDigest,
        invocationEvidence.resolvedVariablesDigest,
      );
      expect(attempt.artifactDigest?.digest, startsWith('sha256:'));
      expect(attempt.artifactDigest?.byteLength, utf8.encode('正式输出').length);
      expect(
        attempt.evaluationFingerprint?.artifactDigest.digest,
        evaluatedArtifact.digest,
      );
      expect(
        attempt.evaluationFingerprint?.artifactDigest.digest,
        isNot(attempt.artifactDigest?.digest),
      );
      final judgeBinding = Map<String, Object?>.from(
        attempt.evaluationFingerprint!.judgeInput! as Map,
      );
      expect(
        judgeBinding.keys,
        unorderedEquals(<String>[
          'evaluatedArtifactDigest',
          'semanticInputDigest',
        ]),
      );
      expect(attempt.generationFingerprint, isNull);
      expect(attempt.evaluationParserRelease, invocation.release.parserRelease);
      expect(
        attempt.evaluationPhase,
        StoryGenerationEvaluationPhase.quality,
      );
      expect(attempt.evidenceComplete, isTrue);

      final privateJson = evidence.toEnvelope().toPrivateJson();
      final blindJson = evidence.toEnvelope().toBlindReviewJson();
      expect(privateJson.toString(), contains('provider-model-release'));
      expect(privateJson.toString(), contains('resp-formal-1'));
      expect(privateJson.toString(), isNot(contains('正式输出')));
      expect(privateJson.toString(), isNot(contains(rawJudgeSentinel)));
      expect(attempt.toJson().toString(), isNot(contains(rawJudgeSentinel)));
      expect(blindJson.toString(), isNot(contains('provider-model-release')));
      expect(blindJson.toString(), isNot(contains('resp-formal-1')));
      expect(blindJson.toString(), isNot(contains('variant:zh')));
      expect(blindJson.toString(), isNot(contains('正式输出')));
      expect(blindJson, isNot(contains('attempts')));
      expect(
        blindJson.keys,
        unorderedEquals(<String>[
          'schemaVersion',
          'visibility',
          'evidenceComplete',
        ]),
      );
    });

    test(
      'formal fingerprint binds full retry caps and configured route chain',
      () async {
        fakeLlm.enqueue([
          const AppLlmChatResult.success(
            text: 'same artifact',
            providerModel: 'same-provider-echo',
          ),
          const AppLlmChatResult.success(
            text: 'same artifact',
            providerModel: 'same-provider-echo',
          ),
          const AppLlmChatResult.success(
            text: 'same artifact',
            providerModel: 'same-provider-echo',
          ),
        ]);
        final settingsStore = await _settingsStore(fakeLlm);
        addTearDown(settingsStore.dispose);
        final invocation = StoryPromptRegistry.production.invocation(
          stageId: 'quality-gate',
          callSiteId: 'quality-scorer',
        );
        final resolvedVariables = _resolvedVariables(invocation.release);
        final messages = invocation.render(resolvedVariables).messages;
        final invocationEvidence = invocation.evidence(
          messages,
          resolvedVariables: resolvedVariables,
        );

        Future<GenerationFingerprint> sample({
          required int outputRetries,
        }) async {
          final capture = StoryGenerationAttemptEvidenceCapture();
          await requestFormalStoryGenerationPassWithRetry(
            settingsStore: settingsStore,
            messages: messages,
            promptInvocation: invocation,
            promptInvocationEvidence: invocationEvidence,
            maxOutputRetries: outputRetries,
            onAttemptEvidence: capture.record,
          );
          return capture.attempts.single.generationFingerprint!;
        }

        final oneOutputRetry = await sample(outputRetries: 1);
        final twoOutputRetries = await sample(outputRetries: 2);
        expect(oneOutputRetry.retryPolicy, isNot(twoOutputRetries.retryPolicy));
        expect(oneOutputRetry.digest, isNot(twoOutputRetries.digest));

        await settingsStore.save(
          providerName: 'test-b',
          baseUrl: 'http://localhost-b',
          model: 'test-model-b',
          apiKey: 'sk-test',
          timeout: const AppLlmTimeoutConfig.uniform(5000),
          maxConcurrentRequests: 4,
        );
        final changedRoute = await sample(outputRetries: 2);
        expect(twoOutputRetries.modelRoute, isNot(changedRoute.modelRoute));
        expect(twoOutputRetries.digest, isNot(changedRoute.digest));
      },
    );

    test(
      'formal pass does not fabricate generation fingerprint without model route',
      () async {
        final evidence = StoryGenerationAttemptEvidenceCapture();
        fakeLlm.enqueue([const AppLlmChatResult.success(text: '正式输出')]);
        final settingsStore = await _settingsStore(fakeLlm);
        addTearDown(settingsStore.dispose);
        final invocation = StoryPromptRegistry.production.invocation(
          stageId: 'quality-gate',
          callSiteId: 'quality-scorer',
        );
        final resolvedVariables = _resolvedVariables(invocation.release);
        final messages = invocation.render(resolvedVariables).messages;
        final invocationEvidence = invocation.evidence(
          messages,
          resolvedVariables: resolvedVariables,
        );

        await requestFormalStoryGenerationPassWithRetry(
          settingsStore: settingsStore,
          messages: messages,
          promptInvocation: invocation,
          promptInvocationEvidence: invocationEvidence,
          onAttemptEvidence: evidence.record,
        );

        final attempt = evidence.attempts.single;
        expect(attempt.artifactDigest?.digest, startsWith('sha256:'));
        expect(attempt.generationFingerprint, isNull);
        expect(attempt.evidenceComplete, isFalse);
      },
    );

    test(
      'no-redraw formal pass rejects missing route identity before dispatch',
      () async {
        final settings = _MissingRouteSettingsContract();
        final invocation = StoryPromptRegistry.production.invocation(
          stageId: 'quality-gate',
          callSiteId: 'quality-scorer',
        );
        final variables = _resolvedVariables(invocation.release);
        final messages = invocation.render(variables).messages;

        expect(
          () => StoryGenerationRetryScope.run(
            policy: const StoryGenerationRetryPolicy.experimentNoContentRedraw(
              maxTotalAttempts: 1,
            ),
            onAttemptEvidence: (_) {},
            generationArmPolicy: 'route-preflight-test-arm-v1',
            body: () => requestFormalStoryGenerationPassWithRetry(
              settingsStore: settings,
              messages: messages,
              promptInvocation: invocation,
              promptInvocationEvidence: invocation.evidence(
                messages,
                resolvedVariables: variables,
              ),
            ),
          ),
          throwsA(isA<StoryGenerationEvidencePreflightFailure>()),
        );
        expect(settings.calls, 0);
      },
    );
  });
}

Future<void> _discardAttemptEvidence(StoryGenerationAttemptEvidence _) async {}

String _evidenceHash(String value) => AppLlmCanonicalHash.domainHash(
  'story-generation-pass-retry-test-v1',
  <String, Object?>{'value': value},
);

Future<AppSettingsStore> _settingsStore(AppLlmClient client) async {
  final store = AppSettingsStore(
    storage: InMemoryAppSettingsStorage(),
    llmClient: client,
    eventLog: AppEventLog(storage: _DiscardingAppEventLogStorage()),
  );
  await store.save(
    providerName: 'test',
    baseUrl: 'http://localhost',
    model: 'test-model',
    apiKey: 'sk-test',
    timeout: const AppLlmTimeoutConfig.uniform(5000),
    maxConcurrentRequests: 4,
  );
  return store;
}

StoryGenerationAttemptDispatcher _retryDispatcher(
  AppLlmClient client,
  List<AppLlmChatMessage> messages,
) =>
    ({
      required int maxTokens,
      required int attempt,
      required int transientRetryCount,
      required int outputRetryCount,
    }) => client.chat(
      AppLlmChatRequest(
        baseUrl: 'https://retry-policy.test',
        apiKey: 'test-credential',
        model: 'test-model',
        maxTokens: maxTokens,
        messages: messages,
      ),
    );

Map<String, Object?> _resolvedVariables(PromptRelease release) {
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

class _SequencedFakeLlmClient implements AppLlmClient {
  final List<AppLlmChatResult> _results = [];
  final List<int> maxTokensSeen = [];
  int callCount = 0;

  void enqueue(List<AppLlmChatResult> results) {
    _results.addAll(results);
  }

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    callCount += 1;
    maxTokensSeen.add(request.maxTokens);
    if (_results.isEmpty) {
      throw StateError('no more results enqueued');
    }
    return _results.removeAt(0);
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) {
    throw UnimplementedError('chatStream');
  }
}

class _BlockingFakeLlmClient implements AppLlmClient {
  _BlockingFakeLlmClient(this._onChat);
  final Future<AppLlmChatResult> Function() _onChat;
  int activeCalls = 0;

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    activeCalls += 1;
    try {
      return await _onChat();
    } finally {
      activeCalls -= 1;
    }
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) {
    throw UnimplementedError('chatStream');
  }
}

class _DiscardingAppEventLogStorage implements AppEventLogStorage {
  @override
  Future<void> write(AppEventLogEntry entry) async {}
}

final class _MissingRouteSettingsContract
    implements StoryGenerationSettingsContract {
  var calls = 0;

  @override
  PromptLanguage get promptLanguage => PromptLanguage.zh;

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
    return const AppLlmChatResult.success(
      text: 'must not dispatch',
      providerModel: 'unreachable-model',
    );
  }
}
