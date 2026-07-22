import 'app_llm_canonical_hash.dart';
import 'app_llm_client_types.dart';
import 'app_llm_prompt_invocation.dart';
import 'app_llm_prompt_release.dart';
import 'app_product_prompt_registry.dart';

enum AppLlmCallSiteDisposition {
  registeredPrompt,
  operationalAllowlist,
  infrastructureBoundary,
}

abstract final class AppLlmCallSiteIds {
  static const workbenchRewrite = 'prompt.workbench.rewrite.zh';
  static const workbenchContinue = 'prompt.workbench.continue.zh';
  static const simulationRealAgentTurn = 'prompt.simulation.real-agent-turn.zh';
  static const settingsConnectionProbe =
      'operational.settings.connection-probe';
}

final class AppLlmCallSiteInventoryEntry {
  const AppLlmCallSiteInventoryEntry({
    required this.id,
    required this.sourcePath,
    required this.disposition,
    required this.reason,
    this.stageId,
    this.callSiteId,
    this.variantId,
    this.templateId,
    this.semanticVersion,
    this.releaseContentHash,
    this.generationBundleHashes,
  });

  final String id;
  final String sourcePath;
  final AppLlmCallSiteDisposition disposition;
  final String reason;
  final String? stageId;
  final String? callSiteId;
  final String? variantId;
  final String? templateId;
  final String? semanticVersion;
  final String? releaseContentHash;
  final List<String>? generationBundleHashes;

  String? get semanticCallSiteKey =>
      stageId == null || callSiteId == null || variantId == null
      ? null
      : '$stageId\u0000$callSiteId\u0000$variantId';

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'sourcePath': sourcePath,
    'disposition': disposition.name,
    'reason': reason,
    if (stageId != null) 'stageId': stageId,
    if (callSiteId != null) 'callSiteId': callSiteId,
    if (variantId != null) 'variantId': variantId,
    if (templateId != null) 'templateId': templateId,
    if (semanticVersion != null) 'semanticVersion': semanticVersion,
    if (releaseContentHash != null) 'releaseContentHash': releaseContentHash,
    if (generationBundleHashes != null)
      'generationBundleHashes': generationBundleHashes,
  };
}

final class AppLlmCallSiteInventory {
  AppLlmCallSiteInventory._(Iterable<AppLlmCallSiteInventoryEntry> entries)
    : entries = List<AppLlmCallSiteInventoryEntry>.unmodifiable(
        List<AppLlmCallSiteInventoryEntry>.of(entries)
          ..sort((left, right) => left.id.compareTo(right.id)),
      ) {
    final ids = <String>{};
    final promptMemberships = <String>{};
    for (final entry in this.entries) {
      if (!ids.add(entry.id) ||
          entry.id.trim() != entry.id ||
          entry.reason.trim().isEmpty ||
          entry.sourcePath.trim().isEmpty) {
        throw StateError(
          'invalid or duplicate LLM inventory entry: ${entry.id}',
        );
      }
      final key = entry.semanticCallSiteKey;
      if (entry.disposition == AppLlmCallSiteDisposition.registeredPrompt) {
        if (key == null ||
            entry.templateId?.trim().isEmpty != false ||
            entry.semanticVersion?.trim().isEmpty != false ||
            !RegExp(
              r'^sha256:[0-9a-f]{64}$',
            ).hasMatch(entry.releaseContentHash ?? '') ||
            entry.generationBundleHashes == null ||
            entry.generationBundleHashes!.isEmpty ||
            entry.generationBundleHashes!.toSet().length !=
                entry.generationBundleHashes!.length ||
            entry.generationBundleHashes!.any(
              (hash) => !RegExp(r'^sha256:[0-9a-f]{64}$').hasMatch(hash),
            )) {
          throw StateError(
            'registered prompt inventory is incomplete: ${entry.id}',
          );
        }
        final membership = <Object?>[
          key,
          entry.templateId,
          entry.semanticVersion,
          entry.releaseContentHash,
          ...entry.generationBundleHashes!,
        ].join('\u0000');
        if (!promptMemberships.add(membership)) {
          throw StateError('duplicate registered LLM prompt membership: $key');
        }
      } else if (key != null ||
          entry.templateId != null ||
          entry.semanticVersion != null ||
          entry.releaseContentHash != null ||
          entry.generationBundleHashes != null) {
        throw StateError('non-prompt inventory must not claim prompt identity');
      }
    }
  }

  static final AppLlmCallSiteInventory current = AppLlmCallSiteInventory._(
    _entries,
  );

