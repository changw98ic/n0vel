abstract interface class StoryGenerationFormatterTraceSink {
  Future<void> record(StoryGenerationFormatterTraceEntry entry);
}

class StoryGenerationFormatterTraceEntry {
  const StoryGenerationFormatterTraceEntry({
    required this.timestampMs,
    required this.chapterId,
    required this.sceneId,
    required this.sceneTitle,
    required this.formatter,
    required this.passName,
    required this.passLabel,
    required this.rawText,
    required this.finalText,
    required this.repairAttempted,
    required this.usedFallback,
    this.repairedText,
  });

  final int timestampMs;
  final String chapterId;
  final String sceneId;
  final String sceneTitle;
  final String formatter;
  final String passName;
  final String passLabel;
  final String rawText;
  final String finalText;
  final bool repairAttempted;
  final bool usedFallback;
  final String? repairedText;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'timestampMs': timestampMs,
      'chapterId': chapterId,
      'sceneId': sceneId,
      'sceneTitle': sceneTitle,
      'formatter': formatter,
      'passName': passName,
      'passLabel': passLabel,
      'rawText': rawText,
      if (repairedText != null) 'repairedText': repairedText,
      'finalText': finalText,
      'repairAttempted': repairAttempted,
      'usedFallback': usedFallback,
    };
  }
}
