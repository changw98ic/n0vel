import 'package:drift/drift.dart';
import 'works.dart';

/// 关系头表（当前关系状态）
@DataClassName('RelationshipHead')
class RelationshipHeads extends Table {
  TextColumn get id => text()();
  TextColumn get workId => text().references(Works, #id, onDelete: KeyAction.cascade)();
  TextColumn get characterAId => text()(); // 规范化：id较小者为A
  TextColumn get characterBId => text()(); // 规范化：id较大者为B
  TextColumn get relationType => text()(); // 敌对/中立/友好/挚友/恋人/亲人/师徒
  TextColumn get emotionDimensions => text().nullable()(); // JSON: {affection, trust, respect, fear}
  TextColumn get firstChapterId => text().nullable()();
  TextColumn get latestChapterId => text().nullable()();
  IntColumn get eventCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>>? get uniqueKeys => [
        {workId, characterAId, characterBId}
      ];
}

/// 关系事件表（变更历史）
@DataClassName('RelationshipEvent')
class RelationshipEvents extends Table {
  TextColumn get id => text()();
  TextColumn get headId => text().references(RelationshipHeads, #id, onDelete: KeyAction.cascade)();
  TextColumn get chapterId => text()();
  TextColumn get changeType => text()(); // create/update/major_shift
  TextColumn get prevRelationType => text().nullable()();
  TextColumn get newRelationType => text()();
  TextColumn get prevEmotionDimensions => text().nullable()(); // JSON
  TextColumn get newEmotionDimensions => text().nullable()(); // JSON
  TextColumn get changeReason => text().nullable()();
  BoolColumn get isKeyEvent => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
