import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../database/database.dart';

class AIUsageTracker {
  final AppDatabase _db;
  final Uuid _uuid;

  AIUsageTracker(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  Future<void> recordUsage({
    required String functionType,
    required String modelId,
    required String tier,
    required String status,
    required int inputTokens,
    required int outputTokens,
    required int responseTimeMs,
    String? errorMessage,
    String? requestId,
    required bool fromCache,
    String? workId,
    Map<String, dynamic>? metadata,
  }) async {
    if (requestId != null && requestId.isNotEmpty) {
      final existing = await (_db.select(_db.aIUsageRecords)
            ..where((table) => table.requestId.equals(requestId))
            ..limit(1))
          .getSingleOrNull();
      if (existing != null) {
        return;
      }
    }

    final record = AIUsageRecordsCompanion.insert(
      id: _uuid.v4(),
      workId: Value(workId),
      functionType: functionType,
      modelId: modelId,
      tier: tier,
      status: status,
      inputTokens: Value(inputTokens),
      outputTokens: Value(outputTokens),
      totalTokens: Value(inputTokens + outputTokens),
      responseTimeMs: Value(responseTimeMs),
      errorMessage: Value(errorMessage),
      requestId: Value(requestId),
      fromCache: Value(fromCache),
      metadata: Value(metadata?.toString()),
      createdAt: DateTime.now(),
    );

    await _db.into(_db.aIUsageRecords).insertOnConflictUpdate(record);

    await _updateDailySummary(
      functionType: functionType,
      modelId: modelId,
      tier: tier,
      status: status,
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      responseTimeMs: responseTimeMs,
      fromCache: fromCache,
      workId: workId,
    );
  }

  Future<List<AIUsageRecord>> getUsageStatistics({
    String? workId,
    DateTime? startDate,
    DateTime? endDate,
    String? functionType,
    int limit = 100,
  }) async {
    final query = _db.select(_db.aIUsageRecords);

    if (workId != null) {
      query.where((table) => table.workId.equals(workId));
    }
    if (startDate != null) {
      query.where((table) => table.createdAt.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where((table) => table.createdAt.isSmallerOrEqualValue(endDate));
    }
    if (functionType != null) {
      query.where((table) => table.functionType.equals(functionType));
    }

    query
      ..orderBy([(table) => OrderingTerm.desc(table.createdAt)])
      ..limit(limit);

    return query.get();
  }

  Future<List<AIUsageSummary>> getUsageSummaries({
    String? workId,
    DateTime? startDate,
    DateTime? endDate,
    String? modelId,
  }) async {
    final query = _db.select(_db.aIUsageSummaries);

    if (workId != null) {
      query.where((table) => table.workId.equals(workId));
    }
    if (startDate != null) {
      query.where((table) => table.date.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where((table) => table.date.isSmallerOrEqualValue(endDate));
    }
    if (modelId != null) {
      query.where((table) => table.modelId.equals(modelId));
    }

    query.orderBy([(table) => OrderingTerm.desc(table.date)]);
    return query.get();
  }

  Future<Map<String, dynamic>> getModelUsageStats({
    String? workId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final summaries = await getUsageSummaries(
      workId: workId,
      startDate: startDate,
      endDate: endDate,
    );

    final result = <String, Map<String, dynamic>>{};
    for (final summary in summaries) {
      result.putIfAbsent(summary.modelId, () {
        return <String, dynamic>{
          'totalTokens': 0,
          'totalRequests': 0,
          'totalCost': 0.0,
          'avgResponseTime': 0,
          'tier': summary.tier,
        };
      });

      final entry = result[summary.modelId]!;
      entry['totalTokens'] += summary.totalTokens;
      entry['totalRequests'] += summary.requestCount;
      entry['totalCost'] += summary.estimatedCost;
      entry['avgResponseTime'] =
          ((entry['avgResponseTime'] as int) + summary.avgResponseTimeMs) ~/ 2;
    }

    return result;
  }

  Future<void> _updateDailySummary({
    required String functionType,
    required String modelId,
    required String tier,
    required String status,
    required int inputTokens,
    required int outputTokens,
    required int responseTimeMs,
    required bool fromCache,
    String? workId,
  }) async {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    final existing =
        await (_db.select(_db.aIUsageSummaries)
              ..where(
                (table) =>
                    table.workId.equalsNullable(workId) &
                    table.modelId.equals(modelId) &
                    table.functionType.equalsNullable(functionType) &
                    table.date.equals(today),
              )
              ..limit(1))
            .get();

    if (existing.isNotEmpty) {
      final summary = existing.first;
      await (_db.update(
        _db.aIUsageSummaries,
      )..where((table) => table.id.equals(summary.id))).write(
        AIUsageSummariesCompanion(
          requestCount: Value(summary.requestCount + 1),
          successCount: Value(
            status == 'success'
                ? summary.successCount + 1
                : summary.successCount,
          ),
          errorCount: Value(
            status == 'error' ? summary.errorCount + 1 : summary.errorCount,
          ),
          cachedCount: Value(
            fromCache ? summary.cachedCount + 1 : summary.cachedCount,
          ),
          totalInputTokens: Value(summary.totalInputTokens + inputTokens),
          totalOutputTokens: Value(summary.totalOutputTokens + outputTokens),
          totalTokens: Value(summary.totalTokens + inputTokens + outputTokens),
          totalResponseTimeMs: Value(
            summary.totalResponseTimeMs + responseTimeMs,
          ),
          avgResponseTimeMs: Value(
            (summary.totalResponseTimeMs + responseTimeMs) ~/
                (summary.requestCount + 1),
          ),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return;
    }

    await _db
        .into(_db.aIUsageSummaries)
        .insert(
          AIUsageSummariesCompanion.insert(
            id: _uuid.v4(),
            workId: Value(workId),
            modelId: modelId,
            tier: tier,
            functionType: Value(functionType),
            date: today,
            requestCount: const Value(1),
            successCount: Value(status == 'success' ? 1 : 0),
            errorCount: Value(status == 'error' ? 1 : 0),
            cachedCount: Value(fromCache ? 1 : 0),
            totalInputTokens: Value(inputTokens),
            totalOutputTokens: Value(outputTokens),
            totalTokens: Value(inputTokens + outputTokens),
            totalResponseTimeMs: Value(responseTimeMs),
            avgResponseTimeMs: Value(responseTimeMs),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
  }
}
