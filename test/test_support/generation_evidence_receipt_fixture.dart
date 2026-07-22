import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:novel_writer/app/llm/app_llm_canonical_hash.dart';
import 'package:novel_writer/app/llm/app_llm_client_io.dart';
import 'package:novel_writer/app/logging/app_event_log.dart';
import 'package:novel_writer/app/logging/app_event_log_storage.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/features/story_generation/data/generation_evidence_fingerprints.dart';
import 'package:novel_writer/features/story_generation/data/generation_evidence_receipt.dart';
import 'package:novel_writer/features/story_generation/data/pipeline_event_log.dart';
import 'package:novel_writer/features/story_generation/data/story_generation_pass_retry.dart';
import 'package:novel_writer/features/story_generation/data/story_prompt_registry.dart';

const String generationEvidenceReceiptFixtureFinalProse = 'final prose';
const String generationEvidenceReceiptFixtureRawJudgeSentinel =
    'RAW-JUDGE-SEED-MUST-NOT-PERSIST';
int _generationEvidenceReceiptFixtureIdentitySerial = 0;

String get generationEvidenceReceiptFixtureBundleHash =>
    StoryPromptRegistry.production.generationBundle.bundleHash;

/// Builds a receipt only after a real loopback HTTP dispatch has crossed the
/// platform IO client, the formal AiRequestService path, and a durable JSONL
/// evidence journal. No receipt-shaped map or caller-provided verified boolean
/// can manufacture either the IO witness or the one-shot journal authority.
Future<GenerationEvidenceReceipt> buildGenerationEvidenceReceiptFixture({
  required String evidenceRunId,
  required String sceneId,
  required String generationArmPolicy,
  required String preparedBriefDigest,
  required String generationBundleHash,
  required String artifactText,
}) async {
  final fixture = await prepareGenerationEvidenceReceiptFixture(
    evidenceRunId: evidenceRunId,
    sceneId: sceneId,
    generationArmPolicy: generationArmPolicy,
    preparedBriefDigest: preparedBriefDigest,
    generationBundleHash: generationBundleHash,
    artifactText: artifactText,
    includeEvaluationAttempt: false,
  );
  return fixture.issue();
}

