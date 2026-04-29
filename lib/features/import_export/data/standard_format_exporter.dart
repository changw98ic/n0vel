import 'dart:convert';

import '../../../domain/workspace_models.dart';
import '../../../app/state/app_version_store.dart';
import '../../../app/state/story_outline_store.dart';

enum StandardExportFormat { markdown, plainText, json }

enum StandardExportMode { fullProject, manuscript, finalDraft }

extension StandardExportModeX on StandardExportMode {
  bool get isManuscriptDelivery =>
      this == StandardExportMode.manuscript ||
      this == StandardExportMode.finalDraft;
}

class StandardExportInput {
  const StandardExportInput({
    required this.project,
    required this.characters,
    required this.scenes,
    required this.worldNodes,
    this.draftText = '',
    this.versionEntries = const [],
    this.outline,
    this.mode = StandardExportMode.fullProject,
  });

  final ProjectRecord project;
  final List<CharacterRecord> characters;
  final List<SceneRecord> scenes;
  final List<WorldNodeRecord> worldNodes;
  final String draftText;
  final List<VersionEntry> versionEntries;
  final StoryOutlineSnapshot? outline;
  final StandardExportMode mode;
}

class StandardFormatExporter {
  String export(
    StandardExportInput input,
    StandardExportFormat format, {
    StandardExportMode? mode,
  }) {
    final resolvedMode = mode ?? input.mode;
    return switch (format) {
      StandardExportFormat.markdown when resolvedMode.isManuscriptDelivery =>
        _exportManuscriptMarkdown(input),
      StandardExportFormat.markdown => _exportMarkdown(input),
      StandardExportFormat.plainText when resolvedMode.isManuscriptDelivery =>
        _exportManuscriptPlainText(input),
      StandardExportFormat.plainText => _exportPlainText(input),
      StandardExportFormat.json => _exportJson(input),
    };
  }

  // ---------------------------------------------------------------------------
  // Markdown
  // ---------------------------------------------------------------------------

  String _exportMarkdown(StandardExportInput input) {
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

    _writeOutlineSection(buf, input);
    _writeCharactersSection(buf, input);
    _writeWorldNodesSection(buf, input);
    _writeScenesSection(buf, input);
    _writeDraftSection(buf, input);
    _writeVersionHistorySection(buf, input);

    return buf.toString();
  }

  void _writeOutlineSection(StringBuffer buf, StandardExportInput input) {
    final outline = input.outline;
    if (outline == null || outline.chapters.isEmpty) return;

    buf.writeln('## 大纲');
    buf.writeln();
    for (final chapter in outline.chapters) {
      buf.writeln('### ${chapter.title}');
      buf.writeln();
      if (chapter.summary.isNotEmpty) {
        buf.writeln(chapter.summary);
        buf.writeln();
      }
      for (final scene in chapter.scenes) {
        buf.writeln('- **${scene.title}**: ${scene.summary}');
        if (scene.cast.isNotEmpty) {
          buf.writeln(
            '  - 角色: ${scene.cast.map((c) => '${c.name}(${c.role})').join('、')}',
          );
        }
      }
      buf.writeln();
    }
  }

  void _writeCharactersSection(StringBuffer buf, StandardExportInput input) {
    if (input.characters.isEmpty) return;

    buf.writeln('## 角色');
    buf.writeln();
    for (final c in input.characters) {
      buf.writeln('### ${c.name}');
      if (c.role.isNotEmpty) {
        buf.writeln();
        buf.writeln('**角色**: ${c.role}');
      }
      if (c.summary.isNotEmpty) {
        buf.writeln();
        buf.writeln(c.summary);
      }
      if (c.need.isNotEmpty) {
        buf.writeln();
        buf.writeln('**核心需求**: ${c.need}');
      }
      if (c.note.isNotEmpty) {
        buf.writeln();
        buf.writeln('**备注**: ${c.note}');
      }
      buf.writeln();
    }
  }

