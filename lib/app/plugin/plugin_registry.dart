// ============================================================================
// Plugin Registry
// ============================================================================
//
// Installed/enabled plugin records and hook index projection.
//
// See M8-02: Plugin System Core

import 'plugin_manifest.dart';

class PluginRegistryException implements Exception {
  const PluginRegistryException(this.message);

  final String message;

  @override
  String toString() => 'PluginRegistryException($message)';
}

class InstalledPluginRecord {
  InstalledPluginRecord({
    required this.manifest,
    required this.bundlePath,
    required this.manifestDigest,
    required this.installedAt,
    required this.enabled,
    Set<PluginPermission>? grantedPermissions,
  }) : grantedPermissions = grantedPermissions ?? manifest.permissions;

  final PluginManifest manifest;
  final String bundlePath;
  final String manifestDigest;
  final DateTime installedAt;
  final bool enabled;
  final Set<PluginPermission> grantedPermissions;

  String get pluginId => manifest.pluginId;

  InstalledPluginRecord copyWith({
    PluginManifest? manifest,
    String? bundlePath,
    String? manifestDigest,
    DateTime? installedAt,
    bool? enabled,
    Set<PluginPermission>? grantedPermissions,
  }) {
    return InstalledPluginRecord(
      manifest: manifest ?? this.manifest,
      bundlePath: bundlePath ?? this.bundlePath,
      manifestDigest: manifestDigest ?? this.manifestDigest,
      installedAt: installedAt ?? this.installedAt,
      enabled: enabled ?? this.enabled,
      grantedPermissions: grantedPermissions ?? this.grantedPermissions,
    );
  }
}

class PluginHookRegistration {
  const PluginHookRegistration({
    required this.pluginId,
    required this.pluginVersion,
    required this.hook,
  });

  final String pluginId;
  final String pluginVersion;
  final PluginHook hook;
}

class PluginPermissionDiff {
  const PluginPermissionDiff({
    required this.added,
    required this.removed,
    required this.unchanged,
  });

  factory PluginPermissionDiff.between(
    Set<PluginPermission> previous,
    Set<PluginPermission> next,
  ) {
    return PluginPermissionDiff(
      added: next.difference(previous),
      removed: previous.difference(next),
      unchanged: previous.intersection(next),
    );
  }

  final Set<PluginPermission> added;
  final Set<PluginPermission> removed;
  final Set<PluginPermission> unchanged;

  bool get hasChanges => added.isNotEmpty || removed.isNotEmpty;
}

class PluginRegistrySnapshot {
  const PluginRegistrySnapshot({this.records = const []});

  final List<InstalledPluginRecord> records;

  InstalledPluginRecord? find(String pluginId) {
    for (final record in records) {
      if (record.pluginId == pluginId) return record;
    }
    return null;
  }

  List<PluginHookRegistration> hooksForType(PluginHookType type) {
    final registrations = <PluginHookRegistration>[];
    for (final record in records) {
      if (!record.enabled) continue;
      for (final hook in record.manifest.hooks) {
        if (hook.type != type) continue;
        registrations.add(
          PluginHookRegistration(
            pluginId: record.pluginId,
            pluginVersion: record.manifest.version,
            hook: hook,
          ),
        );
      }
    }
    return List.unmodifiable(registrations);
  }

  List<PluginHookRegistration> get enabledHooks {
    final registrations = <PluginHookRegistration>[];
    for (final record in records) {
      if (!record.enabled) continue;
      for (final hook in record.manifest.hooks) {
        registrations.add(
          PluginHookRegistration(
            pluginId: record.pluginId,
            pluginVersion: record.manifest.version,
            hook: hook,
          ),
        );
      }
    }
    return List.unmodifiable(registrations);
  }
}

class PluginRegistry {
  PluginRegistry([Iterable<InstalledPluginRecord> records = const []])
    : _recordsById = {for (final record in records) record.pluginId: record};

  final Map<String, InstalledPluginRecord> _recordsById;

  PluginRegistrySnapshot get snapshot {
    final records = _recordsById.values.toList()
      ..sort((a, b) => a.pluginId.compareTo(b.pluginId));
    return PluginRegistrySnapshot(records: List.unmodifiable(records));
  }

  InstalledPluginRecord? find(String pluginId) => _recordsById[pluginId];

  void install(InstalledPluginRecord record) {
    final existing = _recordsById[record.pluginId];
    if (existing != null) {
      throw PluginRegistryException(
        'plugin already installed: ${record.pluginId}',
      );
    }
    _recordsById[record.pluginId] = record;
  }

  void replace(InstalledPluginRecord record) {
    _recordsById[record.pluginId] = record;
  }

  void enable(String pluginId) {
    _update(pluginId, (record) => record.copyWith(enabled: true));
  }

  void disable(String pluginId) {
    _update(pluginId, (record) => record.copyWith(enabled: false));
  }

  void uninstall(String pluginId) {
    final removed = _recordsById.remove(pluginId);
    if (removed == null) {
      throw PluginRegistryException('plugin is not installed: $pluginId');
    }
  }

  List<PluginHookRegistration> hooksForType(PluginHookType type) {
    return snapshot.hooksForType(type);
  }

  void _update(
    String pluginId,
    InstalledPluginRecord Function(InstalledPluginRecord record) transform,
  ) {
    final record = _recordsById[pluginId];
    if (record == null) {
      throw PluginRegistryException('plugin is not installed: $pluginId');
    }
    _recordsById[pluginId] = transform(record);
  }
}
