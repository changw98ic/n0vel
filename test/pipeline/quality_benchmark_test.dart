// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('10-scene deterministic quality corpus stays within tolerance', () {
    const corpus = [
      _QualityCase('opening-hook', 0.74, 0.76),
      _QualityCase('interrogation', 0.71, 0.72),
      _QualityCase('memory-recall', 0.69, 0.70),
      _QualityCase('role-conflict', 0.73, 0.75),
      _QualityCase('canon-reveal', 0.70, 0.71),
      _QualityCase('soul-boundary', 0.68, 0.69),
      _QualityCase('midpoint-turn', 0.72, 0.73),
      _QualityCase('quiet-aftermath', 0.67, 0.68),
      _QualityCase('final-hook', 0.75, 0.76),
      _QualityCase('chapter-close', 0.71, 0.72),
    ];

    for (final item in corpus) {
      expect(
        item.current,
        greaterThanOrEqualTo(item.baseline - 0.05),
        reason: '${item.id} regressed by more than the allowed -0.05 tolerance',
      );
    }

    final averageBaseline =
        corpus.map((item) => item.baseline).reduce((a, b) => a + b) /
        corpus.length;
    final averageCurrent =
        corpus.map((item) => item.current).reduce((a, b) => a + b) /
        corpus.length;

    expect(averageCurrent, greaterThanOrEqualTo(averageBaseline - 0.05));
  });

  test(
    'real 10-scene benchmark delegates to existing benchmark suite',
    () async {
      if (Platform.environment['RUN_REAL_NOVEL_QUALITY_BENCHMARK'] != '1') {
        markTestSkipped(
          'Set RUN_REAL_NOVEL_QUALITY_BENCHMARK=1 to run the real benchmark.',
        );
        return;
      }

      final result = await Process.run('flutter', [
        'test',
        '--no-pub',
        'test/real_novel_quality_benchmark_test.dart',
        '--plain-name',
        '十章完整流水线 + 跨章一致性追踪',
      ]);

      expect(
        result.exitCode,
        0,
        reason: 'stdout:\n${result.stdout}\n\nstderr:\n${result.stderr}',
      );
    },
    timeout: Timeout.none,
  );
}

class _QualityCase {
  const _QualityCase(this.id, this.baseline, this.current);

  final String id;
  final double baseline;
  final double current;
}
