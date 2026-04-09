import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../features/settings/data/character_repository.dart';
import '../../features/settings/data/faction_repository.dart';
import '../../features/settings/data/item_repository.dart';
import '../../features/settings/data/location_repository.dart';
import '../../features/settings/domain/character.dart' as character_domain;
import 'ai/ai_service.dart';
import 'ai/models/model_tier.dart';

// ---------------------------------------------------------------------------
// Domain models
// ---------------------------------------------------------------------------

enum EntityType { character, location, item, faction }

class EntityCreationRequest {
  final EntityType type;
  final String name;
  final Map<String, dynamic> userHints;
  final String? workContext;

  const EntityCreationRequest({
    required this.type,
    required this.name,
    this.userHints = const {},
    this.workContext,
  });
}

class EntityCreationResult {
  final EntityType type;
  final String name;
  final Map<String, dynamic> fields;
  final String aiRationale;

  const EntityCreationResult({
    required this.type,
    required this.name,
    required this.fields,
    this.aiRationale = '',
  });
}

// ---------------------------------------------------------------------------
// EntityCreationService
// ---------------------------------------------------------------------------

/// AI 实体创建服务
/// 从自然语言描述生成完整实体设定
class EntityCreationService extends GetxService {
  final AIService _aiService;
  final CharacterRepository _characterRepository;
  final LocationRepository _locationRepository;
  final ItemRepository _itemRepository;
  final FactionRepository _factionRepository;

  EntityCreationService({
    required AIService aiService,
    required CharacterRepository characterRepository,
    required LocationRepository locationRepository,
    required ItemRepository itemRepository,
    required FactionRepository factionRepository,
  })  : _aiService = aiService,
        _characterRepository = characterRepository,
        _locationRepository = locationRepository,
        _itemRepository = itemRepository,
        _factionRepository = factionRepository;

  /// 解析用户意图：判断要创建什么类型的实体，提取关键属性
  Future<EntityCreationRequest?> parseCreationIntent(
      String userMessage) async {
    try {
      final response = await _aiService.generate(
        prompt: userMessage,
        config: AIRequestConfig(
          function: AIFunction.entityCreation,
          systemPrompt: _intentParsingPrompt,
          userPrompt: userMessage,
          useCache: false,
          stream: false,
        ),
      );

      return _parseIntentResponse(response.content);
    } catch (e) {
      debugPrint('[EntityCreationService] 解析意图失败: $e');
      return null;
    }
  }

  /// 生成完整实体设定
  Future<EntityCreationResult> generateEntity(
      EntityCreationRequest request) async {
    final prompt = _buildGenerationPrompt(request);

    final response = await _aiService.generate(
      prompt: prompt,
      config: AIRequestConfig(
        function: AIFunction.entityCreation,
        systemPrompt: _generationSystemPrompt,
        userPrompt: prompt,
        useCache: false,
        stream: false,
      ),
    );

    return _parseEntityResponse(response.content, request.type);
  }

  /// 保存实体到数据库
  Future<String> saveEntity(EntityCreationResult result, String workId) async {
    switch (result.type) {
      case EntityType.character:
        final character = await _characterRepository.createCharacter(
          character_domain.CreateCharacterParams(
            workId: workId,
            name: result.name,
            tier: _parseTier(result.fields['tier'] as String?),
            gender: result.fields['gender'] as String?,
            age: result.fields['age'] as String?,
            identity: result.fields['identity'] as String?,
            bio: result.fields['bio'] as String? ??
                result.fields['description'] as String?,
          ),
        );
        return character.id;

      case EntityType.location:
        final location = await _locationRepository.createLocation(
          workId: workId,
          name: result.name,
          description:
              result.fields['description'] as String? ?? result.fields['bio'] as String?,
        );
        return location.id;

      case EntityType.item:
        final item = await _itemRepository.createItem(
          workId: workId,
          name: result.name,
          description:
              result.fields['description'] as String? ?? result.fields['bio'] as String?,
        );
        return item.id;

      case EntityType.faction:
        final faction = await _factionRepository.createFaction(
          workId: workId,
          name: result.name,
          description:
              result.fields['description'] as String? ?? result.fields['bio'] as String?,
        );
        return faction.id;
    }
  }

  /// 检测 AI 回复中是否包含实体创建结构化数据
  /// 格式：```entity\n{...}\n```
  static EntityCreationResult? detectEntityInResponse(String content) {
    final match = RegExp(r'```entity\s*([\s\S]*?)\s*```').firstMatch(content);
    if (match == null) return null;

    try {
      final json = jsonDecode(match.group(1)!) as Map<String, dynamic>;
      final typeStr = json['type'] as String? ?? 'character';
      final type = switch (typeStr) {
        'character' => EntityType.character,
        'location' => EntityType.location,
        'item' => EntityType.item,
        'faction' => EntityType.faction,
        _ => EntityType.character,
      };

      return EntityCreationResult(
        type: type,
        name: json['name'] as String? ?? '',
        fields: json['fields'] as Map<String, dynamic>? ?? json,
      );
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

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
      String content, EntityType type) {
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
        fields: {},
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
    return buffer.toString();
  }

  character_domain.CharacterTier _parseTier(String? tier) {
    if (tier == null) return character_domain.CharacterTier.supporting;
    return character_domain.CharacterTier.values.firstWhere(
      (t) => t.name.toLowerCase() == tier.toLowerCase(),
      orElse: () => character_domain.CharacterTier.supporting,
    );
  }

  static const _intentParsingPrompt =
      '你是一个意图识别助手。判断用户是否想创建小说中的实体（角色、地点、物品或势力）。\n'
      '如果是，请用 JSON 格式回复：\n'
      '```json\n'
      '{"is_creation": true, "type": "character/location/item/faction", "name": "实体名", "hints": {"key": "value"}}\n'
      '```\n'
      '如果不是创建意图，回复：\n'
      '```json\n'
      '{"is_creation": false}\n'
      '```';

  static const _generationSystemPrompt =
      '你是一位专业的小说设定创建助手。根据用户的描述生成完整、详细的实体设定。\n'
      '请用 JSON 格式输出，包含以下字段：\n'
      '- name: 名称\n'
      '- description/bio: 详细描述\n'
      '- 其他相关属性（如角色：gender, age, identity, tier, personality；'
      '地点：environment, significance；物品：appearance, function；势力：structure, goals）\n\n'
      '请用以下格式输出：\n'
      '```json\n'
      '{"name": "...", "bio": "...", ...}\n'
      '```';
}
