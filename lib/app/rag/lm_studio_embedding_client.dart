import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/dart.dart';

sealed class LmStudioEmbeddingException implements Exception {
  const LmStudioEmbeddingException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

final class LmStudioEmbeddingHttpException extends LmStudioEmbeddingException {
  const LmStudioEmbeddingHttpException({
    required this.statusCode,
    required this.responseBody,
  }) : super('LM Studio returned HTTP $statusCode.');

  final int statusCode;
  final String responseBody;
}

final class LmStudioEmbeddingProtocolException
    extends LmStudioEmbeddingException {
  const LmStudioEmbeddingProtocolException(super.message);
}

final class LmStudioEmbeddingModelNotFoundException
    extends LmStudioEmbeddingException {
  LmStudioEmbeddingModelNotFoundException(String model)
    : super('LM Studio embedding model "$model" was not found.');
}

final class LmStudioEmbeddingTimeoutException
    extends LmStudioEmbeddingException {
  LmStudioEmbeddingTimeoutException(Duration timeout)
    : super('LM Studio request timed out after $timeout.');
}

final class LmStudioEmbeddingTransportException
    extends LmStudioEmbeddingException {
  LmStudioEmbeddingTransportException(Object cause)
    : super('Could not communicate with LM Studio: $cause');
}

class LmStudioEmbeddingModelInfo {
  const LmStudioEmbeddingModelInfo({
    required this.model,
    required this.quantization,
    required this.sizeBytes,
    this.embeddingDimensions,
    this.contextLength,
  });

  final String model;
  final String? quantization;
  final int? sizeBytes;
  final int? embeddingDimensions;
  final int? contextLength;
}

enum EmbeddingServerMetadataApi { lmStudio, llamaCpp }

/// Minimal LM Studio client for its OpenAI-compatible embeddings endpoint.
class LmStudioEmbeddingClient {
  static const _behaviorProbes = <String>['novel-writer模型身份探针甲', '灰雾剑气都市身份探针乙'];

  factory LmStudioEmbeddingClient({
    required String model,
    required int expectedDimensions,
    required String baseUrl,
    Duration requestTimeout = const Duration(seconds: 30),
    EmbeddingServerMetadataApi metadataApi =
        EmbeddingServerMetadataApi.lmStudio,
    bool allowBehaviorDrift = false,
    HttpClient? httpClient,
  }) {
    final normalizedModel = model.trim();
    if (normalizedModel.isEmpty) {
      throw ArgumentError.value(model, 'model', 'must not be empty');
    }
    if (expectedDimensions <= 0) {
      throw ArgumentError.value(
        expectedDimensions,
        'expectedDimensions',
        'must be greater than zero',
      );
    }
    final parsedBaseUrl = Uri.tryParse(baseUrl);
    if (parsedBaseUrl == null ||
        !parsedBaseUrl.hasAuthority ||
        (parsedBaseUrl.scheme != 'http' && parsedBaseUrl.scheme != 'https')) {
      throw ArgumentError.value(
        baseUrl,
        'baseUrl',
        'must be an absolute HTTP(S) URL',
      );
    }
    if (requestTimeout <= Duration.zero) {
      throw ArgumentError.value(
        requestTimeout,
        'requestTimeout',
        'must be greater than zero',
      );
    }
    return LmStudioEmbeddingClient._(
      model: normalizedModel,
      expectedDimensions: expectedDimensions,
      baseUrl: parsedBaseUrl,
      requestTimeout: requestTimeout,
      metadataApi: metadataApi,
      allowBehaviorDrift: allowBehaviorDrift,
      httpClient: httpClient ?? HttpClient(),
      ownsHttpClient: httpClient == null,
    );
  }

  LmStudioEmbeddingClient._({
    required this.model,
    required this.expectedDimensions,
    required this.baseUrl,
    required this.requestTimeout,
    required this.metadataApi,
    required this.allowBehaviorDrift,
    required HttpClient httpClient,
    required bool ownsHttpClient,
  }) : _httpClient = httpClient,
       _ownsHttpClient = ownsHttpClient;

  final String model;
  final int expectedDimensions;
  final Uri baseUrl;
  final Duration requestTimeout;
  final EmbeddingServerMetadataApi metadataApi;
  final bool allowBehaviorDrift;
  final HttpClient _httpClient;
  final bool _ownsHttpClient;

  Uri get embeddingsEndpoint => baseUrl.resolve('/v1/embeddings');
  Uri get modelsEndpoint => baseUrl.resolve(
    metadataApi == EmbeddingServerMetadataApi.lmStudio
        ? '/api/v1/models'
        : '/v1/models',
  );

  Future<List<double>> embed(String input) async =>
      (await embedAll([input])).single;

  Future<List<List<double>>> embedAll(List<String> inputs) async {
    if (inputs.isEmpty) return const [];
    final body = await _request(
      method: 'POST',
      endpoint: embeddingsEndpoint,
      payload: {'model': model, 'input': inputs},
    );
    return _decodeEmbeddings(body, expectedCount: inputs.length);
  }

