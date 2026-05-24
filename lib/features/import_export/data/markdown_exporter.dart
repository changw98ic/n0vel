import 'dart:io';
import 'dart:convert';

import '../../../domain/workspace_models.dart' as domain;
import '../../../domain/scene_location_parts.dart';

/// Export result containing written files and counts.
class MarkdownExportResult {
  const MarkdownExportResult({
    required this.writtenFiles,
    required this.projectJsonFile,
    required this.readmeFile,
    required this.sceneCount,
    required this.characterCount,
    required this.worldNodeCount,
  });

  /// All written relative paths from the target directory root.
  final List<String> writtenFiles;

  /// Path to project.n0vel.json.
  final String projectJsonFile;

  /// Path to README.md.
  final String readmeFile;

  /// Number of scene files written.
  final int sceneCount;

  /// Number of character files written.
  final int characterCount;

  /// Number of world node files written.
  final int worldNodeCount;
}

/// Input model for markdown export.
class MarkdownExportInput {
  const MarkdownExportInput({
    required this.project,
    required this.scenes,
    required this.characters,
    required this.worldNodes,
    this.draftText = '',
  });

  final domain.ProjectRecord project;
  final List<domain.SceneRecord> scenes;
  final List<domain.CharacterRecord> characters;
  final List<domain.WorldNodeRecord> worldNodes;
  final String draftText;
}

/// Markdown mirror exporter.
///
/// Exports a complete project into a deterministic, readable, editable
/// Markdown file tree while keeping SQLite as the source of truth.
///
/// Output structure:
/// ```
/// project.n0vel.json
/// README.md
/// chapters/
///   ch01/
///     scene-001.md
/// bible/
///   characters/
///     001-<slug>.md
///   world/
///     001-<slug>.md
/// ```
class MarkdownExporter {
  /// Export the project to the target directory.
  ///
  /// The directory will be created if it does not exist.
  /// Existing files will be overwritten.
  Future<MarkdownExportResult> export(
    MarkdownExportInput input,
    Directory targetDirectory,
  ) async {
    final writtenFiles = <String>[];

    // Ensure target directory exists
    if (!await targetDirectory.exists()) {
      await targetDirectory.create(recursive: true);
    }

    // Write project.n0vel.json
    final projectJsonFile = File('${targetDirectory.path}/project.n0vel.json');
    await _writeProjectJson(input, projectJsonFile);
    writtenFiles.add('project.n0vel.json');

    // Write README.md
    final readmeFile = File('${targetDirectory.path}/README.md');
    await _writeReadme(input, readmeFile);
    writtenFiles.add('README.md');

    // Write chapters/
    final chaptersDir = Directory('${targetDirectory.path}/chapters');
    if (!await chaptersDir.exists()) {
      await chaptersDir.create(recursive: true);
    }

    // Group scenes by chapter
    final sceneCount = await _writeScenes(input, chaptersDir, writtenFiles);

    // Write bible/
    final bibleDir = Directory('${targetDirectory.path}/bible');
    if (!await bibleDir.exists()) {
      await bibleDir.create(recursive: true);
    }

    final characterCount = await _writeCharacters(
      input,
      Directory('${bibleDir.path}/characters'),
      writtenFiles,
    );

    final worldNodeCount = await _writeWorldNodes(
      input,
      Directory('${bibleDir.path}/world'),
      writtenFiles,
    );

    return MarkdownExportResult(
      writtenFiles: writtenFiles,
      projectJsonFile: projectJsonFile.path,
      readmeFile: readmeFile.path,
      sceneCount: sceneCount,
      characterCount: characterCount,
      worldNodeCount: worldNodeCount,
    );
  }

  Future<void> _writeProjectJson(
    MarkdownExportInput input,
    File targetFile,
  ) async {
    final data = {
      'project': input.project.toJson(),
      'characters': [for (final c in input.characters) c.toJson()],
      'scenes': [for (final s in input.scenes) s.toJson()],
      'worldNodes': [for (final w in input.worldNodes) w.toJson()],
      'draft': input.draftText,
    };

    const encoder = JsonEncoder.withIndent('  ');
    await targetFile.writeAsString(encoder.convert(data));
  }

