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
      title: '项目 Brief',
      kind: StoryBibleSectionKind.fact,
      entries: [
        StoryBibleEntry(
          title: project.title,
          meta: _joinNonEmpty([project.genre, project.recentLocation]),
          body: _fallback(project.summary, '当前项目还没有 brief 摘要。'),
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
      title: '生成状态占位',
      kind: StoryBibleSectionKind.status,
      entries: [
        StoryBibleEntry(
          title: '章节生成',
          meta: '未推断',
          body: '这里只声明 Story Bible 已聚合的素材；不会把缺失的生成流水线状态伪装成已完成。',
        ),
        StoryBibleEntry(
          title: '伏笔 / 连续性',
          meta: '未接入',
          body: '当前版本不提供完整伏笔系统，只保留后续接入点。',
        ),
      ],
    );
  }

  StoryBibleSection _reviewStatus(List<AuditIssueRecord> auditIssues) {
    final openCount = auditIssues.where((issue) => issue.isOpen).length;
    final closedCount = auditIssues.length - openCount;
    return StoryBibleSection(
      title: '审稿状态占位',
      kind: StoryBibleSectionKind.status,
      entries: [
        StoryBibleEntry(
          title: '审计中心问题',
          meta: '开放 $openCount / 已处理 $closedCount',
          body: '展示已有审计问题数量；不额外生成未存在的审稿结论。',
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
