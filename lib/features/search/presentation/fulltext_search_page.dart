import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../../app/navigation/app_navigator.dart';
import '../../../app/state/fulltext_search_service.dart';
import '../../../app/state/fulltext_search_storage.dart';
import '../../../app/widgets/desktop_shell.dart';

/// 全文搜索 Riverpod 状态。
class FulltextSearchState {
  const FulltextSearchState({
    this.query = '',
    this.characterFilter,
    this.chapterRangeStart,
    this.chapterRangeEnd,
    this.page = 0,
    this.pageSize = 20,
    this.sortOrder = FulltextSortOrder.relevance,
    this.results,
    this.isLoading = false,
    this.error,
    this.availableCharacters = const [],
    this.chapterRange,
  });

  final String query;
  final String? characterFilter;
  final int? chapterRangeStart;
  final int? chapterRangeEnd;
  final int page;
  final int pageSize;
  final FulltextSortOrder sortOrder;
  final FulltextSearchResultSet? results;
  final bool isLoading;
  final String? error;
  final List<String> availableCharacters;
  final (int, int)? chapterRange;

  FulltextSearchState copyWith({
    String? query,
    String? characterFilter,
    int? chapterRangeStart,
    int? chapterRangeEnd,
    int? page,
    int? pageSize,
    FulltextSortOrder? sortOrder,
    FulltextSearchResultSet? results,
    bool? isLoading,
    String? error,
    List<String>? availableCharacters,
    (int, int)? chapterRange,
    bool clearCharacterFilter = false,
    bool clearChapterRange = false,
    bool clearError = false,
  }) {
    return FulltextSearchState(
      query: query ?? this.query,
      characterFilter: clearCharacterFilter
          ? null
          : (characterFilter ?? this.characterFilter),
      chapterRangeStart: clearChapterRange
          ? null
          : (chapterRangeStart ?? this.chapterRangeStart),
      chapterRangeEnd: clearChapterRange
          ? null
          : (chapterRangeEnd ?? this.chapterRangeEnd),
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      sortOrder: sortOrder ?? this.sortOrder,
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      availableCharacters: availableCharacters ?? this.availableCharacters,
      chapterRange: chapterRange ?? this.chapterRange,
    );
  }
}

/// 全文搜索状态管理 Notifier。
class FulltextSearchNotifier extends Notifier<FulltextSearchState> {
  @override
  FulltextSearchState build() {
    return const FulltextSearchState();
  }

  FulltextSearchService get _service {
    final registry = ref.read(serviceRegistryProvider);
    return registry.resolve<FulltextSearchService>();
  }

  String get _projectId => ref.read(appWorkspaceStoreProvider).currentProjectId;

  /// 执行搜索。
  Future<void> search() async {
    final query = state.query.trim();
    if (query.isEmpty) {
      state = state.copyWith(results: null, clearError: true);
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final result = await _service.search(
        projectId: _projectId,
        query: query,
        characterFilter: state.characterFilter,
        chapterRangeStart: state.chapterRangeStart,
        chapterRangeEnd: state.chapterRangeEnd,
        page: state.page,
        pageSize: state.pageSize,
        sortOrder: state.sortOrder,
      );
      state = state.copyWith(results: result, isLoading: false);
    } on Object catch (e) {
      state = state.copyWith(isLoading: false, error: '搜索失败: $e');
    }
  }

  /// 更新搜索关键词。
  void updateQuery(String query) {
    state = state.copyWith(query: query, page: 0);
  }

  /// 更新角色过滤。
  void updateCharacterFilter(String? filter) {
    state = state.copyWith(
      characterFilter: filter,
      clearCharacterFilter: filter == null,
      page: 0,
    );
  }

  /// 更新章节范围。
  void updateChapterRange({int? start, int? end}) {
    state = state.copyWith(
      chapterRangeStart: start,
      chapterRangeEnd: end,
      clearChapterRange: start == null && end == null,
      page: 0,
    );
  }

  /// 更新排序策略。
  void updateSortOrder(FulltextSortOrder order) {
    state = state.copyWith(sortOrder: order, page: 0);
  }

  /// 跳转到指定页。
  void goToPage(int page) {
    state = state.copyWith(page: page);
  }

  /// 上一页。
  void previousPage() {
    if (state.page > 0) {
      state = state.copyWith(page: state.page - 1);
    }
  }

  /// 下一页。
  void nextPage() {
    if (state.results != null && state.results!.hasNextPage) {
      state = state.copyWith(page: state.page + 1);
    }
  }

