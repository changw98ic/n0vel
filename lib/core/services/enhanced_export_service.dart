import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 导出格式
enum ExportFormat { txt, markdown, html }

/// 导出选项
class ExportOptions {
  final ExportFormat format;
  final bool includeTitle; // 包含标题
  final bool includeVolumeTitle; // 包含卷标题
  final bool includeWordCount; // 包含字数统计
  final bool includeTOC; // 包含目录
  final bool separateByVolume; // 按卷分文件
  final String? customHeader; // 自定义页眉
  final String? customFooter; // 自定义页脚

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

/// 导出结果
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

/// 章节数据（轻量级，避免依赖 domain 模型）
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

/// 卷数据
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

/// 作品数据
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

/// 增强导出服务
class EnhancedExportService {
  /// 导出作品
  Future<ExportResult> export({
    required ExportWork work,
    required ExportOptions options,
    String? outputPath,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final List<File> files;

      if (options.separateByVolume && work.volumes.length > 1) {
        files = await _exportByVolume(work, options, outputPath);
      } else {
        files = await _exportSingleFile(work, options, outputPath);
      }

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

  /// 导出单个章节
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

  /// TXT 格式生成
  String _generateTxt(ExportWork work, ExportOptions options) {
    final buffer = StringBuffer();

    if (options.customHeader != null) {
      buffer.writeln(options.customHeader);
      buffer.writeln();
    }

    if (options.includeTitle) {
      buffer.writeln(work.name);
      buffer.writeln('=' * work.name.runes.length);
      buffer.writeln();
    }

    if (work.description != null && work.description!.isNotEmpty) {
      buffer.writeln(work.description);
      buffer.writeln();
    }

    if (options.includeTOC) {
      buffer.writeln(_generateTxtTOC(work));
      buffer.writeln();
    }

    for (final volume in _sortedVolumes(work)) {
      if (options.includeVolumeTitle) {
        buffer.writeln('=' * 40);
        buffer.writeln(volume.title);
        buffer.writeln('=' * 40);
        buffer.writeln();
      }

      for (final chapter in _sortedChapters(volume)) {
        buffer.writeln(chapter.title);
        buffer.writeln('-' * 40);

        if (options.includeWordCount) {
          buffer.writeln('字数: ${chapter.wordCount}');
          buffer.writeln();
        }

        buffer.writeln(chapter.content);
        buffer.writeln();
        buffer.writeln('-' * 40);
        buffer.writeln();
      }
    }

    if (options.customFooter != null) {
      buffer.writeln(options.customFooter);
    }

    return buffer.toString();
  }

  /// Markdown 格式生成
  String _generateMarkdown(ExportWork work, ExportOptions options) {
    final buffer = StringBuffer();

    if (options.customHeader != null) {
      buffer.writeln(options.customHeader);
      buffer.writeln();
    }

    if (options.includeTitle) {
      buffer.writeln('# ${work.name}');
      buffer.writeln();
    }

    if (work.description != null && work.description!.isNotEmpty) {
      buffer.writeln(work.description);
      buffer.writeln();
    }

    if (options.includeTOC) {
      buffer.writeln(_generateMarkdownTOC(work));
      buffer.writeln();
    }

    for (final volume in _sortedVolumes(work)) {
      if (options.includeVolumeTitle) {
        buffer.writeln('## ${volume.title}');
        buffer.writeln();
      }

      for (final chapter in _sortedChapters(volume)) {
        buffer.writeln('### ${chapter.title}');
        buffer.writeln();

        if (options.includeWordCount) {
          buffer.writeln('*字数: ${chapter.wordCount}*');
          buffer.writeln();
        }

        buffer.writeln(chapter.content);
        buffer.writeln();
        buffer.writeln('---');
        buffer.writeln();
      }
    }

    if (options.customFooter != null) {
      buffer.writeln(options.customFooter);
    }

    return buffer.toString();
  }

  /// HTML 格式生成
  String _generateHtml(ExportWork work, ExportOptions options) {
    final buffer = StringBuffer();

    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html lang="zh-CN">');
    buffer.writeln('<head>');
    buffer.writeln('<meta charset="UTF-8">');
    buffer.writeln('<meta name="viewport" content="width=device-width, initial-scale=1.0">');
    buffer.writeln('<title>${_escapeHtml(work.name)}</title>');
    buffer.writeln(_htmlStyles());
    buffer.writeln('</head>');
    buffer.writeln('<body>');

    if (options.customHeader != null) {
      buffer.writeln('<div class="header">${_escapeHtml(options.customHeader!)}</div>');
    }

    if (options.includeTitle) {
      buffer.writeln('<h1 class="work-title">${_escapeHtml(work.name)}</h1>');
    }

    if (work.description != null && work.description!.isNotEmpty) {
      buffer.writeln('<p class="description">${_escapeHtml(work.description!)}</p>');
    }

    if (options.includeTOC) {
      buffer.writeln(_generateHtmlTOC(work));
    }

    buffer.writeln('<div class="content">');

    for (final volume in _sortedVolumes(work)) {
      if (options.includeVolumeTitle) {
        buffer.writeln(
          '<h2 class="volume-title" id="volume-${volume.id}">'
          '${_escapeHtml(volume.title)}</h2>',
        );
      }

      for (final chapter in _sortedChapters(volume)) {
        buffer.writeln(
          '<h3 class="chapter-title" id="chapter-${chapter.id}">'
          '${_escapeHtml(chapter.title)}</h3>',
        );

        if (options.includeWordCount) {
          buffer.writeln(
            '<p class="word-count"><em>字数: ${chapter.wordCount}</em></p>',
          );
        }

        buffer.writeln('<div class="chapter-content">');
        buffer.writeln(_htmlParagraphs(chapter.content));
        buffer.writeln('</div>');

        buffer.writeln('<hr class="chapter-divider">');
      }
    }

    buffer.writeln('</div>');

    if (options.customFooter != null) {
      buffer.writeln('<div class="footer">${_escapeHtml(options.customFooter!)}</div>');
    }

    buffer.writeln('</body>');
    buffer.writeln('</html>');

    return buffer.toString();
  }

  /// 章节内容格式化
  String _formatChapterContent(ExportChapter chapter, ExportFormat format) {
    switch (format) {
      case ExportFormat.txt:
        return '${chapter.title}\n'
            '${'-' * 40}\n'
            '${chapter.content}';

      case ExportFormat.markdown:
        return '### ${chapter.title}\n\n'
            '${chapter.content}';

      case ExportFormat.html:
        return '<!DOCTYPE html>\n'
            '<html lang="zh-CN">\n'
            '<head>\n'
            '<meta charset="UTF-8">\n'
            '<title>${_escapeHtml(chapter.title)}</title>\n'
            '${_htmlStyles()}\n'
            '</head>\n'
            '<body>\n'
            '<h3 class="chapter-title">${_escapeHtml(chapter.title)}</h3>\n'
            '<div class="chapter-content">\n'
            '${_htmlParagraphs(chapter.content)}\n'
            '</div>\n'
            '</body>\n'
            '</html>';
    }
  }

  /// 获取导出路径
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

  /// 计算总字数
  int _countTotalWords(ExportWork work) {
    int total = 0;
    for (final volume in work.volumes) {
      for (final chapter in volume.chapters) {
        total += chapter.wordCount;
      }
    }
    return total;
  }

  // ── Private helpers ──────────────────────────────────────────────

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

    final content = switch (options.format) {
      ExportFormat.txt => _generateTxt(work, options),
      ExportFormat.markdown => _generateMarkdown(work, options),
      ExportFormat.html => _generateHtml(work, options),
    };

    final file = File(filePath);
    await file.writeAsString(content);

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

      final content = switch (options.format) {
        ExportFormat.txt => _generateTxt(volumeWork, options),
        ExportFormat.markdown => _generateMarkdown(volumeWork, options),
        ExportFormat.html => _generateHtml(volumeWork, options),
      };

      await file.writeAsString(content);
      files.add(file);
    }

    return files;
  }

