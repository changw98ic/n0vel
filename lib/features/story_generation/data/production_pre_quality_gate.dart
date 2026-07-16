import '../../../app/llm/app_llm_canonical_hash.dart';
import '../domain/scene_models.dart';
import 'polish_canon_evidence.dart';
import 'polish_canon_verifier.dart';
import 'scene_hard_gates.dart';
import 'story_mechanics_evidence.dart';
import 'story_mechanics_verifier.dart';

/// The provider-free production boundary immediately before final council and
/// independent quality scoring.
///
/// This boundary is intentionally reusable for author-repaired prose. It
/// re-derives the same deterministic evidence consumed by the live pipeline,
/// but it cannot create a quality score, candidate proof, or commit receipt.
final class ProductionPreQualityGate {
  const ProductionPreQualityGate({
    this.polishCanonVerifier = PolishCanonVerifier.standard,
    this.storyMechanicsVerifier = StoryMechanicsVerifier.standard,
  });

  static const standard = ProductionPreQualityGate();

  final PolishCanonVerifier polishCanonVerifier;
  final StoryMechanicsVerifier storyMechanicsVerifier;

  static String get releaseHash => AppLlmCanonicalHash.domainHash(
    'production-pre-quality-gate-release-v3',
    <String, Object?>{
      'boundary': 'post-polish-deterministic-pre-independent-quality',
      'sourceModes': const <String>['pipelinePolish', 'authorRevision'],
      'authorRevisionPolicy':
          'distinct-predecessor-pre-quality-only-no-candidate-finalization-v2',
      'formalHardGates': 'required-enabled-v1',
      'briefBinding': 'exact-hard-gate-requirements-v1',
      'sceneHardGateReleaseHash': sceneHardGateReleaseHash,
      'polishCanonVerifierReleaseHash': PolishCanonVerifier.releaseHash,
      'storyMechanicsVerifierReleaseHash': StoryMechanicsVerifier.releaseHash,
      'downstreamStages': const <String>[
        'final-council',
        'independent-quality-95-90',
        'candidate-finalization',
        'author-commit',
      ],
    },
  );

  ProductionPreQualityEvidence verifyPipelinePolish({
    required SceneBrief brief,
    required ProjectMaterialSnapshot materials,
    required String prePolishProse,
    required String finalProse,
    bool hardGatesEnabled = true,
  }) => _verify(
    brief: brief,
    materials: materials,
    prePolishProse: prePolishProse,
    finalProse: finalProse,
    hardGatesEnabled: hardGatesEnabled,
    sourceMode: ProductionPreQualitySourceMode.pipelinePolish,
  );

  ProductionPreQualityEvidence verifyAuthorRevision({
    required SceneBrief brief,
    required ProjectMaterialSnapshot materials,
    required String predecessorProse,
    required String revisedProse,
    bool hardGatesEnabled = true,
  }) => _verify(
    brief: brief,
    materials: materials,
    prePolishProse: predecessorProse,
    finalProse: revisedProse,
    hardGatesEnabled: hardGatesEnabled,
    sourceMode: ProductionPreQualitySourceMode.authorRevision,
  );

  ProductionPreQualityEvidence _verify({
    required SceneBrief brief,
    required ProjectMaterialSnapshot materials,
    required String prePolishProse,
    required String finalProse,
    bool hardGatesEnabled = true,
    ProductionPreQualitySourceMode sourceMode =
        ProductionPreQualitySourceMode.pipelinePolish,
  }) {
    final normalizedSource = prePolishProse.replaceAll('\r\n', '\n').trim();
    final normalizedFinal = finalProse.replaceAll('\r\n', '\n').trim();
    if (normalizedSource.isEmpty || normalizedFinal.isEmpty) {
      throw const ProductionPreQualityConfigurationViolation(
        'source and final prose must both be non-empty',
      );
    }
    if (brief.formalExecution && !hardGatesEnabled) {
      throw const ProductionPreQualityConfigurationViolation(
        'formal pre-quality verification requires hard gates',
      );
    }
    if (sourceMode == ProductionPreQualitySourceMode.authorRevision &&
        normalizedSource == normalizedFinal) {
      throw const ProductionPreQualityConfigurationViolation(
        'author revision requires a distinct predecessor; final prose cannot '
        'authorize itself',
      );
    }
    final hardGateViolations = sceneHardGateViolations(
      brief: brief,
      proseText: finalProse,
      enabled: hardGatesEnabled,
    );
    final polishCanonEvidence = polishCanonVerifier.verify(
      prePolishProse: prePolishProse,
      polishedProse: finalProse,
      brief: brief,
      materials: materials,
    );
    final storyMechanicsEvidence = storyMechanicsVerifier.verify(finalProse);
    return ProductionPreQualityEvidence._(
      boundaryReleaseHash: releaseHash,
      finalProseHash: finalProseHash(finalProse),
      sourceMode: sourceMode,
      candidateFinalizationEligible:
          sourceMode == ProductionPreQualitySourceMode.pipelinePolish,
      hardGatesEnabled: hardGatesEnabled,
      briefRequirementsHash: briefRequirementsHash(brief),
      hardGateViolations: List<HardGateViolation>.unmodifiable(
        hardGateViolations,
      ),
      hardGateViolationHashes: _hardGateViolationHashes(hardGateViolations),
      polishCanonEvidence: polishCanonEvidence,
      storyMechanicsEvidence: storyMechanicsEvidence,
    );
  }

