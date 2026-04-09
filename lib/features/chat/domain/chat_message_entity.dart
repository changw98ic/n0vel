import 'dart:convert';

import '../../../../core/services/ai/context/context_manager.dart' as cm;

/// 对话消息领域模型
/// 与 context_manager.dart 的 ChatMessage 之间可互相转换
class ChatMessageEntity {
  final String id;
  final String conversationId;
  final String role;
  final String content;
  final String? toolCallId;
  final Map<String, dynamic>? toolCall;
  final Map<String, dynamic>? metadata;
  final int sortOrder;
  final DateTime createdAt;

  const ChatMessageEntity({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    this.toolCallId,
    this.toolCall,
    this.metadata,
    required this.sortOrder,
    required this.createdAt,
  });

  /// 从 Drift 数据行转换
  factory ChatMessageEntity.fromDb(Map<String, dynamic> row) {
    return ChatMessageEntity(
      id: row['id'] as String,
      conversationId: row['conversation_id'] as String,
      role: row['role'] as String,
      content: row['content'] as String,
      toolCallId: row['tool_call_id'] as String?,
      toolCall: row['tool_call'] != null
          ? _tryParseJson(row['tool_call'] as String)
          : null,
      metadata: row['metadata'] != null
          ? _tryParseJson(row['metadata'] as String)
          : null,
      sortOrder: row['sort_order'] as int,
      createdAt: row['created_at'] as DateTime,
    );
  }

  /// 转换为上下文管理器的 ChatMessage
  cm.ChatMessage toContextMessage() {
    return cm.ChatMessage(
      role: role,
      content: content,
      toolCallId: toolCallId,
      toolCall: toolCall,
    );
  }

  /// 从上下文管理器的 ChatMessage 创建
  factory ChatMessageEntity.fromContextMessage({
    required cm.ChatMessage message,
    required String conversationId,
    required int sortOrder,
    String? id,
  }) {
    return ChatMessageEntity(
      id: id ?? '',
      conversationId: conversationId,
      role: message.role,
      content: message.content,
      toolCallId: message.toolCallId,
      toolCall: message.toolCall,
      sortOrder: sortOrder,
      createdAt: DateTime.now(),
    );
  }
}

/// 对话会话领域模型
class ChatConversationEntity {
  final String id;
  final String title;
  final String? workId;
  final String source;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChatConversationEntity({
    required this.id,
    required this.title,
    this.workId,
    this.source = 'standalone',
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatConversationEntity.fromDb(Map<String, dynamic> row) {
    return ChatConversationEntity(
      id: row['id'] as String,
      title: row['title'] as String,
      workId: row['work_id'] as String?,
      source: row['source'] as String? ?? 'standalone',
      metadata: row['metadata'] != null
          ? _tryParseJson(row['metadata'] as String)
          : null,
      createdAt: row['created_at'] as DateTime,
      updatedAt: row['updated_at'] as DateTime,
    );
  }
}

Map<String, dynamic>? _tryParseJson(String json) {
  try {
    return jsonDecode(json) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}
