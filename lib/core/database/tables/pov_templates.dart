import 'package:drift/drift.dart';

/// POV 模板表
@DataClassName('POVTemplateRecord')
class POVTemplateRecords extends Table {
  TextColumn get id => text()();
  TextColumn get workId => text().nullable()(); // null 表示全局模板
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().withLength(min: 1, max: 1000)();
  TextColumn get mode => text()(); // rewrite/supplement/summary/fragment
  TextColumn get style =>
      text()(); // firstPerson/thirdPersonLimited/diary/memoir
  BoolColumn get keepDialogue => boolean().withDefault(const Constant(true))();
  BoolColumn get addInnerThoughts =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get expandObservations =>
      boolean().withDefault(const Constant(true))();
  RealColumn get emotionalIntensity =>
      real().withDefault(const Constant(0.5))();
  BoolColumn get useCharacterVoice =>
      boolean().withDefault(const Constant(true))();
  TextColumn get customInstructions => text().nullable()();
  IntColumn get targetWordCount => integer().nullable()();
  TextColumn get suitableCharacterTypes =>
      text().nullable()(); // JSON array of character types
  TextColumn get exampleOutput => text().nullable()();
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))(); // 排序字段
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>>? get uniqueKeys => [
    {workId, name}, // 同一作品下模板名称唯一
  ];
}
