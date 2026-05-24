import 'dart:async';
import 'dart:math';

import 'app_llm_circuit_breaker.dart';
import 'app_llm_client_contract.dart';
import 'app_llm_client_types.dart';
import 'app_llm_execution_policy.dart';

class AppLlmClientGateway implements AppLlmClient {
  AppLlmClientGateway({
    required AppLlmClient delegate,
    this.maxRetries = 3,
    this.baseDelayMs = 1000,
    AppLlmRetryPolicy? retryPolicy,
    AppLlmCircuitBreaker? circuitBreaker,
  })  : _delegate = delegate,
        _circuitBreaker = circuitBreaker ?? AppLlmCircuitBreaker(),
        _retryPolicy = retryPolicy ??
            AppLlmRetryPolicy(
              maxRetries: maxRetries,
              baseDelayMs: baseDelayMs,
            );

  final AppLlmClient _delegate;
  final int maxRetries;
  final int baseDelayMs;
  final AppLlmCircuitBreaker _circuitBreaker;
  final AppLlmRetryPolicy _retryPolicy;

  /// 暴露 circuit breaker 供外部可观测。
  AppLlmCircuitBreaker get circuitBreaker => _circuitBreaker;

  /// 暴露 retry policy 供外部可观测。
  AppLlmRetryPolicy get retryPolicy => _retryPolicy;

  static final _rng = Random();

  AppLlmConnectionState _connectionState = AppLlmConnectionState.connected;
  final _connectionStateController =
      StreamController<AppLlmConnectionState>.broadcast();

  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;

  String? _lastBaseUrl;
  String? _lastApiKey;
  String? _lastModel;
  AppLlmProvider _lastProvider = AppLlmProvider.openaiCompatible;
  int _lastTimeoutMs = 30000;

  AppLlmConnectionState get connectionState => _connectionState;

  Stream<AppLlmConnectionState> get onConnectionStateChanged =>
      _connectionStateController.stream;

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    _lastBaseUrl = request.baseUrl;
    _lastApiKey = request.apiKey;
    _lastModel = request.model;
    _lastProvider = request.provider;
    _lastTimeoutMs = request.timeoutMs;

    return _circuitBreaker.guard(() async {
      var attempt = 0;
      while (true) {
        final result = await _delegate.chat(request);
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
        if (attempt >= _retryPolicy.maxRetries) {
          if (_isConnectionLost(result.failureKind)) {
            _startReconnectLoop();
          }
          return result;
        }
        await Future<void>.delayed(
          Duration(milliseconds: _backoffMs(attempt)),
        );
      }
    });
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) {
    final effective = _circuitBreaker.state;
    if (effective == AppLlmCircuitState.open) {
      return Stream.error(
        AppLlmStreamException(
          failureKind: AppLlmFailureKind.server,
          detail: 'Circuit breaker is open - '
              '${_circuitBreaker.consecutiveFailures} consecutive failures, '
              'retry after ${const Duration(seconds: 30)}',
        ),
      );
    }

    return _delegate.chatStream(request).transform(
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
    if (_reconnectTimer != null) return;
    _reconnectAttempt = 0;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_connectionStateController.isClosed) return;
    if (_connectionState == AppLlmConnectionState.connected) return;
    if (_lastBaseUrl == null) return;

    final delay = _retryPolicy.backoffMs(
      min(_reconnectAttempt, _retryPolicy.maxReconnectAttempts),
      rng: _rng,
    );
    _reconnectTimer = Timer(Duration(milliseconds: delay), _reconnectTick);
  }

  Future<void> _reconnectTick() async {
    if (_connectionState == AppLlmConnectionState.connected) return;
    if (_connectionStateController.isClosed) return;
    if (_lastBaseUrl == null) return;

    final result = await _delegate.chat(
      AppLlmChatRequest(
        baseUrl: _lastBaseUrl!,
        apiKey: _lastApiKey ?? '',
        model: _lastModel ?? '',
        provider: _lastProvider,
        timeoutMs: _lastTimeoutMs,
        messages: const [AppLlmChatMessage(role: 'user', content: 'ping')],
      ),
    );

    if (!_isConnectionLost(result.failureKind)) {
      _setConnectionState(AppLlmConnectionState.connected);
      _reconnectTimer = null;
      _reconnectAttempt = 0;
      return;
    }

    _reconnectAttempt = min(
      _reconnectAttempt + 1,
      _retryPolicy.maxReconnectAttempts,
    );
    _scheduleReconnect();
  }

  void _stopReconnectLoop() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempt = 0;
  }

  void dispose() {
    _stopReconnectLoop();
    _connectionStateController.close();
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
    return _retryPolicy.isRetryable(kind);
  }

  int _backoffMs(int attempt) {
    return _retryPolicy.backoffMs(attempt, rng: _rng);
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
