import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/navigation/reading_route_data.dart';
import '../../../app/state/app_draft_store.dart';
import '../../../app/state/app_workspace_store.dart';

class ReadingModePage extends StatefulWidget {
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
  State<ReadingModePage> createState() => _ReadingModePageState();
}

class _ReadingModePageState extends State<ReadingModePage> {
  static const int _pageCharThreshold = 220;
  static const Color _canvasColor = Color(0xFFF6F0E6);
  static const Color _paperColor = Color(0xFFFFFDFC);
  static const Color _paperBorderColor = Color(0xFFD8CDC0);
  static const Color _footerColor = Color(0xFFEEE6DA);
  static const Color _noticeColor = Color(0xFFF6F0E6);
  static const Color _noticeBorderColor = Color(0xFFB7AA9A);
  static const Color _accentColor = Color(0xFF51624D);
  static const Color _mutedTextColor = Color(0xFF91887D);
  static const Color _bodyTextColor = Color(0xFF514943);
  static const Color _titleColor = Color(0xFF2E2925);

  final FocusNode _pageFocusNode = FocusNode();
  ReadingSessionData? _activeSession;
  List<_ReadingDocumentPages> _documents = const [];
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
    final session = widget.session ?? _fallbackSession(context);
    _synchronizeSession(session);

    final currentDocument = _documents[_sceneIndex];
    final currentPage = currentDocument.pages[_pageIndex];
    final footerHint = _edgeFeedback ?? _defaultFooterHint();
    final inlineNotice = _inlineNoticeData();
    final previousLabel = _previousHotzoneLabel();
    final nextLabel = _nextHotzoneLabel();

    return Scaffold(
      backgroundColor: _canvasColor,
      body: SafeArea(
        child: Focus(
          autofocus: true,
          focusNode: _pageFocusNode,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) {
              return KeyEventResult.ignored;
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
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    OutlinedButton(
                      key: ReadingModePage.closeButtonKey,
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFFFBF7F1),
                        foregroundColor: _titleColor,
                        side: const BorderSide(color: _paperBorderColor),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('关闭纯净模式'),
                    ),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Center(
                          child: Text(
                          '${session.projectTitle} · ${currentDocument.locationLabel}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: _titleColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                      ),
                    const SizedBox(width: 120),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Row(
                    children: [
                      _ReadingHotzone(
                        zoneKey: ReadingModePage.previousHotzoneKey,
                        label: previousLabel,
                        enabled: previousLabel != '—',
                        onTap: _goPreviousPage,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Semantics(
                          label: '阅读内容',
                          child: Container(
                            key: ReadingModePage.pageBodyKey,
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 36,
                            vertical: 44,
                          ),
                          decoration: BoxDecoration(
                            color: _paperColor,
                            border: Border.all(color: _paperBorderColor),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentPage,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: _bodyTextColor,
                                    height: 1.72,
                                  ),
                                ),
                                if (inlineNotice != null) ...[
                                  const SizedBox(height: 18),
                                  _ReadingInlineNoticeCard(data: inlineNotice),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                        ),
                      const SizedBox(width: 12),
                      _ReadingHotzone(
                        zoneKey: ReadingModePage.nextHotzoneKey,
                        label: nextLabel,
                        enabled: nextLabel != '—',
                        onTap: _goNextPage,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _footerColor,
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
                          color: const Color(0xFF6E665E),
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
                              color: _mutedTextColor,
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
        _ReadingDocumentPages(
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
    final draft = AppDraftScope.of(context).snapshot;
    final workspace = AppWorkspaceScope.of(context);
    return ReadingSessionData(
      projectTitle: workspace.currentProject.title,
      initialSceneId: workspace.currentProject.sceneId,
      documents: [
        ReadingSceneDocument(
          sceneId: workspace.currentProject.sceneId,
          locationLabel: workspace.currentProject.recentLocation,
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
      var end = index + _pageCharThreshold;
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

  _ReadingInlineNoticeData? _inlineNoticeData() {
    final currentDocument = _documents[_sceneIndex];
    final isSinglePage = currentDocument.pages.length == 1;
    final isFirstPage = _pageIndex == 0;
    final isLastPage = _pageIndex == currentDocument.pages.length - 1;
    final hasPreviousScene = _sceneIndex > 0;
    final hasNextScene = _sceneIndex < _documents.length - 1;

    if (isSinglePage) {
      return const _ReadingInlineNoticeData(
        title: '单页阅读',
        message: '当前章节内容较短或无需拆分页，因此以整章单页方式展示。',
      );
    }
    if (isFirstPage && hasPreviousScene) {
      return const _ReadingInlineNoticeData(
        title: '章节边界',
        message: '当前为本章第一页。继续向左翻页时，将进入上一章最后一页。',
      );
    }
    if (isLastPage && hasNextScene) {
      return const _ReadingInlineNoticeData(
        title: '章节边界',
        message: '当前为本章最后一页。继续向右翻页时，将进入下一章第一页。',
      );
    }
    if (isFirstPage && !hasPreviousScene) {
      return const _ReadingInlineNoticeData(
        title: '章节边界',
        message: '当前已是整部作品的第一章第一页，再向前翻页不会继续跳转。',
      );
    }
    if (isLastPage && !hasNextScene) {
      return const _ReadingInlineNoticeData(
        title: '章节边界',
        message: '当前已是整部作品的最后一章最后一页，再向后翻页不会继续跳转。',
      );
    }
    return null;
  }

  String _previousHotzoneLabel() {
    final currentDocument = _documents[_sceneIndex];
    final isSinglePage = currentDocument.pages.length == 1;
    final isFirstPage = _pageIndex == 0;
    final hasPreviousScene = _sceneIndex > 0;

    if (isSinglePage || isFirstPage) {
      return hasPreviousScene ? '上一章' : '—';
    }
    return '上一页';
  }

  String _nextHotzoneLabel() {
    final currentDocument = _documents[_sceneIndex];
    final isSinglePage = currentDocument.pages.length == 1;
    final isLastPage = _pageIndex == currentDocument.pages.length - 1;
    final hasNextScene = _sceneIndex < _documents.length - 1;

    if (isSinglePage || isLastPage) {
      return hasNextScene ? '下一章' : '—';
    }
    return '下一页';
  }
}

class _ReadingHotzone extends StatelessWidget {
  const _ReadingHotzone({
    required this.zoneKey,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final Key zoneKey;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 52,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        child: GestureDetector(
          key: zoneKey,
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          child: Container(
            decoration: BoxDecoration(
              color: _ReadingModePageState._canvasColor,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: ExcludeSemantics(
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _ReadingModePageState._mutedTextColor.withValues(
                    alpha: enabled ? 1 : 0.78,
                  ),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadingInlineNoticeCard extends StatelessWidget {
  const _ReadingInlineNoticeCard({required this.data});

  final _ReadingInlineNoticeData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _ReadingModePageState._noticeColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _ReadingModePageState._noticeBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: _ReadingModePageState._accentColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            data.message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: _ReadingModePageState._titleColor,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadingDocumentPages {
  const _ReadingDocumentPages({
    required this.sceneId,
    required this.locationLabel,
    required this.pages,
  });

  final String sceneId;
  final String locationLabel;
  final List<String> pages;
}

class _ReadingInlineNoticeData {
  const _ReadingInlineNoticeData({required this.title, required this.message});

  final String title;
  final String message;
}
