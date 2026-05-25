// ============================================================================
// Plugin Manifest
// ============================================================================
//
// Manifest parsing and validation for local n0vel plugin bundles.
//
// See M8-01: docs/plugin-system-design.md

import 'dart:convert';

/// Raised when a plugin manifest cannot be parsed or validated.
class PluginManifestException implements Exception {
  const PluginManifestException(this.errors);

  final List<String> errors;

  @override
  String toString() => 'PluginManifestException(${errors.join(', ')})';
}

/// Executable/runtime boundary declared by a plugin.
enum PluginRuntimeKind {
  templateOnly('templateOnly'),
  wasi('wasi'),
  process('process');

  const PluginRuntimeKind(this.id);

  final String id;

  static PluginRuntimeKind? parse(String value) {
    for (final kind in values) {
      if (kind.id == value) return kind;
    }
    return null;
  }
}

/// M7-aligned plugin permission vocabulary.
enum PluginPermission {
  projectRead('project:read'),
  projectWrite('project:write'),
  sceneRead('scene:read'),
  sceneWrite('scene:write'),
  characterRead('character:read'),
  characterWrite('character:write'),
  worldRead('world:read'),
  worldWrite('world:write'),
  runRead('run:read'),
  generateTrigger('generate:trigger'),
  candidateAdopt('candidate:adopt'),
  memoryPreview('memory:preview'),
  memoryCommit('memory:commit'),
  exportRead('export:read'),
  exportWrite('export:write'),
  importRead('import:read'),
  importWrite('import:write'),
  gitRead('git:read');

  const PluginPermission(this.id);

  final String id;

  static PluginPermission? parse(String value) {
    for (final permission in values) {
      if (permission.id == value) return permission;
    }
    return null;
  }
}

/// Declarative extension point kind.
enum PluginHookType {
  commandPalette('command.palette'),
  projectExport('project.export'),
  projectImportPlan('project.importPlan'),
  templateCatalog('template.catalog'),
  reviewPackage('review.package'),
  productionMetric('production.metric');

  const PluginHookType(this.id);

  final String id;

  static PluginHookType? parse(String value) {
    for (final type in values) {
      if (type.id == value) return type;
    }
    return null;
  }
}

class PluginRuntimeSpec {
  const PluginRuntimeSpec({required this.kind, this.entrypoint});

  final PluginRuntimeKind kind;
  final String? entrypoint;

  Map<String, Object?> toJson() => {
    'kind': kind.id,
    if (entrypoint != null) 'entrypoint': entrypoint,
  };
}

class PluginHook {
  const PluginHook({
    required this.id,
    required this.type,
    required this.title,
    this.command,
  });

  final String id;
  final PluginHookType type;
  final String title;
  final String? command;

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.id,
    'title': title,
    if (command != null) 'command': command,
  };
}

class PluginTemplateContribution {
  const PluginTemplateContribution({
    required this.templateId,
    required this.path,
  });

  final String templateId;
  final String path;

  Map<String, Object?> toJson() => {'templateId': templateId, 'path': path};
}

class PluginPublisher {
  const PluginPublisher({this.name, this.url});

  final String? name;
  final String? url;

  Map<String, Object?> toJson() => {
    if (name != null) 'name': name,
    if (url != null) 'url': url,
  };
}

class PluginIntegrity {
  const PluginIntegrity({required this.algorithm, required this.digest});

  final String algorithm;
  final String digest;

  Map<String, Object?> toJson() => {'algorithm': algorithm, 'digest': digest};
}

class PluginSignature {
  const PluginSignature({
    required this.algorithm,
    required this.keyId,
    required this.value,
  });

  final String algorithm;
  final String keyId;
  final String value;

  Map<String, Object?> toJson() => {
    'algorithm': algorithm,
    'keyId': keyId,
    'value': value,
  };
}

/// Parsed and validated plugin manifest.
class PluginManifest {
  const PluginManifest({
    required this.schemaVersion,
    required this.pluginId,
    required this.displayName,
    required this.version,
    required this.runtime,
    required this.permissions,
    required this.hooks,
    required this.minimumAppVersion,
    this.publisher,
    this.description,
    this.templates = const [],
    this.integrity,
    this.signature,
  });

  final int schemaVersion;
  final String pluginId;
  final String displayName;
  final String version;
  final PluginPublisher? publisher;
  final String? description;
  final PluginRuntimeSpec runtime;
  final Set<PluginPermission> permissions;
  final List<PluginHook> hooks;
  final List<PluginTemplateContribution> templates;
  final PluginIntegrity? integrity;
  final PluginSignature? signature;
  final String minimumAppVersion;

