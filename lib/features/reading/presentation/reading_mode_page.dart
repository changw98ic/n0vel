import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../../app/navigation/reading_route_data.dart';
import '../../../app/widgets/desktop_theme.dart';
import '../../../domain/scene_location_parts.dart';

import 'reading_mode_components.dart';

class ReadingModePage extends ConsumerStatefulWidget {
  const ReadingModePage({super.key, this.session});

  static const pageBodyKey = ValueKey<String>('reading-mode-page-body');
  static const closeButtonKey = ValueKey<String>('reading-mode-close-button');
  static const pageIndicatorKey = ValueKey<String>(
    'reading-mode-page-indicator',
  );
  static const boundaryHintKey = ValueKey<String>('reading-mode-boundary-hint');
  static const previousHotzoneKey = ValueKey<String>(
    'reading-mode-previous-hotzone',
  );
  static const nextHotzoneKey = ValueKey<String>('reading-mode-next-hotzone');

  final ReadingSessionData? session;

  @override
  ConsumerState<ReadingModePage> createState() => _ReadingModePageState();
}

class _ReadingModePageState extends ConsumerState<ReadingModePage> {
  static const int _pageCharThreshold = 220;

  final FocusNode _pageFocusNode = FocusNode();
  ReadingSessionData? _activeSession;
  List<ReadingDocumentPages> _documents = const [];
  int _sceneIndex = 0;
  int _pageIndex = 0;
  String? _edgeFeedback;