  static const String expectedContentHash =
      'sha256:8eb9babf0ca56cb650a328c19b255b87f6668ae563c552ed35095c8113f59d86';

  final List<AppLlmCallSiteInventoryEntry> entries;

  Map<String, Object?> toJson() => <String, Object?>{
    'contract': 'whole-lib-llm-call-site-inventory-v1',
    'entries': <Object?>[for (final entry in entries) entry.toJson()],
  };

  String get contentHash =>
      AppLlmCanonicalHash.domainHash('llm-call-site-inventory-v1', toJson());

  bool get hasValidContentHash => contentHash == expectedContentHash;

  AppLlmCallSiteInventoryEntry requireRegisteredPrompt({
    required String stageId,
    required String callSiteId,
    required String variantId,
    required PromptReleaseRef releaseRef,
    required String generationBundleHash,
  }) {
    _requireSealed();
    final key = '$stageId\u0000$callSiteId\u0000$variantId';
    final matches = entries.where(
      (entry) =>
          entry.disposition == AppLlmCallSiteDisposition.registeredPrompt &&
          entry.semanticCallSiteKey == key &&
          entry.templateId == releaseRef.templateId &&
          entry.semanticVersion == releaseRef.semanticVersion &&
          entry.releaseContentHash == releaseRef.contentHash &&
          entry.generationBundleHashes!.contains(generationBundleHash),
    );
    if (matches.length != 1) {
      throw StateError('unregistered production LLM prompt call-site: $key');
    }
    return matches.single;
  }

  AppLlmCallSiteInventoryEntry requireOperationalAllowlist(String id) {
    _requireSealed();
    final matches = entries.where(
      (entry) =>
          entry.id == id &&
          entry.disposition == AppLlmCallSiteDisposition.operationalAllowlist,
    );
    if (matches.length != 1) {
      throw StateError('unknown operational LLM allowlist entry: $id');
    }
    return matches.single;
  }

  void _requireSealed() {
    if (!hasValidContentHash) {
      throw StateError('LLM call-site inventory seal mismatch');
    }
  }
}

sealed class AppLlmCallSiteAuthority {
  const AppLlmCallSiteAuthority(this.entry);

  factory AppLlmCallSiteAuthority.registeredPrompt({
    required PromptReleaseRef? promptReleaseRef,
    required PromptInvocationEvidence? promptInvocationEvidence,
    required String? stageId,
    required String? callSiteId,
    required String? variantId,
    required String? generationBundleHash,
  }) {
    if (promptReleaseRef == null ||
        promptInvocationEvidence == null ||
        stageId == null ||
        callSiteId == null ||
        variantId == null ||
        generationBundleHash == null ||
        !RegExp(r'^sha256:[0-9a-f]{64}$').hasMatch(generationBundleHash)) {
      throw StateError(
        'production LLM dispatch requires complete registered prompt authority',
      );
    }
    if (promptInvocationEvidence.promptReleaseRef != promptReleaseRef ||
        promptInvocationEvidence.release.ref != promptReleaseRef) {
      throw StateError(
        'production prompt authority contains conflicting release',
      );
    }
    final entry = AppLlmCallSiteInventory.current.requireRegisteredPrompt(
      stageId: stageId,
      callSiteId: callSiteId,
      variantId: variantId,
      releaseRef: promptReleaseRef,
      generationBundleHash: generationBundleHash,
    );
    return AppLlmRegisteredPromptAuthority._(
      entry: entry,
      evidence: promptInvocationEvidence,
      generationBundleHash: generationBundleHash,
    );
  }

  factory AppLlmCallSiteAuthority.operational(String id) =>
      AppLlmOperationalCallSiteAuthority._(
        AppLlmCallSiteInventory.current.requireOperationalAllowlist(id),
      );

  final AppLlmCallSiteInventoryEntry entry;

  void validateMessages(Iterable<AppLlmChatMessage> messages);
}

final class AppLlmRegisteredPromptAuthority extends AppLlmCallSiteAuthority {
  const AppLlmRegisteredPromptAuthority._({
    required AppLlmCallSiteInventoryEntry entry,
    required this.evidence,
    required this.generationBundleHash,
  }) : super(entry);

  final PromptInvocationEvidence evidence;
  final String generationBundleHash;

  @override
  void validateMessages(Iterable<AppLlmChatMessage> messages) {
    if (!evidence.matchesMessages(messages) ||
        !evidence.release.hasValidContentHash) {
      throw StateError('registered prompt authority does not match dispatch');
    }
  }
}

final class AppLlmOperationalCallSiteAuthority extends AppLlmCallSiteAuthority {
  const AppLlmOperationalCallSiteAuthority._(super.entry);

