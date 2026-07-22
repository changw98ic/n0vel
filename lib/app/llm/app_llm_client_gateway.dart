import 'dart:async';
import 'dart:math';

import 'app_llm_circuit_breaker.dart';
import 'app_llm_client_contract.dart';
import 'app_llm_client_types.dart';

typedef AppLlmGatewayPhysicalDispatchRunner =
    Future<AppLlmChatResult> Function({
      required AppLlmChatRequest request,
      required int retryIndex,
      required Future<AppLlmChatResult> Function() operation,
    });

class AppLlmClientGateway
    implements
        AppLlmClient,
        AppLlmSinglePhysicalDispatchCapability,
        AppLlmPhysicalDispatchLifecycle {
  AppLlmClientGateway({
    required AppLlmClient delegate,
    this.maxRetries = 3,
    this.baseDelayMs = 1000,
    AppLlmCircuitBreaker? circuitBreaker,
  }) : _delegate = delegate,
       _circuitBreaker = circuitBreaker ?? AppLlmCircuitBreaker();

  final AppLlmClient _delegate;
  final int maxRetries;
  final int baseDelayMs;
  final AppLlmCircuitBreaker _circuitBreaker;

  @override
  bool get supportsSinglePhysicalDispatch =>
      appLlmClientSupportsSinglePhysicalDispatch(_delegate);

  /// 暴露 circuit breaker 供外部可观测。
  AppLlmCircuitBreaker get circuitBreaker => _circuitBreaker;

  static final _rng = Random();

  static const _maxReconnectBackoffAttempt = 7;

  AppLlmConnectionState _connectionState = AppLlmConnectionState.connected;
  final _connectionStateController =
      StreamController<AppLlmConnectionState>.broadcast();

  Timer? _reconnectTimer;
  final Set<Future<void>> _activeReconnectProbes = <Future<void>>{};
  int _reconnectAttempt = 0;
  int _reconnectGeneration = 0;
  bool _reconnectSuppressed = false;
  bool _shutdown = false;
  Future<void>? _physicalDispatchShutdown;

  String? _lastBaseUrl;
  String? _lastApiKey;
  String? _lastModel;
  AppLlmProvider _lastProvider = AppLlmProvider.openaiCompatible;
  int _lastTimeoutMs = 30000;

  AppLlmConnectionState get connectionState => _connectionState;

  Stream<AppLlmConnectionState> get onConnectionStateChanged =>
      _connectionStateController.stream;

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) =>
      chatWithPhysicalDispatch(request);

  /// Runs [request] while exposing each real delegate call independently.
  ///
  /// The callback is deliberately per physical provider dispatch rather than
  /// per logical gateway call: retries therefore receive their own timing,
  /// pool slot, and trace entry. Circuit-breaker ownership remains here so a
  /// reused gateway preserves its failure history across requests.
  Future<AppLlmChatResult> chatWithPhysicalDispatch(
    AppLlmChatRequest request, {
    AppLlmGatewayPhysicalDispatchRunner? dispatchRunner,
  }) async {
    if (_shutdown) {
      throw const AppLlmPhysicalDispatchPreflightException(
        'client-shutdown',
        'the LLM gateway has been shut down',
      );
    }
    validateAppLlmSinglePhysicalDispatchRequest(request);
    validateAppLlmSinglePhysicalDispatchCapability(
      client: _delegate,
      request: request,
    );
    _lastBaseUrl = request.baseUrl;
    _lastApiKey = request.apiKey;
    _lastModel = request.model;
    _lastProvider = request.provider;
    _lastTimeoutMs = request.timeoutMs;

    final singlePhysicalDispatch =
        request.physicalDispatchPolicy == AppLlmPhysicalDispatchPolicy.single;

    Future<AppLlmChatResult> dispatch(int attempt) {
      Future<AppLlmChatResult> operation() {
        // llm-call-site: boundary.gateway.primary
        return _delegate.chat(request);
      }

      return dispatchRunner == null
          ? operation()
          : dispatchRunner(
              request: request,
              retryIndex: attempt,
              operation: operation,
            );
    }

    if (singlePhysicalDispatch) {
      // A stale adaptive reconnect loop and an open circuit must not turn an
      // admitted experiment attempt into either a background request or zero
      // provider requests. The experiment gets one direct, isolated dispatch.
      await quiesceReconnect();
      final result = await dispatch(0);
      if (result.succeeded) {
        _setConnectionState(AppLlmConnectionState.connected);
      } else if (_isConnectionLost(result.failureKind)) {
        _setConnectionState(AppLlmConnectionState.disconnected);
      }
      return result;
    }

    _reconnectSuppressed = false;

    return _circuitBreaker.guard(() async {
      var attempt = 0;
      while (true) {
        final result = await dispatch(attempt);
        if (result.succeeded) {
          _setConnectionState(AppLlmConnectionState.connected);
          _stopReconnectLoop();
          return result;
        }
        if (_isConnectionLost(result.failureKind)) {
          _setConnectionState(AppLlmConnectionState.disconnected);
        }
        if (!_isRetryable(result.failureKind)) {
          return result;
        }
        attempt++;
        if (attempt >= maxRetries) {
          if (_isConnectionLost(result.failureKind)) {
            _startReconnectLoop();
          }
          return result;
        }
        await Future<void>.delayed(Duration(milliseconds: _backoffMs(attempt)));
      }
    });
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) {
    if (_shutdown) {
      throw const AppLlmPhysicalDispatchPreflightException(
        'client-shutdown',
        'the LLM gateway has been shut down',
      );
    }
    validateAppLlmSinglePhysicalDispatchRequest(request);
    validateAppLlmSinglePhysicalDispatchCapability(
      client: _delegate,
      request: request,
    );
    if (request.physicalDispatchPolicy == AppLlmPhysicalDispatchPolicy.single) {
      throw const AppLlmPhysicalDispatchPreflightException(
        'single-stream-unsupported',
        'single physical dispatch requires the atomic chat interface',
      );
    }
    final effective = _circuitBreaker.state;
    if (effective == AppLlmCircuitState.open) {
      return Stream.error(
        AppLlmStreamException(
          failureKind: AppLlmFailureKind.server,
          detail:
              'Circuit breaker is open - '
              '${_circuitBreaker.consecutiveFailures} consecutive failures, '
              'retry after ${const Duration(seconds: 30)}',
        ),
      );
    }

    return _delegate
        // llm-call-site: boundary.gateway.stream
        .chatStream(request)
        .transform(
          StreamTransformer<String, String>.fromHandlers(
            handleData: (data, sink) => sink.add(data),
            handleError: (error, stackTrace, sink) {
              _circuitBreaker.recordStreamFailure();
              sink.addError(error, stackTrace);
            },
            handleDone: (sink) {
              _circuitBreaker.recordStreamSuccess();
              sink.close();
            },
          ),
        );
  }

  void _startReconnectLoop() {
    if (_reconnectSuppressed) return;
    if (_reconnectTimer != null) return;
    if (_activeReconnectProbes.isNotEmpty) return;
    _reconnectAttempt = 0;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectSuppressed) return;
    if (_connectionStateController.isClosed) return;
    if (_connectionState == AppLlmConnectionState.connected) return;
    if (_lastBaseUrl == null) return;
    if (_reconnectTimer != null || _activeReconnectProbes.isNotEmpty) return;

    final delay = _backoffMs(
      min(_reconnectAttempt, _maxReconnectBackoffAttempt),
    );
    final generation = _reconnectGeneration;
    _reconnectTimer = Timer(Duration(milliseconds: delay), () {
      _reconnectTimer = null;
      if (_reconnectSuppressed || generation != _reconnectGeneration) return;
      final probe = _reconnectTick(generation);
      _activeReconnectProbes.add(probe);
      probe.then<void>(
        (_) => _clearReconnectProbe(probe),
        onError: (Object _, StackTrace _) => _clearReconnectProbe(probe),
      );
    });
  }

  Future<void> _reconnectTick(int generation) async {
    if (_reconnectSuppressed || generation != _reconnectGeneration) return;
    if (_connectionState == AppLlmConnectionState.connected) return;
    if (_connectionStateController.isClosed) return;
    if (_lastBaseUrl == null) return;

    late final AppLlmChatResult result;
    try {
      // llm-call-site: boundary.gateway.health-probe
      result = await _delegate.chat(
        AppLlmChatRequest(
          baseUrl: _lastBaseUrl!,
          apiKey: _lastApiKey ?? '',
          model: _lastModel ?? '',
          provider: _lastProvider,
          timeoutMs: _lastTimeoutMs,
          messages: const [AppLlmChatMessage(role: 'user', content: 'ping')],
        ),
      );
    } on Object {
      if (_reconnectSuppressed || generation != _reconnectGeneration) return;
      _reconnectAttempt = min(
        _reconnectAttempt + 1,
        _maxReconnectBackoffAttempt,
      );
      _scheduleReconnect();
      return;
    }

    if (_reconnectSuppressed || generation != _reconnectGeneration) return;
    if (_connectionStateController.isClosed) return;

    if (!_isConnectionLost(result.failureKind)) {
      _setConnectionState(AppLlmConnectionState.connected);
      _reconnectAttempt = 0;
      return;
    }

    _reconnectAttempt = min(_reconnectAttempt + 1, _maxReconnectBackoffAttempt);
    _scheduleReconnect();
  }

  void _stopReconnectLoop() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempt = 0;
    _reconnectGeneration += 1;
  }

  /// Cancels scheduled reconnect work and waits for an already-dispatched
  /// health probe to finish. While quiesced, a stale probe cannot reschedule
  /// itself. The next adaptive chat explicitly re-enables reconnect behavior.
  Future<void> quiesceReconnect() async {
    _reconnectSuppressed = true;
    _stopReconnectLoop();
    while (_activeReconnectProbes.isNotEmpty) {
      final active = List<Future<void>>.of(_activeReconnectProbes);
      await Future.wait<void>(
        active.map(
          (probe) => probe.catchError((Object _) {
            // Probe failures are operational state, not experiment admission.
          }),
        ),
      );
    }
    _stopReconnectLoop();
  }

  void _clearReconnectProbe(Future<void> probe) {
    _activeReconnectProbes.remove(probe);
    if (_activeReconnectProbes.isEmpty &&
        !_reconnectSuppressed &&
        !_shutdown &&
        _connectionState == AppLlmConnectionState.disconnected) {
      _scheduleReconnect();
    }
  }

  void dispose() {
    _shutdown = true;
    _reconnectSuppressed = true;
    _stopReconnectLoop();
    if (!_connectionStateController.isClosed) {
      _connectionStateController.close();
    }
  }

  @override
  Future<void> shutdownPhysicalDispatches() =>
      _physicalDispatchShutdown ??= _shutdownPhysicalDispatchesOnce();

  Future<void> _shutdownPhysicalDispatchesOnce() async {
    _shutdown = true;
    await quiesceReconnect();
    // A gateway owns the complete dispatch lifecycle of its delegate graph.
    // Waiting only for this gateway's reconnect probes can leave an inner
    // gateway, cache, meter, or transport running after an experiment arm has
    // supposedly closed.
    await shutdownAppLlmClientPhysicalDispatches(_delegate);
    if (!_connectionStateController.isClosed) {
      await _connectionStateController.close();
    }
  }

  bool _isConnectionLost(AppLlmFailureKind? kind) {
    switch (kind) {
      case AppLlmFailureKind.network:
      case AppLlmFailureKind.timeout:
        return true;
      default:
        return false;
    }
  }

  bool _isRetryable(AppLlmFailureKind? kind) {
    switch (kind) {
      case AppLlmFailureKind.timeout:
      case AppLlmFailureKind.rateLimited:
      case AppLlmFailureKind.server:
      case AppLlmFailureKind.network:
        return true;
      case AppLlmFailureKind.unauthorized:
      case AppLlmFailureKind.modelNotFound:
      case AppLlmFailureKind.invalidResponse:
      case AppLlmFailureKind.unsupportedPlatform:
      case AppLlmFailureKind.insecureScheme:
      case null:
        return false;
    }
  }

  int _backoffMs(int attempt) {
    final exponential = baseDelayMs * (1 << attempt);
    final jitter = (exponential * 0.2).round();
    return exponential + _rng.nextInt(jitter + 1);
  }

  void _setConnectionState(AppLlmConnectionState state) {
    if (_connectionState != state) {
      _connectionState = state;
      if (!_connectionStateController.isClosed) {
        _connectionStateController.add(state);
      }
    }
  }
}
