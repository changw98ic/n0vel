import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/theme/app_theme.dart';
import 'package:novel_writer/app/widgets/desktop_shell.dart';

void main() {
  test('dark theme exposes warm-linen typography and tertiary token', () {
    final theme = AppTheme.dark();
    final palette = theme.extension<DesktopPalette>()!;

    expect(theme.textTheme.titleMedium?.fontFamily, 'Inter');
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Geist');
    expect(theme.textTheme.labelSmall?.color, const Color(0xFFA99C8E));
    expect(palette.tertiaryText, const Color(0xFFA99C8E));
    expect(
      theme.outlinedButtonTheme.style?.backgroundColor?.resolve({}),
      const Color(0xFF342D28),
    );
    expect(
      theme.outlinedButtonTheme.style?.side?.resolve({})?.color,
      const Color(0xFF564A41),
    );
  });

  testWidgets(
    'desktop menu drawer uses dark foundation fills for idle and selected items',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: DesktopMenuDrawer(
              items: [
                DesktopMenuItemData(
                  label: '书架',
                  onTap: () {},
                ),
                DesktopMenuItemData(
                  label: '编辑工作台',
                  isSelected: true,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );

      final buttons = tester.widgetList<TextButton>(find.byType(TextButton));
      final idleButton = buttons.firstWhere(
        (button) => (button.child as Text).data == '书架',
      );
      final selectedButton = buttons.firstWhere(
        (button) => (button.child as Text).data == '编辑工作台',
      );

      expect(
        idleButton.style?.backgroundColor?.resolve({}),
        const Color(0xFF342D28),
      );
      expect(
        selectedButton.style?.backgroundColor?.resolve({}),
        const Color(0xFF403730),
      );
      expect(
        selectedButton.style?.side?.resolve({})?.color,
        const Color(0xFF564A41),
      );
    },
  );
}
