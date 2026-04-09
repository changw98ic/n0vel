import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AIConfigState {
  final tabController = Rx<TabController?>(null);
  final modelConfigs = RxList<dynamic>([]);
  final functionMappings = RxList<dynamic>([]);
  final promptTemplates = RxList<dynamic>([]);
  final usageStats = Rx<dynamic>(null);
  final modelConfigsError = Rx<Object?>(null);
  final functionMappingsError = Rx<Object?>(null);
  final promptTemplatesError = Rx<Object?>(null);
  final usageStatsError = Rx<Object?>(null);
}
