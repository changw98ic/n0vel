import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/domain/source_ledger_models.dart';

void main() {
  group('SourceLedgerEntry', () {
    test(
      'rejects unknown license status instead of guessing a safe default',
      () {
        expect(
          () => SourceLedgerEntry.fromJson({
            ..._baseLedgerJson(),
            'licenseStatus': 'maybeLicensed',
          }),
          throwsFormatException,
        );
      },
    );

    test('rejects unknown allowed use instead of mapping to adjacent use', () {
      expect(
        () => SourceLedgerEntry.fromJson({
          ..._baseLedgerJson(),
          'allowedUses': ['abstractFeatures', 'styleTransfer'],
        }),
        throwsFormatException,
      );
    });

    test('rejects unknown keys instead of silently accepting extra claims', () {
      expect(
        () => SourceLedgerEntry.fromJson({
          ..._baseLedgerJson(),
          'permissionMemo': 'synthetic extra claim',
        }),
        throwsFormatException,
      );
    });

    test('rejects restricted entries that claim excerpt permission', () {
      expect(
        () => SourceLedgerEntry.fromJson({
          ..._baseLedgerJson(),
          'licenseStatus': 'restricted',
          'allowedUses': ['shortExcerpt'],
        }),
        throwsFormatException,
      );
    });

    test('requires a positive explicit limit for excerpt permission', () {
      expect(
        () => SourceLedgerEntry.fromJson({
          ..._baseLedgerJson(),
          'licenseStatus': 'licensed',
          'allowedUses': ['shortExcerpt'],
          'excerptLimitChars': null,
        }),
        throwsFormatException,
      );
    });

    test(
      'parses valid ledger entries with strict lower camel enum strings',
      () {
        final entry = SourceLedgerEntry.fromJson(_baseLedgerJson());

        expect(entry.sourceId, 'src-user-voice');
        expect(entry.licenseStatus, SourceLicenseStatus.userOwned);
        expect(entry.allowedUses, contains(AllowedSourceUse.abstractFeatures));
        expect(entry.allowedUses, contains(AllowedSourceUse.fullContext));
      },
    );

    test(
      'canonical json is deterministic and excludes prompt-unsafe labels',
      () {
        final entry = SourceLedgerEntry.fromJson(_baseLedgerJson());
        final canonical = entry.toCanonicalJson();
        final encoded = jsonEncode(canonical);

        expect(
          canonical.keys.toList(),
          orderedEquals(canonical.keys.toList()..sort()),
        );
        expect(encoded, contains('src-user-voice'));
        expect(encoded, isNot(contains('Synthetic Voice Notes')));
        expect(encoded, isNot(contains('Test Author')));
        expect(encoded, isNot(contains('/tmp/')));
        expect(encoded, isNot(contains('provenanceUri')));
        expect(entry.canonicalHash, isNotEmpty);
        expect(
          entry.canonicalHash,
          SourceLedgerEntry.fromJson(_baseLedgerJson()).canonicalHash,
        );
        expect(
          entry.canonicalHash,
          isNot(
            SourceLedgerEntry.fromJson({
              ..._baseLedgerJson(),
              'title': 'Changed Synthetic Voice Notes',
            }).canonicalHash,
          ),
        );
      },
    );
  });
}

Map<String, Object?> _baseLedgerJson() {
  return {
    'sourceId': 'src-user-voice',
    'title': 'Synthetic Voice Notes',
    'creator': 'Test Author',
    'licenseStatus': 'userOwned',
    'allowedUses': ['abstractFeatures', 'fullContext'],
    'provenanceUri': 'memory://synthetic/user-owned',
    'provenanceHash': 'sha256:${'a' * 64}',
    'jurisdiction': 'test',
    'determinationDateMs': 1780000000000,
    'excerptLimitChars': 180,
    'attributionRequired': false,
    'reviewedBy': 'test-suite',
    'reviewedAtMs': 1780000000001,
  };
}
