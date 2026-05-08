import 'package:dio/dio.dart';

import '../../features/story_generation/data/story_embedding_provider.dart';

/// LRU cache key = hash of input text.
typedef _CacheKey = int;

/// [StoryEmbeddingProvider] that calls an OpenAI-compatible /embeddings endpoint
/// using the user's BYOK credentials.
class LlmEmbeddingProvider implements StoryEmbeddingProvider {
  LlmEmbeddingProvider({
    required String baseUrl,
    required String apiKey,
    required this.model,
    this.maxCacheSize = 1000,
    Dio? dio,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl,
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 30),
               headers: {
                 'Content-Type': 'application/json',
                 'Authorization': 'Bearer $apiKey',
               },
             ),
           );

  final Dio _dio;
  final String model;
  final int maxCacheSize;

  /// LRU cache: most recent at end, oldest at start.
  final Map<_CacheKey, List<double>> _cache = {};
  final List<_CacheKey> _cacheOrder = [];

  @override
  Future<List<double>> embedText(String text) async {
    final key = _hash(text);
    final cached = _cache[key];
    if (cached != null) {
      _touchCache(key);
      return cached;
    }

    final response = await _dio.post<Map<String, Object?>>(
      '/embeddings',
      data: {'model': model, 'input': text},
    );

    final embedding = _extractEmbedding(response.data);
    _putCache(key, embedding);
    return embedding;
  }

  @override
  Future<List<List<double>>> embedBatch(List<String> texts) async {
    // Check cache for all texts
    final results = List<List<double>?>.filled(texts.length, null);
    final uncachedIndices = <int>[];
    final uncachedTexts = <String>[];

    for (var i = 0; i < texts.length; i++) {
      final key = _hash(texts[i]);
      final cached = _cache[key];
      if (cached != null) {
        _touchCache(key);
        results[i] = cached;
      } else {
        uncachedIndices.add(i);
        uncachedTexts.add(texts[i]);
      }
    }

    if (uncachedTexts.isNotEmpty) {
      final response = await _dio.post<Map<String, Object?>>(
        '/embeddings',
        data: {'model': model, 'input': uncachedTexts},
      );

      final embeddings = _extractEmbeddings(response.data);
      for (var i = 0; i < uncachedIndices.length; i++) {
        final embedding = embeddings[i];
        results[uncachedIndices[i]] = embedding;
        _putCache(_hash(uncachedTexts[i]), embedding);
      }
    }

    return results.map((e) => e!).toList();
  }

  /// Health check: returns true if the embedding endpoint is reachable.
  Future<bool> isHealthy() async {
    try {
      await _dio.post<Map<String, Object?>>(
        '/embeddings',
        data: {'model': model, 'input': 'test'},
      );
      return true;
    } on Object {
      return false;
    }
  }

  List<double> _extractEmbedding(Map<String, Object?>? data) {
    if (data == null) throw FormatException('Empty embedding response');
    final dataList = data['data'] as List?;
    if (dataList == null || dataList.isEmpty) {
      throw FormatException('No embedding data in response');
    }
    final firstItem = dataList[0] as Map<String, Object?>;
    final embedding = firstItem['embedding'] as List;
    return [for (final v in embedding) (v as num).toDouble()];
  }

  List<List<double>> _extractEmbeddings(Map<String, Object?>? data) {
    if (data == null) throw FormatException('Empty embedding response');
    final dataList = data['data'] as List?;
    if (dataList == null || dataList.isEmpty) {
      throw FormatException('No embedding data in response');
    }
    return [
      for (final item in dataList)
        if (item is Map<String, Object?>)
          [for (final v in (item['embedding'] as List)) (v as num).toDouble()]
        else
          <double>[],
    ];
  }

  int _hash(String text) {
    // Simple hash for cache key
    var h = 0xcbf29ce484222325;
    for (var i = 0; i < text.length; i++) {
      h ^= text.codeUnitAt(i);
      h = (h * 0x100000001b3) & 0x7FFFFFFFFFFFFFFF;
    }
    return h;
  }

  void _touchCache(_CacheKey key) {
    _cacheOrder.remove(key);
    _cacheOrder.add(key);
  }

  void _putCache(_CacheKey key, List<double> value) {
    if (_cache.containsKey(key)) {
      _touchCache(key);
      _cache[key] = value;
      return;
    }
    // Evict oldest if at capacity
    while (_cache.length >= maxCacheSize && _cacheOrder.isNotEmpty) {
      final oldest = _cacheOrder.removeAt(0);
      _cache.remove(oldest);
    }
    _cache[key] = value;
    _cacheOrder.add(key);
  }
}
