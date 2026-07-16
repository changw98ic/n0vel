import 'app_llm_canonical_hash.dart';
import 'app_llm_client_types.dart';
import 'app_llm_prompt_release.dart';

final class AppLlmRenderedPrompt {
  const AppLlmRenderedPrompt({
    required this.messages,
    required this.resolvedVariables,
    required this.rendererContractHash,
  });

  final List<AppLlmChatMessage> messages;
  final Map<String, Object?> resolvedVariables;
  final String rendererContractHash;
}

/// Frozen registry for executable prompt renderers.
///
/// `strict-named-template-v1` supports scalar `{{name}}` placeholders plus
/// non-nested positive/negative blocks (`{{?name}}...{{/name}}` and
/// `{{!name}}...{{/name}}`). Every declared schema
/// property must participate in the template and every resolved variable must
/// pass the frozen JSON-schema subset before any message is produced.
final class AppLlmPromptRendererRegistry {
  const AppLlmPromptRendererRegistry._(this._supportedReleases);

  static const strictRendererRelease = 'strict-named-template-v1';

  static final String
  strictRendererContractHash = AppLlmCanonicalHash.domainHash(
    'app-llm-prompt-renderer-contract-v1',
    const <String, Object?>{
      'messages': <String>['system', 'user'],
      'system': 'exact-release-system-template',
      'user':
          'strict-named-scalars-with-non-nested-positive-negative-blocks-v1',
      'schema': 'closed-json-schema-subset-v1',
      'replay': 'exact-role-content-order-v1',
    },
  );

  static final String legacyRendererContractHash =
      AppLlmCanonicalHash.domainHash(
        'app-llm-prompt-renderer-contract-v1',
        const <String, Object?>{
          'messages': <String>['system', 'user'],
          'system': 'exact-release-system-template',
          'user': 'legacy-single-brace-named-scalars-v1',
          'schema': 'closed-json-schema-subset-v1',
          'replay': 'exact-role-content-order-v1',
        },
      );

  static const builtIn = AppLlmPromptRendererRegistry._(<String>{
    strictRendererRelease,
    'user-reachable-product-message-renderer-v1',
    'real-release-judge-renderer-v1',
    'evaluation-judge-renderer-v1',
    'judge-renderer-v1',
  });

  final Set<String> _supportedReleases;

  AppLlmRenderedPrompt render({
    required PromptRelease release,
    required Object? resolvedVariables,
  }) {
    if (!_supportedReleases.contains(release.rendererRelease)) {
      throw StateError(
        'PromptRelease renderer is not present in the frozen registry',
      );
    }
    if (!release.hasValidContentHash) {
      throw StateError('PromptRelease content hash is invalid');
    }
    final schema = _object(release.variablesSchemaSnapshot, 'variables schema');
    final variables = _object(
      AppLlmCanonicalHash.immutableSnapshot(resolvedVariables),
      'resolvedVariables',
    );
    const reserved = <String>{
      'messages',
      'renderedMessages',
      'renderedNonSystemMessages',
    };
    if (variables.keys.any(reserved.contains)) {
      throw const FormatException(
        'rendered messages cannot be supplied as resolved variables',
      );
    }
    final properties = _validateObjectSchema(schema, variables);
    final strict = release.rendererRelease == strictRendererRelease;
    final templateFields = strict
        ? _templateFields(release.userTemplate)
        : _legacyTemplateFields(release.userTemplate);
    if (!_sameSet(templateFields, properties)) {
      throw const FormatException(
        'prompt template fields do not equal the variables schema',
      );
    }
    final user = strict
        ? _renderTemplate(release.userTemplate, variables)
        : _renderLegacyTemplate(release.userTemplate, variables);
    return AppLlmRenderedPrompt(
      messages: List<AppLlmChatMessage>.unmodifiable(<AppLlmChatMessage>[
        AppLlmChatMessage(role: 'system', content: release.systemTemplate),
        AppLlmChatMessage(role: 'user', content: user),
      ]),
      resolvedVariables: Map<String, Object?>.unmodifiable(variables),
      rendererContractHash: strict
          ? strictRendererContractHash
          : legacyRendererContractHash,
    );
  }
}

Set<String> _validateObjectSchema(
  Map<String, Object?> schema,
  Map<String, Object?> value,
) {
  const schemaKeys = <String>{
    'type',
    'additionalProperties',
    'required',
    'properties',
  };
  if (!_sameSet(schema.keys.toSet(), schemaKeys) ||
      schema['type'] != 'object' ||
      schema['additionalProperties'] != false ||
      schema['required'] is! List<Object?> ||
      schema['properties'] is! Map<String, Object?>) {
    throw const FormatException(
      'variables schema must be a closed object with properties and required',
    );
  }
  final rawRequired = schema['required']! as List<Object?>;
  if (rawRequired.any((item) => item is! String)) {
    throw const FormatException('variables schema required is invalid');
  }
  final required = rawRequired.cast<String>().toSet();
  final properties = schema['properties']! as Map<String, Object?>;
  if (properties.keys.any((key) => key.trim().isEmpty) ||
      required.length != rawRequired.length ||
      !_sameSet(required, properties.keys.toSet()) ||
      !_sameSet(value.keys.toSet(), required)) {
    throw const FormatException(
      'resolved variables must exactly match required schema properties',
    );
  }
  for (final entry in properties.entries) {
    _validateSchemaValue(entry.value, value[entry.key], entry.key);
  }
  return properties.keys.toSet();
}