  @override
  void validateMessages(Iterable<AppLlmChatMessage> messages) {
    if (messages.isEmpty) {
      throw StateError('operational LLM probe must send a bounded request');
    }
  }
}

AppLlmCallSiteInventoryEntry _storyPrompt(
  String stageId,
  String callSiteId,
  String templateId, {
  String? idSuffix,
  String? semanticVersion,
  String? releaseContentHash,
  List<String>? generationBundleHashes,
  String sourcePath =
      'lib/features/story_generation/data/story_prompt_registry.dart',
  String reason = 'Production story-generation prompt release.',
}) {
  final identity = _storyReleaseIdentities['$stageId\u0000$callSiteId'];
  if (identity == null) {
    throw StateError('missing frozen story prompt identity');
  }
  return AppLlmCallSiteInventoryEntry(
    id: 'prompt.story.$stageId.$callSiteId.zh${idSuffix ?? ''}',
    sourcePath: sourcePath,
    disposition: AppLlmCallSiteDisposition.registeredPrompt,
    reason: reason,
    stageId: stageId,
    callSiteId: callSiteId,
    variantId: 'zh',
    templateId: templateId,
    semanticVersion: semanticVersion ?? identity.semanticVersion,
    releaseContentHash: releaseContentHash ?? identity.contentHash,
    generationBundleHashes:
        generationBundleHashes ??
        (stageId == 'editorial' && callSiteId == 'scene-editorial-generator'
            ? const <String>[_storyChampionBundleHash]
            : const <String>[
                _storyChampionBundleHash,
                _storyCausalityChallengerBundleHash,
              ]),
  );
}

AppLlmCallSiteInventoryEntry _productPrompt(
  String id,
  String stageId,
  String callSiteId,
  String sourcePath,
  String reason,
) {
  final registration = AppProductPromptRegistry.current.registrations
      .singleWhere(
        (item) =>
            item.stageId == stageId &&
            item.callSiteId == callSiteId &&
            item.variantId == 'zh',
      );
  return AppLlmCallSiteInventoryEntry(
    id: id,
    sourcePath: sourcePath,
    disposition: AppLlmCallSiteDisposition.registeredPrompt,
    reason: reason,
    stageId: stageId,
    callSiteId: callSiteId,
    variantId: 'zh',
    templateId: registration.release.templateId,
    semanticVersion: registration.release.semanticVersion,
    releaseContentHash: registration.release.contentHash,
    generationBundleHashes: <String>[
      AppProductPromptRegistry.current.generationBundle.bundleHash,
    ],
  );
}

