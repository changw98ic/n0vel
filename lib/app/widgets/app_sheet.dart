import 'package:flutter/material.dart';

import 'desktop_theme.dart';

/// A right-side sheet overlay with warm macOS-like styling.
///
/// Use [showAppSheet] to present it as a modal. The sheet slides in from
/// the right edge with a semi-transparent barrier behind it.
class AppSheet extends StatelessWidget {
  const AppSheet({
    super.key,
    required this.title,
    required this.child,
    this.width = 420,
    this.onClose,
  });

  final String title;
  final Widget child;
  final double width;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    final safeWidth = width.clamp(0.0, MediaQuery.sizeOf(context).width * 0.9);

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: safeWidth,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            palette.subtle.withValues(alpha: 0.18),
            palette.surface,
          ),
          border: Border(left: BorderSide(color: palette.border)),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            bottomLeft: Radius.circular(14),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 24,
              offset: const Offset(-8, 0),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 20,
                      color: palette.tertiaryText,
                    ),
                    onPressed: onClose ?? () => Navigator.of(context).pop(),
                    tooltip: '关闭',
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: palette.border),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Displays a modal [AppSheet] that slides in from the right.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required String title,
  required Widget child,
  double width = 420,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: '关闭侧栏',
    barrierColor: Colors.black26,
    transitionDuration: const Duration(milliseconds: 250),
    transitionBuilder: (context, animation, secondaryAnimation, page) {
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: page,
      );
    },
    pageBuilder: (context, animation, secondaryAnimation) {
      return Material(
        type: MaterialType.transparency,
        child: AppSheet(
          title: title,
          width: width,
          onClose: () => Navigator.of(context).pop(),
          child: child,
        ),
      );
    },
  );
}
