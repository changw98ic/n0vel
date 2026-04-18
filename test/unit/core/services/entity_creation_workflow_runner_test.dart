import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:writing_assistant/core/services/ai/agent/agent_service.dart';
import 'package:writing_assistant/core/services/ai/ai_service.dart';
import 'package:writing_assistant/core/services/ai/models/model_tier.dart';
import 'package:writing_assistant/core/services/entity_creation_service.dart';
import 'package:writing_assistant/core/services/entity_creation_workflow_runner.dart';

class MockAgentService extends Mock implements AgentService {}

void main() {
  late MockAgentService agentService;
  late EntityCreationWorkflowRunner runner;

  setUp(() {
    registerFallbackValue(AIFunction.chat);
    registerFallbackValue(ModelTier.middle);
    agentService = MockAgentService();
    runner = EntityCreationWorkflowRunner(agentService: agentService);
  });

  AIResponse response(String content) => AIResponse(
    content: content,
    inputTokens: 1,
    outputTokens: 2,
    modelId: 'test-model',
    responseTime: Duration.zero,
    fromCache: false,
  );

  test('parseCreationIntent parses structured intent JSON', () async {
    when(
      () => agentService.orchestrate(
        task: any(named: 'task'),
        function: any(named: 'function'),
        tier: any(named: 'tier'),
        systemPrompt: any(named: 'systemPrompt'),
      ),
    ).thenAnswer(
      (_) async => response(
        '{"type":"character","name":"Alice","hints":{"gender":"female"}}',
      ),
    );

    final result = await runner.parseCreationIntent('create Alice');

    expect(result, isNotNull);
    expect(result!.type, EntityType.character);
    expect(result.name, 'Alice');
    expect(result.userHints['gender'], 'female');
  });

  test('generateEntity parses generated entity JSON', () async {
    when(
      () => agentService.orchestrate(
        task: any(named: 'task'),
        function: any(named: 'function'),
        tier: any(named: 'tier'),
        systemPrompt: any(named: 'systemPrompt'),
      ),
    ).thenAnswer(
      (_) async =>
          response('{"name":"Alice","description":"hero","tier":"supporting"}'),
    );

    final result = await runner.generateEntity(
      const EntityCreationRequest(type: EntityType.character, name: 'Alice'),
    );

    expect(result.type, EntityType.character);
    expect(result.name, 'Alice');
    expect(result.fields['description'], 'hero');
  });
}
