import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/domain/memo.dart';

void main() {
  group('ComputationMemo', () {
    test('computes and caches a value', () {
      final memo = ComputationMemo<String, int>();
      var callCount = 0;

      final result1 = memo.get('a', () {
        callCount++;
        return 42;
      });

      expect(result1, 42);
      expect(callCount, 1);

      final result2 = memo.get('a', () {
        callCount++;
        return 99;
      });

      expect(result2, 42);
      expect(callCount, 1);
    });

    test('stores values for different keys independently', () {
      final memo = ComputationMemo<String, int>();

      memo.get('a', () => 1);
      memo.get('b', () => 2);

      expect(memo.get('a', () => 10), 1);
      expect(memo.get('b', () => 20), 2);
    });

    test('invalidate removes a single entry', () {
      final memo = ComputationMemo<String, int>();

      memo.get('a', () => 1);
      memo.get('b', () => 2);
      memo.invalidate('a');

      expect(memo.containsKey('a'), isFalse);
      expect(memo.containsKey('b'), isTrue);
    });

    test('invalidateWhere removes matching entries', () {
      final memo = ComputationMemo<String, int>();

      memo.get('foo', () => 1);
      memo.get('bar', () => 2);
      memo.get('foobar', () => 3);
      memo.invalidateWhere((key) => key.startsWith('foo'));

      expect(memo.containsKey('foo'), isFalse);
      expect(memo.containsKey('foobar'), isFalse);
      expect(memo.containsKey('bar'), isTrue);
    });

    test('clear removes all entries', () {
      final memo = ComputationMemo<String, int>();

      memo.get('a', () => 1);
      memo.get('b', () => 2);
      memo.clear();

      expect(memo.length, 0);
      expect(memo.containsKey('a'), isFalse);
    });

    test('length reflects cached entry count', () {
      final memo = ComputationMemo<String, int>();

      expect(memo.length, 0);
      memo.get('a', () => 1);
      expect(memo.length, 1);
      memo.get('b', () => 2);
      expect(memo.length, 2);
    });
  });

  group('TypedMemo', () {
    test('computes and caches per-key values', () {
      var callCount = 0;
      final memo = TypedMemo<String, int>((key) {
        callCount++;
        return key.length;
      });

      expect(memo.get('hello'), 5);
      expect(callCount, 1);

      expect(memo.get('hello'), 5);
      expect(callCount, 1);

      expect(memo.get('hi'), 2);
      expect(callCount, 2);
    });

    test('invalidate refreshes a single key', () {
      final memo = TypedMemo<String, int>((key) => key.length);

      memo.get('hello');
      memo.invalidate('hello');

      expect(memo.containsKey('hello'), isFalse);
    });

    test('invalidateWhere removes matching keys', () {
      final memo = TypedMemo<String, int>((key) => key.length);

      memo.get('foo');
      memo.get('bar');
      memo.invalidateWhere((key) => key.startsWith('f'));

      expect(memo.containsKey('foo'), isFalse);
      expect(memo.containsKey('bar'), isTrue);
    });

    test('clear removes all cached entries', () {
      final memo = TypedMemo<String, int>((key) => key.length);

      memo.get('a');
      memo.get('b');
      memo.clear();

      expect(memo.length, 0);
    });

    test('containsKey and length work as expected', () {
      final memo = TypedMemo<String, int>((key) => key.length);

      expect(memo.containsKey('a'), isFalse);
      expect(memo.length, 0);

      memo.get('a');

      expect(memo.containsKey('a'), isTrue);
      expect(memo.length, 1);
    });
  });
}
