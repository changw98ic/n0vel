import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../domain/chat_message_entity.dart';

/// 对话数据仓库
class ChatRepository {
  final AppDatabase _db;

  ChatRepository(this._db);

  // ---------------------------------------------------------------------------
  // Conversations
  // ---------------------------------------------------------------------------

  /// 获取对话列表，按更新时间倒序
  Future<List<ChatConversationEntity>> getConversations({
    String? workId,
    String? source,
  }) async {
    final query = _db.select(_db.chatConversations)
      ..orderBy([
        (t) => OrderingTerm.desc(t.updatedAt),
      ]);

    if (workId != null) {
      query.where((t) => t.workId.equals(workId));
    }
    if (source != null) {
      query.where((t) => t.source.equals(source));
    }

    final results = await query.get();
    return results.map(_conversationToDomain).toList();
  }

  /// 获取单个对话
  Future<ChatConversationEntity?> getConversationById(String id) async {
    final query = _db.select(_db.chatConversations)
      ..where((t) => t.id.equals(id));
    final result = await query.getSingleOrNull();
    return result != null ? _conversationToDomain(result) : null;
  }

  /// 创建对话
  Future<ChatConversationEntity> createConversation({
    String? workId,
    required String title,
    String source = 'standalone',
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();

    await _db.into(_db.chatConversations).insert(
          ChatConversationsCompanion(
            id: Value(id),
            title: Value(title),
            workId: Value(workId),
            source: Value(source),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    return (await getConversationById(id))!;
  }

  /// 更新对话标题
  Future<void> updateTitle(String id, String title) async {
    await (_db.update(_db.chatConversations)..where((t) => t.id.equals(id)))
        .write(
      ChatConversationsCompanion(
        title: Value(title),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 更新对话元数据
  Future<void> updateMetadata(
      String id, Map<String, dynamic> metadata) async {
    await (_db.update(_db.chatConversations)..where((t) => t.id.equals(id)))
        .write(
      ChatConversationsCompanion(
        metadata: Value(jsonEncode(metadata)),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 删除对话（级联删除消息）
  Future<void> deleteConversation(String id) async {
    await (_db.delete(_db.chatConversations)..where((t) => t.id.equals(id)))
        .go();
  }

  // ---------------------------------------------------------------------------
  // Messages
  // ---------------------------------------------------------------------------

  /// 获取对话的所有消息，按 sortOrder 升序
  Future<List<ChatMessageEntity>> getMessages(String conversationId) async {
    final query = _db.select(_db.chatMessages)
      ..where((t) => t.conversationId.equals(conversationId))
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);

    final results = await query.get();
    return results.map(_messageToDomain).toList();
  }

  /// 获取最近 N 条消息
  Future<List<ChatMessageEntity>> getRecentMessages(
    String conversationId,
    int limit,
  ) async {
    final allMessages = await getMessages(conversationId);
    if (allMessages.length <= limit) return allMessages;
    return allMessages.sublist(allMessages.length - limit);
  }

  /// 获取消息数量
  Future<int> getMessageCount(String conversationId) async {
    final count = _db.select(_db.chatMessages)
      ..where((t) => t.conversationId.equals(conversationId));
    final results = await count.get();
    return results.length;
  }

  /// 添加单条消息
  Future<ChatMessageEntity> addMessage({
    required String conversationId,
    required String role,
    required String content,
    String? toolCallId,
    Map<String, dynamic>? toolCall,
    Map<String, dynamic>? metadata,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();

    // 获取当前最大 sortOrder
    final existing = await getMessages(conversationId);
    final maxOrder = existing.isEmpty
        ? 0
        : existing.map((m) => m.sortOrder).reduce((a, b) => a > b ? a : b);

    await _db.into(_db.chatMessages).insert(
          ChatMessagesCompanion(
            id: Value(id),
            conversationId: Value(conversationId),
            role: Value(role),
            content: Value(content),
            toolCallId: Value(toolCallId),
            toolCall: Value(toolCall != null ? jsonEncode(toolCall) : null),
            metadata: Value(metadata != null ? jsonEncode(metadata) : null),
            sortOrder: Value(maxOrder + 1),
            createdAt: Value(now),
          ),
        );

    // 更新对话的 updatedAt
    await (_db.update(_db.chatConversations)
          ..where((t) => t.id.equals(conversationId)))
        .write(
      ChatConversationsCompanion(
        updatedAt: Value(now),
      ),
    );

    return ChatMessageEntity(
      id: id,
      conversationId: conversationId,
      role: role,
      content: content,
      toolCallId: toolCallId,
      toolCall: toolCall,
      metadata: metadata,
      sortOrder: maxOrder + 1,
      createdAt: now,
    );
  }

  /// 批量添加消息（事务）
  Future<void> addMessages(List<ChatMessageEntity> messages) async {
    if (messages.isEmpty) return;

    await _db.transaction(() async {
      for (final entity in messages) {
        await _db.into(_db.chatMessages).insert(
              ChatMessagesCompanion(
                id: Value(entity.id.isEmpty ? const Uuid().v4() : entity.id),
                conversationId: Value(entity.conversationId),
                role: Value(entity.role),
                content: Value(entity.content),
                toolCallId: Value(entity.toolCallId),
                toolCall: Value(
                    entity.toolCall != null
                        ? jsonEncode(entity.toolCall)
                        : null),
                metadata: Value(
                    entity.metadata != null
                        ? jsonEncode(entity.metadata)
                        : null),
                sortOrder: Value(entity.sortOrder),
                createdAt: Value(entity.createdAt),
              ),
            );
      }

      // 更新对话的 updatedAt
      final convId = messages.first.conversationId;
      await (_db.update(_db.chatConversations)
            ..where((t) => t.id.equals(convId)))
          .write(
        ChatConversationsCompanion(
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Mappers
  // ---------------------------------------------------------------------------

  ChatConversationEntity _conversationToDomain(ChatConversation data) {
    return ChatConversationEntity(
      id: data.id,
      title: data.title,
      workId: data.workId,
      source: data.source,
      metadata: data.metadata != null
          ? _tryParseJson(data.metadata!)
          : null,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
    );
  }

  ChatMessageEntity _messageToDomain(ChatMessageRecord data) {
    return ChatMessageEntity(
      id: data.id,
      conversationId: data.conversationId,
      role: data.role,
      content: data.content,
      toolCallId: data.toolCallId,
      toolCall:
          data.toolCall != null ? _tryParseJson(data.toolCall!) : null,
      metadata:
          data.metadata != null ? _tryParseJson(data.metadata!) : null,
      sortOrder: data.sortOrder,
      createdAt: data.createdAt,
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
