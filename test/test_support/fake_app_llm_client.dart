import 'dart:async';

import 'package:novel_writer/app/llm/app_llm_client.dart';

typedef FakeAppLlmResponder =
    FutureOr<AppLlmChatResult> Function(AppLlmChatRequest request);

typedef FakeAppLlmStreamResponder =
    Stream<String> Function(AppLlmChatRequest request);

class FakeAppLlmClient implements AppLlmClient {
  FakeAppLlmClient({
    FakeAppLlmResponder? responder,
    FakeAppLlmStreamResponder? streamResponder,
  }) : _responder = responder ?? _defaultResponder,
       _streamResponder = streamResponder ?? _defaultStreamResponder;

  final FakeAppLlmResponder _responder;
  final FakeAppLlmStreamResponder _streamResponder;
  final List<AppLlmChatRequest> requests = <AppLlmChatRequest>[];
  final List<AppLlmChatRequest> streamRequests = <AppLlmChatRequest>[];

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    requests.add(request);
    return _responder(request);
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) {
    streamRequests.add(request);
    return _streamResponder(request);
  }

  static AppLlmChatResult _defaultResponder(AppLlmChatRequest request) {
    final normalizedBaseUrl = request.baseUrl.trim().toLowerCase();
    final normalizedApiKey = request.apiKey.trim().toLowerCase();
    final normalizedModel = request.model.trim().toLowerCase();
    final lastUserMessage = request.messages.isEmpty
        ? ''
        : request.messages.last.content;
    final host = Uri.tryParse(request.baseUrl.trim())?.host ?? request.baseUrl;

    if (normalizedBaseUrl.contains('offline') || host.endsWith('.invalid')) {
      return AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.network,
        detail: '无法连接到 $host。',
      );
    }

    if (request.timeout.receiveTimeoutMs < 1000 || normalizedBaseUrl.contains('timeout')) {
      return const AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.timeout,
        detail: 'timeout_ms 太小，请调大后重试。',
      );
    }

    if (normalizedApiKey.contains('unauthorized') ||
        normalizedApiKey.contains('denied') ||
        normalizedApiKey.contains('401') ||
        normalizedApiKey.contains('403')) {
      return const AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.unauthorized,
        statusCode: 401,
        detail: '401 / 403：请检查 API Key、组织权限或账号状态。',
      );
    }

    if (normalizedModel.contains('missing') ||
        normalizedModel.contains('not-found') ||
        normalizedModel.contains('404')) {
      return AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.modelNotFound,
        statusCode: 404,
        detail: '未找到模型 "${request.model}"。',
      );
    }

    if (lastUserMessage.contains('连接测试')) {
      return AppLlmChatResult.success(text: 'pong', latencyMs: 182);
    }

    final taskType = _extractField(lastUserMessage, '任务类型');
    final authorIntent = _extractField(lastUserMessage, '作者意图');
    if (taskType == '续写') {
      final continuation = authorIntent.isEmpty ? '补上一段自然衔接的正文。' : authorIntent;
      return AppLlmChatResult.success(text: continuation, latencyMs: 321);
    }
    if (taskType == '选区改写') {
      final rewrite = authorIntent.isEmpty ? '调整了这段文字。' : authorIntent;
      return AppLlmChatResult.success(text: rewrite, latencyMs: 256);
    }
    final rewrite = authorIntent.isEmpty ? '调整了语气。' : authorIntent;
    return AppLlmChatResult.success(text: rewrite, latencyMs: 298);
  }

  static String _extractField(String body, String label) {
    final pattern = RegExp('^$label：(.+)\$', multiLine: true);
    final match = pattern.firstMatch(body);
    return match == null ? '' : match.group(1)!.trim();
  }

  static Stream<String> _defaultStreamResponder(AppLlmChatRequest request) {
    final result = _defaultResponder(request);
    if (result.succeeded) {
      return Stream.value(result.text!);
    }
    return Stream.error(
      AppLlmStreamException(
        failureKind: result.failureKind!,
        statusCode: result.statusCode,
        detail: result.detail,
      ),
    );
  }
}