  factory PluginManifest.fromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const PluginManifestException(['manifest root must be an object']);
    }
    return PluginManifest.fromJson(Map<String, Object?>.from(decoded));
  }

  factory PluginManifest.fromJson(Map<String, Object?> json) {
    final errors = <String>[];

    final schemaVersion = _readInt(json, 'schemaVersion', errors);
    final pluginId = _readString(json, 'pluginId', errors);
    final displayName = _readString(json, 'displayName', errors);
    final version = _readString(json, 'version', errors);
    final minimumAppVersion = _readString(json, 'minimumAppVersion', errors);
    final runtime = _readRuntime(json['runtime'], errors);
    final publisher = _readPublisher(json['publisher'], errors);
    final integrity = _readIntegrity(json['integrity'], errors);
    final signature = _readSignature(json['signature'], errors);
    final permissions = _readPermissions(json['permissions'], errors);
    final hooks = _readHooks(json['hooks'], errors);
    final templates = _readTemplates(json['templates'], errors);
    final description = json['description'] is String
        ? (json['description'] as String).trim()
        : null;

    if (schemaVersion != null && schemaVersion != 1) {
      errors.add('schemaVersion must be 1');
    }
    if (pluginId != null && !_isValidPluginId(pluginId)) {
      errors.add('pluginId must be reverse-DNS lowercase ASCII');
    }
    if (version != null && !_isValidSemver(version)) {
      errors.add('version must be SemVer');
    }
    if (runtime != null) {
      if (runtime.kind == PluginRuntimeKind.templateOnly &&
          runtime.entrypoint != null &&
          runtime.entrypoint!.isNotEmpty) {
        errors.add('templateOnly runtime must not declare an entrypoint');
      }
      if (runtime.kind != PluginRuntimeKind.templateOnly &&
          (runtime.entrypoint == null || runtime.entrypoint!.isEmpty)) {
        errors.add('${runtime.kind.id} runtime requires an entrypoint');
      }
    }
    if (runtime?.kind != PluginRuntimeKind.templateOnly &&
        hooks.isEmpty &&
        templates.isEmpty) {
      errors.add(
        'executable plugins must declare at least one hook or template',
      );
    }

    if (errors.isNotEmpty) {
      throw PluginManifestException(errors);
    }

    return PluginManifest(
      schemaVersion: schemaVersion!,
      pluginId: pluginId!,
      displayName: displayName!,
      version: version!,
      publisher: publisher,
      description: description,
      runtime: runtime!,
      permissions: Set.unmodifiable(permissions),
      hooks: List.unmodifiable(hooks),
      templates: List.unmodifiable(templates),
      integrity: integrity,
      signature: signature,
      minimumAppVersion: minimumAppVersion!,
    );
  }

  Iterable<String> get referencedPaths sync* {
    final entrypoint = runtime.entrypoint;
    if (entrypoint != null && entrypoint.isNotEmpty) yield entrypoint;
    for (final template in templates) {
      yield template.path;
    }
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'pluginId': pluginId,
    'displayName': displayName,
    'version': version,
    if (publisher != null) 'publisher': publisher!.toJson(),
    if (description != null) 'description': description,
    'runtime': runtime.toJson(),
    'permissions': permissions.map((p) => p.id).toList(),
    'hooks': hooks.map((hook) => hook.toJson()).toList(),
    if (templates.isNotEmpty)
      'templates': templates.map((template) => template.toJson()).toList(),
    if (integrity != null) 'integrity': integrity!.toJson(),
    if (signature != null) 'signature': signature!.toJson(),
    'minimumAppVersion': minimumAppVersion,
  };
}

int? _readInt(Map<String, Object?> json, String key, List<String> errors) {
  final value = json[key];
  if (value is int) return value;
  errors.add('$key is required and must be an integer');
  return null;
}

String? _readString(
  Map<String, Object?> json,
  String key,
  List<String> errors,
) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value.trim();
  errors.add('$key is required and must be a non-empty string');
  return null;
}

PluginRuntimeSpec? _readRuntime(Object? raw, List<String> errors) {
  if (raw is! Map) {
    errors.add('runtime is required and must be an object');
    return null;
  }
  final map = Map<String, Object?>.from(raw);
  final kindRaw = map['kind'];
  if (kindRaw is! String) {
    errors.add('runtime.kind is required');
    return null;
  }
  final kind = PluginRuntimeKind.parse(kindRaw);
  if (kind == null) {
    errors.add('unknown runtime.kind: $kindRaw');
    return null;
  }
  final entrypoint = map['entrypoint'];
  return PluginRuntimeSpec(
    kind: kind,
    entrypoint: entrypoint is String ? entrypoint.trim() : null,
  );
}

PluginPublisher? _readPublisher(Object? raw, List<String> errors) {
  if (raw == null) return null;
  if (raw is! Map) {
    errors.add('publisher must be an object');
    return null;
  }
  final map = Map<String, Object?>.from(raw);
  final name = map['name'] is String ? (map['name'] as String).trim() : null;
  final url = map['url'] is String ? (map['url'] as String).trim() : null;
  return PluginPublisher(name: name, url: url);
}

