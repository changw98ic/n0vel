import 'dart:convert';

import 'ai/ai_service.dart';
import 'ai/models/model_tier.dart';
part 'character_simulation_prompt_helpers.dart';
part 'character_simulation_parsing_helpers.dart';

/// 角色模拟结果
class SimulationResult {
  final String characterName;
  final String reaction;
  final String? dialogue;
  final String? innerThought;
  final String? emotionalState;
  final int inputTokens;
  final int outputTokens;

  const SimulationResult({
    required this.characterName,
    required this.reaction,
    this.dialogue,
    this.innerThought,
    this.emotionalState,
    required this.inputTokens,
    required this.outputTokens,
  });
}

/// 场景上下文
class SimulationContext {
  final String sceneDescription;
  final String? precedingEvents;
  final List<String>? presentCharacters;
  final String? locationName;
  final String? timeOfDay;
  final String? atmosphere;

  const SimulationContext({
    required this.sceneDescription,
    this.precedingEvents,
    this.presentCharacters,
    this.locationName,
    this.timeOfDay,
    this.atmosphere,
  });
}

/// 对话行
class DialogueLine {
  final String characterName;
  final String dialogue;
  final String? stageDirection;
  final String? innerThought;

  const DialogueLine({
    required this.characterName,
    required this.dialogue,
    this.stageDirection,
    this.innerThought,
  });
}

/// 角色简要档案（用于对话模拟）
class SimCharacterProfile {
  final String name;
  final String? personality;
  final String? speechStyle;
  final String? coreValues;
  final String? currentMood;

  const SimCharacterProfile({
    required this.name,
    this.personality,
    this.speechStyle,
    this.coreValues,
    this.currentMood,
  });
}

/// OOC 分析结果
class OOCAnalysis {
  final bool isOOC;
  final double confidence;
  final String? explanation;
  final String? suggestion;

  const OOCAnalysis({
    required this.isOOC,
    required this.confidence,
    this.explanation,
    this.suggestion,
  });
}

/// 角色模拟服务
/// 根据角色设定和场景上下文，模拟角色的行为、对话和心理活动
class CharacterSimulationService {
  final AIService _aiService;

  CharacterSimulationService({required AIService aiService})
      : _aiService = aiService;

  // ---------------------------------------------------------------------------
  // simulateCharacter
  // ---------------------------------------------------------------------------

