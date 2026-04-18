import 'package:flutter/foundation.dart';

import '../../features/editor/domain/chapter.dart' as chapter_domain;
import '../../features/settings/domain/character.dart' as character_domain;
import '../../features/settings/domain/faction.dart' as faction_domain;
import '../../features/settings/domain/item.dart' as item_domain;
import '../../features/settings/domain/location.dart' as location_domain;
import '../../features/editor/data/chapter_repository.dart';
import '../../features/settings/data/character_repository.dart';
import '../../features/settings/data/faction_repository.dart';
import '../../features/settings/data/item_repository.dart';
import '../../features/settings/data/location_repository.dart';
import '../../features/work/data/work_repository.dart';
import '../../features/work/domain/work.dart' as work_domain;

enum SearchResultType { work, chapter, character, item, location, faction }

class SearchResultItem {
  final SearchResultType type;
  final String id;
  final String title;
  final String? subtitle;
  final String? workId;
  final String? workTitle;

  const SearchResultItem({
    required this.type,
    required this.id,
    required this.title,
    this.subtitle,
    this.workId,
    this.workTitle,
  });

  SearchResultItem copyWith({
    SearchResultType? type,
    String? id,
    String? title,
    String? subtitle,
    String? workId,
    String? workTitle,
  }) {
    return SearchResultItem(
      type: type ?? this.type,
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      workId: workId ?? this.workId,
      workTitle: workTitle ?? this.workTitle,
    );
  }
}

class SearchService {
  final Future<List<work_domain.Work>> Function() _allWorksSource;
  final Future<List<work_domain.Work>> Function(String query)
  _searchWorksSource;
  final Future<List<chapter_domain.Chapter>> Function(
    String workId,
    String query,
  )
  _searchChaptersSource;
  final Future<List<character_domain.Character>> Function(
    String workId,
    String query,
  )
  _searchCharactersSource;
  final Future<List<item_domain.Item>> Function(String workId, String query)
  _searchItemsSource;
  final Future<List<location_domain.Location>> Function(
    String workId,
    String query,
  )
  _searchLocationsSource;
  final Future<List<faction_domain.Faction>> Function(
    String workId,
    String query,
  )
  _searchFactionsSource;

  SearchService({
    required WorkRepository workRepository,
    required ChapterRepository chapterRepository,
    required CharacterRepository characterRepository,
    required ItemRepository itemRepository,
    required LocationRepository locationRepository,
    required FactionRepository factionRepository,
  }) : this._(
         allWorksSource: () =>
             workRepository.getAllWorks(includeArchived: true),
         searchWorksSource: workRepository.searchWorks,
         searchChaptersSource: chapterRepository.searchChapters,
         searchCharactersSource: characterRepository.searchCharacters,
         searchItemsSource: itemRepository.searchItems,
         searchLocationsSource: locationRepository.searchLocations,
         searchFactionsSource: factionRepository.searchFactions,
       );

  @visibleForTesting
  SearchService.test({
    required Future<List<work_domain.Work>> Function() allWorksSource,
    required Future<List<work_domain.Work>> Function(String query)
    searchWorksSource,
    required Future<List<chapter_domain.Chapter>> Function(
      String workId,
      String query,
    )
    searchChaptersSource,
    required Future<List<character_domain.Character>> Function(
      String workId,
      String query,
    )
    searchCharactersSource,
    required Future<List<item_domain.Item>> Function(
      String workId,
      String query,
    )
    searchItemsSource,
    required Future<List<location_domain.Location>> Function(
      String workId,
      String query,
    )
    searchLocationsSource,
    required Future<List<faction_domain.Faction>> Function(
      String workId,
      String query,
    )
    searchFactionsSource,
  }) : this._(
         allWorksSource: allWorksSource,
         searchWorksSource: searchWorksSource,
         searchChaptersSource: searchChaptersSource,
         searchCharactersSource: searchCharactersSource,
         searchItemsSource: searchItemsSource,
         searchLocationsSource: searchLocationsSource,
         searchFactionsSource: searchFactionsSource,
       );

