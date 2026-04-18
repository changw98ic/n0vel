import '../../features/work/data/work_repository.dart';
import '../../features/work/data/volume_repository.dart';
import '../../features/editor/data/chapter_repository.dart';
import '../../features/settings/data/character_repository.dart';
import '../../features/settings/data/relationship_repository.dart';
import '../../features/inspiration/data/inspiration_repository.dart';
import 'ai/context/context_manager.dart';
import 'writer_guidance_loader.dart';

class PersistedNovelSnapshot {
  final String workId;
  final String content;

  const PersistedNovelSnapshot({required this.workId, required this.content});

  bool get hasContent => content.trim().isNotEmpty;
}

class StructuredChatContext {
  final String systemPrompt;
  final String userPrompt;
  final String userRequirements;
  final String persistedData;
  final String unsavedData;
  final List<ChatMessage> history;

  const StructuredChatContext({
    required this.systemPrompt,
    required this.userPrompt,
    required this.userRequirements,
    required this.persistedData,
    required this.unsavedData,
    required this.history,
  });
}

class PersistedNovelSnapshotLoader {
  final WorkRepository _workRepository;
  final VolumeRepository _volumeRepository;
  final ChapterRepository _chapterRepository;
  final CharacterRepository _characterRepository;
  final RelationshipRepository _relationshipRepository;
  final InspirationRepository _inspirationRepository;

  PersistedNovelSnapshotLoader({
    required WorkRepository workRepository,
    required VolumeRepository volumeRepository,
    required ChapterRepository chapterRepository,
    required CharacterRepository characterRepository,
    required RelationshipRepository relationshipRepository,
    required InspirationRepository inspirationRepository,
  }) : _workRepository = workRepository,
       _volumeRepository = volumeRepository,
       _chapterRepository = chapterRepository,
       _characterRepository = characterRepository,
       _relationshipRepository = relationshipRepository,
       _inspirationRepository = inspirationRepository;

  Future<PersistedNovelSnapshot?> load(String workId) async {
    if (workId.trim().isEmpty) return null;

    final results = await Future.wait<dynamic>([
      _workRepository.getWorkById(workId),
      _volumeRepository.getVolumesByWorkId(workId),
      _chapterRepository.getChaptersByWorkId(workId),
      _characterRepository.getCharactersByWorkId(workId),
      _relationshipRepository.getRelationshipsByWorkId(workId),
      _inspirationRepository.getByWorkId(workId),
    ]);

    final work = results[0];
    final volumes = results[1] as List<dynamic>;
    final chapters = results[2] as List<dynamic>;
    final characters = results[3] as List<dynamic>;
    final relationships = results[4] as List<dynamic>;
    final inspirations = results[5] as List<dynamic>;

    if (work == null) return null;

    final buffer = StringBuffer();
    buffer.writeln('## 作品已存数据');
    buffer.writeln('作品名: ${work.name}');
    if (work.type != null && work.type.toString().isNotEmpty) {
      buffer.writeln('题材: ${work.type}');
    }
    if (work.description != null && work.description.toString().isNotEmpty) {
      buffer.writeln('简介: ${_clip(work.description.toString(), 500)}');
    }
    buffer.writeln('当前字数: ${work.currentWords}');
    if (work.targetWords != null) {
      buffer.writeln('目标字数: ${work.targetWords}');
    }
    buffer.writeln();

    if (volumes.isNotEmpty) {
      buffer.writeln('### 卷列表');
      for (final volume in volumes.take(10)) {
        buffer.writeln('- ${volume.name} (sort=${volume.sortOrder})');
      }
      buffer.writeln();
    }

    if (chapters.isNotEmpty) {
      buffer.writeln('### 已存章节');
      for (final chapter in chapters.take(12)) {
        final content = (chapter.content ?? '').toString().trim();
        final excerpt = content.isEmpty ? '' : _clip(content, 200);
        buffer.writeln(
          '- ${chapter.title} | 字数=${chapter.wordCount}${excerpt.isNotEmpty ? " | 摘要=$excerpt" : ""}',
        );
      }
      buffer.writeln();
    }

    if (characters.isNotEmpty) {
      buffer.writeln('### 已存角色');
      for (final character in characters.take(20)) {
        final bio = character.bio?.toString().trim() ?? '';
        buffer.writeln(
          '- ${character.name} | ${_enumText(character.tier)}${bio.isNotEmpty ? " | ${_clip(bio, 120)}" : ""}',
        );
      }
      buffer.writeln();
    }

    // 构建 ID→名字 映射，用于关系显示
    final charNameMap = <String, String>{};
    for (final c in characters) {
      charNameMap[c.id] = c.name;
    }

    if (relationships.isNotEmpty) {
      buffer.writeln('### 已存关系');
      for (final relationship in relationships.take(20)) {
        final nameA = charNameMap[relationship.characterAId] ?? relationship.characterAId.substring(0, 8);
        final nameB = charNameMap[relationship.characterBId] ?? relationship.characterBId.substring(0, 8);
        buffer.writeln(
          '- $nameA <-> $nameB | ${_enumText(relationship.relationType)}',
        );
      }
      buffer.writeln();
    }

    if (inspirations.isNotEmpty) {
      buffer.writeln('### 已存素材');
      for (final inspiration in inspirations.take(20)) {
        buffer.writeln(
          '- [${inspiration.category}] ${inspiration.title} | ${_clip(inspiration.content, 120)}',
        );
      }
    }

    return PersistedNovelSnapshot(workId: workId, content: buffer.toString());
  }

