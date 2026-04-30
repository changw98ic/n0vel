import 'character_memory_delta_models.dart';
import 'scene_roleplay_session_models.dart';

class RoleplayAuditReport {
  const RoleplayAuditReport({
    required this.chapterId,
    required this.sceneId,
    required this.sceneTitle,
    required this.roundCount,
    required this.turnCount,
    required this.committedFactCount,
    required this.acceptedMemoryCount,
    required this.privateMemoryCount,
    required this.publicMemoryCount,
    required this.chainErrors,
    required this.summary,
  });

  final String chapterId;
  final String sceneId;
  final String sceneTitle;
  final int roundCount;
  final int turnCount;
  final int committedFactCount;
  final int acceptedMemoryCount;
  final int privateMemoryCount;
  final int publicMemoryCount;
  final List<String> chainErrors;
  final String summary;

  bool get passed => chainErrors.isEmpty;

  Map<String, Object?> toJson() {
    return {
      'chapterId': chapterId,
      'sceneId': sceneId,
      'sceneTitle': sceneTitle,
      'roundCount': roundCount,
      'turnCount': turnCount,
      'committedFactCount': committedFactCount,
      'acceptedMemoryCount': acceptedMemoryCount,
      'privateMemoryCount': privateMemoryCount,
      'publicMemoryCount': publicMemoryCount,
      'chainErrors': chainErrors,
      'summary': summary,
      'passed': passed,
    };
  }

  String toMarkdown() {
    return [
      '## Roleplay Audit: $chapterId/$sceneId $sceneTitle',
      '',
      '- status: ${passed ? 'pass' : 'failed'}',
      '- rounds: $roundCount',
      '- turns: $turnCount',
      '- committed facts: $committedFactCount',
      '- accepted memories: $acceptedMemoryCount',
      '- private memories: $privateMemoryCount',
      '- public memories: $publicMemoryCount',
      if (chainErrors.isNotEmpty) '',
      if (chainErrors.isNotEmpty) '### Chain Errors',
      for (final error in chainErrors) '- $error',
      if (summary.trim().isNotEmpty) '',
      if (summary.trim().isNotEmpty) '### Public Summary',
      if (summary.trim().isNotEmpty) summary.trim(),
    ].join('\n');
  }
}

class RoleplayAuditReportBuilder {
  const RoleplayAuditReportBuilder();

  RoleplayAuditReport build(SceneRoleplaySession session) {
    final accepted = session.acceptedMemoryDeltas;
    return RoleplayAuditReport(
      chapterId: session.chapterId,
      sceneId: session.sceneId,
      sceneTitle: session.sceneTitle,
      roundCount: session.rounds.length,
      turnCount: [for (final round in session.rounds) ...round.turns].length,
      committedFactCount: session.committedFacts.length,
      acceptedMemoryCount: accepted.length,
      privateMemoryCount: _countPrivateMemories(accepted),
      publicMemoryCount: session.acceptedPublicMemoryDeltas.length,
      chainErrors: session.validateCommittedFactChain(),
      summary: session.toCommittedPromptText(maxChars: 2400),
    );
  }

  List<RoleplayAuditReport> buildAll(List<SceneRoleplaySession> sessions) {
    return [for (final session in sessions) build(session)];
  }

  int _countPrivateMemories(List<CharacterMemoryDelta> deltas) {
    return [
      for (final delta in deltas)
        if (delta.characterId.isNotEmpty) delta,
    ].length;
  }
}
