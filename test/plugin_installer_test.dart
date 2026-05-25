import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/plugin/plugin.dart';

void main() {
  group('PluginInstaller', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('n0vel_plugin_test_');
    });

    tearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    test('creates an install plan for a local bundle', () async {
      await _writeValidBundle(root);

      final plan = await const PluginInstaller().createInstallPlan(root);

      expect(plan.bundleRootPath, root.absolute.path);
      expect(plan.manifest.pluginId, 'com.example.timeline-exporter');
      expect(plan.manifestDigest, startsWith('sha256:'));
      expect(
        plan.referencedFiles.map((file) => file.relativePath),
        containsAll(['plugin.n0vel.json', 'README.md', 'bin/plugin.wasm']),
      );
    });

    test('rejects file references that escape the bundle root', () async {
      await _writeValidBundle(
        root,
        overrides: {
          'runtime': {'kind': 'wasi', 'entrypoint': '../plugin.wasm'},
        },
      );

      expect(
        () => const PluginInstaller().createInstallPlan(root),
        throwsA(
          isA<PluginInstallException>().having(
            (e) => e.errors.join('\n'),
            'errors',
            contains('unsafe plugin file reference: ../plugin.wasm'),
          ),
        ),
      );
    });

    test('rejects missing referenced files', () async {
      await _writeValidBundle(root, writeEntrypoint: false);

      expect(
        () => const PluginInstaller().createInstallPlan(root),
        throwsA(
          isA<PluginInstallException>().having(
            (e) => e.errors.join('\n'),
            'errors',
            contains('referenced file does not exist: bin/plugin.wasm'),
          ),
        ),
      );
    });

    test('rejects process runtime unless developer mode allows it', () async {
      await _writeValidBundle(
        root,
        overrides: {
          'runtime': {'kind': 'process', 'entrypoint': 'bin/plugin.wasm'},
        },
      );

      expect(
        () => const PluginInstaller().createInstallPlan(root),
        throwsA(
          isA<PluginInstallException>().having(
            (e) => e.errors,
            'errors',
            contains('process runtime is disabled outside developer mode'),
          ),
        ),
      );

      final plan = await const PluginInstaller(
        allowProcessRuntime: true,
      ).createInstallPlan(root);

      expect(plan.manifest.runtime.kind, PluginRuntimeKind.process);
    });

    test('rejects bundles without README', () async {
      await _writeValidBundle(root, writeReadme: false);

      expect(
        () => const PluginInstaller().createInstallPlan(root),
        throwsA(
          isA<PluginInstallException>().having(
            (e) => e.errors.join('\n'),
            'errors',
            contains('referenced file does not exist: README.md'),
          ),
        ),
      );
    });
  });
}

Future<void> _writeValidBundle(
  Directory root, {
  Map<String, Object?> overrides = const {},
  bool writeReadme = true,
  bool writeEntrypoint = true,
}) async {
  if (writeReadme) {
    await File('${root.path}/README.md').writeAsString('Timeline exporter');
  }
  final bin = Directory('${root.path}/bin');
  await bin.create(recursive: true);
  if (writeEntrypoint) {
    await File('${bin.path}/plugin.wasm').writeAsString('fake wasm');
  }

  final manifest = <String, Object?>{
    'schemaVersion': 1,
    'pluginId': 'com.example.timeline-exporter',
    'displayName': 'Timeline Exporter',
    'version': '0.1.0',
    'runtime': {'kind': 'wasi', 'entrypoint': 'bin/plugin.wasm'},
    'permissions': ['project:read', 'scene:read'],
    'hooks': [
      {
        'id': 'timeline.export',
        'type': 'command.palette',
        'title': 'Export Timeline',
      },
    ],
    'minimumAppVersion': '0.9.0',
    ...overrides,
  };

  await File(
    '${root.path}/plugin.n0vel.json',
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(manifest));
}
