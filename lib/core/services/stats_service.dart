import '../../features/editor/data/chapter_repository.dart';
import '../../features/work/data/work_repository.dart';

class WorkStatsSummary {
  final String workId;
  final int totalWords;
  final int chapterCount;

  const WorkStatsSummary({
    required this.workId,
    required this.totalWords,
    required this.chapterCount,
  });
}

class StatsService {
  final WorkRepository _workRepository;
  final ChapterRepository _chapterRepository;

  StatsService({
    required WorkRepository workRepository,
    required ChapterRepository chapterRepository,
  })  : _workRepository = workRepository,
        _chapterRepository = chapterRepository;

  Future<WorkStatsSummary?> getWorkSummary(String workId) async {
    final work = await _workRepository.getWorkById(workId);
    if (work == null) {
      return null;
    }

    final chapters = await _chapterRepository.getChaptersByWorkId(workId);
    final totalWords = chapters.fold<int>(
      0,
      (sum, chapter) => sum + chapter.wordCount,
    );

    return WorkStatsSummary(
      workId: workId,
      totalWords: totalWords,
      chapterCount: chapters.length,
    );
  }
}
