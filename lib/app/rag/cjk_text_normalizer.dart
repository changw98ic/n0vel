/// Shared CJK tokenization for local lexical and fallback-semantic retrieval.
///
/// SQLite's default FTS5 tokenizer does not provide useful word boundaries for
/// unsegmented CJK prose.  Emitting deterministic unigrams and bigrams gives
/// the local index stable tokens without requiring a platform tokenizer.
const int cjkTextNormalizerVersion = 2;

List<String> cjkSearchTokens(String value, {int? maxTokens = 512}) {
  if (maxTokens != null && maxTokens <= 0) return const [];

  final tokens = <String>{};
  final runes = value.runes.toList(growable: false);
  bool hasCapacity() => maxTokens == null || tokens.length < maxTokens;

  for (var i = 0; i < runes.length && hasCapacity(); i++) {
    if (!isCjkRune(runes[i])) continue;

    final start = i;
    while (i + 1 < runes.length && isCjkRune(runes[i + 1])) {
      i++;
    }

    final run = runes.sublist(start, i + 1);
    for (var offset = 0; offset < run.length && hasCapacity(); offset++) {
      tokens.add(String.fromCharCode(run[offset]));
      if (offset + 1 < run.length && hasCapacity()) {
        tokens.add(String.fromCharCodes(run.sublist(offset, offset + 2)));
      }
    }
  }
  return List.unmodifiable(tokens);
}

/// Tokens used by the deterministic offline embedding.
///
/// Latin words retain the existing word-token behavior. CJK runs use the same
/// normalized unigrams/bigrams as the FTS side index so short queries overlap
/// longer prose instead of hashing each entire sentence as one token.
List<String> localEmbeddingTokens(String value, {int maxTokens = 2048}) {
  final tokens = <String>[];
  final lower = value.toLowerCase();
  for (final match in RegExp(
    r'[\p{L}\p{N}_]+',
    unicode: true,
  ).allMatches(lower)) {
    final token = match.group(0)!;
    if (token.runes.any(isCjkRune)) {
      tokens.addAll(
        cjkSearchTokens(token, maxTokens: maxTokens - tokens.length),
      );
    } else if (token.isNotEmpty) {
      tokens.add(token);
    }
    if (tokens.length >= maxTokens) break;
  }
  return List.unmodifiable(tokens.take(maxTokens));
}

bool containsCjk(String value) => value.runes.any(isCjkRune);

bool isCjkRune(int rune) {
  return (rune >= 0x4E00 && rune <= 0x9FFF) ||
      (rune >= 0x3400 && rune <= 0x4DBF) ||
      (rune >= 0x3040 && rune <= 0x309F) ||
      (rune >= 0x30A0 && rune <= 0x30FF) ||
      (rune >= 0xAC00 && rune <= 0xD7AF);
}
