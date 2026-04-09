import 'package:drift/drift.dart';

/// 作品表
@DataClassName('Work')
class Works extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get type => text().nullable().withLength(max: 50)();
  TextColumn get description => text().nullable()();
  TextColumn get coverPath => text().nullable()();
  IntColumn get targetWords => integer().nullable()();
  IntColumn get currentWords => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('draft'))(); // draft/ongoing/completed
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 卷表
@DataClassName('Volume')
class Volumes extends Table {
  TextColumn get id => text()();
  TextColumn get workId => text().references(Works, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>>? get uniqueKeys => [
        {workId, name}
      ];
}

/// 章节表
@DataClassName('Chapter')
class Chapters extends Table {
  TextColumn get id => text()();
  TextColumn get volumeId => text().references(Volumes, #id, onDelete: KeyAction.cascade)();
  TextColumn get workId => text().references(Works, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get content => text().nullable()();
  IntColumn get wordCount => integer().withDefault(const Constant(0))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('draft'))(); // draft/reviewing/published
  RealColumn get reviewScore => real().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>>? get uniqueKeys => [
        {volumeId, sortOrder}
      ];
}
