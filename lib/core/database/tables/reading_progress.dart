import 'package:drift/drift.dart';
import 'works.dart';

/// 阅读进度表
@DataClassName('ReadingProgress')
class ReadingProgressTable extends Table {
  TextColumn get workId => text().references(Works, #id)();
  TextColumn get currentChapterId => text()();
  IntColumn get currentPosition => integer()();
  RealColumn get progressPercentage => real()();
  DateTimeColumn get lastReadAt => dateTime()();
  IntColumn get totalReadingTime => integer().withDefault(const Constant(0))(); // 分钟
  RealColumn get averageSpeed => real().withDefault(const Constant(0))(); // 字/分钟

  @override
  Set<Column> get primaryKey => {workId};
}

/// 书签表
@DataClassName('Bookmark')
class Bookmarks extends Table {
  TextColumn get id => text()();
  TextColumn get chapterId => text()();
  TextColumn get workId => text().references(Works, #id)();
  IntColumn get position => integer()();
  TextColumn get selectedText => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get color => text().nullable()(); // JSON string for custom color
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 阅读笔记表
@DataClassName('ReadingNote')
class ReadingNotes extends Table {
  TextColumn get id => text()();
  TextColumn get chapterId => text()();
  TextColumn get workId => text().references(Works, #id)();
  IntColumn get startPosition => integer()();
  IntColumn get endPosition => integer()();
  TextColumn get selectedText => text()();
  TextColumn get content => text()();
  TextColumn get tags => text().nullable()(); // JSON array
  TextColumn get color => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 阅读高亮表
@DataClassName('ReadingHighlight')
class ReadingHighlights extends Table {
  TextColumn get id => text()();
  TextColumn get chapterId => text()();
  TextColumn get workId => text().references(Works, #id)();
  IntColumn get startPosition => integer()();
  IntColumn get endPosition => integer()();
  TextColumn get selectedText => text()();
  TextColumn get color => text()(); // yellow/green/blue/pink/purple
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 阅读会话表
@DataClassName('ReadingSession')
class ReadingSessions extends Table {
  TextColumn get id => text()();
  TextColumn get workId => text().references(Works, #id)();
  TextColumn get chapterId => text()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime()();
  IntColumn get wordsRead => integer()();
  IntColumn get startPosition => integer()();
  IntColumn get endPosition => integer()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
