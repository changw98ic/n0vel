import 'rag_retrieval_policy.dart';

// ---------------------------------------------------------------------------
// CJK-compatible tokenizer (self-contained so this module has no
// dependency on deleted files).
// ---------------------------------------------------------------------------

bool _isCJK(int codeUnit) =>
    (codeUnit >= 0x4E00 && codeUnit <= 0x9FFF) || // CJK Unified Ideographs
    (codeUnit >= 0x3400 && codeUnit <= 0x4DBF) || // CJK Extension A
    (codeUnit >= 0x3040 && codeUnit <= 0x309F) || // Hiragana
    (codeUnit >= 0x30A0 && codeUnit <= 0x30FF) || // Katakana
    (codeUnit >= 0xAC00 && codeUnit <= 0xD7AF); // Hangul Syllables

bool _isWhitespace(int codeUnit) =>
    codeUnit == 0x20 ||
    codeUnit == 0x09 ||
    codeUnit == 0x0A ||
    codeUnit == 0x0D;

Set<String> tokenizeForOverlap(String text) {
  final tokens = <String>{};
  final cjkRun = <String>[];
  final wordBuf = StringBuffer();

  void flushCjkRun() {
    if (cjkRun.length == 1) {
      tokens.add(cjkRun[0]);
    } else if (cjkRun.length > 1) {
      for (var i = 0; i < cjkRun.length - 1; i++) {
        tokens.add(cjkRun[i] + cjkRun[i + 1]);
      }
    }
    cjkRun.clear();
  }

  void flushWord() {
    if (wordBuf.isNotEmpty) {
      tokens.add(wordBuf.toString().toLowerCase());
      wordBuf.clear();
    }
  }

  for (final rune in text.runes) {
    if (_isCJK(rune)) {
      flushWord();
      cjkRun.add(String.fromCharCode(rune));
    } else if (_isWhitespace(rune)) {
      flushWord();
      flushCjkRun();
    } else {
      flushCjkRun();
      wordBuf.writeCharCode(rune);
    }
  }
  flushWord();
  flushCjkRun();

  return tokens;
}

// ---------------------------------------------------------------------------
// Scoring helpers (legacy lexical weighting preserved exactly).
// ---------------------------------------------------------------------------

double _keywordOverlap(String content, String query) {
  final contentLower = content.toLowerCase();
  final queryTokens = tokenizeForOverlap(query);
  var count = 0;
  for (final token in queryTokens) {
    if (contentLower.contains(token)) {
      count++;
    }
  }
  return count.toDouble();
}

double _tagOverlap(List<String> itemTags, List<String> queryTags) {
  if (queryTags.isEmpty || itemTags.isEmpty) return 0.0;
  var matches = 0;
  for (final qt in queryTags) {
    if (itemTags.any((at) => at.toLowerCase() == qt.toLowerCase())) {
      matches++;
    }
  }
  return matches.toDouble();
}

// ---------------------------------------------------------------------------
// Public data types.
// ---------------------------------------------------------------------------

/// Generic immutable input for the ranker.
class AgenticRagRankInput {
  const AgenticRagRankInput({
    required this.id,
    required this.content,
    this.tags = const [],
    this.semanticScore = 0.0,
    this.keywordScore = 0.0,
    this.metadata = const {},
  });

  final String id;
  final String content;
  final List<String> tags;
  final double semanticScore;
  final double keywordScore;
  final Map<String, dynamic> metadata;
}

/// A ranked result carrying the original input plus its computed final score.
class AgenticRagRankedResult {
  const AgenticRagRankedResult({required this.input, required this.finalScore});

  final AgenticRagRankInput input;
  final double finalScore;
}

// ---------------------------------------------------------------------------
// Ranker.
// ---------------------------------------------------------------------------

class AgenticRagRanker {
  const AgenticRagRanker();

  /// Compute the final score for a single [input] against [queryText] /
  /// [queryTags] using the strategy and weights from [policy].
  ///
  /// Legacy lexical weighting is preserved:
  ///   lexical = keywordOverlap * 4.0 + tagOverlap * 6.0
  ///
  /// Strategy rules:
  /// - [RankingStrategy.keyword]: use lexical only (ignore semanticScore).
  /// - [RankingStrategy.semantic]: use semanticScore only.
  /// - [RankingStrategy.hybrid]: blend = semanticScore * semanticWeight +
  ///                             lexical * keywordWeight.
  double score(
    AgenticRagRankInput input,
    String queryText,
    List<String> queryTags,
    RagRetrievalPolicy policy,
  ) {
    final lexical =
        _keywordOverlap(input.content, queryText) * 4.0 +
        _tagOverlap(input.tags, queryTags) * 6.0;

    switch (policy.rankingStrategy) {
      case RankingStrategy.keyword:
        return lexical;
      case RankingStrategy.semantic:
        return input.semanticScore;
      case RankingStrategy.hybrid:
        return input.semanticScore * policy.semanticWeight +
            lexical * policy.keywordWeight;
    }
  }

  /// Score every item in [inputs], sort descending by final score, and
  /// optionally truncate to [limit].
  List<AgenticRagRankedResult> rank(
    List<AgenticRagRankInput> inputs,
    String queryText,
    List<String> queryTags,
    RagRetrievalPolicy policy, {
    int? limit,
  }) {
    final results = [
      for (final input in inputs)
        AgenticRagRankedResult(
          input: input,
          finalScore: score(input, queryText, queryTags, policy),
        ),
    ]..sort((a, b) => b.finalScore.compareTo(a.finalScore));

    if (limit != null && limit < results.length) {
      return results.sublist(0, limit);
    }
    return results;
  }
}
