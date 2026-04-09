import 'dart:async';
import 'dart:ui';

/// 防抖工具类
/// 用于延迟执行频繁触发的操作（如搜索输入、自动保存）
class Debounce {
  Debounce({
    this.duration = const Duration(milliseconds: 300),
  });

  final Duration duration;
  Timer? _timer;

  /// 执行防抖操作
  /// 如果在 duration 时间内再次调用，之前的调用会被取消
  void call(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  /// 立即执行并取消等待中的调用
  void immediate(VoidCallback action) {
    _timer?.cancel();
    action();
  }

  /// 取消等待中的调用
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// 是否有待执行的操作
  bool get isActive => _timer?.isActive ?? false;

  /// 释放资源
  void dispose() {
    cancel();
  }
}

/// 节流工具类
/// 用于限制操作频率（如滚动事件、频繁点击）
class Throttle {
  Throttle({
    this.duration = const Duration(milliseconds: 300),
  });

  final Duration duration;
  DateTime? _lastExecution;

  /// 执行节流操作
  /// 如果距离上次执行不足 duration，则忽略本次调用
  void call(VoidCallback action) {
    final now = DateTime.now();
    if (_lastExecution == null ||
        now.difference(_lastExecution!) >= duration) {
      _lastExecution = now;
      action();
    }
  }

  /// 重置节流状态
  void reset() {
    _lastExecution = null;
  }
}
