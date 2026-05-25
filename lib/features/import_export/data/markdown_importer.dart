import 'dart:convert';
import 'dart:io';

import '../../../domain/workspace_models.dart' as domain;

enum ImportTargetKind { project, scene, character, worldNode, draft }

enum ImportState {
  safeApply,
  needsReview,
  conflictKeepBoth,
  unsupported,
  rejected,
}

class MarkdownImportIssue {
  const MarkdownImportIssue({
    required this.code,
    required this.message,
    this.filePath,
    this.blocking = false,
  });

  final String code;
  final String message;
  final String? filePath;
  final bool blocking;
}

typedef ImportIssue = MarkdownImportIssue;

class ImportEntry {
  const ImportEntry({
    required this.id,
    required this.kind,
    required this.state,
    required this.parsedData,
    this.reason,
    this.filePath,
  });

  final String id;
  final ImportTargetKind kind;
  final ImportState state;
  final String? reason;
  final String? filePath;
  final Map<String, Object?> parsedData;

  ImportEntry copyWith({
    ImportState? state,
    String? reason,
    Map<String, Object?>? parsedData,
  }) {
    return ImportEntry(
      id: id,
      kind: kind,
      state: state ?? this.state,
      reason: reason ?? this.reason,
      filePath: filePath,
      parsedData: parsedData ?? this.parsedData,
    );
  }
}

class MarkdownImportPlan {
  const MarkdownImportPlan({required this.entries, required this.issues});

  final List<ImportEntry> entries;
  final List<MarkdownImportIssue> issues;

  List<MarkdownImportIssue> get blockingIssues =>
      issues.where((issue) => issue.blocking).toList(growable: false);

  List<MarkdownImportIssue> get warnings =>
      issues.where((issue) => !issue.blocking).toList(growable: false);

  bool get hasBlockingIssues => blockingIssues.isNotEmpty;

  ImportEntry? entryFor(ImportTargetKind kind, String id) {
    for (final entry in entries) {
      if (entry.kind == kind && entry.id == id) {
        return entry;
      }
    }
    return null;
  }
}

class MarkdownImportResult {
  const MarkdownImportResult({
    required this.plan,
    this.project,
    this.scenes = const [],
    this.characters = const [],
    this.worldNodes = const [],
    this.draftText = '',
  });

  final MarkdownImportPlan plan;
  final domain.ProjectRecord? project;
  final List<domain.SceneRecord> scenes;
  final List<domain.CharacterRecord> characters;
  final List<domain.WorldNodeRecord> worldNodes;
  final String draftText;

  bool get isValid => project != null && !plan.hasBlockingIssues;
}

class MarkdownImporter {
  Future<MarkdownImportResult> importProject(Directory root) async {
    final projectJson = File('${root.path}/project.n0vel.json');
    if (!await projectJson.exists()) {
      return const MarkdownImportResult(
        plan: MarkdownImportPlan(
          entries: [],
          issues: [
            MarkdownImportIssue(
              code: 'missing_project_json',
              message: 'project.n0vel.json is required for Markdown import.',
              blocking: true,
            ),
          ],
        ),
      );
    }

    final issues = <MarkdownImportIssue>[];
    final entries = <ImportEntry>[];
    final base = await _loadProjectJson(projectJson, issues);
    if (base == null) {
      return MarkdownImportResult(
        plan: MarkdownImportPlan(entries: entries, issues: issues),
      );
    }

    final baseScenes = {for (final scene in base.scenes) scene.id: scene};
    final baseCharacters = {
      for (final character in base.characters) character.id: character,
    };
    final baseWorldNodes = {for (final node in base.worldNodes) node.id: node};

    entries.add(
      ImportEntry(
        id: base.project.id,
        kind: ImportTargetKind.project,
        state: ImportState.safeApply,
        filePath: 'project.n0vel.json',
        parsedData: base.project.toJson(),
      ),
    );
    if (base.draftText.isNotEmpty) {
      entries.add(
        ImportEntry(
          id: '${base.project.id}:draft',
          kind: ImportTargetKind.draft,
          state: ImportState.safeApply,
          filePath: 'project.n0vel.json',
          parsedData: {'draft': base.draftText},
        ),
      );
    }

    final scenes = await _scanScenes(root, baseScenes, entries, issues);
    final characters = await _scanCharacters(
      root,
      baseCharacters,
      entries,
      issues,
    );
    final worldNodes = await _scanWorldNodes(
      root,
      baseWorldNodes,
      entries,
      issues,
    );

    _markDuplicateIds(entries, issues);

    return MarkdownImportResult(
      project: base.project,
      scenes: List<domain.SceneRecord>.unmodifiable(scenes),
      characters: List<domain.CharacterRecord>.unmodifiable(characters),
      worldNodes: List<domain.WorldNodeRecord>.unmodifiable(worldNodes),
      draftText: base.draftText,
      plan: MarkdownImportPlan(
        entries: List<ImportEntry>.unmodifiable(entries),
        issues: List<MarkdownImportIssue>.unmodifiable(issues),
      ),
    );
  }

