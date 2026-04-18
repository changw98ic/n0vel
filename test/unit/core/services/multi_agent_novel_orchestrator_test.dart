import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:writing_assistant/core/services/ai/agent/agent_service.dart';
import 'package:writing_assistant/core/services/ai/ai_service.dart';
import 'package:writing_assistant/core/services/ai/models/model_tier.dart';
import 'package:writing_assistant/core/services/multi_agent_novel_orchestrator.dart';
import 'package:writing_assistant/core/services/writer_guidance_loader.dart';

class MockAgentService extends Mock implements AgentService {}

class MockWriterGuidanceLoader extends Mock implements WriterGuidanceLoader {}

void main() {
  setUpAll(() {
    registerFallbackValue(AIFunction.continuation);
    registerFallbackValue(ModelTier.middle);
  });

  group('MultiAgentNovelOrchestrator', () {
    late MockAgentService mockAgentService;
    late MockWriterGuidanceLoader mockGuidanceLoader;
    late MultiAgentNovelOrchestrator orchestrator;

    setUp(() {
      mockAgentService = MockAgentService();
      mockGuidanceLoader = MockWriterGuidanceLoader();
      when(
        () => mockGuidanceLoader.loadTeamGuidance(any()),
      ).thenAnswer((_) async => 'team guidance');
      orchestrator = MultiAgentNovelOrchestrator(
        agentService: mockAgentService,
        guidanceLoader: mockGuidanceLoader,
      );
    });

    test('runs tasks in parallel and preserves task ids', () async {
      when(
        () => mockAgentService.orchestrate(
          task: any(named: 'task'),
          function: any(named: 'function'),
          tier: any(named: 'tier'),
          systemPrompt: any(named: 'systemPrompt'),
        ),
      ).thenAnswer((invocation) async {
        final prompt = invocation.namedArguments[#task] as String;
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return AIResponse(
          content: 'done:$prompt',
          inputTokens: 1,
          outputTokens: 1,
          modelId: 'test-model',
          responseTime: Duration.zero,
          fromCache: false,
        );
      });

      final stopwatch = Stopwatch()..start();
      final results = await orchestrator.runParallel([
        const ParallelAgentTask(id: 'a', prompt: 'chapter-a'),
        const ParallelAgentTask(id: 'b', prompt: 'chapter-b'),
        const ParallelAgentTask(id: 'c', prompt: 'chapter-c'),
      ]);
      stopwatch.stop();

      expect(results.map((result) => result.id), ['a', 'b', 'c']);
      expect(results.map((result) => result.content), [
        'done:chapter-a',
        'done:chapter-b',
        'done:chapter-c',
      ]);
      expect(stopwatch.elapsedMilliseconds, lessThan(220));
      verify(
        () => mockAgentService.orchestrate(
          task: any(named: 'task'),
          function: AIFunction.continuation,
          tier: ModelTier.middle,
          systemPrompt: any(named: 'systemPrompt'),
        ),
      ).called(3);
    });

    test('injects team guidance when team id is provided', () async {
      String? capturedSystemPrompt;
      when(
        () => mockAgentService.orchestrate(
          task: any(named: 'task'),
          function: any(named: 'function'),
          tier: any(named: 'tier'),
          systemPrompt: any(named: 'systemPrompt'),
        ),
      ).thenAnswer((invocation) async {
        capturedSystemPrompt =
            invocation.namedArguments[#systemPrompt] as String?;
        return AIResponse(
          content: 'ok',
          inputTokens: 1,
          outputTokens: 1,
          modelId: 'test-model',
          responseTime: Duration.zero,
          fromCache: false,
        );
      });

      await orchestrator.runParallel(const [
        ParallelAgentTask(id: 'a', prompt: 'chapter-a', systemPrompt: 'base'),
      ], teamId: 'longform-book-team');

      expect(capturedSystemPrompt, contains('team guidance'));
    });
  });
}
