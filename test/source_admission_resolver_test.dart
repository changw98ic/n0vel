import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/source_admission_resolver.dart';
import 'package:novel_writer/features/story_generation/domain/source_ledger_models.dart';

void main() {
  group('SourceAdmissionResolver', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('source_admission_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('fails closed when no source-ledger manifest is present', () {
      _writeJsonl('${tempDir.path}/refined_scenes.jsonl', [
        {'chunk_id': 'synthetic_1', 'excerpt': '合成素材：一个人在雨中调整计划。'},
      ]);

      final resolver = SourceAdmissionResolver.empty();
      final bundle = resolver.resolveRoot(
        rootPath: tempDir.path,
        requestedUsage: ReferenceUsage.licensedExcerpts,
      );

      expect(bundle.allowed, isFalse);
      expect(bundle.referenceUsage, ReferenceUsage.off);
      expect(bundle.denialReasonCode, SourceAdmissionReasonCode.unknownSource);
      expect(bundle.toPromptSafeJson(), isNot(contains('sourceIds')));
    });

    test('does not treat processing manifest.json as source authorization', () {
      _writeJson('${tempDir.path}/manifest.json', {
        'producer': 'chunker-v1',
        'source': 'synthetic-input.txt',
        'recordCount': 1,
      });

      final resolver = SourceAdmissionResolver.fromManifestFile(
        File('${tempDir.path}/manifest.json'),
      );
      final bundle = resolver.resolveRoot(
        rootPath: tempDir.path,
        requestedUsage: ReferenceUsage.abstractFeaturesOnly,
      );

      expect(bundle.allowed, isFalse);
      expect(
        bundle.denialReasonCode,
        SourceAdmissionReasonCode.processingManifestOnly,
      );
    });

    test('allows restricted sources only for reviewed abstract features', () {
      final manifest = _writeSourceManifest(tempDir, [
        for (final sourceId in const [
          'src-restricted-a',
          'src-restricted-b',
          'src-restricted-c',
        ])
          _ledger(
            sourceId: sourceId,
            licenseStatus: 'restricted',
            allowedUses: ['abstractFeatures', 'localRiskScan'],
            excerptLimitChars: null,
          ),
      ]);

      final resolver = SourceAdmissionResolver.fromManifestFile(manifest);
      final abstractBundle = resolver.resolveRoot(
        rootPath: tempDir.path,
        requestedUsage: ReferenceUsage.abstractFeaturesOnly,
        abstractFeatures: const {'rhythm_profile': '短长错落'},
        contributionShares: const {
          'src-restricted-a': 0.34,
          'src-restricted-b': 0.33,
          'src-restricted-c': 0.33,
        },
      );
      final excerptBundle = resolver.resolveRoot(
        rootPath: tempDir.path,
        requestedUsage: ReferenceUsage.licensedExcerpts,
      );

      expect(abstractBundle.allowed, isTrue);
      expect(
        abstractBundle.referenceUsage,
        ReferenceUsage.abstractFeaturesOnly,
      );
      expect(abstractBundle.abstractFeatures, {'rhythm_profile': '短长错落'});
      expect(excerptBundle.allowed, isFalse);
      expect(
        excerptBundle.denialReasonCode,
        SourceAdmissionReasonCode.usageNotAllowed,
      );
    });

    test('carries licensed excerpt limit and blocks raw label leakage', () {
      final manifest = _writeSourceManifest(tempDir, [
        _ledger(
          sourceId: 'src-licensed-excerpt',
          title: 'Synthetic Licensed Anthology',
          creator: 'Synthetic Rights Holder',
          licenseStatus: 'licensed',
          allowedUses: ['abstractFeatures', 'shortExcerpt'],
          excerptLimitChars: 96,
        ),
      ]);

      final bundle = SourceAdmissionResolver.fromManifestFile(manifest)
          .resolveRoot(
            rootPath: tempDir.path,
            requestedUsage: ReferenceUsage.licensedExcerpts,
          );

      expect(bundle.allowed, isTrue);
      expect(bundle.maxExcerptCharsForSource('src-licensed-excerpt'), 96);
      final encoded = jsonEncode(bundle.toPromptSafeJson());
      final auditEncoded = jsonEncode(bundle.toAuditJson());
      expect(encoded, isNot(contains('src-licensed-excerpt')));
      expect(auditEncoded, contains('src-licensed-excerpt'));
      expect(encoded, isNot(contains('Synthetic Licensed Anthology')));
      expect(encoded, isNot(contains('Synthetic Rights Holder')));
      expect(encoded, isNot(contains(tempDir.path)));
      expect(encoded, isNot(contains('provenance')));
    });

    test('licensed excerpts require an explicit positive ledger limit', () {
      final manifest = _writeSourceManifest(tempDir, [
        _ledger(
          sourceId: 'src-unbounded-excerpt',
          licenseStatus: 'licensed',
          allowedUses: ['shortExcerpt'],
          excerptLimitChars: null,
        ),
      ]);

      final bundle = SourceAdmissionResolver.fromManifestFile(manifest)
          .resolveRoot(
            rootPath: tempDir.path,
            requestedUsage: ReferenceUsage.licensedExcerpts,
          );

      expect(bundle.allowed, isFalse);
      expect(
        bundle.denialReasonCode,
        SourceAdmissionReasonCode.manifestInvalid,
      );
    });

    test('restricted ledger claims cannot authorize excerpts', () {
      final manifest = _writeSourceManifest(tempDir, [
        _ledger(
          sourceId: 'src-restricted-excerpt-claim',
          licenseStatus: 'restricted',
          allowedUses: ['shortExcerpt'],
          excerptLimitChars: 80,
        ),
      ]);

      final bundle = SourceAdmissionResolver.fromManifestFile(manifest)
          .resolveRoot(
            rootPath: tempDir.path,
            requestedUsage: ReferenceUsage.licensedExcerpts,
          );

      expect(bundle.allowed, isFalse);
      expect(
        bundle.denialReasonCode,
        SourceAdmissionReasonCode.manifestInvalid,
      );
    });

    test('excerpt permission cannot authorize abstract prompt fields', () {
      final manifest = _writeSourceManifest(tempDir, [
        _ledger(
          sourceId: 'src-excerpt-only',
          licenseStatus: 'licensed',
          allowedUses: ['shortExcerpt'],
          excerptLimitChars: 80,
        ),
      ]);

      final bundle = SourceAdmissionResolver.fromManifestFile(manifest)
          .resolveRoot(
            rootPath: tempDir.path,
            requestedUsage: ReferenceUsage.licensedExcerpts,
            abstractFeatures: const {'rhythm_profile': '短句推进'},
          );

      expect(bundle.allowed, isFalse);
      expect(
        bundle.denialReasonCode,
        SourceAdmissionReasonCode.usageNotAllowed,
      );
    });

    test('returns an explicit reason for unsafe imitation intent', () {
      final manifest = _writeSourceManifest(tempDir, [
        _ledger(
          sourceId: 'src-imitation-target',
          title: 'Synthetic Source',
          creator: 'Synthetic Creator',
          licenseStatus: 'licensed',
          allowedUses: ['abstractFeatures'],
        ),
      ]);

      final bundle = SourceAdmissionResolver.fromManifestFile(manifest)
          .resolveRoot(
            rootPath: tempDir.path,
            requestedUsage: ReferenceUsage.abstractFeaturesOnly,
            rawIntent: '请模仿 Synthetic Creator 的文风。',
          );

      expect(bundle.allowed, isFalse);
      expect(
        bundle.denialReasonCode,
        SourceAdmissionReasonCode.unsafeImitationIntent,
      );
    });

    test('allows user-owned full context when explicitly authorized', () {
      final manifest = _writeSourceManifest(tempDir, [
        _ledger(
          sourceId: 'src-user-owned',
          licenseStatus: 'userOwned',
          allowedUses: ['abstractFeatures', 'fullContext'],
          excerptLimitChars: null,
        ),
      ]);

      final bundle = SourceAdmissionResolver.fromManifestFile(manifest)
          .resolveRoot(
            rootPath: tempDir.path,
            requestedUsage: ReferenceUsage.userOwnedFullContext,
          );

      expect(bundle.allowed, isTrue);
      expect(bundle.referenceUsage, ReferenceUsage.userOwnedFullContext);
      expect(bundle.maxDominantSourceShare, 1.0);
    });

    test(
      'blocks third-party single-source dominance but exempts user-owned voice',
      () {
        final thirdParty = SourceLedgerEntry.fromJson(
          _ledger(
            sourceId: 'src-third-party',
            licenseStatus: 'licensed',
            allowedUses: ['abstractFeatures'],
          ),
        );
        final userOwned = SourceLedgerEntry.fromJson(
          _ledger(
            sourceId: 'src-own-voice',
            licenseStatus: 'userOwned',
            allowedUses: ['abstractFeatures', 'fullContext'],
          ),
        );
        const policy = SourceDominancePolicy();

        expect(
          policy
              .evaluate({thirdParty.sourceId: 1.0}, sources: [thirdParty])
              .decision,
          SourceDominanceDecision.manualReview,
        );
        expect(
          policy
              .evaluate({userOwned.sourceId: 1.0}, sources: [userOwned])
              .decision,
          SourceDominanceDecision.allow,
        );
      },
    );

    test('manual-reviews unknown contribution share source ids', () {
      final thirdParty = SourceLedgerEntry.fromJson(
        _ledger(
          sourceId: 'src-third-party',
          licenseStatus: 'licensed',
          allowedUses: ['abstractFeatures'],
        ),
      );

      final result = const SourceDominancePolicy().evaluate(
        {thirdParty.sourceId: 0.50, 'src-unknown': 0.50},
        sources: [thirdParty],
      );

      expect(result.decision, SourceDominanceDecision.manualReview);
      expect(
        result.reasonCode,
        SourceAdmissionReasonCode.dominantThirdPartySource,
      );
    });

    test(
      'default tracked manifest binds production roots but denies unknown licenses',
      () {
        final resolver = SourceAdmissionResolver.fromDefaultManifest();
        final manifest = resolver.manifest;

        expect(manifest, isNotNull);
        expect(manifest!.rootBindings, hasLength(3));
        expect(
          manifest.rootBindings.map((binding) => binding.rootPath).toSet(),
          containsAll(<String>{
            'artifacts/writing_reference/jianlai',
            'artifacts/writing_reference/guimi',
            'artifacts/writing_reference/tigui',
          }),
        );

        for (final rootPath in const <String>[
          'artifacts/writing_reference/jianlai',
          'artifacts/writing_reference/guimi',
          'artifacts/writing_reference/tigui',
        ]) {
          final bundle = resolver.resolveRoot(
            rootPath: rootPath,
            requestedUsage: ReferenceUsage.abstractFeaturesOnly,
          );
          final promptSafe = jsonEncode(bundle.toPromptSafeJson());

          expect(bundle.allowed, isFalse, reason: rootPath);
          expect(
            bundle.denialReasonCode,
            SourceAdmissionReasonCode.licenseStatusUnknown,
            reason: rootPath,
          );
          expect(promptSafe, isNot(contains('剑来')), reason: rootPath);
          expect(promptSafe, isNot(contains('烽火戏诸侯')), reason: rootPath);
          expect(promptSafe, isNot(contains('诡秘之主')), reason: rootPath);
          expect(promptSafe, isNot(contains('爱潜水的乌贼')), reason: rootPath);
          expect(promptSafe, isNot(contains('我身体里有只鬼')), reason: rootPath);
          expect(promptSafe, isNot(contains('artifacts/writing_reference')));
          expect(promptSafe, isNot(contains('assets/novels')));
        }
      },
    );

    test('rejects duplicate source ids in a source ledger manifest', () {
      final source = _ledger(
        sourceId: 'src-duplicate',
        licenseStatus: 'licensed',
        allowedUses: ['abstractFeatures'],
      );

      expect(
        () => SourceLedgerManifest.fromJson({
          'schemaVersion': 'source-ledger-v1',
          'generatedAtMs': 1780000000000,
          'entries': [source, source],
        }),
        throwsFormatException,
      );
    });

    test('rejects root bindings that reference unknown source ids', () {
      expect(
        () => SourceLedgerManifest.fromJson({
          'schemaVersion': 'source-ledger-v1',
          'generatedAtMs': 1780000000000,
          'entries': [
            _ledger(
              sourceId: 'src-known',
              licenseStatus: 'licensed',
              allowedUses: ['abstractFeatures'],
            ),
          ],
          'rootBindings': [
            {
              'rootPath': tempDir.path,
              'sourceIds': ['src-missing'],
            },
          ],
        }),
        throwsFormatException,
      );
    });

    test(
      'does not admit a path-confused sibling root through default binding',
      () {
        final root = Directory('${tempDir.path}/approved')..createSync();
        final sibling = Directory('${tempDir.path}/approved-sibling')
          ..createSync();
        final manifest = _writeSourceManifest(root, [
          _ledger(
            sourceId: 'src-approved',
            licenseStatus: 'licensed',
            allowedUses: ['abstractFeatures'],
          ),
        ]);
        final resolver = SourceAdmissionResolver.fromManifestFile(manifest);

        final approved = resolver.resolveRoot(
          rootPath: root.path,
          requestedUsage: ReferenceUsage.abstractFeaturesOnly,
        );
        final confused = resolver.resolveRoot(
          rootPath: sibling.path,
          requestedUsage: ReferenceUsage.abstractFeaturesOnly,
        );

        expect(approved.allowed, isTrue);
        expect(confused.allowed, isFalse);
        expect(
          confused.denialReasonCode,
          SourceAdmissionReasonCode.unknownSource,
        );
      },
    );
  });
}