  Future<_ProjectJsonPayload?> _loadProjectJson(
    File file,
    List<MarkdownImportIssue> issues,
  ) async {
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) {
        issues.add(
          const MarkdownImportIssue(
            code: 'invalid_project_json',
            message: 'project.n0vel.json must contain a JSON object.',
            filePath: 'project.n0vel.json',
            blocking: true,
          ),
        );
        return null;
      }
      final data = _asStringObjectMap(decoded);
      final rawProject = data['project'];
      if (rawProject is! Map) {
        issues.add(
          const MarkdownImportIssue(
            code: 'missing_project_record',
            message: 'project.n0vel.json is missing the project object.',
            filePath: 'project.n0vel.json',
            blocking: true,
          ),
        );
        return null;
      }
      return _ProjectJsonPayload(
        project: domain.ProjectRecord.fromJson(_asObjectMap(rawProject)),
        scenes: [
          for (final raw in _asList(data['scenes']))
            if (raw is Map) domain.SceneRecord.fromJson(_asObjectMap(raw)),
        ],
        characters: [
          for (final raw in _asList(data['characters']))
            if (raw is Map) domain.CharacterRecord.fromJson(_asObjectMap(raw)),
        ],
        worldNodes: [
          for (final raw in _asList(data['worldNodes']))
            if (raw is Map) domain.WorldNodeRecord.fromJson(_asObjectMap(raw)),
        ],
        draftText: data['draft']?.toString() ?? '',
      );
    } on Object catch (error) {
      issues.add(
        MarkdownImportIssue(
          code: 'invalid_project_json',
          message: 'Could not parse project.n0vel.json: $error',
          filePath: 'project.n0vel.json',
          blocking: true,
        ),
      );
      return null;
    }
  }

  Future<List<domain.SceneRecord>> _scanScenes(
    Directory root,
    Map<String, domain.SceneRecord> baseScenes,
    List<ImportEntry> entries,
    List<MarkdownImportIssue> issues,
  ) async {
    final chaptersDir = Directory('${root.path}/chapters');
    if (!await chaptersDir.exists()) {
      return [];
    }
    final files = await _listMarkdownFiles(chaptersDir);
    final scenes = <domain.SceneRecord>[];
    for (final file in files) {
      final relativePath = _relativePath(root, file);
      final parsed = await _parseMarkdownFile(file, relativePath, issues);
      if (parsed == null) {
        entries.add(_unsupportedEntry(ImportTargetKind.scene, relativePath));
        continue;
      }
      final id = _requiredIdOrProvisional(
        parsed,
        relativePath,
        prefix: 'scene',
      );
      final title = parsed.heading.isEmpty
          ? baseScenes[id]?.title ?? '等待命名'
          : parsed.heading;
      final frontmatterChapter = parsed.frontmatter['chapter']?.trim() ?? '';
      if (frontmatterChapter.isEmpty && parsed.hasFrontmatter) {
        parsed.issueReason ??= 'missing_required_chapter';
      }
      final chapterLabel = frontmatterChapter.isNotEmpty
          ? frontmatterChapter
          : _chapterLabelFromPath(relativePath);
      final scene = domain.SceneRecord(
        id: id,
        chapterLabel: chapterLabel,
        title: title,
        summary: parsed.section('摘要').trim(),
      );
      scenes.add(scene);
      entries.add(
        _entryForRecord(
          id: id,
          kind: ImportTargetKind.scene,
          filePath: relativePath,
          parsedData: scene.toJson(),
          baseData: baseScenes[id]?.toJson(),
          parseIssueReason: parsed.issueReason,
        ),
      );
    }
    return scenes;
  }

  Future<List<domain.CharacterRecord>> _scanCharacters(
    Directory root,
    Map<String, domain.CharacterRecord> baseCharacters,
    List<ImportEntry> entries,
    List<MarkdownImportIssue> issues,
  ) async {
    final charactersDir = Directory('${root.path}/bible/characters');
    if (!await charactersDir.exists()) {
      return [];
    }
    final files = await _listMarkdownFiles(charactersDir);
    final characters = <domain.CharacterRecord>[];
    for (final file in files) {
      final relativePath = _relativePath(root, file);
      final parsed = await _parseMarkdownFile(file, relativePath, issues);
      if (parsed == null) {
        entries.add(
          _unsupportedEntry(ImportTargetKind.character, relativePath),
        );
        continue;
      }
      final id = _requiredIdOrProvisional(
        parsed,
        relativePath,
        prefix: 'character',
      );
      final base = baseCharacters[id];
      final character = domain.CharacterRecord(
        id: id,
        name: parsed.heading.isEmpty ? base?.name ?? '新角色' : parsed.heading,
        role: parsed.frontmatter['role'] ?? _boldValue(parsed.body, '角色'),
        summary: parsed.section('简介').trim(),
        need: parsed.section('核心需求').trim(),
        note: parsed.section('备注').trim(),
        referenceSummary: base?.referenceSummary ?? '',
        linkedSceneIds: base?.linkedSceneIds ?? const [],
      );
      characters.add(character);
      entries.add(
        _entryForRecord(
          id: id,
          kind: ImportTargetKind.character,
          filePath: relativePath,
          parsedData: character.toJson(),
          baseData: base?.toJson(),
          parseIssueReason: parsed.issueReason,
        ),
      );
    }
    return characters;
  }

  Future<List<domain.WorldNodeRecord>> _scanWorldNodes(
    Directory root,
    Map<String, domain.WorldNodeRecord> baseWorldNodes,
    List<ImportEntry> entries,
    List<MarkdownImportIssue> issues,
  ) async {
    final worldDir = Directory('${root.path}/bible/world');
    if (!await worldDir.exists()) {
      return [];
    }
    final files = await _listMarkdownFiles(worldDir);
    final nodes = <domain.WorldNodeRecord>[];
    for (final file in files) {
      final relativePath = _relativePath(root, file);
      final parsed = await _parseMarkdownFile(file, relativePath, issues);
      if (parsed == null) {
        entries.add(
          _unsupportedEntry(ImportTargetKind.worldNode, relativePath),
        );
        continue;
      }
      final id = _requiredIdOrProvisional(
        parsed,
        relativePath,
        prefix: 'world',
      );
      final base = baseWorldNodes[id];
      final node = domain.WorldNodeRecord(
        id: id,
        title: parsed.heading.isEmpty ? base?.title ?? '新节点' : parsed.heading,
        type: parsed.frontmatter['type'] ?? _boldValue(parsed.body, '类型'),
        location:
            parsed.frontmatter['location'] ?? _boldValue(parsed.body, '位置'),
        summary: parsed.section('概要').trim(),
        ruleSummary: parsed.section('规则').trim(),
        detail: parsed.section('详情').trim(),
        referenceSummary: base?.referenceSummary ?? '',
        linkedSceneIds: base?.linkedSceneIds ?? const [],
      );
      nodes.add(node);
      entries.add(
        _entryForRecord(
          id: id,
          kind: ImportTargetKind.worldNode,
          filePath: relativePath,
          parsedData: node.toJson(),
          baseData: base?.toJson(),
          parseIssueReason: parsed.issueReason,
        ),
      );
    }
    return nodes;
  }

  ImportEntry _entryForRecord({
    required String id,
    required ImportTargetKind kind,
    required String filePath,
    required Map<String, Object?> parsedData,
    required Map<String, Object?>? baseData,
    required String? parseIssueReason,
  }) {
    if (parseIssueReason != null) {
      return ImportEntry(
        id: id,
        kind: kind,
        state: ImportState.needsReview,
        reason: parseIssueReason,
        filePath: filePath,
        parsedData: parsedData,
      );
    }
    if (baseData == null) {
      return ImportEntry(
        id: id,
        kind: kind,
        state: ImportState.needsReview,
        reason: 'added',
        filePath: filePath,
        parsedData: parsedData,
      );
    }
    final state = _canonicalJson(baseData) == _canonicalJson(parsedData)
        ? ImportState.safeApply
        : ImportState.needsReview;
    return ImportEntry(
      id: id,
      kind: kind,
      state: state,
      reason: state == ImportState.needsReview ? 'fingerprint_mismatch' : null,
      filePath: filePath,
      parsedData: parsedData,
    );
  }

  ImportEntry _unsupportedEntry(ImportTargetKind kind, String filePath) {
    return ImportEntry(
      id: 'unsupported:$filePath',
      kind: kind,
      state: ImportState.unsupported,
      reason: 'unsupported',
      filePath: filePath,
      parsedData: const {},
    );
  }

  void _markDuplicateIds(
    List<ImportEntry> entries,
    List<MarkdownImportIssue> issues,
  ) {
    final indexesByKey = <String, List<int>>{};
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (entry.state == ImportState.unsupported ||
          entry.parsedData['deleted'] == true) {
        continue;
      }
      indexesByKey
          .putIfAbsent('${entry.kind.name}:${entry.id}', () => <int>[])
          .add(i);
    }
    for (final duplicate in indexesByKey.entries) {
      if (duplicate.value.length < 2) {
        continue;
      }
      for (final index in duplicate.value) {
        entries[index] = entries[index].copyWith(
          state: ImportState.conflictKeepBoth,
          reason: 'duplicate_id',
        );
      }
      issues.add(
        MarkdownImportIssue(
          code: 'duplicate_id',
          message: 'Multiple Markdown files claim ${duplicate.key}.',
        ),
      );
    }
  }

  Future<List<File>> _listMarkdownFiles(Directory directory) async {
    final files = <File>[];
    await for (final entity in directory.list(recursive: true)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.md')) {
        files.add(entity);
      }
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  Future<_ParsedMarkdown?> _parseMarkdownFile(
    File file,
    String relativePath,
    List<MarkdownImportIssue> issues,
  ) async {
    try {
      var content = await file.readAsString();
      if (content.startsWith('\uFEFF')) {
        content = content.substring(1);
      }
      content = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
      return _ParsedMarkdown.parse(content, relativePath);
    } on Object catch (error) {
      issues.add(
        MarkdownImportIssue(
          code: 'unsupported_file',
          message: 'Could not read $relativePath: $error',
          filePath: relativePath,
        ),
      );
      return null;
    }
  }

  String _requiredIdOrProvisional(
    _ParsedMarkdown parsed,
    String relativePath, {
    required String prefix,
  }) {
    final id = parsed.frontmatter['id']?.trim() ?? '';
    if (id.isNotEmpty) {
      return id;
    }
    parsed.issueReason ??= parsed.hasFrontmatter
        ? 'missing_required_id'
        : 'missing_frontmatter';
    return '$prefix-provisional-${_stablePathSlug(relativePath)}';
  }

  String _chapterLabelFromPath(String relativePath) {
    final parts = relativePath.split('/');
    if (parts.length >= 3) {
      final chapterDir = parts[1];
      final match = RegExp(r'^ch(\d+)$').firstMatch(chapterDir);
      if (match != null) {
        final number = int.tryParse(match.group(1) ?? '');
        if (number != null) {
          return '第 $number 章';
        }
      }
      return chapterDir;
    }
    return '第 1 章 / 场景 01';
  }

  String _relativePath(Directory root, File file) {
    final rootPath = root.absolute.path.endsWith(Platform.pathSeparator)
        ? root.absolute.path
        : '${root.absolute.path}${Platform.pathSeparator}';
    final filePath = file.absolute.path;
    if (!filePath.startsWith(rootPath)) {
      return file.uri.pathSegments.last;
    }
    return filePath
        .substring(rootPath.length)
        .split(Platform.pathSeparator)
        .join('/');
  }

  String _stablePathSlug(String path) {
    return path
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '')
        .toLowerCase();
  }
}