const List<AppLlmCallSiteInventoryEntry>
_boundaryEntries = <AppLlmCallSiteInventoryEntry>[
  AppLlmCallSiteInventoryEntry(
    id: 'boundary.gateway.primary',
    sourcePath: 'lib/app/llm/app_llm_client_gateway.dart',
    disposition: AppLlmCallSiteDisposition.infrastructureBoundary,
    reason: 'Gateway delegates an already-authorized request.',
  ),
  AppLlmCallSiteInventoryEntry(
    id: 'boundary.gateway.stream',
    sourcePath: 'lib/app/llm/app_llm_client_gateway.dart',
    disposition: AppLlmCallSiteDisposition.infrastructureBoundary,
    reason: 'Gateway delegates an already-authorized streaming request.',
  ),
  AppLlmCallSiteInventoryEntry(
    id: 'boundary.gateway.health-probe',
    sourcePath: 'lib/app/llm/app_llm_client_gateway.dart',
    disposition: AppLlmCallSiteDisposition.infrastructureBoundary,
    reason: 'Circuit-breaker health probe reuses the authorized request route.',
  ),
  AppLlmCallSiteInventoryEntry(
    id: 'boundary.failover.direct',
    sourcePath: 'lib/app/llm/app_llm_failover_chain.dart',
    disposition: AppLlmCallSiteDisposition.infrastructureBoundary,
    reason:
        'Failover dispatches an already-authorized request to one endpoint.',
  ),
  AppLlmCallSiteInventoryEntry(
    id: 'boundary.logging.delegate',
    sourcePath: 'lib/app/llm/app_llm_logging_middleware.dart',
    disposition: AppLlmCallSiteDisposition.infrastructureBoundary,
    reason: 'Logging middleware observes and delegates an authorized request.',
  ),
  AppLlmCallSiteInventoryEntry(
    id: 'boundary.logging.stream-delegate',
    sourcePath: 'lib/app/llm/app_llm_logging_middleware.dart',
    disposition: AppLlmCallSiteDisposition.infrastructureBoundary,
    reason: 'Logging middleware observes and delegates a streaming request.',
  ),
  AppLlmCallSiteInventoryEntry(
    id: 'boundary.schema.passthrough',
    sourcePath: 'lib/app/llm/app_llm_output_schema.dart',
    disposition: AppLlmCallSiteDisposition.infrastructureBoundary,
    reason:
        'Schema wrapper passthrough for a request without an output schema.',
  ),
  AppLlmCallSiteInventoryEntry(
    id: 'boundary.schema.initial',
    sourcePath: 'lib/app/llm/app_llm_output_schema.dart',
    disposition: AppLlmCallSiteDisposition.infrastructureBoundary,
    reason: 'Schema wrapper initial authorized provider attempt.',
  ),
  AppLlmCallSiteInventoryEntry(
    id: 'boundary.schema.repair',
    sourcePath: 'lib/app/llm/app_llm_output_schema.dart',
    disposition: AppLlmCallSiteDisposition.infrastructureBoundary,
    reason:
        'Bounded output-schema repair attempt derived from the same request.',
  ),
  AppLlmCallSiteInventoryEntry(
    id: 'boundary.schema.interface',
    sourcePath: 'lib/app/llm/app_llm_output_schema.dart',
    disposition: AppLlmCallSiteDisposition.infrastructureBoundary,
    reason: 'AppLlmClient interface passthrough preserves upstream authority.',
  ),
  AppLlmCallSiteInventoryEntry(
    id: 'boundary.schema.stream-interface',
    sourcePath: 'lib/app/llm/app_llm_output_schema.dart',
    disposition: AppLlmCallSiteDisposition.infrastructureBoundary,
    reason: 'Schema client streaming interface preserves upstream authority.',
  ),
  AppLlmCallSiteInventoryEntry(
    id: 'boundary.cache.miss',
    sourcePath: 'lib/app/llm/app_llm_response_cache.dart',
    disposition: AppLlmCallSiteDisposition.infrastructureBoundary,
    reason: 'Cache miss delegates the original authorized request.',
  ),
  AppLlmCallSiteInventoryEntry(
    id: 'boundary.cache.stream-miss',
    sourcePath: 'lib/app/llm/app_llm_response_cache.dart',
    disposition: AppLlmCallSiteDisposition.infrastructureBoundary,
    reason: 'Streaming cache miss delegates the original request.',
  ),
  AppLlmCallSiteInventoryEntry(
    id: 'boundary.provider.io-chat-http',
    sourcePath: 'lib/app/llm/app_llm_client_io.dart',
    disposition: AppLlmCallSiteDisposition.infrastructureBoundary,
    reason:
        'Primary provider implementation sends the authorized chat HTTP request.',
  ),
  AppLlmCallSiteInventoryEntry(
    id: 'boundary.provider.io-stream-http',
    sourcePath: 'lib/app/llm/app_llm_client_io.dart',
    disposition: AppLlmCallSiteDisposition.infrastructureBoundary,
    reason:
        'Primary provider implementation sends the authorized streaming HTTP request.',
  ),
  AppLlmCallSiteInventoryEntry(
    id: 'boundary.provider.io-formal-admission',
    sourcePath: 'lib/app/llm/app_llm_client_io.dart',
    disposition: AppLlmCallSiteDisposition.infrastructureBoundary,
    reason:
        'Private formal admission delegates its exact permitted request to the concrete IO transport.',
  ),
  AppLlmCallSiteInventoryEntry(
    id: 'boundary.provider.legacy-gateway-http',
    sourcePath: 'lib/app/llm/llm_gateway.dart',
    disposition: AppLlmCallSiteDisposition.infrastructureBoundary,
    reason:
        'Legacy gateway provider implementation sends an authorized chat request.',
  ),
  AppLlmCallSiteInventoryEntry(
    id: 'boundary.ai-request.primary',
    sourcePath: 'lib/app/state/ai_request_service.dart',
    disposition: AppLlmCallSiteDisposition.infrastructureBoundary,
    reason: 'Central product dispatch after typed authority validation.',
  ),
  AppLlmCallSiteInventoryEntry(
    id: 'boundary.settings.connection-probe',
    sourcePath: 'lib/app/state/ai_request_service.dart',
    disposition: AppLlmCallSiteDisposition.infrastructureBoundary,
    reason: 'Explicit bounded operational connection probe.',
  ),
  AppLlmCallSiteInventoryEntry(
    id: 'boundary.settings.central-request',
    sourcePath: 'lib/app/state/app_settings_store_ai_routing.dart',
    disposition: AppLlmCallSiteDisposition.infrastructureBoundary,
    reason:
        'Settings routing enters central dispatch with typed prompt authority.',
  ),
  AppLlmCallSiteInventoryEntry(
    id: 'boundary.simulation.product-request',
    sourcePath: 'lib/app/state/simulation_real_agent_runner.dart',
    disposition: AppLlmCallSiteDisposition.infrastructureBoundary,
    reason: 'User-facing real-agent simulation prompt dispatch.',
  ),
  AppLlmCallSiteInventoryEntry(
    id: 'boundary.evaluation.max-token',
    sourcePath:
        'lib/features/story_generation/data/evaluation/agent_evaluation_app_runtime.dart',
    disposition: AppLlmCallSiteDisposition.infrastructureBoundary,
    reason: 'Evaluation token-cap decorator delegates a metered request.',
  ),
  AppLlmCallSiteInventoryEntry(
    id: 'boundary.evaluation.sut-meter',
    sourcePath:
        'lib/features/story_generation/data/evaluation/agent_evaluation_metered_client.dart',
    disposition: AppLlmCallSiteDisposition.infrastructureBoundary,
    reason:
        'Formal SUT meter crosses the provider boundary after budget checks.',
  ),
  AppLlmCallSiteInventoryEntry(
    id: 'boundary.evaluation.non-release-canary-single-dispatch',
    sourcePath:
        'lib/features/story_generation/data/evaluation/agent_evaluation_non_release_canary_client.dart',
    disposition: AppLlmCallSiteDisposition.infrastructureBoundary,
    reason:
        'Non-release canary client dispatches one bounded request under its local budget.',
  ),
  AppLlmCallSiteInventoryEntry(
    id: 'boundary.evaluation.independent-judge',
    sourcePath:
        'lib/features/story_generation/data/evaluation/agent_evaluation_production_authorities.dart',
    disposition: AppLlmCallSiteDisposition.infrastructureBoundary,
    reason: 'Frozen independent judge prompt provider dispatch.',
  ),
  AppLlmCallSiteInventoryEntry(
    id: 'boundary.evaluation.judge-budget',
    sourcePath:
        'lib/features/story_generation/data/evaluation/agent_evaluation_real_release_harness.dart',
    disposition: AppLlmCallSiteDisposition.infrastructureBoundary,
    reason: 'Release judge dispatch after evaluator budget reservation.',
  ),
  AppLlmCallSiteInventoryEntry(
    id: 'boundary.evaluation.case11.failover',
    sourcePath:
        'lib/features/story_generation/data/evaluation/agent_adversarial_production_cases.dart',
    disposition: AppLlmCallSiteDisposition.infrastructureBoundary,
    reason: 'Case 11 exercises the metered failover boundary.',
  ),
  AppLlmCallSiteInventoryEntry(
    id: 'boundary.evaluation.case11.first-duplicate',
    sourcePath:
        'lib/features/story_generation/data/evaluation/agent_adversarial_production_cases.dart',
    disposition: AppLlmCallSiteDisposition.infrastructureBoundary,
    reason: 'Case 11 records the first duplicate-response probe.',
  ),
  AppLlmCallSiteInventoryEntry(
    id: 'boundary.evaluation.case11.primary-classification',
    sourcePath:
        'lib/features/story_generation/data/evaluation/agent_adversarial_production_cases.dart',
    disposition: AppLlmCallSiteDisposition.infrastructureBoundary,
    reason: 'Case 11 classifies bounded primary-provider failures.',
  ),
  AppLlmCallSiteInventoryEntry(
    id: 'boundary.evaluation.case11.primary-success',
    sourcePath:
        'lib/features/story_generation/data/evaluation/agent_adversarial_production_cases.dart',
    disposition: AppLlmCallSiteDisposition.infrastructureBoundary,
    reason: 'Case 11 exercises the successful primary-provider path.',
  ),
  AppLlmCallSiteInventoryEntry(
    id: 'boundary.evaluation.case11.repeated-duplicate',
    sourcePath:
        'lib/features/story_generation/data/evaluation/agent_adversarial_production_cases.dart',
    disposition: AppLlmCallSiteDisposition.infrastructureBoundary,
    reason: 'Case 11 repeats the duplicate-response probe.',
  ),
  AppLlmCallSiteInventoryEntry(
    id: 'boundary.evaluation.case11.replacement-denial',
    sourcePath:
        'lib/features/story_generation/data/evaluation/agent_adversarial_production_cases.dart',
    disposition: AppLlmCallSiteDisposition.infrastructureBoundary,
    reason: 'Case 11 verifies that a spent attempt cannot be replaced.',
  ),
  AppLlmCallSiteInventoryEntry(
    id: 'boundary.evaluation.case16.sut-probe',
    sourcePath:
        'lib/features/story_generation/data/evaluation/agent_adversarial_production_cases.dart',
    disposition: AppLlmCallSiteDisposition.infrastructureBoundary,
    reason: 'Case 16 sends the bounded SUT response-cache probe.',
  ),
  AppLlmCallSiteInventoryEntry(
    id: 'boundary.evaluation.case17.cache-loop',
    sourcePath:
        'lib/features/story_generation/data/evaluation/agent_adversarial_production_cases.dart',
    disposition: AppLlmCallSiteDisposition.infrastructureBoundary,
    reason: 'Case 17 exercises immutable cache-provenance receipts.',
  ),
  AppLlmCallSiteInventoryEntry(
    id: 'boundary.evaluation.case18.parallel-budget',
    sourcePath:
        'lib/features/story_generation/data/evaluation/agent_adversarial_production_cases.dart',
    disposition: AppLlmCallSiteDisposition.infrastructureBoundary,
    reason: 'Case 18 races bounded requests against one shared budget.',
  ),
  AppLlmCallSiteInventoryEntry(
    id: 'boundary.evaluation.case18.replacement-denial',
    sourcePath:
        'lib/features/story_generation/data/evaluation/agent_adversarial_production_cases.dart',
    disposition: AppLlmCallSiteDisposition.infrastructureBoundary,
    reason: 'Case 18 verifies exhausted parallel budget replacement denial.',
  ),
  AppLlmCallSiteInventoryEntry(
    id: 'boundary.evaluation.case22.sut-probe',
    sourcePath:
        'lib/features/story_generation/data/evaluation/agent_adversarial_production_cases.dart',
    disposition: AppLlmCallSiteDisposition.infrastructureBoundary,
    reason: 'Case 22 sends the bounded pricing-drift SUT probe.',
  ),
  AppLlmCallSiteInventoryEntry(
    id: 'boundary.story.retry-dispatch',
    sourcePath:
        'lib/features/story_generation/data/story_generation_pass_retry.dart',
    disposition: AppLlmCallSiteDisposition.infrastructureBoundary,
    reason: 'Central versioned story-generation request and retry boundary.',
  ),
  AppLlmCallSiteInventoryEntry(
    id: 'boundary.workbench.product-request',
    sourcePath: 'lib/features/workbench/data/workbench_ai_controller.dart',
    disposition: AppLlmCallSiteDisposition.infrastructureBoundary,
    reason: 'User-facing workbench rewrite or continuation request.',
  ),
];

