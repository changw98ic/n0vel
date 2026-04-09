import '../../search_service.dart';
import 'tool_definition.dart';

/// 搜索工具
/// 在作品中搜索角色、地点、物品、章节等内容
class SearchTool extends ToolDefinition {
  final Future<List<Map<String, String>>> Function(
    String workId,
    String query,
    String type,
  ) _searchFn;

  SearchTool({required Future<List<Map<String, String>>> Function(
    String workId,
    String query,
    String type,
  ) searchFn}) : _searchFn = searchFn;

  /// 便捷构造：使用 SearchService
  factory SearchTool.withSearchService(SearchService searchService) {
    return SearchTool(
      searchFn: (workId, query, type) async {
        final results = await _searchByType(searchService, workId, query, type);
        return results
            .map((item) => {
                  'name': item.title,
                  'description': item.subtitle ?? '',
                  'id': item.id,
                  'type': item.type.name,
                })
            .toList();
      },
    );
  }

  static Future<List<SearchResultItem>> _searchByType(
    SearchService service,
    String workId,
    String query,
    String type,
  ) {
    return switch (type) {
      'character' => service.searchCharacters(workId, query),
      'location' => service.searchLocations(workId, query),
      'item' => service.searchItems(workId, query),
      'faction' => service.searchFactions(workId, query),
      'chapter' => service.searchChapters(workId, query),
      _ => service.searchAll(query: query, workId: workId),
    };
  }

  @override
  String get name => 'search_content';

  @override
  String get description => '搜索作品中的角色、地点、物品、章节等内容。'
      '可以按类型搜索，也可以全文搜索。';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'work_id': {
            'type': 'string',
            'description': '作品 ID',
          },
          'query': {
            'type': 'string',
            'description': '搜索关键词',
          },
          'type': {
            'type': 'string',
            'enum': ['character', 'location', 'item', 'faction', 'chapter', 'all'],
            'description': '搜索类型，默认 all',
          },
        },
        'required': ['work_id', 'query'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final workId = input['work_id'] as String?;
    final query = input['query'] as String?;
    final type = input['type'] as String? ?? 'all';

    if (workId == null || query == null) {
      return ToolResult.fail('缺少必要参数: work_id 和 query');
    }

    try {
      final results = await _searchFn(workId, query, type);
      if (results.isEmpty) {
        return ToolResult.ok('未找到与 "$query" 相关的${_typeLabel(type)}内容。');
      }

      final buffer = StringBuffer();
      buffer.writeln('搜索结果（${_typeLabel(type)}，关键词: "$query"）：');
      for (final r in results) {
        buffer.writeln('- ${r['name'] ?? r['title'] ?? '未知'}: ${r['description'] ?? r['content']?.toString().substring(0, (r['content']?.toString().length ?? 100).clamp(0, 200)) ?? ''}');
      }
      return ToolResult.ok(buffer.toString(), data: {'results': results});
    } catch (e) {
      return ToolResult.fail('搜索失败: $e');
    }
  }

  String _typeLabel(String type) => switch (type) {
        'character' => '角色',
        'location' => '地点',
        'item' => '物品',
        'faction' => '势力',
        'chapter' => '章节',
        _ => '',
      };
}
