import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:writing_assistant/core/services/ai/agent/agent_service.dart';
import 'package:writing_assistant/core/services/ai/ai_service.dart';
import 'package:writing_assistant/core/services/ai/models/model_tier.dart';
import 'package:writing_assistant/core/services/extraction_workflow_runner.dart';

class MockAgentService extends Mock implements AgentService {}

void main() {
  late MockAgentService agentService;
  late ExtractionWorkflowRunner runner;

  setUp(() {
    registerFallbackValue(AIFunction.chat);
    registerFallbackValue(ModelTier.middle);
    agentService = MockAgentService();
    runner = ExtractionWorkflowRunner(agentService: agentService);
  });

  AIResponse response(String content) => AIResponse(
    content: content,
    inputTokens: 1,
    outputTokens: 2,
    modelId: 'test-model',
    responseTime: Duration.zero,
    fromCache: false,
  );

  test('extractFromChapter parses JSON entity payload', () async {
    when(
      () => agentService.orchestrate(
        task: any(named: 'task'),
        function: any(named: 'function'),
        tier: any(named: 'tier'),
        systemPrompt: any(named: 'systemPrompt'),
      ),
    ).thenAnswer(
      (_) async => response('''
{
  "characters": [{"name":"Alice","description":"hero"}],
  "locations": [{"name":"Town","description":"small town"}],
  "items": [{"name":"Sword","description":"sharp"}]
}
'''),
    );

    final result = await runner.extractFromChapter(
      chapterContent: 'chapter body',
      workId: 'work-1',
    );

    expect(result.characters.single.name, 'Alice');
    expect(result.locations.single.name, 'Town');
    expect(result.items.single.name, 'Sword');
  });
}
