import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../../app/llm/app_llm_client_contract.dart';
import '../../../../app/llm/app_llm_client_types.dart';
import '../../../../app/llm/app_llm_failover_chain.dart';
import 'agent_evaluation_execution_budget.dart';
import 'agent_evaluation_manifest.dart';
import 'agent_evaluation_metered_client.dart';

enum AgentEvaluationTransportOutcomeKind {
  success,
  timeout,
  rateLimited,
  truncated,
  invalidFormat,
  duplicate,
}

final class AgentEvaluationTransportOutcome {
  const AgentEvaluationTransportOutcome({
    required this.kind,
    this.promptTokens = 10,
    this.completionTokens = 5,
    this.delay = Duration.zero,
    this.responseText,
  });

  final AgentEvaluationTransportOutcomeKind kind;
  final int promptTokens;
  final int completionTokens;
  final Duration delay;
  final String? responseText;
}

/// Loopback HTTP fault server used by the real release transport matrix.
///
/// Requests still cross the production `AppLlmClientIo` HTTP/provider adapter
/// boundary. This component controls only deterministic server behavior; it
/// never synthesizes an `AppLlmChatResult` or bypasses response parsing.
final class AgentEvaluationHttpFaultProtocol {
  AgentEvaluationHttpFaultProtocol._({
    required HttpServer server,
    required List<AgentEvaluationTransportOutcome> outcomes,
  }) : _server = server,
       _outcomes = List<AgentEvaluationTransportOutcome>.unmodifiable(outcomes);

  static Future<AgentEvaluationHttpFaultProtocol> start({
    required List<AgentEvaluationTransportOutcome> outcomes,
  }) async {
    if (outcomes.isEmpty) {
      throw ArgumentError('HTTP fault outcome matrix must not be empty');
    }
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final protocol = AgentEvaluationHttpFaultProtocol._(
      server: server,
      outcomes: outcomes,
    );
    protocol._subscription = server.listen(protocol._handle);
    return protocol;
  }

  static final String releaseHash =
      'sha256:${AgentEvaluationHashes.domainHash('agent-evaluation-http-fault-protocol-release-v2', const <String, Object?>{
        'boundary': 'loopback-http-through-production-AppLlmClientIo',
        'outcomes': <String>['success-sse-with-exact-usage', 'delayed-timeout', 'http-429', 'truncated-sse', 'invalid-json', 'duplicate-sse'],
        'successPayload': 'caller-frozen-response-text-over-real-sse-parser',
        'credentials': 'none-loopback-only',
      })}';

  final HttpServer _server;
  final List<AgentEvaluationTransportOutcome> _outcomes;
  late final StreamSubscription<HttpRequest> _subscription;
  final List<AgentEvaluationTransportOutcomeKind> _received =
      <AgentEvaluationTransportOutcomeKind>[];
  var _cursor = 0;

  String get baseUrl => 'http://${_server.address.address}:${_server.port}/v1';
  int get requestCount => _received.length;
  List<AgentEvaluationTransportOutcomeKind> get receivedOutcomes =>
      List<AgentEvaluationTransportOutcomeKind>.unmodifiable(_received);

  Future<void> close() async {
    await _subscription.cancel();
    await _server.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    if (_cursor >= _outcomes.length) {
      request.response.statusCode = HttpStatus.serviceUnavailable;
      request.response.write('{"error":{"message":"matrix exhausted"}}');
      await request.response.close();
      return;
    }
    final outcome = _outcomes[_cursor++];
    _received.add(outcome.kind);
    await utf8.decoder.bind(request).join();
    if (outcome.delay > Duration.zero) {
      await Future<void>.delayed(outcome.delay);
    }
    switch (outcome.kind) {
      case AgentEvaluationTransportOutcomeKind.timeout:
        // The caller deadline closes the socket before this response arrives.
        request.response.statusCode = HttpStatus.ok;
        request.response.write(_sse(outcome, '{"state":"late"}'));
      case AgentEvaluationTransportOutcomeKind.rateLimited:
        request.response.statusCode = HttpStatus.tooManyRequests;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          '{"error":{"message":"deterministic rate limit"}}',
        );
      case AgentEvaluationTransportOutcomeKind.truncated:
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
          charset: 'utf-8',
        );
        request.response.write('data: {"choices":[{"delta":{"content":"{');
      case AgentEvaluationTransportOutcomeKind.invalidFormat:
        request.response.statusCode = HttpStatus.ok;
        request.response.write('invalid-json');
      case AgentEvaluationTransportOutcomeKind.duplicate:
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
          charset: 'utf-8',
        );
        request.response.write(
          _sse(outcome, outcome.responseText ?? '{"state":"duplicate"}'),
        );
      case AgentEvaluationTransportOutcomeKind.success:
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
          charset: 'utf-8',
        );
        request.response.write(
          _sse(outcome, outcome.responseText ?? '{"state":"accepted"}'),
        );
    }
    try {
      await request.response.close();
    } on HttpException {
      // Expected when the production client enforces a timeout.
    }
  }

  String _sse(AgentEvaluationTransportOutcome outcome, String text) =>
      'data: ${jsonEncode(<String, Object?>{
        'choices': <Object?>[
          <String, Object?>{
            'delta': <String, Object?>{'content': text},
            'index': 0,
          },
        ],
      })}\n\n'
      'data: ${jsonEncode(<String, Object?>{
        'choices': <Object?>[
          <String, Object?>{'delta': const <String, Object?>{}, 'finish_reason': 'stop', 'index': 0},
        ],
        'usage': <String, Object?>{'prompt_tokens': outcome.promptTokens, 'completion_tokens': outcome.completionTokens, 'total_tokens': outcome.promptTokens + outcome.completionTokens},
      })}\n\n'
      'data: [DONE]\n\n';
}

