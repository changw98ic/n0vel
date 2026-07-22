import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../app/state/app_workspace_store.dart';
import '../../../app/theme/app_design_tokens.dart';
import '../../../app/widgets/desktop_shell.dart';

class ProjectShelfCard extends StatefulWidget {
  const ProjectShelfCard({
    super.key,
    required this.project,
    required this.onTap,
    required this.onSecondaryTap,
  });

  final ProjectRecord project;
  final VoidCallback onTap;
  final ValueChanged<Offset> onSecondaryTap;

  @override
  State<ProjectShelfCard> createState() => _ProjectShelfCardState();
}

class _ProjectShelfCardState extends State<ProjectShelfCard> {
  static const _coverColors = [
    Color(0xFF2D3436),
    Color(0xFF6C5CE7),
    Color(0xFF00B894),
    Color(0xFFE17055),
    Color(0xFF0984E3),
    Color(0xFFB83B5E),
    Color(0xFF636E72),
    Color(0xFF1B9CFC),
  ];

  bool _hovered = false;
  bool _pressed = false;

  Color _coverColor() {
    final hash = widget.project.title.hashCode.abs();
    return _coverColors[hash % _coverColors.length];
  }

  @override
  Widget build(BuildContext context) {
    final base = _coverColor();
    final topColor = Color.lerp(base, Colors.white, 0.3)!;
    final bottomColor = Color.lerp(base, Colors.black, 0.4)!;

    final shadowAlpha = _pressed
        ? 0.10
        : _hovered
        ? 0.18
        : 0.13;
    final shadowBlur = _pressed
        ? 6.0
        : _hovered
        ? 36.0
        : 36.0;
    final shadowOffset = _pressed
        ? const Offset(1, 2)
        : _hovered
        ? const Offset(0, 16)
        : const Offset(0, 16);
    final translateY = _pressed
        ? 0.0
        : _hovered
        ? -6.0
        : 0.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: Listener(
        onPointerDown: (event) {
          if (event.buttons == kSecondaryButton) {
            widget.onSecondaryTap(event.position);
          } else {
            setState(() => _pressed = true);
          }
        },
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(0, translateY, 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusLarge),
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0x221F2A1D,
                  ).withValues(alpha: shadowAlpha / 0.13),
                  blurRadius: shadowBlur,
                  offset: shadowOffset,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusLarge),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [topColor, base, bottomColor],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      widget.project.title,
                      style: const TextStyle(
                        fontFamily: AppDesignTokens.fontHeading,
                        fontSize: AppDesignTokens.fontSizeHeadline,
                        color: Colors.white,
                        fontWeight: AppDesignTokens.weightBold,
                        height: AppDesignTokens.lineHeightTight,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.project.genre.isNotEmpty
                          ? '长篇 / ${widget.project.genre}'
                          : '长篇',
                      style: const TextStyle(
                        fontFamily: AppDesignTokens.fontCaption,
                        fontSize: AppDesignTokens.fontSizeCaption,
                        color: Color(0xFFF5F1E8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.project.tag,
                      style: const TextStyle(
                        fontFamily: AppDesignTokens.fontCaption,
                        fontSize: AppDesignTokens.fontSizeCaption,
                        color: Color(0xFFE5DED2),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          AppDesignTokens.radiusFull,
                        ),
                        border: Border.all(color: const Color(0x66FFFFFF)),
                      ),
                      child: Text(
                        widget.project.lastOpenedAtMs > 0 ? '继续写' : '打开',
                        style: const TextStyle(
                          fontFamily: AppDesignTokens.fontCaption,
                          fontSize: AppDesignTokens.fontSizeSmall,
                          fontWeight: AppDesignTokens.weightMedium,
                          color: Color(0xFF243226),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ProjectInlineNoticeCard extends StatelessWidget {
  const ProjectInlineNoticeCard({
    super.key,
    required this.title,
    required this.message,
    required this.accent,
  });

  final String title;
  final String message;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(message, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class ProjectDialogField extends StatelessWidget {
  const ProjectDialogField({
    super.key,
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: appPanelDecoration(
        context,
        color: desktopPalette(context).elevated,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
