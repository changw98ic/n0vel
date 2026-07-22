import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/state/storage_fingerprint.dart';

void main() {
  group('storageFingerprint', () {
    test('identical maps produce the same fingerprint', () {
      final a = <String, Object?>{
        'id': 'project-1',
        'title': 'test',
        'count': 42,
      };
      final b = <String, Object?>{
        'id': 'project-1',
        'title': 'test',
        'count': 42,
      };

      expect(storageFingerprint(a), equals(storageFingerprint(b)));
    });

    test('different maps produce different fingerprints', () {
      final a = <String, Object?>{'id': 'project-1', 'title': 'alpha'};
      final b = <String, Object?>{'id': 'project-1', 'title': 'beta'};

      expect(storageFingerprint(a), isNot(equals(storageFingerprint(b))));
    });

    test('key order does not affect fingerprint', () {
      final a = <String, Object?>{'b': 2, 'a': 1};
      final b = <String, Object?>{'a': 1, 'b': 2};

      expect(storageFingerprint(a), equals(storageFingerprint(b)));
    });

    test('nested maps are canonicalized', () {
      final a = <String, Object?>{
        'outer': {'z': 3, 'a': 1},
      };
      final b = <String, Object?>{
        'outer': {'a': 1, 'z': 3},
      };

      expect(storageFingerprint(a), equals(storageFingerprint(b)));
    });

    test('lists preserve order', () {
      final a = <String, Object?>{
        'items': [1, 2, 3],
      };
      final b = <String, Object?>{
        'items': [3, 2, 1],
      };

      expect(storageFingerprint(a), isNot(equals(storageFingerprint(b))));
    });

    test('empty map produces a stable fingerprint', () {
      final a = <String, Object?>{};
      final b = <String, Object?>{};

      expect(storageFingerprint(a), equals(storageFingerprint(b)));
    });

    test('null values are handled', () {
      final a = <String, Object?>{'key': null};
      final b = <String, Object?>{'key': null};

      expect(storageFingerprint(a), equals(storageFingerprint(b)));
    });

    test('large data (>100KB) produces consistent fingerprint', () {
      final items = List<Map<String, Object?>>.generate(
        10000,
        (i) => {'id': i, 'name': 'item-$i', 'data': 'x' * 50},
      );
      final a = <String, Object?>{'items': items};
      final b = <String, Object?>{'items': items};

      expect(storageFingerprint(a), equals(storageFingerprint(b)));
    });

    test('deeply nested structures (10+ levels) are stable', () {
      Object? buildNested(int depth) {
        if (depth == 0) return 'leaf';
        return <String, Object?>{
          'level': depth,
          'child': buildNested(depth - 1),
        };
      }

      final a = <String, Object?>{'root': buildNested(12)};
      final b = <String, Object?>{'root': buildNested(12)};

      expect(storageFingerprint(a), equals(storageFingerprint(b)));
    });

    test('single field change produces different fingerprint', () {
      final base = <String, Object?>{
        'id': 'p1',
        'title': 'hello',
        'count': 100,
      };
      final modified = <String, Object?>{
        'id': 'p1',
        'title': 'hello',
        'count': 101,
      };

      expect(
        storageFingerprint(base),
        isNot(equals(storageFingerprint(modified))),
      );
    });

    test('unicode and emoji values do not crash', () {
      final data = <String, Object?>{
        'emoji': '🎉🚀💻',
        'cjk': '中文测试日本語',
        'special': r'$\n\r\t\0',
        'empty': '',
      };

      expect(() => storageFingerprint(data), returnsNormally);
    });

    test('empty collection vs absent key are different', () {
      final withEmpty = <String, Object?>{'key': <Object?>[]};
      final without = <String, Object?>{};

      expect(
        storageFingerprint(withEmpty),
        isNot(equals(storageFingerprint(without))),
      );
    });
  });
}
