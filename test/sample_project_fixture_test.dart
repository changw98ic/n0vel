import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sample project fixture', () {
    late Map<String, Object?> fixture;

    setUpAll(() {
      final raw = File(
        'test/fixtures/sample_project_fixture.json',
      ).readAsStringSync();
      fixture = jsonDecode(raw) as Map<String, Object?>;
    });

    test('contains the onboarding content required by issue 8', () {
      expect(fixture['title'], isA<String>());
      expect((fixture['title']! as String).trim(), isNotEmpty);

      final characters = fixture['characters']! as List<Object?>;
      final worldRules = fixture['worldRules']! as List<Object?>;
      final scenes = fixture['scenes']! as List<Object?>;
      final styleNotes = fixture['styleNotes']! as List<Object?>;

      expect(characters, hasLength(greaterThanOrEqualTo(2)));
      expect(worldRules, hasLength(greaterThanOrEqualTo(1)));
      expect(scenes, hasLength(greaterThanOrEqualTo(2)));
      expect(styleNotes, hasLength(greaterThanOrEqualTo(1)));
    });

    test('uses only public fictional onboarding content', () {
      final encoded = jsonEncode(fixture).toLowerCase();

      for (final forbidden in [
        'api_key',
        'api key',
        '/users/',
        'copyright',
        'private',
      ]) {
        expect(encoded, isNot(contains(forbidden)));
      }
    });
  });
}
