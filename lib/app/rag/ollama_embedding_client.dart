import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Base class for failures returned by [OllamaEmbeddingClient].
sealed class OllamaEmbeddingException implements Exception {
  const OllamaEmbeddingException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Ollama returned a non-success HTTP status.
final class OllamaEmbeddingHttpException extends OllamaEmbeddingException {
  const OllamaEmbeddingHttpException({
    required this.statusCode,
    required this.responseBody,
  }) : super('Ollama returned HTTP $statusCode.');

  final int statusCode;
  final String responseBody;
}

/// Ollama returned a response that does not match the `/api/embed` contract.
final class OllamaEmbeddingProtocolException extends OllamaEmbeddingException {
  const OllamaEmbeddingProtocolException(super.message);
}

/// An embedding does not have the configured number of dimensions.
final class OllamaEmbeddingDimensionException extends OllamaEmbeddingException {
  OllamaEmbeddingDimensionException({
    required this.expected,
    required this.actual,
    required this.embeddingIndex,
  }) : super(
         'Embedding $embeddingIndex has $actual dimensions; expected $expected.',
       );

  final int expected;
  final int actual;
  final int embeddingIndex;
}

/// The request did not complete within the configured timeout.
final class OllamaEmbeddingTimeoutException extends OllamaEmbeddingException {
  OllamaEmbeddingTimeoutException(this.timeout)
    : super('Ollama embedding request timed out after $timeout.');

  final Duration timeout;
}

/// A transport-level failure occurred while communicating with Ollama.
final class OllamaEmbeddingTransportException extends OllamaEmbeddingException {
  OllamaEmbeddingTransportException(this.cause)
    : super('Could not communicate with Ollama: $cause');

  final Object cause;
}

/// The configured model is not present in Ollama's `/api/tags` response.
final class OllamaEmbeddingModelNotFoundException
    extends OllamaEmbeddingException {
  OllamaEmbeddingModelNotFoundException(this.model)
    : super('Ollama model "$model" was not found.');

  final String model;
}

/// Stable model identity and embedding metadata reported by Ollama.
class OllamaEmbeddingModelInfo {
  const OllamaEmbeddingModelInfo({
    required this.name,
    required this.model,
    required this.digest,
    required this.embeddingLength,
    required this.quantization,
  });

