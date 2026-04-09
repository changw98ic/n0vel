import 'package:drift/drift.dart';
import 'works.dart';
import 'characters.dart';

/// 势力表
@DataClassName('Faction')
class Factions extends Table {
  TextColumn get id => text()();
  TextColumn get workId => text().references(Works, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get type => text().nullable()();
  TextColumn get emblemPath => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get traits => text().nullable()(); // JSON array
  TextColumn get leaderId => text().nullable().references(Characters, #id, onDelete: KeyAction.setNull)();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 势力-成员事件表
@DataClassName('FactionMember')
class FactionMembers extends Table {
  TextColumn get id => text()();
  TextColumn get factionId => text().references(Factions, #id, onDelete: KeyAction.cascade)();
  TextColumn get characterId => text().references(Characters, #id)();
  TextColumn get role => text().nullable()(); // 首领/长老/成员/...
  TextColumn get joinChapterId => text().nullable()();
  TextColumn get leaveChapterId => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))(); // active/left/expelled/deceased
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 事件表
@DataClassName('StoryEvent')
class Events extends Table {
  TextColumn get id => text()();
  TextColumn get workId => text().references(Works, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get type => text().nullable()(); // main/sub/daily/battle/romance
  TextColumn get importance => text().nullable()(); // normal/important/key/turning
  TextColumn get storyTime => text().nullable()();
  TextColumn get relativeTime => text().nullable()();
  TextColumn get chapterId => text().nullable()();
  TextColumn get locationId => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get consequences => text().nullable()();
  TextColumn get predecessorId => text().nullable()();
  TextColumn get successorId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 事件-角色关联表
@DataClassName('EventCharacter')
class EventCharacters extends Table {
  TextColumn get eventId => text().references(Events, #id)();
  TextColumn get characterId => text().references(Characters, #id)();
  TextColumn get role => text().nullable()(); // 主角/参与者/旁观者/受害者

  @override
  Set<Column> get primaryKey => {eventId, characterId};
}