  @override
  void dispose() {
    _pageFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    final session = widget.session ?? _fallbackSession(context);
    _synchronizeSession(session);

    final currentDocument = _documents[_sceneIndex];
    final currentPage = currentDocument.pages[_pageIndex];
    final footerHint = _edgeFeedback ?? _defaultFooterHint();
    final inlineNotice = _inlineNoticeData();
    final previousLabel = _previousHotzoneLabel();
    final nextLabel = _nextHotzoneLabel();

    const warmPaperBg = Color(0xFFF5F0E8);
    const warmPaperSurface = Color(0xFFFAF6EF);

    return Scaffold(
      backgroundColor: warmPaperBg,
      body: SafeArea(
        child: Focus(
          autofocus: true,
          focusNode: _pageFocusNode,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) {
              return KeyEventResult.ignored;
            }
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              Navigator.of(context).pop();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              _goPreviousPage();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              _goNextPage();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
            child: Column(
              children: [
                Row(
                  children: [
                    OutlinedButton(
                      key: ReadingModePage.closeButtonKey,
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.primary,
                        side: BorderSide(color: palette.border),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('返回写作'),
                    ),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Center(
                          child: Text(
                            '${session.projectTitle} · ${chapterLocationLabel(currentDocument.locationLabel)}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 120),
                  ],
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ReadingHotzone(
                        zoneKey: ReadingModePage.previousHotzoneKey,
                        label: previousLabel,
                        enabled: _canGoPrevious(),
                        onTap: _goPreviousPage,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Semantics(
                          label: '阅读内容',
                          child: Container(
                            key: ReadingModePage.pageBodyKey,
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 36,
                              vertical: 28,
                            ),
                            decoration: BoxDecoration(
                              color: warmPaperSurface,
                              border: Border.all(
                                color: palette.border.withValues(alpha: 0.4),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentPage,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: theme.colorScheme.onSurface,
                                      height: 1.72,
                                    ),
                                  ),
                                  if (inlineNotice != null) ...[
                                    const SizedBox(height: 18),
                                    ReadingInlineNoticeCard(
                                      data: inlineNotice,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      ReadingHotzone(
                        zoneKey: ReadingModePage.nextHotzoneKey,
                        label: nextLabel,
                        enabled: _canGoNext(),
                        onTap: _goNextPage,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE7DC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Semantics(
                        liveRegion: true,
                        label: _pageIndicatorText(),
                        child: Text(
                          _pageIndicatorText(),
                          key: ReadingModePage.pageIndicatorKey,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: palette.secondaryText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Expanded(
                        key: ReadingModePage.boundaryHintKey,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Text(
                            footerHint,
                            key: ValueKey<String>(
                              '${ReadingModePage.boundaryHintKey.value}-$footerHint',
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.tertiaryText,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _synchronizeSession(ReadingSessionData session) {
    if (_activeSession?.signature == session.signature) {
      return;
    }
    _activeSession = session;
    _documents = [
      for (final document in session.documents)
        ReadingDocumentPages(
          sceneId: document.sceneId,
          locationLabel: document.locationLabel,
          pages: _paginate(document.text),
        ),
    ];
    final initialIndex = _documents.indexWhere(
      (document) => document.sceneId == session.initialSceneId,
    );
    _sceneIndex = initialIndex == -1 ? 0 : initialIndex;
    _pageIndex = 0;
    _edgeFeedback = null;
  }

  ReadingSessionData _fallbackSession(BuildContext context) {
    final draft = ref.read(appDraftStoreProvider).snapshot;
    final workspace = ref.read(appWorkspaceStoreProvider);
    return ReadingSessionData(
      projectTitle: workspace.currentProject.title,
      initialSceneId: workspace.currentProject.sceneId,
      documents: [
        ReadingSceneDocument(
          sceneId: workspace.currentProject.sceneId,
          locationLabel: workspace.currentProject.displayRecentLocation,
          text: draft.text,
        ),
      ],
    );
  }

  List<String> _paginate(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return const ['当前章节正文为空。'];
    }
    if (normalized.length <= _pageCharThreshold) {
      return [normalized];
    }

    final pages = <String>[];
    var index = 0;
    while (index < normalized.length) {
      final end = index + _pageCharThreshold;
      if (end >= normalized.length) {
        pages.add(normalized.substring(index).trim());
        break;
      }
      var splitIndex = normalized.lastIndexOf(RegExp(r'[\s，。！？,.!?]'), end);
      if (splitIndex <= index + (_pageCharThreshold ~/ 2)) {
        splitIndex = end;
      } else {
        splitIndex += 1;
      }
      pages.add(normalized.substring(index, splitIndex).trim());
      index = splitIndex;
      while (index < normalized.length &&
          normalized.substring(index, index + 1).trim().isEmpty) {
        index += 1;
      }
    }
    return pages.where((page) => page.isNotEmpty).toList(growable: false);
  }

  void _goPreviousPage() {
    setState(() {
      if (_pageIndex > 0) {
        _pageIndex -= 1;
        _edgeFeedback = _defaultFooterHint();
        return;
      }
      if (_sceneIndex > 0) {
        _sceneIndex -= 1;
        _pageIndex = _documents[_sceneIndex].pages.length - 1;
        _edgeFeedback = _defaultFooterHint();
        return;
      }
      _edgeFeedback = '已到第一章起点 · 再向前翻页无效';
    });
  }

  void _goNextPage() {
    setState(() {
      final currentDocument = _documents[_sceneIndex];
      if (_pageIndex < currentDocument.pages.length - 1) {
        _pageIndex += 1;
        _edgeFeedback = _defaultFooterHint();
        return;
      }
      if (_sceneIndex < _documents.length - 1) {
        _sceneIndex += 1;
        _pageIndex = 0;
        _edgeFeedback = _defaultFooterHint();
        return;
      }
      _edgeFeedback = '已到章节终点 · 再向后翻页无效';
    });
  }

  String _pageIndicatorText() {
    final currentDocument = _documents[_sceneIndex];
    if (currentDocument.pages.length == 1) {
      return '单页';
    }
    return '第 ${_pageIndex + 1} / ${currentDocument.pages.length} 页';
  }

  String _defaultFooterHint() {
    final currentDocument = _documents[_sceneIndex];
    final isSinglePage = currentDocument.pages.length == 1;
    final isFirstPage = _pageIndex == 0;
    final isLastPage = _pageIndex == currentDocument.pages.length - 1;
    final hasPreviousScene = _sceneIndex > 0;
    final hasNextScene = _sceneIndex < _documents.length - 1;

    if (isSinglePage) {
      if (!hasPreviousScene && !hasNextScene) {
        return '当前章节无法分页 · 退出后回到进入前位置';
      }
      if (hasPreviousScene && !hasNextScene) {
        return '单页可切换到上一章';
      }
      if (!hasPreviousScene && hasNextScene) {
        return '单页可切换到下一章';
      }
      return '单页可切换到相邻章节';
    }
    if (isFirstPage && !hasPreviousScene) {
      return '已到第一章起点 · 再向前翻页无效';
    }
    if (isLastPage && !hasNextScene) {
      return '已到章节终点 · 再向后翻页无效';
    }
    if (isFirstPage && hasPreviousScene) {
      return '再向前一页进入上一章最后一页';
    }
    if (isLastPage && hasNextScene) {
      return '再翻一页进入下一章第一页';
    }
    return '末页后进入下一章 · 退出后回到进入前位置';
  }

  ReadingInlineNoticeData? _inlineNoticeData() {
    final currentDocument = _documents[_sceneIndex];
    final isSinglePage = currentDocument.pages.length == 1;
    final isFirstPage = _pageIndex == 0;
    final isLastPage = _pageIndex == currentDocument.pages.length - 1;
    final hasPreviousScene = _sceneIndex > 0;
    final hasNextScene = _sceneIndex < _documents.length - 1;

    if (isSinglePage) {
      return const ReadingInlineNoticeData(
        title: '单页阅读',
        message: '当前章节内容较短或无需拆分页，因此以整章单页方式展示。',
      );
    }
    if (isFirstPage && hasPreviousScene) {
      return const ReadingInlineNoticeData(
        title: '章节边界',
        message: '当前为本章第一页。继续向左翻页时，将进入上一章最后一页。',
      );
    }
    if (isLastPage && hasNextScene) {
      return const ReadingInlineNoticeData(
        title: '章节边界',
        message: '当前为本章最后一页。继续向右翻页时，将进入下一章第一页。',
      );
    }
    if (isFirstPage && !hasPreviousScene) {
      return const ReadingInlineNoticeData(
        title: '章节边界',
        message: '当前已是整部作品的第一章第一页，再向前翻页不会继续跳转。',
      );
    }
    if (isLastPage && !hasNextScene) {
      return const ReadingInlineNoticeData(
        title: '章节边界',
        message: '当前已是整部作品的最后一章最后一页，再向后翻页不会继续跳转。',
      );
    }
    return null;
  }

  bool _canGoPrevious() => _pageIndex > 0 || _sceneIndex > 0;

  bool _canGoNext() {
    final doc = _documents[_sceneIndex];
    return _pageIndex < doc.pages.length - 1 ||
        _sceneIndex < _documents.length - 1;
  }

  String _previousHotzoneLabel() {
    final currentDocument = _documents[_sceneIndex];
    final isSinglePage = currentDocument.pages.length == 1;
    final isFirstPage = _pageIndex == 0;
    final hasPreviousScene = _sceneIndex > 0;

    if (isSinglePage || isFirstPage) {
      return hasPreviousScene ? '上一章' : '';
    }
    return '上一页';
  }

  String _nextHotzoneLabel() {
    final currentDocument = _documents[_sceneIndex];
    final isSinglePage = currentDocument.pages.length == 1;
    final isLastPage = _pageIndex == currentDocument.pages.length - 1;
    final hasNextScene = _sceneIndex < _documents.length - 1;

    if (isSinglePage || isLastPage) {
      return hasNextScene ? '下一章' : '';
    }
    return '下一页';
  }
}
