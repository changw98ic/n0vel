import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';
import '../../../../../app/widgets/app_shell.dart';
import '../../../../../shared/data/base_business/base_page.dart';
import 'work_detail_logic.dart';
import 'work_detail_state.dart';
import '../../../../../features/work/domain/work.dart';
import '../../../../../features/work/domain/volume.dart';
import '../../../../../features/editor/domain/chapter.dart';

class WorkDetailView extends GetView<WorkDetailLogic> with BasePage {
  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;

    return Obx(() {
      if (controller.state.isLoading.value) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }

      final work = controller.state.work.value;
      if (work == null) {
        return AppPageScaffold(
          title: s.work_workNotExist,
          child: AppEmptyState(
            icon: Icons.error_outline_rounded,
            title: s.work_workNotFound,
            description: s.work_workNotFoundDesc,
            action: FilledButton(
              onPressed: () => Get.offAllNamed('/'),
              child: Text(s.work_backToLibrary),
            ),
          ),
        );
      }

      return AppPageScaffold(
        title: work.name,
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: s.work_searchCurrentWork,
            onPressed: () => Get.toNamed('/search?workId=${controller.workId}'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: s.work_refresh,
            onPressed: controller.loadData,
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: s.work_workSettings,
            onPressed: () => Get.toNamed('/work/${controller.workId}/settings'),
          ),
          SizedBox(width: 12.w),
        ],
        bottom: _buildSegmentBar(s, work),
        child: ListView(
          children: [
            // Compact stats row
            Padding(
              padding: EdgeInsets.only(bottom: 20.h),
              child: Wrap(
                spacing: 10.w,
                runSpacing: 8.h,
                children: [
                  AppTag(
                    label: work.type?.isNotEmpty == true
                        ? work.type!
                        : s.work_otherType,
                    icon: Icons.book_rounded,
                  ),
                  AppTag(
                    label: work.progressText,
                    icon: Icons.timeline_rounded,
                  ),
                  AppTag(
                    label: s.work_chaptersCount('${controller.chapterCount}'),
                    icon: Icons.article_rounded,
                  ),
                  AppTag(
                    label: s.work_wordsCount('${controller.totalWords}'),
                    icon: Icons.text_fields_rounded,
                  ),
                ],
              ),
            ),
            _buildSelectedPanel(context, s, work),
          ],
        ),
      );
    });
  }

  Widget _buildSegmentBar(S s, Work work) {
    return Obx(() {
      return Align(
        alignment: Alignment.centerLeft,
        child: SegmentedButton<WorkDetailPanel>(
          segments: [
            ButtonSegment(
              value: WorkDetailPanel.chapters,
              icon: const Icon(Icons.library_books_rounded),
              label: Text(s.work_chapters),
            ),
            ButtonSegment(
              value: WorkDetailPanel.world,
              icon: const Icon(Icons.public_rounded),
              label: Text(s.work_settings),
            ),
            ButtonSegment(
              value: WorkDetailPanel.studio,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: Text(s.work_creation),
            ),
            ButtonSegment(
              value: WorkDetailPanel.insight,
              icon: const Icon(Icons.insights_rounded),
              label: Text(s.work_analysis),
            ),
          ],
          selected: {controller.state.selectedPanel.value},
          onSelectionChanged: (selection) {
            controller.selectPanel(selection.first);
          },
        ),
      );
    });
  }

  Widget _buildSelectedPanel(BuildContext context, S s, Work work) {
    return Obx(() {
      final panel = controller.state.selectedPanel.value;
      return switch (panel) {
        WorkDetailPanel.chapters => _buildChaptersPanel(context, s),
        WorkDetailPanel.world => _buildActionGrid(context, [
            _ActionItem(Icons.people_alt_rounded, s.work_characters,
                '/work/${controller.workId}/characters'),
            _ActionItem(Icons.hub_rounded, s.work_relationships,
                '/work/${controller.workId}/relationships'),
            _ActionItem(Icons.place_rounded, s.work_locations,
                '/work/${controller.workId}/locations'),
            _ActionItem(Icons.groups_rounded, s.work_factions,
                '/work/${controller.workId}/factions'),
            _ActionItem(Icons.inventory_2_rounded, s.work_items,
                '/work/${controller.workId}/items'),
            _ActionItem(Icons.settings_rounded,
                s.work_workSettingsLabel,
                '/work/${controller.workId}/settings'),
          ]),
        WorkDetailPanel.studio => _buildActionGrid(context, [
            _ActionItem(Icons.rate_review_rounded,
                s.work_reviewCenter,
                '/work/${controller.workId}/review'),
            _ActionItem(Icons.auto_awesome_rounded,
                s.work_povGeneration,
                '/work/${controller.workId}/pov'),
            _ActionItem(Icons.chrome_reader_mode_rounded,
                s.work_readingMode,
                '/work/${controller.workId}/read'),
            _ActionItem(Icons.smart_toy_rounded,
                s.work_aiUsageStats,
                '/work/${controller.workId}/ai-usage-stats'),
          ]),
        WorkDetailPanel.insight => _buildActionGrid(context, [
            _ActionItem(Icons.insights_rounded,
                s.work_statistics,
                '/work/${controller.workId}/stats'),
            _ActionItem(Icons.alt_route_rounded, s.work_timeline,
                '/work/${controller.workId}/timeline'),
            _ActionItem(Icons.search_rounded,
                s.work_searchWorkContent,
                '/search?workId=${controller.workId}'),
            _ActionItem(Icons.verified_user_rounded,
                s.work_aiDetection, '/ai-detection'),
          ]),
      };
    });
  }

  Widget _buildActionGrid(BuildContext context, List<_ActionItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 980 ? 2 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 3.0,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return Material(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerLow
                  .withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16.r),
              child: InkWell(
                onTap: () => Get.toNamed(item.route),
                borderRadius: BorderRadius.circular(16.r),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18.w),
                  child: Row(
                    children: [
                      Icon(item.icon, size: 20.sp),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: Text(
                          item.title,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChaptersPanel(BuildContext context, S s) {
    return Obx(() {
      if (controller.state.volumes.isEmpty) {
        return AppEmptyState(
          icon: Icons.article_outlined,
          title: s.work_noChaptersYet,
          description: s.work_noChaptersYetDesc,
          action: FilledButton.icon(
            onPressed: () => controller.createChapter(context),
            icon: const Icon(Icons.add_rounded),
            label: Text(s.work_createFirstChapter),
          ),
        );
      }

      return Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(s.work_chapters, style: Theme.of(context).textTheme.titleMedium)),
              FilledButton.icon(
                onPressed: () => controller.createChapter(context),
                icon: const Icon(Icons.add_rounded),
                label: Text(s.work_newChapterLabel),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          ...controller.state.volumes.map((volume) {
            final chapters = controller.state.chaptersByVolume[volume.id] ?? const <Chapter>[];
            return Padding(
              padding: EdgeInsets.only(bottom: 18.h),
              child: _VolumePanel(
                volume: volume,
                chapters: chapters,
                onOpenChapter: (chapter) =>
                    Get.toNamed('/work/${controller.workId}/chapter/${chapter.id}')
                        ?.then((_) => controller.loadData()),
                controller: controller,
              ),
            );
          }),
        ],
      );
    });
  }
}

class _ActionItem {
  final IconData icon;
  final String title;
  final String route;

  const _ActionItem(this.icon, this.title, this.route);
}

class _VolumePanel extends StatelessWidget {
  final Volume volume;
  final List<Chapter> chapters;
  final ValueChanged<Chapter> onOpenChapter;
  final WorkDetailLogic controller;

  const _VolumePanel({
    required this.volume,
    required this.chapters,
    required this.onOpenChapter,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final theme = Theme.of(context);
    final totalWords = chapters.fold<int>(
      0,
      (sum, chapter) => sum + chapter.wordCount,
    );

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      padding: EdgeInsets.all(22.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onLongPress: () => controller.deleteVolume(context, volume),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(volume.name, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        s.work_volumeChaptersWords('${chapters.length}', '$totalWords'),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              AppTag(
                label: s.work_readingTime(
                  '${chapters.fold<int>(0, (sum, ch) => sum + ch.estimatedReadingTime)}',
                ),
                icon: Icons.schedule_rounded,
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (chapters.isEmpty)
            Text(s.work_noChaptersInVolume, style: theme.textTheme.bodyMedium)
          else
            ...chapters.map((chapter) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () => onOpenChapter(chapter),
                  onLongPress: () => controller.deleteChapter(context, chapter),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                    child: Row(
                      children: [
                        Icon(Icons.article_rounded, size: 20.sp,
                            color: theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${chapter.title} · ${chapter.wordCount} 字',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        if (chapter.reviewScore != null)
                          Padding(
                            padding: EdgeInsets.only(right: 8.w),
                            child: Text(
                              chapter.reviewScore!.toStringAsFixed(1),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.tertiary,
                              ),
                            ),
                          ),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            )),
        ],
      ),
    );
  }
}
