import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/llm/app_llm_client_contract.dart';
import 'package:novel_writer/app/llm/app_llm_client_types.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_execution_budget.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_metered_client.dart';

void main() {
  test('formal attempt returns the complete immutable call sequence', () async {
    final client = _metered(const _Client(withUsage: true));
    client.beginAttempt(trialSlotId: 'slot-1', attemptNo: 1);

    await client.chat(_request());
    await client.chat(_request());
    final snapshot = client.finishAttempt();

    expect(snapshot.calls, hasLength(2));
    expect(snapshot.calls.map((call) => call.sequenceNo), <int>[1, 2]);
    expect(
      snapshot.calls.fold<int>(0, (sum, call) => sum + call.promptTokens),
      20,
    );
    expect(
      snapshot.calls.fold<int>(0, (sum, call) => sum + call.completionTokens),
      10,
    );
  });

  test('missing provider token usage invalidates the whole attempt', () async {
    final client = _metered(const _Client(withUsage: false));
    client.beginAttempt(trialSlotId: 'slot-1', attemptNo: 1);

    await expectLater(client.chat(_request()), throwsStateError);
    expect(client.finishAttempt, throwsStateError);
  });

  test('request cannot claim a different frozen model route', () async {
    final client = _metered(const _Client(withUsage: true));
    client.beginAttempt(trialSlotId: 'slot-1', attemptNo: 1);

    await expectLater(
      client.chat(_request(model: 'fallback-model')),
      throwsStateError,
    );
    expect(client.finishAttempt, throwsStateError);
  });

  test('request cannot change frozen timeout or credential route', () async {
    final timeoutClient = _metered(const _Client(withUsage: true));
    timeoutClient.beginAttempt(trialSlotId: 'slot-1', attemptNo: 1);
    await expectLater(
      timeoutClient.chat(
        _request(timeout: const AppLlmTimeoutConfig.uniform(45000)),
      ),
      throwsStateError,
    );

    final credentialClient = _metered(const _Client(withUsage: true));
    credentialClient.beginAttempt(trialSlotId: 'slot-2', attemptNo: 1);
    await expectLater(
      credentialClient.chat(_request(apiKey: 'replacement-secret')),
      throwsStateError,
    );
  });

  test('formal attempts cannot overlap', () {
    final client = _metered(const _Client(withUsage: true));
    client.beginAttempt(trialSlotId: 'slot-1', attemptNo: 1);

    expect(
      () => client.beginAttempt(trialSlotId: 'slot-2', attemptNo: 1),
      throwsStateError,
    );
  });

  test('single dispatch awaits the physical provider terminal result', () async {
    var nowMs = 0;
    final budget = _budget(nowMs: () => nowMs, deadlineAtMs: 5);
    final inner = _DeferredClient();
    final client = _metered(inner, budget: budget);
    client.beginAttempt(trialSlotId: 'slot-single-terminal', attemptNo: 1);
    var settled = false;

    final call = client.chat(
      _request(
        maxTokens: 4096,
        physicalDispatchPolicy: AppLlmPhysicalDispatchPolicy.single,
        dispatchEvidenceNonce:
            'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ),
    );
    unawaited(
      call.then<void>(
        (_) => settled = true,
        onError: (Object _, StackTrace _) => settled = true,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(settled, isFalse);
    expect(inner.calls, 1);
    nowMs = 5;
    inner.complete(
      const AppLlmChatResult.success(
        text: 'late provider result',
        promptTokens: 10,
        completionTokens: 5,
        totalTokens: 15,
      ),
    );
    await expectLater(call, throwsA(isA<AgentEvaluationBudgetException>()));
  });

  test(
    'single capability rejection precedes budget and provider admission',
    () async {
      final inner = _UnmarkedClient();
      final budget = _budget(maxCalls: 1);
      final client = _metered(inner, budget: budget);
      client.beginAttempt(trialSlotId: 'slot-unsupported', attemptNo: 1);

      await expectLater(
        client.chat(
          _request(
            maxTokens: 4096,
            physicalDispatchPolicy: AppLlmPhysicalDispatchPolicy.single,
            dispatchEvidenceNonce:
                'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          ),
        ),
        throwsA(
          isA<AppLlmPhysicalDispatchPreflightException>().having(
            (error) => error.code,
            'code',
            'unsupported-runtime-capability',
          ),
        ),
      );

      expect(inner.calls, 0);
      expect(budget.snapshot().calls, 0);
      client.abortAttempt();
    },
  );

  test('metered failure preserves single-dispatch provenance', () async {
    const resolution = AppLlmDispatchResolution(
      endpointId: 'primary',
      baseUrl: 'https://provider.invalid/v1',
      model: 'model',
      provider: AppLlmProvider.openaiCompatible,
      isLocal: false,
      physicalDispatchPolicy: AppLlmPhysicalDispatchPolicy.single,
    );
    final budget = _budget(maxCalls: 1);
    final inner = _RecordingClient(
      result: const AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.server,
        dispatchResolution: resolution,
        dispatchFailureDisposition:
            AppLlmDispatchFailureDisposition.confirmedNoCompletion,
      ),
    );
    final client = _metered(
      inner,
      budget: budget,
      returnFailedResultAfterAccounting: true,
    );
    client.beginAttempt(trialSlotId: 'slot-provenance', attemptNo: 1);

    final result = await client.chat(
      _request(
        maxTokens: 4096,
        physicalDispatchPolicy: AppLlmPhysicalDispatchPolicy.single,
        dispatchEvidenceNonce:
            'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ),
    );

    expect(result.dispatchResolution, same(resolution));
    expect(
      result.dispatchFailureDisposition,
      AppLlmDispatchFailureDisposition.confirmedNoCompletion,
    );
    expect(client.finishAttempt().calls, hasLength(1));
  });

  group('execution-wide budget', () {
    test('multiple clients share aggregate call and token limits', () async {
      final budget = _budget(maxCalls: 1);
      final firstInner = _RecordingClient();
      final secondInner = _RecordingClient();
      final first = _metered(firstInner, budget: budget);
      final second = _metered(secondInner, budget: budget);
      first.beginAttempt(trialSlotId: 'slot-1', attemptNo: 1);
      second.beginAttempt(trialSlotId: 'slot-2', attemptNo: 1);

      await first.chat(_request(maxTokens: 5));
      await expectLater(
        second.chat(_request(maxTokens: 5)),
        throwsA(isA<AgentEvaluationBudgetException>()),
      );

      expect(firstInner.calls, 1);
      expect(secondInner.calls, 0);
      expect(budget.snapshot().calls, 1);
      expect(budget.snapshot().totalTokens, 15);
    });

    test('concurrent calls cannot race past a shared reservation', () async {
      final budget = _budget(maxCalls: 1);
      final firstInner = _RecordingClient(
        delay: const Duration(milliseconds: 5),
      );
      final secondInner = _RecordingClient(
        delay: const Duration(milliseconds: 5),
      );
      final clients = <AgentEvaluationMeteredAppLlmClient>[
        _metered(firstInner, budget: budget),
        _metered(secondInner, budget: budget),
      ];
      clients[0].beginAttempt(trialSlotId: 'slot-1', attemptNo: 1);
      clients[1].beginAttempt(trialSlotId: 'slot-2', attemptNo: 1);

      final outcomes = await Future.wait<Object>([
        for (final client in clients)
          client
              .chat(_request(maxTokens: 5))
              .then<Object>(
                (value) => value,
                onError: (Object error, StackTrace _) => error,
              ),
      ]);

      expect(outcomes.whereType<AppLlmChatResult>(), hasLength(1));
      expect(
        outcomes.whereType<AgentEvaluationBudgetException>(),
        hasLength(1),
      );
      expect(firstInner.calls + secondInner.calls, 1);
      expect(budget.snapshot().calls, 1);
    });

    test('thrown provider call permanently consumes its reservation', () async {
      final budget = _budget(maxCalls: 1);
      final failing = _metered(
        _RecordingClient(error: StateError('provider failed')),
        budget: budget,
      );
      failing.beginAttempt(trialSlotId: 'slot-1', attemptNo: 1);

      await expectLater(failing.chat(_request(maxTokens: 5)), throwsStateError);
      final failedAttempt = failing.finishAttempt();

      expect(failedAttempt.calls, hasLength(1));
      expect(failedAttempt.calls.single.succeeded, isFalse);
      expect(
        failedAttempt.calls.single.promptTokens,
        canonicalAgentEvaluationPromptTokenUpperBound(_request(maxTokens: 5)),
      );
      expect(failedAttempt.calls.single.completionTokens, 4096);

      final replacementInner = _RecordingClient();
      final replacement = _metered(replacementInner, budget: budget);
      replacement.beginAttempt(trialSlotId: 'slot-2', attemptNo: 1);
      await expectLater(
        replacement.chat(_request(maxTokens: 5)),
        throwsA(isA<AgentEvaluationBudgetException>()),
      );
      expect(replacementInner.calls, 0);
      expect(budget.snapshot().failedCalls, 1);
      expect(
        budget.snapshot().promptTokens,
        canonicalAgentEvaluationPromptTokenUpperBound(_request(maxTokens: 5)),
      );
      expect(budget.snapshot().completionTokens, 4096);
    });

    test('returned provider failure also consumes its reservation', () async {
      final budget = _budget(maxCalls: 1);
      final inner = _RecordingClient(returnFailure: true);
      final client = _metered(inner, budget: budget);
      client.beginAttempt(trialSlotId: 'slot-1', attemptNo: 1);

      await expectLater(client.chat(_request(maxTokens: 5)), throwsStateError);

      final failedAttempt = client.finishAttempt();

      expect(inner.calls, 1);
      expect(failedAttempt.calls, hasLength(1));
      expect(failedAttempt.calls.single.succeeded, isFalse);
      expect(budget.snapshot().calls, 1);
      expect(budget.snapshot().failedCalls, 1);
      expect(budget.snapshot().activeReservations, 0);
      expect(budget.snapshot().completionTokens, 4096);
    });

    test(
      'late provider failure preserves prior calls and seals conservative usage',
      () async {
        final budget = _budget(maxCalls: 2);
        final client = _metered(_FailAfterFirstClient(), budget: budget);
        client.beginAttempt(trialSlotId: 'slot-late-failure', attemptNo: 1);

        await client.chat(_request(maxTokens: 5));
        await expectLater(
          client.chat(_request(maxTokens: 5)),
          throwsStateError,
        );
        final failedAttempt = client.finishAttempt();

        expect(failedAttempt.calls.map((call) => call.sequenceNo), <int>[1, 2]);
        expect(failedAttempt.calls.map((call) => call.succeeded), <bool>[
          true,
          false,
        ]);
        expect(
          failedAttempt.calls.last.promptTokens,
          canonicalAgentEvaluationPromptTokenUpperBound(_request(maxTokens: 5)),
        );
        expect(failedAttempt.calls.last.completionTokens, 4096);
        expect(budget.snapshot().succeededCalls, 1);
        expect(budget.snapshot().failedCalls, 1);
        expect(budget.snapshot().activeReservations, 0);
      },
    );

    test(
      'provider usage outside reservation latches a budget breach',
      () async {
        final promptReservation = canonicalAgentEvaluationPromptTokenUpperBound(
          _request(maxTokens: 5),
        );
        final budget = _budget(
          maxCalls: 2,
          maxPromptTokens: 5000,
          maxTotalTokens: 100000,
          maxPromptPerCall: promptReservation,
        );
        final client = _metered(
          _RecordingClient(
            promptTokens: promptReservation + 1,
            completionTokens: 5,
          ),
          budget: budget,
        );
        client.beginAttempt(trialSlotId: 'slot-1', attemptNo: 1);

        await expectLater(
          client.chat(_request(maxTokens: 5)),
          throwsA(
            isA<AgentEvaluationBudgetException>().having(
              (error) => error.code,
              'code',
              'provider-usage-exceeded-reservation',
            ),
          ),
        );

        final snapshot = budget.snapshot();
        expect(snapshot.breached, isTrue);
        expect(snapshot.promptTokens, promptReservation + 1);
        expect(snapshot.failedCalls, 1);
      },
    );

    test('worst-case token and cost excess fail before provider', () async {
      final tokenBudget = _budget(maxCompletionTokens: 4095);
      final tokenInner = _RecordingClient();
      final tokenClient = _metered(tokenInner, budget: tokenBudget);
      tokenClient.beginAttempt(trialSlotId: 'slot-token', attemptNo: 1);
      await expectLater(
        tokenClient.chat(_request(maxTokens: 5)),
        throwsA(isA<AgentEvaluationBudgetException>()),
      );
      expect(tokenInner.calls, 0);

      final costBudget = _budget(maxCostMicrousd: 1);
      final costInner = _RecordingClient();
      final costClient = _metered(costInner, budget: costBudget);
      costClient.beginAttempt(trialSlotId: 'slot-cost', attemptNo: 1);
      await expectLater(
        costClient.chat(_request(maxTokens: 5)),
        throwsA(isA<AgentEvaluationBudgetException>()),
      );
      expect(costInner.calls, 0);
    });

    test('unknown maxTokens and expired deadline fail closed', () async {
      var nowMs = 10;
      final budget = _budget(nowMs: () => nowMs, deadlineAtMs: 10);
      final inner = _RecordingClient();
      final client = _metered(inner, budget: budget);
      client.beginAttempt(trialSlotId: 'slot-deadline', attemptNo: 1);

      await expectLater(
        client.chat(_request(maxTokens: 5)),
        throwsA(isA<AgentEvaluationBudgetException>()),
      );
      expect(inner.calls, 0);

      nowMs = 0;
      final unboundedBudget = _budget(nowMs: () => nowMs);
      final unboundedInner = _RecordingClient();
      final unbounded = _metered(unboundedInner, budget: unboundedBudget);
      unbounded.beginAttempt(trialSlotId: 'slot-unbounded', attemptNo: 1);
      await expectLater(
        unbounded.chat(_request()),
        throwsA(isA<AgentEvaluationBudgetException>()),
      );
      expect(unboundedInner.calls, 0);
    });

    test('call completing after deadline is charged and rejected', () async {
      var nowMs = 9;
      final budget = _budget(nowMs: () => nowMs, deadlineAtMs: 10);
      final inner = _RecordingClient(onCalled: () => nowMs = 10);
      final client = _metered(inner, budget: budget);
      client.beginAttempt(trialSlotId: 'slot-1', attemptNo: 1);

      await expectLater(
        client.chat(_request(maxTokens: 5)),
        throwsA(isA<AgentEvaluationBudgetException>()),
      );

      expect(inner.calls, 1);
      expect(budget.snapshot().calls, 1);
      expect(budget.snapshot().failedCalls, 1);
      expect(budget.snapshot().breached, isTrue);
    });

    test('wrong frozen price route is rejected at construction', () {
      final budget = _budget(model: 'other-model');

      expect(
        () => _metered(_RecordingClient(), budget: budget),
        throwsA(
          isA<AgentEvaluationBudgetException>().having(
            (error) => error.code,
            'code',
            'price-route-mismatch',
          ),
        ),
      );
    });

    test(
      'formal tracing mode returns conservatively metered thrown failure',
      () async {
        final request = _request(maxTokens: 5);
        final budget = _budget(maxCalls: 1);
        final client = _metered(
          _RecordingClient(error: StateError('provider failed')),
          budget: budget,
          returnFailedResultAfterAccounting: true,
        );
        client.beginAttempt(trialSlotId: 'slot-traced-failure', attemptNo: 1);

        final result = await client.chat(request);
        final failedAttempt = client.finishAttempt();

        expect(result.succeeded, isFalse);
        expect(result.failureKind, AppLlmFailureKind.network);
        expect(
          result.promptTokens,
          canonicalAgentEvaluationPromptTokenUpperBound(request),
        );
        expect(result.completionTokens, 4096);
        expect(result.totalTokens, result.promptTokens! + 4096);
        expect(failedAttempt.calls, hasLength(1));
        expect(failedAttempt.calls.single.succeeded, isFalse);
        expect(failedAttempt.calls.single.promptTokens, result.promptTokens);
        expect(
          failedAttempt.calls.single.completionTokens,
          result.completionTokens,
        );
        expect(budget.snapshot().failedCalls, 1);
      },
    );

    test('failed reservation cannot be released or finished twice', () {
      final budget = _budget(maxCalls: 1);
      final reservation = budget.reserve(
        modelRouteHash: AgentEvaluationMeteredAppLlmClient.modelRouteHashFor(
          'model',
        ),
        model: 'model',
        maxCompletionTokens: 5,
      );
      budget.finishFailure(reservation);
      final charged = budget.snapshot();

      expect(
        () => budget.finishFailure(reservation),
        throwsA(isA<AgentEvaluationBudgetException>()),
      );
      expect(budget.snapshot().snapshotHash, charged.snapshotHash);
      expect(
        () => budget.reserve(
          modelRouteHash: AgentEvaluationMeteredAppLlmClient.modelRouteHashFor(
            'model',
          ),
          model: 'model',
          maxCompletionTokens: 5,
        ),
        throwsA(isA<AgentEvaluationBudgetException>()),
      );
    });

    test('policy and accounting snapshots have canonical identities', () {
      final first = _budget();
      final second = _budget();

      expect(first.policyHash, second.policyHash);
      expect(first.policy.toCanonicalMap(), second.policy.toCanonicalMap());
      expect(first.snapshot().snapshotHash, second.snapshot().snapshotHash);
      expect(first.policyHash, matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(first.snapshot().snapshotHash, matches(RegExp(r'^[a-f0-9]{64}$')));
    });

    test('canonical prompt overflow fails before provider dispatch', () async {
      final budget = _budget(maxPromptPerCall: 1);
      final inner = _RecordingClient();
      final client = _metered(inner, budget: budget);
      client.beginAttempt(trialSlotId: 'slot-prompt', attemptNo: 1);

      await expectLater(
        client.chat(_request(maxTokens: 4096)),
        throwsA(
          isA<AgentEvaluationBudgetException>().having(
            (error) => error.code,
            'code',
            'prompt-reservation-exceeded',
          ),
        ),
      );
      expect(inner.calls, 0);
    });

    test('formal attempt call cap fails before provider dispatch', () async {
      final inner = _RecordingClient();
      final client = _metered(
        inner,
        budget: _budget(),
        maxCallsPerAttempt: 2,
        maxTokensPerAttempt: 100000,
      );
      client.beginAttempt(trialSlotId: 'slot-attempt-calls', attemptNo: 1);

      await client.chat(_request(maxTokens: 5));
      await client.chat(_request(maxTokens: 5));
      await expectLater(
        client.chat(_request(maxTokens: 5)),
        throwsA(
          isA<AgentEvaluationBudgetException>().having(
            (error) => error.code,
            'code',
            'attempt-call-limit-exceeded',
          ),
        ),
      );

      expect(inner.calls, 2);
      expect(client.finishAttempt().calls, hasLength(2));
    });

    test('concurrent calls cannot race past the attempt call cap', () async {
      final inner = _RecordingClient(delay: const Duration(milliseconds: 5));
      final client = _metered(
        inner,
        budget: _budget(maxCalls: 2),
        maxCallsPerAttempt: 1,
        maxTokensPerAttempt: 100000,
      );
      client.beginAttempt(
        trialSlotId: 'slot-attempt-concurrent-calls',
        attemptNo: 1,
      );

      final outcomes = await Future.wait<Object>([
        for (var index = 0; index < 2; index += 1)
          client
              .chat(_request(maxTokens: 5))
              .then<Object>(
                (value) => value,
                onError: (Object error, StackTrace _) => error,
              ),
      ]);

      expect(outcomes.whereType<AppLlmChatResult>(), hasLength(1));
      expect(
        outcomes.whereType<AgentEvaluationBudgetException>().single.code,
        'attempt-call-limit-exceeded',
      );
      expect(inner.calls, 1);
      expect(client.finishAttempt().calls, hasLength(1));
    });

    test(
      'formal attempt token cap reserves before provider dispatch',
      () async {
        final request = _request(maxTokens: 5);
        final nextCallReservation =
            canonicalAgentEvaluationPromptTokenUpperBound(request) + 4096;
        final inner = _RecordingClient();
        final client = _metered(
          inner,
          budget: _budget(),
          maxCallsPerAttempt: 2,
          maxTokensPerAttempt: nextCallReservation + 14,
        );
        client.beginAttempt(trialSlotId: 'slot-attempt-tokens', attemptNo: 1);

        await client.chat(request);
        await expectLater(
          client.chat(request),
          throwsA(
            isA<AgentEvaluationBudgetException>().having(
              (error) => error.code,
              'code',
              'attempt-token-limit-exceeded',
            ),
          ),
        );

        expect(inner.calls, 1);
        expect(client.finishAttempt().calls, hasLength(1));
      },
    );

    test(
      'concurrent calls reserve attempt tokens before provider dispatch',
      () async {
        final request = _request(maxTokens: 5);
        final nextCallReservation =
            canonicalAgentEvaluationPromptTokenUpperBound(request) + 4096;
        final inner = _RecordingClient(delay: const Duration(milliseconds: 5));
        final client = _metered(
          inner,
          budget: _budget(maxCalls: 2),
          maxCallsPerAttempt: 2,
          maxTokensPerAttempt: nextCallReservation + 14,
        );
        client.beginAttempt(
          trialSlotId: 'slot-attempt-concurrent-tokens',
          attemptNo: 1,
        );

        final outcomes = await Future.wait<Object>([
          for (var index = 0; index < 2; index += 1)
            client
                .chat(request)
                .then<Object>(
                  (value) => value,
                  onError: (Object error, StackTrace _) => error,
                ),
        ]);

        expect(outcomes.whereType<AppLlmChatResult>(), hasLength(1));
        expect(
          outcomes.whereType<AgentEvaluationBudgetException>().single.code,
          'attempt-token-limit-exceeded',
        );
        expect(inner.calls, 1);
        expect(client.finishAttempt().calls, hasLength(1));
      },
    );

    test('deadline bounds transport timeout and Future lifetime', () async {
      final budget = _budget(
        nowMs: () => DateTime.now().millisecondsSinceEpoch,
        deadlineAtMs: DateTime.now()
            .add(const Duration(milliseconds: 80))
            .millisecondsSinceEpoch,
      );
      final inner = _RecordingClient(delay: const Duration(milliseconds: 200));
      final client = _metered(inner, budget: budget);
      client.beginAttempt(trialSlotId: 'slot-timeout', attemptNo: 1);

      await expectLater(
        client.chat(_request(maxTokens: 4096)),
        throwsA(isA<TimeoutException>()),
      );
      expect(inner.calls, 1);
      expect(inner.lastTimeout!.receiveTimeoutMs, lessThanOrEqualTo(80));
      expect(budget.snapshot().failedCalls, 1);
    });

    test(
      'transport normalization cannot cross frozen completion cap',
      () async {
        expect(
          () => _metered(
            _RecordingClient(),
            budget: _budget(),
            frozenMaxCompletionTokens: 4095,
          ),
          throwsArgumentError,
        );
        final inner = _RecordingClient();
        final client = _metered(
          inner,
          budget: _budget(),
          frozenMaxCompletionTokens: 4096,
        );
        client.beginAttempt(trialSlotId: 'slot-normalized', attemptNo: 1);
        await expectLater(
          client.chat(_request(maxTokens: 4097)),
          throwsA(
            isA<AgentEvaluationBudgetException>().having(
              (error) => error.code,
              'code',
              'completion-normalization-exceeded',
            ),
          ),
        );
        expect(inner.calls, 0);
      },
    );

    test('sequential matrix guards share one durable release cap', () {
      final directory = Directory.systemTemp.createTempSync(
        'eval-shared-release-budget-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final journal = File('${directory.path}/execution-budget.json');
      final publicGuard = _budget(
        maxCalls: 2,
        journalFile: journal,
        budgetId: 'combined-release',
      );
      final routeHash = AgentEvaluationMeteredAppLlmClient.modelRouteHashFor(
        'model',
      );
      final publicReservation = publicGuard.reserve(
        modelRouteHash: routeHash,
        model: 'model',
        maxCompletionTokens: 4096,
        promptTokensUpperBound: 400,
      );
      publicGuard.reconcileSuccess(
        publicReservation,
        promptTokens: 10,
        completionTokens: 5,
      );

      final privateGuard = _budget(
        maxCalls: 2,
        journalFile: journal,
        budgetId: 'combined-release',
      );
      expect(privateGuard.snapshot().calls, 1);
      final privateReservation = privateGuard.reserve(
        modelRouteHash: routeHash,
        model: 'model',
        maxCompletionTokens: 4096,
        promptTokensUpperBound: 400,
      );
      privateGuard.reconcileSuccess(
        privateReservation,
        promptTokens: 12,
        completionTokens: 6,
      );

      expect(publicGuard.snapshot().calls, 2);
      expect(
        () => privateGuard.reserve(
          modelRouteHash: routeHash,
          model: 'model',
          maxCompletionTokens: 4096,
          promptTokensUpperBound: 400,
        ),
        throwsA(
          isA<AgentEvaluationBudgetException>().having(
            (error) => error.code,
            'code',
            'budget-reservation-exhausted',
          ),
        ),
      );
    });

    test(
      'durable journal retains crashed reservation across process restart',
      () async {
        final directory = Directory.systemTemp.createTempSync(
          'eval-budget-journal-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final journal = File('${directory.path}/budget.json');
        final script = File('${directory.path}/reserve.dart');
        script.writeAsStringSync('''
import 'dart:io';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_execution_budget.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_metered_client.dart';
void main(List<String> args) {
  final hash = AgentEvaluationMeteredAppLlmClient.modelRouteHashFor('model');
  final guard = AgentEvaluationExecutionBudgetGuard(
    nowMs: () => 0,
    journalFile: File(args.single),
    policy: AgentEvaluationExecutionBudgetPolicy(
      budgetId: 'durable', maxCalls: 1, maxPromptTokens: 1000,
      maxCompletionTokens: 4096, maxTotalTokens: 5096,
      maxCostMicrousd: 1000, deadlineAtMs: 100,
      routes: <AgentEvaluationBudgetRoute>[AgentEvaluationBudgetRoute(
        modelRouteHash: hash, model: 'model', maxPromptTokensPerCall: 1000,
        promptMicrousdPerMillionTokens: 100000,
        completionMicrousdPerMillionTokens: 200000,
      )],
    ),
  );
  guard.reserve(modelRouteHash: hash, model: 'model',
      maxCompletionTokens: 4096, promptTokensUpperBound: 400);
}
''');
        final child = await Process.run('dart', <String>[
          '--packages=.dart_tool/package_config.json',
          script.path,
          journal.path,
        ], workingDirectory: Directory.current.path);
        expect(child.exitCode, 0, reason: '${child.stderr}');

        final resumed = _budget(
          maxCalls: 1,
          maxPromptTokens: 1000,
          maxCompletionTokens: 4096,
          maxTotalTokens: 5096,
          maxCostMicrousd: 1000,
          maxPromptPerCall: 1000,
          journalFile: journal,
          budgetId: 'durable',
        );
        final snapshot = resumed.snapshot();
        expect(snapshot.calls, 1);
        expect(snapshot.failedCalls, 1);
        expect(snapshot.activeReservations, 0);
        expect(snapshot.promptTokens, 400);
        expect(FileStat.statSync(journal.path).mode & 0x1ff, 0x180);
        expect(
          () => resumed.reserve(
            modelRouteHash:
                AgentEvaluationMeteredAppLlmClient.modelRouteHashFor('model'),
            model: 'model',
            maxCompletionTokens: 4096,
            promptTokensUpperBound: 400,
          ),
          throwsA(isA<AgentEvaluationBudgetException>()),
        );

        expect(
          () => _budget(journalFile: journal, budgetId: 'different-policy'),
          throwsA(
            isA<AgentEvaluationBudgetException>().having(
              (error) => error.code,
              'code',
              'budget-journal-policy-mismatch',
            ),
          ),
        );
      },
    );
  });
}

AgentEvaluationMeteredAppLlmClient _metered(
  AppLlmClient inner, {
  AgentEvaluationExecutionBudgetGuard? budget,
  int? frozenMaxCompletionTokens,
  int? maxCallsPerAttempt,
  int? maxTokensPerAttempt,
  bool returnFailedResultAfterAccounting = false,
}) => AgentEvaluationMeteredAppLlmClient(
  inner: inner,
  model: 'model',
  provider: AppLlmProvider.openaiCompatible,
  baseUrl: 'https://provider.invalid/v1',
  frozenTimeout: const AppLlmTimeoutConfig.uniform(30000),
  frozenApiKey: 'secret',
  executionBudget: budget,
  frozenMaxCompletionTokens: frozenMaxCompletionTokens,
  maxCallsPerAttempt: maxCallsPerAttempt,
  maxTokensPerAttempt: maxTokensPerAttempt,
  returnFailedResultAfterAccounting: returnFailedResultAfterAccounting,
);

AppLlmChatRequest _request({
  String model = 'model',
  String apiKey = 'secret',
  AppLlmTimeoutConfig? timeout,
  int maxTokens = AppLlmChatRequest.unlimitedMaxTokens,
  AppLlmPhysicalDispatchPolicy physicalDispatchPolicy =
      AppLlmPhysicalDispatchPolicy.adaptive,
  String? dispatchEvidenceNonce,
}) => AppLlmChatRequest(
  baseUrl: 'https://provider.invalid/v1',
  apiKey: apiKey,
  model: model,
  timeout: timeout,
  maxTokens: maxTokens,
  provider: AppLlmProvider.openaiCompatible,
  messages: const <AppLlmChatMessage>[
    AppLlmChatMessage(role: 'user', content: 'test'),
  ],
  physicalDispatchPolicy: physicalDispatchPolicy,
  dispatchEvidenceNonce: dispatchEvidenceNonce,
);

final class _Client
    implements AppLlmClient, AppLlmSinglePhysicalDispatchCapability {
  const _Client({required this.withUsage});

  final bool withUsage;

  @override
  bool get supportsSinglePhysicalDispatch => true;

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async =>
      AppLlmChatResult.success(
        text: 'ok',
        promptTokens: withUsage ? 10 : null,
        completionTokens: withUsage ? 5 : null,
      );

  @override
  Stream<String> chatStream(AppLlmChatRequest request) => const Stream.empty();
}

AgentEvaluationExecutionBudgetGuard _budget({
  int maxCalls = 10,
  int maxPromptTokens = 100000,
  int maxCompletionTokens = 100000,
  int maxTotalTokens = 200000,
  int maxCostMicrousd = 100000,
  int deadlineAtMs = 100,
  int maxPromptPerCall = 10000,
  String model = 'model',
  int Function()? nowMs,
  File? journalFile,
  String budgetId = 'release-budget',
}) {
  final routeHash = AgentEvaluationMeteredAppLlmClient.modelRouteHashFor(model);
  return AgentEvaluationExecutionBudgetGuard(
    nowMs: nowMs ?? () => 0,
    journalFile: journalFile,
    policy: AgentEvaluationExecutionBudgetPolicy(
      budgetId: budgetId,
      maxCalls: maxCalls,
      maxPromptTokens: maxPromptTokens,
      maxCompletionTokens: maxCompletionTokens,
      maxTotalTokens: maxTotalTokens,
      maxCostMicrousd: maxCostMicrousd,
      deadlineAtMs: deadlineAtMs,
      routes: <AgentEvaluationBudgetRoute>[
        AgentEvaluationBudgetRoute(
          modelRouteHash: routeHash,
          model: model,
          maxPromptTokensPerCall: maxPromptPerCall,
          promptMicrousdPerMillionTokens: 100000,
          completionMicrousdPerMillionTokens: 200000,
        ),
      ],
    ),
  );
}

final class _RecordingClient
    implements AppLlmClient, AppLlmSinglePhysicalDispatchCapability {
  _RecordingClient({
    this.promptTokens = 10,
    this.completionTokens = 5,
    this.error,
    this.returnFailure = false,
    this.delay = Duration.zero,
    this.onCalled,
    this.result,
  });

  final int promptTokens;
  final int completionTokens;
  final Object? error;
  final bool returnFailure;
  final Duration delay;
  final void Function()? onCalled;
  final AppLlmChatResult? result;
  int calls = 0;
  AppLlmTimeoutConfig? lastTimeout;

  @override
  bool get supportsSinglePhysicalDispatch => true;

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    calls += 1;
    lastTimeout = request.timeout;
    onCalled?.call();
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (error case final failure?) {
      throw failure;
    }
    if (result case final fixed?) {
      return fixed;
    }
    if (returnFailure) {
      return const AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.server,
      );
    }
    return AppLlmChatResult.success(
      text: 'ok',
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: promptTokens + completionTokens,
    );
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) => const Stream.empty();
}

final class _DeferredClient
    implements AppLlmClient, AppLlmSinglePhysicalDispatchCapability {
  final Completer<AppLlmChatResult> _result = Completer<AppLlmChatResult>();
  int calls = 0;

  @override
  bool get supportsSinglePhysicalDispatch => true;

  void complete(AppLlmChatResult result) => _result.complete(result);

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) {
    calls += 1;
    return _result.future;
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) => const Stream.empty();
}

final class _UnmarkedClient implements AppLlmClient {
  int calls = 0;

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    calls += 1;
    return const AppLlmChatResult.success(text: 'must not be called');
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) => const Stream.empty();
}

final class _FailAfterFirstClient
    implements AppLlmClient, AppLlmSinglePhysicalDispatchCapability {
  var calls = 0;

  @override
  bool get supportsSinglePhysicalDispatch => true;

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    calls += 1;
    if (calls > 1) throw StateError('provider failed');
    return const AppLlmChatResult.success(
      text: 'ok',
      promptTokens: 10,
      completionTokens: 5,
      totalTokens: 15,
    );
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) => const Stream.empty();
}
