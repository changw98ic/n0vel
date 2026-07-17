// ---------------------------------------------------------------------------
// Shared helpers for character cognition model JSON parsing & equality.
// ---------------------------------------------------------------------------

/// Parses a [double] from [raw], falling back to [fallback] when null or
/// unparseable.  The result is clamped to 0.0–1.0.
double parseClampedDouble(Object? raw, {required double fallback}) {
  final parsed = double.tryParse(raw?.toString() ?? '');
  if (parsed == null) return fallback;
  return parsed.clamp(0.0, 1.0);
}

/// Parses an [int] from [raw], falling back to [fallback].
int parseIntOrFallback(Object? raw, {required int fallback}) {
  return int.tryParse(raw?.toString() ?? '') ?? fallback;
}

/// Parses a JSON list into a typed list using [decoder].
List<T> decodeList<T>(Object? raw, T Function(Map<Object?, Object?>) decoder) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is Map) decoder(Map<Object?, Object?>.from(item)),
  ];
}

/// Shallow list equality check.
bool listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
