import 'dart:convert';
import 'dart:math';

import 'package:cryptography/dart.dart';

class FrozenEvaluationBundle {
  FrozenEvaluationBundle({
    required this.evaluatorBundleId,
    required List<String> deterministicVerifierReleaseHashes,
    required this.judgePromptReleaseHash,
    required this.judgeModelRouteHash,
    required this.rubricReleaseHash,
    required this.aggregatorReleaseHash,
    required this.blindingPolicyVersion,
    required this.systemJudgeRules,
  }) : deterministicVerifierReleaseHashes = List.unmodifiable(
         [...deterministicVerifierReleaseHashes]..sort(),
       ) {
    final identities = <String>[
      evaluatorBundleId,
      judgePromptReleaseHash,
      judgeModelRouteHash,
      rubricReleaseHash,
      aggregatorReleaseHash,
      blindingPolicyVersion,
      systemJudgeRules,
    ];
    if (identities.any((identity) => identity.trim().isEmpty) ||
        this.deterministicVerifierReleaseHashes.isEmpty ||
        this.deterministicVerifierReleaseHashes.any(
          (release) => release.trim().isEmpty,
        ) ||
        this.deterministicVerifierReleaseHashes.toSet().length !=
            this.deterministicVerifierReleaseHashes.length) {
      throw ArgumentError('evaluation bundle releases must be non-empty');
    }
    bundleHash = _domainHash('external-evaluation-bundle-v1', toJson());
  }

  final String evaluatorBundleId;
  final List<String> deterministicVerifierReleaseHashes;
  final String judgePromptReleaseHash;
  final String judgeModelRouteHash;
  final String rubricReleaseHash;
  final String aggregatorReleaseHash;
  final String blindingPolicyVersion;
  final String systemJudgeRules;
  late final String bundleHash;

  Map<String, Object?> toJson() => {
    'evaluatorBundleId': evaluatorBundleId,
    'deterministicVerifierReleaseHashes': deterministicVerifierReleaseHashes,
    'judgePromptReleaseHash': judgePromptReleaseHash,
    'judgeModelRouteHash': judgeModelRouteHash,
    'rubricReleaseHash': rubricReleaseHash,
    'aggregatorReleaseHash': aggregatorReleaseHash,
    'blindingPolicyVersion': blindingPolicyVersion,
    'systemJudgeRules': systemJudgeRules,
  };
}

class ExternalEvaluationCandidate {
  ExternalEvaluationCandidate({
    required this.prose,
    required this.armId,
    required this.generationBundleHash,
    required this.modelRouteHash,
    required Map<String, Object?> deterministicFacts,
  }) : deterministicFacts = Map.unmodifiable(deterministicFacts);

  final String prose;

  /// SUT provenance retained in the evaluator result, never sent to the judge.
  final String armId;
  final String generationBundleHash;
  final String modelRouteHash;
  final Map<String, Object?> deterministicFacts;
}

class SutEvaluationObservations {
  const SutEvaluationObservations({
    required this.qualityScore,
    required this.reviewPassed,
  });

  final double qualityScore;
  final bool reviewPassed;
}

abstract interface class DeterministicEvaluationVerifier {
  String get releaseHash;

  DeterministicVerifierOutput verify(ExternalEvaluationCandidate candidate);
}

class DeterministicVerifierOutput {
  DeterministicVerifierOutput({
    required this.passed,
    this.failureCode,
    required Map<String, Object?> evidence,
  }) : evidence = Map.unmodifiable(evidence);

  final bool passed;
  final String? failureCode;
  final Map<String, Object?> evidence;
}

