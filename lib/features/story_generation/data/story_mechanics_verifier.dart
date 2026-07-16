import '../../../app/llm/app_llm_canonical_hash.dart';
import 'story_mechanics_evidence.dart';

/// Frozen, high-precision deterministic verifier for hard story mechanics.
final class StoryMechanicsVerifier {
  const StoryMechanicsVerifier._();

  static const standard = StoryMechanicsVerifier._();
  static const motifRepeatThreshold = 3;
  static const explanationRepeatThreshold = 2;
  static const analyticalDialogueRatioThresholdMicros = 600000;
  static const analyticalDialogueMinimumChars = 20;

  static String get releaseHash => AppLlmCanonicalHash.domainHash(
    'story-mechanics-verifier-release-v1',
    const <String, Object?>{
      'power': 'ordered-loss-action-local-mechanism-window-v1',
      'powerInversion': 'actor-pair-reversal-with-transfer-window-v1',
      'motifRepeatThreshold': motifRepeatThreshold,
      'explanationRepeatThreshold': explanationRepeatThreshold,
      'analyticalDialogueRatioThresholdMicros':
          analyticalDialogueRatioThresholdMicros,
      'analyticalDialogueMinimumChars': analyticalDialogueMinimumChars,
      'spanEvidence': 'normalized-type-ordinal-sha256-v1',
    },
  );

  static String proseHash(String prose) => AppLlmCanonicalHash.domainHash(
    'story-mechanics-prose-v1',
    prose.replaceAll('\r\n', '\n'),
  );

