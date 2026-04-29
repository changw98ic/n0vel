import 'package:dio/dio.dart';

import '../logging/app_event_log.dart';
import 'token_usage.dart';

class GatewayInterceptor extends Interceptor {
  GatewayInterceptor({required AppEventLog eventLog}) : _eventLog = eventLog;

  final AppEventLog _eventLog;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final correlationId =
        options.headers['X-Request-Id'] as String? ??
        _eventLog.newCorrelationId('gw');
    options.headers['X-Request-Id'] = correlationId;
    options.extra['startTime'] = DateTime.now();
    options.extra['correlationId'] = correlationId;

    _eventLog.logBestEffort(
      level: AppEventLogLevel.debug,
      category: AppEventLogCategory.ai,
      action: 'gateway.request.sent',
      status: AppEventLogStatus.succeeded,
      message:
          '${options.method} ${options.uri} (model=${options.data is Map ? (options.data as Map)['model'] ?? '?' : '?'})',
      correlationId: correlationId,
    );
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final extra = response.requestOptions.extra;
    final correlationId =
        extra['correlationId'] as String? ?? _eventLog.newCorrelationId('gw');
    final startTime = extra['startTime'] as DateTime?;
    final latencyMs = startTime != null
        ? DateTime.now().difference(startTime).inMilliseconds
        : null;

    final tokenUsage = _extractTokenUsage(response);
    response.requestOptions.extra['tokenUsage'] = tokenUsage;

    _eventLog.logBestEffort(
      level: AppEventLogLevel.info,
      category: AppEventLogCategory.ai,
      action: 'gateway.response.received',
      status: AppEventLogStatus.succeeded,
      message:
          '响应 ${response.statusCode} (${latencyMs}ms)${tokenUsage != null ? ' tokens=${tokenUsage.totalTokens}' : ''}',
      correlationId: correlationId,
      metadata: {
        'statusCode': response.statusCode,
        if (latencyMs != null) 'latencyMs': latencyMs,
        if (tokenUsage != null) ...{
          'promptTokens': tokenUsage.promptTokens,
          'completionTokens': tokenUsage.completionTokens,
          'totalTokens': tokenUsage.totalTokens,
        },
      },
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final extra = err.requestOptions.extra;
    final correlationId =
        extra['correlationId'] as String? ?? _eventLog.newCorrelationId('gw');
    final startTime = extra['startTime'] as DateTime?;
    final latencyMs = startTime != null
        ? DateTime.now().difference(startTime).inMilliseconds
        : null;

    _eventLog.logBestEffort(
      level: AppEventLogLevel.error,
      category: AppEventLogCategory.ai,
      action: 'gateway.request.failed',
      status: AppEventLogStatus.failed,
      message:
          '请求失败 ${err.type.name} (${latencyMs}ms) status=${err.response?.statusCode}',
      correlationId: correlationId,
      errorDetail: err.message ?? err.toString(),
      metadata: {
        'errorType': err.type.name,
        'statusCode': err.response?.statusCode,
        if (latencyMs != null) 'latencyMs': latencyMs,
      },
    );
    handler.next(err);
  }

  TokenUsage? _extractTokenUsage(Response<dynamic> response) {
    try {
      final data = response.data;
      if (data is ResponseBody) {
        return null;
      }
      if (data is Map) {
        final usage = data['usage'];
        if (usage is Map) {
          return TokenUsage.fromJson(usage.cast<String, Object?>());
        }
      }
    } catch (_) {}
    return null;
  }
}