class EvaluationReleaseRegistry {
  EvaluationReleaseRegistry({
    required List<DeterministicEvaluationVerifier> deterministicVerifiers,
    required Set<String> judgePromptReleaseHashes,
    required Set<String> judgeModelRouteHashes,
    required Set<String> rubricReleaseHashes,
    required Set<String> aggregatorReleaseHashes,
  }) : _judgePromptReleaseHashes = Set.unmodifiable(judgePromptReleaseHashes),
       _judgeModelRouteHashes = Set.unmodifiable(judgeModelRouteHashes),
       _rubricReleaseHashes = Set.unmodifiable(rubricReleaseHashes),
       _aggregatorReleaseHashes = Set.unmodifiable(aggregatorReleaseHashes) {
    for (final verifier in deterministicVerifiers) {
      if (verifier.releaseHash.trim().isEmpty ||
          _deterministicVerifiers.containsKey(verifier.releaseHash)) {
        throw ArgumentError(
          'deterministic verifier releases must be non-empty and unique',
        );
      }
      _deterministicVerifiers[verifier.releaseHash] = verifier;
    }
  }

  final Map<String, DeterministicEvaluationVerifier> _deterministicVerifiers =
      {};
  final Set<String> _judgePromptReleaseHashes;
  final Set<String> _judgeModelRouteHashes;
  final Set<String> _rubricReleaseHashes;
  final Set<String> _aggregatorReleaseHashes;

  bool supports(FrozenEvaluationBundle bundle) =>
      bundle.deterministicVerifierReleaseHashes.every(
        _deterministicVerifiers.containsKey,
      ) &&
      _judgePromptReleaseHashes.contains(bundle.judgePromptReleaseHash) &&
      _judgeModelRouteHashes.contains(bundle.judgeModelRouteHash) &&
      _rubricReleaseHashes.contains(bundle.rubricReleaseHash) &&
      _aggregatorReleaseHashes.contains(bundle.aggregatorReleaseHash);

  DeterministicEvaluationVerifier verifier(String releaseHash) {
    final verifier = _deterministicVerifiers[releaseHash];
    if (verifier == null) throw StateError('unknown verifier release');
    return verifier;
  }
}

class BlindedJudgeRequest {
  const BlindedJudgeRequest({
    required this.opaqueCandidateLabel,
    required this.systemMessage,
    required this.candidateMessage,
    required this.judgePromptReleaseHash,
    required this.judgeModelRouteHash,
    required this.rubricReleaseHash,
  });

  final String opaqueCandidateLabel;
  final String systemMessage;
  final String candidateMessage;
  final String judgePromptReleaseHash;
  final String judgeModelRouteHash;
  final String rubricReleaseHash;
}

abstract interface class ExternalSubjectiveJudge {
  Future<SubjectiveJudgeOutput> judge(BlindedJudgeRequest request);
}

class SubjectiveJudgeOutput {
  const SubjectiveJudgeOutput({
    required this.passed,
    required this.scores,
    required this.summary,
  });

  final bool passed;
  final Map<String, double> scores;
  final String summary;
}

abstract interface class OpaqueCandidateLabelGenerator {
  String nextLabel();
}

class SecureOpaqueCandidateLabelGenerator
    implements OpaqueCandidateLabelGenerator {
  SecureOpaqueCandidateLabelGenerator() : _random = Random.secure();

  final Random _random;

  @override
  String nextLabel() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    final suffix = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'candidate-$suffix';
  }
}

class ExternalEvaluationEvidence {
  ExternalEvaluationEvidence._({
    required this.proseHash,
    required this.evaluatorBundleHash,
    required this.judgePromptReleaseHash,
    required this.judgeModelRouteHash,
    required this.rubricReleaseHash,
    required this.aggregatorReleaseHash,
    required this.deterministicEvidenceHashes,
    required this.judgeOutputHash,
    required this.opaqueCandidateLabel,
  }) {
    evidenceHash = _domainHash('external-evaluation-evidence-v1', toJson());
  }

  final String proseHash;
  final String evaluatorBundleHash;
  final String judgePromptReleaseHash;
  final String judgeModelRouteHash;
  final String rubricReleaseHash;
  final String aggregatorReleaseHash;
  final List<String> deterministicEvidenceHashes;
  final String judgeOutputHash;
  final String opaqueCandidateLabel;
  late final String evidenceHash;

