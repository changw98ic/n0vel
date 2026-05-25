import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/plugin/plugin.dart';

void main() {
  group('PluginManifest', () {
    test('parses a valid executable manifest', () {
      final manifest = PluginManifest.fromJson({
        'schemaVersion': 1,
        'pluginId': 'com.example.timeline-exporter',
        'displayName': 'Timeline Exporter',
        'version': '0.1.0',
        'description': 'Exports scene timelines.',
        'runtime': {'kind': 'wasi', 'entrypoint': 'bin/plugin.wasm'},
        'permissions': ['project:read', 'scene:read', 'export:write'],
        'hooks': [
          {
            'id': 'timeline.export',
            'type': 'command.palette',
            'title': 'Export Timeline',
            'command': 'timeline.export',
          },
        ],
        'minimumAppVersion': '0.9.0',
      });

      expect(manifest.pluginId, 'com.example.timeline-exporter');
      expect(manifest.runtime.kind, PluginRuntimeKind.wasi);
      expect(manifest.permissions, contains(PluginPermission.sceneRead));
      expect(manifest.hooks.single.type, PluginHookType.commandPalette);
      expect(manifest.referencedPaths, contains('bin/plugin.wasm'));
    });

    test('rejects unknown permissions and hook types', () {
      expect(
        () => PluginManifest.fromJson({
          'schemaVersion': 1,
          'pluginId': 'com.example.bad-plugin',
          'displayName': 'Bad Plugin',
          'version': '0.1.0',
          'runtime': {'kind': 'wasi', 'entrypoint': 'bin/plugin.wasm'},
          'permissions': ['project:read', 'network:anywhere'],
          'hooks': [
            {
              'id': 'bad.hook',
              'type': 'everything.everywhere',
              'title': 'Bad Hook',
            },
          ],
          'minimumAppVersion': '0.9.0',
        }),
        throwsA(
          isA<PluginManifestException>()
              .having(
                (e) => e.errors.join('\n'),
                'errors',
                contains('unknown permission: network:anywhere'),
              )
              .having(
                (e) => e.errors.join('\n'),
                'errors',
                contains('unknown hook.type: everything.everywhere'),
              ),
        ),
      );
    });

    test('enforces runtime boundaries', () {
      expect(
        () => PluginManifest.fromJson({
          'schemaVersion': 1,
          'pluginId': 'com.example.no-entrypoint',
          'displayName': 'No Entrypoint',
          'version': '0.1.0',
          'runtime': {'kind': 'wasi'},
          'permissions': ['project:read'],
          'hooks': [
            {
              'id': 'example.command',
              'type': 'command.palette',
              'title': 'Example',
            },
          ],
          'minimumAppVersion': '0.9.0',
        }),
        throwsA(
          isA<PluginManifestException>().having(
            (e) => e.errors,
            'errors',
            contains('wasi runtime requires an entrypoint'),
          ),
        ),
      );

      expect(
        () => PluginManifest.fromJson({
          'schemaVersion': 1,
          'pluginId': 'com.example.template-only',
          'displayName': 'Template Only',
          'version': '0.1.0',
          'runtime': {'kind': 'templateOnly', 'entrypoint': 'bin/nope'},
          'permissions': [],
          'hooks': [],
          'minimumAppVersion': '0.9.0',
        }),
        throwsA(
          isA<PluginManifestException>().having(
            (e) => e.errors,
            'errors',
            contains('templateOnly runtime must not declare an entrypoint'),
          ),
        ),
      );
    });
  });

  group('PluginRegistry', () {
    test('indexes hooks only for enabled plugins', () {
      final manifest = PluginManifest.fromJson({
        'schemaVersion': 1,
        'pluginId': 'com.example.timeline-exporter',
        'displayName': 'Timeline Exporter',
        'version': '0.1.0',
        'runtime': {'kind': 'wasi', 'entrypoint': 'bin/plugin.wasm'},
        'permissions': ['project:read'],
        'hooks': [
          {
            'id': 'timeline.export',
            'type': 'command.palette',
            'title': 'Export Timeline',
          },
          {
            'id': 'timeline.metric',
            'type': 'production.metric',
            'title': 'Timeline Metrics',
          },
        ],
        'minimumAppVersion': '0.9.0',
      });
      final registry = PluginRegistry();

      registry.install(
        InstalledPluginRecord(
          manifest: manifest,
          bundlePath: '/plugins/timeline',
          manifestDigest: 'sha256:test',
          installedAt: DateTime.utc(2026, 5, 25),
          enabled: false,
        ),
      );

      expect(registry.snapshot.enabledHooks, isEmpty);

      registry.enable(manifest.pluginId);

      expect(registry.snapshot.enabledHooks, hasLength(2));
      expect(
        registry.hooksForType(PluginHookType.commandPalette).single.hook.id,
        'timeline.export',
      );

      registry.disable(manifest.pluginId);

      expect(registry.snapshot.enabledHooks, isEmpty);
    });

    test('computes permission diffs for upgrades and enable reviews', () {
      final previous = {
        PluginPermission.projectRead,
        PluginPermission.sceneRead,
      };
      final next = {PluginPermission.projectRead, PluginPermission.sceneWrite};

      final diff = PluginPermissionDiff.between(previous, next);

      expect(diff.added, {PluginPermission.sceneWrite});
      expect(diff.removed, {PluginPermission.sceneRead});
      expect(diff.unchanged, {PluginPermission.projectRead});
      expect(diff.hasChanges, isTrue);
    });
  });
}
