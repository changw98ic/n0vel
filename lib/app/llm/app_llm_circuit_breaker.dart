import 'app_llm_client_types.dart';

/// Circuit breaker 状态。
enum AppLlmCircuitState { closed, open, halfOpen }

/// LLM 客户端的 Circuit Breaker 保护。
///
/// 经典三态状态机：
/// - [closed]：正常放行，连续失败达到阈值后转为 [open]。
/// - [open]：直接拒绝，等待恢复超时后转为 [halfOpen]。
/// - [halfOpen]：放行有限探测请求，成功回 [closed]，失败回 [open]。
class AppLlmCircuitBreaker {
  AppLlmCircuitBreaker({
    int failureThreshold = 5,
    Duration recoveryTimeout = const Duration(seconds: 30),
    int halfOpenMaxRequests = 1,
  })  : _failureThreshold = failureThreshold,
        _recoveryTimeout = recoveryTimeout,
        _halfOpenMaxRequests = halfOpenMaxRequests;

  final int _failureThreshold;
  final Duration _recoveryTimeout;
  final int _halfOpenMaxRequests;

  AppLlmCircuitState _state = AppLlmCircuitState.closed;
  int _consecutiveFailures = 0;
  DateTime? _lastFailureTime;
  int _halfOpenSuccessCount = 0;

  /// 当前状态，用于可观测性。
  AppLlmCircuitState get state => _effectiveState();

  /// 当前连续失败次数。
  int get consecutiveFailures => _consecutiveFailures;

  /// 最近一次失败的时间。
  DateTime? get lastFailureTime => _lastFailureTime;

  /// 通过 circuit breaker 包装一次调用。
  ///
  /// 返回 [AppLlmChatResult]——如果 circuit 处于 [AppLlmCircuitState.open]
  /// 则直接返回失败结果，不执行 [action]。
  Future<AppLlmChatResult> guard(
    Future<AppLlmChatResult> Function() action,
  ) async {
    final effective = _effectiveState();

    if (effective == AppLlmCircuitState.open) {
      return AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.server,
        detail: 'Circuit breaker is open - '
            '$_consecutiveFailures consecutive failures, '
            'retry after $_recoveryTimeout',
      );
    }

    if (effective == AppLlmCircuitState.halfOpen) {
      if (_halfOpenSuccessCount >= _halfOpenMaxRequests) {
        // 探测名额用完，等价于 open。
        return const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.server,
          detail: 'Circuit breaker is half-open - '
              'probe limit reached, waiting for results',
        );
      }
    }

    final result = await action();

    if (result.succeeded) {
      _onSuccess();
    } else {
      _onFailure();
    }

    return result;
  }

  /// 外部重置 circuit breaker 到 [closed]。
  void reset() {
    _state = AppLlmCircuitState.closed;
    _consecutiveFailures = 0;
    _halfOpenSuccessCount = 0;
    _lastFailureTime = null;
  }

  /// 流式场景：手动记录成功。
  ///
  /// 用于 [Stream] 完成后通知 circuit breaker 本次调用成功。
  void recordStreamSuccess() => _onSuccess();

  /// 流式场景：手动记录失败。
  ///
  /// 用于 [Stream] 发生错误后通知 circuit breaker 本次调用失败。
  void recordStreamFailure() => _onFailure();

  // ---------------------------------------------------------------------------
  // 内部实现
  // ---------------------------------------------------------------------------

  AppLlmCircuitState _effectiveState() {
    if (_state == AppLlmCircuitState.open) {
      final elapsed = DateTime.now().difference(_lastFailureTime!);
      if (elapsed >= _recoveryTimeout) {
        _state = AppLlmCircuitState.halfOpen;
        _halfOpenSuccessCount = 0;
      }
    }
    return _state;
  }

  void _onSuccess() {
    switch (_state) {
      case AppLlmCircuitState.closed:
        _consecutiveFailures = 0;
      case AppLlmCircuitState.halfOpen:
        _halfOpenSuccessCount++;
        if (_halfOpenSuccessCount >= _halfOpenMaxRequests) {
          _state = AppLlmCircuitState.closed;
          _consecutiveFailures = 0;
          _halfOpenSuccessCount = 0;
        }
      case AppLlmCircuitState.open:
        // 不应到达这里，但防御性处理。
        _state = AppLlmCircuitState.closed;
        _consecutiveFailures = 0;
    }
  }

  void _onFailure() {
    _consecutiveFailures++;
    _lastFailureTime = DateTime.now();

    switch (_state) {
      case AppLlmCircuitState.closed:
        if (_consecutiveFailures >= _failureThreshold) {
          _state = AppLlmCircuitState.open;
        }
      case AppLlmCircuitState.halfOpen:
        _state = AppLlmCircuitState.open;
        _halfOpenSuccessCount = 0;
      case AppLlmCircuitState.open:
        // 已经是 open，保持。
        break;
    }
  }
}
