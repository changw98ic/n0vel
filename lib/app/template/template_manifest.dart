// ============================================================================
// Template Manifest
// ============================================================================
//
// Manifest parsing and validation for local n0vel project templates.
//
// See M8-03: Template Market Foundation

import 'dart:convert';

/// Raised when a template manifest cannot be parsed or validated.
class TemplateManifestException implements Exception {
  const TemplateManifestException(this.errors);

  final List<String> errors;

  @override
  String toString() => 'TemplateManifestException(${errors.join(', ')})';
}

/// Metadata used when a template is applied to a new project.
class TemplateProjectSeed {
  const TemplateProjectSeed({
    this.title,
    this.genre,
    this.language,
    this.synopsis,
    this.targetWordCount,
  });

  final String? title;
  final String? genre;
  final String? language;
  final String? synopsis;
  final int? targetWordCount;

  bool get isEmpty =>
      title == null &&
      genre == null &&
      language == null &&
      synopsis == null &&
      targetWordCount == null;

  Map<String, Object?> toJson() => {
    if (title != null) 'title': title,
    if (genre != null) 'genre': genre,
    if (language != null) 'language': language,
    if (synopsis != null) 'synopsis': synopsis,
    if (targetWordCount != null) 'targetWordCount': targetWordCount,
  };
}

/// A file that should be previewed/imported when applying a template.
class TemplateStarterFile {
  const TemplateStarterFile({required this.relativePath, required this.role});

  final String relativePath;
  final String role;

  Map<String, Object?> toJson() => {'path': relativePath, 'role': role};
}

/// Parsed and validated project template manifest.
class TemplateManifest {
  const TemplateManifest({
    required this.schemaVersion,
    required this.templateId,
    required this.displayName,
    required this.version,
    required this.locale,
    required this.minimumAppVersion,
    required this.tags,
    required this.starterFiles,
    this.description,
    this.genre,
    this.pipelinePreset,
    this.uiPreset,
    this.projectSeed = const TemplateProjectSeed(),
  });

  final int schemaVersion;
  final String templateId;
  final String displayName;
  final String version;
  final String locale;
  final String minimumAppVersion;
  final String? description;
  final String? genre;
  final List<String> tags;
  final String? pipelinePreset;
  final String? uiPreset;
  final TemplateProjectSeed projectSeed;
  final List<TemplateStarterFile> starterFiles;