final List<AppLlmCallSiteInventoryEntry>
_entries = <AppLlmCallSiteInventoryEntry>[
  _storyPrompt('director', 'scene-director', 'scene_director'),
  _storyPrompt('editorial', 'scene-editor', 'scene_editor'),
  _storyPrompt(
    'editorial',
    'scene-editorial-generator',
    'scene_editorial_generator',
  ),
  _storyPrompt(
    'editorial',
    'scene-editorial-generator',
    'scene_editorial_generator',
    idSuffix: '.causality-challenger',
    semanticVersion: '1.2.0-causality-challenger',
    releaseContentHash:
        'sha256:4d015ce94cd3f01bc76d6b9d52017f26bbadcc4b2f353eb65e17aad6228a9abc',
    generationBundleHashes: const <String>[_storyCausalityChallengerBundleHash],
  ),
  _storyPrompt('review', 'judge', 'scene_review_judge'),
  _storyPrompt('review', 'consistency', 'scene_review_consistency'),
  _storyPrompt(
    'review',
    'format-repair-judge',
    'scene_review_format_repair_judge',
  ),
  _storyPrompt('quality-gate', 'quality-scorer', 'scene_quality'),
  _storyPrompt(
    'literary-quality',
    'scene-evaluator',
    'scene_literary_quality_evaluation',
    generationBundleHashes: const <String>[_storyLiteraryEvaluationBundleHash],
    sourcePath:
        'lib/features/story_generation/data/scene_literary_quality_evaluator.dart',
    reason: 'Independent closed-schema literary-quality evaluator release.',
  ),
  _storyPrompt('roleplay', 'role-agent-controller', 'role_agent_controller'),
  _storyPrompt('roleplay', 'role-turn', 'role_turn'),
  _storyPrompt('beat-resolution', 'beat-resolver', 'scene_beat_resolve'),
  _storyPrompt('stage-narration', 'stage-narrator', 'scene_stage_narration'),
  _storyPrompt('polish', 'language-polish', 'scene_language_polish'),
  _storyPrompt('roleplay', 'arbiter', 'scene_roleplay_arbiter'),
  _storyPrompt('chapter-summary', 'chapter-summarizer', 'chapter_summary'),
  _storyPrompt('review', 'character-consistency', 'character_consistency'),
  _storyPrompt('prose', 'scene-prose', 'scene_prose'),
  _storyPrompt('review', 'reader-flow', 'scene_review_reader_flow'),
  _storyPrompt('review', 'lexicon', 'scene_review_lexicon'),
  _storyPrompt('review', 'adjudication', 'scene_review_adjudication'),
  _storyPrompt(
    'review',
    'format-repair-consistency',
    'scene_review_format_repair_consistency',
  ),
  _storyPrompt(
    'review',
    'format-repair-reader-flow',
    'scene_review_format_repair_reader_flow',
  ),
  _storyPrompt(
    'review',
    'format-repair-lexicon',
    'scene_review_format_repair_lexicon',
  ),
  _storyPrompt(
    'review',
    'format-repair-adjudication',
    'scene_review_format_repair_adjudication',
  ),
  _productPrompt(
    AppLlmCallSiteIds.workbenchRewrite,
    'workbench',
    'rewrite',
    'lib/features/workbench/data/workbench_ai_controller.dart',
    'User-facing workbench rewrite prompt release.',
  ),
  _productPrompt(
    AppLlmCallSiteIds.workbenchContinue,
    'workbench',
    'continue',
    'lib/features/workbench/data/workbench_ai_controller.dart',
    'User-facing workbench continuation prompt release.',
  ),
  _productPrompt(
    AppLlmCallSiteIds.simulationRealAgentTurn,
    'simulation',
    'real-agent-turn',
    'lib/app/state/simulation_real_agent_runner.dart',
    'User-facing real multi-agent simulation turn prompt release.',
  ),
  const AppLlmCallSiteInventoryEntry(
    id: AppLlmCallSiteIds.settingsConnectionProbe,
    sourcePath: 'lib/app/state/ai_request_service.dart',
    disposition: AppLlmCallSiteDisposition.operationalAllowlist,
    reason:
        'User-initiated bounded connectivity probe; it tests transport and '
        'does not produce product content or formal evaluation evidence.',
  ),
  ..._boundaryEntries,
];

