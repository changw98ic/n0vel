/// Canonical, injective address for a generated scene draft.
///
/// The persisted draft key is `projectId::sceneId`.  Because the separator is
/// not escaped, allowing even one colon inside either component would make two
/// different `(projectId, sceneId)` pairs share one draft address at the join
/// boundary. Current writers must therefore reject such components instead of
/// trying to guess which pair an existing string represents.
abstract final class GenerationSceneScopeIdentity {
  static const String separator = '::';

  static bool hasCanonicalComponents({
    required String projectId,
    required String sceneId,
  }) {
    return projectId.isNotEmpty &&
        sceneId.isNotEmpty &&
        !projectId.contains(':') &&
        !sceneId.contains(':');
  }

  static String canonical({
    required String projectId,
    required String sceneId,
  }) {
    if (!hasCanonicalComponents(projectId: projectId, sceneId: sceneId)) {
      throw const FormatException(
        'generation scene-scope components are empty or ambiguous',
      );
    }
    return '$projectId$separator$sceneId';
  }

  static bool matches({
    required String projectId,
    required String sceneId,
    required String sceneScopeId,
  }) {
    return hasCanonicalComponents(projectId: projectId, sceneId: sceneId) &&
        sceneScopeId == canonical(projectId: projectId, sceneId: sceneId);
  }
}
