import 'package:freezed_annotation/freezed_annotation.dart';

part 'word_count.freezed.dart';

/// 字数统计值对象
/// 支持中英文混合文本的字数计算
@freezed
class WordCount with _$WordCount {
  const WordCount._();

  const factory WordCount({
    required int chineseChars,
    required int englishWords,
    required int punctuation,
    required int total,
  }) = _WordCount;

  /// 从文本计算字数
  factory WordCount.fromText(String text) {
    final chineseRegex = RegExp(r'[\u4e00-\u9fff]');
    final englishRegex = RegExp(r'[a-zA-Z]+');
    final punctuationRegex = RegExp(r'[，。！？、；：""''（）【】《》\.\,\!\?\;\:\"\'\(\)\[\]]');

    final chineseChars = chineseRegex.allMatches(text).length;
    final englishWords = englishRegex.allMatches(text).length;
    final punctuation = punctuationRegex.allMatches(text).length;

    // 中文按字符计，英文按单词计
    final total = chineseChars + englishWords;

    return WordCount(
      chineseChars: chineseChars,
      englishWords: englishWords,
      punctuation: punctuation,
      total: total,
    );
  }

  /// 格式化显示
  String get formatted {
    if (total >= 10000) {
      return '${(total / 10000).toStringAsFixed(1)}万字';
    }
    return '$total字';
  }
}
