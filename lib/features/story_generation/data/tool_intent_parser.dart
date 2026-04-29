import '../domain/pipeline_models.dart';

/// Parses retrieval intents from role agent text output.
///
/// When a role agent needs more context, it emits a line starting with
/// `RETRIEVE:` indicating which tool it wants to call and with what params.
class ToolIntentParser {
  static const _retrievePrefix = 'RETRIEVE:';

  /// Tries to parse a [RetrievalIntent] from the agent's text output.
  /// Returns `null` if no retrieval intent is found.
  RetrievalIntent? tryParse(String text, String characterId) {
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith(_retrievePrefix)) {
        final payload = trimmed.substring(_retrievePrefix.length).trim();
        return _parsePayload(payload, characterId);
      }
    }
    return null;
  }

  RetrievalIntent _parsePayload(String payload, String characterId) {
    // Format: RETRIEVE:tool_name or RETRIEVE:tool_name:key=val,key2=val2
    final colonIndex = payload.indexOf(':');
    if (colonIndex < 0) {
      return RetrievalIntent(
        characterId: characterId,
        toolName: payload.trim(),
        reasoning: 'Agent requested retrieval',
      );
    }

    final toolName = payload.substring(0, colonIndex).trim();
    final paramsStr = payload.substring(colonIndex + 1).trim();
    final parameters = <String, Object?>{};

    for (final pair in paramsStr.split(',')) {
      final eqIndex = pair.indexOf('=');
      if (eqIndex > 0) {
        parameters[pair.substring(0, eqIndex).trim()] =
            pair.substring(eqIndex + 1).trim();
      }
    }

    return RetrievalIntent(
      characterId: characterId,
      toolName: toolName,
      parameters: parameters,
      reasoning: 'Agent requested retrieval',
    );
  }

  /// Returns true if the text contains a valid retrieval intent
  /// referencing an allowed tool.
  bool hasValidRetrievalIntent(String text) {
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith(_retrievePrefix)) {
        final toolName = _extractToolName(
          trimmed.substring(_retrievePrefix.length),
        );
        if (RetrievalIntent.allowedTools.contains(toolName)) return true;
      }
    }
    return false;
  }

  String _extractToolName(String payload) {
    final colonIndex = payload.indexOf(':');
    return colonIndex < 0
        ? payload.trim()
        : payload.substring(0, colonIndex).trim();
  }
}
