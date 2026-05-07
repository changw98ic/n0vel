import 'package:flutter/material.dart';

import 'desktop_theme.dart';

/// A lightweight split-handle primitive for resizable panel dividers.
///
/// Renders a 1 px quiet line by default, thickens to
/// [DesktopLayoutTokens.splitHandleWidth] on hover/drag with a warmer
/// appearance. Hit area is [DesktopLayoutTokens.splitHandleHitArea] for easy
/// grabbing.
///
/// When [onTap] is provided, the handle renders as a tappable button with
/// [InkWell] semantics instead of a drag handle. When [height] is provided,
/// the visual line is constrained instead of filling available space.
class AppSplitHandle extends StatefulWidget {
  const AppSplitHandle({
    super.key,
    this.onDragDelta,
    this.semanticLabel,
    this.onTap,
    this.height,
  });

  /// Called with the horizontal drag delta (px) on every drag update.
  final ValueChanged<double>? onDragDelta;

  /// Optional accessibility label announced by screen readers.
  final String? semanticLabel;

  /// When set, the handle acts as a tappable button using [InkWell].
  final VoidCallback? onTap;

  /// Constrains the visual line height; defaults to fill available space.
  final double? height;

  @override
  State<AppSplitHandle> createState() => _AppSplitHandleState();
}

class _AppSplitHandleState extends State<AppSplitHandle> {
  bool _hovered = false;
  bool _dragging = false;

  bool get _active => _hovered || _dragging;

  static const _quietLine = 1.0;
  static const _animDuration = Duration(milliseconds: 150);

  @override
  Widget build(BuildContext context) {
    final palette = desktopPalette(context);
    const hitSize = DesktopLayoutTokens.splitHandleHitArea;
    const activeSize = DesktopLayoutTokens.splitHandleWidth;

    final visualSize = _active ? activeSize : _quietLine;
    final alpha = _active ? 0.6 : 0.25;

    final line = AnimatedContainer(
      duration: _animDuration,
      curve: Curves.easeOut,
      width: visualSize,
      height: widget.height ?? double.infinity,
      decoration: BoxDecoration(
        color: palette.splitHandle.withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(visualSize / 2),
      ),
    );

    final sizedLine = SizedBox(
      width: hitSize,
      child: Center(child: line),
    );

    if (widget.onTap != null) {
      final tappableHandle = AnimatedContainer(
        duration: _animDuration,
        curve: Curves.easeOut,
        width: 20,
        height: widget.height ?? 64,
        decoration: BoxDecoration(
          color: _active ? palette.subtle : palette.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _active ? palette.borderStrong : palette.border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _active ? 0.08 : 0.04),
              blurRadius: _active ? 10 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.drag_indicator_rounded,
          size: 16,
          color: (_active ? palette.primary : palette.secondaryText).withValues(
            alpha: _active ? 0.95 : 0.72,
          ),
        ),
      );

      return Semantics(
        button: true,
        label: widget.semanticLabel,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onTap,
            hoverColor: palette.sidebar,
            splashColor: palette.border,
            onHover: (hovering) => setState(() => _hovered = hovering),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: ExcludeSemantics(child: tappableHandle),
            ),
          ),
        ),
      );
    }

    return Semantics(
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) {
          if (!_dragging) setState(() => _hovered = false);
        },
        child: GestureDetector(
          onHorizontalDragStart: (_) => _setDragging(true),
          onHorizontalDragUpdate: (details) {
            widget.onDragDelta?.call(details.delta.dx);
          },
          onHorizontalDragEnd: (_) => _setDragging(false),
          behavior: HitTestBehavior.translucent,
          child: sizedLine,
        ),
      ),
    );
  }

  void _setDragging(bool value) {
    setState(() {
      _dragging = value;
      _hovered = value;
    });
  }
}