  static String briefRequirementsHash(SceneBrief brief) =>
      AppLlmCanonicalHash.domainHash(
        'production-pre-quality-brief-requirements-v1',
        <String, Object?>{
          'projectId': brief.projectId,
          'chapterId': brief.chapterId,
          'chapterTitle': brief.chapterTitle,
          'sceneId': brief.sceneId,
          'sceneTitle': brief.sceneTitle,
          'sceneSummary': brief.sceneSummary,
          'targetLength': brief.targetLength,
          'targetBeat': brief.targetBeat,
          'sceneIndex': brief.sceneIndex,
          'totalScenesInChapter': brief.totalScenesInChapter,
          'formalExecution': brief.formalExecution,
          'cast': <Object?>[
            for (final member in brief.cast)
              <String, Object?>{
                'characterId': member.characterId,
                'name': member.name,
                'role': member.role,
              },
          ],
          'hardGateMetadata': <String, Object?>{
            for (final key in const <String>[
              'requireOutlineFidelity',
              'requiredOutlineBeats',
              'requireContinuityLedger',
              'continuityLedger',
              'continuityEntityDeclarations',
              'requireClicheHardGate',
              'requireCharacterIntroduction',
              'requiredCharacterIntroductions',
            ])
              if (brief.metadata.containsKey(key)) key: brief.metadata[key],
          },
        },
      );

  static String finalProseHash(String prose) => AppLlmCanonicalHash.domainHash(
    'production-pre-quality-final-prose-v1',
    prose.replaceAll('\r\n', '\n'),
  );

  static List<String> _hardGateViolationHashes(
    Iterable<HardGateViolation> violations,
  ) => <String>{
    for (final violation in violations)
      AppLlmCanonicalHash.domainHash(
        'production-pre-quality-hard-gate-violation-v1',
        <String, Object?>{
          'failureCode': violation.failureCode.name,
          'text': violation.text,
        },
      ),
  }.toList()..sort();
}

enum ProductionPreQualitySourceMode { pipelinePolish, authorRevision }

/// Hash-bound output of [ProductionPreQualityGate].
///
/// Passing this boundary means only that provider-free production checks
/// passed for the exact prose. It explicitly remains ineligible for release
/// until the downstream council, quality, finalization, and author-commit
/// stages complete.
final class ProductionPreQualityEvidence {
  ProductionPreQualityEvidence._({
    required this.boundaryReleaseHash,
    required this.finalProseHash,
    required this.sourceMode,
    required this.candidateFinalizationEligible,
    required this.hardGatesEnabled,
    required this.briefRequirementsHash,
    required this.hardGateViolations,
    required Iterable<String> hardGateViolationHashes,
    required this.polishCanonEvidence,
    required this.storyMechanicsEvidence,
  }) : hardGateViolationHashes = List<String>.unmodifiable(
         hardGateViolationHashes.toSet().toList()..sort(),
       );

  static const schemaVersion = 'production-pre-quality-evidence-v3';

  final String boundaryReleaseHash;
  final String finalProseHash;
  final ProductionPreQualitySourceMode sourceMode;
  final bool candidateFinalizationEligible;
  final bool hardGatesEnabled;
  final String briefRequirementsHash;
  final List<HardGateViolation> hardGateViolations;
  final List<String> hardGateViolationHashes;
  final PolishCanonEvidence polishCanonEvidence;
  final StoryMechanicsEvidence storyMechanicsEvidence;

  bool get passed =>
      hardGatesEnabled &&
      hardGateViolationHashes.isEmpty &&
      polishCanonEvidence.passed &&
      storyMechanicsEvidence.passed;

  String get nextRequiredStage =>
      sourceMode == ProductionPreQualitySourceMode.authorRevision
      ? 'pipeline_polish_revalidation'
      : 'independent_quality';