class _ParsedMarkdown {
  _ParsedMarkdown({
    required this.frontmatter,
    required this.body,
    required this.hasFrontmatter,
    this.issueReason,
  });

  final Map<String, String> frontmatter;
  final String body;
  final bool hasFrontmatter;
  String? issueReason;

  String get heading {
    for (final line in body.split('\n')) {
      if (line.startsWith('# ') && !line.startsWith('## ')) {
        return line.substring(2).trim();
      }
    }
    return '';
  }

  String section(String title) {
    final lines = body.split('\n');
    final buffer = StringBuffer();
    var collecting = false;
    for (final line in lines) {
      if (line.startsWith('## ')) {
        final currentTitle = line.substring(3).trim();
        if (collecting) {
          break;
        }
        collecting = currentTitle == title;
        continue;
      }
      if (collecting) {
        buffer.writeln(line);
      }
    }
    return buffer.toString().trim();
  }

  static _ParsedMarkdown parse(String content, String relativePath) {
    final lines = content.split('\n');
    if (lines.isEmpty || lines.first.trim() != '---') {
      return _ParsedMarkdown(
        frontmatter: const {},
        body: content.trim(),
        hasFrontmatter: false,
        issueReason: 'missing_frontmatter',
      );
    }
    var closingIndex = -1;
    for (var i = 1; i < lines.length; i++) {
      if (lines[i].trim() == '---') {
        closingIndex = i;
        break;
      }
    }
    if (closingIndex == -1) {
      return _ParsedMarkdown(
        frontmatter: const {},
        body: content.trim(),
        hasFrontmatter: false,
        issueReason: 'missing_frontmatter',
      );
    }
    final frontmatter = <String, String>{};
    for (var i = 1; i < closingIndex; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        continue;
      }
      final colonIndex = line.indexOf(':');
      if (colonIndex <= 0) {
        return _ParsedMarkdown(
          frontmatter: const {},
          body: lines.sublist(closingIndex + 1).join('\n').trim(),
          hasFrontmatter: true,
          issueReason: 'malformed_frontmatter',
        );
      }
      frontmatter[line.substring(0, colonIndex).trim()] = line
          .substring(colonIndex + 1)
          .trim();
    }
    return _ParsedMarkdown(
      frontmatter: Map<String, String>.unmodifiable(frontmatter),
      body: lines.sublist(closingIndex + 1).join('\n').trim(),
      hasFrontmatter: true,
    );
  }
}

