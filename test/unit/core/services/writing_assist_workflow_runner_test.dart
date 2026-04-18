import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:writing_assistant/core/services/ai/agent/agent_service.dart';
import 'package:writing_assistant/core/services/ai/ai_service.dart';
import 'package:writing_assistant/core/services/ai/models/model_tier.dart';
import 'package:writing_assistant/core/services/writing_assist_workflow_runner.dart';

class MockAgentService extends Mock implements AgentService {}

void main() {
  late MockAgentService agentService;
  late WritingAssistWorkflowRunner runner;

  setUp(() {
    registerFallbackValue(AIFunction.chat);
    registerFallbackValue(ModelTier.middle);
    agentService = MockAgentService();
    runner = WritingAssistWorkflowRunner(agentService: agentService);
  });

  AIResponse response(String content) => AIResponse(
    content: content,
    inputTokens: 1,
    outputTokens: 2,
    modelId: 'test-model',
    responseTime: Duration.zero,
    fromCache: false,
  );

  test('generateContinuation delegates to AI service', () async {
    when(
      () => agentService.orchestrate(
        task: any(named: 'task'),
        function: any(named: 'function'),
        tier: any(named: 'tier'),
        systemPrompt: any(named: 'systemPrompt'),
      ),
    ).thenAnswer((_) async => response('continued text'));

    final result = await runner.generateContinuation('chapter body');

    expect(result, 'continued text');
  });

  test('suggestContinuations parses numbered suggestions', () async {
    when(
      () => agentService.orchestrate(
        task: any(named: 'task'),
        function: any(named: 'function'),
        tier: any(named: 'tier'),
        systemPrompt: any(named: 'systemPrompt'),
      ),
    ).thenAnswer((_) async => response('1. Alpha\n2. Beta\n3. Gamma'));

    final result = await runner.suggestContinuations(
      precedingText: 'body',
      count: 3,
    );

    expect(result, ['Alpha', 'Beta', 'Gamma']);
  });
}
