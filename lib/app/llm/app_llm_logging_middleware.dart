import 'dart:async';

import 'package:novel_writer/app/logging/app_event_log.dart';
import 'package:novel_writer/app/logging/app_log.dart';

import 'app_llm_client_contract.dart';
import 'app_llm_client_types.dart';

class AppLlmLoggingMiddleware implements AppLlmClient {
  AppLlmLoggingMiddleware({
    required AppLlmClient delegate,
    AppEventLog? eventLog,
  }) : _delegate = delegate,
       _eventLog = eventLog;

  final AppLlmClient _delegate;
  final AppEventLog? _eventLog;

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    final parsed = Uri.tryParse(request.baseUrl.trim());
    final host = (parsed != null && parsed.host.isNotEmpty)
        ? parsed.host
        : request.baseUrl;
    final messageCount = request.messages.length;

    AppLog.d('→ ${request.model} @ $host | $messageCount msgs', tag: 'LLM');

    final stopwatch = Stopwatch()..start();
    AppLlmChatResult result;
    try {
      result = await _delegate.chat(request);
    } catch (error) {
      stopwatch.stop();
      AppLog.e(
        '← ${request.model} @ $host | ${stopwatch.elapsedMilliseconds}ms | ERROR',
        tag: 'LLM',
        error: error,
      );
      rethrow;
    }
    stopwatch.stop();

    final elapsed = result.latencyMs ?? stopwatch.elapsedMilliseconds;

    if (result.succeeded) {
      AppLog.d(
        '← ${request.model} @ $host | ${elapsed}ms | OK ${result.text!.length} chars',
        tag: 'LLM',
      );
    } else {
      final code = result.failureKind?.name ?? 'unknown';
      final status = result.statusCode != null ? ' ${result.statusCode}' : '';
      AppLog.w(
        '← ${request.model} @ $host | ${elapsed}ms | FAIL $code$status',
        tag: 'LLM',
      );
    }

    await _writeEventLog(
      request: request,
      result: result,
      host: host,
      elapsed: elapsed,
      messageCount: messageCount,
    );

    return result;
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) async* {
    final parsed = Uri.tryParse(request.baseUrl.trim());
    final host = (parsed != null && parsed.host.isNotEmpty)
        ? parsed.host
        : request.baseUrl;
    final messageCount = request.messages.length;

    AppLog.d(
      '→ ${request.model} @ $host | $messageCount msgs (stream)',
      tag: 'LLM',
    );

    final stopwatch = Stopwatch()..start();
    int charCount = 0;

    try {
      await for (final delta in _delegate.chatStream(request)) {
        charCount += delta.length;
        yield delta;
      }
      stopwatch.stop();
      AppLog.d(
        '← ${request.model} @ $host | ${stopwatch.elapsedMilliseconds}ms | STREAM OK $charCount chars',
        tag: 'LLM',
      );
    } catch (error) {
      stopwatch.stop();
      final code = error is AppLlmStreamException
          ? error.failureKind.name
          : 'unknown';
      AppLog.w(
        '← ${request.model} @ $host | ${stopwatch.elapsedMilliseconds}ms | STREAM FAIL $code',
        tag: 'LLM',
      );
      rethrow;
    }
  }

  Future<void> _writeEventLog({
    required AppLlmChatRequest request,
    required AppLlmChatResult result,
    required String host,
    required int elapsed,
    required int messageCount,
  }) async {
    final log = _eventLog;
    if (log == null) return;

    await log.logBestEffort(
      level: result.succeeded ? AppEventLogLevel.info : AppEventLogLevel.warn,
      category: AppEventLogCategory.ai,
      action: 'llm.chat',
      status: result.succeeded
          ? AppEventLogStatus.succeeded
          : AppEventLogStatus.failed,
      message: result.succeeded
          ? '${request.model}: ${result.text!.length} chars in ${elapsed}ms'
          : '${request.model}: ${result.failureKind?.name ?? "unknown"}',
      errorCode: result.failureKind?.name,
      errorDetail: result.detail,
      metadata: <String, Object?>{
        'model': request.model,
        'host': host,
        'latencyMs': elapsed,
        'messageCount': messageCount,
        if (result.statusCode != null) 'statusCode': result.statusCode!,
      },
    );
  }
}
