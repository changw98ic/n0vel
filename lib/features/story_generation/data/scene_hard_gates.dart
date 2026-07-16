// ignore_for_file: deprecated_member_use
import '../../../app/llm/app_llm_canonical_hash.dart';
import '../domain/contracts/event_log.dart';
import 'ai_cliche_detector.dart';
import 'narrative_continuity_verifier.dart';
import 'scene_runtime_models.dart';

const double sceneDialogueRatioMinimum = 0.25;

final String sceneHardGateReleaseHash = AppLlmCanonicalHash.domainHash(
  'scene-hard-gate-release-v4',
  const <String, Object?>{
    'dialogueRatioMinimumMicros': 250000,
    'openingWindowCharacters': 50,
    'physicalContinuity': 'same-actor-minute-two-location-with-mechanism-v2',
    'mechanisms': <String>['delegation', 'system-delay', 'independent-power'],
    'outlineFidelity': 'required-beat-strict-text-and-alias-groups-v3',
    'continuityLedger': 'declared-entity-event-ledger-v2',
    'selfRepeat': 'nearby-cjk-repeat-v1',
    'chapterEndingHook': 'unresolved-tension-v2',
    'characterIntroduction': 'primary-cast-name-first-500-v1',
  },
);

/// A typed hard-gate violation carrying both description text and FailureCode.
class HardGateViolation {
  const HardGateViolation({required this.text, required this.failureCode});

  /// Human-readable violation description.
  final String text;

  /// Machine-readable failure code for pipeline event logging.
  final FailureCode failureCode;
}

class SceneCharacterIntroductionAudit {
  SceneCharacterIntroductionAudit({
    required this.passed,
    required List<String> requiredNames,
    required List<String> observedNames,
    required this.windowCharacters,
    required this.reason,
  }) : requiredNames = List<String>.unmodifiable(requiredNames),
       observedNames = List<String>.unmodifiable(observedNames);

  final bool passed;
  final List<String> requiredNames;
  final List<String> observedNames;
  final int windowCharacters;
  final String reason;

  Map<String, Object?> toJson() => <String, Object?>{
    'passed': passed,
    'requiredNames': requiredNames,
    'observedNames': observedNames,
    'windowCharacters': windowCharacters,
    'reason': reason,
  };
}

class SceneDialogueRatioStats {
  const SceneDialogueRatioStats({
    required this.dialogueChars,
    required this.totalChars,
  });

  final int dialogueChars;
  final int totalChars;

  double get ratio => totalChars == 0 ? 0 : dialogueChars / totalChars;

  int additionalDialogueCharsNeeded({
    double minimum = sceneDialogueRatioMinimum,
  }) {
    if (totalChars == 0 || ratio >= minimum) return 0;
    final missingShare = minimum * totalChars - dialogueChars;
    return (missingShare / (1 - minimum)).ceil();
  }
}

SceneDialogueRatioStats sceneDialogueRatioStats(String prose) {
  var totalCjkChars = 0;
  var dialogueCjkChars = 0;
  var totalVisibleChars = 0;
  var dialogueVisibleChars = 0;
  var inQuote = false;

  for (final rune in prose.runes) {
    final ch = String.fromCharCode(rune);
    if (_isDialogueQuote(ch)) {
      inQuote = !inQuote;
      continue;
    }
    if (_isWhitespace(rune)) continue;

    totalVisibleChars += 1;
    if (inQuote) dialogueVisibleChars += 1;

    if (_isCjk(rune)) {
      totalCjkChars += 1;
      if (inQuote) dialogueCjkChars += 1;
    }
  }

  if (totalCjkChars > 0) {
    return SceneDialogueRatioStats(
      dialogueChars: dialogueCjkChars,
      totalChars: totalCjkChars,
    );
  }
  return SceneDialogueRatioStats(
    dialogueChars: dialogueVisibleChars,
    totalChars: totalVisibleChars,
  );
}

