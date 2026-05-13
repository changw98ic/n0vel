import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/main.dart';
import 'test_support/test_registry.dart';

void main() {
  const desktopSize = Size(1440, 1024);

  setUp(() {
    NovelWriterApp.debugRegistryOverride = createTestRegistry();
  });

  tearDown(() {
    NovelWriterApp.debugRegistryOverride = null;
  });

  Future<void> setDesktopSize(WidgetTester tester) async {
    tester.view.physicalSize = desktopSize;
    tester.view.devicePixelRatio = 1.0;
  }

  group('UI entrypoint contract', () {
    testWidgets('entrypoint renders ProjectListPage, not probe', (
      tester,
    ) async {
      await setDesktopSize(tester);
      await tester.pumpWidget(const NovelWriterApp());
      await tester.pump();

      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(ProjectListPage), findsOneWidget);
      expect(find.text('Missing OLLAMA_API_KEY'), findsNothing);
      expect(find.text('starting real one-chapter probe'), findsNothing);
    });
  });
}
