import '../../../app/state/story_outline_store.dart';
import '../../../app/state/workspace_types.dart';

enum StoryBibleSectionKind { fact, status }

class StoryBibleEntry {
  const StoryBibleEntry({
    required this.title,
    required this.body,
    this.meta = '',
  });

  final String title;
  final String body;
  final String meta;
}

class StoryBibleSection {
  const StoryBibleSection({
    required this.title,
    required this.kind,
    this.entries = const [],
    this.emptyMessage = '',
  });

  final String title;
  final StoryBibleSectionKind kind;
  final List<StoryBibleEntry> entries;
  final String emptyMessage;

  bool get isEmpty => entries.isEmpty;
}

class StoryBibleSnapshot {
  const StoryBibleSnapshot({
    required this.projectTitle,
    required this.factSections,
    required this.statusSections,
  });

  final String projectTitle;
  final List<StoryBibleSection> factSections;
  final List<StoryBibleSection> statusSections;

  int get factCount => factSections.fold<int>(
    0,
    (total, section) => total + section.entries.length,
  );
}

class StoryBibleAggregator {
  const StoryBibleAggregator();

  StoryBibleSnapshot build({
    required ProjectRecord project,
    required List<CharacterRecord> characters,
    required List<WorldNodeRecord> worldNodes,
    required List<SceneRecord> scenes,
    required List<AuditIssueRecord> auditIssues,
    StoryOutlineSnapshot? outline,
  }) {
    return StoryBibleSnapshot(
      projectTitle: project.title,
      factSections: [
        _projectBrief(project),
        _characters(characters),
        _worldNodes(worldNodes),
        _scenes(scenes),
        _outline(outline),
      ],
      statusSections: [_generationStatus(), _reviewStatus(auditIssues)],
    );
  }

  StoryBibleSection _projectBrief(ProjectRecord project) {
    return StoryBibleSection(
      title: '作品简介',
      kind: StoryBibleSectionKind.fact,
      entries: [
        StoryBibleEntry(
          title: project.title,
          meta: _joinNonEmpty([project.genre, project.recentLocation]),
          body: _fallback(project.summary, '当前项目还没有作品简介。'),
        ),
      ],
    );
  }

  StoryBibleSection _characters(List<CharacterRecord> characters) {
    return StoryBibleSection(
      title: '角色设定事实',
      kind: StoryBibleSectionKind.fact,
      emptyMessage: '当前项目还没有角色记录。',
      entries: [
        for (final character in characters)
          StoryBibleEntry(
            title: character.name,
            meta: _joinNonEmpty([character.role, character.need]),
            body: _joinNonEmpty([
              character.summary,
              character.note,
              character.referenceSummary,
            ], separator: '\n'),
          ),
      ],
    );
  }

  StoryBibleSection _worldNodes(List<WorldNodeRecord> nodes) {
    return StoryBibleSection(
      title: '世界观设定事实',
      kind: StoryBibleSectionKind.fact,
      emptyMessage: '当前项目还没有世界观节点。',
      entries: [
        for (final node in nodes)
          StoryBibleEntry(
            title: node.title,
            meta: _joinNonEmpty([node.type, node.location]),
            body: _joinNonEmpty([
              node.summary,
              node.detail,
              node.ruleSummary,
              node.referenceSummary,
            ], separator: '\n'),
          ),
      ],
    );
  }

  StoryBibleSection _scenes(List<SceneRecord> scenes) {
    return StoryBibleSection(
      title: '场景 / 章节摘要',
      kind: StoryBibleSectionKind.fact,
      emptyMessage: '当前项目还没有场景摘要。',
      entries: [
        for (final scene in scenes)
          StoryBibleEntry(
            title: scene.title,
            meta: scene.chapterLabel,
            body: _fallback(scene.summary, '等待补充场景摘要。'),
          ),
      ],
    );
  }

  StoryBibleSection _outline(StoryOutlineSnapshot? outline) {
    final chapters = outline?.chapters ?? const <StoryOutlineChapterSnapshot>[];
    final executableChapters = outline?.executablePlan?.chapters ?? const [];
    final entries = <StoryBibleEntry>[
      for (final chapter in chapters)
        StoryBibleEntry(
          title: chapter.title,
          meta: '${chapter.scenes.length} 个场景',
          body: _chapterBody(chapter.summary, [
            for (final scene in chapter.scenes)
              _joinNonEmpty([scene.title, scene.summary], separator: '：'),
          ]),
        ),
      if (chapters.isEmpty)
        for (final chapter in executableChapters)
          StoryBibleEntry(
            title: chapter.title,
            meta: '${chapter.scenes.length} 个计划场景',
            body: _chapterBody(chapter.summary, [
              for (final scene in chapter.scenes)
                _joinNonEmpty([scene.title, scene.summary], separator: '：'),
            ]),
          ),
    ];
    return StoryBibleSection(
      title: '大纲摘要',
      kind: StoryBibleSectionKind.fact,
      emptyMessage: '当前项目还没有可聚合的大纲快照。',
      entries: entries,
    );
  }

  StoryBibleSection _generationStatus() {
    return const StoryBibleSection(
      title: '写作进度',
      kind: StoryBibleSectionKind.status,
      entries: [
        StoryBibleEntry(
          title: '章节生成',
          meta: '还没有生成记录',
          body: '这里汇总作品已经整理好的素材；没有生成过的章节不会被标成已完成。',
        ),
        StoryBibleEntry(
          title: '伏笔 / 连续性',
          meta: '暂未开启',
          body: '当前版本还不能自动检查伏笔和连续性，你可以先用大纲和场景摘要人工核对。',
        ),
      ],
    );
  }

  StoryBibleSection _reviewStatus(List<AuditIssueRecord> auditIssues) {
    final openCount = auditIssues.where((issue) => issue.isOpen).length;
    final closedCount = auditIssues.length - openCount;
    return StoryBibleSection(
      title: '问题检查',
      kind: StoryBibleSectionKind.status,
      entries: [
        StoryBibleEntry(
          title: '待处理问题',
          meta: '待处理 $openCount / 已处理 $closedCount',
          body: '这里只显示已经发现的问题数量，不会凭空生成审稿结论。',
        ),
      ],
    );
  }

  String _chapterBody(String summary, List<String> sceneLines) {
    return _joinNonEmpty([
      _fallback(summary, ''),
      ...sceneLines,
    ], separator: '\n');
  }

  String _fallback(String value, String fallback) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  String _joinNonEmpty(List<String> values, {String separator = ' · '}) {
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join(separator);
  }
}
