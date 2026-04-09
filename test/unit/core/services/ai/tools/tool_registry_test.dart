import 'package:flutter_test/flutter_test.dart';
import 'package:writing_assistant/core/services/ai/tools/tool_definition.dart';
import 'package:writing_assistant/core/services/ai/tools/tool_registry.dart';

void main() {
  group('ToolDefinition', () {
    test('toFunctionSchema returns OpenAI function calling format', () {
      final tool = _FakeTool(
        name: 'search',
        description: '搜索内容',
        inputSchema: {
          'type': 'object',
          'properties': {
            'query': {'type': 'string', 'description': '关键词'},
          },
          'required': ['query'],
        },
      );

      final schema = tool.toFunctionSchema();

      expect(schema['type'], 'function');
      final func = schema['function'] as Map<String, dynamic>;
      expect(func['name'], 'search');
      expect(func['description'], '搜索内容');
      expect((func['parameters'] as Map)['required'], ['query']);
    });
  });

  group('ToolRegistry', () {
    late ToolRegistry registry;

    setUp(() {
      registry = ToolRegistry();
      registry.clear();
    });

    tearDown(() => registry.clear());

    test('register and get tool', () {
      final tool = _FakeTool(name: 'search', description: '搜索');
      registry.register(tool);

      expect(registry.get('search'), same(tool));
    });

    test('get returns null for unregistered tool', () {
      expect(registry.get('nonexistent'), isNull);
    });

    test('all returns all registered tools', () {
      registry.register(_FakeTool(name: 'a', description: 'A'));
      registry.register(_FakeTool(name: 'b', description: 'B'));

      expect(registry.all.length, 2);
      expect(registry.names, containsAll(['a', 'b']));
    });

    test('toFunctionCallSchema returns schema for all tools', () {
      registry.register(_FakeTool(
        name: 'search',
        description: '搜索',
        inputSchema: {'type': 'object'},
      ));
      registry.register(_FakeTool(
        name: 'generate',
        description: '生成',
        inputSchema: {'type': 'object'},
      ));

      final schemas = registry.toFunctionCallSchema();
      expect(schemas.length, 2);
      expect(
        schemas.map((s) => (s['function'] as Map)['name']),
        containsAll(['search', 'generate']),
      );
    });

    test('register overwrites tool with same name', () {
      registry.register(_FakeTool(name: 'tool', description: 'v1'));
      registry.register(_FakeTool(name: 'tool', description: 'v2'));

      expect(registry.get('tool')!.description, 'v2');
      expect(registry.all.length, 1);
    });
  });
}

class _FakeTool extends ToolDefinition {
  @override
  final String name;
  @override
  final String description;
  @override
  final Map<String, dynamic> inputSchema;

  _FakeTool({
    required this.name,
    required this.description,
    this.inputSchema = const {},
  });

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    return ToolResult.ok('fake result');
  }
}
