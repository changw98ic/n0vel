import 'package:drift/drift.dart';
import 'works.dart';

/// 角色表
@DataClassName('Character')
class Characters extends Table {
  TextColumn get id => text()();
  TextColumn get workId => text().references(Works, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get aliases => text().nullable()(); // JSON array
  TextColumn get tier => text()(); // protagonist/major_antagonist/antagonist/supporting/minor
  TextColumn get avatarPath => text().nullable()();
  TextColumn get gender => text().nullable()();
  TextColumn get age => text().nullable()();
  TextColumn get identity => text().nullable()();
  TextColumn get bio => text().nullable()();
  TextColumn get lifeStatus => text().withDefault(const Constant('alive'))(); // alive/dead/missing/unknown
  TextColumn get deathChapterId => text().nullable()();
  TextColumn get deathReason => text().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 角色深度档案表
@DataClassName('CharacterProfile')
class CharacterProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get characterId => text().references(Characters, #id, onDelete: KeyAction.cascade)();
  TextColumn get mbti => text().nullable()();
  TextColumn get bigFive => text().nullable()(); // JSON object
  TextColumn get personalityKeywords => text().nullable()(); // JSON array
  TextColumn get coreValues => text().nullable()();
  TextColumn get fears => text().nullable()();
  TextColumn get desires => text().nullable()();
  TextColumn get moralBaseline => text().nullable()();
  TextColumn get speechStyle => text().nullable()(); // JSON object
  TextColumn get behaviorPatterns => text().nullable()(); // JSON array
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>>? get uniqueKeys => [
        {characterId}
      ];
}
