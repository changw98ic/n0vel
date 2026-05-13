import 'dart:convert';

import 'standard_format_models.dart';
export 'standard_format_models.dart';

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
      StandardExportFormat.html when resolvedMode.isManuscriptDelivery =>
        _exportManuscriptHtml(input),
      StandardExportFormat.html => _exportHtml(input),
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

    buf.writeln('## 章节');
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
    final wordCount = removeWhitespace(draft).length;

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
    final wordCount = removeWhitespace(draft).length;

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

    return [
      for (final line in input.draftText.split('\n'))
        ?markdownHeadingTitle(line),
    ];
  }

  bool _containsChapterHeading(String draft, String chapterTitle) {
    final normalizedTitle = chapterTitle.trim();
    if (normalizedTitle.isEmpty) {
      return true;
    }
    for (final line in draft.split('\n')) {
      if (lineMatchesChapterTitle(line, normalizedTitle)) {
        return true;
      }
    }
    return false;
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

  // ---------------------------------------------------------------------------
  // HTML
  // ---------------------------------------------------------------------------

  String _exportHtml(StandardExportInput input) {
    final buf = StringBuffer();
    buf.writeln('<!DOCTYPE html>');
    buf.writeln('<html lang="zh-CN">');
    buf.writeln('<head>');
    buf.writeln('<meta charset="UTF-8">');
    buf.writeln('<title>${_esc(input.project.title)}</title>');
    buf.writeln('<style>');
    buf.writeln(
      'body{font-family:system-ui,sans-serif;max-width:720px;'
      'margin:2rem auto;padding:0 1rem;color:#222;line-height:1.7}',
    );
    buf.writeln('h1{font-size:1.6rem}h2{font-size:1.3rem}h3{font-size:1.1rem}');
    buf.writeln('.meta{color:#666;font-size:.9rem;margin-bottom:2rem}');
    buf.writeln(
      'section{margin:1.5rem 0}hr{border:none;border-top:1px solid #ddd;margin:1.5rem 0}',
    );
    buf.writeln('</style>');
    buf.writeln('</head>');
    buf.writeln('<body>');
    buf.writeln('<h1>${_esc(input.project.title)}</h1>');
    if (input.project.genre.isNotEmpty || input.project.summary.isNotEmpty) {
      buf.writeln('<div class="meta">');
      if (input.project.genre.isNotEmpty) {
        buf.writeln('<p><strong>类型:</strong> ${_esc(input.project.genre)}</p>');
      }
      if (input.project.summary.isNotEmpty) {
        buf.writeln('<p>${_esc(input.project.summary)}</p>');
      }
      buf.writeln('</div>');
    }
    buf.writeln('<hr>');

    _writeOutlineHtml(buf, input);
    _writeCharactersHtml(buf, input);
    _writeWorldNodesHtml(buf, input);
    _writeScenesHtml(buf, input);
    _writeDraftHtml(buf, input);

    buf.writeln('</body>');
    buf.writeln('</html>');
    return buf.toString();
  }

  String _exportManuscriptHtml(StandardExportInput input) {
    final draft = input.draftText.trim();
    final chapters = _manuscriptChapters(input);
    final wordCount = removeWhitespace(draft).length;

    final buf = StringBuffer();
    buf.writeln('<!DOCTYPE html>');
    buf.writeln('<html lang="zh-CN">');
    buf.writeln('<head>');
    buf.writeln('<meta charset="UTF-8">');
    buf.writeln('<title>${_esc(input.project.title)}</title>');
    buf.writeln('<style>');
    buf.writeln(
      'body{font-family:system-ui,serif;max-width:640px;'
      'margin:2rem auto;padding:0 1rem;color:#222;line-height:1.8}',
    );
    buf.writeln('h1{font-size:1.6rem}h2{font-size:1.2rem}');
    buf.writeln('.info{color:#666;font-size:.85rem;margin-bottom:1.5rem}');
    buf.writeln('.toc{margin:1rem 0}ol{padding-left:1.5rem}');
    buf.writeln('</style>');
    buf.writeln('</head>');
    buf.writeln('<body>');
    buf.writeln('<h1>${_esc(input.project.title)}</h1>');
    buf.writeln('<div class="info">');
    if (input.project.genre.isNotEmpty) {
      buf.write('<strong>类型:</strong> ${_esc(input.project.genre)} · ');
    }
    buf.writeln('字数: $wordCount');
    buf.writeln('</div>');
    if (chapters.isNotEmpty) {
      buf.writeln('<h2>目录</h2>');
      buf.writeln('<ol class="toc">');
      for (final ch in chapters) {
        buf.writeln('<li>${_esc(ch)}</li>');
      }
      buf.writeln('</ol>');
    }
    if (draft.isNotEmpty) {
      buf.writeln('<h2>正文</h2>');
      for (final paragraph in splitParagraphs(draft)) {
        buf.writeln('<p>${_esc(paragraph)}</p>');
      }
    }
    buf.writeln('</body>');
    buf.writeln('</html>');
    return buf.toString();
  }

  void _writeOutlineHtml(StringBuffer buf, StandardExportInput input) {
    final outline = input.outline;
    if (outline == null || outline.chapters.isEmpty) return;

    buf.writeln('<section><h2>大纲</h2>');
    for (final chapter in outline.chapters) {
      buf.writeln('<h3>${_esc(chapter.title)}</h3>');
      if (chapter.summary.isNotEmpty) {
        buf.writeln('<p>${_esc(chapter.summary)}</p>');
      }
      buf.writeln('<ul>');
      for (final scene in chapter.scenes) {
        buf.writeln(
          '<li><strong>${_esc(scene.title)}</strong>: ${_esc(scene.summary)}</li>',
        );
      }
      buf.writeln('</ul>');
    }
    buf.writeln('</section>');
  }

  void _writeCharactersHtml(StringBuffer buf, StandardExportInput input) {
    if (input.characters.isEmpty) return;

    buf.writeln('<section><h2>角色</h2>');
    for (final c in input.characters) {
      buf.writeln('<h3>${_esc(c.name)}</h3>');
      if (c.role.isNotEmpty) {
        buf.writeln('<p><strong>角色:</strong> ${_esc(c.role)}</p>');
      }
      if (c.summary.isNotEmpty) {
        buf.writeln('<p>${_esc(c.summary)}</p>');
      }
      if (c.need.isNotEmpty) {
        buf.writeln('<p><strong>核心需求:</strong> ${_esc(c.need)}</p>');
      }
    }
    buf.writeln('</section>');
  }

  void _writeWorldNodesHtml(StringBuffer buf, StandardExportInput input) {
    if (input.worldNodes.isEmpty) return;

    buf.writeln('<section><h2>世界观</h2>');
    for (final node in input.worldNodes) {
      buf.writeln('<h3>${_esc(node.title)}</h3>');
      if (node.type.isNotEmpty) {
        buf.writeln('<p><strong>类型:</strong> ${_esc(node.type)}</p>');
      }
      if (node.summary.isNotEmpty) {
        buf.writeln('<p>${_esc(node.summary)}</p>');
      }
      if (node.ruleSummary.isNotEmpty) {
        buf.writeln('<p><strong>规则:</strong> ${_esc(node.ruleSummary)}</p>');
      }
      if (node.detail.isNotEmpty) {
        buf.writeln('<p>${_esc(node.detail)}</p>');
      }
    }
    buf.writeln('</section>');
  }

  void _writeScenesHtml(StringBuffer buf, StandardExportInput input) {
    if (input.scenes.isEmpty) return;

    buf.writeln('<section><h2>章节</h2><ul>');
    for (final scene in input.scenes) {
      buf.writeln('<li>${_esc(scene.displayLocation)}</li>');
    }
    buf.writeln('</ul></section>');
  }

  void _writeDraftHtml(StringBuffer buf, StandardExportInput input) {
    if (input.draftText.isEmpty) return;

    buf.writeln('<section><h2>正文</h2>');
    for (final paragraph in splitParagraphs(input.draftText)) {
      buf.writeln('<p>${_esc(paragraph)}</p>');
    }
    buf.writeln('</section>');
  }

  String _esc(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }
}
