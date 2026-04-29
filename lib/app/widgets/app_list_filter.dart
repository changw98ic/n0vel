import 'package:flutter/material.dart';

import 'desktop_theme.dart';

/// A sort option for list items of type [T].
class AppListSortOption<T> {
  const AppListSortOption({
    required this.label,
    required this.compare,
  });

  final String label;
  final int Function(T a, T b) compare;
}

/// A filter option for list items of type [T].
class AppListFilterOption<T> {
  const AppListFilterOption({
    required this.label,
    required this.test,
  });

  final String label;
  final bool Function(T item) test;
}

/// Applies search, category filter, and sort to a source list.
/// Returns a new list; does not mutate [items].
List<T> applyListFilter<T>({
  required List<T> items,
  String searchQuery = '',
  String Function(T item)? searchExtractor,
  AppListFilterOption<T>? activeFilter,
  AppListSortOption<T>? activeSort,
}) {
  var result = items;

  if (searchQuery.isNotEmpty && searchExtractor != null) {
    final query = searchQuery.toLowerCase();
    result = result
        .where((item) => searchExtractor(item).toLowerCase().contains(query))
        .toList();
  }

  if (activeFilter != null) {
    result = result.where(activeFilter.test).toList();
  }

  if (activeSort != null) {
    result = List<T>.from(result)..sort(activeSort.compare);
  }

  return result;
}

/// A compact dropdown that lets the user pick one sort option.
class AppListSortDropdown<T> extends StatelessWidget {
  const AppListSortDropdown({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<AppListSortOption<T>> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    final current = options[selectedIndex];

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: palette.elevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: PopupMenuButton<int>(
        offset: const Offset(0, 34),
        constraints: const BoxConstraints(minWidth: 140),
        itemBuilder: (_) => [
          for (var i = 0; i < options.length; i++)
            PopupMenuItem<int>(
              value: i,
              child: Row(
                children: [
                  Text(options[i].label, style: theme.textTheme.bodySmall),
                  const Spacer(),
                  if (i == selectedIndex)
                    Icon(Icons.check, size: 16, color: palette.primary),
                ],
              ),
            ),
        ],
        onSelected: onChanged,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              current.label,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(width: 4),
            Icon(Icons.unfold_more, size: 14, color: palette.tertiaryText),
          ],
        ),
      ),
    );
  }
}

/// A horizontal row of filter chips for narrowing by category.
class AppListFilterChipBar<T> extends StatelessWidget {
  const AppListFilterChipBar({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<AppListFilterOption<T>> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < options.length; i++)
          _FilterChipButton(
            label: options[i].label,
            selected: i == selectedIndex,
            onTap: () => onChanged(i),
          ),
      ],
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = desktopPalette(context);
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? palette.primary : palette.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? palette.primary : palette.border,
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: selected ? Colors.white : theme.colorScheme.onSurface,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
