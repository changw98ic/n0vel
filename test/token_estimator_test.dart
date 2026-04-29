import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/token_estimator.dart';

void main() {
  const estimator = TokenEstimator();

  // -----------------------------------------------------------------------
  // estimate — single string
  // -----------------------------------------------------------------------

  group('estimate', () {
    test('empty string yields 0', () {
      expect(estimator.estimate(''), 0);
    });

    test('1 char yields 1', () {
      expect(estimator.estimate('A'), 1);
    });

    test('4 chars yields 1', () {
      expect(estimator.estimate('abcd'), 1);
    });

    test('5 chars yields 2 (ceil)', () {
      expect(estimator.estimate('abcde'), 2);
    });

    test('100 chars yields 25', () {
      expect(estimator.estimate('A' * 100), 25);
    });

    test('400 chars yields 100', () {
      expect(estimator.estimate('A' * 400), 100);
    });

    test('401 chars yields 101', () {
      expect(estimator.estimate('A' * 401), 101);
    });

    test('CJK characters counted by length', () {
      final text = '你好世界测试';
      expect(estimator.estimate(text), (text.length / 4).ceil());
    });

    test('whitespace-only still counts', () {
      expect(estimator.estimate('    '), 1);
    });

    test('mixed ASCII and CJK', () {
      final text = 'Hello你好';
      expect(estimator.estimate(text), (text.length / 4).ceil());
    });
  });

  // -----------------------------------------------------------------------
  // estimateList — list of strings
  // -----------------------------------------------------------------------

  group('estimateList', () {
    test('empty list yields 0', () {
      expect(estimator.estimateList([]), 0);
    });

    test('single element', () {
      expect(estimator.estimateList(['abcd']), 1);
    });

    test('multiple elements are summed', () {
      // 'abcd' = 1, 'efghi' = 2, 'j' = 1 → total 4
      expect(estimator.estimateList(['abcd', 'efghi', 'j']), 4);
    });

    test('list with empty strings', () {
      expect(estimator.estimateList(['', 'abcd', '']), 1);
    });
  });

  // -----------------------------------------------------------------------
  // estimateJoined — joined text with separator
  // -----------------------------------------------------------------------

  group('estimateJoined', () {
    test('empty list yields 0', () {
      expect(estimator.estimateJoined([]), 0);
    });

    test('single element bypasses separator', () {
      expect(estimator.estimateJoined(['abcd']), 1);
    });

    test('two elements include separator', () {
      // 'abcd' + '\n' + 'efgh' = 9 chars → ceil(9/4) = 3
      expect(estimator.estimateJoined(['abcd', 'efgh']), 3);
    });

    test('custom separator', () {
      // 'ab' + ' | ' + 'cd' + ' | ' + 'ef' = 12 chars → ceil(12/4) = 3
      expect(
        estimator.estimateJoined(['ab', 'cd', 'ef'], separator: ' | '),
        3,
      );
    });
  });

  // -----------------------------------------------------------------------
  // fitsBudget
  // -----------------------------------------------------------------------

  group('fitsBudget', () {
    test('text within budget', () {
      expect(estimator.fitsBudget('abcd', 1), true);
    });

    test('text at budget boundary', () {
      expect(estimator.fitsBudget('abcd', 1), true);
      expect(estimator.fitsBudget('abcde', 1), false);
    });

    test('empty text fits any budget', () {
      expect(estimator.fitsBudget('', 0), true);
    });

    test('zero budget rejects non-empty text', () {
      expect(estimator.fitsBudget('a', 0), false);
    });
  });

  // -----------------------------------------------------------------------
  // totalCost
  // -----------------------------------------------------------------------

  group('totalCost', () {
    test('empty list yields 0', () {
      expect(estimator.totalCost([]), 0);
    });

    test('sums token costs', () {
      expect(estimator.totalCost([10, 20, 30]), 60);
    });
  });

  // -----------------------------------------------------------------------
  // remaining
  // -----------------------------------------------------------------------

  group('remaining', () {
    test('full budget unused', () {
      expect(estimator.remaining(800, 0), 800);
    });

    test('partial usage', () {
      expect(estimator.remaining(800, 300), 500);
    });

    test('over budget yields negative', () {
      expect(estimator.remaining(100, 200), -100);
    });
  });

  // -----------------------------------------------------------------------
  // charsPerToken constant
  // -----------------------------------------------------------------------

  group('charsPerToken', () {
    test('is 4', () {
      expect(TokenEstimator.charsPerToken, 4);
    });
  });

  // -----------------------------------------------------------------------
  // Const constructible
  // -----------------------------------------------------------------------

  group('const constructible', () {
    test('can be used as compile-time constant', () {
      const e = TokenEstimator();
      expect(e.estimate('test'), 1);
    });
  });
}
