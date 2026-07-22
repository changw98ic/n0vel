import 'dart:io';

import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/llm/app_llm_canonical_hash.dart';
import 'package:novel_writer/app/llm/app_product_prompt_registry.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/features/story_generation/data/pipeline_event_log.dart';
import 'package:novel_writer/features/story_generation/data/story_generation_pass_retry.dart';

/// Exercises low-level settings routing with a real registered prompt identity.
///
/// Production code must never gain a generic unversioned dispatch escape hatch;
/// routing tests therefore use the frozen workbench rewrite release.
Future<AppLlmChatResult> requestAuthorizedAiCompletionForTest(
  AppSettingsStore store, {
  required List<AppLlmChatMessage> messages,
  int? maxTokens,
  String? traceName,
  Map<String, Object?> traceMetadata = const <String, Object?>{},
  bool singlePhysicalDispatch = false,
  String dispatchEvidenceNonce =
      'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  Map<String, Object?>? formalDispatchIntent,
  Object? committedIntentAuthority,
}) async {
  final invocation = AppProductPromptRegistry.current.invocation(
    stageId: 'workbench',
    callSiteId: 'rewrite',
  );
  final originalText = messages.map((message) => message.content).join('\n');
  final variables = <String, Object?>{
    'taskType': traceName ?? 'routing_test',
    'effectivePrompt': 'verify settings routing',
    'providerSummary': 'test provider',
    'endpointLabel': 'test endpoint',
    'styleSummary': 'none',
    'sceneSummary': 'test scene',
    'characterSummary': '',
    'worldSummary': '',
    'simulationSummary': 'none',
    'previousText': '',
    'originalText': originalText,
    'nextText': '',
  };
  final authorizedMessages = invocation.render(variables).messages;
  final evidence = invocation.evidence(
    messages: authorizedMessages,
    resolvedVariables: variables,
  );
  if (singlePhysicalDispatch) {
    if ((formalDispatchIntent == null) != (committedIntentAuthority == null)) {
      throw StateError(
        'single-dispatch test request must supply both intent and authority',
      );
    }
    final routeLease = store.prepareStoryGenerationSinglePhysicalDispatchRoute(
      traceName: traceName ?? 'routing_test',
    );
    if (routeLease == null) {
      throw StateError('single-dispatch route preflight failed');
    }
    PipelineEventLogImpl? ownedEventLog;
    Directory? ownedTempDir;
    var effectiveIntent = formalDispatchIntent;
    var effectiveAuthority = committedIntentAuthority;
    if (effectiveIntent == null) {
      ownedTempDir = await Directory.systemTemp.createTemp(
        'novel-writer-authorized-request-',
      );
      ownedEventLog = PipelineEventLogImpl(
        jsonlPath: '${ownedTempDir.path}/evidence.jsonl',
      );
      await ownedEventLog.prepareEvidencePersistence();
      final preparedBriefDigest = AppLlmCanonicalHash.domainHash(
        'authorized-ai-test-prepared-brief-v1',
        <String, Object?>{'path': ownedTempDir.path, 'messages': originalText},
      );
      final journal = await ownedEventLog.openStoryGenerationEvidenceJournal(
        evidenceRunId:
            'authorized-test-${DateTime.now().microsecondsSinceEpoch}',
        sceneId: 'settings-routing',
        preparedBriefDigest: preparedBriefDigest,
        generationArmPolicy: 'authorized-test',
      );
      final promptReleaseRef = invocation.promptReleaseRef.toJson();
      final intent = StoryGenerationAttemptIntent(
        evidenceRunId: journal.evidenceRunId,
        sceneId: journal.sceneId,
        preparedBriefDigest: preparedBriefDigest,
        logicalAttemptId: dispatchEvidenceNonce,
        attempt: 1,
        maxTokens: AppLlmChatRequest.normalizeMaxTokens(
          maxTokens ?? store.snapshot.maxTokens,
        ),
        transientRetryCount: 0,
        outputRetryCount: 0,
        stageId: invocation.stageId,
        callSiteId: invocation.callSiteId,
        variantId: invocation.variantId,
        generationBundleHash: invocation.generationBundleHash,
        promptReleaseRef: promptReleaseRef,
        promptReleaseContentHash: invocation.promptReleaseRef.contentHash,
        renderedMessagesDigest: evidence.renderedMessagesDigest,
        resolvedVariablesDigest: evidence.resolvedVariablesDigest,
        rendererContractHash: evidence.rendererContractHash,
        selectedRouteBindingHash: AppLlmCanonicalHash.domainHash(
          'story-generation-configured-model-route-v1',
          routeLease.credentialFreeIdentity,
        ),
        generationArmPolicy: journal.generationArmPolicy,
        retryContractHash: AppLlmCanonicalHash.domainHash(
          'authorized-ai-test-retry-contract-v1',
          const <String, Object?>{'maxAttempts': 1, 'contentRedraw': false},
        ),
        evaluationPhase: null,
      );
      effectiveIntent = intent.toPrivateJson();
      effectiveAuthority = await journal.persistIntent(intent);
    }
    try {
      return await store.requestAiCompletionSinglePhysicalDispatch(
        messages: authorizedMessages,
        maxTokens: maxTokens,
        traceName: traceName,
        traceMetadata: traceMetadata,
        promptReleaseRef: invocation.promptReleaseRef,
        promptInvocationEvidence: evidence,
        stageId: invocation.stageId,
        callSiteId: invocation.callSiteId,
        variantId: invocation.variantId,
        generationBundleHash: invocation.generationBundleHash,
        dispatchEvidenceNonce: dispatchEvidenceNonce,
        formalDispatchIntent: effectiveIntent,
        committedIntentAuthority: effectiveAuthority!,
        routeLease: routeLease,
      );
    } finally {
      await ownedEventLog?.dispose();
      if (ownedTempDir != null && await ownedTempDir.exists()) {
        await ownedTempDir.delete(recursive: true);
      }
    }
  }
  return await store.requestAiCompletion(
    messages: authorizedMessages,
    maxTokens: maxTokens,
    traceName: traceName,
    traceMetadata: traceMetadata,
    promptReleaseRef: invocation.promptReleaseRef,
    promptInvocationEvidence: evidence,
    stageId: invocation.stageId,
    callSiteId: invocation.callSiteId,
    variantId: invocation.variantId,
    generationBundleHash: invocation.generationBundleHash,
  );
}
