import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';
import '../../../../../app/widgets/app_shell.dart';
import '../../../../../shared/data/base_business/base_page.dart';
import 'search_logic.dart';

class SearchView extends GetView<SearchLogic> with BasePage {
  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;

    return AppPageScaffold(
      title: s.work_search,
      actions: [
        if (controller.state.workId.isNotEmpty)
          IconButton(
            tooltip: s.work_backToWork,
            icon: const Icon(Icons.auto_stories_rounded),
            onPressed: () => Get.offAllNamed('/work/${controller.state.workId.value}'),
          ),
        SizedBox(width: 12.w),
      ],
      child: ListView(
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: _SearchBar(
              controller: controller,
              onSearch: (query, persist) => controller.search(query, persist: persist),
            ),
          ),
          Obx(() {
            if (controller.state.recentSearches.isNotEmpty) {
              return Column(
                children: [
                  SizedBox(height: 24.h),
                  AppSectionCard(
                    title: _labelFor(context, zh: '最近搜索', en: 'Recent searches'),
                    trailing: TextButton(
                      onPressed: controller.clearRecentSearches,
                      child: Text(_labelFor(context, zh: '清空', en: 'Clear')),
                    ),
                    child: Wrap(
                      spacing: 10.w,
                      runSpacing: 10.h,
                      children: controller.state.recentSearches
                          .map(
                            (query) => ActionChip(
                              label: Text(query),
                              onPressed: () {
                                controller.search(query, persist: true);
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              );
            }
            return const SizedBox.shrink();
          }),
          SizedBox(height: 24.h),
          AppSectionCard(
            title: s.work_searchResultsTitle,
            child: _ResultsBuilder(controller: controller),
          ),
        ],
      ),
    );
  }

  String _labelFor(BuildContext context, {required String zh, required String en}) {
    final locale = Localizations.localeOf(context);
    return locale.languageCode.startsWith('zh') ? zh : en;
  }
}

class _SearchBar extends StatefulWidget {
  final SearchLogic controller;
  final Function(String query, bool persist) onSearch;

  const _SearchBar({
    required this.controller,
    required this.onSearch,
  });

  @override
  State<_SearchBar> createState() => _SearchBarController();
}

class _SearchBarController extends State<_SearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            autofocus: true,
            onChanged: (_) => widget.controller.searchDebounce(
              () => widget.onSearch(_controller.text, false),
            ),
            onSubmitted: (_) => widget.onSearch(_controller.text, true),
            decoration: InputDecoration(
              hintText: widget.controller.state.workId.isEmpty
                  ? s.work_searchGlobalHint
                  : s.work_searchInWorkHint,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward_rounded),
                onPressed: () => widget.onSearch(_controller.text, true),
              ),
            ),
          ),
        ),
        SizedBox(width: 12.w),
        FilledButton.icon(
          onPressed: () => widget.onSearch(_controller.text, true),
          icon: const Icon(Icons.travel_explore_rounded),
          label: Text(s.work_startSearch),
        ),
      ],
    );
  }
}

class _ResultsBuilder extends StatelessWidget {
  final SearchLogic controller;

  const _ResultsBuilder({required this.controller});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;