  factory TemplateManifest.fromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const TemplateManifestException([
        'manifest root must be an object',
      ]);
    }
    return TemplateManifest.fromJson(Map<String, Object?>.from(decoded));
  }

  factory TemplateManifest.fromJson(Map<String, Object?> json) {
    final errors = <String>[];

    final schemaVersion = _readInt(json, 'schemaVersion', errors);
    final templateId = _readString(json, 'templateId', errors);
    final displayName = _readString(json, 'displayName', errors);
    final version = _readString(json, 'version', errors);
    final locale = _readString(json, 'locale', errors);
    final minimumAppVersion = _readString(json, 'minimumAppVersion', errors);
    final description = _readOptionalString(json['description']);
    final genre = _readOptionalString(json['genre']);
    final pipelinePreset = _readOptionalString(json['pipelinePreset']);
    final uiPreset = _readOptionalString(json['uiPreset']);
    final tags = _readTags(json['tags'], errors);
    final projectSeed = _readProjectSeed(json['projectSeed'], errors);
    final starterFiles = _readStarterFiles(json['starterFiles'], errors);

    if (schemaVersion != null && schemaVersion != 1) {
      errors.add('schemaVersion must be 1');
    }
    if (templateId != null && !_isValidTemplateId(templateId)) {
      errors.add('templateId must be lowercase ASCII slug');
    }
    if (version != null && !_isValidSemver(version)) {
      errors.add('version must be SemVer');
    }
    if (minimumAppVersion != null && !_isValidSemver(minimumAppVersion)) {
      errors.add('minimumAppVersion must be SemVer');
    }
    if (locale != null && !_isValidLocale(locale)) {
      errors.add('locale must be a BCP-47-like tag');
    }

    final seenPaths = <String>{};
    for (final file in starterFiles) {
      if (!seenPaths.add(file.relativePath)) {
        errors.add('duplicate starter file: ${file.relativePath}');
      }
      if (!_isSafeRelativePath(file.relativePath)) {
        errors.add('unsafe starter file path: ${file.relativePath}');
      }
      if (!_isValidRole(file.role)) {
        errors.add('starter file role must be lowercase ASCII: ${file.role}');
      }
    }

    if (errors.isNotEmpty) {
      throw TemplateManifestException(errors);
    }

    return TemplateManifest(
      schemaVersion: schemaVersion!,
      templateId: templateId!,
      displayName: displayName!,
      version: version!,
      locale: locale!,
      minimumAppVersion: minimumAppVersion!,
      description: description,
      genre: genre,
      tags: List.unmodifiable(tags),
      pipelinePreset: pipelinePreset,
      uiPreset: uiPreset,
      projectSeed: projectSeed,
      starterFiles: List.unmodifiable(starterFiles),
    );
  }

  Iterable<String> get referencedPaths sync* {
    for (final file in starterFiles) {
      yield file.relativePath;
    }
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'templateId': templateId,
    'displayName': displayName,
    'version': version,
    'locale': locale,
    'minimumAppVersion': minimumAppVersion,
    if (description != null) 'description': description,
    if (genre != null) 'genre': genre,
    if (tags.isNotEmpty) 'tags': tags,
    if (pipelinePreset != null) 'pipelinePreset': pipelinePreset,
    if (uiPreset != null) 'uiPreset': uiPreset,
    if (!projectSeed.isEmpty) 'projectSeed': projectSeed.toJson(),
    if (starterFiles.isNotEmpty)
      'starterFiles': starterFiles.map((file) => file.toJson()).toList(),
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

String? _readOptionalString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

List<String> _readTags(Object? raw, List<String> errors) {
  if (raw == null) return const [];
  if (raw is! List) {
    errors.add('tags must be a list');
    return const [];
  }
  final tags = <String>[];
  for (final item in raw) {
    if (item is! String || item.trim().isEmpty) {
      errors.add('tags must contain non-empty strings');
      continue;
    }
    final tag = item.trim();
    if (!_isValidRole(tag)) {
      errors.add('tag must be lowercase ASCII: $tag');
      continue;
    }
    tags.add(tag);
  }
  return tags;
}

TemplateProjectSeed _readProjectSeed(Object? raw, List<String> errors) {
  if (raw == null) return const TemplateProjectSeed();
  if (raw is! Map) {
    errors.add('projectSeed must be an object');
    return const TemplateProjectSeed();
  }
  final map = Map<String, Object?>.from(raw);
  final targetWordCount = map['targetWordCount'];
  if (targetWordCount != null &&
      (targetWordCount is! int || targetWordCount <= 0)) {
    errors.add('projectSeed.targetWordCount must be a positive integer');
  }
  return TemplateProjectSeed(
    title: _readOptionalString(map['title']),
    genre: _readOptionalString(map['genre']),
    language: _readOptionalString(map['language']),
    synopsis: _readOptionalString(map['synopsis']),
    targetWordCount: targetWordCount is int && targetWordCount > 0
        ? targetWordCount
        : null,
  );
}

List<TemplateStarterFile> _readStarterFiles(Object? raw, List<String> errors) {
  if (raw == null) return const [];
  if (raw is! List) {
    errors.add('starterFiles must be a list');
    return const [];
  }
  final files = <TemplateStarterFile>[];
  for (final item in raw) {
    if (item is String) {
      final relativePath = item.trim();
      if (relativePath.isEmpty) {
        errors.add('starterFiles must contain non-empty paths');
        continue;
      }
      files.add(
        TemplateStarterFile(
          relativePath: relativePath,
          role: _inferStarterFileRole(relativePath),
        ),
      );
      continue;
    }

    if (item is! Map) {
      errors.add('starter file must be a string path or object');
      continue;
    }
    final map = Map<String, Object?>.from(item);
    final path = map['path'];
    if (path is! String || path.trim().isEmpty) {
      errors.add('starter file path is required');
      continue;
    }
    final role =
        _readOptionalString(map['role']) ?? _inferStarterFileRole(path.trim());
    files.add(TemplateStarterFile(relativePath: path.trim(), role: role));
  }
  return files;
}

String _inferStarterFileRole(String relativePath) {
  if (relativePath == 'project.n0vel.json') return 'project';
  if (relativePath.startsWith('chapters/')) return 'scene';
  if (relativePath.startsWith('bible/characters/')) return 'character';
  if (relativePath.startsWith('bible/locations/')) return 'location';
  if (relativePath.startsWith('bible/')) return 'bible';
  if (relativePath.startsWith('production/')) return 'production';
  if (relativePath.startsWith('assets/')) return 'asset';
  return 'document';
}

bool _isValidTemplateId(String value) {
  return RegExp(r'^[a-z][a-z0-9-]*(?:[.-][a-z0-9-]+)*$').hasMatch(value);
}

bool _isValidSemver(String value) {
  return RegExp(r'^\d+\.\d+\.\d+([+-][0-9A-Za-z.-]+)?$').hasMatch(value);
}

bool _isValidLocale(String value) {
  return RegExp(r'^[A-Za-z]{2,3}([_-][A-Za-z0-9]{2,8})*$').hasMatch(value);
}

bool _isValidRole(String value) {
  return RegExp(r'^[a-z][a-z0-9._-]*$').hasMatch(value);
}

bool _isSafeRelativePath(String value) {
  if (value.trim().isEmpty) return false;
  if (value.startsWith('/') || value.startsWith(r'\')) return false;
  if (RegExp(r'^[A-Za-z]:[\\/]').hasMatch(value)) return false;
  if (value.contains(r'\')) return false;

  final segments = value.split('/');
  if (segments.any((segment) => segment.isEmpty)) return false;
  for (final segment in segments) {
    if (segment == '.' || segment == '..') return false;
  }
  return true;
}