  Future<void> _writeReadme(MarkdownExportInput input, File targetFile) async {
    final buf = StringBuffer();

    buf.writeln('# ${input.project.title}');
    buf.writeln();

    if (input.project.genre.isNotEmpty) {
      buf.writeln('**类型**: ${input.project.genre}');
      buf.writeln();
    }

    if (input.project.summary.isNotEmpty) {
      buf.writeln('> ${input.project.summary}');
      buf.writeln();
    }

    buf.writeln('---');
    buf.writeln();

    // Table of contents
    buf.writeln('## 导出结构');
    buf.writeln();
    buf.writeln('- `project.n0vel.json` — 项目元数据（机器可读）');
    buf.writeln('- `README.md` — 本文件，项目概览');
    buf.writeln('- `chapters/` — 章节和场景');
    buf.writeln('- `bible/characters/` — 角色资料');
    buf.writeln('- `bible/world/` — 世界观设定');
    buf.writeln();

    // Summary statistics
    final sceneCount = input.scenes.length;
    final characterCount = input.characters.length;
    final worldNodeCount = input.worldNodes.length;

    if (sceneCount > 0 || characterCount > 0 || worldNodeCount > 0) {
      buf.writeln('## 内容概览');
      buf.writeln();
      if (sceneCount > 0) {
        buf.writeln('- **章节数**: $sceneCount');
      }
      if (characterCount > 0) {
        buf.writeln('- **角色数**: $characterCount');
      }
      if (worldNodeCount > 0) {
        buf.writeln('- **世界观条目**: $worldNodeCount');
      }
      buf.writeln();
    }

    await targetFile.writeAsString(buf.toString());
  }

  Future<int> _writeScenes(
    MarkdownExportInput input,
    Directory chaptersDir,
    List<String> writtenFiles,
  ) async {
    if (input.scenes.isEmpty) {
      return 0;
    }

    // Group scenes by chapter for organization
    final scenesByChapter = <String, List<domain.SceneRecord>>{};

    for (final scene in input.scenes) {
      final parts = SceneLocationParts.fromLabel(scene.chapterLabel);
      final chapterKey = parts.chapterLabel.isEmpty
          ? 'unsorted'
          : _slugifyChapterLabel(parts.chapterLabel);

      scenesByChapter.putIfAbsent(chapterKey, () => []).add(scene);
    }

    // Sort chapters deterministically
    final sortedChapterKeys = scenesByChapter.keys.toList()..sort();

    // Track used filenames within each chapter to detect collisions
    final usedFilenamesByChapter = <String, Set<String>>{};

    // Write each scene
    var sceneIndex = 0;
    for (final chapterKey in sortedChapterKeys) {
      final chapterScenes = scenesByChapter[chapterKey]!;
      usedFilenamesByChapter.putIfAbsent(chapterKey, () => <String>{});

      // Sort scenes within chapter by chapterLabel
      chapterScenes.sort((a, b) => a.chapterLabel.compareTo(b.chapterLabel));

      for (final scene in chapterScenes) {
        sceneIndex++;
        final sceneNumber = _sceneIndexFor(scene, sceneIndex);

        // Create path: chapters/ch01/scene-001.md
        final chapterDir = Directory('${chaptersDir.path}/$chapterKey');
        if (!await chapterDir.exists()) {
          await chapterDir.create(recursive: true);
        }

        // Generate unique filename to prevent collisions
        final filename = _generateUniqueSceneFilename(
          scene,
          sceneNumber,
          usedFilenamesByChapter[chapterKey]!,
        );
        final sceneFile = File('${chapterDir.path}/$filename');
        final relativePath = 'chapters/$chapterKey/$filename';

        await _writeSceneFile(scene, sceneFile);
        writtenFiles.add(relativePath);
      }
    }

    return sceneIndex;
  }

  Future<void> _writeSceneFile(
    domain.SceneRecord scene,
    File targetFile,
  ) async {
    final buf = StringBuffer();

    // Frontmatter with metadata
    buf.writeln('---');
    buf.writeln('id: ${scene.id}');
    buf.writeln('chapter: ${scene.chapterLabel}');
    buf.writeln('---');
    buf.writeln();

    // Title
    buf.writeln('# ${scene.title}');
    buf.writeln();

    // Summary (goal/conflict/constraint)
    if (scene.summary.isNotEmpty) {
      buf.writeln('## 摘要');
      buf.writeln();
      buf.writeln(scene.summary);
      buf.writeln();
    }

    await targetFile.writeAsString(buf.toString());
  }

