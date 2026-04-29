/// Deep-clones a storage value (Map, List, or scalar).
Object? cloneStorageValue(Object? value) {
  if (value is Map) {
    return {
      for (final entry in value.entries)
        entry.key.toString(): cloneStorageValue(entry.value),
    };
  }
  if (value is List) {
    return [for (final item in value) cloneStorageValue(item)];
  }
  return value;
}

/// Deep-clones a storage map with string keys.
Map<String, Object?> cloneStorageMap(Map<String, Object?> value) {
  return {
    for (final entry in value.entries)
      entry.key: cloneStorageValue(entry.value),
  };
}

List<T> immutableList<T>(List<T> items) => List<T>.unmodifiable(items);

Map<String, Object?> immutableMap(Map<String, Object?> value) =>
    Map<String, Object?>.unmodifiable({
      for (final entry in value.entries)
        entry.key: _immutableStorageValue(entry.value),
    });

Object? _immutableStorageValue(Object? value) {
  if (value is List) return List<Object?>.unmodifiable(value);
  if (value is Map<String, Object?>) return immutableMap(value);
  if (value is Map) {
    return Map<String, Object?>.unmodifiable({
      for (final entry in value.entries) entry.key.toString(): entry.value,
    });
  }
  return value;
}
