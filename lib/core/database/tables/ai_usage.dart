import 'package:drift/drift.dart';

/// AI使用统计表
@DataClassName('AIUsageRecord')
class AIUsageRecords extends Table {
  TextColumn get id => text()();
  TextColumn get workId => text().nullable()(); // 关联作品ID，可能为空
  TextColumn get functionType => text()(); // AI功能类型
  TextColumn get modelId => text()(); // 使用的模型ID
  TextColumn get tier => text()(); // 模型层级 thinking/middle/fast
  TextColumn get status => text()(); // success/error/cached
  IntColumn get inputTokens => integer().withDefault(const Constant(0))();
  IntColumn get outputTokens => integer().withDefault(const Constant(0))();
  IntColumn get totalTokens => integer().withDefault(const Constant(0))();
  IntColumn get responseTimeMs => integer().withDefault(const Constant(0))(); // 响应时间（毫秒）
  TextColumn get errorMessage => text().nullable()(); // 错误信息
  TextColumn get requestId => text().nullable()(); // 请求ID（用于追踪）
  BoolColumn get fromCache => boolean().withDefault(const Constant(false))();
  TextColumn get metadata => text().nullable()(); // JSON元数据
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>>? get uniqueKeys => [
        {requestId}, // requestId应该是唯一的
      ];
}

/// AI使用统计汇总表（按日期和模型汇总）
@DataClassName('AIUsageSummary')
class AIUsageSummaries extends Table {
  TextColumn get id => text()();
  TextColumn get workId => text().nullable()();
  TextColumn get modelId => text()();
  TextColumn get tier => text()();
  TextColumn get functionType => text().nullable()(); // 为null表示所有功能
  DateTimeColumn get date => dateTime()(); // 统计日期
  IntColumn get requestCount => integer().withDefault(const Constant(0))();
  IntColumn get successCount => integer().withDefault(const Constant(0))();
  IntColumn get errorCount => integer().withDefault(const Constant(0))();
  IntColumn get cachedCount => integer().withDefault(const Constant(0))();
  IntColumn get totalInputTokens => integer().withDefault(const Constant(0))();
  IntColumn get totalOutputTokens => integer().withDefault(const Constant(0))();
  IntColumn get totalTokens => integer().withDefault(const Constant(0))();
  IntColumn get totalResponseTimeMs => integer().withDefault(const Constant(0))();
  IntColumn get avgResponseTimeMs => integer().withDefault(const Constant(0))();
  RealColumn get estimatedCost => real().withDefault(const Constant(0))(); // 预估成本
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>>? get uniqueKeys => [
        {workId, modelId, functionType, date}, // 确保每天每个模型只有一个汇总记录
      ];
}
