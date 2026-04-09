import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../features/editor/data/chapter_repository.dart';
import '../../features/editor/domain/chapter.dart';
import '../../features/work/data/volume_repository.dart';
import '../../features/work/data/work_repository.dart';
import '../../features/work/domain/volume.dart';
import '../../features/work/domain/work.dart';

enum WorkExportFormat {
  zip('zip'),
  txt('txt'),
  markdown('md');

  const WorkExportFormat(this.fileExtension);

  final String fileExtension;
}

class ExportResult {
  final String path;
  final int chapterCount;

  const ExportResult({
    required this.path,
    required this.chapterCount,
  });
}

class ExportService {
  final WorkRepository _workRepository;
  final VolumeRepository _volumeRepository;
  final ChapterRepository _chapterRepository;

  ExportService({
    required WorkRepository workRepository,
    required VolumeRepository volumeRepository,
    required ChapterRepository chapterRepository,
  })  : _workRepository = workRepository,
        _volumeRepository = volumeRepository,
        _chapterRepository = chapterRepository;

  Future<ExportResult> exportWork({
    required String workId,
    required WorkExportFormat format,
  }) async {
    final work = await _workRepository.getWorkById(workId);
    if (work == null) {
      throw StateError('Work not found: $workId');
    }

    final volumes = await _volumeRepository.getVolumesByWorkId(workId);
    final chapters = await _chapterRepository.getChaptersByWorkId(workId);

    return switch (format) {
      WorkExportFormat.zip => _exportZip(work, volumes, chapters),
      WorkExportFormat.txt => _exportSingleFile(work, volumes, chapters, format),
      WorkExportFormat.markdown =>
        _exportSingleFile(work, volumes, chapters, format),
    };
  }

  Future<ExportResult> _exportSingleFile(
    Work work,
    List<Volume> volumes,
    List<Chapter> chapters,
    WorkExportFormat format,
  ) async {
    final exportDir = await _ensureExportDirectory();
    final fileName =
        '${_sanitizeFileName(work.name)}_${_timestamp()}.${format.fileExtension}';
    final file = File(p.join(exportDir.path, fileName));
    final content = _buildCombinedContent(work, volumes, chapters, format);
    await file.writeAsString(content);

    return ExportResult(
      path: file.path,
      chapterCount: chapters.length,
    );
  }

  Future<ExportResult> _exportZip(
    Work work,
    List<Volume> volumes,
    List<Chapter> chapters,
  ) async {
    final exportDir = await _ensureExportDirectory();
    final fileName = '${_sanitizeFileName(work.name)}_${_timestamp()}.zip';
    final file = File(p.join(exportDir.path, fileName));

    final archive = Archive();
    archive.addFile(
      ArchiveFile.string(
        'info.txt',
        _buildInfoContent(work, volumes, chapters),
      ),
    );

    if (work.coverPath != null && work.coverPath!.isNotEmpty) {
      final coverFile = File(work.coverPath!);
      if (await coverFile.exists()) {
        final bytes = await coverFile.readAsBytes();
        archive.addFile(
          ArchiveFile(
            'cover${p.extension(coverFile.path)}',
            bytes.length,
            bytes,
          ),
        );
      }
    }

    if (volumes.isEmpty) {
      for (final chapter in chapters) {
        archive.addFile(
          ArchiveFile.string(
            _chapterFileName(chapter, chapter.sortOrder + 1, 'txt'),
            chapter.content ?? '',
          ),
        );
      }
    } else {
      for (final volume in volumes) {
        final volumeChapters = chapters
            .where((chapter) => chapter.volumeId == volume.id)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

        for (var i = 0; i < volumeChapters.length; i++) {
          final chapter = volumeChapters[i];
          archive.addFile(
            ArchiveFile.string(
              p.join(
                _sanitizeFileName(volume.name),
                _chapterFileName(chapter, i + 1, 'txt'),
              ),
              chapter.content ?? '',
            ),
          );
        }
      }
    }

    final bytes = ZipEncoder().encode(archive);
    if (bytes == null) {
      throw StateError('Failed to encode zip archive');
    }
    await file.writeAsBytes(bytes, flush: true);

    return ExportResult(
      path: file.path,
      chapterCount: chapters.length,
    );
  }

  String _buildCombinedContent(
    Work work,
    List<Volume> volumes,
    List<Chapter> chapters,
    WorkExportFormat format,
  ) {
    final isMarkdown = format == WorkExportFormat.markdown;
    final buffer = StringBuffer();

    if (isMarkdown) {
      buffer.writeln('# ${work.name}');
      buffer.writeln();
      if (work.description != null && work.description!.isNotEmpty) {
        buffer.writeln(work.description);
        buffer.writeln();
      }
    } else {
      buffer.writeln(work.name);
      buffer.writeln('=' * work.name.length);
      if (work.description != null && work.description!.isNotEmpty) {
        buffer.writeln(work.description);
        buffer.writeln();
      }
    }

    if (volumes.isEmpty) {
      final orderedChapters = [...chapters]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      for (var i = 0; i < orderedChapters.length; i++) {
        _writeChapter(buffer, orderedChapters[i], i + 1, isMarkdown);
      }
      return buffer.toString();
    }

    for (final volume in [...volumes]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder))) {
      if (isMarkdown) {
        buffer.writeln('## ${volume.name}');
      } else {
        buffer.writeln();
        buffer.writeln(volume.name);
        buffer.writeln('-' * volume.name.length);
      }
      buffer.writeln();

      final volumeChapters = chapters
          .where((chapter) => chapter.volumeId == volume.id)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      for (var i = 0; i < volumeChapters.length; i++) {
        _writeChapter(buffer, volumeChapters[i], i + 1, isMarkdown);
      }
    }

    return buffer.toString();
  }

  void _writeChapter(
    StringBuffer buffer,
    Chapter chapter,
    int order,
    bool isMarkdown,
  ) {
    final title = '第$order章 ${chapter.title}';
    if (isMarkdown) {
      buffer.writeln('### $title');
    } else {
      buffer.writeln(title);
      buffer.writeln('~' * title.length);
    }
    buffer.writeln();
    if (chapter.content != null && chapter.content!.isNotEmpty) {
      buffer.writeln(chapter.content);
    }
    buffer.writeln();
  }

  String _buildInfoContent(
    Work work,
    List<Volume> volumes,
    List<Chapter> chapters,
  ) {
    final totalWords = chapters.fold<int>(
      0,
      (sum, chapter) => sum + chapter.wordCount,
    );

    return [
      '标题: ${work.name}',
      '类型: ${work.type ?? 'unknown'}',
      '状态: ${work.status}',
      '目标字数: ${work.targetWords ?? 0}',
      '当前字数: $totalWords',
      '卷数: ${volumes.length}',
      '章节数: ${chapters.length}',
      '创建时间: ${work.createdAt.toIso8601String()}',
      '更新时间: ${work.updatedAt.toIso8601String()}',
      if (work.description != null && work.description!.isNotEmpty)
        '简介: ${work.description}',
    ].join('\n');
  }

  String _chapterFileName(Chapter chapter, int order, String extension) {
    final safeTitle = _sanitizeFileName(chapter.title);
    return '第$order章_$safeTitle.$extension';
  }

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

  String _timestamp() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');
    return '${now.year}$month$day-$hour$minute$second';
  }

  String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }
}
