import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:window_manager/window_manager.dart';

import 'package:get/get.dart';
import '../theme.dart';
import '../../modules/dashboard/dashboard_logic.dart';
import '../../modules/dashboard/dashboard_view.dart';
import '../../modules/work/work_list/work_list_view.dart';
import '../../modules/ai_config/ai_config/ai_config_view.dart';
import '../../modules/inspiration/inspiration/inspiration_view.dart';
import '../../modules/ai_chat/ai_chat_view.dart';

class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _currentIndex = 0;

  static const _navItems = [
    _NavItem(Icons.dashboard_outlined, Icons.dashboard, '仪表盘'),
    _NavItem(Icons.auto_stories_outlined, Icons.auto_stories, '作品'),
    _NavItem(Icons.lightbulb_outlined, Icons.lightbulb, '素材'),
    _NavItem(Icons.chat_outlined, Icons.chat, 'AI 助手'),
    _NavItem(Icons.settings_outlined, Icons.settings, '设置'),
  ];

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      DashboardView(),
      WorkListView(),
      InspirationView(),
      AIChatView(),
      AIConfigView(),
    ];
  }

  void _onTabSelected(int index) {
    if (index != _currentIndex) {
      setState(() => _currentIndex = index);
      // 切换到仪表盘时刷新数据（反映删除/新增等变化）
      if (index == 0) {
        try {
          Get.find<DashboardLogic>().loadData();
        } catch (_) {}
      }
    }
  }

  Widget _buildPageContent() {
    return AnimatedSwitcher(
      duration: AppTokens.durationNormal,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: KeyedSubtree(
        key: ValueKey(_currentIndex),
        child: _pages[_currentIndex],
      ),
    );
  }

  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  @override
  Widget build(BuildContext context) {
    if (_isDesktop) return _buildDesktop(context);
    return _buildMobile(context);
  }

  // ---------------------------------------------------------------------------
  // Desktop layout
  // ---------------------------------------------------------------------------
  Widget _buildDesktop(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Gradient background
        _ShellBackground(colorScheme: colorScheme),

        // Foreground content
        Column(
          children: [
            // Custom Windows title bar
            SizedBox(
              height: 32,
              child: WindowCaption(
                brightness: theme.brightness,
                backgroundColor: Colors.transparent,
                title: const SizedBox.shrink(),
              ),
            ),

            // Main row: rail + content
            Expanded(
              child: Row(
                children: [
                  // ---- Navigation Rail ----
                  _buildNavigationRail(colorScheme),

                  // ---- Vertical divider ----
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                  ),

                  // ---- Content area ----
                  Expanded(child: _buildPageContent()),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNavigationRail(ColorScheme colorScheme) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: NavigationRail(
          minWidth: 76.w,
          minExtendedWidth: 76.w,
          selectedIndex: _currentIndex,
          onDestinationSelected: _onTabSelected,
          labelType: NavigationRailLabelType.all,
          backgroundColor: colorScheme.surfaceContainerLowest.withValues(alpha: 0.6),
          indicatorColor: colorScheme.secondaryContainer.withValues(alpha: 0.7),
          selectedIconTheme: IconThemeData(color: colorScheme.primary, size: 24.sp),
          unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant, size: 22.sp),
          selectedLabelTextStyle: TextStyle(
            color: colorScheme.primary,
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelTextStyle: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 11.sp,
          ),
          leading: Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              ),
              child: Icon(
                Icons.edit_note_rounded,
                color: colorScheme.primary,
                size: 22.sp,
              ),
            ),
          ),
          trailing: Expanded(child: const SizedBox.shrink()),
          destinations: _navItems
              .map(
                (item) => NavigationRailDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.activeIcon),
                  label: Text(item.label),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Mobile layout
  // ---------------------------------------------------------------------------
  Widget _buildMobile(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        _ShellBackground(colorScheme: colorScheme),
        Column(
          children: [
            Expanded(child: _buildPageContent()),
            ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: BottomNavigationBar(
                  backgroundColor:
                      colorScheme.surfaceContainerLowest.withValues(alpha: 0.7),
                  currentIndex: _currentIndex,
                  onTap: _onTabSelected,
                  type: BottomNavigationBarType.fixed,
                  selectedItemColor: colorScheme.secondary,
                  unselectedItemColor: colorScheme.onSurfaceVariant,
                  showUnselectedLabels: true,
                  items: _navItems
                      .map(
                        (item) => BottomNavigationBarItem(
                          icon: Icon(item.icon),
                          activeIcon: Icon(item.activeIcon),
                          label: item.label,
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Aurora background — animated gradient orbs with heavy blur
// ---------------------------------------------------------------------------
class _ShellBackground extends StatefulWidget {
  final ColorScheme colorScheme;

  const _ShellBackground({required this.colorScheme});

  @override
  State<_ShellBackground> createState() => _ShellBackgroundState();
}

class _ShellBackgroundState extends State<_ShellBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.colorScheme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;

        return Stack(
          fit: StackFit.expand,
          children: [
            // Base gradient
            DecoratedBox(
              decoration: BoxDecoration(
                color: widget.colorScheme.surface,
              ),
            ),

            // Orb 1 — soft blue, top-left drift
            _AuroraOrb(
              color: isDark
                  ? const Color(0x4C0A84FF) // 0.3 alpha
                  : const Color(0x66A2D2FF), // 0.4 alpha
              blur: 100,
              size: 0.55,
              x: -0.15 + 0.20 * _sin(t * 0.7),
              y: -0.10 + 0.15 * _cos(t * 0.5),
            ),

            // Orb 2 — soft violet, bottom-right drift
            _AuroraOrb(
              color: isDark
                  ? const Color(0x3DBF5AF2) // 0.24 alpha
                  : const Color(0x4DC8B4FF), // 0.3 alpha
              blur: 120,
              size: 0.50,
              x: 0.15 + 0.18 * _cos(t * 0.6),
              y: 0.20 + 0.12 * _sin(t * 0.8),
            ),

            // Orb 3 — soft teal, center drift
            _AuroraOrb(
              color: isDark
                  ? const Color(0x3364D2FF) // 0.2 alpha
                  : const Color(0x40B4E4FF), // 0.25 alpha
              blur: 90,
              size: 0.40,
              x: 0.0 + 0.12 * _sin(t * 0.9),
              y: 0.0 + 0.10 * _cos(t * 0.4),
            ),
          ],
        );
      },
    );
  }

  static double _sin(double v) => (v * 2 * 3.14159265).abs() > 0.001
      ? _fastSin(v * 2 * 3.14159265)
      : 0.0;

  static double _cos(double v) => _fastCos(v * 2 * 3.14159265);
}

class _AuroraOrb extends StatelessWidget {
  final Color color;
  final double blur;
  final double size; // fraction of screen
  final double x; // offset fraction
  final double y;

  const _AuroraOrb({
    required this.color,
    required this.blur,
    required this.size,
    required this.x,
    required this.y,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final h = mq.size.height;
    final orbSize = (w > h ? w : h) * size;

    return Positioned(
      left: w * (0.5 + x) - orbSize / 2,
      top: h * (0.5 + y) - orbSize / 2,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            width: orbSize,
            height: orbSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color,
                  color.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Fast sin/cos approximations (Bhaskara I)
double _fastSin(double x) {
  x = x % (2 * 3.14159265);
  if (x < 0) x += 2 * 3.14159265;
  if (x > 3.14159265) return -_fastSinImpl(2 * 3.14159265 - x);
  return _fastSinImpl(x);
}

double _fastSinImpl(double x) {
  // Bhaskara I approximation
  final pi = 3.14159265;
  return 16 * x * (pi - x) / (5 * pi * pi - 4 * x * (pi - x));
}

double _fastCos(double x) => _fastSin(x + 3.14159265 / 2);

// ---------------------------------------------------------------------------
// Nav item descriptor
// ---------------------------------------------------------------------------
class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem(this.icon, this.activeIcon, this.label);
}
