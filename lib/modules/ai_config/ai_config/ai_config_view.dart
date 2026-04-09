import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../../shared/data/base_business/base_page.dart';
import 'ai_config_logic.dart';
import '../view/ai_config_form_sections.dart';
import '../view/ai_config_page_sections.dart';
import '../../../../../features/ai_config/domain/model_config.dart';
import '../../../../../app/widgets/app_shell.dart';

class AIConfigView extends GetView<AIConfigLogic> with BasePage {
  @override
  Widget build(BuildContext context) {
    final s = AIConfigCopy.of(context);

    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerLow.withValues(alpha: 0.7),
          child: TabBar(
            controller: controller.tabController,
            tabs: [
              Tab(text: s.aiConfig_tab_modelConfig),
              Tab(text: s.aiConfig_tab_functionMapping),
              Tab(text: s.aiConfig_tab_promptManager),
              Tab(text: s.aiConfig_tab_usageStats),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: controller.tabController,
            children: const [
              _ModelConfigTab(),
              _FunctionMappingTab(),
              _PromptManagerTab(),
              _UsageStatsTab(),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModelConfigTab extends GetView<AIConfigLogic> {
  const _ModelConfigTab();

  @override
  Widget build(BuildContext context) {
    final s = AIConfigCopy.of(context);

    return Obx(() {
      if (controller.state.modelConfigsError.value != null) {
        return Center(child: Text('${s.aiConfig_loadFailed}: ${controller.state.modelConfigsError.value}'));
      }
      if (controller.state.modelConfigs.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      return ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      s.aiConfig_tierConfig_description,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 24.h),
          ...ModelTier.values.map((tier) => AITierConfigCard(tier: tier)),
        ],
      );
    });
  }
}

class _FunctionMappingTab extends GetView<AIConfigLogic> {
  const _FunctionMappingTab();

  @override
  Widget build(BuildContext context) {
    final s = AIConfigCopy.of(context);

    return Obx(() {
      if (controller.state.functionMappingsError.value != null) {
        return Center(child: Text('${s.aiConfig_loadFailed}: ${controller.state.functionMappingsError.value}'));
      }
      if (controller.state.functionMappings.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      return ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: AIFunction.values.length,
        itemBuilder: (context, index) {
          final function = AIFunction.values[index];
          final mapping = controller.state.functionMappings.firstWhere(
            (item) => item.functionKey == function.key,
            orElse: () => FunctionMapping(functionKey: function.key),
          );
          return AIFunctionMappingCard(function: function, mapping: mapping);
        },
      );
    });
  }
}

class _PromptManagerTab extends GetView<AIConfigLogic> {
  const _PromptManagerTab();

  @override
  Widget build(BuildContext context) {
    final s = AIConfigCopy.of(context);

    return Obx(() {
      if (controller.state.promptTemplatesError.value != null) {
        return Center(child: Text('${s.aiConfig_loadFailed}: ${controller.state.promptTemplatesError.value}'));
      }
      if (controller.state.promptTemplates.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      return Column(
        children: [
          PromptManagerToolbar(onCreateTemplate: controller.createTemplate),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              itemCount: controller.state.promptTemplates.length,
              itemBuilder: (context, index) {
                final template = controller.state.promptTemplates[index];
                return AIPromptTemplateCard(template: template);
              },
            ),
          ),
        ],
      );
    });
  }
}

class _UsageStatsTab extends GetView<AIConfigLogic> {
  const _UsageStatsTab();

  @override
  Widget build(BuildContext context) {
    final s = AIConfigCopy.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Obx(() {
      if (controller.state.usageStatsError.value != null) {
        return Center(child: Text('${s.aiConfig_loadFailed}: ${controller.state.usageStatsError.value}'));
      }
      final stats = controller.state.usageStats.value;
      if (stats == null) {
        return const Center(child: CircularProgressIndicator());
      }

      return SingleChildScrollView(
        padding: EdgeInsets.all(24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: AppStatCard(
                    icon: Icons.today,
                    label: s.aiConfig_todayRequests,
                    value: stats.todayRequests.toString(),
                    hint: '',
                    accent: colorScheme.primary,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: AppStatCard(
                    icon: Icons.token,
                    label: s.aiConfig_todayTokens,
                    value: controller.formatNumber(stats.todayTokens),
                    hint: '',
                    accent: colorScheme.secondary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: AppStatCard(
                    icon: Icons.weekend,
                    label: s.aiConfig_weekRequests,
                    value: stats.weekRequests.toString(),
                    hint: '',
                    accent: colorScheme.tertiary,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: AppStatCard(
                    icon: Icons.bar_chart,
                    label: s.aiConfig_weekTokens,
                    value: controller.formatNumber(stats.weekTokens),
                    hint: '',
                    accent: colorScheme.error,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),
            AppSectionCard(
              title: s.aiConfig_byModelStats,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 16.h),
                  ...stats.byModel.entries.map((entry) {
                    return Material(
                      color: Colors.transparent,
                      child: ListTile(
                        leading: CircleAvatar(child: Text(entry.key.substring(0, 1))),
                        title: Text(entry.key),
                        trailing: Text(
                          '${entry.value.requests} ${s.aiConfig_timesCount} / ${controller.formatNumber(entry.value.tokens)} ${s.aiConfig_tokens}',
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            SizedBox(height: 24.h),
            AppSectionCard(
              title: s.aiConfig_byFunctionStats,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 16.h),
                  ...stats.byFunction.entries.map((entry) {
                    final func = AIFunction.fromKey(entry.key);
                    return Material(
                      color: Colors.transparent,
                      child: ListTile(
                        leading: Icon(func?.icon ?? Icons.article),
                        title: Text(func?.label ?? entry.key),
                        trailing: Text(
                          '${entry.value.requests} ${s.aiConfig_timesCount} / ${controller.formatNumber(entry.value.tokens)} ${s.aiConfig_tokens}',
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}