  /// Fingerprints observable behavior when the server cannot expose the source
  /// model file's cryptographic digest.
  Future<String> fetchBehaviorFingerprint() async {
    return _fingerprintEmbeddings(await embedAll(_behaviorProbes));
  }

  /// Embeds application inputs and verifies model behavior in the same HTTP
  /// request, avoiding a second inference round trip at every checkpoint.
  Future<List<List<double>>> embedAllVerifyingBehavior(
    List<String> inputs, {
    required String expectedFingerprint,
  }) async {
    if (inputs.isEmpty) return const [];
    final combined = await embedAll([...inputs, ..._behaviorProbes]);
    final applicationCount = inputs.length;
    final fingerprint = _fingerprintEmbeddings(
      combined.sublist(applicationCount),
    );
    if (fingerprint != expectedFingerprint && !allowBehaviorDrift) {
      throw const LmStudioEmbeddingProtocolException(
        'Embedding server model behavior changed during indexing.',
      );
    }
    return List<List<double>>.unmodifiable(
      combined.sublist(0, applicationCount),
    );
  }

  String _fingerprintEmbeddings(List<List<double>> embeddings) {
    final header = utf8.encode('lmstudio-embedding-behavior-v1\u0000');
    final valueCount = embeddings.fold<int>(
      0,
      (count, embedding) => count + embedding.length,
    );
    final bytes = ByteData(header.length + valueCount * 4);
    for (var index = 0; index < header.length; index++) {
      bytes.setUint8(index, header[index]);
    }
    var offset = header.length;
    for (final embedding in embeddings) {
      for (final value in embedding) {
        bytes.setFloat32(offset, value, Endian.little);
        offset += 4;
      }
    }
    final digest = const DartSha256()
        .hashSync(bytes.buffer.asUint8List())
        .bytes;
    return 'sha256:${digest.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}';
  }

  Future<LmStudioEmbeddingModelInfo> fetchModelInfo() async {
    final body = await _request(method: 'GET', endpoint: modelsEndpoint);
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException catch (error) {
      throw LmStudioEmbeddingProtocolException(
        'LM Studio returned invalid model JSON: ${error.message}',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const LmStudioEmbeddingProtocolException(
        'Embedding server returned an invalid model response.',
      );
    }
    if (metadataApi == EmbeddingServerMetadataApi.llamaCpp) {
      return _decodeLlamaCppModelInfo(decoded);
    }
    if (decoded['models'] is! List) {
      throw const LmStudioEmbeddingProtocolException(
        'LM Studio model response is missing a models array.',
      );
    }
    for (final raw in decoded['models'] as List) {
      if (raw is! Map) continue;
      final entry = Map<String, Object?>.from(raw);
      if (entry['key']?.toString() != model) continue;
      if (entry['type']?.toString() != 'embedding') {
        throw LmStudioEmbeddingProtocolException(
          'LM Studio reports "$model" as ${entry['type']}, not embedding.',
        );
      }
      final quantization = entry['quantization'];
      final quantizationName = quantization is Map
          ? quantization['name']?.toString()
          : null;
      final rawSizeBytes = entry['size_bytes'];
      final sizeBytes = switch (rawSizeBytes) {
        null => null,
        final int value => value,
        final num value when value.isFinite && value == value.roundToDouble() =>
          value.toInt(),
        _ => throw const LmStudioEmbeddingProtocolException(
          'LM Studio model size_bytes is not an integer.',
        ),
      };
      return LmStudioEmbeddingModelInfo(
        model: model,
        quantization: quantizationName,
        sizeBytes: sizeBytes,
      );
    }
    throw LmStudioEmbeddingModelNotFoundException(model);
  }

  LmStudioEmbeddingModelInfo _decodeLlamaCppModelInfo(
    Map<String, dynamic> decoded,
  ) {
    if (decoded['data'] is! List) {
      throw const LmStudioEmbeddingProtocolException(
        'llama.cpp model response is missing a data array.',
      );
    }
    for (final raw in decoded['data'] as List) {
      if (raw is! Map || raw['id']?.toString() != model) continue;
      final meta = raw['meta'];
      if (meta is! Map) {
        throw const LmStudioEmbeddingProtocolException(
          'llama.cpp model response is missing model metadata.',
        );
      }
      final dimensions = _metadataInteger(meta['n_embd'], 'n_embd');
      if (dimensions != expectedDimensions) {
        throw LmStudioEmbeddingProtocolException(
          'llama.cpp reports n_embd=$dimensions; expected '
          '$expectedDimensions.',
        );
      }
      return LmStudioEmbeddingModelInfo(
        model: model,
        quantization: meta['ftype']?.toString(),
        sizeBytes: _optionalMetadataInteger(meta['size'], 'size'),
        embeddingDimensions: dimensions,
        contextLength: _optionalMetadataInteger(meta['n_ctx'], 'n_ctx'),
      );
    }
    throw LmStudioEmbeddingModelNotFoundException(model);
  }

  static int _metadataInteger(Object? value, String field) {
    final parsed = _optionalMetadataInteger(value, field);
    if (parsed == null) {
      throw LmStudioEmbeddingProtocolException(
        'Embedding server model metadata is missing $field.',
      );
    }
    return parsed;
  }

  static int? _optionalMetadataInteger(Object? value, String field) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num && value.isFinite && value == value.roundToDouble()) {
      return value.toInt();
    }
    throw LmStudioEmbeddingProtocolException(
      'Embedding server model metadata $field is not an integer.',
    );
  }

