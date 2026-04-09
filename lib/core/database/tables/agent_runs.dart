import 'package:drift/drift.dart';
import 'works.dart';

/// Agent 运行记录表
@DataClassName('AgentRun')
class AgentRuns extends Table {
  TextColumn get id => text()();
  TextColumn get workId => text().references(Works, #id, onDelete: KeyAction.cascade)();
  TextColumn get task => text()();
  TextColumn get status =>
      text().withDefault(const Constant('running'))(); // running/completed/failed
  IntColumn get iterations => integer().withDefault(const Constant(0))();
  TextColumn get toolsUsed =>
      text().withDefault(const Constant('[]'))(); // JSON array of tool names
  TextColumn get result => text().nullable()();
  IntColumn get totalInputTokens => integer().withDefault(const Constant(0))();
  IntColumn get totalOutputTokens => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Agent 执行步骤表
@DataClassName('AgentStep')
class AgentSteps extends Table {
  TextColumn get id => text()();
  TextColumn get runId => text().references(AgentRuns, #id, onDelete: KeyAction.cascade)();
  IntColumn get stepIndex => integer()();
  TextColumn get type => text()(); // thought/action/observation/response
  TextColumn get content => text()();
  TextColumn get toolName => text().nullable()();
  TextColumn get toolInput => text().nullable()(); // JSON
  TextColumn get toolOutput => text().nullable()(); // JSON
  IntColumn get inputTokens => integer().withDefault(const Constant(0))();
  IntColumn get outputTokens => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
