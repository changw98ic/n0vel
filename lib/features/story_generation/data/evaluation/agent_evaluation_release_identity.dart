import 'agent_evaluation_manifest.dart';

/// Release identities derived from the source manifest and the complete signed
/// macOS application-bundle manifest. They are intentionally not caller-chosen
/// labels.
abstract final class AgentEvaluationDerivedReleaseIdentity {
  static const buildArtifactScheme = 'macos-app-bundle-manifest-v1';

  static String runtimeReleaseHash({
    required String sourceTreeHash,
    required String buildArtifactHash,
  }) {
    _requireInputs(sourceTreeHash, buildArtifactHash);
    return AgentEvaluationHashes.domainHash(
      'agent-evaluation-runtime-release-identity-v2',
      <String, Object?>{
        'sourceTreeHash': sourceTreeHash,
        'buildArtifactHash': buildArtifactHash,
        'buildArtifactScheme': buildArtifactScheme,
        'entrypoint': 'agent_evaluation_release_coordinator_runtime.dart',
        'runtime': 'single-prebuilt-macos-app-bundle-v2',
      },
    );
  }

  static String sdkAdapterReleaseHash({
    required String sourceTreeHash,
    required String buildArtifactHash,
    required String providerApiRevision,
  }) {
    _requireInputs(sourceTreeHash, buildArtifactHash);
    final revision = providerApiRevision.trim();
    if (revision.isEmpty) {
      throw ArgumentError('provider API revision is required');
    }
    return AgentEvaluationHashes.domainHash(
      'agent-evaluation-sdk-adapter-release-identity-v2',
      <String, Object?>{
        'sourceTreeHash': sourceTreeHash,
        'buildArtifactHash': buildArtifactHash,
        'buildArtifactScheme': buildArtifactScheme,
        'providerApiRevision': revision,
        'adapter': 'app-llm-io-client-factory-v1',
      },
    );
  }

  static String tokenizerReleaseHash({
    required String sourceTreeHash,
    required String buildArtifactHash,
  }) {
    _requireInputs(sourceTreeHash, buildArtifactHash);
    return AgentEvaluationHashes.domainHash(
      'agent-evaluation-tokenizer-release-identity-v2',
      <String, Object?>{
        'sourceTreeHash': sourceTreeHash,
        'buildArtifactHash': buildArtifactHash,
        'buildArtifactScheme': buildArtifactScheme,
        'policy': 'canonical-json-utf8-byte-upper-bound-plus-envelope-v1',
      },
    );
  }

  static void _requireInputs(String sourceTreeHash, String buildArtifactHash) {
    AgentEvaluationHashes.requireDigest(sourceTreeHash, 'sourceTreeHash');
    AgentEvaluationHashes.requireDigest(buildArtifactHash, 'buildArtifactHash');
  }
}