  /// 加载可用角色名列表。
  Future<void> loadCharacterNames() async {
    try {
      final names = await _service.indexedCharacterNames(_projectId);
      state = state.copyWith(availableCharacters: names);
    } on Object {
      // 静默失败
    }
  }

  /// 加载已索引的章节范围。
  Future<void> loadChapterRange() async {
    try {
      final range = await _service.indexedChapterRange(_projectId);
      state = state.copyWith(chapterRange: range);
    } on Object {
      // 静默失败
    }
  }
}

final fulltextSearchProvider =
    NotifierProvider<FulltextSearchNotifier, FulltextSearchState>(
      FulltextSearchNotifier.new,
    );

// ═══════════════════════════════════════════════════════════════════════════
// 全文搜索页面
// ═══════════════════════════════════════════════════════════════════════════

class FulltextSearchPage extends ConsumerStatefulWidget {
  const FulltextSearchPage({super.key});

  static const searchFieldKey = ValueKey<String>('fulltext-search-field');
  static const searchButtonKey = ValueKey<String>('fulltext-search-button');
  static const resultListViewKey = ValueKey<String>('fulltext-result-list');

  @override
  ConsumerState<FulltextSearchPage> createState() => _FulltextSearchPageState();
}

class _FulltextSearchPageState extends ConsumerState<FulltextSearchPage> {
  final TextEditingController _queryController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void dispose() {
    _queryController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fulltextSearchProvider);

    return DesktopShellFrame(
      header: DesktopHeaderBar(
        title: '全文搜索',
        showBackButton: true,
        actions: [
          _SortOrderDropdown(
            value: state.sortOrder,
            onChanged: (order) {
              ref.read(fulltextSearchProvider.notifier).updateSortOrder(order);
              ref.read(fulltextSearchProvider.notifier).search();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── 搜索条件区域 ──
          _SearchCriteriaPanel(
            queryController: _queryController,
            searchFocus: _searchFocus,
            state: state,
            onSearch: _executeSearch,
            onQueryChanged: (q) {
              ref.read(fulltextSearchProvider.notifier).updateQuery(q);
            },
            onCharacterChanged: (c) {
              ref
                  .read(fulltextSearchProvider.notifier)
                  .updateCharacterFilter(c);
            },
            onChapterRangeChanged: (start, end) {
              ref
                  .read(fulltextSearchProvider.notifier)
                  .updateChapterRange(start: start, end: end);
            },
          ),
          const Divider(height: 1),
          // ── 结果区域 ──
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                ? _ErrorDisplay(message: state.error!)
                : state.results == null
                ? _EmptyHint(hasQuery: state.query.isNotEmpty)
                : state.results!.rows.isEmpty
                ? const Center(child: Text('未找到匹配结果'))
                : _ResultList(
                    state: state,
                    onPageChanged: (page) {
                      ref.read(fulltextSearchProvider.notifier).goToPage(page);
                      ref.read(fulltextSearchProvider.notifier).search();
                    },
                    onSceneTap: _navigateToScene,
                  ),
          ),
        ],
      ),
    );
  }

  void _executeSearch() {
    ref.read(fulltextSearchProvider.notifier).search();
  }