  void _writeWorldNodesSection(StringBuffer buf, StandardExportInput input) {
    if (input.worldNodes.isEmpty) return;

    buf.writeln('## 世界观');
    buf.writeln();
    for (final node in input.worldNodes) {
      buf.writeln('### ${node.title}');
      if (node.type.isNotEmpty) {
        buf.writeln();
        buf.writeln('**类型**: ${node.type}');
      }
      if (node.location.isNotEmpty) {
        buf.writeln();
        buf.writeln('**位置**: ${node.location}');
      }
      if (node.summary.isNotEmpty) {
        buf.writeln();
        buf.writeln(node.summary);
      }
      if (node.ruleSummary.isNotEmpty) {
        buf.writeln();
        buf.writeln('**规则**: ${node.ruleSummary}');
      }
      if (node.detail.isNotEmpty) {
        buf.writeln();
        buf.writeln(node.detail);
      }
      buf.writeln();
    }
  }

  void _writeScenesSection(StringBuffer buf, StandardExportInput input) {
    if (input.scenes.isEmpty) return;

    buf.writeln('## 场景');
    buf.writeln();
    for (final scene in input.scenes) {
      buf.writeln('### ${scene.displayLocation}');
      if (scene.summary.isNotEmpty) {
        buf.writeln();
        buf.writeln(scene.summary);
      }
      buf.writeln();
    }
  }

  void _writeDraftSection(StringBuffer buf, StandardExportInput input) {
    if (input.draftText.isEmpty) return;

    buf.writeln('## 正文');
    buf.writeln();
    buf.writeln(input.draftText);
    buf.writeln();
  }

  void _writeVersionHistorySection(
    StringBuffer buf,
    StandardExportInput input,
  ) {
    if (input.versionEntries.isEmpty) return;

    buf.writeln('## 版本历史');
    buf.writeln();
    for (var i = 0; i < input.versionEntries.length; i++) {
      final entry = input.versionEntries[i];
      buf.writeln('${i + 1}. **${entry.label}**');
    }
    buf.writeln();
  }

  // ---------------------------------------------------------------------------
  // Plain Text
  // ---------------------------------------------------------------------------

  String _exportPlainText(StandardExportInput input) {
    final buf = StringBuffer();
    buf.writeln(input.project.title);
    buf.writeln();
    if (input.project.genre.isNotEmpty) {
      buf.writeln('[${input.project.genre}]');
      buf.writeln();
    }
    if (input.project.summary.isNotEmpty) {
      buf.writeln(input.project.summary);
      buf.writeln();
    }

    final outline = input.outline;
    if (outline != null && outline.chapters.isNotEmpty) {
      buf.writeln('========== 大纲 ==========');
      buf.writeln();
      for (final chapter in outline.chapters) {
        buf.writeln(chapter.title);
        if (chapter.summary.isNotEmpty) {
          buf.writeln('  ${chapter.summary}');
        }
        for (final scene in chapter.scenes) {
          buf.writeln('  - ${scene.title}: ${scene.summary}');
        }
        buf.writeln();
      }
    }

    if (input.draftText.isNotEmpty) {
      buf.writeln('========== 正文 ==========');
      buf.writeln();
      buf.writeln(input.draftText);
    }

    return buf.toString();
  }

  // ---------------------------------------------------------------------------
  // Manuscript / Final Draft
  // ---------------------------------------------------------------------------

  String _exportManuscriptMarkdown(StandardExportInput input) {
    final buf = StringBuffer();
    final draft = input.draftText.trim();
    final chapters = _manuscriptChapters(input);
    final wordCount = _countManuscriptWords(draft);

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

    buf.writeln('## 稿件信息');
    buf.writeln();
    buf.writeln('- 字数: $wordCount');
    if (chapters.isNotEmpty) {
      buf.writeln('- 章节数: ${chapters.length}');
    }
    buf.writeln();

    if (chapters.isNotEmpty) {
      buf.writeln('## 目录');
      buf.writeln();
      for (var i = 0; i < chapters.length; i++) {
        buf.writeln('${i + 1}. ${chapters[i]}');
      }
      buf.writeln();
    }

    if (draft.isNotEmpty) {
      buf.writeln('## 正文');
      buf.writeln();
      _writeManuscriptBodyMarkdown(buf, draft, chapters);
    }

    return buf.toString();
  }