const String _storyChampionBundleHash =
    'sha256:9b21c650a5e4227fec3f30673d4c7381f06b33c30c593cdac1eb0a2fbeb2674f';
const String _storyCausalityChallengerBundleHash =
    'sha256:4e48de41b71e2a1a228a1b6786d85ed59507fa57bd16579320f120cbb1c1ce60';
const String _storyLiteraryEvaluationBundleHash =
    'sha256:d7ad5efa0012d394bf4d55ff010489189b9e3bbf316bafae366b8a71ff391aed';

const Map<String, ({String semanticVersion, String contentHash})>
_storyReleaseIdentities = <String, ({String semanticVersion, String contentHash})>{
  'director\u0000scene-director': (
    semanticVersion: '2.0.0-renderer-replay',
    contentHash:
        'sha256:bcd85caadd8e4814874adddfa32ca2047ce2de7a741282c4fdbda235822d996c',
  ),
  'editorial\u0000scene-editor': (
    semanticVersion: '2.0.0-renderer-replay',
    contentHash:
        'sha256:4b47ec8e9bb03dee8f7dbefe5db124034f6639719574dcd5322e9bde9af6b085',
  ),
  'editorial\u0000scene-editorial-generator': (
    semanticVersion: '2.0.0-renderer-replay',
    contentHash:
        'sha256:5ed38e400cebb1857422b215fabfecb34a13413134d68b954525dde5d5ed5758',
  ),
  'review\u0000judge': (
    semanticVersion: '2.0.0-renderer-replay',
    contentHash:
        'sha256:bfbc469837898ba4160e2c552d4a1fddad558d9120dee7fae907b20cc705c232',
  ),
  'review\u0000consistency': (
    semanticVersion: '2.0.0-renderer-replay',
    contentHash:
        'sha256:b3a358e614e7c808be816324854661e6a0d1604d5e94072986323fbde1ac1cd6',
  ),
  'review\u0000format-repair-judge': (
    semanticVersion: '2.0.0-renderer-replay',
    contentHash:
        'sha256:2eee41ba46b1d50b7341824bf3a437de2abf472352216115b6a0d496e8056990',
  ),
  'quality-gate\u0000quality-scorer': (
    semanticVersion: '2.1.1-extended-quality-rubric-strict-format',
    contentHash:
        'sha256:99b3e8e57e7dcb10bdc65520d05edab08b6b8a2fe2849848ec2dfa452f5c6398',
  ),
  'literary-quality\u0000scene-evaluator': (
    semanticVersion: '1.2.0',
    contentHash:
        'sha256:a2e69dc47a58fe1bf3b49ee65266c690ce4cbfbbbb87092e3326dcb52fcb16d1',
  ),
  'roleplay\u0000role-agent-controller': (
    semanticVersion: '2.0.0-renderer-replay',
    contentHash:
        'sha256:852d81988643e0865eef34e8369010a33e5cf0a834ded5612965c012acc3bf50',
  ),
  'roleplay\u0000role-turn': (
    semanticVersion: '2.1.0-exact-structured-output',
    contentHash:
        'sha256:8104092f9c779fb9f65d28b77aba966db0ca75519b56f6a1b2e9ac4ef4bc0b26',
  ),
  'beat-resolution\u0000beat-resolver': (
    semanticVersion: '2.0.0-renderer-replay',
    contentHash:
        'sha256:91a68fec86ae505577c583e3267d6dff9a463e83f2aae2427352aaca25d2aaf7',
  ),
  'stage-narration\u0000stage-narrator': (
    semanticVersion: '2.1.0-exact-structured-output',
    contentHash:
        'sha256:3e9f24e83cb4aba823c640c03ad33cf13dee3c8710b7f48a850379f5c5eecd6a',
  ),
  'polish\u0000language-polish': (
    semanticVersion: '2.0.0-renderer-replay',
    contentHash:
        'sha256:7cbcbf274c4c5bae6d322aa9aba1a4985bbc6d48676f42e3f9104af6b6829493',
  ),
  'roleplay\u0000arbiter': (
    semanticVersion: '2.1.0-exact-structured-output',
    contentHash:
        'sha256:8760ee1336caf7a74c65d8d4e50ea2b5f4e5147f482758b66e256bf97f4204b4',
  ),
  'chapter-summary\u0000chapter-summarizer': (
    semanticVersion: '2.0.0-renderer-replay',
    contentHash:
        'sha256:661551e9d3ac71fa824255f7f0d8a86d3bff1092473c92ec47bf3354668e00fb',
  ),
  'review\u0000character-consistency': (
    semanticVersion: '2.0.0-renderer-replay',
    contentHash:
        'sha256:5d8469af9972cf64d8c93ed12b209997face3b21bd4d6a3c971e3417ad3def4e',
  ),
  'prose\u0000scene-prose': (
    semanticVersion: '2.0.0-renderer-replay',
    contentHash:
        'sha256:705806442999fa273615e813741016d794a0a4f0815c208052702efb8e9aed9e',
  ),
  'review\u0000reader-flow': (
    semanticVersion: '2.0.0-renderer-replay',
    contentHash:
        'sha256:b1f2f8882d7e56bcf9b012f19c80d207f292588a71192e60d65ea1609aaa9093',
  ),
  'review\u0000lexicon': (
    semanticVersion: '2.0.0-renderer-replay',
    contentHash:
        'sha256:d8fdb61671ffa0da4059b807528f18678ba0d9f94b82ae0618f3a02431e3168d',
  ),
  'review\u0000adjudication': (
    semanticVersion: '2.0.0-renderer-replay',
    contentHash:
        'sha256:37097386f50a38b94d85ef779c622a3deb80f79d6566b6db8b712da00f2f2f60',
  ),
  'review\u0000format-repair-consistency': (
    semanticVersion: '2.0.0-renderer-replay',
    contentHash:
        'sha256:0c3bc72884ccf856470bb73d82a0ebb4af3cc3f6139ad61121f1b2ccaa95771f',
  ),
  'review\u0000format-repair-reader-flow': (
    semanticVersion: '2.0.0-renderer-replay',
    contentHash:
        'sha256:7137830bddb9f9e6fbf16fee619740420f1fa6739520553f02ff9934b9a49100',
  ),
  'review\u0000format-repair-lexicon': (
    semanticVersion: '2.0.0-renderer-replay',
    contentHash:
        'sha256:5aa5989a8b8b1449b6957f8fd33a9bde3d77a2cc3eae8e5e624a54f65b9cf94c',
  ),
  'review\u0000format-repair-adjudication': (
    semanticVersion: '2.0.0-renderer-replay',
    contentHash:
        'sha256:7c8e5e216f273bf432ab4589fa2d508e3db1085fb852fe394c2487df9709748f',
  ),
};
