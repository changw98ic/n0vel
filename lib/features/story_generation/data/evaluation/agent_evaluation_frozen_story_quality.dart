import '../story_mechanics_verifier.dart';

final class AgentEvaluationStoryQualityVerdict {
  const AgentEvaluationStoryQualityVerdict({
    required this.passed,
    required this.failureCodes,
    required this.evidenceHash,
  });

  final bool passed;
  final List<String> failureCodes;
  final String evidenceHash;
}

/// Frozen deterministic authority for story-world mechanics and repetition.
/// It intentionally covers only hard, text-observable contradictions; softer
/// literary quality remains the responsibility of the blinded judge.
final class AgentEvaluationFrozenStoryQualityVerifier {
  factory AgentEvaluationFrozenStoryQualityVerifier.standard() {
    return AgentEvaluationFrozenStoryQualityVerifier._(
      releaseHash: StoryMechanicsVerifier.releaseHash,
    );
  }

  const AgentEvaluationFrozenStoryQualityVerifier._({
    required this.releaseHash,
  });

  final String releaseHash;

  AgentEvaluationStoryQualityVerdict verify(String prose) {
    final evidence = StoryMechanicsVerifier.standard.verify(prose);
    return AgentEvaluationStoryQualityVerdict(
      passed: evidence.passed,
      failureCodes: evidence.failureCodes,
      evidenceHash: evidence.evidenceHash,
    );
  }
}
