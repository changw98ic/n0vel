import 'package:drift/drift.dart';
import 'works.dart';

/// AI 对话会话表
@DataClassName('ChatConversation')
class ChatConversations extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get workId =>
      text().nullable().references(Works, #id, onDelete: KeyAction.setNull)();
  TextColumn get source =>
      text().withDefault(const Constant('standalone'))(); // standalone / editor
  TextColumn get metadata => text().nullable()(); // JSON
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// AI 对话消息表
@DataClassName('ChatMessageRecord')
class ChatMessages extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text().references(ChatConversations, #id,
      onDelete: KeyAction.cascade)();
  TextColumn get role => text()(); // system / user / assistant / tool
  TextColumn get content => text()();
  TextColumn get toolCallId => text().nullable()();
  TextColumn get toolCall => text().nullable()(); // JSON
  TextColumn get metadata => text().nullable()(); // JSON
  IntColumn get sortOrder => integer()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
