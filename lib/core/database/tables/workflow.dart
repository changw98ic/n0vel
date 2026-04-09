import 'package:drift/drift.dart';
import 'works.dart';

/// AI任务表
@DataClassName('AITask')
class AiTasks extends Table {
  TextColumn get id => text()();
  TextColumn get workId => text().references(Works, #id)();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get type => text()(); // review/extract/generate/analyze
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending/running/paused/completed/failed/cancelled
  RealColumn get progress => real().withDefault(const Constant(0))();
  IntColumn get currentNodeIndex => integer().withDefault(const Constant(0))();
  TextColumn get config => text().nullable()(); // JSON object
  TextColumn get result => text().nullable()(); // JSON object
  TextColumn get errorMessage => text().nullable()();
  IntColumn get inputTokens => integer().withDefault(const Constant(0))();
  IntColumn get outputTokens => integer().withDefault(const Constant(0))();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 工作流节点执行记录表
@DataClassName('WorkflowNodeRun')
class WorkflowNodeRuns extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text().references(AiTasks, #id)();
  TextColumn get nodeName => text()();
  IntColumn get nodeIndex => integer()();
  TextColumn get branchId => text().withDefault(const Constant('main'))(); // 并行分支标识
  TextColumn get status => text()(); // pending/running/completed/failed/skipped/waiting_review/approved/rejected
  IntColumn get attempt => integer().withDefault(const Constant(0))(); // 重试次数
  TextColumn get inputSnapshot => text().nullable()(); // JSON
  TextColumn get outputSnapshot => text().nullable()(); // JSON
  TextColumn get error => text().nullable()();
  TextColumn get aiRequestId => text().nullable()();
  IntColumn get inputTokens => integer().withDefault(const Constant(0))();
  IntColumn get outputTokens => integer().withDefault(const Constant(0))();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>>? get uniqueKeys => [
        {taskId, nodeIndex, branchId, attempt}
      ];
}

/// 工作流检查点表
@DataClassName('WorkflowCheckpoint')
class WorkflowCheckpoints extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text().references(AiTasks, #id)();
  TextColumn get checkpointType => text()(); // auto/manual/pre_node/post_node
  IntColumn get nodeIndex => integer()();
  TextColumn get fullState => text().nullable()(); // JSON
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 章节角色关联表（出场记录）
@DataClassName('ChapterCharacter')
class ChapterCharacters extends Table {
  TextColumn get chapterId => text()();
  TextColumn get characterId => text()();
  IntColumn get dialogueCount => integer().withDefault(const Constant(0))();
  IntColumn get dialogueWords => integer().withDefault(const Constant(0))();
  IntColumn get actionCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {chapterId, characterId};
}