  final String name;
  final String model;
  final String digest;
  final int? embeddingLength;
  final String? quantization;
}

/// Minimal Ollama `/api/embed` client backed only by [HttpClient].
class OllamaEmbeddingClient {
  factory OllamaEmbeddingClient({
    required String model,
    required int expectedDimensions,
    String baseUrl = 'http://127.0.0.1:11434',
    Duration requestTimeout = const Duration(seconds: 30),
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
    if (requestTimeout <= Duration.zero) {
      throw ArgumentError.value(
        requestTimeout,
        'requestTimeout',
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

    return OllamaEmbeddingClient._(
      model: normalizedModel,
      expectedDimensions: expectedDimensions,
      baseUrl: parsedBaseUrl,
      requestTimeout: requestTimeout,
      httpClient: httpClient ?? HttpClient(),
      ownsHttpClient: httpClient == null,
    );
  }

  OllamaEmbeddingClient._({
    required this.model,
    required this.expectedDimensions,
    required this.baseUrl,
    required this.requestTimeout,
    required HttpClient httpClient,
    required bool ownsHttpClient,
  }) : _httpClient = httpClient,
       _ownsHttpClient = ownsHttpClient;

  final String model;
  final int expectedDimensions;
  final Uri baseUrl;
  final Duration requestTimeout;
  final HttpClient _httpClient;
  final bool _ownsHttpClient;

  Uri get endpoint => baseUrl.resolve('/api/embed');

  Uri get tagsEndpoint => baseUrl.resolve('/api/tags');

  Future<List<double>> embed(String input) async {
    final embeddings = await embedAll([input]);
    return embeddings.single;
  }

  Future<List<List<double>>> embedAll(List<String> inputs) async {
    if (inputs.isEmpty) return const [];

    HttpClientRequest? activeRequest;
    try {
      final requestFuture = () async {
        activeRequest = await _httpClient.postUrl(endpoint);
        activeRequest!.headers.contentType = ContentType.json;
        activeRequest!.write(jsonEncode({'model': model, 'input': inputs}));

        final response = await activeRequest!.close();
        final responseBody = await response.transform(utf8.decoder).join();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw OllamaEmbeddingHttpException(
            statusCode: response.statusCode,
            responseBody: _truncate(responseBody),
          );
        }

        return _decodeEmbeddings(responseBody, expectedCount: inputs.length);
      }();

      return await requestFuture.timeout(
        requestTimeout,
        onTimeout: () {
          activeRequest?.abort();
          throw OllamaEmbeddingTimeoutException(requestTimeout);
        },
      );
    } on OllamaEmbeddingException {
      rethrow;
    } on TimeoutException {
      activeRequest?.abort();
      throw OllamaEmbeddingTimeoutException(requestTimeout);
    } on Object catch (error) {
      throw OllamaEmbeddingTransportException(error);
    }
  }

  /// Reads `/api/tags` and returns the configured model's local identity.
  ///
  /// Both `name` and `model` are considered. Ollama's implicit `:latest` tag
  /// is treated as equivalent to an untagged configured model name.
  Future<OllamaEmbeddingModelInfo> fetchModelInfo() async {
    HttpClientRequest? activeRequest;
    try {
      final requestFuture = () async {
        activeRequest = await _httpClient.getUrl(tagsEndpoint);
        final response = await activeRequest!.close();
        final responseBody = await response.transform(utf8.decoder).join();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw OllamaEmbeddingHttpException(
            statusCode: response.statusCode,
            responseBody: _truncate(responseBody),
          );
        }
        return _decodeModelInfo(responseBody);
      }();

      return await requestFuture.timeout(
        requestTimeout,
        onTimeout: () {
          activeRequest?.abort();
          throw OllamaEmbeddingTimeoutException(requestTimeout);
        },
      );
    } on OllamaEmbeddingException {
      rethrow;
    } on TimeoutException {
      activeRequest?.abort();
      throw OllamaEmbeddingTimeoutException(requestTimeout);
    } on Object catch (error) {
      throw OllamaEmbeddingTransportException(error);
    }
  }

  List<List<double>> _decodeEmbeddings(
    String responseBody, {
    required int expectedCount,
  }) {
    final Object? decoded;
    try {
      decoded = jsonDecode(responseBody);
    } on FormatException catch (error) {
      throw OllamaEmbeddingProtocolException(
        'Ollama returned invalid JSON: ${error.message}',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const OllamaEmbeddingProtocolException(
        'Ollama response must be a JSON object.',
      );
    }
    final rawEmbeddings = decoded['embeddings'];
    if (rawEmbeddings is! List) {
      throw const OllamaEmbeddingProtocolException(
        'Ollama response is missing an embeddings array.',
      );
    }
    if (rawEmbeddings.length != expectedCount) {
      throw OllamaEmbeddingProtocolException(
        'Ollama returned ${rawEmbeddings.length} embeddings for '
        '$expectedCount inputs.',
      );
    }

    final result = <List<double>>[];
    for (
      var embeddingIndex = 0;
      embeddingIndex < rawEmbeddings.length;
      embeddingIndex++
    ) {
      final rawEmbedding = rawEmbeddings[embeddingIndex];
      if (rawEmbedding is! List) {
        throw OllamaEmbeddingProtocolException(
          'Embedding $embeddingIndex must be an array.',
        );
      }
      if (rawEmbedding.length != expectedDimensions) {
        throw OllamaEmbeddingDimensionException(
          expected: expectedDimensions,
          actual: rawEmbedding.length,
          embeddingIndex: embeddingIndex,
        );
      }

      final embedding = <double>[];
      for (var valueIndex = 0; valueIndex < rawEmbedding.length; valueIndex++) {
        final rawValue = rawEmbedding[valueIndex];
        if (rawValue is! num || !rawValue.toDouble().isFinite) {
          throw OllamaEmbeddingProtocolException(
            'Embedding $embeddingIndex contains a non-finite numeric value '
            'at index $valueIndex.',
          );
        }
        embedding.add(rawValue.toDouble());
      }
      result.add(List<double>.unmodifiable(embedding));
    }
    return List<List<double>>.unmodifiable(result);
  }

  OllamaEmbeddingModelInfo _decodeModelInfo(String responseBody) {
    final Object? decoded;
    try {
      decoded = jsonDecode(responseBody);
    } on FormatException catch (error) {
      throw OllamaEmbeddingProtocolException(
        'Ollama returned invalid JSON: ${error.message}',
      );
    }
    if (decoded is! Map<String, dynamic> || decoded['models'] is! List) {
      throw const OllamaEmbeddingProtocolException(
        'Ollama tags response is missing a models array.',
      );
    }

    Map<String, dynamic>? matched;
    Map<String, dynamic>? aliasMatched;
    for (final candidate in decoded['models'] as List) {
      if (candidate is! Map<String, dynamic>) continue;
      final candidateName = candidate['name'];
      final candidateModel = candidate['model'];
      if (candidateName == model || candidateModel == model) {
        matched = candidate;
        break;
      }
      if ((candidateName is String &&
              _withoutLatestTag(candidateName) == model) ||
          (candidateModel is String &&
              _withoutLatestTag(candidateModel) == model)) {
        aliasMatched ??= candidate;
      }
    }
    matched ??= aliasMatched;
    if (matched == null) {
      throw OllamaEmbeddingModelNotFoundException(model);
    }

    final name = matched['name'];
    final matchedModel = matched['model'];
    final digest = matched['digest'];
    if (name is! String || matchedModel is! String || digest is! String) {
      throw const OllamaEmbeddingProtocolException(
        'Matched Ollama model is missing name, model, or digest.',
      );
    }
    final details = matched['details'];
    if (details != null && details is! Map<String, dynamic>) {
      throw const OllamaEmbeddingProtocolException(
        'Matched Ollama model details must be an object.',
      );
    }
    final rawEmbeddingLength = details?['embedding_length'];
    final embeddingLength = switch (rawEmbeddingLength) {
      null => null,
      final int value => value,
      final num value when value == value.roundToDouble() => value.toInt(),
      final String value => int.tryParse(value),
      _ => null,
    };
    if (rawEmbeddingLength != null && embeddingLength == null) {
      throw const OllamaEmbeddingProtocolException(
        'Ollama model embedding_length must be an integer.',
      );
    }
    final rawQuantization =
        details?['quantization_level'] ?? details?['quantization'];
    if (rawQuantization != null && rawQuantization is! String) {
      throw const OllamaEmbeddingProtocolException(
        'Ollama model quantization must be a string.',
      );
    }

    return OllamaEmbeddingModelInfo(
      name: name,
      model: matchedModel,
      digest: digest,
      embeddingLength: embeddingLength,
      quantization: rawQuantization as String?,
    );
  }

  /// Closes the internally-created HTTP client.
  ///
  /// Injected clients remain owned by the caller and are not closed here.
  void close({bool force = false}) {
    if (_ownsHttpClient) _httpClient.close(force: force);
  }

  static String _truncate(String value) {
    const maxRunes = 4096;
    final runes = value.runes;
    if (runes.length <= maxRunes) return value;
    return '${String.fromCharCodes(runes.take(maxRunes))}…';
  }

  static String _withoutLatestTag(String value) =>
      value.endsWith(':latest') ? value.substring(0, value.length - 7) : value;
}
