import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/theme/app_theme.dart';
import 'package:novel_writer/app/widgets/app_loading_state.dart';
import 'package:novel_writer/app/widgets/desktop_shell.dart';

void main() {
  group('AppLoadingIndicator', () {
    testWidgets('renders a CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: AppLoadingIndicator(),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('uses primary color from DesktopPalette', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: AppLoadingIndicator(),
          ),
        ),
      );

      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.color, appPrimaryColor);
    });

    testWidgets('inline variant is smaller than overlay variant', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Column(
            children: [
              AppLoadingIndicator(variant: AppLoadingVariant.inline),
              AppLoadingIndicator(variant: AppLoadingVariant.overlay),
            ],
          ),
        ),
      );

      final boxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      final inline = boxes.firstWhere((b) => b.width == 16);
      final overlay = boxes.firstWhere((b) => b.width == 36);
      expect(inline, isNotNull);
      expect(overlay, isNotNull);
    });
  });

  group('AppLoadingOverlay', () {
    testWidgets('shows child only when isLoading is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: AppLoadingOverlay(
              isLoading: false,
              child: Text('content'),
            ),
          ),
        ),
      );

      expect(find.text('content'), findsOneWidget);
      expect(find.byType(AppLoadingIndicator), findsNothing);
    });

    testWidgets('shows spinner and optional message when isLoading is true',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: SizedBox.expand(
              child: AppLoadingOverlay(
                isLoading: true,
                message: 'Loading…',
                child: Text('content'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('content'), findsOneWidget);
      expect(find.byType(AppLoadingIndicator), findsOneWidget);
      expect(find.text('Loading…'), findsOneWidget);
    });

    testWidgets('uses canvas overlay color by default', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: AppLoadingOverlay(
              isLoading: true,
              child: SizedBox.expand(),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(Positioned),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, appCanvasColor.withValues(alpha: 0.55));
    });
  });

  group('AppLoadingButton', () {
    testWidgets('renders child text when not loading', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: AppLoadingButton(
              onPressed: () {},
              child: const Text('Save'),
            ),
          ),
        ),
      );

      expect(find.text('Save'), findsOneWidget);
      expect(find.byType(AppLoadingIndicator), findsNothing);
    });

    testWidgets('renders spinner and disables button when loading',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: AppLoadingButton(
              onPressed: null,
              isLoading: true,
              child: Text('Save'),
            ),
          ),
        ),
      );

      expect(find.text('Save'), findsNothing);
      expect(find.byType(AppLoadingIndicator), findsOneWidget);

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('calls onPressed when tapped and not loading', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: AppLoadingButton(
              onPressed: () => tapped = true,
              child: const Text('Save'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });

  group('AppSkeletonLine', () {
    testWidgets('renders a rounded container', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: AppSkeletonLine(),
          ),
        ),
      );

      expect(find.byType(Container), findsOneWidget);
      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.borderRadius, isNotNull);
    });

    testWidgets('uses subtle palette color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: AppSkeletonLine(),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, appSubtleColor);
    });
  });

  group('AppSkeletonCard', () {
    testWidgets('renders header line and multiple body lines', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: AppSkeletonCard(lineCount: 3),
          ),
        ),
      );

      expect(find.byType(AppSkeletonLine), findsNWidgets(4));
    });

    testWidgets('last line is shorter than full width', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const SizedBox(
            width: 400,
            child: Scaffold(
              body: AppSkeletonCard(lineCount: 2),
            ),
          ),
        ),
      );

      final lines = tester.widgetList<AppSkeletonLine>(find.byType(AppSkeletonLine));
      final last = lines.last;
      expect(last.widthFactor, lessThan(1.0));
    });
  });

  group('AppSkeletonLoader', () {
    testWidgets('shows skeleton when isLoading is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: AppSkeletonLoader(
              isLoading: true,
              child: Text('loaded'),
            ),
          ),
        ),
      );

      expect(find.byType(AppSkeletonCard), findsOneWidget);
      expect(find.text('loaded'), findsNothing);
    });

    testWidgets('shows child when isLoading is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: AppSkeletonLoader(
              isLoading: false,
              child: Text('loaded'),
            ),
          ),
        ),
      );

      expect(find.text('loaded'), findsOneWidget);
      expect(find.byType(AppSkeletonCard), findsNothing);
    });

    testWidgets('uses custom skeleton when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: AppSkeletonLoader(
              isLoading: true,
              skeleton: Text('custom skeleton'),
              child: Text('loaded'),
            ),
          ),
        ),
      );

      expect(find.text('custom skeleton'), findsOneWidget);
      expect(find.byType(AppSkeletonCard), findsNothing);
    });
  });
}
