import 'app_llm_canonical_hash.dart';

final class PromptReleaseRef {
  PromptReleaseRef({
    required String templateId,
    required String semanticVersion,
    required String language,
    required String contentHash,
  }) : templateId = _required(templateId, 'templateId'),
       semanticVersion = _required(semanticVersion, 'semanticVersion'),
       language = _required(language, 'language'),
       contentHash = _hash(contentHash, 'contentHash');

  final String templateId;
  final String semanticVersion;
  final String language;
  final String contentHash;

  Map<String, Object?> toJson() => {
    'templateId': templateId,
    'semanticVersion': semanticVersion,
    'language': language,
    'contentHash': contentHash,
  };

  @override
  bool operator ==(Object other) =>
      other is PromptReleaseRef &&
      AppLlmCanonicalHash.canonicalJson(toJson()) ==
          AppLlmCanonicalHash.canonicalJson(other.toJson());

  @override
  int get hashCode =>
      Object.hash(templateId, semanticVersion, language, contentHash);
}

final class PromptRelease {
  factory PromptRelease({
    required String templateId,
    required String semanticVersion,
    required String language,
    required String systemTemplate,
    required String userTemplate,
    required Object? variablesSchemaSnapshot,
    required Object? outputSchemaSnapshot,
    required String rendererRelease,
    required String parserRelease,
    required Object? repairPolicySnapshot,
    required String owner,
    required String changeNote,
    required DateTime createdAt,
    String? expectedContentHash,
  }) {
    final normalizedTemplateId = _required(templateId, 'templateId');
    final normalizedVersion = _required(semanticVersion, 'semanticVersion');
    final normalizedLanguage = _required(language, 'language');
    final normalizedSystem = AppLlmCanonicalHash.normalizeNfc(systemTemplate);
    final normalizedUser = AppLlmCanonicalHash.normalizeNfc(userTemplate);
    final variables = AppLlmCanonicalHash.immutableSnapshot(
      variablesSchemaSnapshot,
    );
    final output = AppLlmCanonicalHash.immutableSnapshot(outputSchemaSnapshot);
    final repair = AppLlmCanonicalHash.immutableSnapshot(repairPolicySnapshot);
    final normalizedRenderer = _required(rendererRelease, 'rendererRelease');
    final normalizedParser = _required(parserRelease, 'parserRelease');
    final hashInput = <String, Object?>{
      'templateId': normalizedTemplateId,
      'semanticVersion': normalizedVersion,
      'language': normalizedLanguage,
      'systemTemplate': normalizedSystem,
      'userTemplate': normalizedUser,
      'variablesSchemaSnapshot': variables,
      'outputSchemaSnapshot': output,
      'rendererRelease': normalizedRenderer,
      'parserRelease': normalizedParser,
      'repairPolicySnapshot': repair,
    };
    final contentHash = AppLlmCanonicalHash.domainHash(
      'prompt-release-v1',
      hashInput,
    );
    if (expectedContentHash != null && expectedContentHash != contentHash) {
      throw StateError(
        'PromptRelease content hash mismatch: expected $expectedContentHash, '
        'computed $contentHash',
      );
    }
    return PromptRelease._(
      templateId: normalizedTemplateId,
      semanticVersion: normalizedVersion,
      language: normalizedLanguage,
      contentHash: contentHash,
      systemTemplate: normalizedSystem,
      userTemplate: normalizedUser,
      variablesSchemaSnapshot: variables,
      outputSchemaSnapshot: output,
      rendererRelease: normalizedRenderer,
      parserRelease: normalizedParser,
      repairPolicySnapshot: repair,
      owner: _required(owner, 'owner'),
      changeNote: AppLlmCanonicalHash.normalizeNfc(changeNote),
      createdAt: createdAt.toUtc(),
    );
  }

