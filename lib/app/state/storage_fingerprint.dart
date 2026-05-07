import 'dart:convert';

/// Computes a lightweight fingerprint (hash) of a storage map.
///
/// Used by the write-after-verification layer to confirm that data
/// persisted to disk matches what was originally written.
///
/// The fingerprint is based on a canonical JSON encoding of the map,
/// which provides deterministic ordering of keys and stable equality
/// across save/load round-trips.
int storageFingerprint(Map<String, Object?> data) {
  final encoded = jsonEncode(_canonicalize(data));
  return encoded.hashCode;
}

/// Recursively normalizes a value so that JSON encoding is deterministic.
///
/// - Maps are sorted by key.
/// - Lists retain their order.
/// - Scalar values are left as-is.
Object? _canonicalize(Object? value) {
  if (value is Map) {
    final sortedKeys = value.keys.map((k) => k.toString()).toList()..sort();
    return {
      for (final key in sortedKeys) key: _canonicalize(value[key]),
    };
  }
  if (value is List) {
    return [for (final item in value) _canonicalize(item)];
  }
  return value;
}