  Future<int> _writeCharacters(
    MarkdownExportInput input,
    Directory charactersDir,
    List<String> writtenFiles,
  ) async {
    if (input.characters.isEmpty) {
      return 0;
    }

    if (!await charactersDir.exists()) {
      await charactersDir.create(recursive: true);
    }

    // Sort characters deterministically by name
    final sortedCharacters = input.characters.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    for (var i = 0; i < sortedCharacters.length; i++) {
      final character = sortedCharacters[i];
      final number = (i + 1).toString().padLeft(3, '0');
      final slug = _slugifyFilename(character.name);
      final filename = '$number-$slug.md';
      final characterFile = File('${charactersDir.path}/$filename');
      final relativePath = 'bible/characters/$filename';

      await _writeCharacterFile(character, characterFile);
      writtenFiles.add(relativePath);
    }

    return sortedCharacters.length;
  }

  Future<void> _writeCharacterFile(
    domain.CharacterRecord character,
    File targetFile,
  ) async {
    final buf = StringBuffer();

    // Frontmatter
    buf.writeln('---');
    buf.writeln('id: ${character.id}');
    if (character.role.isNotEmpty) {
      buf.writeln('role: ${character.role}');
    }
    buf.writeln('---');
    buf.writeln();

    // Name and role
    buf.writeln('# ${character.name}');
    if (character.role.isNotEmpty) {
      buf.writeln();
      buf.writeln('**角色**: ${character.role}');
    }
    buf.writeln();

    // Summary
    if (character.summary.isNotEmpty) {
      buf.writeln('## 简介');
      buf.writeln();
      buf.writeln(character.summary);
      buf.writeln();
    }

    // Core need
    if (character.need.isNotEmpty) {
      buf.writeln('## 核心需求');
      buf.writeln();
      buf.writeln(character.need);
      buf.writeln();
    }

    // Notes
    if (character.note.isNotEmpty) {
      buf.writeln('## 备注');
      buf.writeln();
      buf.writeln(character.note);
      buf.writeln();
    }

    await targetFile.writeAsString(buf.toString());
  }

  Future<int> _writeWorldNodes(
    MarkdownExportInput input,
    Directory worldDir,
    List<String> writtenFiles,
  ) async {
    if (input.worldNodes.isEmpty) {
      return 0;
    }

    if (!await worldDir.exists()) {
      await worldDir.create(recursive: true);
    }

    // Sort world nodes deterministically by title
    final sortedNodes = input.worldNodes.toList()
      ..sort((a, b) => a.title.compareTo(b.title));

    for (var i = 0; i < sortedNodes.length; i++) {
      final node = sortedNodes[i];
      final number = (i + 1).toString().padLeft(3, '0');
      final slug = _slugifyFilename(node.title);
      final filename = '$number-$slug.md';
      final nodeFile = File('${worldDir.path}/$filename');
      final relativePath = 'bible/world/$filename';

      await _writeWorldNodeFile(node, nodeFile);
      writtenFiles.add(relativePath);
    }

    return sortedNodes.length;
  }

  Future<void> _writeWorldNodeFile(
    domain.WorldNodeRecord node,
    File targetFile,
  ) async {
    final buf = StringBuffer();

    // Frontmatter
    buf.writeln('---');
    buf.writeln('id: ${node.id}');
    if (node.type.isNotEmpty) {
      buf.writeln('type: ${node.type}');
    }
    if (node.location.isNotEmpty) {
      buf.writeln('location: ${node.location}');
    }
    buf.writeln('---');
    buf.writeln();

    // Title and type
    buf.writeln('# ${node.title}');
    if (node.type.isNotEmpty) {
      buf.writeln();
      buf.writeln('**类型**: ${node.type}');
    }
    if (node.location.isNotEmpty) {
      buf.writeln();
      buf.writeln('**位置**: ${node.location}');
    }
    buf.writeln();

    // Summary
    if (node.summary.isNotEmpty) {
      buf.writeln('## 概要');
      buf.writeln();
      buf.writeln(node.summary);
      buf.writeln();
    }

    // Rules
    if (node.ruleSummary.isNotEmpty) {
      buf.writeln('## 规则');
      buf.writeln();
      buf.writeln(node.ruleSummary);
      buf.writeln();
    }

    // Detail
    if (node.detail.isNotEmpty) {
      buf.writeln('## 详情');
      buf.writeln();
      buf.writeln(node.detail);
      buf.writeln();
    }

    await targetFile.writeAsString(buf.toString());
  }

