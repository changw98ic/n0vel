import 'package:flutter/material.dart';

import 'desktop_shell.dart';

/// Unified loading state variants for the app.
enum AppLoadingVariant {
  /// A small inline spinner for use inside buttons or compact spaces.
  inline,

  /// A centered spinner suitable for panel-sized areas.
  panel,

  /// A full-page overlay with semi-transparent backdrop.
  overlay,
}

/// A styled circular progress indicator that adapts to the app's [DesktopPalette].
class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({
    super.key,
    this.variant = AppLoadingVariant.panel,
    this.size,
    this.strokeWidth = 2.5,
  });

  final AppLoadingVariant variant;
  final double? size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final palette = desktopPalette(context);
    final dimension = size ?? _defaultSize;

    return SizedBox(
      width: dimension,
      height: dimension,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: palette.primary,
        backgroundColor: palette.subtle,
      ),
    );
  }

  double get _defaultSize {
    switch (variant) {
      case AppLoadingVariant.inline:
        return 16;
      case AppLoadingVariant.panel:
        return 28;
      case AppLoadingVariant.overlay:
        return 36;
    }
  }
}

/// A loading overlay that dims its child and shows a centered spinner with an
/// optional message.
///
/// When [isLoading] is false, only [child] is rendered.
class AppLoadingOverlay extends StatelessWidget {
  const AppLoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
    this.overlayColor,
    this.borderRadius,
  });

  final bool isLoading;
  final Widget child;
  final String? message;
  final Color? overlayColor;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final palette = desktopPalette(context);

    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: overlayColor ?? palette.canvas.withValues(alpha: 0.55),
                borderRadius: borderRadius,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppLoadingIndicator(variant: AppLoadingVariant.overlay),
                    if (message != null && message!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        message!,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: palette.secondaryText),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A button that supports a loading state.
///
/// When [isLoading] is true, the button is disabled and shows an inline spinner
/// instead of the [child].
class AppLoadingButton extends StatelessWidget {
  const AppLoadingButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.isLoading = false,
    this.style,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool isLoading;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: style,
      child: isLoading
          ? const SizedBox(
              height: 18,
              width: 18,
              child: AppLoadingIndicator(
                variant: AppLoadingVariant.inline,
                strokeWidth: 2.2,
              ),
            )
          : child,
    );
  }
}

/// A skeleton placeholder shaped like a single text line.
///
/// Use [widthFactor] to control relative width (e.g. 0.6 for a short line).
class AppSkeletonLine extends StatelessWidget {
  const AppSkeletonLine({
    super.key,
    this.height = 14,
    this.widthFactor = 1.0,
    this.borderRadius,
  });

  final double height;
  final double widthFactor;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final palette = desktopPalette(context);
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: palette.subtle,
          borderRadius: borderRadius ?? BorderRadius.circular(height / 2),
        ),
      ),
    );
  }
}

/// A skeleton placeholder shaped like a card or panel.
class AppSkeletonCard extends StatelessWidget {
  const AppSkeletonCard({
    super.key,
    this.height,
    this.padding = const EdgeInsets.all(16),
    this.lineCount = 4,
    this.lineSpacing = 10,
  });

  final double? height;
  final EdgeInsets padding;
  final int lineCount;
  final double lineSpacing;

  @override
  Widget build(BuildContext context) {
    final palette = desktopPalette(context);
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppSkeletonLine(height: 16, widthFactor: 0.35),
          SizedBox(height: lineSpacing + 4),
          for (var i = 0; i < lineCount; i++) ...[
            AppSkeletonLine(
              height: 12,
              widthFactor: i == lineCount - 1 ? 0.6 : 1.0,
            ),
            if (i < lineCount - 1) SizedBox(height: lineSpacing),
          ],
        ],
      ),
    );
    if (height != null) {
      return SizedBox(
        height: height,
        child: content,
      );
    }
    return content;
  }
}

/// A convenience widget that shows a skeleton while [isLoading] is true,
/// otherwise renders [child].
class AppSkeletonLoader extends StatelessWidget {
  const AppSkeletonLoader({
    super.key,
    required this.isLoading,
    required this.child,
    this.skeleton,
  });

  final bool isLoading;
  final Widget child;
  final Widget? skeleton;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: isLoading ? (skeleton ?? const AppSkeletonCard()) : child,
    );
  }
}
