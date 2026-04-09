import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:writing_assistant/l10n/app_localizations.dart';
import 'package:writing_assistant/shared/widgets/filter_bar/filter_bar.dart';

void main() {
  testWidgets('filter bar keeps controller text in sync with widget state', (
    tester,
  ) async {
    var query = '初始关键词';

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(1920, 1080),
        minTextAdapt: true,
        builder: (context, child) => MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: FilterBar<String>(
                searchQuery: query,
                onSearchChanged: (value) {
                  setState(() => query = value);
                },
                onFilterChanged: (_) {},
                onSortChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('初始关键词'), findsOneWidget);

    query = '同步后的关键词';
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(1920, 1080),
        minTextAdapt: true,
        builder: (context, child) => MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: FilterBar<String>(
                searchQuery: query,
                onSearchChanged: (value) {
                  setState(() => query = value);
                },
                onFilterChanged: (_) {},
                onSortChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('同步后的关键词'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