  String get evidenceHash => AppLlmCanonicalHash.domainHash(
    'production-pre-quality-evidence-v3',
    _identityJson(),
  );

  Map<String, Object?> toJson() => <String, Object?>{
    ..._identityJson(),
    'evidenceHash': evidenceHash,
  };

  static ProductionPreQualityEvidence fromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('pre-quality evidence must be an object');
    }
    final value = <String, Object?>{
      for (final entry in raw.entries) entry.key.toString(): entry.value,
    };
    const keys = <String>{
      'schemaVersion',
      'boundaryReleaseHash',
      'sourceMode',
      'candidateFinalizationEligible',
      'hardGatesEnabled',
      'briefRequirementsHash',
      'finalProseHash',
      'sceneHardGateReleaseHash',
      'hardGateViolationHashes',
      'polishCanonEvidence',
      'storyMechanicsEvidence',
      'passed',
      'nextRequiredStage',
      'releaseEligible',
      'evidenceHash',
    };
    if (value.keys.toSet().difference(keys).isNotEmpty ||
        keys.difference(value.keys.toSet()).isNotEmpty ||
        value['schemaVersion'] != schemaVersion ||
        value['candidateFinalizationEligible'] is! bool ||
        value['hardGatesEnabled'] is! bool ||
        value['hardGateViolationHashes'] is! List ||
        value['sceneHardGateReleaseHash'] != sceneHardGateReleaseHash ||
        value['releaseEligible'] != false) {
      throw const FormatException('pre-quality evidence shape is invalid');
    }
    late final ProductionPreQualitySourceMode sourceMode;
    try {
      sourceMode = ProductionPreQualitySourceMode.values.byName(
        value['sourceMode'] as String,
      );
    } on Object {
      throw const FormatException('pre-quality source mode is invalid');
    }
    final evidence = ProductionPreQualityEvidence._(
      boundaryReleaseHash: value['boundaryReleaseHash'] as String,
      finalProseHash: value['finalProseHash'] as String,
      sourceMode: sourceMode,
      candidateFinalizationEligible:
          value['candidateFinalizationEligible'] as bool,
      hardGatesEnabled: value['hardGatesEnabled'] as bool,
      briefRequirementsHash: value['briefRequirementsHash'] as String,
      hardGateViolations: const <HardGateViolation>[],
      hardGateViolationHashes: (value['hardGateViolationHashes'] as List)
          .cast<String>(),
      polishCanonEvidence: PolishCanonEvidence.fromJson(
        value['polishCanonEvidence'],
      ),
      storyMechanicsEvidence: StoryMechanicsEvidence.fromJson(
        value['storyMechanicsEvidence'],
      ),
    );
    if (evidence.candidateFinalizationEligible !=
            (sourceMode == ProductionPreQualitySourceMode.pipelinePolish) ||
        value['nextRequiredStage'] != evidence.nextRequiredStage ||
        value['passed'] != evidence.passed ||
        value['evidenceHash'] != evidence.evidenceHash) {
      throw const FormatException('pre-quality evidence hash is invalid');
    }
    return evidence;
  }

  Map<String, Object?> _identityJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'boundaryReleaseHash': boundaryReleaseHash,
    'sourceMode': sourceMode.name,
    'candidateFinalizationEligible': candidateFinalizationEligible,
    'hardGatesEnabled': hardGatesEnabled,
    'briefRequirementsHash': briefRequirementsHash,
    'finalProseHash': finalProseHash,
    'sceneHardGateReleaseHash': sceneHardGateReleaseHash,
    'hardGateViolationHashes': hardGateViolationHashes,
    'polishCanonEvidence': polishCanonEvidence.toJson(),
    'storyMechanicsEvidence': storyMechanicsEvidence.toJson(),
    'passed': passed,
    'nextRequiredStage': nextRequiredStage,
    'releaseEligible': false,
  };
}

final class ProductionPreQualityConfigurationViolation implements Exception {
  const ProductionPreQualityConfigurationViolation(this.message);

  final String message;

  @override
  String toString() => 'ProductionPreQualityConfigurationViolation($message)';
}

final class ProductionPreQualityGateViolation implements Exception {
  const ProductionPreQualityGateViolation(this.evidence);

  final ProductionPreQualityEvidence evidence;

  @override
  String toString() =>
      'ProductionPreQualityGateViolation('
      '${evidence.hardGateViolationHashes.length} hard-gate findings; '
      'canon=${evidence.polishCanonEvidence.failureCodes.join(',')}; '
      'mechanics=${evidence.storyMechanicsEvidence.failureCodes.join(',')})';
}
