import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_call_site_inventory.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/llm/app_product_prompt_registry.dart';
import 'package:novel_writer/app/llm/app_llm_prompt_invocation.dart';
import 'package:novel_writer/app/llm/app_llm_prompt_release.dart';
import 'package:novel_writer/app/llm/app_llm_prompt_renderer.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/features/story_generation/data/story_prompt_registry.dart';

final RegExp _llmInvocationPattern = RegExp(
  r'(?:[A-Za-z_][A-Za-z0-9_]*|\)|^\s*)\.(?:chat|chatStream|chatWithPhysicalDispatch|requestAiCompletion|requestCompletion)\s*\('
  r'|\.(?:postUri|post)(?:<[^>]+>)?\s*\('
  r'|\.(?:chat|chatStream|requestAiCompletion|requestCompletion)\s*(?=;|,|\)|$)'
  r'|\.(?:postUri|post)(?:<[^>]+>)?\s*(?=;|,|\)|$)',
);

void main() {
  test('whole-lib LLM call-site inventory is unique and hash sealed', () {
    final inventory = AppLlmCallSiteInventory.current;

    expect(
      inventory.hasValidContentHash,
      isTrue,
      reason: 'computed inventory seal: ${inventory.contentHash}',
    );
    expect(
      inventory.entries.map((entry) => entry.id).toSet(),
      hasLength(inventory.entries.length),
    );
    expect(
      inventory.entries
          .where(
            (entry) =>
                entry.disposition ==
                AppLlmCallSiteDisposition.operationalAllowlist,
          )
          .map((entry) => entry.id),
      <String>[AppLlmCallSiteIds.settingsConnectionProbe],
    );
  });

  test('semantic prompt inventory covers story and product releases', () {
    final inventory = AppLlmCallSiteInventory.current;
    final expectedStoryKeys = <String>{
      for (final callSite in StoryPromptRegistry.requiredCallSites)
        callSite.key,
    };
    final actualStoryKeys = inventory.entries
        .where((entry) => entry.id.startsWith('prompt.story.'))
        .map((entry) => entry.semanticCallSiteKey)
        .whereType<String>()
        .toSet();

    expect(actualStoryKeys, expectedStoryKeys);
    for (final registration in StoryPromptRegistry.current().registrations) {
      final entry = inventory.requireRegisteredPrompt(
        stageId: registration.callSite.stageId,
        callSiteId: registration.callSite.callSiteId,
        variantId: registration.callSite.variantId,
        releaseRef: registration.release.ref,
        generationBundleHash:
            StoryPromptRegistry.current().generationBundle.bundleHash,
      );
      expect(entry.disposition, AppLlmCallSiteDisposition.registeredPrompt);
    }
    for (final registration in AppProductPromptRegistry.current.registrations) {
      final entry = inventory.requireRegisteredPrompt(
        stageId: registration.stageId,
        callSiteId: registration.callSiteId,
        variantId: registration.variantId,
        releaseRef: registration.release.ref,
        generationBundleHash:
            AppProductPromptRegistry.current.generationBundle.bundleHash,
      );
      expect(entry.disposition, AppLlmCallSiteDisposition.registeredPrompt);
      expect(registration.release.hasValidContentHash, isTrue);
    }
  });

  test('every direct provider or request call in lib has a frozen marker', () {
    final inventory = AppLlmCallSiteInventory.current;
    final boundaryEntries = <String, AppLlmCallSiteInventoryEntry>{
      for (final entry in inventory.entries)
        if (entry.disposition ==
            AppLlmCallSiteDisposition.infrastructureBoundary)
          entry.id: entry,
    };
    final observed = <String, String>{};
    final missingMarkers = <String>[];
    final duplicateMarkers = <String>[];
    final markerPattern = RegExp(r'^\s*// llm-call-site: ([a-z0-9._-]+)\s*$');

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var index = 0; index < lines.length; index += 1) {
        if (!_llmInvocationPattern.hasMatch(lines[index])) continue;
        final marker = index == 0
            ? null
            : markerPattern.firstMatch(lines[index - 1])?.group(1);
        if (marker == null) {
          missingMarkers.add('${entity.path}:${index + 1}');
          continue;
        }
        if (observed.containsKey(marker)) {
          duplicateMarkers.add(marker);
          continue;
        }
        observed[marker] = entity.path;
      }
    }

    expect(missingMarkers, isEmpty, reason: 'unmarked calls: $missingMarkers');
    expect(duplicateMarkers, isEmpty, reason: 'duplicate markers');
    expect(observed.keys.toSet(), boundaryEntries.keys.toSet());
    for (final entry in boundaryEntries.values) {
      expect(observed[entry.id], entry.sourcePath);
      expect(entry.reason.trim(), isNotEmpty);
    }
  });

  test('scanner covers streaming, raw transport, and method tear-offs', () {
    for (final source in const <String>[
      'client.chatStream(request)',
      'gateway.chatWithPhysicalDispatch(request)',
      'dio.postUri<ResponseBody>(uri)',
      'dio.post(uri)',
      'final send = client.chat;',
      'Function.apply(client.requestCompletion, args)',
      'final send = dio.post;',
      'final sendUri = dio.postUri<ResponseBody>;',
    ]) {
      expect(_llmInvocationPattern.hasMatch(source), isTrue, reason: source);
    }
  });

  test('unknown semantic prompt and non-operational allowlist fail closed', () {
    final inventory = AppLlmCallSiteInventory.current;

    expect(
      () => inventory.requireRegisteredPrompt(
        stageId: 'unknown',
        callSiteId: 'unknown',
        variantId: 'zh',
        releaseRef: PromptReleaseRef(
          templateId: 'unknown',
          semanticVersion: '1.0.0',
          language: 'zh',
          contentHash:
              'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        ),
        generationBundleHash:
            'sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      ),
      throwsStateError,
    );
    expect(
      () => inventory.requireOperationalAllowlist(
        AppLlmCallSiteIds.workbenchRewrite,
      ),
      throwsStateError,
    );
  });

  test('same template id and version with a different hash fails closed', () {
    final registered = AppProductPromptRegistry.current.invocation(
      stageId: 'workbench',
      callSiteId: 'rewrite',
    );
    final forged = PromptRelease(
      templateId: registered.release.templateId,
      semanticVersion: registered.release.semanticVersion,
      language: registered.release.language,
      systemTemplate: '${registered.release.systemTemplate}\nforged',
      userTemplate: registered.release.userTemplate,
      variablesSchemaSnapshot: registered.release.variablesSchemaSnapshot,
      outputSchemaSnapshot: registered.release.outputSchemaSnapshot,
      rendererRelease: registered.release.rendererRelease,
      parserRelease: registered.release.parserRelease,
      repairPolicySnapshot: registered.release.repairPolicySnapshot,
      owner: 'attacker',
      changeNote: 'same template id but not registered',
      createdAt: DateTime.utc(2026, 7, 13),
    );
    final variables = _workbenchVariables();
    final messages = AppLlmPromptRendererRegistry.builtIn
        .render(release: forged, resolvedVariables: variables)
        .messages;
    final evidence = PromptInvocationEvidence(
      release: forged,
      promptReleaseRef: forged.ref,
      messages: messages,
      resolvedVariables: variables,
    );

    expect(
      () => AppLlmCallSiteAuthority.registeredPrompt(
        promptReleaseRef: forged.ref,
        promptInvocationEvidence: evidence,
        stageId: registered.stageId,
        callSiteId: registered.callSiteId,
        variantId: registered.variantId,
        generationBundleHash: registered.generationBundleHash,
      ),
      throwsStateError,
    );
  });

  test(
    'frozen challenger reaches the provider only in its own bundle',
    () async {
      final client = _CountingLlmClient();
      final store = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: client,
      );
      addTearDown(store.dispose);
      final challenger = StoryPromptRegistry.causalityChallenger();
      final invocation = challenger.invocation(
        stageId: 'editorial',
        callSiteId: 'scene-editorial-generator',
      );
      final variables = _variablesFor(invocation.release);
      final messages = invocation.render(variables).messages;

      final result = await store.requestAiCompletion(
        messages: messages,
        promptReleaseRef: invocation.promptReleaseRef,
        promptInvocationEvidence: invocation.evidence(
          messages,
          resolvedVariables: variables,
        ),
        stageId: invocation.callSite.stageId,
        callSiteId: invocation.callSite.callSiteId,
        variantId: invocation.callSite.variantId,
        generationBundleHash: invocation.generationBundleHash,
      );

      expect(result.succeeded, isTrue);
      expect(client.calls, 1);
      expect(
        () => AppLlmCallSiteAuthority.registeredPrompt(
          promptReleaseRef: invocation.promptReleaseRef,
          promptInvocationEvidence: invocation.evidence(
            messages,
            resolvedVariables: variables,
          ),
          stageId: invocation.callSite.stageId,
          callSiteId: invocation.callSite.callSiteId,
          variantId: invocation.callSite.variantId,
          generationBundleHash:
              StoryPromptRegistry.current().generationBundle.bundleHash,
        ),
        throwsStateError,
      );

      final unchanged = challenger.invocation(
        stageId: 'director',
        callSiteId: 'scene-director',
      );
      final unchangedVariables = _variablesFor(unchanged.release);
      final unchangedMessages = unchanged.render(unchangedVariables).messages;
      expect(
        AppLlmCallSiteAuthority.registeredPrompt(
          promptReleaseRef: unchanged.promptReleaseRef,
          promptInvocationEvidence: unchanged.evidence(
            unchangedMessages,
            resolvedVariables: unchangedVariables,
          ),
          stageId: unchanged.callSite.stageId,
          callSiteId: unchanged.callSite.callSiteId,
          variantId: unchanged.callSite.variantId,
          generationBundleHash: unchanged.generationBundleHash,
        ),
        isA<AppLlmRegisteredPromptAuthority>(),
      );
    },
  );

  test(
    'central product dispatch rejects missing authority before provider',
    () async {
      final client = _CountingLlmClient();
      final store = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: client,
      );
      addTearDown(store.dispose);

      expect(
        () => store.requestAiCompletion(
          messages: const <AppLlmChatMessage>[
            AppLlmChatMessage(role: 'user', content: 'unregistered'),
          ],
        ),
        throwsStateError,
      );
      expect(client.calls, 0);
    },
  );
}

final class _CountingLlmClient implements AppLlmClient {
  int calls = 0;

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    calls += 1;
    return const AppLlmChatResult.success(text: 'unexpected');
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) =>
      const Stream<String>.empty();
}

Map<String, Object?> _workbenchVariables() => <String, Object?>{
  'taskType': 'rewrite',
  'effectivePrompt': 'forged request',
  'providerSummary': 'provider',
  'endpointLabel': 'endpoint',
  'styleSummary': 'style',
  'sceneSummary': 'scene',
  'characterSummary': 'character',
  'worldSummary': 'world',
  'simulationSummary': 'simulation',
  'previousText': 'previous',
  'originalText': 'original',
  'nextText': 'next',
};

Map<String, Object?> _variablesFor(PromptRelease release) {
  final schema = release.variablesSchemaSnapshot as Map<String, Object?>;
  final properties = schema['properties']! as Map<String, Object?>;
  return <String, Object?>{
    for (final entry in properties.entries)
      entry.key: switch ((entry.value as Map<String, Object?>)['type']) {
        'string' => 'sample-${entry.key}',
        'integer' => 1,
        'number' => 1.5,
        'boolean' => true,
        _ => throw StateError('unsupported test variable: ${entry.key}'),
      },
  };
}
