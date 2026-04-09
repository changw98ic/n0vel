import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';

class FilterBar<T> extends StatefulWidget {
  final String? searchQuery;
  final void Function(String) onSearchChanged;
  final List<FilterOption<T>> filters;
  final T? selectedFilter;
  final void Function(T?) onFilterChanged;
  final SortOption? sortOption;
  final List<SortOption> availableSorts;
  final void Function(SortOption?) onSortChanged;

  const FilterBar({
    super.key,
    this.searchQuery,
    required this.onSearchChanged,
    this.filters = const [],
    this.selectedFilter,
    required this.onFilterChanged,
    this.sortOption,
    this.availableSorts = const [],
    required this.onSortChanged,
  });

  @override
  State<FilterBar<T>> createState() => _FilterBarState<T>();
}

class _FilterBarState<T> extends State<FilterBar<T>> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery ?? '');
  }

  @override
  void didUpdateWidget(covariant FilterBar<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextValue = widget.searchQuery ?? '';
    if (nextValue == _searchController.text) {
      return;
    }

    _searchController.value = TextEditingValue(
      text: nextValue,
      selection: TextSelection.collapsed(offset: nextValue.length),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: s.search,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 12.w),
                suffixIcon:
                    widget.searchQuery != null && widget.searchQuery!.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          widget.onSearchChanged('');
                        },
                      )
                    : null,
              ),
              onChanged: widget.onSearchChanged,
            ),
          ),
          if (widget.filters.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(left: 8.w),
              child: PopupMenuButton<T>(
                icon: const Icon(Icons.filter_list),
                tooltip: _labelFor(context, zh: '筛选', en: 'Filter'),
                onSelected: widget.onFilterChanged,
                itemBuilder: (context) => widget.filters
                    .map(
                      (filter) => PopupMenuItem(
                        value: filter.value,
                        child: Text(filter.label),
                      ),
                    )
                    .toList(),
              ),
            ),
          if (widget.availableSorts.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(left: 8.w),
              child: PopupMenuButton<SortOption>(
                icon: const Icon(Icons.sort),
                tooltip: _labelFor(context, zh: '排序', en: 'Sort'),
                onSelected: widget.onSortChanged,
                itemBuilder: (context) => widget.availableSorts
                    .map(
                      (sort) =>
                          PopupMenuItem(value: sort, child: Text(sort.label)),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  String _labelFor(
    BuildContext context, {
    required String zh,
    required String en,
  }) {
    final locale = Localizations.localeOf(context);
    return locale.languageCode.startsWith('zh') ? zh : en;
  }
}

class FilterOption<T> {
  final T value;
  final String label;

  const FilterOption({required this.value, required this.label});
}

class SortOption {
  final String value;
  final String label;

  const SortOption({required this.value, required this.label});
}
