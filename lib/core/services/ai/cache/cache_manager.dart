import 'dart:convert';
import 'dart:collection';

import 'package:crypto/crypto.dart';
import 'package:collection/collection.dart';

/// Prompt 缓存管理器
/// 支持 L1-L4 四层缓存策略
class PromptCacheManager {
  final int _maxMemoryCacheSize;
  final Duration _exactCacheTTL;
  final double _semanticSimilarityThreshold;

  PromptCacheManager({
    int maxMemoryCacheSize = 1000,
    Duration exactCacheTTL = const Duration(hours: 24),
    double semanticSimilarityThreshold = 0.95,
  })  : _maxMemoryCacheSize = maxMemoryCacheSize,
        _exactCacheTTL = exactCacheTTL,
        _semanticSimilarityThreshold = semanticSimilarityThreshold;

  /// L1: 内存缓存（会话内）
  final LinkedHashMap<String, CacheEntry> _memoryCache = LinkedHashMap();

  /// L2: 精确匹配缓存（跨会话）
  final Map<String, CacheEntry> _exactCache = {};

  /// L3: 语义缓存（相似请求）
  final List<SemanticCacheEntry> _semanticCache = [];

  /// 缓存层级开关
  bool enableL1 = true;
  bool enableL2 = true;
  bool enableL3 = false; // 默认关闭，需要向量支持
  bool enableL4 = true;  // 供应商级缓存

  /// 生成缓存键
  String _generateKey(String prompt, String modelId, {Map<String, dynamic>? params}) {
    final content = '$prompt|$modelId|${jsonEncode(params ?? {})}';
    return sha256.convert(utf8.encode(content)).toString();
  }

  /// 查找缓存
  CacheEntry? find(String prompt, String modelId, {Map<String, dynamic>? params}) {
    final key = _generateKey(prompt, modelId, params: params);

    // L1: 内存缓存
    if (enableL1) {
      final entry = _memoryCache[key];
      if (entry != null && !entry.isExpired) {
        return entry;
      }
    }

    // L2: 精确匹配
    if (enableL2) {
      final entry = _exactCache[key];
      if (entry != null && !entry.isExpired) {
        // 提升到 L1
        _memoryCache[key] = entry;
        _evictIfNeeded();
        return entry;
      }
    }

    // L3: 语义缓存
    if (enableL3) {
      final entry = _findSemanticMatch(prompt, modelId);
      if (entry != null) {
        return entry.entry;
      }
    }

    return null;
  }

  /// 存储到缓存
  void store(
    String prompt,
    String modelId,
    String response, {
    Map<String, dynamic>? params,
    int? inputTokens,
    int? outputTokens,
  }) {
    final key = _generateKey(prompt, modelId, params: params);
    final now = DateTime.now();

    final entry = CacheEntry(
      key: key,
      response: response,
      createdAt: now,
      expiresAt: now.add(_exactCacheTTL),
      inputTokens: inputTokens,
      outputTokens: outputTokens,
    );

    // L1
    if (enableL1) {
      _memoryCache[key] = entry;
      _evictIfNeeded();
    }

    // L2
    if (enableL2) {
      _exactCache[key] = entry;
    }
  }

  /// L3: 语义匹配查找
  SemanticCacheEntry? _findSemanticMatch(String prompt, String modelId) {
    // 这里需要向量相似度计算，简化实现使用编辑距离
    for (final entry in _semanticCache) {
      if (entry.modelId == modelId &&
          entry.similarity(prompt) >= _semanticSimilarityThreshold &&
          !entry.entry.isExpired) {
        return entry;
      }
    }
    return null;
  }

  /// 清理过期缓存
  void cleanup() {
    _memoryCache.removeWhere((_, entry) => entry.isExpired);
    _exactCache.removeWhere((_, entry) => entry.isExpired);
    _semanticCache.removeWhere((entry) => entry.entry.isExpired);
  }

  /// 清空所有缓存
  void clear() {
    _memoryCache.clear();
    _exactCache.clear();
    _semanticCache.clear();
  }

  /// 驱逐策略（LRU）
  void _evictIfNeeded() {
    while (_memoryCache.length > _maxMemoryCacheSize) {
      _memoryCache.remove(_memoryCache.keys.first);
    }
  }

  /// 统计信息
  CacheStats get stats => CacheStats(
        l1Count: _memoryCache.length,
        l2Count: _exactCache.length,
        l3Count: _semanticCache.length,
      );
}

/// 缓存条目
class CacheEntry {
  final String key;
  final String response;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int? inputTokens;
  final int? outputTokens;

  CacheEntry({
    required this.key,
    required this.response,
    required this.createdAt,
    required this.expiresAt,
    this.inputTokens,
    this.outputTokens,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// 语义缓存条目
class SemanticCacheEntry {
  final String prompt;
  final String modelId;
  final CacheEntry entry;

  SemanticCacheEntry({
    required this.prompt,
    required this.modelId,
    required this.entry,
  });

  /// 计算相似度（简化版，实际应使用向量）
  double similarity(String other) {
    // 使用 Levenshtein 距离的简化版本
    final distance = _levenshteinDistance(prompt, other);
    final maxLen = prompt.length > other.length ? prompt.length : other.length;
    if (maxLen == 0) return 1.0;
    return 1.0 - (distance / maxLen);
  }

  int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> prev = List.generate(s2.length + 1, (i) => i);
    List<int> curr = List.filled(s2.length + 1, 0);

    for (int i = 1; i <= s1.length; i++) {
      curr[0] = i;
      for (int j = 1; j <= s2.length; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        curr[j] = [
          prev[j] + 1,
          curr[j - 1] + 1,
          prev[j - 1] + cost,
        ].min;
      }
      final temp = prev;
      prev = curr;
      curr = temp;
    }

    return prev[s2.length];
  }
}

/// 缓存统计
class CacheStats {
  final int l1Count;
  final int l2Count;
  final int l3Count;

  CacheStats({
    required this.l1Count,
    required this.l2Count,
    required this.l3Count,
  });

  int get total => l1Count + l2Count + l3Count;
}