/// Returns terminally verified issuance material for receipt validation tests.
/// [issue] still obtains the authority from the exact journal re-read and can
/// consume it only once.
Future<RealGenerationEvidenceReceiptFixture>
prepareGenerationEvidenceReceiptFixture({
  String? evidenceRunId,
  String? sceneId,
  String generationArmPolicy = 'arm-current-v1',
  String? preparedBriefDigest,
  String? generationBundleHash,
  String artifactText = generationEvidenceReceiptFixtureFinalProse,
  String? evaluatedArtifactText,
  bool includeEvaluationAttempt = true,
}) async {
  final identitySerial = _generationEvidenceReceiptFixtureIdentitySerial += 1;
  final resolvedEvidenceRunId =
      evidenceRunId ?? 'receipt-fixture-run-$identitySerial';
  final resolvedSceneId = sceneId ?? 'receipt-fixture-scene-$identitySerial';
  final registry = StoryPromptRegistry.production;
  final actualBundleHash = registry.generationBundle.bundleHash;
  if (generationBundleHash != null &&
      generationBundleHash != actualBundleHash) {
    throw ArgumentError.value(
      generationBundleHash,
      'generationBundleHash',
      'must be the bundle exercised by the real formal prompt path',
    );
  }
  final briefDigest = preparedBriefDigest ?? _fixtureHash('prepared-brief');
  final directory = await Directory.systemTemp.createTemp(
    'novel-writer-receipt-evidence-',
  );
  final protocol = await _ReceiptFixtureProtocol.start(
    responses: <String>[
      if (includeEvaluationAttempt) 'evaluation response',
      artifactText,
    ],
  );
  final log = PipelineEventLogImpl(
    jsonlPath: '${directory.path}/pipeline-evidence.jsonl',
  );
  final settings = AppSettingsStore(
    storage: InMemoryAppSettingsStorage(),
    llmClient: createAppLlmClient(),
    eventLog: AppEventLog(storage: _DiscardingAppEventLogStorage()),
  );
  try {
    await settings.save(
      providerName: 'OpenAI Compatible Fixture',
      baseUrl: protocol.baseUrl,
      model: _ReceiptFixtureProtocol.model,
      apiKey: '',
      timeoutMs: 10000,
      maxConcurrentRequests: 1,
    );
    final journal = await log.openStoryGenerationEvidenceJournal(
      evidenceRunId: resolvedEvidenceRunId,
      sceneId: resolvedSceneId,
      preparedBriefDigest: briefDigest,
      generationArmPolicy: generationArmPolicy,
    );
    final capture = StoryGenerationAttemptEvidenceCapture();

    await StoryGenerationRetryScope.run<Future<void>>(
      policy: const StoryGenerationRetryPolicy.experimentNoContentRedraw(
        maxTotalAttempts: 1,
      ),
      onAttemptEvidence: capture.record,
      persistAttemptIntent: journal.persistIntent,
      persistAttemptEvidence: journal.persistAttempt,
      generationArmPolicy: generationArmPolicy,
      evidenceRunId: resolvedEvidenceRunId,
      evidenceSceneId: resolvedSceneId,
      preparedBriefDigest: briefDigest,
      body: () async {
        if (includeEvaluationAttempt) {
          final evaluationInvocation = registry.invocation(
            stageId: 'review',
            callSiteId: 'judge',
          );
          final evaluationVariables = _resolvedVariables(
            evaluationInvocation.release.variablesSchemaSnapshot,
          );
          final evaluationMessages = evaluationInvocation
              .render(evaluationVariables)
              .messages;
          final evaluatedText = evaluatedArtifactText ?? artifactText;
          final evaluatedDigest = ArtifactDigest.fromUtf8String(evaluatedText);
          final evaluationResult = await StoryGenerationEvaluationScope.run(
            phase: StoryGenerationEvaluationPhase.preliminaryReview,
            artifactText: evaluatedText,
            body: () => requestFormalStoryGenerationPassWithRetry(
              settingsStore: settings,
              messages: evaluationMessages,
              maxTransientRetries: 0,
              maxOutputRetries: 0,
              promptInvocation: evaluationInvocation,
              promptInvocationEvidence: evaluationInvocation.evidence(
                evaluationMessages,
                resolvedVariables: evaluationVariables,
              ),
              evaluationFingerprintSeed:
                  StoryGenerationEvaluationFingerprintSeed(
                    artifactDigest: evaluatedDigest,
                    evaluationBundleHash: _fixtureHash('evaluation-bundle'),
                    judgeInput: <String, Object?>{
                      'binding': storyGenerationEvaluationJudgeInput(
                        phase: StoryGenerationEvaluationPhase.preliminaryReview,
                        stageId: evaluationInvocation.callSite.stageId,
                        callSiteId: evaluationInvocation.callSite.callSiteId,
                        artifactDigest: evaluatedDigest,
                      ),
                      'privatePrompt':
                          generationEvidenceReceiptFixtureRawJudgeSentinel,
                    },
                    rubricHash: storyGenerationEvaluationRubricHash(
                      phase: StoryGenerationEvaluationPhase.preliminaryReview,
                      promptInvocation: evaluationInvocation,
                    ),
                    blindingPolicy: 'story-generation-runtime-evaluation-v1',
                  ),
            ),
          );
          if (!evaluationResult.succeeded) {
            throw StateError('real evaluation fixture dispatch failed');
          }
        }

        final polishInvocation = registry.invocation(
          stageId: 'polish',
          callSiteId: 'language-polish',
        );
        final polishVariables = _resolvedVariables(
          polishInvocation.release.variablesSchemaSnapshot,
        );
        final polishMessages = polishInvocation
            .render(polishVariables)
            .messages;
        final polishResult = await requestFormalStoryGenerationPassWithRetry(
          settingsStore: settings,
          messages: polishMessages,
          maxTransientRetries: 0,
          maxOutputRetries: 0,
          promptInvocation: polishInvocation,
          promptInvocationEvidence: polishInvocation.evidence(
            polishMessages,
            resolvedVariables: polishVariables,
          ),
        );
        if (!polishResult.succeeded || polishResult.text != artifactText) {
          throw StateError('real polish fixture dispatch failed');
        }
      },
    );

    final outcomes = capture.attempts;
    final terminalAttempt = outcomes.last;
    final sealedArtifactDigest = await journal.sealArtifact(
      stageId: 'finalization',
      artifactText: artifactText,
      sourceLogicalAttemptId: terminalAttempt.logicalAttemptId!,
      sourceCallSiteId: terminalAttempt.callSiteId!,
    );
    final envelope = capture.toEnvelope();
    final terminalVerified = await journal.persistAndVerifyEnvelope(
      envelope: envelope,
      completed: true,
      finalArtifactDigest: sealedArtifactDigest,
    );
    if (!terminalVerified) {
      throw StateError('real receipt fixture journal did not close verified');
    }
    if (protocol.callCount != outcomes.length) {
      throw StateError('fixture physical dispatch cardinality mismatch');
    }
    return RealGenerationEvidenceReceiptFixture._(
      journal: journal,
      evidenceRunId: resolvedEvidenceRunId,
      sceneId: resolvedSceneId,
      generationArmPolicy: generationArmPolicy,
      preparedBriefDigest: briefDigest,
      generationBundleHash: actualBundleHash,
      artifactText: artifactText,
      sealedArtifactDigest: sealedArtifactDigest,
      intents: <GenerationEvidenceReceiptIntent>[
        for (final admission in journal.verifiedAdmissionOrderedAdmissions)
          GenerationEvidenceReceiptIntent(
            admissionSequenceNo: admission.sequenceNo,
            intent: admission.intent,
          ),
      ],
      envelope: envelope,
      providerCallCount: protocol.callCount,
    );
  } finally {
    await settings.quiesceLlmDispatches();
    settings.dispose();
    await log.dispose();
    await protocol.close();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}

final class RealGenerationEvidenceReceiptFixture {
  RealGenerationEvidenceReceiptFixture._({
    required PipelineStoryGenerationEvidenceJournal journal,
    required this.evidenceRunId,
    required this.sceneId,
    required this.generationArmPolicy,
    required this.preparedBriefDigest,
    required this.generationBundleHash,
    required this.artifactText,
    required this.sealedArtifactDigest,
    required this.intents,
    required this.envelope,
    required this.providerCallCount,
  }) : _journal = journal;

  final PipelineStoryGenerationEvidenceJournal _journal;
  final String evidenceRunId;
  final String sceneId;
  final String generationArmPolicy;
  final String preparedBriefDigest;
  final String generationBundleHash;
  final String artifactText;
  final ArtifactDigest sealedArtifactDigest;
  final List<GenerationEvidenceReceiptIntent> intents;
  final StoryGenerationAttemptEvidenceEnvelope envelope;
  final int providerCallCount;

  List<StoryGenerationAttemptEvidence> get outcomes => envelope.attempts;

  GenerationEvidenceReceipt issue({
    String? overrideEvidenceRunId,
    String? overrideSceneId,
    String? overrideGenerationArmPolicy,
    String? overridePreparedBriefDigest,
    Iterable<GenerationEvidenceReceiptIntent>? overrideIntents,
    StoryGenerationAttemptEvidenceEnvelope? overrideEnvelope,
    ArtifactDigest? overrideSealedArtifactDigest,
  }) {
    final authority = _journal.issueReceiptAuthority(
      sealedArtifactDigest: sealedArtifactDigest,
    );
    return GenerationEvidenceReceipt.fromVerified(
      authority: authority,
      evidenceRunId: overrideEvidenceRunId ?? evidenceRunId,
      sceneId: overrideSceneId ?? sceneId,
      generationArmPolicy: overrideGenerationArmPolicy ?? generationArmPolicy,
      preparedBriefDigest: overridePreparedBriefDigest ?? preparedBriefDigest,
      intents: overrideIntents ?? intents,
      envelope: overrideEnvelope ?? envelope,
      sealedArtifactDigest:
          overrideSealedArtifactDigest ?? sealedArtifactDigest,
    );
  }
}

final class _ReceiptFixtureProtocol {
  _ReceiptFixtureProtocol._({
    required HttpServer server,
    required StreamSubscription<HttpRequest> subscription,
    required List<String> responses,
  }) : _server = server,
       _subscription = subscription,
       _responses = responses;

  static const String model = 'receipt-fixture-model';

  final HttpServer _server;
  // This owned listener is deterministically cancelled by [close].
  // ignore: cancel_subscriptions
  final StreamSubscription<HttpRequest> _subscription;
  final List<String> _responses;
  int callCount = 0;

  String get baseUrl => 'http://127.0.0.1:${_server.port}/v1';

  static Future<_ReceiptFixtureProtocol> start({
    required List<String> responses,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    late final _ReceiptFixtureProtocol protocol;
    // Ownership is transferred into [protocol], whose [close] cancels it.
    // ignore: cancel_subscriptions
    final subscription = server.listen((request) async {
      await protocol._handle(request);
    });
    protocol = _ReceiptFixtureProtocol._(
      server: server,
      subscription: subscription,
      responses: List<String>.unmodifiable(responses),
    );
    return protocol;
  }

  Future<void> _handle(HttpRequest request) async {
    final requestIndex = callCount;
    callCount += 1;
    try {
      final body = await utf8.decoder.bind(request).join();
      final decoded = jsonDecode(body);
      if (request.method != 'POST' ||
          request.uri.path != '/v1/chat/completions' ||
          decoded is! Map ||
          decoded['model'] != model ||
          decoded['messages'] is! List ||
          requestIndex >= _responses.length) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.write('invalid formal fixture request');
        return;
      }
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(<String, Object?>{
          'id': 'receipt-fixture-response-${requestIndex + 1}',
          'object': 'chat.completion',
          'created': 1,
          'model': model,
          'choices': <Object?>[
            <String, Object?>{
              'index': 0,
              'message': <String, Object?>{
                'role': 'assistant',
                'content': _responses[requestIndex],
              },
              'finish_reason': 'stop',
            },
          ],
          'usage': const <String, Object?>{
            'prompt_tokens': 10,
            'completion_tokens': 20,
            'total_tokens': 30,
          },
        }),
      );
    } finally {
      await request.response.close();
    }
  }

  Future<void> close() async {
    await _subscription.cancel();
    await _server.close(force: true);
  }
}

Map<String, Object?> _resolvedVariables(Object? schemaSnapshot) {
  final schema = Map<String, Object?>.from(schemaSnapshot! as Map);
  final properties = Map<String, Object?>.from(schema['properties']! as Map);
  return <String, Object?>{
    for (final entry in properties.entries)
      entry.key: switch (Map<String, Object?>.from(
        entry.value as Map,
      )['type']) {
        'string' => 'fixture=${entry.key}',
        'integer' => 1,
        'number' => 1.0,
        'boolean' => true,
        _ => throw StateError('unsupported fixture variable: ${entry.key}'),
      },
  };
}

String _fixtureHash(String value) => AppLlmCanonicalHash.domainHash(
  'generation-receipt-real-fixture-v1',
  <String, Object?>{'value': value},
);

final class _DiscardingAppEventLogStorage implements AppEventLogStorage {
  @override
  Future<void> write(AppEventLogEntry entry) async {}
}