String? sceneDialogueRatioViolationText(String prose) {
  final stats = sceneDialogueRatioStats(prose);
  if (stats.totalChars == 0 || stats.ratio >= sceneDialogueRatioMinimum) {
    return null;
  }

  final pct = (stats.ratio * 100).toStringAsFixed(1);
  final targetPct = (sceneDialogueRatioMinimum * 100).toStringAsFixed(0);
  final needed = stats.additionalDialogueCharsNeeded();
  return '对话占比$pct%低于$targetPct%硬约束（当前${stats.dialogueChars}/${stats.totalChars}字），'
      '还需增加约$needed个中文对白字；请将连续纯叙述改为角色对白，'
      '每2段至少1段含对话，并确保至少6个独立对话回合。';
}

/// Programmatic hard-gate checks returning typed violations with FailureCodes.
///
/// Returns a list of [HardGateViolation] for each failing gate. Used by
/// [ReviewStep] to emit structured events and by [SceneReviewCoordinator]
/// to override LLM review decisions when hard constraints are violated.
List<HardGateViolation> sceneHardGateViolations({
  required SceneBrief brief,
  required String proseText,
  bool enabled = true,
}) {
  if (!enabled) return const [];
  final violations = <HardGateViolation>[];

  final minimumLengthViolation = sceneMinimumLengthViolationText(
    brief: brief,
    proseText: proseText,
  );
  if (minimumLengthViolation != null) {
    violations.add(
      HardGateViolation(
        text: minimumLengthViolation,
        failureCode: FailureCode.qualityFail,
      ),
    );
  }

  final truncationViolation = sceneProseTruncationViolationText(proseText);
  if (truncationViolation != null) {
    violations.add(
      HardGateViolation(
        text: truncationViolation,
        failureCode: FailureCode.qualityFail,
      ),
    );
  }

  final dialogueViolation = _checkDialogueRatio(proseText);
  if (dialogueViolation != null) {
    violations.add(
      HardGateViolation(
        text: dialogueViolation,
        failureCode: FailureCode.qualityFail,
      ),
    );
  }

  final physicalViolation = scenePhysicalContinuityViolationText(proseText);
  if (physicalViolation != null) {
    violations.add(
      HardGateViolation(
        text: physicalViolation,
        failureCode: FailureCode.qualityFail,
      ),
    );
  }

  violations.addAll(
    _outlineFidelityViolations(brief: brief, proseText: proseText),
  );

  final continuityReport = const NarrativeContinuityVerifier().verify(
    brief: brief,
    prose: proseText,
  );
  for (final finding in continuityReport.findings) {
    violations.add(
      HardGateViolation(
        text: '跨场景连续性硬约束：${finding.explanation}',
        failureCode: FailureCode.qualityFail,
      ),
    );
  }

  final requiresClicheHardGate =
      brief.formalExecution || brief.metadata['requireClicheHardGate'] == true;
  if (requiresClicheHardGate) {
    final clicheReport = AiClicheDetector().detect(proseText);
    for (final finding in clicheReport.findingsOf(AiClicheKind.selfRepeat)) {
      violations.add(
        HardGateViolation(
          text:
              '句内复沓硬约束：短距离内重复“${finding.matched}”；'
              '证据：${finding.context}',
          failureCode: FailureCode.qualityFail,
        ),
      );
    }
  }

  if (brief.sceneIndex == 0) {
    final hookViolation = sceneChapterOpeningHookViolationText(proseText);
    if (hookViolation != null) {
      violations.add(
        HardGateViolation(
          text: hookViolation,
          failureCode: FailureCode.qualityFail,
        ),
      );
    }
  }

  final requiresCharacterIntroduction =
      brief.formalExecution ||
      brief.metadata['requireCharacterIntroduction'] == true;
  if (brief.sceneIndex == 0 && requiresCharacterIntroduction) {
    final introduction = sceneCharacterIntroductionAudit(
      brief: brief,
      proseText: proseText,
    );
    if (!introduction.passed) {
      violations.add(
        HardGateViolation(
          text: '角色引入硬约束：${introduction.reason}',
          failureCode: FailureCode.qualityFail,
        ),
      );
    }
  }

  if (brief.totalScenesInChapter > 0 &&
      brief.sceneIndex == brief.totalScenesInChapter - 1) {
    final hookViolation = sceneChapterEndingHookViolationText(proseText);
    if (hookViolation != null) {
      violations.add(
        HardGateViolation(
          text: hookViolation,
          failureCode: FailureCode.qualityFail,
        ),
      );
    }
  }

  return violations;
}

