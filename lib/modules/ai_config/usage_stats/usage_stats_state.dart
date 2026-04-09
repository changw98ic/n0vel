import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../core/database/database.dart';

class UsageStatsState {
  final workId = RxString('');
  final selectedRange = Rx<DateTimeRange?>(null);
  final overviewRecords = RxList<AIUsageRecord>([]);
  final byModelSummaries = RxList<AIUsageSummary>([]);
  final byFunctionRecords = RxList<AIUsageRecord>([]);
  final overviewError = Rx<Object?>(null);
  final byModelError = Rx<Object?>(null);
  final byFunctionError = Rx<Object?>(null);
}
