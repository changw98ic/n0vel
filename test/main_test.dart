import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:novel_writer/app/app.dart';
import 'package:novel_writer/app/logging/app_event_log.dart';

void main() {
  testWidgets('NovelWriterApp provides AppEventLogScope', (tester) async {
    await tester.pumpWidget(const NovelWriterApp());
    expect(find.byType(NovelWriterApp), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('AppEventLogScope is accessible from context', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: _TestLogScopeWidget(),
      ),
    );
    expect(find.text('log-found'), findsOneWidget);
  });
}

class _TestLogScopeWidget extends StatelessWidget {
  const _TestLogScopeWidget();

  @override
  Widget build(BuildContext context) {
    final log = AppEventLogScope.of(context);
    return Text(log.sessionId.isNotEmpty ? 'log-found' : 'log-missing');
  }
}