  Future<String> _request({
    required String method,
    required Uri endpoint,
    Object? payload,
  }) async {
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      HttpClientRequest? activeRequest;
      try {
        final future = () async {
          activeRequest = method == 'POST'
              ? await _httpClient.postUrl(endpoint)
              : await _httpClient.getUrl(endpoint);
          if (payload != null) {
            activeRequest!.headers.contentType = ContentType.json;
            activeRequest!.write(jsonEncode(payload));
          }
          final response = await activeRequest!.close();
          final body = await response.transform(utf8.decoder).join();
          if (response.statusCode < 200 || response.statusCode >= 300) {
            throw LmStudioEmbeddingHttpException(
              statusCode: response.statusCode,
              responseBody: _truncate(body),
            );
          }
          return body;
        }();
        return await future.timeout(
          requestTimeout,
          onTimeout: () {
            activeRequest?.abort();
            throw LmStudioEmbeddingTimeoutException(requestTimeout);
          },
        );
      } on LmStudioEmbeddingHttpException {
        rethrow;
      } on LmStudioEmbeddingException catch (error) {
        if (attempt == maxAttempts) rethrow;
        activeRequest?.abort();
        await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
        if (error is LmStudioEmbeddingTimeoutException) continue;
      } on TimeoutException {
        activeRequest?.abort();
        if (attempt == maxAttempts) {
          throw LmStudioEmbeddingTimeoutException(requestTimeout);
        }
        await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
      } on Object catch (error) {
        activeRequest?.abort();
        if (attempt == maxAttempts) {
          throw LmStudioEmbeddingTransportException(error);
        }
        await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
      }
    }
    throw StateError('Embedding request retry loop exhausted');
  }

  List<List<double>> _decodeEmbeddings(
    String responseBody, {
    required int expectedCount,
  }) {
    final Object? decoded;
    try {
      decoded = jsonDecode(responseBody);
    } on FormatException catch (error) {
      throw LmStudioEmbeddingProtocolException(
        'LM Studio returned invalid embedding JSON: ${error.message}',
      );
    }
    if (decoded is! Map<String, dynamic> || decoded['data'] is! List) {
      throw const LmStudioEmbeddingProtocolException(
        'LM Studio response is missing a data array.',
      );
    }
    if (decoded['model'] is! String || decoded['model'] != model) {
      throw LmStudioEmbeddingProtocolException(
        'LM Studio response model ${decoded['model']} does not match $model.',
      );
    }
    final rawData = decoded['data'] as List;
    if (rawData.length != expectedCount) {
      throw LmStudioEmbeddingProtocolException(
        'LM Studio returned ${rawData.length} embeddings for '
        '$expectedCount inputs.',
      );
    }
    final ordered = List<List<double>?>.filled(expectedCount, null);
    for (var position = 0; position < rawData.length; position++) {
      final raw = rawData[position];
      if (raw is! Map || raw['embedding'] is! List) {
        throw LmStudioEmbeddingProtocolException(
          'Embedding response item $position is invalid.',
        );
      }
      if (raw['index'] is! int) {
        throw LmStudioEmbeddingProtocolException(
          'Embedding response item $position is missing an integer index.',
        );
      }
      final index = raw['index'] as int;
      if (index < 0 || index >= expectedCount || ordered[index] != null) {
        throw LmStudioEmbeddingProtocolException(
          'Embedding response contains invalid index $index.',
        );
      }
      final values = raw['embedding'] as List;
      if (values.length != expectedDimensions) {
        throw LmStudioEmbeddingProtocolException(
          'Embedding $index has ${values.length} dimensions; expected '
          '$expectedDimensions.',
        );
      }
      final vector = <double>[];
      for (var valueIndex = 0; valueIndex < values.length; valueIndex++) {
        final value = values[valueIndex];
        if (value is! num || !value.toDouble().isFinite) {
          throw LmStudioEmbeddingProtocolException(
            'Embedding $index contains an invalid value at $valueIndex.',
          );
        }
        vector.add(value.toDouble());
      }
      ordered[index] = List<double>.unmodifiable(vector);
    }
    return List<List<double>>.unmodifiable(ordered.cast<List<double>>());
  }

  void close({bool force = false}) {
    if (_ownsHttpClient) _httpClient.close(force: force);
  }

  static String _truncate(String value) =>
      value.length <= 4096 ? value : '${value.substring(0, 4096)}…';
}
