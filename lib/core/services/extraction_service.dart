import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../features/settings/data/character_repository.dart';
import '../../features/settings/data/item_repository.dart';
import '../../features/settings/data/location_repository.dart';
import '../../features/settings/domain/character.dart' as character_domain;
import 'ai/ai_service.dart';
import 'ai/models/model_tier.dart';

// ---------------------------------------------------------------------------
// Domain models
// ---------------------------------------------------------------------------

class ExtractionResult {
  final List<ExtractedEntity> characters;
  final List<ExtractedEntity> locations;
  final List<ExtractedEntity> items;

  const ExtractionResult({
    this.characters = const [],
    this.locations = const [],
    this.items = const [],
  });

  int get totalCount => characters.length + locations.length + items.length;

  factory ExtractionResult.empty() => const ExtractionResult();
}

class ExtractedEntity {
  final String name;
  final String type; // character / location / item
  final String description;
  final Map<String, dynamic> attributes;
  final String sourceExcerpt;

  const ExtractedEntity({
    required this.name,
    required this.type,
    this.description = '',
    this.attributes = const {},
    this.sourceExcerpt = '',
  });
}

class NewEntityCandidate {
  final ExtractedEntity entity;
  final bool isNew;
  final String? existingEntityId;
  final double confidence;
  bool accepted;

  NewEntityCandidate({
    required this.entity,
    this.isNew = true,
    this.existingEntityId,
    this.confidence = 1.0,
    this.accepted = false,
  });
}

// ---------------------------------------------------------------------------
// ExtractionService
// ---------------------------------------------------------------------------

/// 提取服务
/// 从章节文本中提取角色、地点、物品等实体信息
class ExtractionService extends GetxService {
  final AIService _aiService;
  final CharacterRepository _characterRepository;
  final LocationRepository _locationRepository;
  final ItemRepository _itemRepository;

  ExtractionService({
    required AIService aiService,
    required CharacterRepository characterRepository,
    required LocationRepository locationRepository,
    required ItemRepository itemRepository,
  })  : _aiService = aiService,
        _characterRepository = characterRepository,
        _locationRepository = locationRepository,
        _itemRepository = itemRepository;

  /// 从章节内容提取实体
  Future<ExtractionResult> extractFromChapter({
    required String chapterContent,
    required String workId,
  }) async {
    // 截取内容避免超出 token 限制
    final content = chapterContent.length > 6000
        ? '${chapterContent.substring(0, 6000)}...'
        : chapterContent;

    final response = await _aiService.generate(
      prompt: content,
      config: AIRequestConfig(
        function: AIFunction.entityExtraction,
        systemPrompt: _extractionSystemPrompt,
        userPrompt: '请从以下文本中提取角色、地点和物品等实体信息：\n\n$content',
        useCache: false,
        stream: false,
      ),
    );

    return _deduplicateResult(_parseExtractionResponse(response.content));
  }

  /// 对比已有实体，找出新实体
  Future<List<NewEntityCandidate>> findNewEntities(
    ExtractionResult result,
    String workId,
  ) async {
    final candidates = <NewEntityCandidate>[];

    // 加载已有实体
    final existingCharacters =
        await _characterRepository.getCharactersByWorkId(workId);
    final existingLocations =
        await _locationRepository.getLocationsByWorkId(workId);
    final existingItems = await _itemRepository.getItemsByWorkId(workId);

    // 对比角色
    for (final entity in result.characters) {
      final match = _findSimilarName(
        entity.name,
        existingCharacters.map((c) => c.name).toList(),
      );
      candidates.add(NewEntityCandidate(
        entity: entity,
        isNew: match == null,
        existingEntityId: match,
        confidence: match == null ? 1.0 : 0.9,
        accepted: match == null,
      ));
    }

    // 对比地点
    for (final entity in result.locations) {
      final match = _findSimilarName(
        entity.name,
        existingLocations.map((l) => l.name).toList(),
      );
      candidates.add(NewEntityCandidate(
        entity: entity,
        isNew: match == null,
        confidence: match == null ? 1.0 : 0.9,
        accepted: match == null,
      ));
    }

    // 对比物品
    for (final entity in result.items) {
      final match = _findSimilarName(
        entity.name,
        existingItems.map((i) => i.name).toList(),
      );
      candidates.add(NewEntityCandidate(
        entity: entity,
        isNew: match == null,
        confidence: match == null ? 1.0 : 0.9,
        accepted: match == null,
      ));
    }

    return candidates;
  }