  int _countTotalChapters(ExportWork work) {
    int count = 0;
    for (final volume in work.volumes) {
      count += volume.chapters.length;
    }
    return count;
  }

  List<ExportVolume> _sortedVolumes(ExportWork work) {
    return [...work.volumes]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  List<ExportChapter> _sortedChapters(ExportVolume volume) {
    return [...volume.chapters]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  // ── TOC generators ───────────────────────────────────────────────

  String _generateTxtTOC(ExportWork work) {
    final buffer = StringBuffer();
    buffer.writeln('目录');
    buffer.writeln('=' * 10);

    for (final volume in _sortedVolumes(work)) {
      buffer.writeln('  ${volume.title}');
      for (final chapter in _sortedChapters(volume)) {
        buffer.writeln('    - ${chapter.title}');
      }
    }

    return buffer.toString().trimRight();
  }

  String _generateMarkdownTOC(ExportWork work) {
    final buffer = StringBuffer();
    buffer.writeln('## 目录');
    buffer.writeln();

    for (final volume in _sortedVolumes(work)) {
      buffer.writeln('- **${volume.title}**');
      for (final chapter in _sortedChapters(volume)) {
        final anchor = _markdownAnchor(chapter.title);
        buffer.writeln('  - [${chapter.title}](#$anchor)');
      }
    }

    return buffer.toString().trimRight();
  }

  String _generateHtmlTOC(ExportWork work) {
    final buffer = StringBuffer();
    buffer.writeln('<nav class="toc">');
    buffer.writeln('<h2 class="toc-title">目录</h2>');
    buffer.writeln('<ul class="toc-volumes">');

    for (final volume in _sortedVolumes(work)) {
      buffer.writeln('<li class="toc-volume">');
      buffer.writeln(
        '<a href="#volume-${volume.id}">${_escapeHtml(volume.title)}</a>',
      );
      buffer.writeln('<ul class="toc-chapters">');

      for (final chapter in _sortedChapters(volume)) {
        buffer.writeln(
          '<li><a href="#chapter-${chapter.id}">'
          '${_escapeHtml(chapter.title)}</a></li>',
        );
      }

      buffer.writeln('</ul>');
      buffer.writeln('</li>');
    }

    buffer.writeln('</ul>');
    buffer.writeln('</nav>');

    return buffer.toString();
  }

  // ── HTML helpers ─────────────────────────────────────────────────

  String _htmlStyles() {
    return '<style>\n'
        '  body {\n'
        '    font-family: "Georgia", "Noto Serif SC", "SimSun", serif;\n'
        '    max-width: 800px;\n'
        '    margin: 0 auto;\n'
        '    padding: 2em;\n'
        '    line-height: 1.8;\n'
        '    color: #333;\n'
        '    background-color: #fff;\n'
        '  }\n'
        '  .work-title {\n'
        '    text-align: center;\n'
        '    font-size: 2em;\n'
        '    margin-bottom: 0.5em;\n'
        '    border-bottom: 2px solid #333;\n'
        '    padding-bottom: 0.5em;\n'
        '  }\n'
        '  .description {\n'
        '    text-align: center;\n'
        '    font-style: italic;\n'
        '    color: #666;\n'
        '    margin-bottom: 2em;\n'
        '  }\n'
        '  .volume-title {\n'
        '    font-size: 1.5em;\n'
        '    margin-top: 2em;\n'
        '    padding-bottom: 0.3em;\n'
        '    border-bottom: 1px solid #ccc;\n'
        '  }\n'
        '  .chapter-title {\n'
        '    font-size: 1.2em;\n'
        '    margin-top: 1.5em;\n'
        '  }\n'
        '  .chapter-content p {\n'
        '    text-indent: 2em;\n'
        '    margin: 0.8em 0;\n'
        '  }\n'
        '  .chapter-divider {\n'
        '    border: none;\n'
        '    border-top: 1px solid #ddd;\n'
        '    margin: 2em 0;\n'
        '  }\n'
        '  .word-count {\n'
        '    font-size: 0.85em;\n'
        '    color: #999;\n'
        '  }\n'
        '  .toc {\n'
        '    background-color: #f9f9f9;\n'
        '    border: 1px solid #ddd;\n'
        '    border-radius: 4px;\n'
        '    padding: 1em 2em;\n'
        '    margin-bottom: 2em;\n'
        '  }\n'
        '  .toc-title {\n'
        '    margin-top: 0;\n'
        '    font-size: 1.3em;\n'
        '  }\n'
        '  .toc-volumes, .toc-chapters {\n'
        '    list-style: none;\n'
        '    padding-left: 1em;\n'
        '  }\n'
        '  .toc-chapters {\n'
        '    padding-left: 2em;\n'
        '  }\n'
        '  .toc-volume > a {\n'
        '    font-weight: bold;\n'
        '  }\n'
        '  .toc a {\n'
        '    color: #0366d6;\n'
        '    text-decoration: none;\n'
        '  }\n'
        '  .toc a:hover {\n'
        '    text-decoration: underline;\n'
        '  }\n'
        '  .header, .footer {\n'
        '    text-align: center;\n'
        '    font-size: 0.9em;\n'
        '    color: #999;\n'
        '    padding: 1em 0;\n'
        '  }\n'
        '  .header {\n'
        '    border-bottom: 1px solid #eee;\n'
        '    margin-bottom: 1em;\n'
        '  }\n'
        '  .footer {\n'
        '    border-top: 1px solid #eee;\n'
        '    margin-top: 1em;\n'
        '  }\n'
        '  @media print {\n'
        '    body {\n'
        '      max-width: none;\n'
        '      padding: 0;\n'
        '    }\n'
        '    .toc {\n'
        '      page-break-after: always;\n'
        '    }\n'
        '    .volume-title {\n'
        '      page-break-before: always;\n'
        '    }\n'
        '    .chapter-divider {\n'
        '      display: none;\n'
        '    }\n'
        '  }\n'
        '</style>';
  }

  String _htmlParagraphs(String text) {
    final paragraphs = text.split(RegExp(r'\n\s*\n'));
    final buffer = StringBuffer();
    for (final para in paragraphs) {
      final trimmed = para.trim();
      if (trimmed.isNotEmpty) {
        buffer.writeln('<p>${_escapeHtml(trimmed)}</p>');
      }
    }
    return buffer.toString();
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  String _markdownAnchor(String title) {
    return title
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s\u4e00-\u9fff-]'), '')
        .replaceAll(RegExp(r'\s+'), '-');
  }

  // ── File helpers ─────────────────────────────────────────────────

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

  String _fileExtension(ExportFormat format) {
    return switch (format) {
      ExportFormat.txt => 'txt',
      ExportFormat.markdown => 'md',
      ExportFormat.html => 'html',
    };
  }

  String _timestamp() {
    final now = DateTime.now();
    final y = now.year.toString();
    final mo = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final h = now.hour.toString().padLeft(2, '0');
    final mi = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    return '$y$mo$d-$h$mi$s';
  }

  String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }
}
