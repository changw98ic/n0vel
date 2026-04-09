import 'package:drift/drift.dart';
import 'works.dart';

/// 写作会话表（记录每次写作活动）
@DataClassName('WritingSession')
class WritingSessionsTable extends Table {
  TextColumn get id => text()();
  TextColumn get workId => text().references(Works, #id)();
  TextColumn get chapterId => text().nullable()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime().nullable()();
  IntColumn get startWordCount => integer()();
  IntColumn get endWordCount => integer().withDefault(const Constant(0))();
  IntColumn get wordsWritten => integer().withDefault(const Constant(0))();
  IntColumn get durationSeconds => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 每日写作统计表
@DataClassName('DailyWritingStat')
class DailyWritingStats extends Table {
  TextColumn get id => text()();
  TextColumn get workId => text().references(Works, #id)();
  DateTimeColumn get date => dateTime()();
  IntColumn get totalWordsWritten => integer().withDefault(const Constant(0))();
  IntColumn get totalDurationSeconds =>
      integer().withDefault(const Constant(0))();
  IntColumn get sessionCount => integer().withDefault(const Constant(0))();
  IntColumn get chaptersWorkedOn => integer().withDefault(const Constant(0))();
  IntColumn get aiAssistCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
