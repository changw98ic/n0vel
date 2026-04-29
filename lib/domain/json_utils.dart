/// Common JSON deserialization helpers used by domain models.
library;

/// Extracts a list of non-empty strings from a raw JSON value.
List<String> stringListFromRaw(Object? raw) {
  if (raw is! List) {
    return const <String>[];
  }
  return [
    for (final item in raw)
      if (item.toString().trim().isNotEmpty) item.toString(),
  ];
}

/// Extracts a map with string keys from a raw JSON value.
Map<String, Object?> stringObjectMapFromRaw(Object? raw) {
  if (raw is! Map) {
    return const <String, Object?>{};
  }
  return {for (final entry in raw.entries) entry.key.toString(): entry.value};
}

/// Parses an int from a raw JSON value with an optional fallback.
int intFromRaw(Object? value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

/// Generates a fallback scoped record ID from a seed string.
String fallbackScopedRecordId(String prefix, Object? seed) {
  final normalized = seed?.toString().trim().toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9]+'),
    '-',
  );
  if (normalized == null || normalized.isEmpty) {
    return '$prefix-fallback';
  }
  return '$prefix-$normalized';
}
