import 'package:novel_writer/app/llm/app_llm_client.dart';

/// 可控的 fake [AppLlmClient]，用于故障演练测试。
///
/// 通过配置 [failCountBeforeSuccess]、[failureKind]、[simulateDelay]、
/// [malformedResponse] 等参数，模拟各种 LLM 故障场景。
/// 每次调用都记录到 [callLog] 供断言使用。
class FakeFaultyClient implements AppLlmClient {
  FakeFaultyClient({
    this.failCountBeforeSuccess = 0,
    this.failureKind,
    this.simulateDelay,
    this.malformedResponse,
    this.successText = '正常的回复文本，用于测试',
    this.streamChunks = const ['正常', '的', '流式', '回复'],
  });

  /// 前 N 次调用失败，之后返回成功。
  /// 默认 0 表示总是成功。
  int failCountBeforeSuccess;

  /// 失败时使用的 [AppLlmFailureKind]。
  /// 为 null 时表示总是成功（除非 [malformedResponse] 不为 null）。
  AppLlmFailureKind? failureKind;

  /// 模拟延迟。设置后每次调用会等待 [simulateDelay]。
  Duration? simulateDelay;

  /// 如果不为 null，返回成功结果但 text 内容为这个畸形 payload。
  /// 用于 schema 校验测试。
  String? malformedResponse;

  /// 成功时返回的文本。
  String successText;

  /// 流式成功时的 chunk 列表。
  List<String> streamChunks;

  /// 记录所有 [chat] 和 [chatStream] 调用的 request。
  final List<AppLlmChatRequest> callLog = [];

  int _callCount = 0;

  /// 已调用次数（包括 chat 和 chatStream）。
  int get callCount => _callCount;

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    callLog.add(request);
    _callCount++;

    if (simulateDelay != null) {
      await Future<void>.delayed(simulateDelay!);
    }

    final shouldFail = _callCount <= failCountBeforeSuccess;

    if (shouldFail && failureKind != null) {
      return AppLlmChatResult.failure(
        failureKind: failureKind!,
        detail: '模拟故障 (call #$_callCount)',
      );
    }

    // 返回畸形 payload（成功状态但内容异常）
    final text = malformedResponse ?? successText;
    return AppLlmChatResult.success(text: text);
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) async* {
    callLog.add(request);
    _callCount++;

    if (simulateDelay != null) {
      await Future<void>.delayed(simulateDelay!);
    }

    final shouldFail = _callCount <= failCountBeforeSuccess;

    if (shouldFail && failureKind != null) {
      yield* Stream.error(
        AppLlmStreamException(
          failureKind: failureKind!,
          detail: '模拟流式故障 (call #$_callCount)',
        ),
      );
      return;
    }

    for (final chunk in streamChunks) {
      yield chunk;
    }
  }

  /// 重置调用计数和日志，复用同一 client 实例。
  void reset() {
    _callCount = 0;
    callLog.clear();
  }
}

/// 构建一个用于测试的标准 [AppLlmChatRequest]。
AppLlmChatRequest testChatRequest({List<AppLlmChatMessage>? messages}) {
  return AppLlmChatRequest(
    baseUrl: 'http://localhost:11434/v1',
    apiKey: 'test-key',
    model: 'test-model',
    timeout: const AppLlmTimeoutConfig.uniform(1000),
    messages:
        messages ?? const [AppLlmChatMessage(role: 'user', content: '测试消息')],
  );
}
