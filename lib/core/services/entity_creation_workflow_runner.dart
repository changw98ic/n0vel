import 'dart:convert';

import 'package:flutter/material.dart';

import 'ai/agent/agent_service.dart';
import 'ai/models/model_tier.dart' show AIFunction, ModelTier;
import 'entity_creation_service.dart';

class EntityCreationWorkflowRunner {
  final AgentService _agentService;

  EntityCreationWorkflowRunner({required AgentService agentService})
      : _agentService = agentService;

  Future<EntityCreationRequest?> parseCreationIntent(String userMessage) async {
    try {
      final response = await _agentService.orchestrate(
        task: userMessage,
        function: AIFunction.entityCreation,
        systemPrompt: _intentParsingPrompt,
        tier: ModelTier.middle,
      );

      return _parseIntentResponse(response.content);
    } catch (error) {
      debugPrint('[EntityCreationWorkflowRunner] 解析意图失败: $error');
      return null;
    }
  }

  Future<EntityCreationResult> generateEntity(
    EntityCreationRequest request,
  ) async {
    final prompt = _buildGenerationPrompt(request);

    final response = await _agentService.orchestrate(
      task: prompt,
      function: AIFunction.entityCreation,
      systemPrompt: _generationSystemPrompt,
      tier: ModelTier.middle,
    );

    return _parseEntityResponse(response.content, request.type);
  }

  EntityCreationRequest? _parseIntentResponse(String content) {
    try {
      final jsonMatch =
          RegExp(r'```json\s*([\s\S]*?)\s*```').firstMatch(content);
      final jsonStr = jsonMatch?.group(1) ?? content;
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      final typeStr = json['type'] as String? ?? 'character';
      final type = switch (typeStr) {
        'character' => EntityType.character,
        'location' => EntityType.location,
        'item' => EntityType.item,
        'faction' => EntityType.faction,
        _ => EntityType.character,
      };

      return EntityCreationRequest(
        type: type,
        name: json['name'] as String? ?? '',
        userHints: json['hints'] as Map<String, dynamic>? ?? {},
      );
    } catch (_) {
      return null;
    }
  }

  EntityCreationResult _parseEntityResponse(
    String content,
    EntityType type,
  ) {
    try {
      final jsonMatch =
          RegExp(r'```json\s*([\s\S]*?)\s*```').firstMatch(content);
      final jsonStr = jsonMatch?.group(1) ?? content;
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      return EntityCreationResult(
        type: type,
        name: json['name'] as String? ?? '',
        fields: json,
        aiRationale: json['rationale'] as String? ?? '',
      );
    } catch (_) {
      return EntityCreationResult(
        type: type,
        name: '',
        fields: const {},
        aiRationale: content,
      );
    }
  }

  String _buildGenerationPrompt(EntityCreationRequest request) {
    final buffer = StringBuffer();
    buffer.writeln('请创建以下实体：');
    buffer.writeln('类型: ${request.type.name}');
    buffer.writeln('名称: ${request.name}');
    if (request.userHints.isNotEmpty) {
      buffer.writeln('用户描述: ${request.userHints}');
    }
    if (request.workContext != null && request.workContext!.isNotEmpty) {
      buffer.writeln('作品上下文: ${request.workContext}');
    }
    return buffer.toString();
  }

  static const _intentParsingPrompt = '''
你是实体创建意图解析器。请从用户输入里识别要创建的实体类型、名称和辅助提示。
返回 JSON：
{
  "type": "character|location|item|faction",
  "name": "实体名称",
  "hints": {}
}
只返回 JSON。''';

  static const _generationSystemPrompt = '''
你是小说设定创建助手。请根据用户请求生成完整实体设定，返回 JSON。
字段可包括：name、description、bio、gender、age、identity、tier、personality、environment、significance、appearance、function、structure、goals、rationale。
只返回 JSON。''';
}
