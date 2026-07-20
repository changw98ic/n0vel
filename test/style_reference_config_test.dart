import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/generation_pipeline_config.dart';
import 'package:novel_writer/features/story_generation/data/retrieval_controller.dart';
import 'package:novel_writer/features/story_generation/data/scene_pipeline_models.dart';
import 'package:novel_writer/features/story_generation/data/story_generation_models.dart';
import 'package:novel_writer/features/story_generation/data/style_reference_config.dart';
import 'package:novel_writer/features/story_generation/domain/source_ledger_models.dart';

void main() {
  group('StyleReferenceConfig WP0 source boundary', () {
    test('defaults to neutral disabled instead of a named reference work', () {
      const style = StyleReferenceConfig.defaultEnabled();
      const config = GenerationPipelineConfig();

      expect(style.enabled, isFalse);
      expect(style.promptSummary, isEmpty);
      expect(style.referenceLabel, isEmpty);
      expect(style.rootPath, isEmpty);
      expect(style.allowWritingReferenceRetrieval, isFalse);
      expect(config.enableWritingReference, isFalse);
      expect(config.styleReferenceConfig.enabled, isFalse);
    });

    test('raw workspace profile cannot self-authorize prompt rendering', () {
      final style = StyleReferenceConfig.fromProfile(
        intensity: 1,
        profileId: 'p1',
        profileName: '剑来参考',
        profileSource: 'workspace',
        profileJson: const <String, Object?>{
          'rhythm_profile': '短长错落',
          'notes': '模仿剑来文风',
          'writing_reference_root': 'artifacts/writing_reference/jianlai',
        },
      );

      expect(style.enabled, isFalse);
      expect(style.promptSummary, isEmpty);
      expect(style.rootPath, isEmpty);
      expect(style.allowWritingReferenceRetrieval, isFalse);
      expect(style.profileJson, isEmpty);
    });

    test(
      'licensed excerpt-only bundle enables retrieval without prompt text',
      () {
        final tempDir = Directory.systemTemp.createTempSync(
          'style_reference_excerpt_test_',
        );
        addTearDown(() {
          if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
        });
        _writeSourceManifest(tempDir, [
          _ledger(
            sourceId: 'src-excerpt',
            title: 'Synthetic Excerpt Source',
            allowedUses: ['shortExcerpt'],
          ),
        ]);

        final style = StyleReferenceConfig.fromProfile(
          intensity: 1,
          profileJson: <String, Object?>{
            'writing_reference_root': tempDir.path,
            'reference_usage': 'licensedExcerpts',
          },
        );

        expect(style.enabled, isTrue);
        expect(style.promptSummary, isEmpty);
        expect(style.approvedBundle, isNotNull);
        expect(style.approvedBundle!.abstractFeatures, isEmpty);
        expect(
          style.approvedBundle!.referenceUsage,
          ReferenceUsage.licensedExcerpts,
        );
        expect(style.allowWritingReferenceRetrieval, isTrue);
        expect(style.profileJson, isEmpty);
      },
    );

    test('local analysis usage never renders or enables prompt injection', () {
      final tempDir = Directory.systemTemp.createTempSync(
        'style_reference_local_analysis_test_',
      );
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });
      _writeSourceManifest(tempDir, [
        _ledger(
          sourceId: 'src-local',
          title: 'Synthetic Local Scan Source',
          allowedUses: ['localRiskScan'],
        ),
      ]);

      final style = StyleReferenceConfig.fromProfile(
        intensity: 1,
        profileJson: <String, Object?>{
          'writing_reference_root': tempDir.path,
          'reference_usage': 'localAnalysisOnly',
          'rhythm_profile': '只用于本地诊断',
        },
      );

      expect(style.enabled, isFalse);
      expect(style.promptSummary, isEmpty);
      expect(style.approvedBundle, isNull);
      expect(style.allowWritingReferenceRetrieval, isFalse);
      expect(style.profileJson, isEmpty);
    });

    test('legal multi-source abstract bundle renders prompt-safe features', () {
      final tempDir = Directory.systemTemp.createTempSync(
        'style_reference_manifest_test_',
      );
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });
      _writeSourceManifest(tempDir, [
        _ledger(sourceId: 'src-a', title: 'Synthetic Source A'),
        _ledger(sourceId: 'src-b', title: 'Synthetic Source B'),
        _ledger(sourceId: 'src-c', title: 'Synthetic Source C'),
      ]);

      final style = StyleReferenceConfig.fromProfile(
        intensity: 2,
        profileName: '不应渲染的显示名',
        profileJson: <String, Object?>{
          'writing_reference_root': tempDir.path,
          'rhythm_profile': '短长错落，段末留白',
          'narrative_distance': 'close',
          'tone_keywords': ['克制', '清晰'],
          'source_contribution_shares': {
            'src-a': 0.34,
            'src-b': 0.33,
            'src-c': 0.33,
          },
        },
      );

      expect(style.enabled, isTrue);
      expect(style.approvedBundle, isNotNull);
      expect(
        style.approvedBundle!.referenceUsage,
        ReferenceUsage.abstractFeaturesOnly,
      );
      expect(style.promptSummary, contains('强度：2'));
      expect(style.promptSummary, contains('节奏：短长错落，段末留白'));
      expect(style.promptSummary, contains('语气关键词：克制、清晰'));
      expect(style.promptSummary, isNot(contains('Synthetic Source')));
      expect(style.promptSummary, isNot(contains('Synthetic Creator')));
      expect(style.promptSummary, isNot(contains(tempDir.path)));
      expect(style.allowWritingReferenceRetrieval, isFalse);
      expect(style.profileJson, equals(style.approvedBundle!.abstractFeatures));
    });

    test('user-owned abstract fields still remove source labels', () {
      final tempDir = Directory.systemTemp.createTempSync(
        'style_reference_owned_label_test_',
      );
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });
      _writeSourceManifest(tempDir, [
        _ledger(
          sourceId: 'src-own-voice',
          title: 'Synthetic Own Voice',
          creator: 'Synthetic Own Creator',
          licenseStatus: 'userOwned',
          allowedUses: ['abstractFeatures'],
        ),
      ]);

      final style = StyleReferenceConfig.fromProfile(
        intensity: 2,
        profileJson: <String, Object?>{
          'writing_reference_root': tempDir.path,
          'rhythm_profile': '沿用 Synthetic Own Voice 的短句结构',
        },
      );

      expect(style.enabled, isTrue);
      expect(style.promptSummary, isNot(contains('Synthetic Own Voice')));
      expect(style.promptSummary, isNot(contains('Synthetic Own Creator')));
      expect(style.promptSummary, contains('[受保护来源]'));
    });

    test('central unknown named work profile remains disabled', () {
      final style = StyleReferenceConfig.fromProfile(
        intensity: 1,
        profileName: '剑来参考',
        profileJson: const <String, Object?>{'rhythm_profile': '短长错落'},
      );

      expect(style.enabled, isFalse);
      expect(style.promptSummary, isEmpty);
      expect(style.approvedBundle, isNull);
    });

    test('imitation notes deny an otherwise admitted abstract profile', () {
      final tempDir = Directory.systemTemp.createTempSync(
        'style_reference_imitation_test_',
      );
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });
      _writeSourceManifest(tempDir, [
        _ledger(sourceId: 'src-a', title: 'Synthetic Source A'),
        _ledger(sourceId: 'src-b', title: 'Synthetic Source B'),
        _ledger(sourceId: 'src-c', title: 'Synthetic Source C'),
      ]);

      final style = StyleReferenceConfig.fromProfile(
        intensity: 1,
        profileJson: <String, Object?>{
          'writing_reference_root': tempDir.path,
          'rhythm_profile': '短长错落',
          'notes': '模仿 Synthetic Source A 的文风',
          'source_contribution_shares': {
            'src-a': 0.34,
            'src-b': 0.33,
            'src-c': 0.33,
          },
        },
      );

      expect(style.enabled, isFalse);
      expect(style.promptSummary, isEmpty);
      expect(style.approvedBundle, isNull);
    });

    test(
      'retrieval controller does not construct a default writing reference',
      () {
        const controller = RetrievalController();
        final roleTurn = RolePlayTurnOutput.fromDynamicAgentOutput(
          const DynamicRoleAgentOutput(
            characterId: 'c1',
            name: '角色',
            text:
                '立场：试探\n动作：开口\n禁忌：直白\n'
                '检索：search_writing_reference|对白 潜台词|需要写对白潜台词时',
          ),
        );

        final capsules = controller.resolve(
          taskCard: _taskCard(),
          turns: [roleTurn],
        );

        expect(roleTurn.retrievalIntents, hasLength(1));
        expect(capsules, isEmpty);
      },
    );
  });
}

