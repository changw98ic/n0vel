import 'dart:convert';

class BatchChapterContentParts {
  final String content;
  final String endingSummary;

  const BatchChapterContentParts({
    required this.content,
    required this.endingSummary,
  });
}

class BatchChapterParsing {
  const BatchChapterParsing._();

  static Map<String, dynamic>? tryParseJson(String str) {
    try {
      return jsonDecode(str) as Map<String, dynamic>;
    } catch (_) {
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(str);
      if (match != null) {
        try {
          return jsonDecode(match.group(0)!) as Map<String, dynamic>;
        } catch (_) {}
      }
      return null;
    }
  }

  static BatchChapterContentParts splitEndingSummary(String rawContent) {
    final endingMatch = RegExp(
      r'\[ENDING_SUMMARY\]\s*([\s\S]*?)\s*\[/ENDING_SUMMARY\]',
    ).firstMatch(rawContent);

    if (endingMatch == null) {
      return BatchChapterContentParts(
        content: rawContent.trim(),
        endingSummary: '',
      );
    }

    return BatchChapterContentParts(
      content: rawContent.replaceFirst(endingMatch.group(0)!, '').trim(),
      endingSummary: endingMatch.group(1)!.trim(),
    );
  }
}
