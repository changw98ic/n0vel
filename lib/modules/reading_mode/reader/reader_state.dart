import 'package:get/get.dart';

import '../../../features/reading_mode/domain/reading_models.dart';
import '../../../features/editor/domain/chapter.dart';

/// Reader 页面响应式状态
class ReaderState {
  final currentChapterId = Rx<String?>(null);
  final currentChapter = Rx<Chapter?>(null);
  final currentPosition = 0.obs;
  final startPosition = 0.obs;
  final isToolbarVisible = true.obs;
  final isSettingsVisible = false.obs;
  final settings = const ReadingSettings().obs;

  final chaptersForSelector = Rx<List<Chapter>?>(null);
  final chaptersForSelectorError = Rx<Object?>(null);

  final loadedChapter = Rx<Chapter?>(null);
  final chapterError = Rx<Object?>(null);

  final readingProgress = Rx<ReadingProgress?>(null);
  final readingProgressError = Rx<Object?>(null);
}