class _ProjectJsonPayload {
  const _ProjectJsonPayload({
    required this.project,
    required this.scenes,
    required this.characters,
    required this.worldNodes,
    required this.draftText,
  });

  final domain.ProjectRecord project;
  final List<domain.SceneRecord> scenes;
  final List<domain.CharacterRecord> characters;
  final List<domain.WorldNodeRecord> worldNodes;
  final String draftText;
}

Map<String, Object?> _asStringObjectMap(Object? value) {
  if (value is Map) {
    return {
      for (final entry in value.entries) entry.key.toString(): entry.value,
    };
  }
  return const {};
}

Map<Object?, Object?> _asObjectMap(Object? value) {
  if (value is Map) {
    return {for (final entry in value.entries) entry.key: entry.value};
  }
  return const {};
}

List<Object?> _asList(Object? value) {
  if (value is List) {
    return value;
  }
  return const [];
}

String _boldValue(String body, String label) {
  final pattern = RegExp(r'\*\*' + RegExp.escape(label) + r'\*\*:\s*(.+)');
  final match = pattern.firstMatch(body);
  return match?.group(1)?.trim() ?? '';
}

String _canonicalJson(Map<String, Object?> value) {
  return jsonEncode(_sortJson(value));
}

Object? _sortJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return {for (final key in keys) key: _sortJson(value[key])};
  }
  if (value is List) {
    return [for (final item in value) _sortJson(item)];
  }
  return value;
}
