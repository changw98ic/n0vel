import 'app_event_log_types.dart';

const String redactedValue = '[REDACTED]';

class SensitiveDataRedactionPolicy {
  const SensitiveDataRedactionPolicy({
    this.enabled = true,
    this.replacement = redactedValue,
    this.sensitiveKeys = _defaultSensitiveKeys,
  });

  static const SensitiveDataRedactionPolicy defaults =
      SensitiveDataRedactionPolicy();

  static const Set<String> _defaultSensitiveKeys = {
    'authorization',
    'proxy-authorization',
    'x-api-key',
    'api-key',
    'apikey',
    'api_key',
    'apiKey',
    'openai-api-key',
    'anthropic-api-key',
    'access-token',
    'access_token',
    'refresh-token',
    'refresh_token',
    'id-token',
    'id_token',
    'token',
    'secret',
    'client-secret',
    'client_secret',
    'password',
  };

  static final RegExp _authorizationWithSchemePattern = RegExp(
    r'\b(authorization\s*[:=]\s*)(bearer|basic)\s+([^,;\s]+)',
    caseSensitive: false,
  );
  static final RegExp _authorizationPattern = RegExp(
    r'\b(authorization\s*[:=]\s*)(?!(?:bearer|basic)\b)([^,;\s]+)',
    caseSensitive: false,
  );
  static final RegExp _apiKeyHeaderPattern = RegExp(
    r'(^|[\s,{])((?:x-api-key|api-key|api_key|apikey|openai-api-key|anthropic-api-key)\s*[:=]\s*)([^,;\s&]+)',
    caseSensitive: false,
  );
  static final RegExp _querySecretPattern = RegExp(
    r'([?&](?:api[_-]?key|apikey|access[_-]?token|refresh[_-]?token|id[_-]?token|token|client[_-]?secret|secret|password)=)([^&#\s]+)',
    caseSensitive: false,
  );
  static final RegExp _keyValueSecretPattern = RegExp(
    r'''(["']?(?:apiKey|api_key|api-key|x-api-key|authorization|access[_-]?token|refresh[_-]?token|client[_-]?secret|secret|password)["']?\s*[:=]\s*["'])([^"',}&\s#]+)(["']?)''',
    caseSensitive: false,
  );
  static final RegExp _openAiKeyPattern = RegExp(
    r'\bsk-(?:proj-)?[A-Za-z0-9][A-Za-z0-9_-]{6,}\b',
  );

  final bool enabled;
  final String replacement;
  final Set<String> sensitiveKeys;

  String redactString(String value) {
    if (!enabled || value.isEmpty) return value;

    var redacted = value;

    redacted = redacted.replaceAllMapped(
      _authorizationWithSchemePattern,
      (match) => '${match[1]}${match[2]} $replacement',
    );
    redacted = redacted.replaceAllMapped(
      _authorizationPattern,
      (match) => '${match[1]}$replacement',
    );
    redacted = redacted.replaceAllMapped(
      _apiKeyHeaderPattern,
      (match) => '${match[1]}${match[2]}$replacement',
    );
    redacted = redacted.replaceAllMapped(
      _querySecretPattern,
      (match) => '${match[1]}$replacement',
    );
    redacted = redacted.replaceAllMapped(
      _keyValueSecretPattern,
      (match) => '${match[1]}$replacement${match[3]}',
    );
    redacted = redacted.replaceAllMapped(_openAiKeyPattern, (_) => replacement);

    return redacted;
  }

  Object? redactValue(Object? value, {String? key}) {
    if (!enabled) return value;
    if (_isSensitiveKey(key)) {
      return _redactSensitiveValue(value);
    }
    if (value is String) {
      return redactString(value);
    }
    if (value is Map) {
      return _redactMap(value);
    }
    if (value is Iterable) {
      return _redactIterable(value);
    }
    return value;
  }

  bool _isSensitiveKey(String? key) {
    if (key == null) return false;
    final normalized = key.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    for (final sensitiveKey in sensitiveKeys) {
      if (normalized == sensitiveKey.toLowerCase()) return true;
    }
    return false;
  }

  Object? _redactSensitiveValue(Object? value) {
    if (value == null) return null;
    if (value is String && value.trim().isEmpty) return value;
    return replacement;
  }

  Object _redactMap(Map<dynamic, dynamic> value) {
    var changed = false;
    final redacted = <String, Object?>{};
    value.forEach((rawKey, rawValue) {
      final key = rawKey?.toString() ?? '';
      final redactedValue = redactValue(rawValue, key: key);
      redacted[key] = redactedValue;
      if (!identical(redactedValue, rawValue) || key != rawKey) {
        changed = true;
      }
    });
    if (!changed && value is Map<String, Object?>) {
      return value;
    }
    return redacted;
  }

  Object _redactIterable(Iterable<dynamic> value) {
    var changed = false;
    final redacted = <Object?>[];
    for (final item in value) {
      final redactedItem = redactValue(item);
      redacted.add(redactedItem);
      if (!identical(redactedItem, item)) {
        changed = true;
      }
    }
    if (!changed && value is List<Object?>) {
      return value;
    }
    return redacted;
  }
}

AppEventLogEntry redactAppEventLogEntry(
  AppEventLogEntry entry,
  SensitiveDataRedactionPolicy policy,
) {
  if (!policy.enabled) return entry;

  final message = policy.redactString(entry.message);
  final errorDetail = entry.errorDetail == null
      ? null
      : policy.redactString(entry.errorDetail!);
  final redactedMetadata = policy.redactValue(entry.metadata);
  final metadata = redactedMetadata is Map<String, Object?>
      ? redactedMetadata
      : const <String, Object?>{};

  if (message == entry.message &&
      errorDetail == entry.errorDetail &&
      identical(metadata, entry.metadata)) {
    return entry;
  }

  return AppEventLogEntry(
    eventId: entry.eventId,
    timestampMs: entry.timestampMs,
    level: entry.level,
    category: entry.category,
    action: entry.action,
    status: entry.status,
    sessionId: entry.sessionId,
    correlationId: entry.correlationId,
    projectId: entry.projectId,
    sceneId: entry.sceneId,
    message: message,
    errorCode: entry.errorCode,
    errorDetail: errorDetail,
    metadata: metadata,
  );
}