void _validateSchemaValue(Object? rawSchema, Object? value, String path) {
  final schema = _object(rawSchema, '$path schema');
  final type = schema['type'];
  if (type is! String) throw FormatException('$path type is invalid');
  final allowedKeys = switch (type) {
    'array' => const <String>{'type', 'items'},
    'object' => const <String>{
      'type',
      'additionalProperties',
      'required',
      'properties',
    },
    'string' ||
    'integer' ||
    'number' ||
    'boolean' ||
    'null' => const <String>{'type'},
    _ => throw FormatException('$path uses an unsupported schema type'),
  };
  if (!_sameSet(schema.keys.toSet(), allowedKeys)) {
    throw FormatException('$path schema fields are invalid');
  }
  switch (type) {
    case 'string':
      if (value is! String) throw FormatException('$path must be a string');
    case 'integer':
      if (value is! int) throw FormatException('$path must be an integer');
    case 'number':
      if (value is! num) throw FormatException('$path must be a number');
    case 'boolean':
      if (value is! bool) throw FormatException('$path must be a boolean');
    case 'null':
      if (value != null) throw FormatException('$path must be null');
    case 'array':
      if (value is! List<Object?>) {
        throw FormatException('$path must be an array');
      }
      for (var index = 0; index < value.length; index += 1) {
        _validateSchemaValue(schema['items'], value[index], '$path[$index]');
      }
    case 'object':
      _validateObjectSchema(schema, _object(value, path));
  }
}

Set<String> _templateFields(String template) {
  if (template.trim().isEmpty || template.contains('{{{')) {
    throw const FormatException('prompt user template is invalid');
  }
  final fields = <String>{};
  final token = RegExp(r'\{\{([?!/]?)([A-Za-z][A-Za-z0-9_]*)\}\}');
  String? openBlock;
  for (final match in token.allMatches(template)) {
    final operator = match.group(1)!;
    final name = match.group(2)!;
    switch (operator) {
      case '':
        fields.add(name);
      case '?' || '!':
        if (openBlock != null) {
          throw const FormatException(
            'prompt optional blocks must not be nested',
          );
        }
        openBlock = name;
        fields.add(name);
      case '/':
        if (openBlock != name) {
          throw const FormatException('prompt optional block is malformed');
        }
        openBlock = null;
    }
  }
  if (openBlock != null) {
    throw const FormatException('prompt optional block is malformed');
  }
  final stripped = template.replaceAll(token, '');
  if (stripped.contains('{{') || stripped.contains('}}')) {
    throw const FormatException('prompt template contains unknown syntax');
  }
  return fields;
}

Set<String> _legacyTemplateFields(String template) {
  if (template.trim().isEmpty || template.contains('{{')) {
    throw const FormatException('legacy prompt user template is invalid');
  }
  final fields = RegExp(
    r'\{([A-Za-z][A-Za-z0-9_]*)\}',
  ).allMatches(template).map((match) => match.group(1)!).toSet();
  final stripped = template.replaceAll(
    RegExp(r'\{[A-Za-z][A-Za-z0-9_]*\}'),
    '',
  );
  if (fields.isEmpty || stripped.contains('{') || stripped.contains('}')) {
    throw const FormatException(
      'legacy prompt template contains unknown syntax',
    );
  }
  return fields;
}

String _renderTemplate(String template, Map<String, Object?> variables) {
  var rendered = template;
  final starts = RegExp(
    r'\{\{([?!])([A-Za-z][A-Za-z0-9_]*)\}\}',
  ).allMatches(template).toList(growable: false).reversed;
  for (final start in starts) {
    final polarity = start.group(1)!;
    final name = start.group(2)!;
    final close = '{{/$name}}';
    final closeIndex = rendered.indexOf(close, start.end);
    if (closeIndex < 0) {
      throw const FormatException('prompt optional block is malformed');
    }
    final body = rendered.substring(start.end, closeIndex);
    final isPresent = _present(variables[name]);
    final replacement = (polarity == '?' ? isPresent : !isPresent) ? body : '';
    rendered = rendered.replaceRange(
      start.start,
      closeIndex + close.length,
      replacement,
    );
  }
  rendered = rendered.replaceAllMapped(
    RegExp(r'\{\{([A-Za-z][A-Za-z0-9_]*)\}\}'),
    (match) => _scalar(variables[match.group(1)!], match.group(1)!),
  );
  return rendered;
}

String _renderLegacyTemplate(String template, Map<String, Object?> variables) =>
    template.replaceAllMapped(
      RegExp(r'\{([A-Za-z][A-Za-z0-9_]*)\}'),
      (match) => _scalar(variables[match.group(1)!], match.group(1)!),
    );

bool _present(Object? value) => switch (value) {
  null => false,
  String() => value.isNotEmpty,
  bool() => value,
  List<Object?>() => value.isNotEmpty,
  _ => true,
};

String _scalar(Object? value, String field) => switch (value) {
  String() => value,
  int() => value.toString(),
  double() => value.toString(),
  bool() => value.toString(),
  _ => throw FormatException('$field is not a scalar template value'),
};

Map<String, Object?> _object(Object? value, String label) {
  if (value is! Map<String, Object?>) {
    throw FormatException('$label must be a JSON object');
  }
  return value;
}

bool _sameSet(Set<Object?> left, Set<Object?> right) =>
    left.length == right.length && left.containsAll(right);