  /// Generate a zero-padded scene number from index.
  /// Uses scene.label sceneNumber when available, falls back to index.
  String _sceneIndexFor(domain.SceneRecord scene, int fallbackIndex) {
    final parts = SceneLocationParts.fromLabel(scene.chapterLabel);
    final sceneNum = parts.sceneNumber;
    if (sceneNum != null) {
      return sceneNum.toString().padLeft(3, '0');
    }
    return fallbackIndex.toString().padLeft(3, '0');
  }

  /// Generate a unique scene filename, avoiding collisions within a chapter.
  /// Returns a filename like 'scene-001.md' or 'scene-001-title-slug.md' or 'scene-001-id.md'.
  String _generateUniqueSceneFilename(
    domain.SceneRecord scene,
    String sceneNumber,
    Set<String> usedFilenames,
  ) {
    final baseFilename = 'scene-$sceneNumber.md';

    if (!usedFilenames.contains(baseFilename)) {
      usedFilenames.add(baseFilename);
      return baseFilename;
    }

    // Collision detected: generate unique suffix
    // Try title slug first, then fall back to id
    final titleSlug = _slugifyFilename(scene.title);
    if (titleSlug.isNotEmpty && titleSlug != 'unnamed') {
      final withTitle = 'scene-$sceneNumber-$titleSlug.md';
      if (!usedFilenames.contains(withTitle)) {
        usedFilenames.add(withTitle);
        return withTitle;
      }
    }

    // Fall back to id for guaranteed uniqueness (sanitize id first)
    final idSlug = _slugifyFilename(scene.id);
    final withId = 'scene-$sceneNumber-$idSlug.md';
    var candidate = withId;
    var counter = 2;

    while (usedFilenames.contains(candidate)) {
      candidate = 'scene-$sceneNumber-$idSlug-$counter.md';
      counter++;
    }

    usedFilenames.add(candidate);
    return candidate;
  }

  /// Slugify chapter label for directory name.
  /// Extracts chapter number if present, otherwise generates a safe name.
  String _slugifyChapterLabel(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) {
      return 'ch00';
    }

    // Try to extract chapter number from pattern like "第 1 章" or "第一章"
    final match = RegExp(r'第\s*(\d+)\s*章').firstMatch(trimmed);
    if (match != null) {
      final num = int.tryParse(match.group(1) ?? '');
      if (num != null) {
        return 'ch${num.toString().padLeft(2, '0')}';
      }
    }

    // Try Chinese numeral
    final chineseNumMatch = RegExp(r'([一二三四五六七八九十]+)章').firstMatch(trimmed);
    if (chineseNumMatch != null) {
      final chineseNum = chineseNumMatch.group(1)!;
      final num = _chineseNumeralToInt(chineseNum);
      if (num != null) {
        return 'ch${num.toString().padLeft(2, '0')}';
      }
    }

    // Fallback: safe slug from label
    return 'ch-${_slugifyFilename(trimmed)}';
  }

  /// Convert Chinese numeral to int (simple version for 1-10).
  int? _chineseNumeralToInt(String chinese) {
    const map = {
      '一': 1,
      '二': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '七': 7,
      '八': 8,
      '九': 9,
      '十': 10,
    };
    return map[chinese];
  }

  /// Slugify text for safe filename usage.
  /// Preserves CJK characters, replaces unsafe chars with hyphens.
  String _slugifyFilename(String text) {
    if (text.isEmpty) {
      return 'unnamed';
    }

    final buffer = StringBuffer();

    // Allow: letters, digits, CJK range, hyphen, underscore
    for (final unit in text.codeUnits) {
      if ((unit >= 0x41 && unit <= 0x5A) || // A-Z
          (unit >= 0x61 && unit <= 0x7A) || // a-z
          (unit >= 0x30 && unit <= 0x39) || // 0-9
          (unit >= 0x4E00 && unit <= 0x9FFF) || // CJK Unified Ideographs
          (unit >= 0x3400 && unit <= 0x4DBF) || // CJK Extension A
          unit == 0x2D || // -
          unit == 0x5F) {
        // _
        buffer.writeCharCode(unit);
      } else {
        // Replace unsafe chars with single hyphen
        if (buffer.isNotEmpty && buffer.toString().endsWith('-')) {
          continue;
        }
        buffer.write('-');
      }
    }

    final result = buffer.toString().trim();
    // Remove trailing hyphens
    while (result.endsWith('-')) {
      return result.substring(0, result.length - 1);
    }

    return result.isEmpty ? 'unnamed' : result;
  }
}
