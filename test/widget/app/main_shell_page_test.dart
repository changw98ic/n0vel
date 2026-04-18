import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:writing_assistant/app/pages/main_shell_page.dart';
import 'package:writing_assistant/features/work/data/work_repository.dart';
import 'package:writing_assistant/modules/dashboard/dashboard_logic.dart';
import 'package:writing_assistant/modules/dashboard/dashboard_view.dart';
import 'package:writing_assistant/modules/work/work_list/work_list_logic.dart';
import 'package:writing_assistant/modules/work/work_list/work_list_view.dart';

import '../helpers/pump_get_app.dart';

class _MockWorkRepository extends Mock implements WorkRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MainShellPage', () {
    late _MockWorkRepository workRepository;

    setUp(() {
      Get.testMode = true;
      workRepository = _MockWorkRepository();

      when(
        () => workRepository.getAllWorks(),
      ).thenAnswer((_) async => const []);
      when(
        () => workRepository.getAllWorks(includeArchived: true),
      ).thenAnswer((_) async => const []);

      Get.put<WorkRepository>(workRepository);
      Get.put<DashboardLogic>(DashboardLogic());
      Get.put<WorkListLogic>(WorkListLogic());
    });

    tearDown(() {
      Get.reset();
    });

    testWidgets('renders desktop shell with dashboard selected by default', (
      tester,
    ) async {
      await pumpGetApp(tester, home: const MainShellPage());

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(DashboardView), findsOneWidget);
      expect(find.byType(WorkListView), findsNothing);

      verify(() => workRepository.getAllWorks()).called(1);
    });

    testWidgets('switches between dashboard and works tabs', (tester) async {
      await pumpGetApp(tester, home: const MainShellPage());

      final navRail = find.byType(NavigationRail);

      await tester.tap(
        find
            .descendant(
              of: navRail,
              matching: find.byIcon(Icons.auto_stories_outlined),
            )
            .first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(WorkListView), findsOneWidget);
      verify(() => workRepository.getAllWorks(includeArchived: true)).called(1);

      await tester.tap(
        find
            .descendant(
              of: navRail,
              matching: find.byIcon(Icons.dashboard_outlined),
            )
            .first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(DashboardView), findsOneWidget);
      verify(() => workRepository.getAllWorks()).called(2);
    });
  });
}
