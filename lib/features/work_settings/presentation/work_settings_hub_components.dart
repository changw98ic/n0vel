import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../app/widgets/desktop_shell.dart';


class WorkSettingsStatChip extends StatelessWidget {
  const WorkSettingsStatChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Text('$label：', style: theme.textTheme.bodySmall),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class WorkSettingsNavItem extends StatelessWidget {
  const WorkSettingsNavItem({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: palette.border, width: 1),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: palette.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: palette.tertiaryText),
            ],
          ),
        ),
      ),
    );
  }
}

class HoverableCardWrapper extends StatefulWidget {
  const HoverableCardWrapper({
    required this.child,
    this.onTap,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<HoverableCardWrapper> createState() => _HoverableCardWrapperState();
}

class _HoverableCardWrapperState extends State<HoverableCardWrapper> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transformAlignment: Alignment.center,
          transform: Matrix4.translationValues(0.0, _isHovered ? -3.0 : 0.0, 0.0)
            ..multiply(Matrix4.diagonal3Values(_isHovered ? 1.025 : 1.0, _isHovered ? 1.025 : 1.0, 1.0)),
          child: widget.child,
        ),
      ),
    );
  }
}

class FrostedCharacterCard extends StatelessWidget {
  const FrostedCharacterCard({
    required this.name,
    required this.role,
    required this.avatarInitial,
    this.onTap,
    super.key,
  });

