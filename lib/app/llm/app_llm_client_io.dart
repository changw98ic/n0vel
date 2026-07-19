import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../logging/app_event_log_privacy.dart';
import 'app_llm_client_contract.dart';
import 'app_llm_client_types.dart';
import 'app_llm_provider_adapters.dart';
import 'app_llm_response_decoding.dart';

AppLlmClient createAppLlmClient() => _IoAppLlmClient();

class _IoAppLlmClient implements AppLlmClient {
  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    // A streaming attempt and its non-stream fallback are one user-visible
    // request. They must share a deadline so a provider that keeps a stream
    // alive without completing cannot double (or indefinitely extend) the
    // caller's configured receive timeout.
    final deadline = DateTime.now().add(
      Duration(milliseconds: request.timeout.receiveTimeoutMs),
    );
    if (!request.preferStreaming) {
      return _chatOnce(request, stream: false, deadline: deadline);
    }
    final streamed = await _chatOnce(request, stream: true, deadline: deadline);
    if (streamed.succeeded ||
        streamed.failureKind != AppLlmFailureKind.invalidResponse) {
      return streamed;
    }
    return _chatOnce(request, stream: false, deadline: deadline);
  }

  Future<AppLlmChatResult> _chatOnce(
    AppLlmChatRequest request, {
    required bool stream,
    required DateTime deadline,
  }) async {
    final adapter = AppLlmProviderAdapters.of(request.provider);
    final endpoint = _resolveEndpoint(request.baseUrl, adapter.endpointPath);
    if (_isInsecureScheme(request.baseUrl)) {
      return const AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.insecureScheme,
        detail: '仅支持 HTTPS 连接。请将接口地址改为 https:// 开头。',
      );
    }
    if (endpoint == null) {
      return const AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.network,
        detail: '接口地址无法解析为有效地址。',
      );
    }

    final dio = Dio(
      BaseOptions(
        connectTimeout: Duration(
          milliseconds: request.timeout.connectTimeoutMs,
        ),
        receiveTimeout: Duration(
          milliseconds: request.timeout.receiveTimeoutMs,
        ),
        sendTimeout: Duration(milliseconds: request.timeout.sendTimeoutMs),
        responseType: ResponseType.stream,
        validateStatus: (_) => true,
        headers: adapter.buildHeaders(request.apiKey),
      ),
    );

    final stopwatch = Stopwatch()..start();
    final cancelToken = CancelToken();

    Duration remaining() {
      final value = deadline.difference(DateTime.now());
      if (value <= Duration.zero) {
        cancelToken.cancel('chat deadline exceeded');
        throw TimeoutException('chat deadline exceeded');
      }
      return value;
    }

    Future<T> beforeDeadline<T>(Future<T> future) => future.timeout(
      remaining(),
      onTimeout: () {
        cancelToken.cancel('chat deadline exceeded');
        throw TimeoutException('chat deadline exceeded');
      },
    );

    try {
      final response = await beforeDeadline(
        // llm-call-site: boundary.provider.io-stream-http
        dio.postUri<ResponseBody>(
          endpoint,
          data: adapter.buildBody(
            model: request.model,
            messages: request.messages,
            stream: stream,
            maxTokens: request.effectiveMaxTokens,
          ),
          cancelToken: cancelToken,
        ),
      );
      final statusCode = response.statusCode ?? 0;

      if (statusCode < 200 || statusCode >= 300) {
        final body = await beforeDeadline(
          _readResponseBody(
            response.data,
            timeoutMs: request.timeout.receiveTimeoutMs,
          ),
        );
        stopwatch.stop();
        if (statusCode == HttpStatus.unauthorized ||
            statusCode == HttpStatus.forbidden) {
          return AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.unauthorized,
            statusCode: statusCode,
            detail: _normalizeDetail(body),
          );
        }
        if (statusCode == HttpStatus.notFound) {
          return AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.modelNotFound,
            statusCode: statusCode,
            detail: _normalizeDetail(body),
          );
        }
        if (statusCode == HttpStatus.tooManyRequests) {
          return AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.rateLimited,
            statusCode: statusCode,
            detail: _normalizeDetail(body),
          );
        }
        return AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.server,
          statusCode: statusCode,
          detail: _normalizeDetail(body),
        );
      }

      final body = await beforeDeadline(
        _readResponseBody(
          response.data,
          timeoutMs: request.timeout.receiveTimeoutMs,
        ),
      );
      stopwatch.stop();

      final decoded = request.provider == AppLlmProvider.anthropic
          ? decodeAnthropicMessageStreamBody(body) ??
                decodeAnthropicMessageResponseBody(body)
          : decodeOpenAiChatStreamBody(body) ??
                decodeOpenAiChatResponseBody(body);
      final outputText = decoded?.text ?? adapter.decodeOutputText(body);
      if (outputText == null || outputText.trim().isEmpty) {
        return AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.invalidResponse,
          statusCode: statusCode,
          detail: '模型返回成功，但响应体里没有可用文本。',
        );
      }

      return AppLlmChatResult.success(
        text: outputText.trim(),
        latencyMs: stopwatch.elapsedMilliseconds,
        promptTokens: decoded?.promptTokens,
        completionTokens: decoded?.completionTokens,
        totalTokens: decoded?.totalTokens,
        providerModel: decoded?.providerModel,
      );
    } on DioException catch (error) {
      final failure = _mapDioException(error);
      return AppLlmChatResult.failure(
        failureKind: failure.failureKind,
        statusCode: failure.statusCode,
        detail: failure.detail,
      );
    } on FormatException catch (error) {
      return AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.invalidResponse,
        detail: AppEventLogPrivacy.sanitizeErrorDetail(error.message),
      );
    } on TimeoutException {
      return const AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.timeout,
        detail: '请求在超时时间内未完成。',
      );
    } catch (error) {
      return AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.server,
        detail: AppEventLogPrivacy.sanitizeErrorDetail(error.toString()),
      );
    } finally {
      dio.close(force: true);
    }
  }

  Future<String> _readResponseBody(
    ResponseBody? body, {
    required int timeoutMs,
  }) async {
    if (body == null) {
      return '';
    }

    final bytes = await body.stream
        .expand((chunk) => chunk)
        .toList()
        .timeout(Duration(milliseconds: timeoutMs));
    return utf8.decode(bytes, allowMalformed: true);
  }

  Uri? _resolveEndpoint(String baseUrl, String endpointPath) {
    final trimmed = baseUrl.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final baseUri = Uri.tryParse(trimmed);
    if (baseUri == null) {
      return null;
    }
    final needsTrailingSlash = trimmed.endsWith('/');
    final normalized = needsTrailingSlash ? trimmed : '$trimmed/';
    return Uri.tryParse('$normalized$endpointPath');
  }

  bool _isInsecureScheme(String baseUrl) {
    final uri = Uri.tryParse(baseUrl.trim());
    if (uri == null || !uri.isScheme('HTTP')) return false;
    return !_isLocalhost(uri.host);
  }

  bool _isLocalhost(String host) {
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        host.endsWith('.localhost');
  }

  String? _normalizeDetail(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    String? detail;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map) {
          final message = error['message']?.toString();
          if (message != null && message.trim().isNotEmpty) {
            detail = message.trim();
          }
        }
        if (detail == null) {
          final message = decoded['message']?.toString();
          if (message != null && message.trim().isNotEmpty) {
            detail = message.trim();
          }
        }
      }
    } on FormatException {
      // Fall through to raw body.
    }
    return AppEventLogPrivacy.sanitizeErrorDetail(detail ?? trimmed);
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) async* {
    final adapter = AppLlmProviderAdapters.of(request.provider);
    final endpoint = _resolveEndpoint(request.baseUrl, adapter.endpointPath);
    if (_isInsecureScheme(request.baseUrl)) {
      throw const AppLlmStreamException(
        failureKind: AppLlmFailureKind.insecureScheme,
        detail: '仅支持 HTTPS 连接。请将接口地址改为 https:// 开头。',
      );
    }
    if (endpoint == null) {
      throw const AppLlmStreamException(
        failureKind: AppLlmFailureKind.network,
        detail: '接口地址无法解析为有效地址。',
      );
    }

    final dio = Dio(
      BaseOptions(
        connectTimeout: Duration(
          milliseconds: request.timeout.connectTimeoutMs,
        ),
        receiveTimeout: Duration(
          milliseconds: request.timeout.receiveTimeoutMs,
        ),
        sendTimeout: Duration(milliseconds: request.timeout.sendTimeoutMs),
        responseType: ResponseType.stream,
        validateStatus: (_) => true,
        headers: adapter.buildHeaders(request.apiKey),
      ),
    );

    try {
      // llm-call-site: boundary.provider.io-chat-http
      final response = await dio.postUri<ResponseBody>(
        endpoint,
        data: adapter.buildBody(
          model: request.model,
          messages: request.messages,
          maxTokens: request.effectiveMaxTokens,
        ),
      );

      final statusCode = response.statusCode ?? 0;

      if (statusCode == HttpStatus.unauthorized ||
          statusCode == HttpStatus.forbidden) {
        final body = await _readResponseBody(
          response.data,
          timeoutMs: request.timeout.receiveTimeoutMs,
        );
        throw AppLlmStreamException(
          failureKind: AppLlmFailureKind.unauthorized,
          statusCode: statusCode,
          detail: _normalizeDetail(body),
        );
      }

      if (statusCode == HttpStatus.notFound) {
        final body = await _readResponseBody(
          response.data,
          timeoutMs: request.timeout.receiveTimeoutMs,
        );
        throw AppLlmStreamException(
          failureKind: AppLlmFailureKind.modelNotFound,
          statusCode: statusCode,
          detail: _normalizeDetail(body),
        );
      }

      if (statusCode < 200 || statusCode >= 300) {
        final body = await _readResponseBody(
          response.data,
          timeoutMs: request.timeout.receiveTimeoutMs,
        );
        throw AppLlmStreamException(
          failureKind: AppLlmFailureKind.server,
          statusCode: statusCode,
          detail: _normalizeDetail(body),
        );
      }

      final body = response.data;
      if (body == null) {
        throw const AppLlmStreamException(
          failureKind: AppLlmFailureKind.invalidResponse,
          detail: '服务器返回空响应体。',
        );
      }

      yield* _parseSseDeltas(
        body,
        request.timeout.effectiveIdleTimeoutMs,
        adapter,
      );
    } on AppLlmStreamException {
      rethrow;
    } on DioException catch (error) {
      throw _mapDioExceptionToStream(error);
    } on TimeoutException {
      throw const AppLlmStreamException(
        failureKind: AppLlmFailureKind.timeout,
        detail: '请求在超时时间内未完成。',
      );
    } catch (error) {
      throw AppLlmStreamException(
        failureKind: AppLlmFailureKind.server,
        detail: AppEventLogPrivacy.sanitizeErrorDetail(error.toString()),
      );
    } finally {
      dio.close(force: true);
    }
  }

  Stream<String> _parseSseDeltas(
    ResponseBody body,
    int timeoutMs,
    AppLlmProviderAdapter adapter,
  ) {
    return body.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .timeout(Duration(milliseconds: timeoutMs))
        .handleError((Object error, StackTrace stackTrace) {
          throw const AppLlmStreamException(
            failureKind: AppLlmFailureKind.timeout,
            detail: '请求在超时时间内未完成。',
          );
        }, test: (error) => error is TimeoutException)
        .expand((line) {
          final trimmed = line.trim();
          if (!trimmed.startsWith('data:')) return <String>[];
          final payload = trimmed.substring(5).trim();
          if (payload.isEmpty || payload == '[DONE]') return <String>[];

          try {
            final decoded = jsonDecode(payload);
            if (decoded is Map) {
              final choices = decoded['choices'];
              if (choices is List && choices.isNotEmpty) {
                final firstChoice = choices.first;
                if (firstChoice is Map) {
                  final delta = firstChoice['delta'];
                  if (delta is Map) {
                    final content = normalizeLlmContent(delta['content']);
                    if (content != null && content.isNotEmpty) {
                      return <String>[content];
                    }
                  }
                }
              }
            }
          } on FormatException {
            // Skip malformed SSE payload.
          }
          final adapterText = adapter.decodeOutputText('data: $payload\n\n');
          if (adapterText != null && adapterText.isNotEmpty) {
            return <String>[adapterText];
          }
          return <String>[];
        });
  }

  AppLlmStreamException _mapDioExceptionToStream(DioException error) {
    final mapped = _mapDioException(error);
    return AppLlmStreamException(
      failureKind: mapped.failureKind,
      statusCode: mapped.statusCode,
      detail: mapped.detail,
    );
  }

  _MappedFailure _mapDioException(DioException error) {
    final response = error.response;
    final statusCode = response?.statusCode;
    final detail = _normalizeDioErrorDetail(error);
    final underlying = error.error;

    if (statusCode == HttpStatus.unauthorized ||
        statusCode == HttpStatus.forbidden) {
      return _MappedFailure(
        failureKind: AppLlmFailureKind.unauthorized,
        statusCode: statusCode,
        detail: detail,
      );
    }
    if (statusCode == HttpStatus.notFound) {
      return _MappedFailure(
        failureKind: AppLlmFailureKind.modelNotFound,
        statusCode: statusCode,
        detail: detail,
      );
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return _MappedFailure(
        failureKind: AppLlmFailureKind.timeout,
        statusCode: statusCode,
        detail: '请求在超时时间内未完成。',
      );
    }
    if (error.type == DioExceptionType.badCertificate ||
        error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.cancel) {
      return _MappedFailure(
        failureKind: AppLlmFailureKind.network,
        statusCode: statusCode,
        detail: detail,
      );
    }
    if (underlying is SocketException ||
        underlying is HttpException ||
        underlying is FormatException) {
      return _MappedFailure(
        failureKind: AppLlmFailureKind.network,
        statusCode: statusCode,
        detail: detail,
      );
    }
    return _MappedFailure(
      failureKind: statusCode == null
          ? AppLlmFailureKind.network
          : AppLlmFailureKind.server,
      statusCode: statusCode,
      detail: detail,
    );
  }

  String _normalizeDioErrorDetail(DioException error) {
    final raw = error.message ?? error.toString();
    return AppEventLogPrivacy.sanitizeErrorDetail(raw) ?? '';
  }
}

class _MappedFailure {
  const _MappedFailure({
    required this.failureKind,
    required this.statusCode,
    required this.detail,
  });

  final AppLlmFailureKind failureKind;
  final int? statusCode;
  final String? detail;
}
