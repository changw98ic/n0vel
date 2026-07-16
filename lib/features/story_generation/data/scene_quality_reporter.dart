import 'dart:convert';

import '../domain/scene_models.dart';
import 'ai_cliche_detector.dart';
import 'scene_hard_gates.dart';

class SceneQualityReporter {
  const SceneQualityReporter._();

  static const int overallMinimum = 95;
  static const int criticalMinimum = 90;

  static String toMarkdown(List<SceneRuntimeOutput> outputs) {
    final repetitionReport = _repetitionReport(outputs);
    final blockingRepetition = _blockingRepetitionFindings(repetitionReport);
    final buffer = StringBuffer()
      ..writeln('# Scene Quality Report')
      ..writeln()
      ..writeln(
        '| Scene | Review | 综合 | 文笔 | 文风 | 修辞 | 节奏 | 忠实 | 连贯 | 角色 | 完整 | Attempts | Summary | Warning |',
      )
      ..writeln(
        '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|',
      );

    for (final output in outputs) {
      final score = output.qualityScore;
      buffer.writeln(
        [
          _sceneLabel(output),
          output.review.decision.name,
          _score(score?.overall),
          _score(score?.prose),
          _score(score?.style),
          _score(score?.imagery),
          _score(score?.rhythm),
          _score(score?.faithfulness),
          _score(score?.coherence),
          _score(score?.character),
          _score(score?.completeness),
          output.proseAttempts.toString(),
          _escapeTable(score?.summary ?? '未记录'),
          _escapeTable(score?.warning ?? ''),
        ].join(' | ').surroundWithPipes(),
      );
    }

    buffer.writeln();
    buffer.writeln('## Review Notes');
    buffer.writeln();
    for (final output in outputs) {
      final attractiveness = _attractivenessAudit(output);
      buffer
        ..writeln('### ${_sceneLabel(output)}')
        ..writeln()
        ..writeln(
          '- Judge: ${output.review.judge.status.name} - ${output.review.judge.reason}',
        )
        ..writeln(
          '- Consistency: ${output.review.consistency.status.name} - ${output.review.consistency.reason}',
        )
        ..writeln(
          '- Reader flow: ${output.review.readerFlow?.status.name ?? 'disabled'}',
        )
        ..writeln(
          '- Lexicon: ${output.review.lexicon?.status.name ?? 'disabled'}',
        )
        ..writeln(
          '- Quality gate: ${_passesSceneQualityGate(output) ? 'PASS' : 'BLOCKED'} '
          '(overall >= $overallMinimum, critical >= $criticalMinimum, '
          'attractiveness=${attractiveness['passed'] == true ? 'PASS' : 'BLOCKED'})',
        )
        ..writeln('- Soft failures: ${output.softFailureCount}')
        ..writeln('- Characters: ${output.prose.text.trim().length}')
        ..writeln(
          '- Character introduction: '
          '${(attractiveness['characterIntroduction'] as Map)['passed'] == true ? 'PASS' : 'BLOCKED'}',
        );
      for (final issue in (attractiveness['issues'] as List<String>)) {
        buffer.writeln('- Attractiveness evidence: ${_escapeTable(issue)}');
      }
      _writeReviewHistory(buffer, output.reviewAttempts);
      buffer
        ..write(_warningLine(output.qualityScore?.warning))
        ..writeln();
    }

    buffer
      ..writeln('## Deterministic Repetition Gate')
      ..writeln()
      ..writeln('- Status: ${blockingRepetition.isEmpty ? 'PASS' : 'BLOCKED'}');
    if (blockingRepetition.isEmpty) {
      buffer.writeln(
        '- Evidence: no sentence self-repeat or cross-scene reuse.',
      );
    } else {
      for (final finding in blockingRepetition) {
        buffer.writeln(
          '- ${finding.kind.label}: ${_escapeTable(finding.matched)} — '
          '${_escapeTable(finding.context)}',
        );
      }
    }

    return buffer.toString().trimRight();
  }

