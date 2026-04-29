/// A generic memoization cache for computation results.
///
/// Use [get] to retrieve a cached value or compute and store it.
/// Use [invalidate], [invalidateWhere], or [clear] to evict entries
/// when upstream data changes.
class ComputationMemo<K, V> {
  final Map<K, V> _cache = {};

  /// Returns the cached value for [key] or invokes [compute],
  /// stores the result, and returns it.
  V get(K key, V Function() compute) {
    if (_cache.containsKey(key)) {
      return _cache[key] as V;
    }
    final result = compute();
    _cache[key] = result;
    return result;
  }

  /// Invalidates a single entry.
  void invalidate(K key) => _cache.remove(key);

  /// Invalidates entries matching [predicate].
  void invalidateWhere(bool Function(K key) predicate) {
    _cache.removeWhere((key, _) => predicate(key));
  }

  /// Clears all cached entries.
  void clear() => _cache.clear();

  /// Whether the cache contains [key].
  bool containsKey(K key) => _cache.containsKey(key);

  /// The number of cached entries.
  int get length => _cache.length;
}

/// A typed helper that memoizes per-key computations for a single
/// logical category (e.g. per-project character lists).
///
/// This is a thin wrapper around [ComputationMemo] with a
/// pre-registered [compute] function.
class TypedMemo<K, V> {
  final ComputationMemo<K, V> _memo = ComputationMemo<K, V>();
  final V Function(K key) _compute;

  TypedMemo(this._compute);

  V get(K key) => _memo.get(key, () => _compute(key));

  void invalidate(K key) => _memo.invalidate(key);
  void invalidateWhere(bool Function(K key) predicate) =>
      _memo.invalidateWhere(predicate);
  void clear() => _memo.clear();
  bool containsKey(K key) => _memo.containsKey(key);
  int get length => _memo.length;
}
