import '../domain/memory_models.dart';

bool _isCJK(int codeUnit) {
  return (codeUnit >= 0x4E00 && codeUnit <= 0x9FFF) ||
      (codeUnit >= 0x3400 && codeUnit <= 0x4DBF) ||
      (codeUnit >= 0x3040 && codeUnit <= 0x309F) ||
      (codeUnit >= 0x30A0 && codeUnit <= 0x30FF) ||
      (codeUnit >= 0xAC00 && codeUnit <= 0xD7AF);
}

bool _isWhitespace(int codeUnit) {
  return codeUnit == 0x20 ||
      codeUnit == 0x09 ||
      codeUnit == 0x0A ||
      codeUnit == 0x0D ||
      codeUnit == 0x0B ||
      codeUnit == 0x0C;
}

/// Tokenize text for lexical overlap scoring.
///
/// For ASCII/word tokens: whitespace-split, lowercased.
/// For CJK runs: character bigrams, respecting whitespace boundaries.
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

/// A single retrieval atom with a relevance score.
class RetrievalAtom {
  const RetrievalAtom({
    required this.id,
    required this.content,
    required this.sourceTool,
    this.score = 0.0,
    this.tags = const [],
    this.sourceRefs = const [],
    this.isThought = false,
  });

  final String id;
  final String content;
  final String sourceTool;
  final double score;
  final List<String> tags;
  final List<MemorySourceRef> sourceRefs;
  final bool isThought;
}

/// Ranks retrieval atoms and converts memory retrieval packs into atoms.
///
/// Supports both legacy atom-only ranking and new memory retrieval packs.
class AgenticRag {
  AgenticRag({this.maxResults = 10});

  final int maxResults;

  /// Ranks atoms by score (descending) and returns the top [maxResults].
  List<RetrievalAtom> rank(List<RetrievalAtom> atoms) {
    final sorted = List<RetrievalAtom>.from(atoms)
      ..sort((a, b) => b.score.compareTo(a.score));
    return sorted.take(maxResults).toList();
  }

  /// Scores an atom based on keyword and tag overlap with a query.
  double scoreAtom(RetrievalAtom atom, String query, List<String> queryTags) {
    final keywordOverlap = _keywordOverlap(atom.content, query);
    final tagOverlap = _tagOverlap(atom.tags, queryTags);
    return keywordOverlap * 4.0 + tagOverlap * 6.0;
  }

  /// Scores and ranks atoms against a query in one pass.
  List<RetrievalAtom> query(
    List<RetrievalAtom> atoms,
    String queryText,
    List<String> queryTags,
  ) {
    final scored = atoms.map((a) {
      final score = scoreAtom(a, queryText, queryTags);
      return RetrievalAtom(
        id: a.id,
        content: a.content,
        sourceTool: a.sourceTool,
        score: score,
        tags: a.tags,
        sourceRefs: a.sourceRefs,
        isThought: a.isThought,
      );
    }).toList();
    return rank(scored);
  }

  /// Converts a retrieval pack into ranked atoms.
  List<RetrievalAtom> fromRetrievalPack(StoryRetrievalPack pack) {
    final atoms = pack.hits.map((hit) {
      return RetrievalAtom(
        id: hit.chunk.id,
        content: hit.chunk.content,
        sourceTool: hit.chunk.kind.name,
        score: hit.score,
        tags: hit.chunk.tags,
        sourceRefs: hit.chunk.sourceRefs,
        isThought: hit.isThought,
      );
    }).toList();
    return rank(atoms);
  }

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

  double _tagOverlap(List<String> atomTags, List<String> queryTags) {
    if (queryTags.isEmpty || atomTags.isEmpty) return 0.0;
    var matches = 0;
    for (final qt in queryTags) {
      if (atomTags.any((at) => at.toLowerCase() == qt.toLowerCase())) {
        matches++;
      }
    }
    return matches.toDouble();
  }
}
