// ============================================================================
// Template Catalog
// ============================================================================
//
// Installed and built-in template records. This layer remains storage-neutral
// so UI and repository wiring can decide how to persist catalog state.

import 'template_installer.dart';
import 'template_manifest.dart';

class TemplateCatalogException implements Exception {
  const TemplateCatalogException(this.message);

  final String message;

  @override
  String toString() => 'TemplateCatalogException($message)';
}

enum TemplateCatalogSource {
  builtIn('builtIn'),
  local('local'),
  plugin('plugin');

  const TemplateCatalogSource(this.id);

  final String id;
}

class TemplateCatalogEntry {
  const TemplateCatalogEntry({
    required this.manifest,
    required this.source,
    this.bundleRootPath,
    this.manifestDigest,
    this.installedAt,
    this.providerPluginId,
  });

  factory TemplateCatalogEntry.fromInstallPlan(
    TemplateInstallPlan plan, {
    DateTime? installedAt,
  }) {
    return TemplateCatalogEntry(
      manifest: plan.manifest,
      source: TemplateCatalogSource.local,
      bundleRootPath: plan.bundleRootPath,
      manifestDigest: plan.manifestDigest,
      installedAt: installedAt,
    );
  }

  final TemplateManifest manifest;
  final TemplateCatalogSource source;
  final String? bundleRootPath;
  final String? manifestDigest;
  final DateTime? installedAt;
  final String? providerPluginId;

  String get templateId => manifest.templateId;
}

class TemplateCatalogSnapshot {
  const TemplateCatalogSnapshot({this.entries = const []});

  final List<TemplateCatalogEntry> entries;

  TemplateCatalogEntry? find(String templateId) {
    for (final entry in entries) {
      if (entry.templateId == templateId) return entry;
    }
    return null;
  }

  List<TemplateCatalogEntry> byLocale(String locale) {
    final normalized = locale.trim().toLowerCase();
    return List.unmodifiable(
      entries.where(
        (entry) => entry.manifest.locale.toLowerCase() == normalized,
      ),
    );
  }

  List<TemplateCatalogEntry> bySource(TemplateCatalogSource source) {
    return List.unmodifiable(entries.where((entry) => entry.source == source));
  }
}

class TemplateCatalog {
  TemplateCatalog([Iterable<TemplateCatalogEntry> entries = const []])
    : _entriesById = {for (final entry in entries) entry.templateId: entry};

  final Map<String, TemplateCatalogEntry> _entriesById;

  TemplateCatalogSnapshot get snapshot {
    final entries = _entriesById.values.toList()
      ..sort((a, b) => a.templateId.compareTo(b.templateId));
    return TemplateCatalogSnapshot(entries: List.unmodifiable(entries));
  }

  TemplateCatalogEntry? find(String templateId) => _entriesById[templateId];

  void install(TemplateCatalogEntry entry) {
    final existing = _entriesById[entry.templateId];
    if (existing != null) {
      throw TemplateCatalogException(
        'template already installed: ${entry.templateId}',
      );
    }
    _entriesById[entry.templateId] = entry;
  }

  void replace(TemplateCatalogEntry entry) {
    _entriesById[entry.templateId] = entry;
  }

  void uninstall(String templateId) {
    final removed = _entriesById.remove(templateId);
    if (removed == null) {
      throw TemplateCatalogException('template is not installed: $templateId');
    }
  }
}

class BuiltInTemplateCatalog {
  BuiltInTemplateCatalog._();

  static TemplateCatalogSnapshot get snapshot =>
      TemplateCatalogSnapshot(entries: entries);

  static List<TemplateCatalogEntry> get entries => List.unmodifiable([
    TemplateCatalogEntry(
      source: TemplateCatalogSource.builtIn,
      manifest: TemplateManifest.fromJson({
        'schemaVersion': 1,
        'templateId': 'blank-novel',
        'displayName': 'Blank Novel',
        'version': '1.0.0',
        'locale': 'en-US',
        'minimumAppVersion': '0.9.0',
        'description': 'A clean project with no starter manuscript files.',
        'genre': 'novel',
        'tags': ['blank', 'novel'],
        'projectSeed': {
          'title': 'Untitled Novel',
          'genre': 'novel',
          'language': 'en-US',
        },
      }),
    ),
    TemplateCatalogEntry(
      source: TemplateCatalogSource.builtIn,
      manifest: TemplateManifest.fromJson({
        'schemaVersion': 1,
        'templateId': 'cn-webnovel-basic',
        'displayName': 'CN Webnovel Basic',
        'version': '1.0.0',
        'locale': 'zh-CN',
        'minimumAppVersion': '0.9.0',
        'description': 'A lightweight starting point for serialized fiction.',
        'genre': 'webnovel',
        'tags': ['cn', 'webnovel'],
        'pipelinePreset': 'webnovel-fast-v1',
        'uiPreset': 'studio-focus',
        'projectSeed': {
          'title': 'Untitled Webnovel',
          'genre': 'webnovel',
          'language': 'zh-CN',
        },
      }),
    ),
    TemplateCatalogEntry(
      source: TemplateCatalogSource.builtIn,
      manifest: TemplateManifest.fromJson({
        'schemaVersion': 1,
        'templateId': 'mystery-basic',
        'displayName': 'Mystery Basic',
        'version': '1.0.0',
        'locale': 'en-US',
        'minimumAppVersion': '0.9.0',
        'description': 'A planning shell for clue-driven fiction.',
        'genre': 'mystery',
        'tags': ['mystery', 'outline'],
        'projectSeed': {
          'title': 'Untitled Mystery',
          'genre': 'mystery',
          'language': 'en-US',
        },
      }),
    ),
  ]);
}
