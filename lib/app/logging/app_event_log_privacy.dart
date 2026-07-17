/// Privacy defaults for metadata attached to local event-log records.
///
/// Event logs are useful for diagnosing a failed request, but they are not a
/// safe place to persist excerpts of a user's manuscript or prompt context.
/// Keep the shape of the old `*Preview` fields for log consumers while making
/// the value an explicit redaction marker. Length remains useful for
/// diagnostics and does not reveal the text itself.
abstract final class AppEventLogPrivacy {
  static const String redactedPreview = '[redacted]';
  static const int maxErrorDetailLength = 2000;

  static Map<String, Object?> textMetadata({
    required String field,
    required String value,
  }) {
    final normalizedField = field.trim();
    if (normalizedField.isEmpty ||
        !RegExp(r'^[A-Za-z][A-Za-z0-9]*$').hasMatch(normalizedField)) {
      throw ArgumentError.value(field, 'field', 'invalid metadata field');
    }
    return {
      '${normalizedField}Length': value.length,
      '${normalizedField}Preview': redactedPreview,
    };
  }

  /// Sanitizes arbitrary metadata supplied by feature code before it reaches
  /// a durable sink. Non-sensitive scalar fields keep their diagnostic value;
  /// credential- and manuscript-shaped fields are redacted recursively.
  static Map<String, Object?> sanitizeMetadata(Map<String, Object?> metadata) {
    Object? sanitizeValue(String key, Object? value) {
      final normalized = key.toLowerCase();
      final sensitive =
          normalized.contains('prompt') ||
          normalized.contains('response') ||
          normalized.contains('preview') ||
          normalized.contains('token') ||
          normalized.contains('secret') ||
          normalized.contains('password') ||
          normalized.contains('apikey') ||
          normalized.contains('authorization');
      if (sensitive && value is String) return redactedPreview;
      if (value is Map) {
        return {
          for (final entry in value.entries)
            entry.key.toString(): sanitizeValue(
              entry.key.toString(),
              entry.value,
            ),
        };
      }
      if (value is Iterable) {
        return [for (final item in value) sanitizeValue(key, item)];
      }
      return value;
    }

    return {
      for (final entry in metadata.entries)
        entry.key: sanitizeValue(entry.key, entry.value),
    };
  }

  /// Removes common credential-shaped values from provider/error diagnostics
  /// while retaining a bounded message useful for local troubleshooting.
  static String? sanitizeErrorDetail(String? value) {
    if (value == null) return null;
    var sanitized = value.trim();
    if (sanitized.isEmpty) return sanitized;
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'Bearer\s+[A-Za-z0-9._~+/=-]+', caseSensitive: false),
      (_) => 'Bearer $redactedPreview',
    );
    sanitized = sanitized.replaceAllMapped(
      RegExp(
        r'(api[_-]?key|token|authorization|secret|password)\s*[:=]\s*[^\s,;]+',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}=$redactedPreview',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'\bsk-[A-Za-z0-9_-]{8,}\b'),
      redactedPreview,
    );
    if (sanitized.length > maxErrorDetailLength) {
      sanitized = sanitized.substring(0, maxErrorDetailLength);
    }
    return sanitized;
  }
}
