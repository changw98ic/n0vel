import 'package:drift/drift.dart';
import 'works.dart';

/// 章节版本快照表
@DataClassName('ChapterVersion')
class ChapterVersions extends Table {
  TextColumn get id => text()();
  TextColumn get chapterId => text().references(Chapters, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()(); // 版本标题（自动或手动）
  TextColumn get content => text()(); // 完整章节内容快照
  IntColumn get wordCount => integer()();
  TextColumn get changeDescription => text().nullable()(); // 变更说明
  TextColumn get changeType => text().withDefault(const Constant('manual'))();
  // manual/auto_save/major_edit/restore
  IntColumn get versionNumber => integer()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
