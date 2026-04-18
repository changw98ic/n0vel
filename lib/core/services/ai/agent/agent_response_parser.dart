class ParsedPlanStep {
  final String description;
  final Set<int> dependsOn;
  final String? suggestedTool;

  const ParsedPlanStep({
    required this.description,
    this.dependsOn = const {},
    this.suggestedTool,
  });
}

class ParsedReflection {
  final bool passed;
  final String? evaluation;
  final String? feedback;

  const ParsedReflection({
    required this.passed,
    this.evaluation,
    this.feedback,
  });
}

class AgentResponseParser {
  const AgentResponseParser._();

  static List<ParsedPlanStep>? tryParseJsonPlan(
    String content,
    Set<String> toolNames,
  ) {
    try {
      var jsonStr = content;
      final mdMatch = RegExp(
        r'```(?:json)?\s*([\s\S]*?)```',
      ).firstMatch(content);
      if (mdMatch != null) {
        jsonStr = mdMatch.group(1)!;
      }

      final list = jsonStr.contains('[') ? jsonStr : null;
      if (list == null) {
        return null;
      }

      final startIdx = jsonStr.indexOf('[');
      final endIdx = jsonStr.lastIndexOf(']');
      if (startIdx < 0 || endIdx <= startIdx) {
        return null;
      }

      final stepRegex = RegExp(r'\{[^{}]*"step"\s*:\s*"([^"]+)"[^{}]*\}');
      final matches = stepRegex.allMatches(
        jsonStr.substring(startIdx, endIdx + 1),
      );

      final steps = <ParsedPlanStep>[];
      for (final match in matches) {
        final stepDesc = match.group(1)!;
        final objectText = match.group(0)!;

        final toolMatch = RegExp(
          r'"tool"\s*:\s*"([^"]+)"',
        ).firstMatch(objectText);
        final tool =
            toolMatch != null && toolNames.contains(toolMatch.group(1)!)
            ? toolMatch.group(1)!
            : null;

        final depsMatch = RegExp(
          r'"depends_on"\s*:\s*\[([^\]]*)\]',
        ).firstMatch(objectText);
        final deps = <int>{};
        if (depsMatch != null) {
          for (final match in RegExp(r'\d+').allMatches(depsMatch.group(1)!)) {
            deps.add(int.parse(match.group(0)!));
          }
        }

        steps.add(
          ParsedPlanStep(
            description: stepDesc,
            dependsOn: deps,
            suggestedTool: tool,
          ),
        );
      }

      return steps.isNotEmpty ? steps : null;
    } catch (_) {
      return null;
    }
  }

  static List<String> parseTextPlan(String content) {
    final lines = content.split('\n');
    final steps = <String>[];
    for (final line in lines) {
      final cleaned = line.replaceFirst(RegExp(r'^\d+[\.\)\s]*'), '').trim();
      if (cleaned.isNotEmpty &&
          !cleaned.startsWith('#') &&
          !cleaned.startsWith('```') &&
          !cleaned.startsWith('[') &&
          !cleaned.startsWith('{')) {
        steps.add(cleaned);
      }
    }
    return steps;
  }

  static ParsedReflection parseReflection(String content) {
    final passLine = extractLine(content, 'PASS');
    return ParsedReflection(
      passed: passLine == null ? true : passLine.toLowerCase().contains('yes'),
      evaluation: extractLine(content, 'EVALUATION'),
      feedback: extractLine(content, 'FEEDBACK'),
    );
  }

  static String? extractLine(String content, String prefix) {
    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith(prefix)) {
        return trimmed
            .substring(prefix.length)
            .replaceFirst(RegExp(r'^[:\s]*'), '')
            .trim();
      }
    }
    return null;
  }
}
