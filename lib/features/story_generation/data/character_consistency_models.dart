/// Severity of a consistency issue found during verification.
enum ConsistencySeverity {
  /// Informational note, does not affect generation.
  info,

  /// A potential inconsistency that should be flagged.
  warning,

  /// A clear violation that should trigger a rewrite.
  blocking,
}

/// Aspect of character consistency being checked.
enum ConsistencyAspect {
  /// Dialogue tone/voice matches character profile.
  dialogueVoice,

  /// Actions align with character capabilities and current state.
  actionCapability,

  /// Character only references information they should know.
  knowledgeBoundary,

  /// Emotional trajectory follows established arc.
  emotionalArc,

  /// Relationships align with established dynamics.
  relationshipConsistency,
}

/// A single consistency issue detected during verification.
class ConsistencyIssue {
  const ConsistencyIssue({
    required this.aspect,
    required this.severity,
    required this.characterId,
    required this.description,
    this.suggestion,
  });

  final ConsistencyAspect aspect;
  final ConsistencySeverity severity;
  final String characterId;
  final String description;
  final String? suggestion;

  @override
  String toString() =>
      '[$severity] $aspect @ $characterId: $description'
      '${suggestion != null ? " → $suggestion" : ""}';
}

/// Report containing all consistency issues found during a verification pass.
class ConsistencyReport {
  const ConsistencyReport({required this.issues});

  final List<ConsistencyIssue> issues;

  bool get hasBlockingIssues =>
      issues.any((i) => i.severity == ConsistencySeverity.blocking);

  bool get hasWarnings =>
      issues.any((i) => i.severity == ConsistencySeverity.warning);

  bool get isEmpty => issues.isEmpty;

  /// Formats issues as text for injection into review prompts.
  String toPromptText() {
    if (isEmpty) return '';
    final buffer = StringBuffer('【角色一致性校验】\n');
    for (final issue in issues) {
      final marker = switch (issue.severity) {
        ConsistencySeverity.blocking => '❌',
        ConsistencySeverity.warning => '⚠️',
        ConsistencySeverity.info => 'ℹ️',
      };
      buffer.writeln(
        '$marker ${issue.aspect.name} [${issue.characterId}]: ${issue.description}',
      );
      if (issue.suggestion != null) {
        buffer.writeln('   建议: ${issue.suggestion}');
      }
    }
    return buffer.toString();
  }

  /// Issues filtered to a specific character.
  List<ConsistencyIssue> issuesFor(String characterId) =>
      issues.where((i) => i.characterId == characterId).toList();

  /// Issues filtered to a specific aspect.
  List<ConsistencyIssue> issuesOf(ConsistencyAspect aspect) =>
      issues.where((i) => i.aspect == aspect).toList();
}