List<HardGateViolation> _outlineFidelityViolations({
  required SceneBrief brief,
  required String proseText,
}) {
  const contractKey = 'requiredOutlineBeats';
  final explicitlyRequired = brief.metadata['requireOutlineFidelity'] == true;
  final strictContract = brief.formalExecution || explicitlyRequired;
  final contractPresent = brief.metadata.containsKey(contractKey);
  final rawContract = brief.metadata[contractKey];

  if (!contractPresent) {
    if (!strictContract) return const [];
    return [
      _outlineContractViolation(
        '大纲忠实度契约缺失：正式执行或 requireOutlineFidelity=true '
        '时必须提供 requiredOutlineBeats 及显式 evidenceGroups。',
      ),
    ];
  }

  if (rawContract is! List || rawContract.isEmpty) {
    if (!strictContract) return const [];
    return [
      _outlineContractViolation(
        '大纲忠实度契约无效：requiredOutlineBeats '
        '必须是非空节拍列表。',
      ),
    ];
  }

  final normalizedProse = _normalizeOutlineEvidence(proseText);
  final violations = <HardGateViolation>[];
  for (var beatIndex = 0; beatIndex < rawContract.length; beatIndex += 1) {
    final rawBeat = rawContract[beatIndex];
    if (rawBeat is! Map) {
      if (strictContract) {
        violations.add(
          _outlineContractViolation('大纲忠实度契约无效：第${beatIndex + 1}个节拍不是结构化对象。'),
        );
      }
      continue;
    }

    final rawId = rawBeat['id'];
    final id = rawId is String ? rawId.trim() : '';
    final displayId = id.isEmpty ? '#${beatIndex + 1}' : id;
    final rawDescription = rawBeat['description'];
    final description = rawDescription is String ? rawDescription.trim() : '';
    final rawGroups = rawBeat['evidenceGroups'];
    final evidenceGroups = <List<String>>[];
    var malformedGroups = rawGroups is! List || rawGroups.isEmpty;
    if (rawGroups is List) {
      for (final rawGroup in rawGroups) {
        if (rawGroup is! List) {
          malformedGroups = true;
          continue;
        }
        final aliases = <String>[];
        final normalizedAliases = <String>{};
        for (final rawAlias in rawGroup) {
          if (rawAlias is! String || rawAlias.trim().isEmpty) {
            malformedGroups = true;
            continue;
          }
          final alias = rawAlias.trim();
          final normalizedAlias = _normalizeOutlineEvidence(alias);
          if (normalizedAlias.isEmpty ||
              !normalizedAliases.add(normalizedAlias)) {
            malformedGroups = true;
            continue;
          }
          aliases.add(alias);
        }
        if (aliases.isEmpty) {
          malformedGroups = true;
          continue;
        }
        evidenceGroups.add(aliases);
      }
    }

    final malformed =
        id.isEmpty ||
        description.isEmpty ||
        malformedGroups ||
        evidenceGroups.isEmpty;
    if (malformed) {
      if (strictContract) {
        violations.add(
          _outlineContractViolation(
            '大纲忠实度契约无效：节拍 "$displayId" '
            '必须同时提供非空 id、description 和显式 evidenceGroups；'
            '不得用节拍摘要猜测宽松证据。',
          ),
        );
      }
      continue;
    }

    final missingGroups = <String>[];
    for (
      var groupIndex = 0;
      groupIndex < evidenceGroups.length;
      groupIndex += 1
    ) {
      final aliases = evidenceGroups[groupIndex];
      final matched = aliases.any((alias) {
        final normalizedAlias = _normalizeOutlineEvidence(alias);
        return normalizedAlias.isNotEmpty &&
            normalizedProse.contains(normalizedAlias);
      });
      if (!matched) {
        missingGroups.add('组${groupIndex + 1}[${aliases.join('|')}]');
      }
    }
    if (missingGroups.isNotEmpty) {
      violations.add(
        _outlineContractViolation(
          '大纲忠实度硬约束：节拍 "$id" 未在正文中覆盖'
          '${missingGroups.join('、')}（$description）；'
          '每个 evidence group 都必须至少命中一个 alias。',
        ),
      );
    }
  }
  return violations;
}