  final String name;
  final String role;
  final String avatarInitial;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);

    return HoverableCardWrapper(
      onTap: onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(12),
        decoration: glassCardDecoration(context, color: palette.glassCard),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              child: Text(
                avatarInitial,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: palette.primary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              role.isEmpty ? '设定角色' : role,
              style: theme.textTheme.labelSmall?.copyWith(
                color: palette.secondaryText,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class FrostedChapterCard extends StatelessWidget {
  const FrostedChapterCard({
    required this.title,
    required this.location,
    required this.summary,
    required this.onTap,
    super.key,
  });

  final String title;
  final String location;
  final String summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);

    return HoverableCardWrapper(
      onTap: onTap,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(14),
        decoration: glassCardDecoration(context, color: palette.glassCard),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.book_outlined,
                  size: 16,
                  color: Color(0xFFB6813B),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    location,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF77736A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: palette.primary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                summary.isEmpty ? '暂无章节目标与冲突梗概。' : summary,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.tertiaryText,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.bottomRight,
              child: TextButton(
                onPressed: onTap,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(40, 20),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('进入写作', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PremiumHorizontalScrollView extends StatefulWidget {
  const PremiumHorizontalScrollView({
    required this.builder,
    this.controller,
    this.gradientColor,
    super.key,
  });

  final Widget Function(BuildContext context, ScrollController controller) builder;
  final ScrollController? controller;
  final Color? gradientColor;

  @override
  State<PremiumHorizontalScrollView> createState() => _PremiumHorizontalScrollViewState();
}

class _PremiumHorizontalScrollViewState extends State<PremiumHorizontalScrollView> {
  ScrollController? _internalController;
  ScrollController get _scrollController => widget.controller ?? _internalController!;

  bool _showLeftArrow = false;
  bool _showRightArrow = false;
  double _scrollProgress = 0.0;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _internalController = ScrollController();
    }
    _scrollController.addListener(_scrollListener);
  }

  @override
  void didUpdateWidget(PremiumHorizontalScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_scrollListener);
      _internalController?.removeListener(_scrollListener);

      if (widget.controller == null) {
        _internalController ??= ScrollController();
      } else {
        _internalController?.dispose();
        _internalController = null;
      }

      _scrollController.addListener(_scrollListener);
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollMetrics());
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _internalController?.dispose();
    super.dispose();
  }

  void _scrollListener() {
    _updateScrollMetrics();
  }

  void _updateScrollMetrics() {
    if (!mounted) return;
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final offset = _scrollController.offset;
      final showLeft = offset > 5.0;
      final showRight = maxScroll > 0.0 && (maxScroll - offset) > 5.0;
      
      double progress = 0.0;
      if (maxScroll > 0.0) {
        progress = (offset / maxScroll).clamp(0.0, 1.0);
      }
      
      if (showLeft != _showLeftArrow || showRight != _showRightArrow || progress != _scrollProgress) {
        setState(() {
          _showLeftArrow = showLeft;
          _showRightArrow = showRight;
          _scrollProgress = progress;
        });
      }
    }
  }

  void _scrollLeft() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final viewport = _scrollController.position.viewportDimension;
      final scrollAmount = viewport > 0.0 ? viewport * 0.75 : 200.0;
      final target = (_scrollController.offset - scrollAmount).clamp(0.0, maxScroll);
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _scrollRight() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final viewport = _scrollController.position.viewportDimension;
      final scrollAmount = viewport > 0.0 ? viewport * 0.75 : 200.0;
      final target = (_scrollController.offset + scrollAmount).clamp(0.0, maxScroll);
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = desktopPalette(context);
    final baseGradientColor = widget.gradientColor ?? palette.glassCard;

    // Trigger initial check after build frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollMetrics());

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            final dy = event.scrollDelta.dy;
            final dx = event.scrollDelta.dx;
            if (dy != 0.0 && dx == 0.0) {
              if (_scrollController.hasClients) {
                final targetOffset = (_scrollController.offset + dy).clamp(
                  0.0,
                  _scrollController.position.maxScrollExtent,
                );
                _scrollController.jumpTo(targetOffset);
              }
            }
          }
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            _updateScrollMetrics();
            return false;
          },
          child: Stack(
            children: [
              // 1. Scroll Content with config
              ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                  },
                ),
                child: widget.builder(context, _scrollController),
              ),

              // 2. Left gradient overlay
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 40,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _showLeftArrow ? 1.0 : 0.0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            baseGradientColor.withValues(alpha: 0.9),
                            baseGradientColor.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 3. Right gradient overlay
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 40,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _showRightArrow ? 1.0 : 0.0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                          colors: [
                            baseGradientColor.withValues(alpha: 0.9),
                            baseGradientColor.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 4. Left Arrow button
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: (_isHovered && _showLeftArrow) ? 1.0 : 0.0,
                    child: IgnorePointer(
                      ignoring: !_isHovered || !_showLeftArrow,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _scrollLeft,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.chevron_left,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 5. Right Arrow button
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: (_isHovered && _showRightArrow) ? 1.0 : 0.0,
                    child: IgnorePointer(
                      ignoring: !_isHovered || !_showRightArrow,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _scrollRight,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.chevron_right,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 6. Progress bar at bottom
              Positioned(
                left: 12,
                right: 12,
                bottom: 4,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: (_isHovered && _scrollController.hasClients && _scrollController.position.maxScrollExtent > 0.0) ? 1.0 : 0.0,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: palette.border.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (!_scrollController.hasClients) {
                          return const SizedBox.shrink();
                        }
                        final trackWidth = constraints.maxWidth;
                        final maxScroll = _scrollController.position.maxScrollExtent;
                        final offset = _scrollController.offset;
                        final viewport = _scrollController.position.viewportDimension;
                        
                        final totalContent = maxScroll + viewport;
                        final thumbRatio = totalContent > 0 ? (viewport / totalContent) : 0.2;
                        final thumbWidth = (trackWidth * thumbRatio).clamp(24.0, trackWidth);
                        
                        final scrollableWidth = trackWidth - thumbWidth;
                        final progress = maxScroll > 0 ? (offset / maxScroll).clamp(0.0, 1.0) : 0.0;
                        final thumbLeft = progress * scrollableWidth;
                        
                        return Stack(
                          children: [
                            Positioned(
                              left: thumbLeft,
                              top: 0,
                              bottom: 0,
                              width: thumbWidth,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFB6813B),
                                  borderRadius: BorderRadius.circular(1.5),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