void _writeSourceManifest(Directory root, List<Map<String, Object?>> entries) {
  File('${root.path}/source_manifest.json').writeAsStringSync(
    jsonEncode({
      'schemaVersion': 'source-ledger-v1',
      'generatedAtMs': 1780000000000,
      'entries': entries,
    }),
  );
}

Map<String, Object?> _ledger({
  required String sourceId,
  required String title,
  String creator = 'Synthetic Creator',
  String licenseStatus = 'licensed',
  List<String> allowedUses = const ['abstractFeatures'],
}) {
  return {
    'sourceId': sourceId,
    'title': title,
    'creator': creator,
    'licenseStatus': licenseStatus,
    'allowedUses': allowedUses,
    'provenanceUri': 'memory://synthetic/$sourceId',
    'provenanceHash': 'sha256:${'a' * 64}',
    'jurisdiction': 'test',
    'determinationDateMs': 1780000000000,
    'excerptLimitChars': 120,
    'attributionRequired': false,
    'reviewedBy': 'test-suite',
    'reviewedAtMs': 1780000000001,
  };
}

SceneTaskCard _taskCard() {
  return SceneTaskCard(
    brief: SceneBrief(
      chapterId: 'ch1',
      chapterTitle: 'chapter',
      sceneId: 'sc1',
      sceneTitle: 'test',
      sceneSummary: 'summary',
      targetBeat: 'beat',
    ),
    cast: [
      ResolvedSceneCastMember(
        characterId: 'c1',
        name: '角色',
        role: '主角',
        contributions: [SceneCastContribution.action],
      ),
    ],
    directorPlan: 'plan',
  );
}
