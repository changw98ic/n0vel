import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../shared/data/base_business/base_controller.dart';
import 'ai_config_state.dart';
import '../../../../../features/ai_config/data/ai_config_repository.dart';
import '../view/ai_config_page_sections.dart';

class AIConfigLogic extends BaseController with GetTickerProviderStateMixin {
  final AIConfigState state = AIConfigState();
  late final TabController tabController;

  @override
  void onInit() {
    super.onInit();
    tabController = TabController(length: 4, vsync: this);
    loadModelConfigs();
    loadFunctionMappings();
    loadPromptTemplates();
    loadUsageStats();
  }

  @override
  void onClose() {
    tabController.dispose();
    super.onClose();
  }

  Future<void> loadModelConfigs() async {
    try {
      final repository = Get.find<AIConfigRepository>();
      final configs = await repository.getAllModelConfigs();
      state.modelConfigs.value = configs;
      state.modelConfigsError.value = null;
    } catch (e) {
      state.modelConfigsError.value = e;
    }
  }

  Future<void> loadFunctionMappings() async {
    try {
      final repository = Get.find<AIConfigRepository>();
      final mappings = await repository.getFunctionMappings();
      state.functionMappings.value = mappings;
      state.functionMappingsError.value = null;
    } catch (e) {
      state.functionMappingsError.value = e;
    }
  }

  Future<void> loadPromptTemplates() async {
    try {
      final repository = Get.find<AIConfigRepository>();
      final templates = await repository.getPromptTemplates();
      state.promptTemplates.value = templates;
      state.promptTemplatesError.value = null;
    } catch (e) {
      state.promptTemplatesError.value = e;
    }
  }

  Future<void> loadUsageStats() async {
    try {
      final repository = Get.find<AIConfigRepository>();
      final stats = await repository.getUsageStats();
      state.usageStats.value = stats;
      state.usageStatsError.value = null;
    } catch (e) {
      state.usageStatsError.value = e;
    }
  }

  void createTemplate() {
    Get.dialog(
      const AIPromptTemplateEditorDialog(),
    ).then((_) => loadPromptTemplates());
  }

  String formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    }
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}
