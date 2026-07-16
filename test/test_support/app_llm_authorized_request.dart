import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/llm/app_product_prompt_registry.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';

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
}) {
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
  return store.requestAiCompletion(
    messages: authorizedMessages,
    maxTokens: maxTokens,
    traceName: traceName,
    traceMetadata: traceMetadata,
    promptReleaseRef: invocation.promptReleaseRef,
    promptInvocationEvidence: invocation.evidence(
      messages: authorizedMessages,
      resolvedVariables: variables,
    ),
    stageId: invocation.stageId,
    callSiteId: invocation.callSiteId,
    variantId: invocation.variantId,
    generationBundleHash: invocation.generationBundleHash,
  );
}
