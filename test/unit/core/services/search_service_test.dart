import 'package:flutter_test/flutter_test.dart';
import 'package:writing_assistant/core/services/search_service.dart';
import 'package:writing_assistant/features/editor/domain/chapter.dart';
import 'package:writing_assistant/features/settings/domain/character.dart';
import 'package:writing_assistant/features/settings/domain/faction.dart';
import 'package:writing_assistant/features/settings/domain/item.dart';
import 'package:writing_assistant/features/settings/domain/location.dart';
import 'package:writing_assistant/features/work/domain/work.dart';

void main() {
  group('SearchService', () {
    test(
      'searchAll aggregates work and scoped result groups in order',
      () async {
        final service = SearchService.test(
          allWorksSource: () async => [_work(id: 'work-1', name: '作品')],
          searchWorksSource: (_) async => [_work(id: 'work-1', name: '作品')],
          searchChaptersSource: (_, __) async => [
            _chapter(id: 'chapter-1', title: '第一章'),
          ],
          searchCharactersSource: (_, __) async => [
            _character(id: 'character-1', name: '主角'),
          ],
          searchItemsSource: (_, __) async => [_item(id: 'item-1', name: '法宝')],
          searchLocationsSource: (_, __) async => [
            _location(id: 'location-1', name: '山门'),
          ],
          searchFactionsSource: (_, __) async => [
            _faction(id: 'faction-1', name: '宗门'),
          ],
        );

        final results = await service.searchAll(query: '关键词', workId: 'work-1');

        expect(results.map((item) => item.type), [
          SearchResultType.work,
          SearchResultType.chapter,
          SearchResultType.character,
          SearchResultType.item,
          SearchResultType.location,
          SearchResultType.faction,
        ]);
        expect(results.map((item) => item.id), [
          'work-1',
          'chapter-1',
          'character-1',
          'item-1',
          'location-1',
          'faction-1',
        ]);
      },
    );

    test('searchChapters trims long preview content to 80 chars', () async {
      final longContent = List.filled(100, 'a').join();
      final service = SearchService.test(
        allWorksSource: () async => [_work(id: 'work-1', name: '作品')],
        searchWorksSource: (_) async => const [],
        searchChaptersSource: (_, __) async => [
          _chapter(id: 'chapter-1', title: '长章节', content: longContent),
        ],
        searchCharactersSource: (_, __) async => const [],
        searchItemsSource: (_, __) async => const [],
        searchLocationsSource: (_, __) async => const [],
        searchFactionsSource: (_, __) async => const [],
      );

      final results = await service.searchChapters('work-1', 'a');

      expect(results.single.subtitle, longContent.substring(0, 80));
    });

    test(
      'searchAll searches scoped entities across all works when workId is null',
      () async {
        final service = SearchService.test(
          allWorksSource: () async => [
            _work(id: 'work-1', name: '作品一'),
            _work(id: 'work-2', name: '作品二'),
          ],
          searchWorksSource: (_) async => [_work(id: 'work-1', name: '作品一')],
          searchChaptersSource: (workId, __) async => [
            _chapter(
              id: 'chapter-$workId',
              title: '章节-$workId',
              workId: workId,
            ),
          ],
          searchCharactersSource: (_, __) async => const [],
          searchItemsSource: (_, __) async => const [],
          searchLocationsSource: (_, __) async => const [],
          searchFactionsSource: (_, __) async => const [],
        );

        final results = await service.searchAll(query: '章节');
        final chapterResults = results
            .where((item) => item.type == SearchResultType.chapter)
            .toList();

        expect(chapterResults, hasLength(2));
        expect(chapterResults.map((item) => item.workTitle), ['作品一', '作品二']);
        expect(chapterResults.map((item) => item.workId), ['work-1', 'work-2']);
      },
    );
  });
}

Work _work({required String id, required String name}) {
  final now = DateTime(2026, 4, 6);
  return Work(id: id, name: name, createdAt: now, updatedAt: now);
}

Chapter _chapter({
  required String id,
  required String title,
  String? content,
  String workId = 'work-1',
}) {
  final now = DateTime(2026, 4, 6);
  return Chapter(
    id: id,
    volumeId: 'volume-1',
    workId: workId,
    title: title,
    content: content,
    createdAt: now,
    updatedAt: now,
  );
}

Character _character({required String id, required String name}) {
  final now = DateTime(2026, 4, 6);
  return Character(
    id: id,
    workId: 'work-1',
    name: name,
    tier: CharacterTier.protagonist,
    createdAt: now,
    updatedAt: now,
  );
}

Item _item({required String id, required String name}) {
  final now = DateTime(2026, 4, 6);
  return Item(
    id: id,
    workId: 'work-1',
    name: name,
    createdAt: now,
    updatedAt: now,
  );
}

Location _location({required String id, required String name}) {
  final now = DateTime(2026, 4, 6);
  return Location(
    id: id,
    workId: 'work-1',
    name: name,
    createdAt: now,
    updatedAt: now,
  );
}

Faction _faction({required String id, required String name}) {
  final now = DateTime(2026, 4, 6);
  return Faction(
    id: id,
    workId: 'work-1',
    name: name,
    createdAt: now,
    updatedAt: now,
  );
}