  static String toJson(List<SceneRuntimeOutput> outputs) {
    final repetitionReport = _repetitionReport(outputs);
    final blockingRepetition = _blockingRepetitionFindings(repetitionReport);
    final sceneScoreGatePassed =
        outputs.isNotEmpty && outputs.every(_passesQualityGate);
    final sceneAttractivenessGatePassed =
        outputs.isNotEmpty && outputs.every(_passesAttractivenessGate);
    final data = <String, Object?>{
      'generatedAtMs': DateTime.now().millisecondsSinceEpoch,
      'sceneCount': outputs.length,
      'qualityGate': <String, Object?>{
        'passed':
            sceneScoreGatePassed &&
            sceneAttractivenessGatePassed &&
            blockingRepetition.isEmpty,
        'overallMinimum': overallMinimum,
        'criticalMinimum': criticalMinimum,
        'sceneScoreGatePassed': sceneScoreGatePassed,
        'sceneAttractivenessGatePassed': sceneAttractivenessGatePassed,
        'deterministicRepetitionGatePassed': blockingRepetition.isEmpty,
      },
      'repetitionAudit': <String, Object?>{
        'findingCount': blockingRepetition.length,
        'findings': <Object?>[
          for (final finding in blockingRepetition)
            <String, Object?>{
              'kind': finding.kind.name,
              'matched': finding.matched,
              'position': finding.position,
              'context': finding.context,
            },
        ],
      },
      'scenes': [for (final output in outputs) _sceneToJson(output)],
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  static Map<String, Object?> _sceneToJson(SceneRuntimeOutput output) {
    final score = output.qualityScore;
    final attractiveness = _attractivenessAudit(output);
    return <String, Object?>{
      'chapterId': output.brief.chapterId,
      'chapterTitle': output.brief.chapterTitle,
      'sceneId': output.brief.sceneId,
      'sceneTitle': output.brief.sceneTitle,
      'proseAttempts': output.proseAttempts,
      'softFailureCount': output.softFailureCount,
      'characterCount': output.prose.text.trim().length,
      'qualityGate': <String, Object?>{
        'passed': _passesSceneQualityGate(output),
        'overallMinimum': overallMinimum,
        'criticalMinimum': criticalMinimum,
        'scorePassed': _passesQualityGate(output),
        'attractivenessPassed': attractiveness['passed'],
      },
      'chapterAttractivenessAudit': attractiveness,
      'review': <String, Object?>{
        'decision': output.review.decision.name,
        'judgeStatus': output.review.judge.status.name,
        'judgeReason': output.review.judge.reason,
        'consistencyStatus': output.review.consistency.status.name,
        'consistencyReason': output.review.consistency.reason,
      },
      'reviewAttempts': <Object?>[
        for (final attempt in output.reviewAttempts) attempt.toJson(),
      ],
      if (score != null) 'qualityScore': score.toJson(),
      if (score?.warning != null && score!.warning!.isNotEmpty)
        'qualityWarning': score.warning,
    };
  }

  static String _warningLine(String? warning) {
    if (warning == null || warning.isEmpty) return '';
    return '- Quality warning: ${_escapeTable(warning)}\n';
  }

  static void _writeReviewHistory(
    StringBuffer buffer,
    List<SceneReviewAttempt> attempts,
  ) {
    if (attempts.isEmpty) {
      buffer.writeln('- Review history: none');
      return;
    }
    buffer.writeln('- Review history:');
    for (final attempt in attempts) {
      final failures = attempt.failureCodes.isEmpty
          ? ''
          : ' [${attempt.failureCodes.join(', ')}]';
      final repair = attempt.repairScheduled ? ' -> repair scheduled' : '';
      buffer.writeln(
        '  - Round ${attempt.round}, prose ${attempt.proseAttempt}, '
        '${attempt.phase.wireName}: ${attempt.decision.name}$failures$repair - '
        '${_escapeTable(attempt.reason)}',
      );
    }
  }

  static bool _passesQualityGate(SceneRuntimeOutput output) {
    final score = output.qualityScore;
    if (score == null) return false;
    final requiresExtendedRubric =
        output.brief.formalExecution ||
        output.brief.metadata['requireExtendedQualityRubric'] == true;
    final scoreValues = <double>[
      score.overall,
      score.prose,
      score.coherence,
      score.character,
      score.completeness,
      if (score.hasExtendedRubric) ...[
        score.styleScore,
        score.imageryScore,
        score.rhythmScore,
        score.faithfulnessScore,
      ],
    ];
    return score.warning == null &&
        score.summary.trim().isNotEmpty &&
        scoreValues.every(
          (value) => value.isFinite && value >= 0 && value <= 100,
        ) &&
        (!requiresExtendedRubric || score.hasExtendedRubric) &&
        score.overall >= overallMinimum &&
        scoreValues.skip(1).every((value) => value >= criticalMinimum);
  }

  static bool _passesSceneQualityGate(SceneRuntimeOutput output) =>
      _passesQualityGate(output) && _passesAttractivenessGate(output);

  static bool _passesAttractivenessGate(SceneRuntimeOutput output) =>
      _attractivenessAudit(output)['passed'] == true;

  static Map<String, Object?> _attractivenessAudit(SceneRuntimeOutput output) {
    final brief = output.brief;
    final prose = output.prose.text;
    final issues = <String>[];
    final isFirstScene = brief.sceneIndex == 0;
    final isLastScene =
        brief.totalScenesInChapter > 0 &&
        brief.sceneIndex == brief.totalScenesInChapter - 1;
    final openingViolation = isFirstScene
        ? sceneChapterOpeningHookViolationText(prose)
        : null;
    final endingViolation = isLastScene
        ? sceneChapterEndingHookViolationText(prose)
        : null;
    if (openingViolation != null) issues.add(openingViolation);
    if (endingViolation != null) issues.add(endingViolation);

    final introduction = sceneCharacterIntroductionAudit(
      brief: brief,
      proseText: prose,
    );
    final introductionRequired =
        isFirstScene &&
        (brief.formalExecution ||
            brief.metadata['requireCharacterIntroduction'] == true ||
            brief.cast.isNotEmpty);
    if (introductionRequired && !introduction.passed) {
      issues.add(introduction.reason);
    }

    return <String, Object?>{
      'passed': issues.isEmpty,
      'openingHookPassed': openingViolation == null,
      'endingHookPassed': endingViolation == null,
      'characterIntroduction': <String, Object?>{
        ...introduction.toJson(),
        'required': introductionRequired,
      },
      'issues': List<String>.unmodifiable(issues),
    };
  }

  static AiClicheReport _repetitionReport(List<SceneRuntimeOutput> outputs) {
    return AiClicheDetector().detectAcrossScenes(<String, String>{
      for (final output in outputs)
        '${output.brief.chapterId}/${output.brief.sceneId}': output.prose.text,
    });
  }

  static List<AiClicheFinding> _blockingRepetitionFindings(
    AiClicheReport report,
  ) {
    return <AiClicheFinding>[
      for (final finding in report.findings)
        if (finding.kind == AiClicheKind.selfRepeat ||
            finding.kind.name.startsWith('crossScene'))
          finding,
    ];
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