  Map<String, Object?> toJson() => {
    'proseHash': proseHash,
    'evaluatorBundleHash': evaluatorBundleHash,
    'judgePromptReleaseHash': judgePromptReleaseHash,
    'judgeModelRouteHash': judgeModelRouteHash,
    'rubricReleaseHash': rubricReleaseHash,
    'aggregatorReleaseHash': aggregatorReleaseHash,
    'deterministicEvidenceHashes': deterministicEvidenceHashes,
    'judgeOutputHash': judgeOutputHash,
    'opaqueCandidateLabel': opaqueCandidateLabel,
  };
}

enum ExternalEvaluationStatus { passed, failed, failClosed }

class ExternalEvaluationResult {
  ExternalEvaluationResult({
    required this.status,
    required this.sutObservations,
    required Set<String> failureCodes,
    required List<DeterministicVerifierOutput> deterministicOutputs,
    required this.subjectiveJudgeOutput,
    required this.evidence,
  }) : failureCodes = Set.unmodifiable(failureCodes),
       deterministicOutputs = List.unmodifiable(deterministicOutputs);

  final ExternalEvaluationStatus status;
  final SutEvaluationObservations sutObservations;
  final Set<String> failureCodes;
  final List<DeterministicVerifierOutput> deterministicOutputs;
  final SubjectiveJudgeOutput? subjectiveJudgeOutput;
  final ExternalEvaluationEvidence? evidence;

  bool get hardPass => status == ExternalEvaluationStatus.passed;
}

/// Runs frozen deterministic checks before an independently configured judge.
class ExternalAgentEvaluator {
  ExternalAgentEvaluator({
    required this.bundle,
    required this.releaseRegistry,
    required this.judge,
    OpaqueCandidateLabelGenerator? opaqueLabelGenerator,
  }) : opaqueLabelGenerator =
           opaqueLabelGenerator ?? SecureOpaqueCandidateLabelGenerator();

  final FrozenEvaluationBundle bundle;
  final EvaluationReleaseRegistry releaseRegistry;
  final ExternalSubjectiveJudge judge;
  final OpaqueCandidateLabelGenerator opaqueLabelGenerator;

