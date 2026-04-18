part of 'character_simulation_service.dart';

Map<String, String?> parseCharacterSimulationResponse(String content) {
  try {
    final jsonStr = extractCharacterSimulationJsonBlock(content);
    if (jsonStr != null) {
      final decoded = json.decode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return {
          'reaction': decoded['reaction']?.toString(),
          'dialogue': decoded['dialogue']?.toString(),
          'innerThought': decoded['innerThought']?.toString(),
          'emotionalState': decoded['emotionalState']?.toString(),
        };
      }
    }
  } catch (_) {}

  return {'reaction': content.trim()};
}

List<DialogueLine> parseCharacterSimulationDialogueLines(String content) {
  try {
    final jsonStr = extractCharacterSimulationJsonBlock(content);
    if (jsonStr != null) {
      final decoded = json.decode(jsonStr);
      if (decoded is List) {
        return decoded
            .map((item) {
              if (item is Map<String, dynamic>) {
                return DialogueLine(
                  characterName: item['characterName']?.toString() ?? '未知角色',
                  dialogue: item['dialogue']?.toString() ?? '',
                  stageDirection: item['stageDirection']?.toString(),
                  innerThought: item['innerThought']?.toString(),
                );
              }
              return null;
            })
            .whereType<DialogueLine>()
            .toList();
      }
    }
  } catch (_) {}

  return parseCharacterSimulationDialogueFromText(content);
}

OOCAnalysis parseCharacterSimulationOocAnalysis(String content) {
  try {
    final jsonStr = extractCharacterSimulationJsonBlock(content);
    if (jsonStr != null) {
      final decoded = json.decode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return OOCAnalysis(
          isOOC: decoded['isOOC'] == true,
          confidence: parseCharacterSimulationDouble(decoded['confidence'], 0.5),
          explanation: decoded['explanation']?.toString(),
          suggestion: decoded['suggestion']?.toString(),
        );
      }
    }
  } catch (_) {}

  final lower = content.toLowerCase();
  final isOOC =
      lower.contains('ooc') || lower.contains('不一致') || lower.contains('偏离');
  return OOCAnalysis(
    isOOC: isOOC,
    confidence: 0.3,
    explanation: content.trim(),
  );
}

String? extractCharacterSimulationJsonBlock(String content) {
  final trimmed = content.trim();

  if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
      (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
    return trimmed;
  }

  final codeBlockRegex = RegExp(r'```(?:json)?\s*\n?([\s\S]*?)\n?```');
  final codeBlockMatch = codeBlockRegex.firstMatch(trimmed);
  if (codeBlockMatch != null) {
    return codeBlockMatch.group(1)?.trim();
  }

  final jsonStart = trimmed.indexOf('{');
  final arrayStart = trimmed.indexOf('[');
  late final int startIdx;

  if (jsonStart >= 0 && (arrayStart < 0 || jsonStart < arrayStart)) {
    startIdx = jsonStart;
  } else if (arrayStart >= 0) {
    startIdx = arrayStart;
  } else {
    return null;
  }

  var depth = 0;
  var inString = false;
  var escape = false;

  for (var i = startIdx; i < trimmed.length; i++) {
    final ch = trimmed[i];
    if (escape) {
      escape = false;
      continue;
    }
    if (ch == '\\' && inString) {
      escape = true;
      continue;
    }
    if (ch == '"') {
      inString = !inString;
      continue;
    }
    if (inString) continue;

    if (ch == '{' || ch == '[') depth++;
    if (ch == '}' || ch == ']') {
      depth--;
      if (depth == 0) {
        return trimmed.substring(startIdx, i + 1);
      }
    }
  }

  return null;
}

List<DialogueLine> parseCharacterSimulationDialogueFromText(String content) {
  final lines = <DialogueLine>[];
  final dialogueRegex = RegExp(
    r'([^：「」""\n]{1,20})[：:]\s*[「"「]([^」"」]+)[」"」]',
  );

  for (final match in dialogueRegex.allMatches(content)) {
    lines.add(DialogueLine(
      characterName: match.group(1)?.trim() ?? '未知角色',
      dialogue: match.group(2)?.trim() ?? '',
    ));
  }

  return lines;
}

double parseCharacterSimulationDouble(dynamic value, double fallback) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}
