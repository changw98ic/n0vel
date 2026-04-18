import 'package:get/get.dart';

import '../../../core/services/ai/ai_service.dart';
import '../../../core/services/ai/context/context_manager.dart' as cm;
import '../../../core/services/ai/models/model_tier.dart';

/// 编辑器内多轮对话 Logic
/// 消息保持在内存中，不持久化到数据库
class EditorChatLogic extends GetxController {
  final messages = RxList<cm.ChatMessage>([]);
  final isGenerating = false.obs;
  final streamingContent = ''.obs;

  final AIService _aiService = Get.find<AIService>();
  final List<cm.ChatMessage> _contextHistory = [];

  /// 发送用户消息
  Future<void> sendMessage(String text, String chapterContent) async {
    if (text.trim().isEmpty || isGenerating.value) return;

    final userMsg = cm.ChatMessage(role: 'user', content: text);
    messages.add(userMsg);
    _contextHistory.add(userMsg);
    isGenerating.value = true;
    streamingContent.value = '';

    try {
      final response = await _aiService.generate(
        prompt: _buildPrompt(text, chapterContent),
        config: AIRequestConfig(
          function: AIFunction.chat,
          systemPrompt: _buildSystemPrompt(chapterContent),
          userPrompt: _buildPrompt(text, chapterContent),
          useCache: false,
          stream: false,
        ),
      );

      final assistantMsg =
          cm.ChatMessage(role: 'assistant', content: response.content);
      messages.add(assistantMsg);
      _contextHistory.add(assistantMsg);
      streamingContent.value = '';
    } catch (e) {
      messages.add(cm.ChatMessage(role: 'assistant', content: '生成失败：$e'));
    } finally {
      isGenerating.value = false;
    }
  }

  /// 快捷操作：续写
  Future<void> continuation(String chapterContent) =>
      _quickAction('请根据以下内容自然续写故事', chapterContent, AIFunction.continuation);

  /// 快捷操作：对白
  Future<void> dialogue(String chapterContent) =>
      _quickAction('请根据上下文生成符合角色的对话', chapterContent, AIFunction.dialogue);

  /// 快捷操作：剧情灵感
  Future<void> plotInspiration(String chapterContent) =>
      _quickAction('请根据当前章节提供3-5个剧情方向建议', chapterContent, AIFunction.chat);

  /// 快捷操作：角色模拟
  Future<void> characterSimulation(String chapterContent) =>
      _quickAction('请根据当前章节模拟角色的可能反应', chapterContent, AIFunction.characterSimulation);

  /// 清空历史
  void clearHistory() {
    messages.clear();
    _contextHistory.clear();
    streamingContent.value = '';
  }

  void startExternalRequest(String prompt) {
    if (prompt.trim().isEmpty) return;
    final userMsg = cm.ChatMessage(role: 'user', content: prompt);
    messages.add(userMsg);
    _contextHistory.add(userMsg);
    isGenerating.value = true;
    streamingContent.value = '';
  }

  void finishExternalRequest(String content) {
    if (content.trim().isNotEmpty) {
      final assistantMsg =
          cm.ChatMessage(role: 'assistant', content: content);
      messages.add(assistantMsg);
      _contextHistory.add(assistantMsg);
    }
    isGenerating.value = false;
    streamingContent.value = '';
  }

  void failExternalRequest(Object error) {
    messages.add(cm.ChatMessage(role: 'assistant', content: '生成失败：$error'));
    isGenerating.value = false;
    streamingContent.value = '';
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  Future<void> _quickAction(
      String prompt, String chapterContent, AIFunction function) async {
    if (isGenerating.value) return;

    final userMsg = cm.ChatMessage(role: 'user', content: prompt);
    messages.add(userMsg);
    _contextHistory.add(userMsg);
    isGenerating.value = true;
    streamingContent.value = '';

    try {
      final response = await _aiService.generate(
        prompt: _buildPrompt(prompt, chapterContent),
        config: AIRequestConfig(
          function: function,
          systemPrompt: _buildSystemPrompt(chapterContent),
          userPrompt: _buildPrompt(prompt, chapterContent),
          useCache: false,
          stream: false,
        ),
      );

      final assistantMsg =
          cm.ChatMessage(role: 'assistant', content: response.content);
      messages.add(assistantMsg);
      _contextHistory.add(assistantMsg);
    } catch (e) {
      messages.add(cm.ChatMessage(role: 'assistant', content: '生成失败：$e'));
    } finally {
      isGenerating.value = false;
      streamingContent.value = '';
    }
  }

  String _buildSystemPrompt(String chapterContent) {
    final buffer = StringBuffer();
    buffer.writeln('你是一位专业的小说写作助手。');
    buffer.writeln('请根据提供的章节内容和对话历史，帮助用户进行创作。');
    buffer.writeln('如果用户要求修改或调整，请参考之前的对话内容。');
    return buffer.toString();
  }

  String _buildPrompt(String userText, String chapterContent) {
    final buffer = StringBuffer();

    // 添加对话历史
    if (_contextHistory.length > 1) {
      buffer.writeln('---对话历史---');
      for (final msg in _contextHistory.take(_contextHistory.length - 1)) {
        if (msg.role == 'system') continue;
        final label = msg.role == 'user' ? '用户' : '助手';
        buffer.writeln('[$label]: ${msg.content}');
      }
      buffer.writeln('---对话历史结束---');
      buffer.writeln();
    }

    // 当前章节内容
    if (chapterContent.isNotEmpty) {
      buffer.writeln('---当前章节内容---');
      buffer.writeln(chapterContent.length > 3000
          ? '${chapterContent.substring(0, 3000)}...(内容过长已截断)'
          : chapterContent);
      buffer.writeln('---章节内容结束---');
      buffer.writeln();
    }

    buffer.writeln(userText);
    return buffer.toString();
  }
}
