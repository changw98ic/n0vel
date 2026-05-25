import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/template/template.dart';

void main() {
  group('TemplateInstaller', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('n0vel_template_test_');
    });

    tearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    test('creates an install plan for a local template bundle', () async {
      await _writeValidBundle(root);

      final plan = await const TemplateInstaller().createInstallPlan(root);

      expect(plan.bundleRootPath, root.absolute.path);
      expect(plan.manifest.templateId, 'cn-webnovel-basic');
      expect(plan.manifestDigest, startsWith('sha256:'));
      expect(
        plan.referencedFiles.map((file) => file.relativePath),
        containsAll([
          'template.n0vel.json',
          'README.md',
          'project.n0vel.json',
          'bible/characters/protagonist.md',
        ]),
      );
    });

    test('rejects missing starter files', () async {
      await _writeValidBundle(root, writeCharacter: false);

      expect(
        () => const TemplateInstaller().createInstallPlan(root),
        throwsA(
          isA<TemplateInstallException>().having(
            (e) => e.errors.join('\n'),
            'errors',
            contains(
              'referenced file does not exist: '
              'bible/characters/protagonist.md',
            ),
          ),
        ),
      );
    });

    test('rejects template bundles without README', () async {
      await _writeValidBundle(root, writeReadme: false);

      expect(
        () => const TemplateInstaller().createInstallPlan(root),
        throwsA(
          isA<TemplateInstallException>().having(
            (e) => e.errors.join('\n'),
            'errors',
            contains('referenced file does not exist: README.md'),
          ),
        ),
      );
    });

    test('rejects unsafe paths before creating an install plan', () async {
      await _writeValidBundle(
        root,
        overrides: {
          'starterFiles': ['../outside.md'],
        },
      );

      expect(
        () => const TemplateInstaller().createInstallPlan(root),
        throwsA(
          isA<TemplateInstallException>().having(
            (e) => e.errors,
            'errors',
            contains('unsafe starter file path: ../outside.md'),
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
  bool writeCharacter = true,
}) async {
  if (writeReadme) {
    await File('${root.path}/README.md').writeAsString('Template readme');
  }
  await File('${root.path}/project.n0vel.json').writeAsString('{}');

  final characterDir = Directory('${root.path}/bible/characters');
  await characterDir.create(recursive: true);
  if (writeCharacter) {
    await File(
      '${characterDir.path}/protagonist.md',
    ).writeAsString('# Protagonist');
  }

  final manifest = <String, Object?>{
    'schemaVersion': 1,
    'templateId': 'cn-webnovel-basic',
    'displayName': 'CN Webnovel Basic',
    'version': '1.0.0',
    'locale': 'zh-CN',
    'minimumAppVersion': '0.9.0',
    'genre': 'webnovel',
    'tags': ['cn', 'webnovel'],
    'starterFiles': ['project.n0vel.json', 'bible/characters/protagonist.md'],
    ...overrides,
  };

  await File(
    '${root.path}/template.n0vel.json',
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(manifest));
}