  String _enumText(dynamic value) {
    if (value == null) return '';
    try {
      final label = value.label;
      if (label is String && label.isNotEmpty) {
        return label;
      }
    } catch (_) {}
    try {
      final name = value.name;
      if (name is String && name.isNotEmpty) {
        return name;
      }
    } catch (_) {}
    return value.toString();
  }
}

class ChatContextBuilder {
  final ContextManager _contextManager;
  final PersistedNovelSnapshotLoader _snapshotLoader;
  final WriterGuidanceLoader _guidanceLoader;

  ChatContextBuilder({
    required ContextManager contextManager,
    required PersistedNovelSnapshotLoader snapshotLoader,
    WriterGuidanceLoader? guidanceLoader,
  }) : _contextManager = contextManager,
       _snapshotLoader = snapshotLoader,
       _guidanceLoader = guidanceLoader ?? WriterGuidanceLoader();

  Future<StructuredChatContext> build({
    required List<ChatMessage> conversationHistory,
    required String currentUserMessage,
    required String workId,
    String? baseSystemPrompt,
    String? contextContent,
    List<String> runtimePaths = const [],
    String modelName = '',
  }) async {
    final history = _stripCurrentUserDuplication(
      conversationHistory,
      currentUserMessage,
    );

    var compactedHistory = history;
    if (compactedHistory.length > 6 &&
        _contextManager.needsCompact(compactedHistory, modelName)) {
      final compacted = await _contextManager.compact(
        messages: compactedHistory,
        modelName: modelName,
      );
      compactedHistory = compacted.recent;
    }

    final snapshot = await _snapshotLoader.load(workId);
    final userRequirements = _buildUserRequirements(
      currentUserMessage,
      compactedHistory,
    );
    final unsavedData = _buildUnsavedData(compactedHistory);
    final persistedData = snapshot?.content ?? '';
    final writerCharter = await _guidanceLoader.loadGlobalCharter();
    final moduleMemories = await _guidanceLoader.loadModuleMemories(
      currentUserMessage,
      contextContent: contextContent,
    );
    final runtimeSkills = await _guidanceLoader.loadSkillGuidance(
      currentUserMessage,
      contextContent: contextContent,
    );
    final pathMemories = await _guidanceLoader.loadPathMemories(runtimePaths);

    final systemPrompt = _composeSystemPrompt(
      writerCharter: writerCharter,
      moduleMemories: moduleMemories,
      pathMemories: pathMemories,
      runtimeSkills: runtimeSkills,
      baseSystemPrompt: baseSystemPrompt,
      userRequirements: userRequirements,
      persistedData: persistedData,
      unsavedData: unsavedData,
      contextContent: contextContent,
    );

    return StructuredChatContext(
      systemPrompt: systemPrompt,
      userPrompt: currentUserMessage,
      userRequirements: userRequirements,
      persistedData: persistedData,
      unsavedData: unsavedData,
      history: compactedHistory,
    );
  }