  Future<ExternalEvaluationResult> evaluate({
    required ExternalEvaluationCandidate candidate,
    required SutEvaluationObservations sutObservations,
  }) async {
    if (!releaseRegistry.supports(bundle)) {
      return ExternalEvaluationResult(
        status: ExternalEvaluationStatus.failClosed,
        sutObservations: sutObservations,
        failureCodes: const {'evaluation.unknown_release'},
        deterministicOutputs: const [],
        subjectiveJudgeOutput: null,
        evidence: null,
      );
    }

    final proseHash = _domainHash('evaluated-prose-v1', candidate.prose);
    final deterministicOutputs = <DeterministicVerifierOutput>[];
    final deterministicEvidenceHashes = <String>[];
    try {
      for (final releaseHash in bundle.deterministicVerifierReleaseHashes) {
        final output = releaseRegistry.verifier(releaseHash).verify(candidate);
        deterministicOutputs.add(output);
        deterministicEvidenceHashes.add(
          _domainHash('deterministic-evaluation-evidence-v1', {
            'releaseHash': releaseHash,
            'proseHash': proseHash,
            'passed': output.passed,
            'failureCode': output.failureCode,
            'evidence': output.evidence,
          }),
        );
        final hasFailureCode =
            output.failureCode != null && output.failureCode!.trim().isNotEmpty;
        if (output.evidence.isEmpty ||
            (output.passed && hasFailureCode) ||
            (!output.passed && !hasFailureCode)) {
          return ExternalEvaluationResult(
            status: ExternalEvaluationStatus.failClosed,
            sutObservations: sutObservations,
            failureCodes: const {'evaluation.incomplete_verifier_evidence'},
            deterministicOutputs: deterministicOutputs,
            subjectiveJudgeOutput: null,
            evidence: null,
          );
        }
      }
    } catch (_) {
      return ExternalEvaluationResult(
        status: ExternalEvaluationStatus.failClosed,
        sutObservations: sutObservations,
        failureCodes: const {'evaluation.verifier_unavailable'},
        deterministicOutputs: deterministicOutputs,
        subjectiveJudgeOutput: null,
        evidence: null,
      );
    }

    final deterministicFailures = deterministicOutputs
        .where((output) => !output.passed)
        .map((output) => output.failureCode!)
        .toSet();
    if (deterministicFailures.isNotEmpty) {
      return ExternalEvaluationResult(
        status: ExternalEvaluationStatus.failed,
        sutObservations: sutObservations,
        failureCodes: deterministicFailures,
        deterministicOutputs: deterministicOutputs,
        subjectiveJudgeOutput: null,
        evidence: null,
      );
    }

    final label = opaqueLabelGenerator.nextLabel();
    if (label.trim().isEmpty ||
        label == candidate.armId ||
        label == candidate.generationBundleHash ||
        label == candidate.modelRouteHash) {
      return ExternalEvaluationResult(
        status: ExternalEvaluationStatus.failClosed,
        sutObservations: sutObservations,
        failureCodes: const {'evaluation.invalid_blinding_label'},
        deterministicOutputs: deterministicOutputs,
        subjectiveJudgeOutput: null,
        evidence: null,
      );
    }
    final request = BlindedJudgeRequest(
      opaqueCandidateLabel: label,
      systemMessage: bundle.systemJudgeRules,
      candidateMessage: jsonEncode({
        'opaqueCandidateLabel': label,
        'contentType': 'untrusted_quoted_candidate',
        'quotedContent': candidate.prose,
      }),
      judgePromptReleaseHash: bundle.judgePromptReleaseHash,
      judgeModelRouteHash: bundle.judgeModelRouteHash,
      rubricReleaseHash: bundle.rubricReleaseHash,
    );

    SubjectiveJudgeOutput judgeOutput;
    try {
      final rawOutput = await judge.judge(request);
      if (rawOutput.summary.trim().isEmpty ||
          rawOutput.scores.isEmpty ||
          rawOutput.scores.values.any(
            (score) => !score.isFinite || score < 0 || score > 100,
          )) {
        throw const FormatException('invalid external judge output');
      }
      judgeOutput = SubjectiveJudgeOutput(
        passed: rawOutput.passed,
        scores: Map.unmodifiable(rawOutput.scores),
        summary: rawOutput.summary,
      );
    } catch (_) {
      return ExternalEvaluationResult(
        status: ExternalEvaluationStatus.failClosed,
        sutObservations: sutObservations,
        failureCodes: const {'evaluation.judge_unavailable'},
        deterministicOutputs: deterministicOutputs,
        subjectiveJudgeOutput: null,
        evidence: null,
      );
    }

    final judgeOutputHash = _domainHash('subjective-judge-output-v1', {
      'passed': judgeOutput.passed,
      'scores': judgeOutput.scores,
      'summary': judgeOutput.summary,
    });
    final evidence = ExternalEvaluationEvidence._(
      proseHash: proseHash,
      evaluatorBundleHash: bundle.bundleHash,
      judgePromptReleaseHash: bundle.judgePromptReleaseHash,
      judgeModelRouteHash: bundle.judgeModelRouteHash,
      rubricReleaseHash: bundle.rubricReleaseHash,
      aggregatorReleaseHash: bundle.aggregatorReleaseHash,
      deterministicEvidenceHashes: List.unmodifiable(
        deterministicEvidenceHashes,
      ),
      judgeOutputHash: judgeOutputHash,
      opaqueCandidateLabel: label,
    );
    return ExternalEvaluationResult(
      status: judgeOutput.passed
          ? ExternalEvaluationStatus.passed
          : ExternalEvaluationStatus.failed,
      sutObservations: sutObservations,
      failureCodes: judgeOutput.passed
          ? const {}
          : const {'evaluation.subjective_quality'},
      deterministicOutputs: deterministicOutputs,
      subjectiveJudgeOutput: judgeOutput,
      evidence: evidence,
    );
  }
}

String _domainHash(String domain, Object? value) {
  final preimage = '$domain\u0000${jsonEncode(_canonicalize(value))}';
  final digest = const DartSha256().hashSync(utf8.encode(preimage));
  final hex = digest.bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return 'sha256:$hex';
}

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalize(value[key]),
    };
  }
  if (value is Iterable) {
    return value.map(_canonicalize).toList(growable: false);
  }
  return value;
}
