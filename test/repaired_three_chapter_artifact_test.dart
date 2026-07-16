import 'dart:convert';
import 'dart:io';

import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_canonical_hash.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/features/story_generation/data/ai_cliche_detector.dart';
import 'package:novel_writer/features/story_generation/data/chapter_concurrent_runner.dart';
import 'package:novel_writer/features/story_generation/data/generation_pipeline_config.dart';
import 'package:novel_writer/features/story_generation/data/narrative_continuity_verifier.dart';
import 'package:novel_writer/features/story_generation/data/pipeline_stage_runner_impl.dart';
import 'package:novel_writer/features/story_generation/data/production_pre_quality_gate.dart';
import 'package:novel_writer/features/story_generation/data/scene_hard_gates.dart';
import 'package:novel_writer/features/story_generation/data/scene_quality_reporter.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';

const _artifactRoot = 'artifacts/real_validation/three_chapter_repaired';

void main() {
  test('repaired chapters pass production deterministic release gates', () async {
    final allScenes = <String, String>{};
    final chapterPreQualityEvidenceRoots = <String, String>{};
    final scenePreQualityRecords = <Map<String, Object?>>[];
    final chapterCrossSceneRecords = <Map<String, Object?>>[];
    final continuityEventRecords = <Map<String, Object?>>[];
    var continuityLedger = <Map<String, Object?>>[];
    final outlineText = File(
      '$_artifactRoot/outline/three_chapter_outline.md',
    ).readAsStringSync();
    final settings = AppSettingsStore(storage: InMemoryAppSettingsStorage());
    addTearDown(settings.dispose);
    final checkpoints = _ArtifactCheckpointStore();
    final productionRunner = PipelineStageRunnerImpl(
      settingsStore: settings,
      pipelineConfig: const GenerationPipelineConfig(
        enableWritingReference: false,
      ),
    )..checkpointStore = checkpoints;

    for (final chapter in _chapters) {
      final markdown = File(
        '$_artifactRoot/chapters/${chapter.chapterId}.md',
      ).readAsStringSync();
      expect(markdown, isNot(contains(RegExp(r'U盘|存储卡'))));
      if (chapter.chapterId == 'chapter-03') {
        expect(markdown, isNot(contains('活着把他拉上来——这是你刚才的条件')));
        expect(markdown, isNot(contains('把柳溪的枪也推还她')));
        _expectMarkerBefore(
          markdown,
          '“按你说的做，先让人活着，也让证据留下。”',
          '整个人翻出护栏',
          reason: 'The disclosure agreement must not refer to a later fall.',
        );
        _expectMarkerBefore(
          markdown,
          '先退出弹匣',
          '从积水里捡回自己的枪',
          reason: 'Shen Du must retrieve the same unloaded weapon.',
        );
        _expectMarkerBefore(
          markdown,
          '从积水里捡回自己的枪',
          '弹匣重新装好',
          reason: 'The weapon must be in hand before it is reloaded.',
        );
        _expectMarkerBefore(
          markdown,
          '拉套筒上膛',
          '连开两枪',
          reason: 'Reloading must be explicit before Shen Du fires again.',
        );
      }

      final scenes = _parseSceneMarkdown(markdown);
      final predecessorScenes = _parseSceneMarkdown(
        File(
          'artifacts/real_validation/three_chapter_run/chapters/${chapter.chapterId}.md',
        ).readAsStringSync(),
      );
      expect(
        scenes.keys,
        orderedEquals(chapter.sceneTitles),
        reason: '${chapter.chapterId} must retain the four audited scene IDs',
      );
      expect(
        scenes.values.fold<int>(0, (sum, prose) => sum + prose.length),
        greaterThanOrEqualTo(1800),
      );

      final chapterScenes = <String, String>{};
      final scenePreQualityEvidenceHashes = <String>[];
      for (var index = 0; index < chapter.sceneTitles.length; index += 1) {
        final sceneTitle = chapter.sceneTitles[index];
        final sceneId = 'scene-${(index + 1).toString().padLeft(2, '0')}';
        final sceneKey = '${chapter.chapterId}/$sceneId';
        final prose = scenes[sceneTitle]!;
        final continuityDeclarations = _continuityDeclarationsFor(sceneKey);

        final brief = SceneBrief(
          chapterId: chapter.chapterId,
          chapterTitle: chapter.chapterTitle,
          sceneId: sceneId,
          sceneTitle: sceneTitle,
          sceneSummary: chapter.sceneSummaries[index],
          targetLength: 450,
          targetBeat: chapter.sceneSummaries[index],
          sceneIndex: index,
          totalScenesInChapter: chapter.sceneTitles.length,
          formalExecution: true,
          cast: <SceneCastCandidate>[
            SceneCastCandidate(characterId: 'liuxi', name: '柳溪', role: '调查记者'),
            SceneCastCandidate(characterId: 'shendu', name: '沈渡', role: '港区向导'),
          ],
          metadata: <String, Object?>{
            'requireOutlineFidelity': true,
            'requireClicheHardGate': true,
            'requireCharacterIntroduction': true,
            if (index == 0)
              'requiredCharacterIntroductions': <String>['柳溪', '沈渡'],
            'requiredOutlineBeats': chapter.beats[sceneTitle],
            'continuityLedger': continuityLedger,
            'continuityEntityDeclarations': ?continuityDeclarations,
          },
        );

        final continuity = const NarrativeContinuityVerifier().verify(
          brief: brief,
          prose: prose,
        );
        expect(
          continuity.findings,
          isEmpty,
          reason:
              '$sceneKey continuity: ${continuity.findings.map((item) => item.explanation).join(' | ')}',
        );
        productionRunner.checkpointRunId = 'artifact-author-revision:$sceneKey';
        late final ProductionPreQualityEvidence preQualityEvidence;
        try {
          preQualityEvidence = await productionRunner
              .runAuthorRevisionPreQuality(
                brief: brief,
                materials: ProjectMaterialSnapshot(
                  characterProfiles: const <String>['柳溪：调查记者。', '沈渡：港区向导。'],
                  outlineBeats: <String>[outlineText],
                  sceneSummaries: chapter.sceneSummaries,
                ),
                predecessorProse: predecessorScenes[sceneTitle]!,
                revisedProse: prose,
              );
        } on ProductionPreQualityGateViolation catch (error) {
          fail('$sceneKey: $error');
        }
        expect(
          preQualityEvidence.passed,
          isTrue,
          reason:
              '$sceneKey pre-quality: '
              '${preQualityEvidence.hardGateViolations.map((item) => item.text).join(' | ')} '
              '${preQualityEvidence.polishCanonEvidence.failureCodes.join(', ')} '
              '${preQualityEvidence.storyMechanicsEvidence.failureCodes.join(', ')}',
        );
        expect(
          preQualityEvidence.boundaryReleaseHash,
          ProductionPreQualityGate.releaseHash,
        );
        expect(
          preQualityEvidence.sourceMode,
          ProductionPreQualitySourceMode.authorRevision,
        );
        expect(preQualityEvidence.candidateFinalizationEligible, isFalse);
        expect(preQualityEvidence.hardGatesEnabled, isTrue);
        expect(
          preQualityEvidence.briefRequirementsHash,
          ProductionPreQualityGate.briefRequirementsHash(brief),
        );
        expect(preQualityEvidence.toJson()['releaseEligible'], isFalse);
        expect(
          preQualityEvidence.toJson()['nextRequiredStage'],
          'pipeline_polish_revalidation',
        );
        final checkpoint = checkpoints.values.singleWhere(
          (item) => item.runId == 'artifact-author-revision:$sceneKey',
        );
        expect(checkpoint.ordinal, 8);
        expect(checkpoint.stageId, 'deterministic_gate');
        final checkpointPayload =
            checkpoint.artifactJson['payload']! as Map<String, Object?>;
        expect(
          checkpointPayload['productionPreQualityEvidence'],
          preQualityEvidence.toJson(),
        );
        scenePreQualityEvidenceHashes.add(preQualityEvidence.evidenceHash);
        scenePreQualityRecords.add(<String, Object?>{
          'sceneId': sceneKey,
          'sourceMode': preQualityEvidence.sourceMode.name,
          'candidateFinalizationEligible':
              preQualityEvidence.candidateFinalizationEligible,
          'sourceProseHash':
              preQualityEvidence.polishCanonEvidence.prePolishProseHash,
          'finalProseHash': preQualityEvidence.finalProseHash,
          'evidenceHash': preQualityEvidence.evidenceHash,
          'boundaryReleaseHash': preQualityEvidence.boundaryReleaseHash,
          'hardGatesEnabled': preQualityEvidence.hardGatesEnabled,
          'briefRequirementsHash': preQualityEvidence.briefRequirementsHash,
          'checkpointArtifactDigest': checkpoint.artifactDigest,
          'passed': preQualityEvidence.passed,
          'nextRequiredStage': preQualityEvidence.toJson()['nextRequiredStage'],
          'releaseEligible': preQualityEvidence.toJson()['releaseEligible'],
        });
        continuityLedger = continuity.resultingLedgerJson;
        if (continuityDeclarations != null) {
          continuityEventRecords.add(<String, Object?>{
            'sceneId': sceneKey,
            'declaration': continuityDeclarations.single,
            'resultingEntity': continuityLedger.singleWhere(
              (entry) => entry['entityId'] == 'evidence-phone',
            ),
          });
        }
        if (sceneKey == 'chapter-02/scene-01') {
          expect(continuityLedger.single['holder'], 'liuxi');
          expect(continuityLedger.single['location'], '内袋');
        }
        if (sceneKey == 'chapter-02/scene-04') {
          expect(continuityLedger.single['holder'], 'shendu');
          expect(continuityLedger.single['location'], '沈渡手中');
        }
        if (sceneKey == 'chapter-03/scene-03') {
          expect(continuityLedger.single['holder'], 'liuxi');
          expect(continuityLedger.single['location'], '手中');
        }

        allScenes[sceneKey] = prose;
        chapterScenes[sceneKey] = prose;
      }

      final crossSceneViolations = const ChapterCrossSceneClicheGate().evaluate(
        chapterScenes,
      );
      expect(
        crossSceneViolations,
        isEmpty,
        reason: '${chapter.chapterId} contains a repeated cross-scene template',
      );
      chapterCrossSceneRecords.add(<String, Object?>{
        'chapterId': chapter.chapterId,
        'sceneIds': chapterScenes.keys.toList(growable: false),
        'passed': crossSceneViolations.isEmpty,
        'findingCount': crossSceneViolations.length,
        'evidenceHash': AppLlmCanonicalHash.domainHash(
          'production-pre-quality-chapter-cross-scene-v1',
          <String, Object?>{
            'chapterId': chapter.chapterId,
            'sceneProseHashes': <String, Object?>{
              for (final entry in chapterScenes.entries)
                entry.key: AppLlmCanonicalHash.domainHash(
                  'production-pre-quality-cross-scene-prose-v1',
                  entry.value.replaceAll('\r\n', '\n'),
                ),
            },
            'findingCount': crossSceneViolations.length,
          },
        ),
      });
      chapterPreQualityEvidenceRoots[chapter.chapterId] =
          AppLlmCanonicalHash.domainHash(
            'production-pre-quality-chapter-evidence-root-v1',
            <String, Object?>{
              'chapterId': chapter.chapterId,
              'sceneEvidenceHashes': scenePreQualityEvidenceHashes,
            },
          );

      final firstBrief = SceneBrief(
        chapterId: chapter.chapterId,
        chapterTitle: chapter.chapterTitle,
        sceneId: 'scene-01',
        sceneTitle: chapter.sceneTitles.first,
        sceneSummary: chapter.sceneSummaries.first,
        sceneIndex: 0,
        totalScenesInChapter: 4,
        cast: <SceneCastCandidate>[
          SceneCastCandidate(characterId: 'liuxi', name: '柳溪', role: '调查记者'),
          SceneCastCandidate(characterId: 'shendu', name: '沈渡', role: '港区向导'),
        ],
        metadata: const <String, Object?>{
          'requireCharacterIntroduction': true,
          'requiredCharacterIntroductions': <String>['柳溪', '沈渡'],
        },
      );
      final introduction = sceneCharacterIntroductionAudit(
        brief: firstBrief,
        proseText: scenes.values.first,
      );
      expect(introduction.passed, isTrue, reason: introduction.reason);
      expect(introduction.observedNames, containsAll(<String>['柳溪', '沈渡']));
    }

    final repetition = AiClicheDetector().detectAcrossScenes(allScenes);
    final blocking = repetition.findings.where(
      (finding) =>
          finding.kind == AiClicheKind.selfRepeat ||
          finding.kind.name.startsWith('crossScene'),
    );
    expect(
      blocking,
      isEmpty,
      reason: blocking
          .map((finding) => '${finding.kind.name}: ${finding.context}')
          .join(' | '),
    );

    final manifest =
        jsonDecode(File('$_artifactRoot/manifest.json').readAsStringSync())
            as Map<String, Object?>;
    final derived = manifest['derived']! as Map<String, Object?>;
    final productionPath =
        derived['productionPreQualityPath']! as Map<String, Object?>;
    expect(
      productionPath['boundaryReleaseHash'],
      ProductionPreQualityGate.releaseHash,
    );
    expect(
      productionPath['chapterEvidenceRootHashes'],
      chapterPreQualityEvidenceRoots,
    );
    final evidenceRootHash = AppLlmCanonicalHash.domainHash(
      'production-pre-quality-artifact-evidence-root-v1',
      <String, Object?>{
        'chapterEvidenceRootHashes': chapterPreQualityEvidenceRoots,
      },
    );
    expect(productionPath['evidenceRootHash'], evidenceRootHash);
    final artifactSetHash = AppLlmCanonicalHash.domainHash(
      'production-pre-quality-artifact-set-v1',
      <String, Object?>{
        'outlineSha256':
            (derived['authorityCopy']! as Map<String, Object?>)['sha256'],
        'chapterSha256': <String, Object?>{
          for (final entry in derived['chapters']! as List<Object?>)
            ((entry! as Map<String, Object?>)['path']! as String)
                    .split('/')
                    .last
                    .replaceAll('.md', ''):
                (entry as Map<String, Object?>)['sha256'],
        },
        'evidenceRootHash': evidenceRootHash,
      },
    );
    expect(productionPath['artifactSetHash'], artifactSetHash);
    expect(productionPath['qualityStatus'], 'not_run');
    expect(productionPath['candidateFinalizationEligible'], isFalse);
    expect(productionPath['nextRequiredStage'], 'pipeline_polish_revalidation');
    expect(productionPath['candidateProofStatus'], 'not_created');
    expect(productionPath['commitReceiptStatus'], 'not_created');

    final expectedEvidenceFile = <String, Object?>{
      'schemaVersion': 'production-pre-quality-artifact-evidence-v3',
      'artifactStatus': 'unscored_unreleased',
      'boundary': <String, Object?>{
        'name': 'ProductionPreQualityGate',
        'entryPoint': 'PipelineStageRunnerImpl.runAuthorRevisionPreQuality',
        'releaseHash': ProductionPreQualityGate.releaseHash,
        'evidenceRootHash': evidenceRootHash,
        'artifactSetHash': artifactSetHash,
      },
      'source': <String, Object?>{
        'outline': derived['authorityCopy'],
        'chapters': derived['chapters'],
        'predecessors':
            (manifest['source']! as Map<String, Object?>)['historicalChapters'],
      },
      'scenes': scenePreQualityRecords,
      'chapterCrossSceneGates': chapterCrossSceneRecords,
      'continuityEvents': continuityEventRecords,
      'qualityScore': null,
      'candidateFinalizationEligible': false,
      'releaseEligible': false,
      'nextRequiredStage': 'pipeline_polish_revalidation',
      'downstreamArtifacts': <String, Object?>{
        'candidateProof': null,
        'commitReceipt': null,
      },
    };
    final evidencePath = File(
      '$_artifactRoot/reports/production-pre-quality-evidence.json',
    );
    final evidenceFile = jsonDecode(evidencePath.readAsStringSync());
    // Keep the durable artifact byte-for-byte derivable from production
    // authorities rather than trusting a hand-written audit assertion.
    expect(evidenceFile, expectedEvidenceFile);
  });

  test('derived artifact does not mislabel deterministic repair as 95', () {
    expect(SceneQualityReporter.overallMinimum, 95);
    expect(SceneQualityReporter.criticalMinimum, 90);
    expect(
      sceneHardGateReleaseHash,
      'sha256:24af7a88c1a1b4e6bfab417c5f0a795af8eb6bb3cd89bee9c5d23ae44be72074',
    );
    expect(
      File('$_artifactRoot/reports/quality-report.json').existsSync(),
      isFalse,
      reason: 'changed prose must not inherit or fabricate an LLM score',
    );

    final readme = File('$_artifactRoot/README.md').readAsStringSync();
    expect(readme, contains('未评分'));
    expect(readme, contains('未发布'));
    expect(readme, contains('95'));
  });

  test('manifest binds historical authority and the repaired prose', () {
    final manifest =
        jsonDecode(File('$_artifactRoot/manifest.json').readAsStringSync())
            as Map<String, Object?>;
    expect(manifest['artifactStatus'], 'unscored_unreleased');

    final source = manifest['source']! as Map<String, Object?>;
    _expectManifestFile(source['authority']! as Map<String, Object?>);
    for (final entry in source['historicalChapters']! as List<Object?>) {
      _expectManifestFile(entry! as Map<String, Object?>);
    }
    _expectManifestFile(
      source['historicalQualityReport']! as Map<String, Object?>,
    );

    final derived = manifest['derived']! as Map<String, Object?>;
    _expectManifestFile(derived['authorityCopy']! as Map<String, Object?>);
    for (final entry in derived['chapters']! as List<Object?>) {
      _expectManifestFile(entry! as Map<String, Object?>);
    }
    expect(
      (derived['sceneHardGateReleaseHash']! as Map<String, Object?>)['value'],
      sceneHardGateReleaseHash,
    );
    _expectManifestFile(
      derived['productionPreQualityEvidence']! as Map<String, Object?>,
    );
    for (final entry in derived['auditReports']! as List<Object?>) {
      _expectManifestFile(entry! as Map<String, Object?>);
    }

    final audit =
        jsonDecode(
              File(
                '$_artifactRoot/reports/deterministic-repair-audit.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
    final quality = audit['quality']! as Map<String, Object?>;
    final requirements =
        quality['productionReleaseRequirements']! as Map<String, Object?>;
    expect(requirements['sceneHardGateReleaseHash'], sceneHardGateReleaseHash);
    final path = audit['productionPreQualityPath']! as Map<String, Object?>;
    expect(path['boundaryReleaseHash'], ProductionPreQualityGate.releaseHash);
    expect(path['continuityDeclarationCount'], 11);
    expect(path['continuityEventCount'], 12);
    expect(
      path['evidenceFileSha256'],
      _sha256File(
        File('$_artifactRoot/reports/production-pre-quality-evidence.json'),
      ),
    );
    final ledger = audit['evidenceObjectLedger']! as List<Object?>;
    expect(ledger, hasLength(12));
    expect(
      (ledger.first! as Map<String, Object?>)['scene'],
      'chapter-01/scene-02',
    );
  });
}

void _expectManifestFile(Map<String, Object?> entry) {
  final path = entry['path']! as String;
  final actual = _sha256File(File(path));
  expect(actual, entry['sha256'], reason: path);
}

String _sha256File(File file) => const DartSha256()
    .hashSync(file.readAsBytesSync())
    .bytes
    .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
    .join();

void _expectMarkerBefore(
  String text,
  String earlier,
  String later, {
  required String reason,
}) {
  final earlierOffset = text.indexOf(earlier);
  final laterOffset = text.indexOf(later);
  expect(
    earlierOffset,
    greaterThanOrEqualTo(0),
    reason: '$reason Missing: $earlier',
  );
  expect(
    laterOffset,
    greaterThanOrEqualTo(0),
    reason: '$reason Missing: $later',
  );
  expect(earlierOffset, lessThan(laterOffset), reason: reason);
}

Map<String, String> _parseSceneMarkdown(String markdown) {
  final scenes = <String, String>{};
  String? currentTitle;
  var buffer = StringBuffer();

  void flush() {
    final title = currentTitle;
    if (title == null) return;
    scenes[title] = buffer.toString().trim();
  }

  for (final line in markdown.split('\n')) {
    if (line.startsWith('## ')) {
      flush();
      currentTitle = line.substring(3).trim();
      buffer = StringBuffer();
    } else if (currentTitle != null) {
      buffer.writeln(line);
    }
  }
  flush();
  return scenes;
}

Map<String, Object?> _beat(
  String id,
  String description,
  List<List<String>> evidenceGroups,
) => <String, Object?>{
  'id': id,
  'description': description,
  'evidenceGroups': evidenceGroups,
};

List<Map<String, Object?>>? _continuityDeclarationsFor(String sceneKey) {
  final event = switch (sceneKey) {
    'chapter-01/scene-02' => <String, Object?>{
      'eventId': 'evidence-phone-introduced',
      'kind': 'introduce',
      'evidence': '柳溪解锁手机后，把它举到沈渡面前',
      'alias': '手机',
      'holder': 'liuxi',
      'location': '沈渡面前',
      'status': 'held',
    },
    'chapter-01/scene-03' => <String, Object?>{
      'eventId': 'evidence-phone-moved-to-table',
      'kind': 'relocate',
      'evidence': '柳溪把手机放到桌面',
      'alias': '手机',
      'fromHolder': 'liuxi',
      'holder': 'liuxi',
      'location': '桌面',
      'status': 'held',
    },
    'chapter-01/scene-04' => <String, Object?>{
      'eventId': 'evidence-phone-observed-before-escape',
      'kind': 'observe',
      'evidence': '柳溪按住内袋里的手机',
      'alias': '手机',
      'holder': 'liuxi',
      'location': '内袋',
      'status': 'held',
    },
    'chapter-02/scene-01' => <String, Object?>{
      'eventId': 'evidence-phone-observed-in-inner-pocket',
      'kind': 'observe',
      'evidence': '柳溪摸了摸内袋里的手机',
      'alias': '手机',
      'holder': 'liuxi',
      'location': '内袋',
      'status': 'held',
    },
    'chapter-02/scene-02' => <String, Object?>{
      'eventId': 'evidence-phone-moved-to-cover',
      'kind': 'relocate',
      'evidence': '柳溪刚把手机镜头移到封皮前',
      'alias': '手机',
      'fromHolder': 'liuxi',
      'holder': 'liuxi',
      'location': '封皮前',
      'status': 'held',
    },
    'chapter-02/scene-03' => <String, Object?>{
      'eventId': 'evidence-phone-moved-to-backlight',
      'kind': 'relocate',
      'evidence': '柳溪在柜架背光处取出那部手机',
      'alias': '手机',
      'fromHolder': 'liuxi',
      'holder': 'liuxi',
      'location': '柜架背光处',
      'status': 'held',
    },
    'chapter-02/scene-04' => <String, Object?>{
      'eventId': 'evidence-phone-liuxi-to-shendu',
      'kind': 'transfer',
      'evidence': '柳溪没有迟疑，把证据手机递到沈渡手中',
      'alias': '证据手机',
      'fromHolder': 'liuxi',
      'holder': 'shendu',
      'location': '沈渡手中',
      'status': 'held',
    },
    'chapter-03/scene-01' => <String, Object?>{
      'eventId': 'evidence-phone-moved-to-waterproof-bag',
      'kind': 'relocate',
      'evidence': '沈渡把手机按在胸前防水袋里',
      'alias': '手机',
      'fromHolder': 'shendu',
      'holder': 'shendu',
      'location': '胸前防水袋',
      'status': 'held',
    },
    'chapter-03/scene-02' => <String, Object?>{
      'eventId': 'evidence-phone-drawn-in-hand',
      'kind': 'relocate',
      'evidence': '沈渡从防水袋中取出手机，握在手中',
      'alias': '手机',
      'fromHolder': 'shendu',
      'holder': 'shendu',
      'location': '手中',
      'status': 'held',
    },
    'chapter-03/scene-03' => <String, Object?>{
      'eventId': 'evidence-phone-shendu-to-liuxi',
      'kind': 'transfer',
      'evidence': '沈渡把手机交还给柳溪，送到她手中',
      'alias': '手机',
      'fromHolder': 'shendu',
      'holder': 'liuxi',
      'location': '手中',
      'status': 'held',
    },
    'chapter-03/scene-04' => <String, Object?>{
      'eventId': 'evidence-phone-upload-observed',
      'kind': 'observe',
      'evidence': '柳溪把手机举在手中',
      'alias': '手机',
      'holder': 'liuxi',
      'location': '手中',
      'status': 'held',
    },
    _ => null,
  };
  if (event == null) return null;
  final additionalEvent = sceneKey == 'chapter-01/scene-03'
      ? <String, Object?>{
          'eventId': 'evidence-phone-returned-to-inner-pocket',
          'kind': 'relocate',
          'evidence': '柳溪也没去碰那只手。她关掉延迟邮件，把手机重新扣回内袋',
          'alias': '手机',
          'fromHolder': 'liuxi',
          'holder': 'liuxi',
          'location': '内袋',
          'status': 'held',
        }
      : null;
  return <Map<String, Object?>>[
    <String, Object?>{
      'entityId': 'evidence-phone',
      'aliases': <String>['证据手机', '手机'],
      'events': <Map<String, Object?>>[event, ?additionalEvent],
    },
  ];
}

final _chapters = <_ChapterAuditSpec>[
  _ChapterAuditSpec(
    chapterId: 'chapter-01',
    chapterTitle: '第一章 雨夜码头',
    sceneTitles: const <String>['抵达旧码头', '雨棚下的试探', '条件交换', '封港前的离场'],
    sceneSummaries: const <String>[
      '柳溪在封港前拦住沈渡。',
      '沈渡发现风衣纽扣内的定位器。',
      '双方被迫合作并锁定档案楼暗门。',
      '追兵迫使二人进入集装箱暗巷。',
    ],
    beats: <String, List<Map<String, Object?>>>{
      '抵达旧码头': <Map<String, Object?>>[
        _beat('c1-contact', '封港倒计时中建立接触。', <List<String>>[
          <String>['封港'],
          <String>['柳溪'],
          <String>['沈渡'],
        ]),
      ],
      '雨棚下的试探': <Map<String, Object?>>[
        _beat('c1-tracker', '纽扣定位器暴露跟踪。', <List<String>>[
          <String>['纽扣'],
          <String>['微型定位器', '追踪器'],
          <String>['清道夫报坐标', '盯梢'],
        ]),
      ],
      '条件交换': <Map<String, Object?>>[
        _beat('c1-deal', '建立合作并锁定物理位置。', <List<String>>[
          <String>['合作', '成交'],
          <String>['档案楼'],
          <String>['暗门', '暗库'],
        ]),
      ],
      '封港前的离场': <Map<String, Object?>>[
        _beat('c1-hook', '追杀中交出档案楼暗门警告。', <List<String>>[
          <String>['封港警报'],
          <String>['探照灯', '光柱'],
          <String>['集装箱暗巷'],
          <String>['底册不在账本里'],
          <String>['送死'],
        ]),
      ],
    },
  ),
  _ChapterAuditSpec(
    chapterId: 'chapter-02',
    chapterTitle: '第二章 档案楼暗门',
    sceneTitles: const <String>['侧门潜入', '封存柜检索', '发现被动过的底册', '撤离前的分歧'],
    sceneSummaries: const <String>[
      '两人经档案楼暗门潜入。',
      '找到旧航运底册并争执证据去向。',
      '紫外光还原被撕关键页的资金压痕。',
      '清道夫焊死出口，唯一生路是天台。',
    ],
    beats: <String, List<Map<String, Object?>>>{
      '侧门潜入': <Map<String, Object?>>[
        _beat('c2-entry', '经隐藏入口潜入档案楼。', <List<String>>[
          <String>['档案楼'],
          <String>['暗门'],
          <String>['进入', '潜入'],
        ]),
      ],
      '封存柜检索': <Map<String, Object?>>[
        _beat('c2-ledger', '找到底册并形成拍摄与销毁冲突。', <List<String>>[
          <String>['底册'],
          <String>['手机'],
          <String>['拍下', '拍'],
          <String>['原件'],
          <String>['销毁', '烧掉'],
        ]),
      ],
      '发现被动过的底册': <Map<String, Object?>>[
        _beat('c2-imprint', '从撕页压痕恢复资金密码。', <List<String>>[
          <String>['撕走', '撕掉', '撕页'],
          <String>['紫外'],
          <String>['压痕'],
          <String>['资金'],
          <String>['代码', '密码'],
        ]),
      ],
      '撤离前的分歧': <Map<String, Object?>>[
        _beat('c2-rooftop', '清道夫焊门后只剩天台出口。', <List<String>>[
          <String>['焊死', '焊点'],
          <String>['清道夫'],
          <String>['唯一'],
          <String>['天台'],
        ]),
      ],
    },
  ),
  _ChapterAuditSpec(
    chapterId: 'chapter-03',
    chapterTitle: '第三章 天台交锋',
    sceneTitles: const <String>['逼退到天台', '公开还是潜伏', '分头计划', '转折与余波'],
    sceneSummaries: const <String>[
      '清道夫封住天台出口。',
      '两人拔枪争执是否立即上传。',
      '重火力迫使沈渡交还手机并掩护上传。',
      '上传成功同时沈渡中弹坠向楼外。',
    ],
    beats: <String, List<Map<String, Object?>>>{
      '逼退到天台': <Map<String, Object?>>[
        _beat('c3-rooftop', '清道夫把二人逼入天台掩体。', <List<String>>[
          <String>['清道夫'],
          <String>['天台'],
          <String>['遮蔽', '冷却机'],
        ]),
      ],
      '公开还是潜伏': <Map<String, Object?>>[
        _beat('c3-standoff', '双方拔枪争夺手机去向。', <List<String>>[
          <String>['拔枪', '举平'],
          <String>['手机'],
          <String>['砸了', '砸碎'],
          <String>['上传'],
        ]),
      ],
      '分头计划': <Map<String, Object?>>[
        _beat('c3-cover', '重火力下交还手机并掩护上传。', <List<String>>[
          <String>['重火力'],
          <String>['枪平放', '放下枪'],
          <String>['回到柳溪', '交还给柳溪'],
          <String>['上传'],
        ]),
      ],
      '转折与余波': <Map<String, Object?>>[
        _beat('c3-cliffhanger', '上传完成与中弹坠落同时发生。', <List<String>>[
          <String>['全网发送'],
          <String>['中弹', '血花'],
          <String>['翻出护栏', '天台边缘'],
          <String>['抓住'],
          <String>['上传成功'],
          <String>['清算路径', '清算网'],
        ]),
      ],
    },
  ),
];

final class _ChapterAuditSpec {
  _ChapterAuditSpec({
    required this.chapterId,
    required this.chapterTitle,
    required this.sceneTitles,
    required this.sceneSummaries,
    required this.beats,
  });

  final String chapterId;
  final String chapterTitle;
  final List<String> sceneTitles;
  final List<String> sceneSummaries;
  final Map<String, List<Map<String, Object?>>> beats;
}

final class _ArtifactCheckpointStore implements PipelineCheckpointStore {
  final List<PipelineStageCheckpoint> values = <PipelineStageCheckpoint>[];

  @override
  Future<List<PipelineStageCheckpoint>> load({required String runId}) async =>
      List<PipelineStageCheckpoint>.unmodifiable(
        values.where((item) => item.runId == runId),
      );

  @override
  Future<void> save(PipelineStageCheckpoint checkpoint) async {
    values.removeWhere(
      (item) =>
          item.runId == checkpoint.runId &&
          item.ordinal == checkpoint.ordinal &&
          item.stageAttempt == checkpoint.stageAttempt,
    );
    values.add(checkpoint);
  }
}