  const PromptRelease._({
    required this.templateId,
    required this.semanticVersion,
    required this.language,
    required this.contentHash,
    required this.systemTemplate,
    required this.userTemplate,
    required this.variablesSchemaSnapshot,
    required this.outputSchemaSnapshot,
    required this.rendererRelease,
    required this.parserRelease,
    required this.repairPolicySnapshot,
    required this.owner,
    required this.changeNote,
    required this.createdAt,
  });

  final String templateId;
  final String semanticVersion;
  final String language;
  final String contentHash;
  final String systemTemplate;
  final String userTemplate;
  final Object? variablesSchemaSnapshot;
  final Object? outputSchemaSnapshot;
  final String rendererRelease;
  final String parserRelease;
  final Object? repairPolicySnapshot;
  final String owner;
  final String changeNote;
  final DateTime createdAt;

  PromptReleaseRef get ref => PromptReleaseRef(
    templateId: templateId,
    semanticVersion: semanticVersion,
    language: language,
    contentHash: contentHash,
  );

  bool get hasValidContentHash =>
      contentHash ==
      AppLlmCanonicalHash.domainHash('prompt-release-v1', _hashInput());

  Map<String, Object?> _hashInput() => {
    'templateId': templateId,
    'semanticVersion': semanticVersion,
    'language': language,
    'systemTemplate': systemTemplate,
    'userTemplate': userTemplate,
    'variablesSchemaSnapshot': variablesSchemaSnapshot,
    'outputSchemaSnapshot': outputSchemaSnapshot,
    'rendererRelease': rendererRelease,
    'parserRelease': parserRelease,
    'repairPolicySnapshot': repairPolicySnapshot,
  };
}

final class GenerationBundleBinding {
  GenerationBundleBinding({
    required String stageId,
    required String callSiteId,
    required String variantId,
    required this.promptReleaseRef,
  }) : stageId = _required(stageId, 'stageId'),
       callSiteId = _required(callSiteId, 'callSiteId'),
       variantId = _required(variantId, 'variantId');

  final String stageId;
  final String callSiteId;
  final String variantId;
  final PromptReleaseRef promptReleaseRef;

  String get callSiteKey => '$stageId\u0000$callSiteId\u0000$variantId';

  Map<String, Object?> toJson() => {
    'stageId': stageId,
    'callSiteId': callSiteId,
    'variantId': variantId,
    'promptReleaseRef': promptReleaseRef.toJson(),
  };
}

final class GenerationBundle {
  factory GenerationBundle({
    required String bundleId,
    required Iterable<GenerationBundleBinding> releases,
    String? expectedBundleHash,
  }) {
    final normalizedId = _required(bundleId, 'bundleId');
    final bindings = List<GenerationBundleBinding>.of(releases)
      ..sort((left, right) => left.callSiteKey.compareTo(right.callSiteKey));
    if (bindings.isEmpty) {
      throw ArgumentError.value(releases, 'releases', 'must not be empty');
    }
    final seen = <String>{};
    for (final binding in bindings) {
      if (!seen.add(binding.callSiteKey)) {
        throw ArgumentError(
          'duplicate generation call-site: ${binding.callSiteKey}',
        );
      }
    }
    final frozen = List<GenerationBundleBinding>.unmodifiable(bindings);
    final bundleHash = AppLlmCanonicalHash.domainHash('generation-bundle-v1', {
      'bundleId': normalizedId,
      'releases': [for (final binding in frozen) binding.toJson()],
    });
    if (expectedBundleHash != null && expectedBundleHash != bundleHash) {
      throw StateError('GenerationBundle hash mismatch');
    }
    return GenerationBundle._(normalizedId, frozen, bundleHash);
  }

  const GenerationBundle._(this.bundleId, this.releases, this.bundleHash);

  final String bundleId;
  final List<GenerationBundleBinding> releases;
  final String bundleHash;
}

