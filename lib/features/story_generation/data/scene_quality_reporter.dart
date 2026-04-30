import 'dart:convert';

import '../domain/scene_models.dart';

class SceneQualityReporter {
  const SceneQualityReporter._();

  static String toMarkdown(List<SceneRuntimeOutput> outputs) {
    final buffer = StringBuffer()
      ..writeln('# Scene Quality Report')
      ..writeln()
      ..writeln(
        '| Scene | Review | 综合 | 文笔 | 连贯 | 角色 | 完整 | Attempts | Summary |',
      )
      ..writeln('|---|---:|---:|---:|---:|---:|---:|---:|---|');

    for (final output in outputs) {
      final score = output.qualityScore;
      buffer.writeln(
        [
          _sceneLabel(output),
          output.review.decision.name,
          _score(score?.overall),
          _score(score?.prose),
          _score(score?.coherence),
          _score(score?.character),
          _score(score?.completeness),
          output.proseAttempts.toString(),
          _escapeTable(score?.summary ?? '未记录'),
        ].join(' | ').surroundWithPipes(),
      );
    }

    buffer.writeln();
    buffer.writeln('## Review Notes');
    buffer.writeln();
    for (final output in outputs) {
      buffer
        ..writeln('### ${_sceneLabel(output)}')
        ..writeln()
        ..writeln(
          '- Judge: ${output.review.judge.status.name} - ${output.review.judge.reason}',
        )
        ..writeln(
          '- Consistency: ${output.review.consistency.status.name} - ${output.review.consistency.reason}',
        )
        ..writeln('- Soft failures: ${output.softFailureCount}')
        ..writeln('- Characters: ${output.prose.text.trim().length}')
        ..writeln();
    }

    return buffer.toString().trimRight();
  }

  static String toJson(List<SceneRuntimeOutput> outputs) {
    final data = <String, Object?>{
      'generatedAtMs': DateTime.now().millisecondsSinceEpoch,
      'sceneCount': outputs.length,
      'scenes': [for (final output in outputs) _sceneToJson(output)],
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  static Map<String, Object?> _sceneToJson(SceneRuntimeOutput output) {
    final score = output.qualityScore;
    return <String, Object?>{
      'chapterId': output.brief.chapterId,
      'chapterTitle': output.brief.chapterTitle,
      'sceneId': output.brief.sceneId,
      'sceneTitle': output.brief.sceneTitle,
      'proseAttempts': output.proseAttempts,
      'softFailureCount': output.softFailureCount,
      'characterCount': output.prose.text.trim().length,
      'review': <String, Object?>{
        'decision': output.review.decision.name,
        'judgeStatus': output.review.judge.status.name,
        'judgeReason': output.review.judge.reason,
        'consistencyStatus': output.review.consistency.status.name,
        'consistencyReason': output.review.consistency.reason,
      },
      if (score != null) 'qualityScore': score.toJson(),
    };
  }

  static String _sceneLabel(SceneRuntimeOutput output) {
    return '${output.brief.chapterId}/${output.brief.sceneId} '
        '${_escapeTable(output.brief.sceneTitle)}';
  }

  static String _score(double? value) {
    if (value == null) return 'n/a';
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  static String _escapeTable(String value) {
    return value.replaceAll('|', r'\|').replaceAll('\n', ' ');
  }
}

extension on String {
  String surroundWithPipes() => '| $this |';
}
