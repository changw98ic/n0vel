class BatchChapterPromptBuilder {
  const BatchChapterPromptBuilder._();

  static List<String> recentOutlineSummaries(
    Iterable<({String title, String plotSummary})> outlines,
  ) {
    final list = outlines.toList();
    final recent = list.length > 3 ? list.sublist(list.length - 3) : list;
    return [
      for (final outline in recent) '- ${outline.title}: ${outline.plotSummary}',
    ];
  }
}
