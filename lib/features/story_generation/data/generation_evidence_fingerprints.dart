import 'dart:convert';

import 'package:cryptography/dart.dart';

import '../../../app/llm/app_llm_canonical_hash.dart';

final class GenerationFingerprint {
  factory GenerationFingerprint({
    required Object? semanticInput,
    required String generationBundleHash,
    required String modelRoute,
    required Object? decodingParameters,
    required String armPolicy,
    required String retryPolicy,
    String domainTag = defaultDomainTag,
    String? expectedDigest,
  }) {
    final tag = _domainTag(
      domainTag,
      'domainTag',
      expectedPrefix: 'story-generation-fingerprint',
    );
    if (tag != defaultDomainTag) {
      throw ArgumentError.value(
        domainTag,
        'domainTag',
        'only the exact v1 generation fingerprint contract is writable',
      );
    }
    final canonical = <String, Object?>{
      'domainTag': tag,
      'canonicalContract': AppLlmCanonicalHash.contract,
      'semanticInput': AppLlmCanonicalHash.immutableSnapshot(semanticInput),
      'generationBundleHash': _sha256(
        generationBundleHash,
        'generationBundleHash',
      ),
      'modelRoute': _sha256(modelRoute, 'modelRoute'),
      'decodingParameters': AppLlmCanonicalHash.immutableSnapshot(
        decodingParameters,
      ),
      'armPolicy': _required(armPolicy, 'armPolicy'),
      'retryPolicy': _sha256(retryPolicy, 'retryPolicy'),
    };
    final digest = AppLlmCanonicalHash.domainHash(tag, canonical);
    if (expectedDigest != null &&
        _sha256(expectedDigest, 'expectedDigest') != digest) {
      throw StateError('GenerationFingerprint digest mismatch');
    }
    return GenerationFingerprint._(
      domainTag: tag,
      semanticInput: canonical['semanticInput'],
      generationBundleHash: canonical['generationBundleHash']! as String,
      modelRoute: canonical['modelRoute']! as String,
      decodingParameters: canonical['decodingParameters'],
      armPolicy: canonical['armPolicy']! as String,
      retryPolicy: canonical['retryPolicy']! as String,
      digest: digest,
    );
  }

  const GenerationFingerprint._({
    required this.domainTag,
    required this.semanticInput,
    required this.generationBundleHash,
    required this.modelRoute,
    required this.decodingParameters,
    required this.armPolicy,
    required this.retryPolicy,
    required this.digest,
  });

  static const String defaultDomainTag = 'story-generation-fingerprint-v1';

  final String domainTag;
  final Object? semanticInput;
  final String generationBundleHash;
  final String modelRoute;
  final Object? decodingParameters;
  final String armPolicy;
  final String retryPolicy;
  final String digest;

  Map<String, Object?> toCanonicalMap() => {
    'domainTag': domainTag,
    'canonicalContract': AppLlmCanonicalHash.contract,
    'semanticInput': semanticInput,
    'generationBundleHash': generationBundleHash,
    'modelRoute': modelRoute,
    'decodingParameters': decodingParameters,
    'armPolicy': armPolicy,
    'retryPolicy': retryPolicy,
  };
}

final class EvaluationFingerprint {
  factory EvaluationFingerprint({
    required ArtifactDigest artifactDigest,
    required String evaluationBundleHash,
    required Object? judgeInput,
    required String judgeModelRoute,
    required String rubricHash,
    required String blindingPolicy,
    String domainTag = defaultDomainTag,
    String? expectedDigest,
  }) {
    final tag = _domainTag(
      domainTag,
      'domainTag',
      expectedPrefix: 'story-evaluation-fingerprint',
    );
    if (tag != defaultDomainTag) {
      throw ArgumentError.value(
        domainTag,
        'domainTag',
        'only the exact v1 evaluation fingerprint contract is writable',
      );
    }
    final evaluatedArtifactDigest = Map<String, Object?>.unmodifiable(
      artifactDigest.toCanonicalMap(),
    );
    final semanticInputDigest = AppLlmCanonicalHash.domainHash(
      judgeSemanticInputDomainTag,
      AppLlmCanonicalHash.immutableSnapshot(judgeInput),
    );
    final canonicalJudgeInput =
        Map<String, Object?>.unmodifiable(<String, Object?>{
          'evaluatedArtifactDigest': evaluatedArtifactDigest,
          'semanticInputDigest': semanticInputDigest,
        });
    final canonical = <String, Object?>{
      'domainTag': tag,
      'canonicalContract': AppLlmCanonicalHash.contract,
      'artifactDigest': evaluatedArtifactDigest,
      'evaluationBundleHash': _sha256(
        evaluationBundleHash,
        'evaluationBundleHash',
      ),
      'judgeInput': canonicalJudgeInput,
      'judgeModelRoute': _sha256(judgeModelRoute, 'judgeModelRoute'),
      'rubricHash': _sha256(rubricHash, 'rubricHash'),
      'blindingPolicy': _required(blindingPolicy, 'blindingPolicy'),
    };
    final digest = AppLlmCanonicalHash.domainHash(tag, canonical);
    if (expectedDigest != null &&
        _sha256(expectedDigest, 'expectedDigest') != digest) {
      throw StateError('EvaluationFingerprint digest mismatch');
    }
    return EvaluationFingerprint._(
      domainTag: tag,
      artifactDigest: artifactDigest,
      evaluationBundleHash: canonical['evaluationBundleHash']! as String,
      judgeInput: canonical['judgeInput'],
      judgeModelRoute: canonical['judgeModelRoute']! as String,
      rubricHash: canonical['rubricHash']! as String,
      blindingPolicy: canonical['blindingPolicy']! as String,
      digest: digest,
    );
  }