    return Obx(() {
      final searchFuture = controller.state.searchFuture.value;

      if (searchFuture == null) {
        return SizedBox(
          height: 320.h,
          child: AppEmptyState(
            icon: Icons.search_rounded,
            title: s.work_enterKeyword,
            description: s.work_enterKeywordDesc,
          ),
        );
      }

      return FutureBuilder<List<dynamic>>(
        future: searchFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return SizedBox(
              height: 240.h,
              child: const Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return SizedBox(
              height: 240.h,
              child: AppEmptyState(
                icon: Icons.error_outline_rounded,
                title: s.work_searchFailed,
                description: s.work_searchFailedDesc,
                action: FilledButton(
                  onPressed: () => controller.search('', persist: true),
                  child: Text(s.work_retry),
                ),
              ),
            );
          }

          final results = snapshot.data ?? const <dynamic>[];
          final availableTypes = results
              .map((item) => item.type)
              .toSet()
              .toList();
          final filtered = controller.state.selectedType.value == null
              ? results
              : results.where((item) => item.type == controller.state.selectedType.value).toList();

          if (results.isEmpty) {
            return SizedBox(
              height: 240.h,
              child: AppEmptyState(
                icon: Icons.inbox_outlined,
                title: s.work_noResults,
                description: s.work_noResultsDesc,
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: [
                  ChoiceChip(
                    label: Text(_labelFor(context, zh: '全部', en: 'All')),
                    selected: controller.state.selectedType.value == null,
                    onSelected: (_) => controller.selectType(null),
                  ),
                  ...availableTypes.map(
                    (type) => ChoiceChip(
                      label: Text(_typeLabel(context, type)),
                      selected: controller.state.selectedType.value == type,
                      onSelected: (_) => controller.selectType(type),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => SizedBox(height: 12.h),
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  final accent = _accentForType(context, item.type);

                  return Material(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerLowest.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(24.r),
                    child: InkWell(
                      onTap: () => controller.openResult(item),
                      borderRadius: BorderRadius.circular(24.r),
                      child: Padding(
                        padding: EdgeInsets.all(18.w),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                              child: Icon(_typeIcons[item.type] ?? Icons.article_rounded, color: accent),
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _HighlightedText(
                                    text: item.title,
                                    query: '',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium!,
                                    highlightColor: accent,
                                  ),
                                  SizedBox(height: 6.h),
                                  if (item.workTitle != null &&
                                      controller.state.workId.isEmpty)
                                    Padding(
                                      padding: EdgeInsets.only(bottom: 6.h),
                                      child: Text(
                                        item.workTitle!,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ),
                                  if (item.subtitle != null &&
                                      item.subtitle!.isNotEmpty)
                                    _HighlightedText(
                                      text: item.subtitle!,
                                      query: '',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall!,
                                      highlightColor: accent,
                                      maxLines: 2,
                                    ),
                                ],
                              ),
                            ),
                            SizedBox(width: 12.w),
                            AppTag(
                              label: _typeLabel(context, item.type),
                              icon: _typeIcons[item.type] ?? Icons.article_rounded,
                              color: accent,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      );
    });
  }

  Color _accentForType(BuildContext context, String type) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (type) {
      'work' => colorScheme.primary,
      'chapter' => colorScheme.secondary,
      'character' => colorScheme.tertiary,
      'item' => colorScheme.primary,
      'location' => colorScheme.secondary,
      'faction' => colorScheme.tertiary,
      _ => colorScheme.primary,
    };
  }

  static const _typeIcons = <String, IconData>{
    'work': Icons.menu_book_rounded,
    'chapter': Icons.article_rounded,
    'character': Icons.person_rounded,
    'item': Icons.inventory_2_rounded,
    'location': Icons.place_rounded,
    'faction': Icons.groups_rounded,
  };

  String _typeLabel(BuildContext context, String type) {
    final s = S.of(context)!;
    return switch (type) {
      'work' => s.work_typeWork,
      'chapter' => s.work_typeChapter,
      'character' => s.work_typeCharacter,
      'item' => s.work_typeItem,
      'location' => s.work_typeLocation,
      'faction' => s.work_typeFaction,
      _ => 'Unknown',
    };
  }

  String _labelFor(BuildContext context, {required String zh, required String en}) {
    final locale = Localizations.localeOf(context);
    return locale.languageCode.startsWith('zh') ? zh : en;
  }
}

class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;
  final Color highlightColor;
  final int? maxLines;

  const _HighlightedText({
    required this.text,
    required this.query,
    required this.style,
    required this.highlightColor,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    final normalizedText = text.toLowerCase();
    final normalizedQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;

    while (start < text.length) {
      final index = normalizedText.indexOf(normalizedQuery, start);
      if (index < 0) {
        spans.add(TextSpan(text: text.substring(start), style: style));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: style));
      }
      final end = index + query.length;
      spans.add(
        TextSpan(
          text: text.substring(index, end),
          style: style.copyWith(
            color: highlightColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      start = end;
    }

    return RichText(
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(children: spans),
    );
  }
}
