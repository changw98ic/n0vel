import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../app/widgets/app_shell.dart';
import '../../core/config/app_routes.dart';
import '../../shared/data/base_business/base_page.dart';
import 'dashboard_logic.dart';

/// 写作工作台 — 仪表盘首页
class DashboardView extends GetView<DashboardLogic> with BasePage {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1440),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
            child: Obx(() {
              if (controller.isLoading.value) {
                return loadingIndicator();
              }

              if (controller.hasError) {
                return errorState(
                  controller.errorMessage.value,
                  onRetry: controller.loadData,
                );
              }

              final works = controller.state.works;

              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  // ── page header ───────────────────────────────
                  Text('写作工作台', style: theme.textTheme.displaySmall),
                  SizedBox(height: 6.h),
                  Text(controller.todayLabel, style: theme.textTheme.bodyLarge),
                  SizedBox(height: 28.h),

                  // ── stats row ─────────────────────────────────
                  _buildStatsGrid(colorScheme, works),
                  SizedBox(height: 24.h),

                  // ── recent works ──────────────────────────────
                  AppSectionCard(
                    title: '最近作品',
                    subtitle: '你最近编辑过的作品',
                    child: works.isEmpty
                        ? Padding(
                            padding: EdgeInsets.symmetric(vertical: 24.h),
                            child: Center(
                              child: Text(
                                '还没有作品，快去创建吧',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          )
                        : Column(
                            children: controller.recentWorks.map((work) {
                              return Padding(
                                padding: EdgeInsets.only(bottom: 10.h),
                                child: Material(
                                  color: colorScheme.surfaceContainerLowest
                                      .withValues(alpha: 0.72),
                                  borderRadius: BorderRadius.circular(22.r),
                                  child: InkWell(
                                    onTap: () => Get.toNamed(
                                      '/work/${work.id}',
                                    ),
                                    borderRadius: BorderRadius.circular(22.r),
                                    child: Padding(
                                      padding: EdgeInsets.all(16.w),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 42.w,
                                            height: 42.h,
                                            decoration: BoxDecoration(
                                              color: colorScheme.primaryContainer
                                                  .withValues(alpha: 0.6),
                                              borderRadius:
                                                  BorderRadius.circular(14.r),
                                            ),
                                            child: Icon(
                                              Icons.auto_stories_rounded,
                                              color: colorScheme.primary,
                                            ),
                                          ),
                                          SizedBox(width: 14.w),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  work.name,
                                                  style: theme
                                                      .textTheme.titleMedium,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                SizedBox(height: 4.h),
                                                Text(
                                                  '${work.statusText} · ${work.progressText}',
                                                  style:
                                                      theme.textTheme.bodySmall,
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            Icons.arrow_forward_rounded,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                  SizedBox(height: 24.h),

                  // ── quick actions ──────────────────────────────
                  AppSectionCard(
                    title: '快捷操作',
                    subtitle: '常用功能一键直达',
                    child: Column(
                      children: [
                        AppActionTile(
                          icon: Icons.add_rounded,
                          title: '新建作品',
                          description: '创建一部新的小说或文稿',
                          onTap: () => Get.toNamed(AppRoutes.workNew),
                        ),
                        SizedBox(height: 10.h),
                        AppActionTile(
                          icon: Icons.rate_review_rounded,
                          title: 'AI 审稿',
                          description: '使用 AI 检查章节质量与连贯性',
                          onTap: () => controller.showInfoSnackbar(
                            'AI 审稿功能即将上线',
                          ),
                          accent: colorScheme.secondary,
                        ),
                        SizedBox(height: 10.h),
                        AppActionTile(
                          icon: Icons.psychology_rounded,
                          title: '角色模拟',
                          description: '与角色对话，探索人物性格',
                          onTap: () => controller.showInfoSnackbar(
                            '角色模拟功能即将上线',
                          ),
                          accent: colorScheme.tertiary,
                        ),
                        SizedBox(height: 10.h),
                        AppActionTile(
                          icon: Icons.data_object_rounded,
                          title: '设定提取',
                          description: '从文本中自动提取世界观和设定',
                          onTap: () => controller.showInfoSnackbar(
                            '设定提取功能即将上线',
                          ),
                          accent: colorScheme.error,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // ── writing tip ────────────────────────────────
                  _buildWritingTipCard(theme, colorScheme),
                  SizedBox(height: 24.h),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  // ─── stats grid ──────────────────────────────────────────────

  Widget _buildStatsGrid(ColorScheme colorScheme, List<dynamic> works) {
    final cards = [
      AppStatCard(
        icon: Icons.text_fields_rounded,
        label: '总字数',
        value: controller.formatNumber(controller.totalWords),
        hint: '所有作品累计',
        accent: colorScheme.primary,
      ),
      AppStatCard(
        icon: Icons.auto_stories_rounded,
        label: '作品数',
        value: '${works.length}',
        hint: '部作品',
        accent: colorScheme.secondary,
      ),
      AppStatCard(
        icon: Icons.edit_note_rounded,
        label: '今日写作',
        value: controller.formatNumber(controller.todayWords),
        hint: '字',
        accent: colorScheme.tertiary,
      ),
      AppStatCard(
        icon: Icons.local_fire_department_rounded,
        label: '连续天数',
        value: '${controller.streak}',
        hint: '天连续写作',
        accent: colorScheme.error,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 860;
        final crossCount = wide ? 4 : 2;
        final aspectRatio = wide ? 1.1 : 1.2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisSpacing: 16.h,
            crossAxisSpacing: 16.w,
            childAspectRatio: aspectRatio,
          ),
          itemBuilder: (context, index) => cards[index],
        );
      },
    );
  }

  // ─── writing tip card ────────────────────────────────────────

  Widget _buildWritingTipCard(ThemeData theme, ColorScheme colorScheme) {
    const tips = [
      '每天写一点，比偶尔写很多更容易保持创作状态。',
      '不要追求完美初稿，先把故事讲完，再回头打磨。',
      '卡文时试试换个角色的视角重写同一段场景。',
      '写作瓶颈往往意味着你的潜意识正在处理一个大转折。',
      '把长篇拆成短目标，每完成一个小目标就奖励自己。',
      '先写你最有感觉的场景，不必从第一章开始。',
    ];
    final tip = tips[DateTime.now().day % tips.length];

    return Card(
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40.w,
              height: 40.h,
              decoration: BoxDecoration(
                color: colorScheme.tertiaryContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Icon(
                Icons.lightbulb_outline_rounded,
                color: colorScheme.tertiary,
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('写作小贴士', style: theme.textTheme.titleMedium),
                  SizedBox(height: 6.h),
                  Text(tip, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
