import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:writing_assistant/core/services/ai/agent/agent_service.dart';
import 'package:writing_assistant/core/services/ai/ai_service.dart';
import 'package:writing_assistant/core/services/ai/context/context_manager.dart';
import 'package:writing_assistant/core/services/ai/tools/tool_definition.dart';
import 'package:writing_assistant/core/services/ai/tools/tool_registry.dart';

class MockAIService extends Mock implements AIService {}

class MockContextManager extends Mock implements ContextManager {}

class FakeAIRequestConfig extends Fake implements AIRequestConfig {}

class FakeChatMessageList extends Fake implements List<ChatMessage> {}

class _EchoTool extends ToolDefinition {
  @override
  String get name => 'echo';

  @override
  String get description => '回显输入内容';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'message': {'type': 'string'},
        },
        'required': ['message'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    return ToolResult.ok('echo: ${input['message']}');
  }
}

class _FailTool extends ToolDefinition {
  @override
  String get name => 'fail_tool';

  @override
  String get description => '总是失败的工具';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {},
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    return ToolResult.fail('intentional failure');
  }
}

void main() {
  late MockAIService mockAiService;
  late ToolRegistry registry;
  late MockContextManager mockContextManager;
  late AgentService agentService;

  setUpAll(() {
    registerFallbackValue(FakeAIRequestConfig());
    registerFallbackValue(FakeChatMessageList());
  });

  setUp(() {
    mockAiService = MockAIService();
    registry = ToolRegistry();
    registry.clear();
    mockContextManager = MockContextManager();

    when(() => mockContextManager.needsCompact(
          any<List<ChatMessage>>(),
          any<String>(),
        )).thenReturn(false);

    agentService = AgentService(
      aiService: mockAiService,
      toolRegistry: registry,
      contextManager: mockContextManager,
    );
  });

  tearDown(() => registry.clear());

  AIResponse _makeResponse({
    String content = '',
    List<ToolCall> toolCalls = const [],
  }) {
    return AIResponse(
      content: content,
      inputTokens: 10,
      outputTokens: 20,
      modelId: 'test-model',
      responseTime: Duration.zero,
      fromCache: false,
      toolCalls: toolCalls,
    );
  }

  group('AgentService ReAct loop', () {
    test('returns final response when no tool calls', () async {
      registry.register(_EchoTool());

      when(() => mockAiService.generateWithTools(
            prompt: any(named: 'prompt'),
            config: any(named: 'config'),
            tools: any(named: 'tools'),
          )).thenAnswer((_) async => _makeResponse(content: '这是最终回答'));

      final events = await agentService
          .run(task: '你好', workId: 'w1')
          .toList();

      expect(events, hasLength(1));
      expect(events[0], isA<AgentResponse>());
      final resp = events[0] as AgentResponse;
      expect(resp.content, '这是最终回答');
      expect(resp.iterations, 1);
    });

    test('calls tool and then returns final response', () async {
      registry.register(_EchoTool());

      var callCount = 0;
      when(() => mockAiService.generateWithTools(
            prompt: any(named: 'prompt'),
            config: any(named: 'config'),
            tools: any(named: 'tools'),
          )).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          return _makeResponse(
            content: '',
            toolCalls: [
              ToolCall(
                id: 'call_1',
                name: 'echo',
                arguments: {'message': 'hello'},
              ),
            ],
          );
        }
        return _makeResponse(content: '根据搜索结果，回答如下');
      });

      final events = await agentService
          .run(task: '搜索并回答', workId: 'w1')
          .toList();

      // 期待: AgentAction + AgentThinking + AgentObservation + AgentResponse
      expect(events.length, 4);
      expect(events[0], isA<AgentAction>());
      expect((events[0] as AgentAction).toolName, 'echo');
      expect(events[1], isA<AgentThinking>());
      expect(events[2], isA<AgentObservation>());
      final obs = events[2] as AgentObservation;
      expect(obs.result.success, isTrue);
      expect(obs.result.output, contains('hello'));
      expect(events[3], isA<AgentResponse>());

      expect(callCount, 2);
    });

    test('handles tool execution failure gracefully', () async {
      registry.register(_FailTool());

      var callCount = 0;
      when(() => mockAiService.generateWithTools(
            prompt: any(named: 'prompt'),
            config: any(named: 'config'),
            tools: any(named: 'tools'),
          )).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          return _makeResponse(
            toolCalls: [
              ToolCall(id: 'c1', name: 'fail_tool', arguments: {}),
            ],
          );
        }
        return _makeResponse(content: '工具失败了，但我来回答');
      });

      final events = await agentService
          .run(task: '测试失败工具', workId: 'w1')
          .toList();

      final observation =
          events.whereType<AgentObservation>().first;
      expect(observation.result.success, isFalse);
      expect(observation.result.error, contains('intentional failure'));

      final response = events.whereType<AgentResponse>().first;
      expect(response.content, '工具失败了，但我来回答');
    });

    test('handles unknown tool name', () async {
      registry.register(_EchoTool());

      var callCount = 0;
      when(() => mockAiService.generateWithTools(
            prompt: any(named: 'prompt'),
            config: any(named: 'config'),
            tools: any(named: 'tools'),
          )).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          return _makeResponse(
            toolCalls: [
              ToolCall(id: 'c1', name: 'nonexistent_tool', arguments: {}),
            ],
          );
        }
        return _makeResponse(content: '工具不存在');
      });

      final events = await agentService
          .run(task: '调用不存在的工具', workId: 'w1')
          .toList();

      final observation =
          events.whereType<AgentObservation>().first;
      expect(observation.result.success, isFalse);
      expect(observation.result.error, contains('不存在'));
    });

    test('emits AgentError when no tools available', () async {
      // registry is empty

      final events = await agentService
          .run(task: '没有工具可用', workId: 'w1')
          .toList();

      expect(events, hasLength(1));
      expect(events[0], isA<AgentError>());
      expect((events[0] as AgentError).error, contains('没有可用的工具'));
    });

    test('respects allowedTools filter', () async {
      registry.register(_EchoTool());
      registry.register(_FailTool());

      when(() => mockAiService.generateWithTools(
            prompt: any(named: 'prompt'),
            config: any(named: 'config'),
            tools: any(named: 'tools'),
          )).thenAnswer((_) async => _makeResponse(content: 'done'));

      final events = await agentService
          .run(task: '测试', workId: 'w1', allowedTools: ['echo'])
          .toList();

      // Should succeed — only echo tool is available
      expect(events.last, isA<AgentResponse>());

      // Verify only 1 tool schema was passed
      verify(() => mockAiService.generateWithTools(
            prompt: any(named: 'prompt'),
            config: any(named: 'config'),
            tools: any(named: 'tools'),
          )).called(1);
    });

    test('emits AgentError after max iterations', () async {
      registry.register(_EchoTool());

      when(() => mockAiService.generateWithTools(
            prompt: any(named: 'prompt'),
            config: any(named: 'config'),
            tools: any(named: 'tools'),
          )).thenAnswer((_) async => _makeResponse(
            toolCalls: [
              ToolCall(id: 'c1', name: 'echo', arguments: {'message': 'loop'}),
            ],
          ));

      final events = await agentService
          .run(task: '无限循环', workId: 'w1', maxIterations: 2)
          .toList();

      expect(events.last, isA<AgentError>());
      expect((events.last as AgentError).error, contains('最大迭代次数'));
    });
  });
}