File _writeSourceManifest(Directory root, List<Map<String, Object?>> sources) {
  final file = File('${root.path}/source_manifest.json');
  _writeJson(file.path, {
    'schemaVersion': 'source-ledger-v1',
    'generatedAtMs': 1780000000000,
    'entries': sources,
  });
  return file;
}

Map<String, Object?> _ledger({
  required String sourceId,
  String title = 'Synthetic Source',
  String? creator = 'Synthetic Creator',
  required String licenseStatus,
  required List<String> allowedUses,
  int? excerptLimitChars = 120,
}) {
  final json = <String, Object?>{
    'sourceId': sourceId,
    'title': title,
    'licenseStatus': licenseStatus,
    'allowedUses': allowedUses,
    'provenanceUri': 'memory://synthetic/$sourceId',
    'provenanceHash': 'sha256:${'b' * 64}',
    'jurisdiction': 'test',
    'determinationDateMs': 1780000000000,
    'attributionRequired': false,
    'reviewedBy': 'test-suite',
    'reviewedAtMs': 1780000000001,
  };
  if (creator != null) {
    json['creator'] = creator;
  }
  if (excerptLimitChars != null) {
    json['excerptLimitChars'] = excerptLimitChars;
  }
  return json;
}

void _writeJson(String path, Map<String, Object?> json) {
  File(path).writeAsStringSync(jsonEncode(json));
}

void _writeJsonl(String path, List<Map<String, Object?>> records) {
  File(path).writeAsStringSync(records.map(jsonEncode).join('\n'));
}