HardGateViolation _outlineContractViolation(String text) {
  return HardGateViolation(text: text, failureCode: FailureCode.qualityFail);
}

String _normalizeOutlineEvidence(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
}

/// Enforces the lower side of the requested scene budget. The existing
/// overlong check is not enough: a short clue list can pass every score while
/// still failing to establish a readable scene turn.
String? sceneMinimumLengthViolationText({
  required SceneBrief brief,
  required String proseText,
}) {
  final target = brief.targetLength < 1 ? 400 : brief.targetLength;
  // Tiny unit-test/utility scenes intentionally use compact briefs. The
  // production lower bound applies to normal prose scenes only.
  if (target < 1000) return null;
  final minimum = (target * 0.8).ceil();
  final actual = proseText.trim().length;
  if (actual >= minimum) return null;
  return '正文长度$actual字低于场景最低长度$minimum字（目标$target字）；'
      '需要补齐目标、阻碍、行动和后果，不能只提交线索摘要。';
}

/// Rejects provider cut-offs and malformed prose tails before an LLM score can
/// turn an incomplete scene into a passing candidate.
String? sceneProseTruncationViolationText(String prose) {
  final text = prose.trim();
  if (text.isEmpty) return null;

  if (text.endsWith('...')) {
    return '正文疑似被 provider 截断：以 ASCII 省略号结尾；必须补齐完整句子后才能评分。';
  }
  if (RegExp(r'[，、：:]$').hasMatch(text)) {
    return '正文疑似被 provider 截断：以未完成标点结尾；必须补齐完整句子后才能评分。';
  }

  final pairs = <String, String>{
    '「': '」',
    '『': '』',
    '“': '”',
    '（': '）',
    '(': ')',
    '【': '】',
    '[': ']',
  };
  for (final entry in pairs.entries) {
    if (text.runes
            .where((rune) => String.fromCharCode(rune) == entry.key)
            .length !=
        text.runes
            .where((rune) => String.fromCharCode(rune) == entry.value)
            .length) {
      return '正文结构不完整：${entry.key}${entry.value}未闭合；不得进入质量评分。';
    }
  }
  final doubleQuoteCount = text.runes
      .where((rune) => String.fromCharCode(rune) == '"')
      .length;
  if (doubleQuoteCount.isOdd) {
    return '正文结构不完整：英文引号未闭合；不得进入质量评分。';
  }
  return null;
}

/// Convenience wrapper returning joined violation text or empty string.
///
/// Delegates to [sceneHardGateViolations]. Prefer the typed function when
/// FailureCode information is needed.
String sceneHardGateViolationText({
  required SceneBrief brief,
  required String proseText,
  bool enabled = true,
}) {
  final violations = sceneHardGateViolations(
    brief: brief,
    proseText: proseText,
    enabled: enabled,
  );
  return violations.isEmpty ? '' : violations.map((v) => v.text).join('；');
}

/// Check that dialogue text accounts for at least 25% of total prose.
///
/// Dialogue is defined as text inside 「」, "", or 『』 brackets.
String? _checkDialogueRatio(String prose) {
  return sceneDialogueRatioViolationText(prose);
}

