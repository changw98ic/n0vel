import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import 'app_http_client.dart';
import 'app_llm_client_contract.dart';
import 'app_llm_client_types.dart';
import 'token_usage.dart';

class LlmGateway implements AppLlmClient {
  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    final endpoint = _chatCompletionsUri(request.baseUrl);
    if (endpoint == null) {
      return const AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.network,
        detail: 'base_url 无法解析为有效地址。',
      );
    }

    final dio = AppHttpClient.shared;
    final stopwatch = Stopwatch()..start();

    try {
      final result = await (() async {
        final response = await dio.postUri<ResponseBody>(
          endpoint,
          data: <String, Object?>{
            'model': request.model,
            'messages': [
              for (final message in request.messages) message.toJson(),
            ],
            'stream': true,
          },
          options: Options(
            connectTimeout: Duration(milliseconds: request.timeoutMs),
            receiveTimeout: Duration(milliseconds: request.timeoutMs),
            sendTimeout: Duration(milliseconds: request.timeoutMs),
            responseType: ResponseType.stream,
            headers: {
              if (request.apiKey.trim().isNotEmpty)
                HttpHeaders.authorizationHeader:
                    'Bearer ${request.apiKey.trim()}',
            },
          ),
        );
        final statusCode = response.statusCode ?? 0;
        final streamed = await _readStreamedBody(
          response.data,
          timeoutMs: request.timeoutMs,
          onPartialText: request.onPartialText,
        );

        if (statusCode == HttpStatus.unauthorized ||
            statusCode == HttpStatus.forbidden) {
          return AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.unauthorized,
            statusCode: statusCode,
            detail: _normalizeDetail(streamed.rawBody),
          );
        }

        if (statusCode == HttpStatus.notFound) {
          return AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.modelNotFound,
            statusCode: statusCode,
            detail: _normalizeDetail(streamed.rawBody),
          );
        }

        if (statusCode < 200 || statusCode >= 300) {
          return AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.server,
            statusCode: statusCode,
            detail: _normalizeDetail(streamed.rawBody),
          );
        }

        final text = streamed.text.trim();
        if (text.isEmpty) {
          final fallbackText = _decodeNonStreamedText(streamed.rawBody);
          if (fallbackText == null || fallbackText.trim().isEmpty) {
            return AppLlmChatResult.failure(
              failureKind: AppLlmFailureKind.invalidResponse,
              statusCode: statusCode,
              detail: '模型返回成功，但响应体里没有可用文本。',
            );
          }
          return AppLlmChatResult.success(
            text: fallbackText.trim(),
            latencyMs: stopwatch.elapsedMilliseconds,
          );
        }

        return AppLlmChatResult.success(
          text: text,
          latencyMs: stopwatch.elapsedMilliseconds,
          tokenUsage: streamed.tokenUsage,
        );
      })().timeout(Duration(milliseconds: request.timeoutMs));
      stopwatch.stop();
      return result;
    } on DioException catch (error) {
      final mapped = _mapDioException(error);
      return AppLlmChatResult.failure(
        failureKind: mapped.failureKind,
        statusCode: mapped.statusCode,
        detail: mapped.detail,
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
    }
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) async* {
    final result = await chat(request);
    if (result.succeeded) {
      final text = result.text;
      if (text != null && text.isNotEmpty) {
        yield text;
      }
      return;
    }
    throw AppLlmStreamException(
      failureKind: result.failureKind ?? AppLlmFailureKind.server,
      statusCode: result.statusCode,
      detail: result.detail,
    );
  }

  Future<_StreamedResult> _readStreamedBody(
    ResponseBody? body, {
    required int timeoutMs,
    void Function(String chunk)? onPartialText,
  }) async {
    if (body == null) {
      return const _StreamedResult(rawBody: '', text: '');
    }

    final textBuffer = StringBuffer();
    final rawBuffer = StringBuffer();
    TokenUsage? usage;
    String? lineBuffer;

    await for (final chunk in body.stream.timeout(
      Duration(milliseconds: timeoutMs),
    )) {
      final decoded = utf8.decode(chunk, allowMalformed: true);
      rawBuffer.write(decoded);

      final parts = decoded.split('\n');
      for (var i = 0; i < parts.length; i++) {
        if (i < parts.length - 1) {
          final line = (lineBuffer != null ? lineBuffer + parts[i] : parts[i])
              .trim();
          lineBuffer = null;
          _processSseLine(
            line,
            textBuffer: textBuffer,
            onPartialText: onPartialText,
            onUsage: (u) => usage = u,
          );
        } else {
          lineBuffer = (lineBuffer != null ? lineBuffer + parts[i] : parts[i]);
        }
      }
    }

    if (lineBuffer != null) {
      _processSseLine(
        lineBuffer.trim(),
        textBuffer: textBuffer,
        onPartialText: onPartialText,
        onUsage: (u) => usage = u,
      );
    }

    return _StreamedResult(
      rawBody: rawBuffer.toString(),
      text: textBuffer.toString(),
      tokenUsage: usage,
    );
  }

  void _processSseLine(
    String line, {
    required StringBuffer textBuffer,
    void Function(String chunk)? onPartialText,
    void Function(TokenUsage usage)? onUsage,
  }) {
    if (!line.startsWith('data:')) return;
    final payload = line.substring(5).trim();
    if (payload.isEmpty || payload == '[DONE]') return;

    Object? decoded;
    try {
      decoded = jsonDecode(payload);
    } on FormatException {
      return;
    }
    if (decoded is! Map) return;

    final choices = decoded['choices'];
    if (choices is List && choices.isNotEmpty) {
      final firstChoice = choices.first;
      if (firstChoice is Map) {
        final delta = firstChoice['delta'];
        if (delta is Map) {
          final content = delta['content'];
          if (content is String && content.isNotEmpty) {
            textBuffer.write(content);
            onPartialText?.call(content);
          }
        }
      }
    }

    final usageJson = decoded['usage'];
    if (usageJson is Map) {
      onUsage?.call(TokenUsage.fromJson(usageJson.cast<String, Object?>()));
    }
  }

  Uri? _chatCompletionsUri(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.isEmpty) return null;
    final baseUri = Uri.tryParse(trimmed);
    if (baseUri == null) return null;
    final needsTrailingSlash = trimmed.endsWith('/');
    final normalized = needsTrailingSlash ? trimmed : '$trimmed/';
    return Uri.tryParse('${normalized}chat/completions');
  }

  String? _decodeNonStreamedText(String body) {
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;

    final choices = decoded['choices'];
    if (choices is List && choices.isNotEmpty) {
      final firstChoice = choices.first;
      if (firstChoice is Map) {
        final message = firstChoice['message'];
        if (message is Map) {
          return _normalizeContent(message['content']);
        }
      }
    }

    final response = decoded['response'];
    if (response is String && response.trim().isNotEmpty) {
      return response;
    }

    return null;
  }

  String? _normalizeContent(Object? content) {
    if (content is String) return content;
    if (content is List) {
      final buffer = StringBuffer();
      for (final item in content) {
        if (item is Map && item['type']?.toString() == 'text') {
          final text = item['text']?.toString() ?? '';
          if (text.isNotEmpty) {
            if (buffer.isNotEmpty) buffer.write('\n');
            buffer.write(text);
          }
        }
      }
      final normalized = buffer.toString().trim();
      return normalized.isEmpty ? null : normalized;
    }
    return null;
  }

  String? _normalizeDetail(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;
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
        if (message != null && message.trim().isNotEmpty) return message.trim();
      }
    } on FormatException {
      return trimmed;
    }
    return trimmed;
  }

  _MappedFailure _mapDioException(DioException error) {
    final response = error.response;
    final statusCode = response?.statusCode;
    final detail = error.message ?? error.toString();

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
    final underlying = error.error;
    if (error.type == DioExceptionType.badCertificate ||
        error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.cancel ||
        underlying is SocketException ||
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
}

class _StreamedResult {
  const _StreamedResult({
    required this.rawBody,
    required this.text,
    this.tokenUsage,
  });

  final String rawBody;
  final String text;
  final TokenUsage? tokenUsage;
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
