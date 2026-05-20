// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('Scene prompt projection fixtures', () {
    late List<dynamic> fixtures;

    setUp(() {
      final file = File(
        'test/fixtures/golden_prompts/scene_prompt_projection_fixtures.json',
      );
      final raw = file.readAsStringSync();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      fixtures = decoded['fixtures'] as List<dynamic>;
    });

    test('contains exactly 3 fixtures', () {
      expect(fixtures, hasLength(3));
    });

    for (var i = 0; i < 3; i++) {
      test(
        'fixture-${i + 1} has all required section headers in built prompt',
        () {
          final f = fixtures[i] as Map<String, dynamic>;
          final requiredSections = (f['requiredSections'] as List<dynamic>)
              .cast<String>();

          final prompt = _buildPrompt(
            sceneTitle: f['sceneTitle'] as String,
            sceneSummary: f['sceneSummary'] as String,
            cast: (f['cast'] as List<dynamic>).cast<Map<String, dynamic>>(),
            memoryContext: (f['memoryContext'] as List<dynamic>).cast<String>(),
            targetBeat: f['targetBeat'] as String,
          );

          for (final header in requiredSections) {
            expect(
              prompt,
              contains('## $header'),
              reason: 'Missing section header: $header in fixture index $i',
            );
          }
        },
      );

      test('fixture-${i + 1} matches golden prompt projection', () {
        final f = fixtures[i] as Map<String, dynamic>;
        final prompt = _buildPrompt(
          sceneTitle: f['sceneTitle'] as String,
          sceneSummary: f['sceneSummary'] as String,
          cast: (f['cast'] as List<dynamic>).cast<Map<String, dynamic>>(),
          memoryContext: (f['memoryContext'] as List<dynamic>).cast<String>(),
          targetBeat: f['targetBeat'] as String,
        );

        expect(
          _normalizePrompt(prompt),
          _normalizePrompt(f['goldenPrompt'] as String),
        );
      });

      test('fixture-${i + 1} token estimate is within expectedTokenRange', () {
        final f = fixtures[i] as Map<String, dynamic>;
        final range = f['expectedTokenRange'] as Map<String, dynamic>;
        final minTokens = range['min'] as int;
        final maxTokens = range['max'] as int;

        final prompt = _buildPrompt(
          sceneTitle: f['sceneTitle'] as String,
          sceneSummary: f['sceneSummary'] as String,
          cast: (f['cast'] as List<dynamic>).cast<Map<String, dynamic>>(),
          memoryContext: (f['memoryContext'] as List<dynamic>).cast<String>(),
          targetBeat: f['targetBeat'] as String,
        );

        final estimate = _estimateTokens(prompt);

        expect(
          estimate,
          greaterThanOrEqualTo(minTokens),
          reason:
              'Token estimate $estimate below minimum $minTokens for fixture index $i',
        );
        expect(
          estimate,
          lessThanOrEqualTo(maxTokens),
          reason:
              'Token estimate $estimate above maximum $maxTokens for fixture index $i',
        );
      });
    }
  });
}

String _buildPrompt({
  required String sceneTitle,
  required String sceneSummary,
  required List<Map<String, dynamic>> cast,
  required List<String> memoryContext,
  required String targetBeat,
}) {
  final buffer = StringBuffer();

  buffer.writeln('## SCENE BRIEF');
  buffer.writeln('Scene: $sceneTitle');
  buffer.writeln(sceneSummary);
  buffer.writeln();

  buffer.writeln('## CAST');
  for (final member in cast) {
    final name = member['name'] as String;
    final role = member['role'] as String;
    final traits = (member['traits'] as List<dynamic>).cast<String>().join(
      ', ',
    );
    buffer.writeln('- $name ($role): $traits');
  }
  buffer.writeln();

  buffer.writeln('## MEMORY CONTEXT');
  for (final entry in memoryContext) {
    buffer.writeln('- $entry');
  }
  buffer.writeln();

  buffer.writeln('## TARGET BEAT');
  buffer.writeln(targetBeat);
  buffer.writeln();

  buffer.writeln('## OUTPUT CONTRACT');
  buffer.writeln(
    'Write prose following the scene brief and target beat above.',
  );

  return buffer.toString();
}

/// Rough token estimate: ~4 characters per token for English/mixed content.
int _estimateTokens(String text) {
  return (text.length / 4).ceil();
}

String _normalizePrompt(String text) {
  return text.replaceAll('\r\n', '\n').trimRight();
}
