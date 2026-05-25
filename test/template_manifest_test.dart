import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/template/template.dart';

void main() {
  group('TemplateManifest', () {
    test('parses a valid template manifest', () {
      final manifest = TemplateManifest.fromJson({
        'schemaVersion': 1,
        'templateId': 'cn-webnovel-basic',
        'displayName': 'CN Webnovel Basic',
        'version': '1.0.0',
        'locale': 'zh-CN',
        'minimumAppVersion': '0.9.0',
        'description': 'A serialized fiction starter.',
        'genre': 'webnovel',
        'tags': ['cn', 'webnovel'],
        'pipelinePreset': 'webnovel-fast-v1',
        'uiPreset': 'studio-focus',
        'projectSeed': {
          'title': 'Untitled Webnovel',
          'genre': 'webnovel',
          'language': 'zh-CN',
          'synopsis': 'A starter synopsis.',
          'targetWordCount': 120000,
        },
        'starterFiles': [
          'project.n0vel.json',
          {'path': 'bible/characters/protagonist.md', 'role': 'character'},
          'chapters/ch01/scene-001.md',
        ],
      });

      expect(manifest.templateId, 'cn-webnovel-basic');
      expect(manifest.locale, 'zh-CN');
      expect(manifest.projectSeed.targetWordCount, 120000);
      expect(manifest.starterFiles, hasLength(3));
      expect(manifest.starterFiles.first.role, 'project');
      expect(manifest.starterFiles.last.role, 'scene');
      expect(
        manifest.referencedPaths,
        contains('bible/characters/protagonist.md'),
      );
      expect(manifest.toJson()['pipelinePreset'], 'webnovel-fast-v1');
    });

    test('rejects unsafe and duplicate starter paths', () {
      expect(
        () => TemplateManifest.fromJson({
          'schemaVersion': 1,
          'templateId': 'bad-template',
          'displayName': 'Bad Template',
          'version': '1.0.0',
          'locale': 'en-US',
          'minimumAppVersion': '0.9.0',
          'starterFiles': [
            '../outside.md',
            'chapters/ch01/scene.md',
            'chapters/ch01/scene.md',
          ],
        }),
        throwsA(
          isA<TemplateManifestException>()
              .having(
                (e) => e.errors.join('\n'),
                'errors',
                contains('unsafe starter file path: ../outside.md'),
              )
              .having(
                (e) => e.errors.join('\n'),
                'errors',
                contains('duplicate starter file: chapters/ch01/scene.md'),
              ),
        ),
      );
    });

    test('enforces id, version, locale, and seed validation', () {
      expect(
        () => TemplateManifest.fromJson({
          'schemaVersion': 2,
          'templateId': 'Bad Template',
          'displayName': 'Bad Template',
          'version': '1',
          'locale': 'not a locale',
          'minimumAppVersion': '0.9',
          'projectSeed': {'targetWordCount': -1},
        }),
        throwsA(
          isA<TemplateManifestException>()
              .having(
                (e) => e.errors,
                'errors',
                contains('schemaVersion must be 1'),
              )
              .having(
                (e) => e.errors,
                'errors',
                contains('templateId must be lowercase ASCII slug'),
              )
              .having(
                (e) => e.errors,
                'errors',
                contains('version must be SemVer'),
              )
              .having(
                (e) => e.errors,
                'errors',
                contains('minimumAppVersion must be SemVer'),
              )
              .having(
                (e) => e.errors,
                'errors',
                contains('locale must be a BCP-47-like tag'),
              )
              .having(
                (e) => e.errors,
                'errors',
                contains(
                  'projectSeed.targetWordCount must be a positive integer',
                ),
              ),
        ),
      );
    });
  });
}