  /// 模拟单个角色在场景中的反应
  Future<SimulationResult> simulateCharacter({
    required String characterName,
    required String characterProfile,
    required SimulationContext context,
    required String workId,
  }) async {
    try {
      final profileSection = _buildProfileSection(characterProfile);
      final contextSection = _buildContextSection(context);
      final promptBundle = _buildSimulationPromptBundle(
        characterName: characterName,
        profileSection: profileSection,
        contextSection: contextSection,
      );

      final config = AIRequestConfig(
        function: AIFunction.characterSimulation,
        systemPrompt: promptBundle.systemPrompt,
        userPrompt: promptBundle.userPrompt,
        temperature: 0.75,
        maxTokens: 1500,
        stream: false,
      );

      final response = await _aiService.generate(
        prompt: promptBundle.userPrompt,
        config: config,
      );

      final parsed = _parseSimulationResponse(response.content);
      return SimulationResult(
        characterName: characterName,
        reaction: parsed['reaction'] ?? _simulationFallbackReaction,
        dialogue: parsed['dialogue'],
        innerThought: parsed['innerThought'],
        emotionalState: parsed['emotionalState'],
        inputTokens: response.inputTokens,
        outputTokens: response.outputTokens,
      );
    } catch (e) {
      return SimulationResult(
        characterName: characterName,
        reaction: _buildSimulationFailureReaction(e),
        inputTokens: 0,
        outputTokens: 0,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // simulateDialogue
  // ---------------------------------------------------------------------------

  /// 模拟角色间对话
  Future<List<DialogueLine>> simulateDialogue({
    required List<SimCharacterProfile> characters,
    required SimulationContext context,
    required String topic,
    int turns = 4,
    required String workId,
  }) async {
    if (characters.isEmpty) return [];
    if (characters.length == 1) {
      return _simulateMonologue(characters.first, context, topic, workId);
    }

    try {
      final charactersSection = _buildCharactersSection(characters);
      final contextSection = _buildContextSection(context);
      final promptBundle = _buildDialoguePromptBundle(
        turns: turns,
        topic: topic,
        charactersSection: charactersSection,
        contextSection: contextSection,
      );

      final config = AIRequestConfig(
        function: AIFunction.characterSimulation,
        systemPrompt: promptBundle.systemPrompt,
        userPrompt: promptBundle.userPrompt,
        temperature: 0.85,
        maxTokens: 2500,
        stream: false,
      );

      final response = await _aiService.generate(
        prompt: promptBundle.userPrompt,
        config: config,
      );

      return _parseDialogueLines(response.content);
    } catch (e) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // analyzeCharacterBehavior (OOC detection)
  // ---------------------------------------------------------------------------

  /// 检测角色行为是否符合设定（OOC检测辅助）
  Future<OOCAnalysis> analyzeCharacterBehavior({
    required String characterName,
    required String characterProfile,
    required String textToAnalyze,
    required String workId,
  }) async {
    try {
      final profileSection = _buildProfileSection(characterProfile);
      final promptBundle = _buildOocPromptBundle(
        characterName: characterName,
        profileSection: profileSection,
        textToAnalyze: textToAnalyze,
      );

      final config = AIRequestConfig(
        function: AIFunction.oocDetection,
        systemPrompt: promptBundle.systemPrompt,
        userPrompt: promptBundle.userPrompt,
        temperature: 0.3,
        maxTokens: 1200,
        stream: false,
      );

      final response = await _aiService.generate(
        prompt: promptBundle.userPrompt,
        config: config,
      );

      return _parseOOCAnalysis(response.content);
    } catch (e) {
      return OOCAnalysis(
        isOOC: false,
        confidence: 0.0,
        explanation: 'OOC 分析失败：',
      );
    }
  }

  // ===========================================================================
  // Private helpers
  // ===========================================================================

  /// 从 JSON 字符串构建可读的角色档案段落
  String _buildProfileSection(String characterProfileJson) =>
      buildCharacterSimulationProfileSection(characterProfileJson);

  /// 从 SimulationContext 构建可读的场景信息段落
  String _buildContextSection(SimulationContext context) =>
      buildCharacterSimulationContextSection(context);

  /// 解析 simulateCharacter 的 AI 回复为结构化数据
  Map<String, String?> _parseSimulationResponse(String content) =>
      parseCharacterSimulationResponse(content);

  /// 解析 simulateDialogue 的 AI 回复为 DialogueLine 列表
  List<DialogueLine> _parseDialogueLines(String content) =>
      parseCharacterSimulationDialogueLines(content);

  /// 解析 OOC 分析的 AI 回复
  OOCAnalysis _parseOOCAnalysis(String content) =>
      parseCharacterSimulationOocAnalysis(content);

  /// 从文本内容中提取 JSON 块
  String? _extractJsonBlock(String content) =>
      extractCharacterSimulationJsonBlock(content);

  /// 从纯文本中解析对话（当 JSON 解析失败时的降级方案）
  List<DialogueLine> _parseDialogueFromText(String content) =>
      parseCharacterSimulationDialogueFromText(content);

  /// 安全解析 double
  double _parseDouble(dynamic value, double fallback) =>
      parseCharacterSimulationDouble(value, fallback);

  /// 单角色自言自语
  Future<List<DialogueLine>> _simulateMonologue(
    SimCharacterProfile character,
    SimulationContext context,
    String topic,
    String workId,
  ) async {
    try {
      final contextSection = _buildContextSection(context);
      final characterDesc = _describeSimCharacter(character);
      final promptBundle = _buildMonologuePromptBundle(
        character: character,
        characterDescription: characterDesc,
        contextSection: contextSection,
        topic: topic,
      );

      final config = AIRequestConfig(
        function: AIFunction.characterSimulation,
        systemPrompt: promptBundle.systemPrompt,
        userPrompt: promptBundle.userPrompt,
        temperature: 0.8,
        maxTokens: 1500,
        stream: false,
      );

      final response = await _aiService.generate(
        prompt: promptBundle.userPrompt,
        config: config,
      );

      return _parseDialogueLines(response.content);
    } catch (e) {
      return [];
    }
  }

  /// 构建 SimCharacterProfile 的描述文本
  String _describeSimCharacter(SimCharacterProfile c) =>
      describeCharacterSimulationProfile(c);
}
