import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_call_trace.dart';
import 'package:novel_writer/app/llm/app_llm_client_types.dart';
import 'package:novel_writer/app/llm/app_llm_prompt_invocation.dart';
import 'package:novel_writer/app/llm/app_llm_prompt_release.dart';

void main() {
  test('binds a valid release ref to the actual rendered messages', () {
    final release = _release();
    final evidence = PromptInvocationEvidence(
      release: release,
      promptReleaseRef: release.ref,
      messages: _messages(release, '雨夜'),
      resolvedVariables: const {'scene': '雨夜'},
    );

    expect(evidence.promptReleaseRef, release.ref);
    expect(evidence.renderedMessagesDigest, startsWith('sha256:'));
    expect(evidence.resolvedVariablesDigest, startsWith('sha256:'));
    expect(evidence.matchesMessages(_messages(release, '雨夜')), isTrue);
    expect(evidence.rendererContractHash, startsWith('sha256:'));
  });

  test('rejects missing, duplicate, or substituted system messages', () {
    final release = _release();

    expect(
      () => PromptInvocationEvidence(
        release: release,
        promptReleaseRef: release.ref,
        messages: const [AppLlmChatMessage(role: 'user', content: 'scene')],
        resolvedVariables: const {'scene': '雨夜'},
      ),
      throwsStateError,
    );
    expect(
      () => PromptInvocationEvidence(
        release: release,
        promptReleaseRef: release.ref,
        messages: [
          AppLlmChatMessage(role: 'system', content: release.systemTemplate),
          AppLlmChatMessage(role: 'system', content: release.systemTemplate),
        ],
        resolvedVariables: const {'scene': '雨夜'},
      ),
      throwsStateError,
    );
    expect(
      () => PromptInvocationEvidence(
        release: release,
        promptReleaseRef: release.ref,
        messages: const [
          AppLlmChatMessage(role: 'system', content: 'substituted'),
          AppLlmChatMessage(role: 'user', content: 'scene'),
        ],
        resolvedVariables: const {'scene': '雨夜'},
      ),
      throwsStateError,
    );
  });

  test('rejects a stale or forged release ref', () {
    final release = _release();
    final staleRef = PromptReleaseRef(
      templateId: release.templateId,
      semanticVersion: release.semanticVersion,
      language: release.language,
      contentHash:
          'sha256:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
    );

    expect(
      () => PromptInvocationEvidence(
        release: release,
        promptReleaseRef: staleRef,
        messages: _messages(release, '雨夜'),
        resolvedVariables: const {'scene': '雨夜'},
      ),
      throwsStateError,
    );
  });

  test('variable changes replay different exact request identities', () {
    final release = _release();
    final first = _evidence(release, const {'scene': 'A'});
    final second = _evidence(release, const {'scene': 'B'});

    expect(first.renderedMessagesDigest, isNot(second.renderedMessagesDigest));
    expect(
      first.resolvedVariablesDigest,
      isNot(second.resolvedVariablesDigest),
    );
  });

  test('message order or extra messages fail exact renderer replay', () {
    final release = _release();
    expect(
      () => PromptInvocationEvidence(
        release: release,
        promptReleaseRef: release.ref,
        messages: [
          ..._messages(release, '雨夜').reversed,
          const AppLlmChatMessage(role: 'assistant', content: 'extra'),
        ],
        resolvedVariables: const {'scene': '雨夜'},
      ),
      throwsStateError,
    );
  });

  test(
    'trace ignores caller-forged digests and persists computed evidence',
    () {
      final release = _release();
      final messages = _messages(release, '雨夜');
      final evidence = PromptInvocationEvidence(
        release: release,
        promptReleaseRef: release.ref,
        messages: messages,
        resolvedVariables: const {'scene': '雨夜'},
      );
      final entry = AppLlmCallTraceEntry.fromRequestResult(
        request: AppLlmChatRequest(
          baseUrl: 'https://example.test/v1',
          apiKey: 'secret',
          model: 'model',
          timeout: const AppLlmTimeoutConfig.uniform(1000),
          messages: messages,
        ),
        result: const AppLlmChatResult.success(text: 'ok'),
        traceName: 'scene-editorial',
        metadata: const {
          'renderedMessagesDigest': 'forged',
          'resolvedVariablesDigest': 'forged',
        },
        promptInvocationEvidence: evidence,
      );
      final json = entry.toJson();
      final metadata = json['metadata']! as Map<String, Object?>;

      expect(json['promptReleaseRef'], release.ref.toJson());
      expect(json['renderedMessagesDigest'], evidence.renderedMessagesDigest);
      expect(json['resolvedVariablesDigest'], evidence.resolvedVariablesDigest);
      expect(
        metadata['renderedMessagesDigest'],
        evidence.renderedMessagesDigest,
      );
      expect(
        metadata['resolvedVariablesDigest'],
        evidence.resolvedVariablesDigest,
      );
      expect(metadata['rendererContractHash'], evidence.rendererContractHash);
    },
  );

  test('trace rejects evidence created for different actual messages', () {
    final release = _release();
    final evidence = _evidence(release, const {'scene': '雨夜'});

    expect(
      () => AppLlmCallTraceEntry.fromRequestResult(
        request: AppLlmChatRequest(
          baseUrl: 'https://example.test/v1',
          apiKey: 'secret',
          model: 'model',
          timeout: const AppLlmTimeoutConfig.uniform(1000),
          messages: [
            AppLlmChatMessage(role: 'system', content: release.systemTemplate),
            const AppLlmChatMessage(role: 'user', content: 'Scene: different'),
          ],
        ),
        result: const AppLlmChatResult.success(text: 'ok'),
        traceName: 'scene-editorial',
        promptInvocationEvidence: evidence,
      ),
      throwsStateError,
    );
  });
}

PromptInvocationEvidence _evidence(PromptRelease release, Object? variables) =>
    PromptInvocationEvidence(
      release: release,
      promptReleaseRef: release.ref,
      messages: _messages(
        release,
        (variables! as Map<String, Object?>)['scene']! as String,
      ),
      resolvedVariables: variables,
    );

List<AppLlmChatMessage> _messages(PromptRelease release, String scene) => [
  AppLlmChatMessage(role: 'system', content: release.systemTemplate),
  AppLlmChatMessage(role: 'user', content: 'Scene: $scene'),
];

PromptRelease _release() => PromptRelease(
  templateId: 'scene-editorial',
  semanticVersion: '1.0.0',
  language: 'zh',
  systemTemplate: 'You are the frozen scene editor.',
  userTemplate: 'Scene: {{scene}}',
  variablesSchemaSnapshot: const {
    'type': 'object',
    'additionalProperties': false,
    'required': ['scene'],
    'properties': <String, Object?>{
      'scene': <String, Object?>{'type': 'string'},
    },
  },
  outputSchemaSnapshot: const {'type': 'string'},
  rendererRelease: 'strict-named-template-v1',
  parserRelease: 'parser-v1',
  repairPolicySnapshot: const {'maxAttempts': 1},
  owner: 'story-generation',
  changeNote: 'test',
  createdAt: DateTime.utc(2026, 7, 12),
);
