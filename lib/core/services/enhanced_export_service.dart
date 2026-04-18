import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'enhanced_export_formatting.dart';

/// 絳堤跡宒
enum ExportFormat { txt, markdown, html }

/// 絳堤恁砐
class ExportOptions {
  final ExportFormat format;
  final bool includeTitle; // 婦漪梓枙
  final bool includeVolumeTitle; // 婦漪橙梓枙
  final bool includeWordCount; // 婦漪趼杅苀數
  final bool includeTOC; // 婦漪醴翹
  final bool separateByVolume; // 偌橙煦恅璃
  final String? customHeader; // 赻隅砱珜羹
  final String? customFooter; // 赻隅砱珜褐

  const ExportOptions({
    this.format = ExportFormat.txt,
    this.includeTitle = true,
    this.includeVolumeTitle = true,
    this.includeWordCount = false,
    this.includeTOC = true,
    this.separateByVolume = false,
    this.customHeader,
    this.customFooter,
  });
}

/// 絳堤賦彆
class ExportResult {
  final List<File> files;
  final int totalWords;
  final int totalChapters;
  final Duration exportTime;

  const ExportResult({
    required this.files,
    required this.totalWords,
    required this.totalChapters,
    required this.exportTime,
  });
}

/// 梒誹杅擂ㄗュ講撰ㄛ旌轎甡懇 domain 耀倰ㄘ
class ExportChapter {
  final String id;
  final String title;
  final String content;
  final int wordCount;
  final int sortOrder;

  const ExportChapter({
    required this.id,
    required this.title,
    required this.content,
    required this.wordCount,
    required this.sortOrder,
  });
}

/// 橙杅擂
class ExportVolume {
  final String id;
  final String title;
  final int sortOrder;
  final List<ExportChapter> chapters;

  const ExportVolume({
    required this.id,
    required this.title,
    required this.sortOrder,
    required this.chapters,
  });
}

/// 釬ⅲ杅擂
class ExportWork {
  final String id;
  final String name;
  final String? description;
  final List<ExportVolume> volumes;

  const ExportWork({
    required this.id,
    required this.name,
    this.description,
    required this.volumes,
  });
}

/// 崝ッ絳堤督昢
class EnhancedExportService {
  /// 絳堤釬ⅲ
  Future<ExportResult> export({
    required ExportWork work,
    required ExportOptions options,
    String? outputPath,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final files = options.separateByVolume && work.volumes.length > 1
          ? await _exportByVolume(work, options, outputPath)
          : await _exportSingleFile(work, options, outputPath);

      stopwatch.stop();

      return ExportResult(
        files: files,
        totalWords: _countTotalWords(work),
        totalChapters: _countTotalChapters(work),
        exportTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      rethrow;
    }
  }

  /// 絳堤等跺梒誹
  Future<File> exportChapter({
    required ExportChapter chapter,
    required ExportOptions options,
    String? outputPath,
  }) async {
    final exportDir = outputPath != null
        ? Directory(outputPath)
        : await _ensureExportDirectory();

    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final extension = _fileExtension(options.format);
    final safeTitle = _sanitizeFileName(chapter.title);
    final fileName = '${safeTitle}.$extension';
    final file = File(p.join(exportDir.path, fileName));

    final content = _formatChapterContent(chapter, options.format);
    await file.writeAsString(content);

    return file;
  }

  /// 鳳龰絳堤繚噤
  Future<String> _getExportPath(
    String workName,
    ExportFormat format,
    String? customPath,
  ) async {
    final dir = customPath != null
        ? customPath
        : (await _ensureExportDirectory()).path;
    final extension = _fileExtension(format);
    final timestamp = _timestamp();
    final safeName = _sanitizeFileName(workName);
    return p.join(dir, '${safeName}_$timestamp.$extension');
  }

  // 岸岸 Private helpers 岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸

  Future<List<File>> _exportSingleFile(
    ExportWork work,
    ExportOptions options,
    String? outputPath,
  ) async {
    final filePath = await _getExportPath(
      work.name,
      options.format,
      outputPath,
    );

    final file = File(filePath);
    await file.writeAsString(_buildExportContent(work, options));

    return [file];
  }

  Future<List<File>> _exportByVolume(
    ExportWork work,
    ExportOptions options,
    String? outputPath,
  ) async {
    final exportDir = outputPath != null
        ? outputPath
        : (await _ensureExportDirectory()).path;
    final extension = _fileExtension(options.format);
    final timestamp = _timestamp();
    final safeWorkName = _sanitizeFileName(work.name);
    final files = <File>[];

    final workDir = Directory(p.join(exportDir, '${safeWorkName}_$timestamp'));
    await workDir.create(recursive: true);

    for (final volume in _sortedVolumes(work)) {
      final safeVolumeName = _sanitizeFileName(volume.title);
      final fileName = '$safeVolumeName.$extension';
      final file = File(p.join(workDir.path, fileName));

      final volumeWork = ExportWork(
        id: work.id,
        name: '${work.name} - ${volume.title}',
        description: work.description,
        volumes: [volume],
      );

      await file.writeAsString(_buildExportContent(volumeWork, options));
      files.add(file);
    }

    return files;
  }

  // 岸岸 File helpers 岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸岸

  Future<Directory> _ensureExportDirectory() async {
    final baseDir = await getApplicationDocumentsDirectory();
    final exportDir = Directory(
      p.join(baseDir.path, 'writing_assistant', 'exports'),
    );
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    return exportDir;
  }
}
