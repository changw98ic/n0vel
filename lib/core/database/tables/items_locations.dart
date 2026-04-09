import 'package:drift/drift.dart';
import 'works.dart';
import 'characters.dart';

/// 物品表
@DataClassName('Item')
class Items extends Table {
  TextColumn get id => text()();
  TextColumn get workId => text().references(Works, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get type => text().nullable()();
  TextColumn get rarity => text().nullable()();
  TextColumn get iconPath => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get abilities => text().nullable()(); // JSON array
  TextColumn get holderId => text().nullable().references(Characters, #id, onDelete: KeyAction.setNull)();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 地点表
@DataClassName('Location')
class Locations extends Table {
  TextColumn get id => text()();
  TextColumn get workId => text().references(Works, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get type => text().nullable()();
  TextColumn get parentId => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get importantPlaces => text().nullable()(); // JSON array
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>>? get uniqueKeys => [
        {workId, name}
      ];
}

/// 地点-角色关联事件表
@DataClassName('LocationCharacter')
class LocationCharacters extends Table {
  TextColumn get id => text()();
  TextColumn get locationId => text().references(Locations, #id, onDelete: KeyAction.cascade)();
  TextColumn get characterId => text().references(Characters, #id)();
  TextColumn get relationship => text().nullable()(); // 居住/常驻/路过/重要场所
  TextColumn get startChapterId => text().nullable()();
  TextColumn get endChapterId => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))(); // active/left/temporary
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
