import 'dart:async';
import 'dart:math';

import 'app_llm_client_contract.dart';
import 'app_llm_client_types.dart';

class AppLlmClientGateway implements AppLlmClient {
  AppLlmClientGateway({
    required AppLlmClient delegate,
    this.maxRetries = 3,
    this.baseDelayMs = 1000,
  }) : _delegate = delegate;

  final AppLlmClient _delegate;
  final int maxRetries;
  final int baseDelayMs;

  static final _rng = Random();

  static const _maxReconnectBackoffAttempt = 7;

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
      if (attempt >= maxRetries) {
        if (_isConnectionLost(result.failureKind)) {
          _startReconnectLoop();
        }
        return result;
      }
      await Future<void>.delayed(Duration(milliseconds: _backoffMs(attempt)));
    }
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) {
    return _delegate.chatStream(request);
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

    final delay = _backoffMs(
      min(_reconnectAttempt, _maxReconnectBackoffAttempt),
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

    _reconnectAttempt = min(_reconnectAttempt + 1, _maxReconnectBackoffAttempt);
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
