import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_assistant/app/pages/main_shell_page.dart';
import 'package:writing_assistant/core/config/app_pages.dart';
import 'package:writing_assistant/core/config/app_routes.dart';

void main() {
  group('getPages contract', () {
    test('registers every declared route exactly once', () {
      const expectedRoutes = {
        AppRoutes.root,
        AppRoutes.search,
        AppRoutes.workDetail,
        AppRoutes.workSettings,
        AppRoutes.workCharacters,
        AppRoutes.workCharacterNew,
        AppRoutes.workCharacterDetail,
        AppRoutes.workRelationships,
        AppRoutes.workItems,
        AppRoutes.workLocations,
        AppRoutes.workFactions,
        AppRoutes.chapterEditor,
        AppRoutes.review,
        AppRoutes.aiDetection,
        AppRoutes.timeline,
        AppRoutes.pov,
        AppRoutes.stats,
        AppRoutes.read,
        AppRoutes.aiConfig,
        AppRoutes.aiUsageStats,
        AppRoutes.workEdit,
        AppRoutes.workNew,
      };

      final actualRoutes = getPages.map((page) => page.name).toList();

      expect(actualRoutes.toSet(), expectedRoutes);
      expect(actualRoutes.length, expectedRoutes.length);
    });

    test('root route resolves to MainShellPage', () {
      final rootPage = getPages.singleWhere(
        (page) => page.name == AppRoutes.root,
      );

      expect(rootPage.page(), isA<MainShellPage>());
    });

    test('routes without path params can create widgets eagerly', () {
      final staticRoutes = getPages.where((page) => !page.name.contains(':'));

      for (final route in staticRoutes) {
        expect(route.page(), isA<Widget>(), reason: route.name);
      }
    });

    test('parameterized routes keep required placeholders', () {
      expect(AppRoutes.workDetail, contains(':id'));
      expect(AppRoutes.workSettings, contains(':id'));
      expect(AppRoutes.workCharacters, contains(':id'));
      expect(AppRoutes.workCharacterNew, contains(':id'));
      expect(
        AppRoutes.workCharacterDetail,
        allOf(contains(':workId'), contains(':characterId')),
      );
      expect(AppRoutes.workRelationships, contains(':id'));
      expect(AppRoutes.workItems, contains(':id'));
      expect(AppRoutes.workLocations, contains(':id'));
      expect(AppRoutes.workFactions, contains(':id'));
      expect(
        AppRoutes.chapterEditor,
        allOf(contains(':workId'), contains(':chapterId')),
      );
      expect(AppRoutes.review, contains(':id'));
      expect(AppRoutes.timeline, contains(':id'));
      expect(AppRoutes.pov, contains(':id'));
      expect(AppRoutes.stats, contains(':id'));
      expect(AppRoutes.read, contains(':id'));
      expect(AppRoutes.aiUsageStats, contains(':id'));
      expect(AppRoutes.workEdit, contains(':id'));
    });
  });
}
