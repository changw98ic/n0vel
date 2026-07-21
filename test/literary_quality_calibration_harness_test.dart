import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/literary_quality_calibration_harness.dart';

void main() {
  final root = Directory('test/fixtures/story_quality/dev_v1');

  test('development corpus has 300 unique admitted fixtures', () {
    final corpus = LiteraryQualityDevelopmentCorpus.loadSync(root);

    expect(corpus.fixtures, hasLength(300));
    expect(corpus.provenance, hasLength(300));
    expect(corpus.primaryFamilyCounts, {
      'causalMainlineHard': 30,
      'povKnowledge': 30,
      'worldObjectTime': 30,
      'motivationRelationship': 30,
      'craftWeakness': 50,
      'styleChoice': 50,
      'effectiveDeviation': 30,
      'prettyHollow': 30,
      'highScoreDisguisedBad': 20,
    });
    expect(corpus.voiceTagCounts.values, everyElement(60));
    expect(corpus.negativeControlCounts.values, everyElement(10));
    expect(corpus.anchorCounts.keys.toSet(), {'60', '75', '85', '90', '95'});
  });

  test('development artifact cannot impersonate formal certification', () {
    final corpus = LiteraryQualityDevelopmentCorpus.loadSync(root);
    final artifact = LiteraryQualityDevelopmentCalibrationArtifact.loadSync(
      File('${root.path}/calibration-development.json'),
      corpus,
    );

    expect(artifact.uniqueItemCount, 300);
    expect(artifact.metricStatus, 'pendingRealEvaluatorRun');
    expect(artifact.humanAdjudicatedHardDecisions, 0);
    expect(artifact.humanAdjudicatedNonHardDecisions, 0);
    expect(artifact.formalCertificationEligible, isFalse);
    expect(artifact.limitation, contains('does not satisfy'));
  });

  test('high-score disguised bad fixtures never become release eligible', () {
    final corpus = LiteraryQualityDevelopmentCorpus.loadSync(root);
    final disguised = corpus.fixtures
        .where((fixture) => fixture.primaryFamily == 'highScoreDisguisedBad')
        .toList(growable: false);

    expect(disguised, hasLength(20));
    for (final fixture in disguised) {
      expect(fixture.anchorScore, 95);
      expect(fixture.expectedFindingClasses, contains('hardError'));
      expect(fixture.expectedBlocked, isTrue);
      expect(fixture.expectedReleaseEligible, isFalse);
    }
  });

  test('development corpus rejects a truncated fixture shard', () {
    final temporary = _copyCorpusToTemporaryDirectory(root);
    try {
      final shard = File(
        '${temporary.path}/fixtures/high_score_disguised_bad.jsonl',
      );
      final lines = shard.readAsLinesSync()..removeLast();
      shard.writeAsStringSync('${lines.join('\n')}\n');

      expect(
        () => LiteraryQualityDevelopmentCorpus.loadSync(temporary),
        throwsFormatException,
      );
    } finally {
      temporary.deleteSync(recursive: true);
    }
  });

  test('Wilson interval uses unique decision count as its denominator', () {
    final perfectSmall = LiteraryQualityWilsonInterval.calculate(
      successes: 25,
      sampleSize: 25,
    );
    final nearPerfectLarge = LiteraryQualityWilsonInterval.calculate(
      successes: 294,
      sampleSize: 300,
    );

    expect(perfectSmall.point, 1);
    expect(perfectSmall.ci95Low, closeTo(0.8668, 0.0002));
    expect(nearPerfectLarge.point, 0.98);
    expect(nearPerfectLarge.ci95Low, greaterThan(0.95));
    expect(
      () => LiteraryQualityWilsonInterval.calculate(
        successes: 26,
        sampleSize: 25,
      ),
      throwsArgumentError,
    );
  });
}

Directory _copyCorpusToTemporaryDirectory(Directory source) {
  final target = Directory.systemTemp.createTempSync(
    'novel-writer-literary-corpus-',
  );
  for (final entity in source.listSync(recursive: true)) {
    final relativePath = entity.path.substring(source.path.length + 1);
    final destinationPath = '${target.path}/$relativePath';
    if (entity is Directory) {
      Directory(destinationPath).createSync(recursive: true);
    } else if (entity is File) {
      File(destinationPath).parent.createSync(recursive: true);
      entity.copySync(destinationPath);
    }
  }
  return target;
}
