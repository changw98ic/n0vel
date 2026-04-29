import 'dart:collection';

import 'app_llm_client_contract.dart';
import 'app_llm_client_types.dart';

int _requestFingerprint(AppLlmChatRequest request) {
  return Object.hash(
    request.baseUrl,
    request.apiKey,
    request.model,
    Object.hashAll(request.messages.map((m) => Object.hash(m.role, m.content))),
  );
}

class _CacheEntry {
  _CacheEntry({required this.result, required this.createdAtMs});

  final AppLlmChatResult result;
  final int createdAtMs;
}

/// A caching decorator for [AppLlmClient] that returns cached successful
/// responses for identical requests within a configurable TTL.
///
/// When the same prompt (same model, base URL, API key, and messages) is
/// submitted again before the entry expires, the cached result is returned
/// without hitting the upstream LLM endpoint. Only successful responses are
/// cached. Entries are evicted in FIFO order once [maxEntries] is exceeded.
class AppLlmResponseCache implements AppLlmClient {
  AppLlmResponseCache({
    required AppLlmClient delegate,
    this.defaultTtlMs = 300000,
    this.maxEntries = 64,
  }) : _delegate = delegate;

  final AppLlmClient _delegate;
  final int defaultTtlMs;
  final int maxEntries;

  final LinkedHashMap<int, _CacheEntry> _entries =
      LinkedHashMap<int, _CacheEntry>();

  int _hits = 0;
  int _misses = 0;

  /// Total cache hits since creation or last [clearAll].
  int get hits => _hits;

  /// Total cache misses since creation or last [clearAll].
  int get misses => _misses;

  /// Number of cached entries.
  int get size => _entries.length;

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    final key = _requestFingerprint(request);
    final now = DateTime.now().millisecondsSinceEpoch;

    final cached = _entries[key];
    if (cached != null) {
      if (now < cached.createdAtMs + defaultTtlMs) {
        _hits++;
        return cached.result;
      }
      _entries.remove(key);
    }

    _misses++;
    final result = await _delegate.chat(request);

    if (result.succeeded) {
      _entries[key] = _CacheEntry(result: result, createdAtMs: now);
      _evictIfNeeded();
    }

    return result;
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) {
    _misses++;
    return _delegate.chatStream(request);
  }

  void _evictIfNeeded() {
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  /// Clears all cache entries and resets hit/miss counters.
  void clearAll() {
    _entries.clear();
    _hits = 0;
    _misses = 0;
  }
}
