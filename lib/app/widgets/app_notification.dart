import 'dart:async';

import 'package:flutter/material.dart';

import '../events/app_domain_events.dart';
import '../events/app_event_bus_scope.dart';
import 'desktop_shell.dart';

const int _maxVisibleNotifications = 5;

class AppNotificationData {
  const AppNotificationData({
    required this.id,
    required this.title,
    this.message,
    this.severity = AppNoticeSeverity.info,
    this.duration = const Duration(seconds: 4),
  });

  final int id;
  final String title;
  final String? message;
  final AppNoticeSeverity severity;
  final Duration duration;
}

void showAppNotification(
  BuildContext context, {
  required String title,
  String? message,
  AppNoticeSeverity severity = AppNoticeSeverity.info,
  Duration duration = const Duration(seconds: 4),
}) {
  final bus = AppEventBusScope.of(context);
  bus.publish(NotificationRequestedEvent(
    title: title,
    message: message,
    severity: severity,
    duration: duration,
  ));
}

class AppNotificationOverlay extends StatefulWidget {
  const AppNotificationOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<AppNotificationOverlay> createState() => _AppNotificationOverlayState();
}

class _AppNotificationOverlayState extends State<AppNotificationOverlay> {
  final List<AppNotificationData> _notifications = [];
  final Map<int, Timer> _timers = {};
  StreamSubscription<NotificationRequestedEvent>? _subscription;
  int _nextId = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscription?.cancel();
    final bus = AppEventBusScope.of(context);
    _subscription = bus.on<NotificationRequestedEvent>().listen(_onNotification);
  }

  void _onNotification(NotificationRequestedEvent event) {
    final id = _nextId++;
    final data = AppNotificationData(
      id: id,
      title: event.title,
      message: event.message,
      severity: event.severity,
      duration: event.duration,
    );

    setState(() {
      _notifications.add(data);
      while (_notifications.length > _maxVisibleNotifications) {
        _dismissInternal(_notifications.first.id);
      }
    });

    _timers[id] = Timer(data.duration, () {
      _timers.remove(id);
      if (mounted) {
        setState(() {
          _dismissInternal(id);
        });
      }
    });
  }

  void _dismissInternal(int id) {
    _timers[id]?.cancel();
    _timers.remove(id);
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index >= 0) {
      _notifications.removeAt(index);
    }
  }

  void _dismiss(int id) {
    setState(() {
      _dismissInternal(id);
    });
  }

  @override
  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_notifications.isNotEmpty)
          Positioned(
            top: 24,
            right: 24,
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final notification in _notifications)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _NotificationCard(
                      key: ValueKey(notification.id),
                      data: notification,
                      onDismiss: () => _dismiss(notification.id),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _NotificationCard extends StatefulWidget {
  const _NotificationCard({
    super.key,
    required this.data,
    required this.onDismiss,
  });

  final AppNotificationData data;
  final VoidCallback onDismiss;

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  static const Color _warningColor = Color(0xFFB6813B);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    final accent = _resolveAccentColor(palette);

    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _opacity,
        child: Semantics(
          liveRegion: true,
          label:
              '${widget.data.title}${widget.data.message != null ? '：${widget.data.message}' : ''}',
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            color: palette.elevated,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent),
              ),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(_resolveIcon(), color: accent, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.data.title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (widget.data.message != null &&
                            widget.data.message!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(widget.data.message!,
                              style: theme.textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: '关闭通知',
                    child: IconButton(
                      onPressed: widget.onDismiss,
                      icon: Icon(
                        Icons.close,
                        size: 16,
                        color: palette.tertiaryText,
                      ),
                      constraints:
                          const BoxConstraints(minWidth: 28, minHeight: 28),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _resolveAccentColor(DesktopPalette palette) =>
      switch (widget.data.severity) {
        AppNoticeSeverity.error => palette.danger,
        AppNoticeSeverity.warning => _warningColor,
        AppNoticeSeverity.info => palette.info,
        AppNoticeSeverity.success => palette.success,
      };

  IconData _resolveIcon() => switch (widget.data.severity) {
        AppNoticeSeverity.error => Icons.error_outline,
        AppNoticeSeverity.warning => Icons.warning_amber_rounded,
        AppNoticeSeverity.info => Icons.info_outline,
        AppNoticeSeverity.success => Icons.check_circle_outline,
      };
}
