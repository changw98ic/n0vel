// ignore_for_file: deprecated_member_use
import '../domain/contracts/event_log.dart';
import 'scene_runtime_models.dart';

const double sceneDialogueRatioMinimum = 0.25;

/// A typed hard-gate violation carrying both description text and FailureCode.
class HardGateViolation {
  const HardGateViolation({required this.text, required this.failureCode});

  /// Human-readable violation description.
  final String text;

  /// Machine-readable failure code for pipeline event logging.
  final FailureCode failureCode;
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

  final dialogueViolation = _checkDialogueRatio(proseText);
  if (dialogueViolation != null) {
    violations.add(HardGateViolation(
      text: dialogueViolation,
      failureCode: FailureCode.qualityFail,
    ));
  }

  if (brief.sceneIndex == 0) {
    final hookViolation = _checkChapterOpeningHook(proseText);
    if (hookViolation != null) {
      violations.add(HardGateViolation(
        text: hookViolation,
        failureCode: FailureCode.qualityFail,
      ));
    }
  }

  if (brief.totalScenesInChapter > 0 &&
      brief.sceneIndex == brief.totalScenesInChapter - 1) {
    final hookViolation = _checkChapterEndingHook(proseText);
    if (hookViolation != null) {
      violations.add(HardGateViolation(
        text: hookViolation,
        failureCode: FailureCode.qualityFail,
      ));
    }
  }

  return violations;
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

/// Check that the first 50 Chinese characters contain a suspense signal.
///
/// Suspense signals include: dialogue, questions, exclamation marks, or
/// tension-related keywords. Pure atmospheric description fails this check.
String? _checkChapterOpeningHook(String prose) {
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

/// Check that the last paragraph leaves an unresolved hook.
///
/// Fails if the ending uses conclusive/resolved language with no tension.
String? _checkChapterEndingHook(String prose) {
  final trimmed = prose.trim();
  if (trimmed.isEmpty) return null;

  // Get the last paragraph (after last double newline, or full text)
  final paragraphs = trimmed.split(RegExp(r'\n\s*\n'));
  final lastParagraph = paragraphs.last.trim();
  if (lastParagraph.isEmpty) return null;

  // Check for conclusive language that signals no hook
  final conclusivePatterns = RegExp(
    r'问题已解决|一切尘埃落定|皆大欢喜|圆满结束|完美收官|'
    r'从此过上了|幸福地生活|故事结束|全剧终|终章|'
    r'一切都结束了|终于解决了|彻底解决了|完全平息',
  );
  if (conclusivePatterns.hasMatch(lastParagraph)) {
    return '章尾使用了收口句式，缺少未决冲突或悬念钩子';
  }

  // Check for tension/hook signals in the ending
  final hookPatterns = RegExp(
    r'[？?！!…]|'
    r'「[^」]*$|"[^"]*$|' // unclosed dialogue
    r'突然|忽然|然而|但是|可是|只是|'
    r'威胁|危险|不安|紧张|疑|悬念|未解|未知|'
    r'转身|离开|消失|逃离|逃走|'
    r'暗暗|悄悄|秘密|隐藏|隐瞒|'
    r'即将|将要|准备|打算|决定',
  );
  if (hookPatterns.hasMatch(lastParagraph)) return null;

  // If ending is very short (under 30 chars), likely a punchline/hook
  final lastParaChars = lastParagraph.replaceAll(RegExp(r'\s+'), '').length;
  if (lastParaChars < 30) return null;

  // Ending with dialogue is usually a hook
  if (RegExp(r'[」"』]\s*$').hasMatch(lastParagraph)) return null;

  return '章尾缺少悬念钩子，建议留下未决冲突、未知去向或紧急选择';
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