  SearchService._({
    required Future<List<work_domain.Work>> Function() allWorksSource,
    required Future<List<work_domain.Work>> Function(String query)
    searchWorksSource,
    required Future<List<chapter_domain.Chapter>> Function(
      String workId,
      String query,
    )
    searchChaptersSource,
    required Future<List<character_domain.Character>> Function(
      String workId,
      String query,
    )
    searchCharactersSource,
    required Future<List<item_domain.Item>> Function(
      String workId,
      String query,
    )
    searchItemsSource,
    required Future<List<location_domain.Location>> Function(
      String workId,
      String query,
    )
    searchLocationsSource,
    required Future<List<faction_domain.Faction>> Function(
      String workId,
      String query,
    )
    searchFactionsSource,
  }) : _allWorksSource = allWorksSource,
       _searchWorksSource = searchWorksSource,
       _searchChaptersSource = searchChaptersSource,
       _searchCharactersSource = searchCharactersSource,
       _searchItemsSource = searchItemsSource,
       _searchLocationsSource = searchLocationsSource,
       _searchFactionsSource = searchFactionsSource;

  Future<List<SearchResultItem>> searchWorks(String query) async {
    return _mapResults(
      await _searchWorksSource(query),
      type: SearchResultType.work,
      idOf: (work) => work.id,
      titleOf: (work) => work.name,
      subtitleOf: (work) => work.description,
      workIdOf: (work) => work.id,
    );
  }

  Future<List<SearchResultItem>> searchChapters(
    String workId,
    String query,
  ) async {
    return _mapResults(
      await _searchChaptersSource(workId, query),
      type: SearchResultType.chapter,
      idOf: (chapter) => chapter.id,
      titleOf: (chapter) => chapter.title,
      subtitleOf: (chapter) => _trimPreview(chapter.content),
      workIdOf: (chapter) => chapter.workId,
    );
  }

  Future<List<SearchResultItem>> searchCharacters(
    String workId,
    String query,
  ) async {
    return _mapResults(
      await _searchCharactersSource(workId, query),
      type: SearchResultType.character,
      idOf: (character) => character.id,
      titleOf: (character) => character.name,
      subtitleOf: (character) => character.identity ?? character.bio,
      workIdOf: (character) => character.workId,
    );
  }

  Future<List<SearchResultItem>> searchItems(
    String workId,
    String query,
  ) async {
    return _mapResults(
      await _searchItemsSource(workId, query),
      type: SearchResultType.item,
      idOf: (item) => item.id,
      titleOf: (item) => item.name,
      subtitleOf: (item) => item.description,
      workIdOf: (item) => item.workId,
    );
  }

  Future<List<SearchResultItem>> searchLocations(
    String workId,
    String query,
  ) async {
    return _mapResults(
      await _searchLocationsSource(workId, query),
      type: SearchResultType.location,
      idOf: (location) => location.id,
      titleOf: (location) => location.name,
      subtitleOf: (location) => location.description,
      workIdOf: (location) => location.workId,
    );
  }

  Future<List<SearchResultItem>> searchFactions(
    String workId,
    String query,
  ) async {
    return _mapResults(
      await _searchFactionsSource(workId, query),
      type: SearchResultType.faction,
      idOf: (faction) => faction.id,
      titleOf: (faction) => faction.name,
      subtitleOf: (faction) => faction.description,
      workIdOf: (faction) => faction.workId,
    );
  }

  Future<List<SearchResultItem>> searchAll({
    required String query,
    String? workId,
  }) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return const [];
    }

    final groups = workId != null
        ? await Future.wait([
            searchChapters(workId, normalized),
            searchCharacters(workId, normalized),
            searchItems(workId, normalized),
            searchLocations(workId, normalized),
            searchFactions(workId, normalized),
          ])
        : await _searchAllWorksScope(normalized);
    return groups.expand((group) => group).toList();
  }

  Future<List<List<SearchResultItem>>> _searchAllWorksScope(
    String query,
  ) async {
    final works = await _allWorksSource();
    final workResults = await searchWorks(query);
    final scopedGroups = await Future.wait(
      works.map((work) async {
        final groups = await Future.wait([
          searchChapters(work.id, query),
          searchCharacters(work.id, query),
          searchItems(work.id, query),
          searchLocations(work.id, query),
          searchFactions(work.id, query),
        ]);
        return groups
            .expand((items) => items)
            .map((item) => item.copyWith(workTitle: work.name))
            .toList();
      }),
    );

    return [workResults, ...scopedGroups];
  }

  List<SearchResultItem> _mapResults<T>(
    List<T> items, {
    required SearchResultType type,
    required String Function(T item) idOf,
    required String Function(T item) titleOf,
    required String? Function(T item) subtitleOf,
    String? Function(T item)? workIdOf,
  }) {
    return items
        .map(
          (item) => SearchResultItem(
            type: type,
            id: idOf(item),
            title: titleOf(item),
            subtitle: subtitleOf(item),
            workId: workIdOf?.call(item),
          ),
        )
        .toList();
  }

  String? _trimPreview(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return value.length > 80 ? value.substring(0, 80) : value;
  }
}
