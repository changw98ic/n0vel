import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/app_storage_clone.dart';

void main() {
  group('cloneStorageValue', () {
    test('returns null unchanged', () {
      expect(cloneStorageValue(null), isNull);
    });

    test('returns primitive string unchanged', () {
      expect(cloneStorageValue('hello'), 'hello');
    });

    test('returns primitive int unchanged', () {
      expect(cloneStorageValue(42), 42);
    });

    test('returns primitive double unchanged', () {
      expect(cloneStorageValue(3.14), 3.14);
    });

    test('returns primitive bool unchanged', () {
      expect(cloneStorageValue(true), isTrue);
      expect(cloneStorageValue(false), isFalse);
    });

    test('clones a flat list with deep independence', () {
      final original = <Object?>[1, 'two', true, null];
      final cloned = cloneStorageValue(original) as List<Object?>;

      expect(cloned, equals(original));
      cloned[0] = 999;
      expect(original[0], 1);
    });

    test('clones a flat map with deep independence', () {
      final original = <Object?, Object?>{'a': 1, 'b': 'two'};
      final cloned = cloneStorageValue(original) as Map<String, Object?>;

      expect(cloned, equals({'a': 1, 'b': 'two'}));
      cloned['a'] = 999;
      expect((original as Map)['a'], 1);
    });

    test('coerces map keys to strings', () {
      final original = <Object?, Object?>{42: 'int-key', true: 'bool-key'};
      final cloned = cloneStorageValue(original) as Map<String, Object?>;

      expect(cloned['42'], 'int-key');
      expect(cloned['true'], 'bool-key');
      expect(cloned.length, 2);
    });

    test('deep clones nested map mutations are isolated', () {
      final original = <Object?, Object?>{
        'nested': <Object?, Object?>{'inner': 'value'},
      };
      final cloned = cloneStorageValue(original) as Map<String, Object?>;

      final clonedNested = cloned['nested'] as Map<String, Object?>;
      clonedNested['inner'] = 'mutated';

      final originalNested = (original as Map)['nested'] as Map;
      expect(originalNested['inner'], 'value');
    });

    test('deep clones nested list mutations are isolated', () {
      final original = <Object?>[
        <Object?>[1, 2, 3],
      ];
      final cloned = cloneStorageValue(original) as List<Object?>;

      final innerCloned = cloned[0] as List<Object?>;
      innerCloned[0] = 999;

      final innerOriginal = original[0] as List;
      expect(innerOriginal[0], 1);
    });

    test('deep clones map inside list inside map', () {
      final original = <Object?, Object?>{
        'items': <Object?>[
          <Object?, Object?>{'id': 'a', 'value': 10},
          <Object?, Object?>{'id': 'b', 'value': 20},
        ],
      };
      final cloned = cloneStorageValue(original) as Map<String, Object?>;

      final clonedItems = cloned['items'] as List<Object?>;
      final firstItem = clonedItems[0] as Map<String, Object?>;
      firstItem['value'] = 999;

      final originalItems = (original as Map)['items'] as List;
      final originalFirst = originalItems[0] as Map;
      expect(originalFirst['value'], 10);
    });

    test('returns empty list for empty list input', () {
      final original = <Object?>[];
      final cloned = cloneStorageValue(original) as List<Object?>;

      expect(cloned, isEmpty);
      expect(identical(original, cloned), isFalse);
    });

    test('returns empty map for empty map input', () {
      final original = <Object?, Object?>{};
      final cloned = cloneStorageValue(original) as Map<String, Object?>;

      expect(cloned, isEmpty);
      expect(identical(original, cloned), isFalse);
    });
  });

  group('cloneStorageMap', () {
    test('clones flat map with structural equality', () {
      const original = <String, Object?>{
        'name': '月潮回声',
        'version': 2,
        'active': true,
      };
      final cloned = cloneStorageMap(original);

      expect(cloned, equals(original));
      expect(identical(original, cloned), isFalse);
    });

    test('cloned map mutations do not affect original', () {
      const original = <String, Object?>{
        'key': 'original-value',
      };
      final cloned = cloneStorageMap(original);
      cloned['key'] = 'mutated';

      expect(original['key'], 'original-value');
      expect(cloned['key'], 'mutated');
    });

    test('nested map mutations in clone do not affect original', () {
      const original = <String, Object?>{
        'settings': <String, Object?>{
          'theme': 'dark',
          'fontSize': 14,
        },
      };
      final cloned = cloneStorageMap(original);

      final clonedSettings = cloned['settings'] as Map<String, Object?>;
      clonedSettings['theme'] = 'light';

      final originalSettings =
          original['settings'] as Map<String, Object?>;
      expect(originalSettings['theme'], 'dark');
    });

    test('nested list mutations in clone do not affect original', () {
      const original = <String, Object?>{
        'tags': <Object?>['悬疑', '推理', '都市'],
      };
      final cloned = cloneStorageMap(original);

      final clonedTags = cloned['tags'] as List<Object?>;
      clonedTags[0] = '言情';

      final originalTags = original['tags'] as List<Object?>;
      expect(originalTags[0], '悬疑');
    });

    test('adding keys to cloned map does not affect original', () {
      const original = <String, Object?>{'a': 1};
      final cloned = cloneStorageMap(original);
      cloned['b'] = 2;

      expect(original.containsKey('b'), isFalse);
      expect(cloned['b'], 2);
    });

    test('removing keys from cloned map does not affect original', () {
      const original = <String, Object?>{'a': 1, 'b': 2};
      final cloned = cloneStorageMap(original);
      cloned.remove('a');

      expect(original.containsKey('a'), isTrue);
      expect(original['a'], 1);
      expect(cloned.containsKey('a'), isFalse);
    });

    test('handles deeply nested structure with full isolation', () {
      const original = <String, Object?>{
        'project': <String, Object?>{
          'chapters': <Object?>[
            <String, Object?>{
              'id': 'ch-01',
              'scenes': <Object?>[
                <String, Object?>{
                  'id': 's-01',
                  'cast': <Object?>[
                    <String, Object?>{
                      'characterId': 'char-01',
                      'name': '柳溪',
                    },
                  ],
                },
              ],
            },
          ],
        },
      };
      final cloned = cloneStorageMap(original);

      final clonedChapter = ((cloned['project'] as Map<String, Object?>)['chapters'] as List<Object?>)[0] as Map<String, Object?>;
      final clonedScene = (clonedChapter['scenes'] as List<Object?>)[0] as Map<String, Object?>;
      final clonedCast = (clonedScene['cast'] as List<Object?>)[0] as Map<String, Object?>;
      clonedCast['name'] = '陈默';

      final originalChapter =
          ((original['project'] as Map)['chapters'] as List)[0] as Map;
      final originalScene = (originalChapter['scenes'] as List)[0] as Map;
      final originalCast = (originalScene['cast'] as List)[0] as Map;
      expect(originalCast['name'], '柳溪');
    });

    test('returns empty map for empty input', () {
      const original = <String, Object?>{};
      final cloned = cloneStorageMap(original);

      expect(cloned, isEmpty);
      expect(identical(original, cloned), isFalse);
    });

    test('preserves null values in map', () {
      const original = <String, Object?>{
        'present': 'value',
        'absent': null,
      };
      final cloned = cloneStorageMap(original);

      expect(cloned, equals(original));
      expect(cloned['absent'], isNull);
      expect(cloned.containsKey('absent'), isTrue);
    });
  });
}
