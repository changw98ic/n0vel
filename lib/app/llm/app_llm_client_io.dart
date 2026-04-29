import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import 'app_llm_client_contract.dart';
import 'app_llm_client_types.dart';
import 'app_llm_provider_adapters.dart';

AppLlmClient createAppLlmClient() => _IoAppLlmClient();

class _IoAppLlmClient implements AppLlmClient {
  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    final adapter = AppLlmProviderAdapters.of(request.provider);
    final endpoint = _resolveEndpoint(request.baseUrl, adapter.endpointPath);
    if (endpoint == null) {
      return const AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.network,
        detail: 'base_url 无法解析为有效地址。',
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
    try {
      final response = await dio.postUri<ResponseBody>(
        endpoint,
        data: adapter.buildBody(
          model: request.model,
          messages: request.messages,
        ),
      );
      final statusCode = response.statusCode ?? 0;

      if (statusCode < 200 || statusCode >= 300) {
        final body = await _readResponseBody(
          response.data,
          timeoutMs: request.timeout.receiveTimeoutMs,
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

      final body = await _readResponseBody(
        response.data,
        timeoutMs: request.timeout.receiveTimeoutMs,
      );
      stopwatch.stop();

      final decoded = _decodeStreamedResponse(body) ?? _decodeResponse(body);
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
        detail: error.message,
      );
    } on TimeoutException {
      return const AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.timeout,
        detail: '请求在超时时间内未完成。',
      );
    } catch (error) {
      return AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.server,
        detail: error.toString(),
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

  _DecodedResponse? _decodeResponse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      return null;
    }

    String? text;
    final choices = decoded['choices'];
    if (choices is List && choices.isNotEmpty) {
      final firstChoice = choices.first;
      if (firstChoice is Map) {
        final message = firstChoice['message'];
        if (message is Map) {
          final content = message['content'];
          final normalized = _normalizeContent(content);
          if (normalized != null && normalized.isNotEmpty) {
            text = normalized;
          }
        }
      }
    }

    final response = decoded['response'];
    if (response is String && response.trim().isNotEmpty) {
      text = response;
    }

    final usage = decoded['usage'];
    int? promptTokens;
    int? completionTokens;
    int? totalTokens;
    if (usage is Map) {
      promptTokens = _toInt(usage['prompt_tokens']);
      completionTokens = _toInt(usage['completion_tokens']);
      totalTokens = _toInt(usage['total_tokens']);
    }

    if (text == null || text.trim().isEmpty) {
      return null;
    }

    return _DecodedResponse(
      text: text.trim(),
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: totalTokens,
    );
  }

  String? _normalizeContent(Object? content) {
    if (content is String) {
      return content;
    }
    if (content is List) {
      final buffer = StringBuffer();
      for (final item in content) {
        if (item is Map && item['type']?.toString() == 'text') {
          final text = item['text']?.toString() ?? '';
          if (text.isNotEmpty) {
            if (buffer.isNotEmpty) {
              buffer.write('\n');
            }
            buffer.write(text);
          }
        }
      }
      final normalized = buffer.toString().trim();
      return normalized.isEmpty ? null : normalized;
    }
    return null;
  }

  _DecodedResponse? _decodeStreamedResponse(String body) {
    final buffer = StringBuffer();
    int? promptTokens;
    int? completionTokens;
    int? totalTokens;
    for (final rawLine in const LineSplitter().convert(body)) {
      final line = rawLine.trim();
      if (!line.startsWith('data:')) {
        continue;
      }
      final payload = line.substring(5).trim();
      if (payload.isEmpty || payload == '[DONE]') {
        continue;
      }

      try {
        final decoded = jsonDecode(payload);
        if (decoded is! Map) {
          continue;
        }
        final choices = decoded['choices'];
        if (choices is List && choices.isNotEmpty) {
          final firstChoice = choices.first;
          if (firstChoice is Map) {
            final delta = firstChoice['delta'];
            if (delta is Map) {
              final content = _normalizeContent(delta['content']);
              if (content != null && content.isNotEmpty) {
                buffer.write(content);
              }
            }
          }
        }

        final usage = decoded['usage'];
        if (usage is Map) {
          promptTokens = _toInt(usage['prompt_tokens']);
          completionTokens = _toInt(usage['completion_tokens']);
          totalTokens = _toInt(usage['total_tokens']);
        }
      } on FormatException {
        continue;
      }
    }

    final normalized = buffer.toString().trim();
    if (normalized.isEmpty) {
      return null;
    }

    final filtered = stripThinkingChain(normalized);
    return _DecodedResponse(
      text: filtered.isNotEmpty ? filtered : normalized,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: totalTokens,
    );
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

  String? _normalizeDetail(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map) {
          final message = error['message']?.toString();
          if (message != null && message.trim().isNotEmpty) {
            return message.trim();
          }
        }
        final message = decoded['message']?.toString();
        if (message != null && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    } on FormatException {
      // Fall through to raw body.
    }
    return trimmed;
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) async* {
    final adapter = AppLlmProviderAdapters.of(request.provider);
    final endpoint = _resolveEndpoint(request.baseUrl, adapter.endpointPath);
    if (endpoint == null) {
      throw const AppLlmStreamException(
        failureKind: AppLlmFailureKind.network,
        detail: 'base_url 无法解析为有效地址。',
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
      final response = await dio.postUri<ResponseBody>(
        endpoint,
        data: adapter.buildBody(
          model: request.model,
          messages: request.messages,
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

      yield* _parseSseDeltas(body, request.timeout.effectiveIdleTimeoutMs);
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
        detail: error.toString(),
      );
    } finally {
      dio.close(force: true);
    }
  }

  Stream<String> _parseSseDeltas(ResponseBody body, int timeoutMs) {
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
            if (decoded is! Map) return <String>[];
            final choices = decoded['choices'];
            if (choices is! List || choices.isEmpty) return <String>[];
            final firstChoice = choices.first;
            if (firstChoice is! Map) return <String>[];
            final delta = firstChoice['delta'];
            if (delta is! Map) return <String>[];
            final content = delta['content'];
            if (content is String && content.isNotEmpty) {
              return <String>[content];
            }
          } on FormatException {
            // Skip malformed SSE payload.
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
    return error.message ?? error.toString();
  }
}

class _DecodedResponse {
  const _DecodedResponse({
    required this.text,
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
  });

  final String text;
  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;
}

int? _toInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
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
