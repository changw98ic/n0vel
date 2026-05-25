import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/template/template.dart';

void main() {
  group('TemplateCatalog', () {
    test('exposes built-in templates', () {
      final snapshot = BuiltInTemplateCatalog.snapshot;

      expect(snapshot.entries, isNotEmpty);
      expect(snapshot.find('blank-novel'), isNotNull);
      expect(snapshot.find('cn-webnovel-basic'), isNotNull);
      expect(snapshot.byLocale('zh-CN').single.templateId, 'cn-webnovel-basic');
      expect(
        snapshot.bySource(TemplateCatalogSource.builtIn),
        hasLength(snapshot.entries.length),
      );
    });

    test('installs, finds, replaces, and removes local templates', () {
      final manifest = _manifest(templateId: 'local-basic');
      final catalog = TemplateCatalog();
      final entry = TemplateCatalogEntry(
        manifest: manifest,
        source: TemplateCatalogSource.local,
        bundleRootPath: '/templates/local-basic',
        manifestDigest: 'sha256:test',
        installedAt: DateTime.utc(2026, 5, 26),
      );

      catalog.install(entry);

      expect(catalog.find('local-basic'), entry);
      expect(
        () => catalog.install(entry),
        throwsA(
          isA<TemplateCatalogException>().having(
            (e) => e.message,
            'message',
            contains('template already installed: local-basic'),
          ),
        ),
      );

      final replacement = TemplateCatalogEntry(
        manifest: _manifest(templateId: 'local-basic', version: '1.1.0'),
        source: TemplateCatalogSource.local,
        bundleRootPath: '/templates/local-basic',
        manifestDigest: 'sha256:next',
      );
      catalog.replace(replacement);

      expect(catalog.find('local-basic')?.manifest.version, '1.1.0');

      catalog.uninstall('local-basic');

      expect(catalog.find('local-basic'), isNull);
    });
  });

  group('TemplateApplicationPlanner', () {
    test(
      'creates an inert project application plan from a built-in template',
      () {
        final entry = BuiltInTemplateCatalog.snapshot.find('blank-novel')!;

        final plan = const TemplateApplicationPlanner().createPlan(
          entry,
          projectName: 'My Novel',
          targetProjectId: 'project_test',
          now: DateTime.utc(2026, 5, 26),
        );

        expect(plan.targetProjectId, 'project_test');
        expect(plan.projectName, 'My Novel');
        expect(plan.templateId, 'blank-novel');
        expect(plan.requiresVersionAnchor, isTrue);
        expect(plan.versionAnchorLabel, 'Project initialization: Blank Novel');
        expect(plan.projectMetadata['title'], 'My Novel');
        expect(plan.projectMetadata['templateId'], 'blank-novel');
        expect(plan.starterFiles, isEmpty);
      },
    );

    test(
      'maps local starter files into source paths without applying them',
      () {
        final root = Directory('/tmp/local-template');
        final entry = TemplateCatalogEntry(
          manifest: _manifest(starterFiles: ['project.n0vel.json']),
          source: TemplateCatalogSource.local,
          bundleRootPath: root.path,
          manifestDigest: 'sha256:test',
        );

        final plan = const TemplateApplicationPlanner().createPlan(
          entry,
          projectName: 'Local Story',
          targetProjectId: 'project_local',
        );

        expect(plan.hasStarterFiles, isTrue);
        expect(plan.starterFiles.single.relativePath, 'project.n0vel.json');
        expect(
          plan.starterFiles.single.sourcePath?.replaceAll(r'\', '/'),
          '/tmp/local-template/project.n0vel.json',
        );
      },
    );

    test('requires a project name when the template has no title seed', () {
      final entry = TemplateCatalogEntry(
        manifest: _manifest(),
        source: TemplateCatalogSource.builtIn,
      );

      expect(
        () => const TemplateApplicationPlanner().createPlan(
          entry,
          projectName: '  ',
        ),
        throwsA(isA<TemplateApplicationException>()),
      );
    });
  });
}

TemplateManifest _manifest({
  String templateId = 'local-basic',
  String version = '1.0.0',
  List<Object?> starterFiles = const [],
}) {
  return TemplateManifest.fromJson({
    'schemaVersion': 1,
    'templateId': templateId,
    'displayName': 'Local Basic',
    'version': version,
    'locale': 'en-US',
    'minimumAppVersion': '0.9.0',
    'starterFiles': starterFiles,
  });
}
