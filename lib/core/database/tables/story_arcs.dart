import 'package:drift/drift.dart';

import 'works.dart';
import 'characters.dart';

/// 故事弧线表（主线/支线/暗线）
@DataClassName('StoryArc')
class StoryArcs extends Table {
  TextColumn get id => text()();
  TextColumn get workId => text().references(Works, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()(); // 弧线名称：如"主角成长线"、"复仇线"
  TextColumn get arcType => text()(); // main/subplot/hidden/romance/comedy
  TextColumn get description => text().nullable()();
  TextColumn get startChapterId =>
      text().nullable().references(Chapters, #id)(); // 起始章节
  TextColumn get endChapterId =>
      text().nullable().references(Chapters, #id)(); // 结束章节
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get status => text()
      .withDefault(const Constant('active'))(); // active/resolved/abandoned
  TextColumn get metadata => text().nullable()(); // JSON for extra data
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 弧线-章节关联表（一个章节可参与多条弧线）
@DataClassName('ArcChapter')
class ArcChapters extends Table {
  TextColumn get id => text()();
  TextColumn get arcId => text().references(StoryArcs, #id)();
  TextColumn get chapterId => text().references(Chapters, #id)();
  TextColumn get role => text().withDefault(const Constant('progression'))();
  // progression/climax/twist/resolution/foreshadow/callback
  TextColumn get note => text().nullable()(); // 此弧线在此章节的作用说明
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 弧线-角色关联表
@DataClassName('ArcCharacter')
class ArcCharacters extends Table {
  TextColumn get id => text()();
  TextColumn get arcId => text().references(StoryArcs, #id)();
  TextColumn get characterId => text().references(Characters, #id)();
  TextColumn get role => text().withDefault(const Constant('participant'))();
  // protagonist/antagonist/mentor/participant/observer
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 伏笔/回收追踪表
@DataClassName('Foreshadow')
class Foreshadows extends Table {
  TextColumn get id => text()();
  TextColumn get workId => text().references(Works, #id, onDelete: KeyAction.cascade)();
  TextColumn get description => text()(); // 伏笔描述
  TextColumn get plantChapterId =>
      text().nullable().references(Chapters, #id)(); // 埋设章节
  IntColumn get plantParagraphIndex => integer().nullable()();
  TextColumn get payoffChapterId =>
      text().nullable().references(Chapters, #id)(); // 回收章节
  IntColumn get payoffParagraphIndex => integer().nullable()();
  TextColumn get status => text().withDefault(const Constant('planted'))();
  // planted/hinted/paid_off/abandoned
  TextColumn get importance => text().withDefault(const Constant('minor'))();
  // critical/major/minor
  TextColumn get arcId => text().nullable().references(StoryArcs, #id)();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