/// Rejects an explicitly impossible ordinary-world alibi before prose reaches
/// an LLM reviewer. This intentionally targets only texts that themselves
/// assert the impossible simultaneity; fantastical travel remains governed by
/// the world model rather than this generic gate.
String? scenePhysicalContinuityViolationText(String prose) {
  final sameMinute = RegExp(r'同(?:一)?分钟|同一时刻|完全重叠').hasMatch(prose);
  final separatePlaces = RegExp(r'相距\s*\d+\s*(?:公里|千米)|两地').hasMatch(prose);
  final sameActor = RegExp(r'同(?:一)?人|同一个人|他(?:本人)?|她(?:本人)?').hasMatch(prose);
  final mechanism = RegExp(r'代签|代理|系统延迟|延迟同步|独立电源|备用电源').hasMatch(prose);
  if (sameMinute && separatePlaces && sameActor && !mechanism) {
    return '物理连续性硬约束：正文声称同一人同一分钟出现在相距两地，'
        '却未给出代签、系统延迟、独立电源或其他既有机制；'
        '不得把这一不可能事件作为推理证据。';
  }
  return null;
}

/// Check that the first 50 Chinese characters contain a suspense signal.
///
/// Suspense signals include: dialogue, questions, exclamation marks, or
/// tension-related keywords. Pure atmospheric description fails this check.
String? sceneChapterOpeningHookViolationText(String prose) {
  final trimmed = prose.trim();
  if (trimmed.isEmpty) return null;

  // Take first ~50 Chinese characters (skip ASCII/whitespace)
  final buffer = StringBuffer();
  for (final char in trimmed.runes) {
    final c = String.fromCharCode(char);
    if (RegExp(r'[一-鿿　-〿＀-￯]').hasMatch(c)) {
      buffer.write(c);
      if (buffer.length >= 50) break;
    }
  }
  final first50 = buffer.toString();
  if (first50.isEmpty) return null;

  // Check for suspense signals
  if (RegExp(r'[「"『」"』？！?!\…]').hasMatch(first50)) return null;
  if (RegExp(
    r'突然|忽然|猛然|意外|惊|吓|恐|危|险|疑|秘|暗|杀|死|血|'
    r'威胁|冲突|矛盾|不安|紧张|诡异|反常|异常|离奇|神秘|失踪|'
    r'警告|危险|阴谋|背叛|隐瞒|欺骗|秘密|线索|谜|悬念',
  ).hasMatch(first50)) {
    return null;
  }

  return '章首前50字缺少悬念信号（无对话/疑问/感叹/紧张关键词），需在开头注入悬念';
}

SceneCharacterIntroductionAudit sceneCharacterIntroductionAudit({
  required SceneBrief brief,
  required String proseText,
  int windowCharacters = 500,
}) {
  final explicit = brief.metadata['requiredCharacterIntroductions'];
  final requiredNames = <String>[];

  String displayNameFor(String token) {
    for (final candidate in brief.cast) {
      if (candidate.characterId == token || candidate.name == token) {
        return candidate.name.trim().isEmpty ? token : candidate.name.trim();
      }
    }
    return token;
  }

  if (explicit is List) {
    for (final raw in explicit) {
      if (raw is! String || raw.trim().isEmpty) continue;
      final name = displayNameFor(raw.trim());
      if (!requiredNames.contains(name)) requiredNames.add(name);
    }
  } else if (brief.cast.isNotEmpty) {
    final primary = brief.cast.first.name.trim();
    if (primary.isNotEmpty) requiredNames.add(primary);
  }

  final requirementExplicit =
      brief.metadata['requireCharacterIntroduction'] == true;
  if (requiredNames.isEmpty) {
    final passed = !requirementExplicit;
    return SceneCharacterIntroductionAudit(
      passed: passed,
      requiredNames: const <String>[],
      observedNames: const <String>[],
      windowCharacters: windowCharacters,
      reason: passed
          ? '本场没有需要在开头引入的角色。'
          : '已要求角色引入，但 brief.cast/requiredCharacterIntroductions 未提供角色。',
    );
  }

  final text = proseText.trim();
  final window = text.length > windowCharacters
      ? text.substring(0, windowCharacters)
      : text;
  final observedNames = <String>[
    for (final name in requiredNames)
      if (window.contains(name)) name,
  ];
  final missingNames = <String>[
    for (final name in requiredNames)
      if (!observedNames.contains(name)) name,
  ];
  final passed = missingNames.isEmpty;
  return SceneCharacterIntroductionAudit(
    passed: passed,
    requiredNames: requiredNames,
    observedNames: observedNames,
    windowCharacters: windowCharacters,
    reason: passed
        ? '开头$windowCharacters字已按规范名引入${observedNames.join('、')}。'
        : '开头$windowCharacters字未按规范名引入${missingNames.join('、')}；'
              '代词或“某人”不能代替首次身份锚定。',
  );
}