PluginIntegrity? _readIntegrity(Object? raw, List<String> errors) {
  if (raw == null) return null;
  if (raw is! Map) {
    errors.add('integrity must be an object');
    return null;
  }
  final map = Map<String, Object?>.from(raw);
  final algorithm = map['algorithm'];
  final digest = map['digest'];
  if (algorithm is! String || algorithm.trim().isEmpty) {
    errors.add('integrity.algorithm is required');
  }
  if (digest is! String || digest.trim().isEmpty) {
    errors.add('integrity.digest is required');
  }
  if (algorithm is String && digest is String) {
    return PluginIntegrity(algorithm: algorithm.trim(), digest: digest.trim());
  }
  return null;
}

PluginSignature? _readSignature(Object? raw, List<String> errors) {
  if (raw == null) return null;
  if (raw is! Map) {
    errors.add('signature must be an object');
    return null;
  }
  final map = Map<String, Object?>.from(raw);
  final algorithm = map['algorithm'];
  final keyId = map['keyId'];
  final value = map['value'];
  if (algorithm is! String || algorithm.trim().isEmpty) {
    errors.add('signature.algorithm is required');
  }
  if (keyId is! String || keyId.trim().isEmpty) {
    errors.add('signature.keyId is required');
  }
  if (value is! String || value.trim().isEmpty) {
    errors.add('signature.value is required');
  }
  if (algorithm is String && keyId is String && value is String) {
    return PluginSignature(
      algorithm: algorithm.trim(),
      keyId: keyId.trim(),
      value: value.trim(),
    );
  }
  return null;
}

Set<PluginPermission> _readPermissions(Object? raw, List<String> errors) {
  if (raw == null) return const {};
  if (raw is! List) {
    errors.add('permissions must be a list');
    return const {};
  }
  final permissions = <PluginPermission>{};
  for (final item in raw) {
    if (item is! String) {
      errors.add('permissions must contain strings');
      continue;
    }
    final permission = PluginPermission.parse(item);
    if (permission == null) {
      errors.add('unknown permission: $item');
      continue;
    }
    permissions.add(permission);
  }
  return permissions;
}

List<PluginHook> _readHooks(Object? raw, List<String> errors) {
  if (raw == null) return const [];
  if (raw is! List) {
    errors.add('hooks must be a list');
    return const [];
  }
  final hooks = <PluginHook>[];
  for (final item in raw) {
    if (item is! Map) {
      errors.add('hook must be an object');
      continue;
    }
    final map = Map<String, Object?>.from(item);
    final id = map['id'];
    final typeRaw = map['type'];
    final title = map['title'];
    if (id is! String || id.trim().isEmpty) {
      errors.add('hook.id is required');
      continue;
    }
    if (typeRaw is! String) {
      errors.add('hook.type is required for $id');
      continue;
    }
    final type = PluginHookType.parse(typeRaw);
    if (type == null) {
      errors.add('unknown hook.type: $typeRaw');
      continue;
    }
    if (title is! String || title.trim().isEmpty) {
      errors.add('hook.title is required for $id');
      continue;
    }
    final command = map['command'] is String
        ? (map['command'] as String).trim()
        : null;
    hooks.add(
      PluginHook(
        id: id.trim(),
        type: type,
        title: title.trim(),
        command: command,
      ),
    );
  }
  return hooks;
}

List<PluginTemplateContribution> _readTemplates(
  Object? raw,
  List<String> errors,
) {
  if (raw == null) return const [];
  if (raw is! List) {
    errors.add('templates must be a list');
    return const [];
  }
  final templates = <PluginTemplateContribution>[];
  for (final item in raw) {
    if (item is! Map) {
      errors.add('template contribution must be an object');
      continue;
    }
    final map = Map<String, Object?>.from(item);
    final templateId = map['templateId'];
    final path = map['path'];
    if (templateId is! String || templateId.trim().isEmpty) {
      errors.add('templateId is required');
      continue;
    }
    if (path is! String || path.trim().isEmpty) {
      errors.add('template path is required for $templateId');
      continue;
    }
    templates.add(
      PluginTemplateContribution(
        templateId: templateId.trim(),
        path: path.trim(),
      ),
    );
  }
  return templates;
}

bool _isValidPluginId(String value) {
  return RegExp(r'^[a-z][a-z0-9-]*(\.[a-z0-9-]+)+$').hasMatch(value);
}

bool _isValidSemver(String value) {
  return RegExp(r'^\d+\.\d+\.\d+([+-][0-9A-Za-z.-]+)?$').hasMatch(value);
}
