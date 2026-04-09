import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../app/theme.dart';

class EditorToolbar extends StatelessWidget {
  final VoidCallback? onBold;
  final VoidCallback? onItalic;
  final VoidCallback? onQuote;
  final VoidCallback? onFormat;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onFind;
  final VoidCallback? onReplace;

  const EditorToolbar({
    super.key,
    this.onBold,
    this.onItalic,
    this.onQuote,
    this.onFormat,
    this.onUndo,
    this.onRedo,
    this.onFind,
    this.onReplace,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
      child: Row(
        children: [
          _ToolIcon(icon: Icons.undo_rounded, tooltip: '撤销 (Ctrl+Z)', onPressed: onUndo),
          _ToolIcon(icon: Icons.redo_rounded, tooltip: '重做 (Ctrl+Y)', onPressed: onRedo),
          _ToolbarDivider(colorScheme: colorScheme),
          _ToolIcon(icon: Icons.format_bold_rounded, tooltip: '粗体', onPressed: onBold),
          _ToolIcon(icon: Icons.format_italic_rounded, tooltip: '斜体', onPressed: onItalic),
          _ToolIcon(icon: Icons.format_quote_rounded, tooltip: '对白引号', onPressed: onQuote),
          _ToolbarDivider(colorScheme: colorScheme),
          _ToolIcon(
            icon: Icons.auto_fix_high_rounded,
            tooltip: '润色排版',
            onPressed: onFormat,
            highlighted: true,
          ),
          _ToolIcon(icon: Icons.search_rounded, tooltip: '查找', onPressed: onFind),
          _ToolIcon(icon: Icons.find_replace_rounded, tooltip: '替换', onPressed: onReplace),
        ],
      ),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  final ColorScheme colorScheme;
  const _ToolbarDivider({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: SizedBox(
        width: 1,
        height: 20.h,
        child: ColoredBox(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
    );
  }
}

class _ToolIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool highlighted;

  const _ToolIcon({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 34.w,
        height: 34.h,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(
            icon,
            size: 18.sp,
            color: highlighted ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
          style: IconButton.styleFrom(
            backgroundColor: highlighted
                ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                : Colors.transparent,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            ),
          ),
        ),
      ),
    );
  }
}