  List<ChatMessage> _stripCurrentUserDuplication(
    List<ChatMessage> history,
    String currentUserMessage,
  ) {
    if (history.isEmpty) return const [];
    final last = history.last;
    if (last.role == 'user' &&
        last.content.trim() == currentUserMessage.trim()) {
      return history.sublist(0, history.length - 1);
    }
    return history;
  }

  String _buildUserRequirements(
    String currentUserMessage,
    List<ChatMessage> compactedHistory,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('## 用户要求');
    buffer.writeln('- 当前回合要求: ${currentUserMessage.trim()}');

    final priorUserMessages = compactedHistory
        .where((message) => message.role == 'user')
        .map((message) => message.content.trim())
        .where((content) => content.isNotEmpty)
        .toList();
    if (priorUserMessages.isNotEmpty) {
      buffer.writeln('- 之前用户要求:');
      for (final message in priorUserMessages.take(6)) {
        buffer.writeln('  - ${_clip(message, 160)}');
      }
    }

    buffer.writeln('- 以上要求优先级最高，必须满足，除非用户明确撤销。');
    return buffer.toString().trim();
  }

  String _buildUnsavedData(List<ChatMessage> compactedHistory) {
    if (compactedHistory.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('## 未存对话上下文');
    for (final message in compactedHistory.take(10)) {
      final label = switch (message.role) {
        'user' => '用户',
        'assistant' => '助手',
        'tool' => '工具',
        'system' => '系统',
        _ => message.role,
      };
      buffer.writeln('- [$label] ${_clip(message.content, 180)}');
    }
    return buffer.toString().trim();
  }

  String _composeSystemPrompt({
    required String writerCharter,
    required List<String> moduleMemories,
    required List<String> pathMemories,
    required List<String> runtimeSkills,
    String? baseSystemPrompt,
    required String userRequirements,
    required String persistedData,
    required String unsavedData,
    String? contextContent,
  }) {
    final buffer = StringBuffer();
    final basePrompt =
        baseSystemPrompt ?? '你是一位专业的小说写作助手。请严格满足用户要求，并在需要时调用工具真实落库。';
    buffer.writeln(basePrompt);

    if (writerCharter.trim().isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## Writer Charter');
      buffer.writeln(writerCharter.trim());
    }

    if (moduleMemories.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## Module Memory');
      for (final memory in moduleMemories) {
        buffer.writeln(memory);
        buffer.writeln();
      }
    }

    if (pathMemories.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## Path Memory');
      for (final memory in pathMemories) {
        buffer.writeln(memory);
        buffer.writeln();
      }
    }

    if (runtimeSkills.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## Runtime Skills');
      for (final skill in runtimeSkills) {
        buffer.writeln(skill);
        buffer.writeln();
      }
    }

    buffer.writeln();
    buffer.writeln(userRequirements);

    if (persistedData.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(persistedData);
    }

    if (unsavedData.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(unsavedData);
    }

    if (contextContent != null && contextContent.trim().isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## 额外参考资料');
      buffer.writeln(contextContent.trim());
    }

    buffer.writeln();
    buffer.writeln('执行规则:');
    buffer.writeln('- 优先遵守“用户要求”部分。');
    buffer.writeln('- 作品已存数据视为已落库事实，不能随意改写。');
    buffer.writeln('- 未存对话上下文可作为草稿、计划、讨论信息使用。');
    buffer.writeln('- 如果要创建章节，必须写入完整正文而不是空章节。');
    return buffer.toString().trim();
  }
}

String _clip(String text, int max) {
  final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.length <= max) return normalized;
  return '${normalized.substring(0, max)}...';
}