  StoryMechanicsEvidence verify(String prose) {
    final spans = _spans(prose);
    final powerLosses = spans
        .where(
          (span) => _containsAny(span.text, const [
            '断电',
            '停电',
            '没有电',
            '失去供电',
            '电源已切断',
            '电源被切断',
          ]),
        )
        .toList();
    final deviceActions = spans
        .where(
          (span) => _containsAny(span.text, const [
            '终端启动',
            '终端仍然启动',
            '电梯运行',
            '电梯仍然运行',
            '门禁打开',
            '门禁仍然打开',
            '设备启动',
            '机器继续运转',
            '屏幕亮起',
          ]),
        )
        .toList();
    final mechanisms = spans
        .where(
          (span) => _containsAny(span.text, const [
            '备用电源',
            '独立电源',
            '应急电源',
            '蓄电池',
            '机械解锁',
            '手动开启',
            '手摇',
            '惯性供电',
            '电容余电',
          ]),
        )
        .toList();
    final unexplainedActions = <_TextSpan>[];
    for (final action in deviceActions) {
      final precedingLosses = powerLosses.where(
        (loss) =>
            loss.ordinal <= action.ordinal &&
            action.ordinal - loss.ordinal <= 4,
      );
      if (precedingLosses.isEmpty) continue;
      final loss = precedingLosses.last;
      final explained = mechanisms.any(
        (mechanism) =>
            mechanism.ordinal >= loss.ordinal &&
            mechanism.ordinal <= action.ordinal + 1,
      );
      if (!explained) unexplainedActions.add(action);
    }

    final coercions = <_Relation>[];
    final inversions = <_Relation>[];
    final transfers = spans
        .where(
          (span) => _containsAny(span.text, const [
            '夺下武器',
            '缴械',
            '控制权转移',
            '失去意识',
            '解除控制',
            '摆脱控制',
            '反制成功',
            '证据曝光',
            '权力移交',
            '授权',
          ]),
        )
        .toList();
    for (final span in spans) {
      coercions.addAll(
        _relations(span, const ['胁迫', '控制着', '控制', '挟持', '威逼', '强迫']),
      );
      inversions.addAll(_relations(span, const ['命令', '迫使', '逼迫', '要求']));
    }
    final unearnedInversions = <_Relation>[];
    for (final inversion in inversions) {
      for (final coercion in coercions) {
        if (coercion.subject != inversion.object ||
            coercion.object != inversion.subject ||
            coercion.span.ordinal > inversion.span.ordinal) {
          continue;
        }
        final hasTransfer = transfers.any(
          (span) =>
              span.ordinal >= coercion.span.ordinal &&
              span.ordinal <= inversion.span.ordinal,
        );
        if (!hasTransfer) unearnedInversions.add(inversion);
      }
    }

    final clauseCounts = <String, int>{};
    final explanationCounts = <String, int>{};
    for (final clause in _clauses(prose)) {
      final normalized = _normalize(clause.text);
      if (normalized.runes.length < 4) continue;
      clauseCounts.update(normalized, (count) => count + 1, ifAbsent: () => 1);
      if (_containsAny(clause.text, const [
        '解释',
        '因为',
        '所以',
        '也就是说',
        '换句话说',
        '原因是',
        '这意味着',
      ])) {
        explanationCounts.update(
          normalized,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }
    final repeatedMotifs = _frozenCounts(
      clauseCounts,
      threshold: motifRepeatThreshold,
      domain: 'story-mechanics-motif-v1',
    );
    final repeatedExplanations = _frozenCounts(
      explanationCounts,
      threshold: explanationRepeatThreshold,
      domain: 'story-mechanics-explanation-v1',
    );
    final dialogue = _dialogueMeasure(prose);

    final failures = <String>[];
    if (unexplainedActions.isNotEmpty) {
      failures.add('quality.unpowered_device_action');
    }
    if (unearnedInversions.isNotEmpty) {
      failures.add('quality.unearned_power_inversion');
    }
    if (repeatedMotifs.isNotEmpty || repeatedExplanations.isNotEmpty) {
      failures.add('quality.repetition_loop');
    }
    if (dialogue.totalChars >= analyticalDialogueMinimumChars &&
        dialogue.ratioMicros >= analyticalDialogueRatioThresholdMicros) {
      failures.add('quality.expository_dialogue_density');
    }
    return StoryMechanicsEvidence(
      verifierReleaseHash: releaseHash,
      proseHash: proseHash(prose),
      powerLossSpanHashes: powerLosses.map(
        (span) => _spanHash('powerLoss', span),
      ),
      deviceActionSpanHashes: deviceActions.map(
        (span) => _spanHash('deviceAction', span),
      ),
      powerMechanismSpanHashes: mechanisms.map(
        (span) => _spanHash('powerMechanism', span),
      ),
      unexplainedDeviceActionSpanHashes: unexplainedActions.map(
        (span) => _spanHash('deviceAction', span),
      ),
      coercionSpanHashes: coercions.map(
        (relation) => _relationHash('coercion', relation),
      ),
      powerInversionSpanHashes: inversions.map(
        (relation) => _relationHash('powerInversion', relation),
      ),
      authorityTransferSpanHashes: transfers.map(
        (span) => _spanHash('authorityTransfer', span),
      ),
      unearnedPowerInversionSpanHashes: unearnedInversions.map(
        (relation) => _relationHash('powerInversion', relation),
      ),
      repeatedMotifCounts: repeatedMotifs,
      repeatedExplanationCounts: repeatedExplanations,
      dialogueChars: dialogue.totalChars,
      analyticalDialogueChars: dialogue.analyticalChars,
      analyticalDialogueRatioMicros: dialogue.ratioMicros,
      failureCodes: failures,
    );
  }

  List<_TextSpan> _spans(String prose) => _split(prose, RegExp(r'[。！？!?\n]+'));

  List<_TextSpan> _clauses(String prose) =>
      _split(prose, RegExp(r'[，。！？；：、,.!?;:\n]+'));

  List<_TextSpan> _split(String prose, RegExp delimiter) {
    final result = <_TextSpan>[];
    var ordinal = 0;
    for (final value in prose.split(delimiter)) {
      final text = value.trim();
      if (text.isEmpty) continue;
      result.add(_TextSpan(ordinal++, text));
    }
    return result;
  }

  Iterable<_Relation> _relations(_TextSpan span, List<String> verbs) sync* {
    for (final verb in verbs) {
      final index = span.text.indexOf(verb);
      if (index <= 0) continue;
      final before = _actorBefore(span.text.substring(0, index));
      final after = _actorAfter(span.text.substring(index + verb.length));
      if (before != null && after != null && before != after) {
        yield _Relation(span, before, after);
        return;
      }
    }
  }

  String? _actorBefore(String value) {
    final clean = value
        .split(RegExp(r'[，,；;：:\s]'))
        .last
        .trim()
        .replaceFirst(RegExp(r'^(?:随后|接着|这时|忽然|突然|下一秒|片刻后|转眼间)'), '');
    final runes = clean.runes.toList();
    if (runes.isEmpty) return null;
    return String.fromCharCodes(
      runes.skip(runes.length > 4 ? runes.length - 4 : 0),
    );
  }

  String? _actorAfter(String value) {
    final clean = value.trimLeft().split(RegExp(r'[，,；;：:\s]')).first.trim();
    if (clean.isEmpty) return null;
    final stop = <String>['服从', '跪下', '离开', '交出', '闭嘴'];
    var actor = clean;
    for (final suffix in stop) {
      final at = actor.indexOf(suffix);
      if (at > 0) actor = actor.substring(0, at);
    }
    return String.fromCharCodes(actor.runes.take(4));
  }

  Map<String, int> _frozenCounts(
    Map<String, int> source, {
    required int threshold,
    required String domain,
  }) {
    final result = <String, int>{};
    for (final entry in source.entries) {
      if (entry.value < threshold) continue;
      result[AppLlmCanonicalHash.domainHash(domain, entry.key)] = entry.value;
    }
    return result;
  }

  ({int totalChars, int analyticalChars, int ratioMicros}) _dialogueMeasure(
    String prose,
  ) {
    var inDialogue = false;
    var total = 0;
    var analytical = 0;
    final current = StringBuffer();
    void flush() {
      final text = current.toString();
      current.clear();
      final chars = text.runes.where((rune) => !_isWhitespace(rune)).length;
      total += chars;
      if (_containsAny(text, const [
        '因为',
        '所以',
        '也就是说',
        '换句话说',
        '原因是',
        '这意味着',
        '原理',
        '逻辑',
        '结论',
        '解释',
      ])) {
        analytical += chars;
      }
    }

    for (final rune in prose.runes) {
      final char = String.fromCharCode(rune);
      if ('「『“"'.contains(char) && !inDialogue) {
        inDialogue = true;
        current.clear();
      } else if ('」』”"'.contains(char) && inDialogue) {
        flush();
        inDialogue = false;
      } else if (inDialogue) {
        current.write(char);
      }
    }
    if (inDialogue) flush();
    return (
      totalChars: total,
      analyticalChars: analytical,
      ratioMicros: total == 0 ? 0 : ((analytical / total) * 1000000).round(),
    );
  }

  String _spanHash(String kind, _TextSpan span) =>
      AppLlmCanonicalHash.domainHash(
        'story-mechanics-span-v1',
        <String, Object?>{
          'kind': kind,
          'ordinal': span.ordinal,
          'text': _normalize(span.text),
        },
      );

  String _relationHash(String kind, _Relation relation) =>
      AppLlmCanonicalHash.domainHash(
        'story-mechanics-relation-v1',
        <String, Object?>{
          'kind': kind,
          'spanHash': _spanHash(kind, relation.span),
          'subject': _normalize(relation.subject),
          'object': _normalize(relation.object),
        },
      );

  String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[\s，。！？；：、,.!?;:「」『』“”\"]+'), '');

  bool _containsAny(String value, List<String> needles) =>
      needles.any(value.contains);

  bool _isWhitespace(int rune) =>
      rune == 0x20 ||
      rune == 0x09 ||
      rune == 0x0a ||
      rune == 0x0d ||
      rune == 0x3000;
}

final class StoryMechanicsViolation implements Exception {
  const StoryMechanicsViolation(this.evidence);

  final StoryMechanicsEvidence evidence;

  @override
  String toString() =>
      'StoryMechanicsViolation: ${evidence.failureCodes.join(',')}';
}

final class _TextSpan {
  const _TextSpan(this.ordinal, this.text);

  final int ordinal;
  final String text;
}

final class _Relation {
  const _Relation(this.span, this.subject, this.object);

  final _TextSpan span;
  final String subject;
  final String object;
}
