import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/llm/app_llm_prompt_release.dart';
import 'package:novel_writer/app/llm/app_llm_prompt_invocation.dart';
import 'package:novel_writer/domain/prompt_language.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_trace_context.dart';
import 'package:novel_writer/features/story_generation/data/story_generation_pass_retry.dart';
import 'package:novel_writer/features/story_generation/data/story_prompt_registry.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/settings_contract.dart';

void main() {
  test('concurrent async Zones keep trial identities isolated', () async {
    Future<String> readAfterDelay(String id, Duration delay) =>
        AgentEvaluationTraceContext.run(_context(trialSlotId: id), () async {
          await Future<void>.delayed(delay);
          return AgentEvaluationTraceContext.current!.trialSlotId;
        });

    final values = await Future.wait([
      readAfterDelay('slot-a', const Duration(milliseconds: 5)),
      readAfterDelay('slot-b', Duration.zero),
    ]);

    expect(values, ['slot-a', 'slot-b']);
    expect(AgentEvaluationTraceContext.current, isNull);
  });

  test('nested Zone restores its parent identity', () async {
    await AgentEvaluationTraceContext.run(
      _context(trialSlotId: 'outer'),
      () async {
        expect(AgentEvaluationTraceContext.current!.trialSlotId, 'outer');
        await AgentEvaluationTraceContext.run(
          _context(trialSlotId: 'inner'),
          () async {
            await Future<void>.delayed(Duration.zero);
            expect(AgentEvaluationTraceContext.current!.trialSlotId, 'inner');
          },
        );
        expect(AgentEvaluationTraceContext.current!.trialSlotId, 'outer');
      },
    );
    expect(AgentEvaluationTraceContext.current, isNull);
  });

  test('formal helper overwrites spoofed evaluation metadata', () async {
    final settings = _CapturingSettings();
    final context = _context(trialSlotId: 'authoritative-slot');

    await AgentEvaluationTraceContext.run(
      context,
      () => _request(
        settings,
        traceMetadata: const {
          'experimentId': 'spoofed',
          'executionId': 'spoofed',
          'cellId': 'spoofed',
          'trialSlotId': 'spoofed',
          'attemptNo': 999,
          'runId': 'spoofed',
          'leaseEpoch': 999,
          'leaseOwner': 'spoofed',
          'isolationTrialId': 'spoofed',
          'generationBundleHash': 'spoofed',
          'evaluationBundleHash': 'spoofed',
        },
      ),
    );

    for (final entry in context.toTraceMetadata().entries) {
      expect(settings.metadata[entry.key], entry.value, reason: entry.key);
    }
  });

  test('partial formal context fails closed before provider call', () {
    final settings = _CapturingSettings();

    expect(
      () => AgentEvaluationTraceContext.runFormalExperiment(
        experimentId: 'experiment',
        executionId: 'execution',
        // cellId is deliberately missing.
        trialSlotId: 'slot',
        attemptNo: 1,
        runId: 'run',
        evaluationBundleHash: _evaluationHash,
        body: () => _request(settings),
      ),
      throwsStateError,
    );
    expect(settings.calls, 0);
  });

  test('ordinary production helper permits no evaluation context', () async {
    final settings = _CapturingSettings();

    await _request(settings);

    expect(settings.calls, 1);
    expect(settings.metadata.containsKey('experimentId'), isFalse);
    expect(settings.metadata.containsKey('trialSlotId'), isFalse);
  });

  test('cell and invocation bundle mismatch fails before provider', () {
    final settings = _CapturingSettings();
    final context = _context(
      trialSlotId: 'slot-mismatch',
      generationBundleHash: _otherGenerationHash,
    );

    expect(
      () => AgentEvaluationTraceContext.run(context, () => _request(settings)),
      throwsStateError,
    );
    expect(settings.calls, 0);
  });
}

Future<AppLlmChatResult> _request(
  _CapturingSettings settings, {
  Map<String, Object?> traceMetadata = const {},
}) {
  final invocation = StoryPromptRegistry.production.invocation(
    stageId: 'review',
    callSiteId: 'judge',
  );
  final resolvedVariables = <String, Object?>{
    'taskType': 'scene_judge_review',
    'passLabel': 'judge',
    'categories': 'all',
    'sceneNumber': 1,
    'totalScenes': 1,
    'openingBoundary': '',
    'closingBoundary': '',
    'sceneTitle': '测试场景',
    'director': '测试导演计划',
    'noninteractiveBoundary': '',
    'roleSummary': '测试角色输入',
    'roleplayProcess': '',
    'roleplayGuidance': '',
    'prose': '测试正文',
    'adjudicationContext': '',
    'evidenceSection': '',
    'reviewCriteria': '测试评审标准',
  };
  final messages = invocation.render(resolvedVariables).messages;
  return requestFormalStoryGenerationPassWithRetry(
    settingsStore: settings,
    messages: messages,
    promptInvocation: invocation,
    promptInvocationEvidence: invocation.evidence(
      messages,
      resolvedVariables: resolvedVariables,
    ),
    traceMetadata: traceMetadata,
    maxTransientRetries: 0,
  );
}

AgentEvaluationTraceContext _context({
  required String trialSlotId,
  String? generationBundleHash,
}) => AgentEvaluationTraceContext(
  experimentId: 'experiment',
  executionId: 'execution',
  cellId: 'cell',
  trialSlotId: trialSlotId,
  attemptNo: 1,
  runId: 'run-$trialSlotId',
  leaseEpoch: 1,
  leaseOwner: 'worker-1',
  isolationTrialId: 'isolation-$trialSlotId',
  generationBundleHash:
      generationBundleHash ??
      StoryPromptRegistry.production.generationBundle.bundleHash,
  evaluationBundleHash: _evaluationHash,
);

final class _CapturingSettings implements StoryGenerationSettingsContract {
  int calls = 0;
  Map<String, Object?> metadata = const {};

  @override
  PromptLanguage get promptLanguage => PromptLanguage.zh;

  @override
  Future<AppLlmChatResult> requestAiCompletion({
    required List<AppLlmChatMessage> messages,
    int? maxTokens,
    String? traceName,
    Map<String, Object?> traceMetadata = const {},
    PromptReleaseRef? promptReleaseRef,
    PromptInvocationEvidence? promptInvocationEvidence,
    PromptVersion? promptVersion,
    String? stageId,
    String? callSiteId,
    String? variantId,
    String? generationBundleHash,
  }) async {
    calls += 1;
    metadata = Map<String, Object?>.unmodifiable(traceMetadata);
    return const AppLlmChatResult.success(text: 'ok');
  }
}

const _evaluationHash =
    'sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _otherGenerationHash =
    'sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