/// Check that the last paragraph leaves an unresolved hook.
///
/// Fails if the ending uses conclusive/resolved language with no tension.
String? sceneChapterEndingHookViolationText(String prose) {
  final trimmed = prose.trim();
  if (trimmed.isEmpty) return null;

  // Get the last paragraph (after last double newline, or full text)
  final paragraphs = trimmed.split(RegExp(r'\n\s*\n'));
  final lastParagraph = paragraphs.last.trim();
  if (lastParagraph.isEmpty) return null;

  // Resolution wins over punctuation or a stray suspense noun. Otherwise a
  // sentence such as “秘密已经公开！” would incorrectly pass on “秘密” and “！”.
  final conclusivePatterns = RegExp(
    r'问题已解决|一切尘埃落定|皆大欢喜|圆满结束|完美收官|'
    r'从此过上了|幸福地生活|故事结束|全剧终|终章|'
    r'一切都结束了|终于解决了|彻底解决了|完全平息|'
    r'秘密已经公开|真相(?:已经)?大白|证据已经公布|'
    r'所有人都安全了|再无危险|各自离开|转身离开',
  );
  if (conclusivePatterns.hasMatch(lastParagraph)) {
    return '章尾使用了收口句式，缺少未决冲突或悬念钩子';
  }

  final unansweredQuestion = RegExp(
    r'(?:谁|什么|为何|为什么|哪里|怎么|怎么办|究竟|到底|是否|难道)'
    r'[^。！？!?]{0,24}[？?]|[？?]$',
  ).hasMatch(lastParagraph);
  final unfinishedAction = RegExp(
    r'还没|尚未|来不及|正要|就要|差一点|眼看|只剩|'
    r'必须在[^。！？]{0,18}之前|倒计时|正在逼近|追兵|脚步声|警报(?:骤然)?响起',
  ).hasMatch(lastParagraph);
  final unresolvedThreat = RegExp(
    r'未知|未解|下落不明|失踪|威胁|危险|杀机|枪口|伏击|'
    r'陌生来电|暗门|另一份|第二个|幕后|背后(?:还有|的人|势力)',
  );
  if (unansweredQuestion ||
      unfinishedAction ||
      unresolvedThreat.hasMatch(lastParagraph)) {
    return null;
  }

  return '章尾缺少语义上的悬念钩子：感叹号、省略号、“决定/准备”或孤立的悬念词不算证据；'
      '必须留下未回答问题、未完成动作或仍在逼近的具体威胁';
}

bool _isDialogueQuote(String ch) {
  return ch == '「' ||
      ch == '」' ||
      ch == '"' ||
      ch == '『' ||
      ch == '』' ||
      ch == '“' ||
      ch == '”' ||
      ch == '‘' ||
      ch == '’';
}

bool _isCjk(int rune) => rune >= 0x4E00 && rune <= 0x9FFF;

bool _isWhitespace(int rune) =>
    rune == 0x20 ||
    rune == 0x09 ||
    rune == 0x0A ||
    rune == 0x0D ||
    rune == 0x3000;
