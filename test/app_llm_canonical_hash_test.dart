import 'dart:convert';
import 'dart:io';

import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_canonical_hash.dart';

void main() {
  group(AppLlmCanonicalHash.contract, () {
    test('sorts object keys recursively without reordering arrays', () {
      final left = {
        'z': [3, 2, 1],
        'a': {'y': true, 'x': 1.0},
      };
      final right = {
        'a': {'x': 1, 'y': true},
        'z': [3, 2, 1],
      };

      expect(
        AppLlmCanonicalHash.canonicalJson(left),
        '{"a":{"x":1,"y":true},"z":[3,2,1]}',
      );
      expect(
        AppLlmCanonicalHash.domainHash('test-v1', left),
        AppLlmCanonicalHash.domainHash('test-v1', right),
      );
      expect(
        AppLlmCanonicalHash.domainHash('test-v1', left),
        isNot(
          AppLlmCanonicalHash.domainHash('test-v1', {
            ...right,
            'z': [1, 2, 3],
          }),
        ),
      );
    });

    test('normalizes NFC before serialization and hashing', () {
      const composed = 'café';
      const decomposed = 'cafe\u0301';

      expect(
        AppLlmCanonicalHash.canonicalJson({'b': 2, 'a': decomposed}),
        '{"a":"café","b":2}',
      );
      expect(
        AppLlmCanonicalHash.domainHash('prompt-release-v1', {
          'a': decomposed,
          'b': 2,
        }),
        AppLlmCanonicalHash.domainHash('prompt-release-v1', {
          'b': 2,
          'a': composed,
        }),
      );
    });

    test('matches the independent UTF-8/SHA-256 golden vector', () {
      expect(
        AppLlmCanonicalHash.domainHash('prompt-release-v1', {
          'b': 2,
          'a': 'cafe\u0301',
        }),
        'sha256:45a51b477b558dc56c9184f97f581dca59476e3ff26d5f5540a5980cee32f262',
      );
    });

    test('retains an explicit reader for legacy v1 digests', () {
      expect(AppLlmCanonicalHash.legacyContract, contains('limited'));
      expect(
        AppLlmCanonicalHash.legacyDomainHash('prompt-release-v1', {
          'b': 2,
          'a': 'cafe\u0301',
        }),
        'sha256:e2c95488067ac9295952795695a56e35664244eb07a1092d6f5571460581b0c4',
      );
    });

    test('domain separation changes the digest', () {
      final value = {'same': 'payload'};
      expect(
        AppLlmCanonicalHash.domainHash('prompt-release-v1', value),
        isNot(AppLlmCanonicalHash.domainHash('generation-bundle-v1', value)),
      );
    });

    test('fails closed on ambiguous or invalid scalar input', () {
      expect(
        () => AppLlmCanonicalHash.canonicalJson({'é': 1, 'e\u0301': 2}),
        throwsFormatException,
      );
      expect(
        () => AppLlmCanonicalHash.canonicalJson(double.nan),
        throwsArgumentError,
      );
      expect(
        () => AppLlmCanonicalHash.canonicalJson(String.fromCharCode(0xd800)),
        throwsFormatException,
      );
    });

    test('normalizes canonical ordering across multiple scripts', () {
      expect(AppLlmCanonicalHash.normalizeNfc('α\u0313'), 'ἀ');
      expect(
        AppLlmCanonicalHash.normalizeNfc('a\u0302\u0323'),
        AppLlmCanonicalHash.normalizeNfc('a\u0323\u0302'),
      );
      expect(AppLlmCanonicalHash.normalizeNfc('\u1100\u1161\u11a8'), '각');
    });

    test(
      'passes every Unicode 17.0.0 NFC conformance vector',
      () {
        final fixture = File(
          'test/fixtures/unicode-17.0.0/NormalizationTest.txt',
        );
        final bytes = fixture.readAsBytesSync();
        final digest = const DartSha256()
            .hashSync(bytes)
            .bytes
            .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
            .join();
        expect(
          digest,
          '5019ffd530751a741900c849c0e010332f142a3612234639bd200b82138a87db',
        );
        var cases = 0;
        for (final rawLine in const LineSplitter().convert(
          utf8.decode(bytes),
        )) {
          final content = rawLine.split('#').first.trim();
          if (content.isEmpty || content.startsWith('@')) continue;
          final fields = content
              .split(';')
              .map((value) => value.trim())
              .toList();
          if (fields.length < 5) {
            throw TestFailure('malformed NormalizationTest row: $rawLine');
          }
          final values = fields
              .take(5)
              .map(_decodeCodePoints)
              .toList(growable: false);
          _expectNormalized(values[0], values[1], rawLine);
          _expectNormalized(values[1], values[1], rawLine);
          _expectNormalized(values[2], values[1], rawLine);
          _expectNormalized(values[3], values[3], rawLine);
          _expectNormalized(values[4], values[3], rawLine);
          cases += 1;
        }
        expect(cases, greaterThan(19000));
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}

String _decodeCodePoints(String value) => String.fromCharCodes(
  value
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => int.parse(part, radix: 16)),
);

void _expectNormalized(String input, String expected, String source) {
  final actual = AppLlmCanonicalHash.normalizeNfc(input);
  if (actual != expected) {
    throw TestFailure(
      'NFC mismatch for $source: '
      'actual=${actual.runes.map((value) => value.toRadixString(16)).join(' ')} '
      'expected=${expected.runes.map((value) => value.toRadixString(16)).join(' ')}',
    );
  }
}