  /// 保存用户接受的实体
  Future<int> saveAcceptedEntities(
    List<NewEntityCandidate> candidates,
    String workId,
  ) async {
    var saved = 0;

    for (final candidate in candidates) {
      if (!candidate.accepted || !candidate.isNew) continue;

      try {
        switch (candidate.entity.type) {
          case 'character':
            await _characterRepository.createCharacter(
              character_domain.CreateCharacterParams(
                workId: workId,
                name: candidate.entity.name,
                tier: character_domain.CharacterTier.supporting,
                gender: candidate.entity.attributes['gender'] as String?,
                bio: candidate.entity.description,
              ),
            );
          case 'location':
            await _locationRepository.createLocation(
              workId: workId,
              name: candidate.entity.name,
              description: candidate.entity.description,
            );
          case 'item':
            await _itemRepository.createItem(
              workId: workId,
              name: candidate.entity.name,
              description: candidate.entity.description,
            );
        }
        saved++;
      } catch (e) {
        debugPrint('[ExtractionService] 保存实体失败: $e');
      }
    }

    return saved;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  ExtractionResult _parseExtractionResponse(String content) {
    try {
      // 尝试从 AI 回复中提取 JSON
      final jsonMatch = RegExp(r'```json\s*([\s\S]*?)\s*```').firstMatch(content);
      final jsonStr = jsonMatch?.group(1) ?? content;

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      return ExtractionResult(
        characters: _parseEntities(json, 'characters', 'character'),
        locations: _parseEntities(json, 'locations', 'location'),
        items: _parseEntities(json, 'items', 'item'),
      );
    } catch (e) {
      debugPrint('[ExtractionService] 解析提取结果失败: $e');
      return ExtractionResult.empty();
    }
  }

  List<ExtractedEntity> _parseEntities(
    Map<String, dynamic> json,
    String key,
    String type,
  ) {
    final list = json[key] as List<dynamic>?;
    if (list == null) return [];

    return list
        .map((item) {
          try {
            final map = item as Map<String, dynamic>;
            return ExtractedEntity(
              name: map['name'] as String? ?? '',
              type: type,
              description: map['description'] as String? ?? '',
              attributes: map['attributes'] as Map<String, dynamic>? ?? {},
              sourceExcerpt: map['source_excerpt'] as String? ?? '',
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<ExtractedEntity>()
        .toList();
  }

  /// 查找相似名称（三级匹配策略）
  /// 1. 精确匹配：完全相同
  /// 2. 包含匹配：一个名称包含另一个
  /// 3. 核心词匹配：去掉常见后缀词后比较
  String? _findSimilarName(String name, List<String> existingNames) {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    // 第一级：精确匹配
    for (final existing in existingNames) {
      if (existing.trim().toLowerCase() == normalized) {
        return existing;
      }
    }

    // 第二级：包含匹配（短名包含在长名中）
    for (final existing in existingNames) {
      final existingLower = existing.trim().toLowerCase();
      if (existingLower.length >= 2 &&
          (normalized.contains(existingLower) ||
              existingLower.contains(normalized))) {
        return existing;
      }
    }

    // 第三级：核心词匹配
    final nameCore = _extractCore(normalized);
    if (nameCore.length >= 2) {
      for (final existing in existingNames) {
        final existingCore = _extractCore(existing.trim().toLowerCase());
        if (existingCore.length >= 2 && existingCore == nameCore) {
          return existing;
        }
      }
    }

    return null;
  }

  /// 提取名称核心词（去掉常见修饰后缀）
  static const _suffixes = ['大楼', '公司', '大厦', '中心', '广场', '区域', '地带'];
  static const _prefixes = ['公司', '集团', '学校', '城市'];

  String _extractCore(String name) {
    var core = name;
    for (final suffix in _suffixes) {
      if (core.endsWith(suffix)) {
        core = core.substring(0, core.length - suffix.length);
      }
    }
    for (final prefix in _prefixes) {
      if (core.startsWith(prefix)) {
        core = core.substring(prefix.length);
      }
    }
    return core.trim();
  }

  /// 对提取结果内部去重（同一类型中相似名称只保留第一个）
  ExtractionResult _deduplicateResult(ExtractionResult result) {
    return ExtractionResult(
      characters: _deduplicateEntities(result.characters),
      locations: _deduplicateEntities(result.locations),
      items: _deduplicateEntities(result.items),
    );
  }

  List<ExtractedEntity> _deduplicateEntities(List<ExtractedEntity> entities) {
    final seen = <String>[];
    final unique = <ExtractedEntity>[];
    for (final entity in entities) {
      final normalized = entity.name.trim().toLowerCase();
      if (normalized.isEmpty) continue;

      // 检查是否与已保留的实体相似
      bool isDuplicate = false;
      for (final existing in seen) {
        if (_isSimilarName(normalized, existing)) {
          isDuplicate = true;
          break;
        }
      }

      if (!isDuplicate) {
        seen.add(normalized);
        unique.add(entity);
      }
    }
    return unique;
  }

  /// 判断两个名称是否相似
  bool _isSimilarName(String a, String b) {
    if (a == b) return true;
    if (a.length >= 2 && (a.contains(b) || b.contains(a))) return true;
    if (_extractCore(a) == _extractCore(b) &&
        _extractCore(a).length >= 2) {
      return true;
    }
    return false;
  }

  static const _extractionSystemPrompt =
      '你是一位专业的小说设定提取助手。请从用户提供的文本中提取所有命名实体，'
      '包括角色、地点和物品。对每个实体提供名称、简短描述和出现位置。\n\n'
      '请以 JSON 格式输出，结构如下：\n'
      '```json\n'
      '{\n'
      '  "characters": [{"name": "角色名", "description": "描述", "attributes": {"gender": "性别"}, "source_excerpt": "原文片段"}],\n'
      '  "locations": [{"name": "地名", "description": "描述"}],\n'
      '  "items": [{"name": "物品名", "description": "描述"}]\n'
      '}\n'
      '```\n\n'
      '注意：\n'
      '- 只提取有名字的具体实体，不提取泛指\n'
      '- 描述尽量简洁（50字以内）\n'
      '- 如果文本中没有某类实体，返回空数组';
}