  String _exportManuscriptPlainText(StandardExportInput input) {
    final buf = StringBuffer();
    final draft = input.draftText.trim();
    final chapters = _manuscriptChapters(input);
    final wordCount = _countManuscriptWords(draft);

    buf.writeln(input.project.title);
    buf.writeln();
    if (input.project.genre.isNotEmpty) {
      buf.writeln('[${input.project.genre}]');
      buf.writeln();
    }
    if (input.project.summary.isNotEmpty) {
      buf.writeln(input.project.summary);
      buf.writeln();
    }

    buf.writeln('========== 稿件信息 ==========');
    buf.writeln();
    buf.writeln('字数: $wordCount');
    if (chapters.isNotEmpty) {
      buf.writeln('章节数: ${chapters.length}');
    }
    buf.writeln();

    if (chapters.isNotEmpty) {
      buf.writeln('========== 目录 ==========');
      buf.writeln();
      for (var i = 0; i < chapters.length; i++) {
        buf.writeln('${i + 1}. ${chapters[i]}');
      }
      buf.writeln();
    }

    if (draft.isNotEmpty) {
      buf.writeln('========== 正文 ==========');
      buf.writeln();
      _writeManuscriptBodyPlainText(buf, draft, chapters);
    }

    return buf.toString();
  }

  void _writeManuscriptBodyMarkdown(
    StringBuffer buf,
    String draft,
    List<String> chapters,
  ) {
    if (chapters.length == 1 && !_containsChapterHeading(draft, chapters[0])) {
      buf.writeln('### ${chapters[0]}');
      buf.writeln();
    }
    buf.writeln(draft);
    buf.writeln();
  }

  void _writeManuscriptBodyPlainText(
    StringBuffer buf,
    String draft,
    List<String> chapters,
  ) {
    if (chapters.length == 1 && !_containsChapterHeading(draft, chapters[0])) {
      buf.writeln(chapters[0]);
      buf.writeln();
    }
    buf.writeln(draft);
  }

  List<String> _manuscriptChapters(StandardExportInput input) {
    final outline = input.outline;
    if (outline != null && outline.chapters.isNotEmpty) {
      return [
        for (final chapter in outline.chapters)
          if (chapter.title.trim().isNotEmpty) chapter.title.trim(),
      ];
    }

    final headingPattern = RegExp(r'^\s*#{1,3}\s+(.+?)\s*$', multiLine: true);
    return [
      for (final match in headingPattern.allMatches(input.draftText))
        if ((match.group(1) ?? '').trim().isNotEmpty)
          (match.group(1) ?? '').trim(),
    ];
  }

  bool _containsChapterHeading(String draft, String chapterTitle) {
    final normalizedTitle = chapterTitle.trim();
    if (normalizedTitle.isEmpty) return true;
    final escaped = RegExp.escape(normalizedTitle);
    return RegExp(
      r'^\s*(?:#{1,3}\s*)?' + escaped + r'\s*$',
      multiLine: true,
    ).hasMatch(draft);
  }

  int _countManuscriptWords(String draft) {
    return draft.replaceAll(RegExp(r'\s+'), '').length;
  }

  // ---------------------------------------------------------------------------
  // JSON
  // ---------------------------------------------------------------------------

  String _exportJson(StandardExportInput input) {
    final data = <String, Object?>{
      'project': input.project.toJson(),
      'characters': [for (final c in input.characters) c.toJson()],
      'scenes': [for (final s in input.scenes) s.toJson()],
      'worldNodes': [for (final n in input.worldNodes) n.toJson()],
      'draft': input.draftText,
      'versions': [for (final v in input.versionEntries) v.toJson()],
      if (input.outline != null) 'outline': input.outline!.toJson(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }
}
