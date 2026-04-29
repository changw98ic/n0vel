import 'package:dio/dio.dart';

import 'openviking_models.dart';
import 'rag_config.dart';

/// HTTP client for the OpenViking RAG server.
class OpenVikingClient {
  OpenVikingClient({RagConfig config = const RagConfig()})
      : _config = config,
        _dio = Dio(BaseOptions(
          baseUrl: config.serverUrl,
          connectTimeout: Duration(milliseconds: config.connectTimeoutMs),
          receiveTimeout: Duration(milliseconds: config.receiveTimeoutMs),
          headers: {'Content-Type': 'application/json'},
        ));

  final RagConfig _config;
  final Dio _dio;

  /// Adds a resource at the given path.
  Future<void> addResource({
    required String path,
    required String content,
    Map<String, Object?>? metadata,
  }) async {
    await _dio.post<void>(
      '/v1/resources',
      data: {
        'path': path,
        'content': content,
        if (metadata != null) 'metadata': metadata,
      },
    );
  }

  /// Semantic search for resources matching [query].
  Future<OpenVikingFindResponse> find({
    required String query,
    String? pathPrefix,
    int? limit,
    double? scoreThreshold,
  }) async {
    final response = await _dio.post<Map<String, Object?>>(
      '/v1/find',
      data: {
        'query': query,
        if (pathPrefix != null) 'pathPrefix': pathPrefix,
        'limit': limit ?? _config.defaultLimit,
        'scoreThreshold': scoreThreshold ?? _config.scoreThreshold,
      },
    );
    return OpenVikingFindResponse.fromJson(response.data ?? {});
  }

  /// Reads a resource at the given path.
  Future<String> read(String path) async {
    final response = await _dio.get<Map<String, Object?>>(
      '/v1/resources/$path',
    );
    return response.data?['content']?.toString() ?? '';
  }

  /// Lists resources under the given path.
  Future<List<OpenVikingResourceInfo>> ls(String path) async {
    final response = await _dio.get<Map<String, Object?>>(
      '/v1/ls/$path',
    );
    final items = response.data?['items'];
    if (items is! List) return const [];
    return [
      for (final item in items)
        if (item is Map)
          OpenVikingResourceInfo.fromJson(Map<String, Object?>.from(item)),
    ];
  }

  /// Creates a directory at the given path.
  Future<void> mkdir(String path) async {
    await _dio.post<void>('/v1/mkdir', data: {'path': path});
  }

  /// Health check: returns true if server is reachable.
  Future<bool> isHealthy() async {
    try {
      await _dio.get<void>('/v1/health');
      return true;
    } on DioException {
      return false;
    }
  }

  RagConfig get config => _config;
}
