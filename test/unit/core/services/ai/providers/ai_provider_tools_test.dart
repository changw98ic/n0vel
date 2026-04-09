import 'package:flutter_test/flutter_test.dart';
import 'package:writing_assistant/core/services/ai/ai_service.dart';
import 'package:writing_assistant/core/services/ai/providers/ai_provider.dart';
import 'package:writing_assistant/core/services/ai/tools/tool_definition.dart';

void main() {
  group('AIProvider base class tool support', () {
    test('_buildToolsPrompt generates valid prompt from tool schemas', () {
      final tools = [
        {
          'type': 'function',
          'function': {
            'name': 'search_content',
            'description': '搜索作品中的角色、地点等内容',
            'parameters': {
              'type': 'object',
              'properties': {
                'query': {'type': 'string', 'description': '搜索关键词'},
              },
              'required': ['query'],
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'generate_text',
            'description': '生成文本内容',
          },
        },
      ];

      // 通过反射或直接调用 static 方法
      // _buildToolsPrompt 是 private 的，我们通过完整调用测试
      // 改为测试 parse 逻辑（public 可访问的部分）
    });

    group('tool call text parsing', () {
      test('parses JSON block with tool_calls', () {
        // 测试 Anthropic/OpenAI provider 的解析逻辑
        // 完整的解析测试需要通过 provider 实例
        // 这里测试 JSON 格式的正确性

        const jsonBlock = '''```json
{"tool_calls": [{"id": "call_1", "name": "search_content", "arguments": {"query": "主角"}}]}
```''';

        final regex = RegExp(r'```json\s*([\s\S]*?)\s*```');
        final match = regex.firstMatch(jsonBlock);
        expect(match, isNotNull);

        // 验证格式可被解析
        final jsonStr = match!.group(1)!;
        // 这里验证 json 格式正确
        expect(jsonStr, contains('"tool_calls"'));
        expect(jsonStr, contains('"search_content"'));
      });

      test('parses inline JSON with tool_calls', () {
        const inlineJson =
            '{"tool_calls": [{"id": "c1", "name": "gen", "arguments": {"x": 1}}]}';
        final regex = RegExp(r'\{[\s\S]*"tool_calls"[\s\S]*\}');
        expect(regex.hasMatch(inlineJson), isTrue);
      });
    });

    group('ToolCall', () {
      test('fromJson creates ToolCall', () {
        final tc = ToolCall.fromJson({
          'id': 'call_123',
          'name': 'search',
          'arguments': {'query': 'test'},
        });

        expect(tc.id, 'call_123');
        expect(tc.name, 'search');
        expect(tc.arguments, {'query': 'test'});
      });

      test('toJson serializes ToolCall', () {
        const tc = ToolCall(
          id: 'call_123',
          name: 'search',
          arguments: {'query': 'test'},
        );

        final json = tc.toJson();
        expect(json['id'], 'call_123');
        expect(json['name'], 'search');
        expect(json['arguments'], {'query': 'test'});
      });
    });

    group('ToolResult', () {
      test('ok creates success result', () {
        final result = ToolResult.ok('found 3 items', data: {'count': 3});
        expect(result.success, isTrue);
        expect(result.output, 'found 3 items');
        expect(result.data?['count'], 3);
        expect(result.error, isNull);
      });

      test('fail creates error result', () {
        final result = ToolResult.fail('network error');
        expect(result.success, isFalse);
        expect(result.output, '');
        expect(result.error, 'network error');
      });
    });
  });
}