  void _navigateToScene(FulltextResultRow row) {
    // 跳转到阅读模式，定位到对应章节/场景
    AppNavigator.push(context, AppRoutes.reading);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 搜索条件面板
// ═══════════════════════════════════════════════════════════════════════════

class _SearchCriteriaPanel extends StatelessWidget {
  const _SearchCriteriaPanel({
    required this.queryController,
    required this.searchFocus,
    required this.state,
    required this.onSearch,
    required this.onQueryChanged,
    required this.onCharacterChanged,
    required this.onChapterRangeChanged,
  });

  final TextEditingController queryController;
  final FocusNode searchFocus;
  final FulltextSearchState state;
  final VoidCallback onSearch;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String?> onCharacterChanged;
  final void Function(int? start, int? end) onChapterRangeChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 搜索框 + 按钮
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: FulltextSearchPage.searchFieldKey,
                  controller: queryController,
                  focusNode: searchFocus,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: '输入关键词搜索章节内容...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: (_) => onSearch(),
                  onChanged: onQueryChanged,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: FulltextSearchPage.searchButtonKey,
                onPressed: onSearch,
                child: const Text('搜索'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 过滤条件行
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // 角色过滤
              _CharacterFilterChip(
                characters: state.availableCharacters,
                selected: state.characterFilter,
                onChanged: onCharacterChanged,
              ),
              // 章节范围
              _ChapterRangeSelector(
                chapterRange: state.chapterRange,
                start: state.chapterRangeStart,
                end: state.chapterRangeEnd,
                onChanged: onChapterRangeChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 角色过滤组件
// ═══════════════════════════════════════════════════════════════════════════

class _CharacterFilterChip extends StatelessWidget {
  const _CharacterFilterChip({
    required this.characters,
    required this.selected,
    required this.onChanged,
  });

  final List<String> characters;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.person_outline, size: 16, color: theme.colorScheme.outline),
        const SizedBox(width: 4),
        DropdownButton<String?>(
          value: selected,
          hint: const Text('角色'),
          isDense: true,
          underline: const SizedBox.shrink(),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('全部角色')),
            for (final name in characters)
              DropdownMenuItem<String?>(value: name, child: Text(name)),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 章节范围选择器
// ═══════════════════════════════════════════════════════════════════════════

class _ChapterRangeSelector extends StatelessWidget {
  const _ChapterRangeSelector({
    required this.chapterRange,
    required this.start,
    required this.end,
    required this.onChanged,
  });

  final (int, int)? chapterRange;
  final int? start;
  final int? end;
  final void Function(int? start, int? end) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rangeLabel = _buildLabel();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.book_outlined, size: 16, color: theme.colorScheme.outline),
        const SizedBox(width: 4),
        ActionChip(
          label: Text(rangeLabel, style: theme.textTheme.bodySmall),
          onPressed: () => _showRangeDialog(context),
          visualDensity: VisualDensity.compact,
        ),
        if (start != null || end != null)
          IconButton(
            icon: const Icon(Icons.close, size: 14),
            visualDensity: VisualDensity.compact,
            onPressed: () => onChanged(null, null),
            tooltip: '清除章节范围',
          ),
      ],
    );
  }

  String _buildLabel() {
    if (start != null && end != null) {
      return '第 $start - $end 章';
    }
    if (start != null) {
      return '从第 $start 章起';
    }
    if (end != null) {
      return '到第 $end 章止';
    }
    return '章节范围';
  }

  void _showRangeDialog(BuildContext context) {
    final startController = TextEditingController(
      text: start?.toString() ?? '',
    );
    final endController = TextEditingController(text: end?.toString() ?? '');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('章节范围'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: startController,
              decoration: const InputDecoration(
                labelText: '起始章节',
                hintText: '如: 1',
                isDense: true,
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: endController,
              decoration: const InputDecoration(
                labelText: '结束章节',
                hintText: '如: 10',
                isDense: true,
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final s = int.tryParse(startController.text);
              final e = int.tryParse(endController.text);
              onChanged(s, e);
              Navigator.of(ctx).pop();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 排序下拉
// ═══════════════════════════════════════════════════════════════════════════

class _SortOrderDropdown extends StatelessWidget {
  const _SortOrderDropdown({required this.value, required this.onChanged});

  final FulltextSortOrder value;
  final ValueChanged<FulltextSortOrder> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<FulltextSortOrder>(
      value: value,
      isDense: true,
      underline: const SizedBox.shrink(),
      items: const [
        DropdownMenuItem(
          value: FulltextSortOrder.relevance,
          child: Text('相关度', style: TextStyle(fontSize: 13)),
        ),
        DropdownMenuItem(
          value: FulltextSortOrder.chapterAsc,
          child: Text('章节升序', style: TextStyle(fontSize: 13)),
        ),
        DropdownMenuItem(
          value: FulltextSortOrder.chapterDesc,
          child: Text('章节降序', style: TextStyle(fontSize: 13)),
        ),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 结果列表
// ═══════════════════════════════════════════════════════════════════════════

class _ResultList extends StatelessWidget {
  const _ResultList({
    required this.state,
    required this.onPageChanged,
    required this.onSceneTap,
  });

  final FulltextSearchState state;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<FulltextResultRow> onSceneTap;

  @override
  Widget build(BuildContext context) {
    final results = state.results!;
    return Column(
      children: [
        // 结果统计
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                '共 ${results.totalCount} 条结果，'
                '第 ${results.page + 1}/${results.totalPages} 页',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
        // 结果列表
        Expanded(
          child: ListView.builder(
            key: FulltextSearchPage.resultListViewKey,
            itemCount: results.rows.length,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (ctx, index) {
              final row = results.rows[index];
              return _ResultCard(row: row, onTap: () => onSceneTap(row));
            },
          ),
        ),
        // 分页控制
        _PaginationBar(
          page: results.page,
          totalPages: results.totalPages,
          hasPrevious: results.hasPreviousPage,
          hasNext: results.hasNextPage,
          onPageChanged: onPageChanged,
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 结果卡片
// ═══════════════════════════════════════════════════════════════════════════

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.row, required this.onTap});

  final FulltextResultRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 第一行：章节号 + 场景标题 + 分数
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '第${row.chapterIndex}章',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      row.sceneTitle,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${(row.score * 100).toStringAsFixed(0)}%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // 章节标题 + 角色
              Row(
                children: [
                  Text(
                    row.chapterTitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  if (row.characterNames.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Icon(
                      Icons.people_outline,
                      size: 12,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      row.characterNames,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              // 高亮摘要
              _HighlightedSnippet(snippet: row.snippet),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 高亮摘要（解析 <mark> 标签）
// ═══════════════════════════════════════════════════════════════════════════

class _HighlightedSnippet extends StatelessWidget {
  const _HighlightedSnippet({required this.snippet});

  final String snippet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlightColor = theme.colorScheme.primaryContainer;
    final spans = _parseHighlight(snippet, highlightColor);

    return RichText(
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: theme.textTheme.bodyMedium?.copyWith(
          height: 1.5,
          color: theme.colorScheme.onSurface,
        ),
        children: spans,
      ),
    );
  }

  /// 解析 <mark>...</mark> 标签为 TextSpan 列表。
  List<TextSpan> _parseHighlight(String text, Color highlightColor) {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'<mark>(.*?)</mark>', dotAll: true);
    var lastEnd = 0;

    for (final match in pattern.allMatches(text)) {
      // match 前的普通文本
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      // 高亮文本
      spans.add(
        TextSpan(
          text: match.group(1),
          style: TextStyle(
            backgroundColor: highlightColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      lastEnd = match.end;
    }
    // 剩余文本
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return spans;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 分页控制栏
// ═══════════════════════════════════════════════════════════════════════════

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.page,
    required this.totalPages,
    required this.hasPrevious,
    required this.hasNext,
    required this.onPageChanged,
  });

  final int page;
  final int totalPages;
  final bool hasPrevious;
  final bool hasNext;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: hasPrevious ? () => onPageChanged(page - 1) : null,
            tooltip: '上一页',
            visualDensity: VisualDensity.compact,
          ),
          // 页码按钮
          ..._buildPageButtons(context),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: hasNext ? () => onPageChanged(page + 1) : null,
            tooltip: '下一页',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageButtons(BuildContext context) {
    final buttons = <Widget>[];
    final start = (page - 2).clamp(0, totalPages - 1);
    final end = (page + 2).clamp(0, totalPages - 1);

    if (start > 0) {
      buttons.add(
        _PageButton(pageNum: 0, isCurrent: false, onTap: onPageChanged),
      );
      if (start > 1) {
        buttons.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('...', style: TextStyle(fontSize: 12)),
          ),
        );
      }
    }

    for (var i = start; i <= end; i++) {
      buttons.add(
        _PageButton(pageNum: i, isCurrent: i == page, onTap: onPageChanged),
      );
    }

    if (end < totalPages - 1) {
      if (end < totalPages - 2) {
        buttons.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('...', style: TextStyle(fontSize: 12)),
          ),
        );
      }
      buttons.add(
        _PageButton(
          pageNum: totalPages - 1,
          isCurrent: false,
          onTap: onPageChanged,
        ),
      );
    }

    return buttons;
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({
    required this.pageNum,
    required this.isCurrent,
    required this.onTap,
  });

  final int pageNum;
  final bool isCurrent;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: SizedBox(
        width: 32,
        height: 32,
        child: isCurrent
            ? FilledButton(
                onPressed: null,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('${pageNum + 1}'),
              )
            : TextButton(
                onPressed: () => onTap(pageNum),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('${pageNum + 1}'),
              ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 辅助组件
// ═══════════════════════════════════════════════════════════════════════════

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.hasQuery});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search,
            size: 48,
            color: theme.colorScheme.outline.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            hasQuery ? '按回车或点击搜索按钮开始检索' : '输入关键词搜索章节内容',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '支持中文、英文搜索，可按角色和章节范围过滤',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorDisplay extends StatelessWidget {
  const _ErrorDisplay({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 12),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