/// Production failover chain whose every endpoint dispatch crosses its own
/// metered client while sharing one execution-wide budget guard.
final class AgentEvaluationMeteredFailoverClient implements AppLlmClient {
  AgentEvaluationMeteredFailoverClient({
    required List<FailoverEndpoint> endpoints,
    required AppLlmClient inner,
    required AgentEvaluationExecutionBudgetGuard executionBudget,
    required AppLlmTimeoutConfig frozenTimeout,
    required String trialSlotId,
    required int attemptNo,
  }) : _endpoints = List<FailoverEndpoint>.unmodifiable(endpoints) {
    if (_endpoints.length < 2) {
      throw ArgumentError('metered failover requires at least two endpoints');
    }
    final meters = <String, AgentEvaluationMeteredAppLlmClient>{};
    for (final endpoint in _endpoints) {
      final routeHash = AgentEvaluationMeteredAppLlmClient.modelRouteHashFor(
        endpoint.model,
      );
      final meter = AgentEvaluationMeteredAppLlmClient(
        inner: inner,
        model: endpoint.model,
        provider: endpoint.provider,
        baseUrl: endpoint.baseUrl,
        frozenModelRouteHash: routeHash,
        frozenTimeout: frozenTimeout,
        frozenApiKey: endpoint.apiKey,
        executionBudget: executionBudget,
        frozenMaxCompletionTokens: 4096,
        maxCallsPerAttempt: 1,
        maxTokensPerAttempt: 20000,
        returnFailedResultAfterAccounting: true,
      )..beginAttempt(trialSlotId: trialSlotId, attemptNo: attemptNo);
      meters[endpoint.id] = meter;
    }
    _multiplexer = _MeteredEndpointMultiplexer(
      endpoints: _endpoints,
      meters: meters,
    );
    _chain = LlmFailoverChain(
      endpoints: _endpoints,
      delegate: _multiplexer,
      strategy: FailoverStrategy.configOrder,
      maxRetriesPerEndpoint: 0,
      baseDelayMs: 0,
    );
  }

  static final String releaseHash =
      'sha256:${AgentEvaluationHashes.domainHash('agent-evaluation-metered-failover-release-v1', const <String, Object?>{'chain': 'production-LlmFailoverChain-config-order', 'meter': 'one-frozen-meter-per-endpoint-shared-budget', 'retry': 'one-dispatch-per-endpoint'})}';

  final List<FailoverEndpoint> _endpoints;
  late final _MeteredEndpointMultiplexer _multiplexer;
  late final LlmFailoverChain _chain;
  final List<FailoverAttemptResult> attempts = <FailoverAttemptResult>[];

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) =>
      _chain.executeWithFailover(request, attempts: attempts);

  List<AgentEvaluationMeterSnapshot> finishAttempt() =>
      <AgentEvaluationMeterSnapshot>[
        for (final endpointId in _multiplexer.usedEndpointIds)
          _multiplexer.meters[endpointId]!.finishAttempt(),
      ];

  @override
  Stream<String> chatStream(AppLlmChatRequest request) =>
      throw UnsupportedError('metered evaluation failover is unary');
}

final class _MeteredEndpointMultiplexer implements AppLlmClient {
  _MeteredEndpointMultiplexer({required this.endpoints, required this.meters});

  final List<FailoverEndpoint> endpoints;
  final Map<String, AgentEvaluationMeteredAppLlmClient> meters;
  final List<String> usedEndpointIds = <String>[];

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) {
    final matches = endpoints.where(
      (endpoint) =>
          endpoint.baseUrl == request.baseUrl &&
          endpoint.model == request.model &&
          endpoint.provider == request.provider,
    );
    if (matches.length != 1) {
      throw StateError('failover request has no unique frozen endpoint meter');
    }
    final endpoint = matches.single;
    if (!usedEndpointIds.contains(endpoint.id)) {
      usedEndpointIds.add(endpoint.id);
    }
    return meters[endpoint.id]!.chat(request);
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) =>
      throw UnsupportedError('metered endpoint multiplexer is unary');
}
