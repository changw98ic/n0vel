import 'package:drift/drift.dart';
import 'works.dart';

/// 灵感/素材表
@DataClassName('Inspiration')
class Inspirations extends Table {
  TextColumn get id => text()();
  TextColumn get workId => text().nullable().references(Works, #id)(); // nullable = 通用素材
  TextColumn get title => text()();
  TextColumn get content => text()(); // 素材内容
  TextColumn get category => text().withDefault(const Constant('idea'))();
  // idea/reference/character_sketch/scene_fragment/worldbuilding/dialogue_snippet
  TextColumn get tags => text().withDefault(const Constant('[]'))(); // JSON array of tags
  TextColumn get source => text().nullable()(); // 来源（URL/书名/自创）
  IntColumn get priority => integer().withDefault(const Constant(0))(); // 0=普通, 1=重要, 2=紧急
  TextColumn get color => text().nullable()(); // 标记颜色
  TextColumn get metadata => text().nullable()(); // JSON for extra data
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 素材集合表（类似文件夹）
@DataClassName('InspirationCollection')
class InspirationCollections extends Table {
  TextColumn get id => text()();
  TextColumn get workId => text().nullable().references(Works, #id)();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get icon => text().nullable()(); // emoji or icon name
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 素材-集合关联表
@DataClassName('InspirationCollectionItem')
class InspirationCollectionItems extends Table {
  TextColumn get id => text()();
  TextColumn get collectionId =>
      text().references(InspirationCollections, #id)();
  TextColumn get inspirationId => text().references(Inspirations, #id)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