  const EvaluationFingerprint._({
    required this.domainTag,
    required this.artifactDigest,
    required this.evaluationBundleHash,
    required this.judgeInput,
    required this.judgeModelRoute,
    required this.rubricHash,
    required this.blindingPolicy,
    required this.digest,
  });

  static const String defaultDomainTag = 'story-evaluation-fingerprint-v1';
  static const String judgeSemanticInputDomainTag =
      'story-evaluation-judge-semantic-input-v1';

  final String domainTag;
  final ArtifactDigest artifactDigest;
  final String evaluationBundleHash;

  /// Credential-free canonical binding for the evaluated artifact and a
  /// domain-separated digest of the caller's immutable judge semantics.
  ///
  /// Raw judge input is intentionally never retained or serialized.
  final Object? judgeInput;
  final String judgeModelRoute;
  final String rubricHash;
  final String blindingPolicy;
  final String digest;

  Map<String, Object?> toCanonicalMap() => {
    'domainTag': domainTag,
    'canonicalContract': AppLlmCanonicalHash.contract,
    'artifactDigest': artifactDigest.toCanonicalMap(),
    'evaluationBundleHash': evaluationBundleHash,
    'judgeInput': judgeInput,
    'judgeModelRoute': judgeModelRoute,
    'rubricHash': rubricHash,
    'blindingPolicy': blindingPolicy,
  };
}

final class ArtifactDigest {
  factory ArtifactDigest.fromUtf8String(
    String content, {
    String domainTag = defaultDomainTag,
    String? expectedDigest,
  }) {
    final tag = _domainTag(
      domainTag,
      'domainTag',
      expectedPrefix: 'story-artifact-utf8-bytes',
    );
    if (tag != defaultDomainTag) {
      throw ArgumentError.value(
        domainTag,
        'domainTag',
        'only the exact v1 artifact digest contract is writable',
      );
    }
    final bytes = utf8.encode(content);
    final digest = _sha256Bytes(bytes);
    if (expectedDigest != null &&
        _sha256(expectedDigest, 'expectedDigest') != digest) {
      throw StateError('ArtifactDigest digest mismatch');
    }
    return ArtifactDigest._(
      domainTag: tag,
      byteLength: bytes.length,
      digest: digest,
    );
  }

  const ArtifactDigest._({
    required this.domainTag,
    required this.byteLength,
    required this.digest,
  });

  static const String defaultDomainTag = 'story-artifact-utf8-bytes-v1';

  final String domainTag;
  final int byteLength;
  final String digest;

  Map<String, Object?> toCanonicalMap() => {
    'domainTag': domainTag,
    'byteContract': 'exact-utf8-bytes-no-normalization-v1',
    'byteLength': byteLength,
    'digest': digest,
  };
}

String _sha256Bytes(List<int> bytes) {
  final digest = const DartSha256().hashSync(bytes);
  final hex = digest.bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return 'sha256:$hex';
}

String _required(String value, String field) {
  final normalized = AppLlmCanonicalHash.normalizeNfc(value.trim());
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'required');
  }
  return normalized;
}

String _sha256(String value, String field) {
  final normalized = _required(value, field);
  if (!RegExp(r'^sha256:[0-9a-f]{64}$').hasMatch(normalized)) {
    throw ArgumentError.value(
      value,
      field,
      'must be a sha256:<lower-hex> digest',
    );
  }
  return normalized;
}

String _domainTag(
  String value,
  String field, {
  required String expectedPrefix,
}) {
  final normalized = _required(value, field);
  final expectedPattern = RegExp('^${RegExp.escape(expectedPrefix)}-v[0-9]+\$');
  if (!expectedPattern.hasMatch(normalized)) {
    throw ArgumentError.value(
      value,
      field,
      'must use the $expectedPrefix-vN domain family',
    );
  }
  return normalized;
}