final class EvaluationBundle {
  factory EvaluationBundle({
    required String evaluatorBundleId,
    required Iterable<String> deterministicVerifierReleases,
    required Iterable<PromptReleaseRef> judgePromptReleases,
    required Iterable<String> judgeModelRoutes,
    required String rubricReleaseHash,
    required String aggregatorReleaseHash,
    required String failureTaxonomyHash,
    required String blindingPolicyVersion,
    String? expectedEvaluatorBundleHash,
  }) {
    final id = _required(evaluatorBundleId, 'evaluatorBundleId');
    final verifiers = _sortedRequired(
      deterministicVerifierReleases,
      'deterministicVerifierReleases',
    );
    final prompts = List<PromptReleaseRef>.of(judgePromptReleases)
      ..sort(
        (left, right) => AppLlmCanonicalHash.canonicalJson(
          left.toJson(),
        ).compareTo(AppLlmCanonicalHash.canonicalJson(right.toJson())),
      );
    final models = _sortedRequired(judgeModelRoutes, 'judgeModelRoutes');
    final input = <String, Object?>{
      'evaluatorBundleId': id,
      'deterministicVerifierReleases': verifiers,
      'judgePromptReleases': [for (final prompt in prompts) prompt.toJson()],
      'judgeModelRoutes': models,
      'rubricReleaseHash': _hash(rubricReleaseHash, 'rubricReleaseHash'),
      'aggregatorReleaseHash': _hash(
        aggregatorReleaseHash,
        'aggregatorReleaseHash',
      ),
      'failureTaxonomyHash': _hash(failureTaxonomyHash, 'failureTaxonomyHash'),
      'blindingPolicyVersion': _required(
        blindingPolicyVersion,
        'blindingPolicyVersion',
      ),
    };
    final hash = AppLlmCanonicalHash.domainHash('evaluation-bundle-v1', input);
    if (expectedEvaluatorBundleHash != null &&
        expectedEvaluatorBundleHash != hash) {
      throw StateError('EvaluationBundle hash mismatch');
    }
    return EvaluationBundle._(
      evaluatorBundleId: id,
      deterministicVerifierReleases: List<String>.unmodifiable(verifiers),
      judgePromptReleases: List<PromptReleaseRef>.unmodifiable(prompts),
      judgeModelRoutes: List<String>.unmodifiable(models),
      rubricReleaseHash: input['rubricReleaseHash']! as String,
      aggregatorReleaseHash: input['aggregatorReleaseHash']! as String,
      failureTaxonomyHash: input['failureTaxonomyHash']! as String,
      blindingPolicyVersion: input['blindingPolicyVersion']! as String,
      evaluatorBundleHash: hash,
    );
  }

  const EvaluationBundle._({
    required this.evaluatorBundleId,
    required this.deterministicVerifierReleases,
    required this.judgePromptReleases,
    required this.judgeModelRoutes,
    required this.rubricReleaseHash,
    required this.aggregatorReleaseHash,
    required this.failureTaxonomyHash,
    required this.blindingPolicyVersion,
    required this.evaluatorBundleHash,
  });

  final String evaluatorBundleId;
  final List<String> deterministicVerifierReleases;
  final List<PromptReleaseRef> judgePromptReleases;
  final List<String> judgeModelRoutes;
  final String rubricReleaseHash;
  final String aggregatorReleaseHash;
  final String failureTaxonomyHash;
  final String blindingPolicyVersion;
  final String evaluatorBundleHash;
}

List<String> _sortedRequired(Iterable<String> values, String field) {
  final result = values.map((value) => _required(value, field)).toList()
    ..sort();
  if (result.isEmpty) {
    throw ArgumentError.value(values, field, 'must not be empty');
  }
  if (result.toSet().length != result.length) {
    throw ArgumentError.value(values, field, 'must not contain duplicates');
  }
  return result;
}

String _required(String value, String field) {
  final normalized = AppLlmCanonicalHash.normalizeNfc(value.trim());
  if (normalized.isEmpty) throw ArgumentError.value(value, field, 'required');
  return normalized;
}

String _hash(String value, String field) {
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
