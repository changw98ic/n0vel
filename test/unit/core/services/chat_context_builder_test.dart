import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:writing_assistant/core/services/ai/context/context_manager.dart';
import 'package:writing_assistant/core/services/chat_context_builder.dart';
import 'package:writing_assistant/core/services/writer_guidance_loader.dart';

class MockContextManager extends Mock implements ContextManager {}

class MockPersistedNovelSnapshotLoader extends Mock
    implements PersistedNovelSnapshotLoader {}

class MockWriterGuidanceLoader extends Mock implements WriterGuidanceLoader {}

void main() {
  group('ChatContextBuilder', () {
    late MockContextManager mockContextManager;
    late MockPersistedNovelSnapshotLoader mockSnapshotLoader;
    late MockWriterGuidanceLoader mockGuidanceLoader;
    late ChatContextBuilder builder;

    setUp(() {
      mockContextManager = MockContextManager();
      mockSnapshotLoader = MockPersistedNovelSnapshotLoader();
      mockGuidanceLoader = MockWriterGuidanceLoader();
      builder = ChatContextBuilder(
        contextManager: mockContextManager,
        snapshotLoader: mockSnapshotLoader,
        guidanceLoader: mockGuidanceLoader,
      );
      when(
        () => mockGuidanceLoader.loadGlobalCharter(),
      ).thenAnswer((_) async => 'Global writer charter');
      when(
        () => mockGuidanceLoader.loadModuleMemories(
          any(),
          contextContent: any(named: 'contextContent'),
        ),
      ).thenAnswer((_) async => ['Matched module memory']);
      when(
        () => mockGuidanceLoader.loadSkillGuidance(
          any(),
          contextContent: any(named: 'contextContent'),
        ),
      ).thenAnswer((_) async => ['Matched runtime skill']);
      when(
        () => mockGuidanceLoader.loadPathMemories(any()),
      ).thenAnswer((_) async => ['Matched path memory']);
    });

    test('splits requirements persisted data and unsaved history', () async {
      when(
        () => mockContextManager.needsCompact(
          any(),
          any(),
          reserveTokens: any(named: 'reserveTokens'),
        ),
      ).thenReturn(false);
      when(() => mockSnapshotLoader.load('work-1')).thenAnswer(
        (_) async => const PersistedNovelSnapshot(
          workId: 'work-1',
          content: '## 作品已存数据\n作品名: 黑神话：无常',
        ),
      );

      final context = await builder.build(
        conversationHistory: const [
          ChatMessage(role: 'user', content: '先帮我规划故事骨架'),
          ChatMessage(role: 'assistant', content: '我建议先搭建世界观'),
          ChatMessage(role: 'user', content: '第1章必须大于4000字'),
        ],
        currentUserMessage: '第1章必须大于4000字',
        workId: 'work-1',
        baseSystemPrompt: '你是小说写作助手',
      );

      expect(context.userPrompt, '第1章必须大于4000字');
      expect(context.userRequirements, contains('当前回合要求'));
      expect(context.userRequirements, contains('第1章必须大于4000字'));
      expect(context.persistedData, contains('作品名: 黑神话：无常'));
      expect(context.unsavedData, contains('先帮我规划故事骨架'));
      expect(context.systemPrompt, contains('## 用户要求'));
      expect(context.systemPrompt, contains('## Writer Charter'));
      expect(context.systemPrompt, contains('Global writer charter'));
      expect(context.systemPrompt, contains('## Module Memory'));
      expect(context.systemPrompt, contains('Matched module memory'));
      expect(context.systemPrompt, contains('## Runtime Skills'));
      expect(context.systemPrompt, contains('Matched runtime skill'));
      expect(context.systemPrompt, contains('## Path Memory'));
      expect(context.systemPrompt, contains('Matched path memory'));
      expect(context.systemPrompt, contains('## 作品已存数据'));
      expect(context.systemPrompt, contains('## 未存对话上下文'));
      expect(context.history.length, 2);
    });

    test(
      'uses compacted history when context manager requests compaction',
      () async {
        when(
          () => mockContextManager.needsCompact(
            any(),
            any(),
            reserveTokens: any(named: 'reserveTokens'),
          ),
        ).thenReturn(true);
        when(
          () => mockContextManager.compact(
            messages: any(named: 'messages'),
            modelName: any(named: 'modelName'),
            reserveTokens: any(named: 'reserveTokens'),
          ),
        ).thenAnswer(
          (_) async => const CompactedContext(
            summary: 'summary',
            recent: [ChatMessage(role: 'system', content: 'summary block')],
            estimatedTokens: 10,
            wasCompacted: true,
          ),
        );
        when(() => mockSnapshotLoader.load('')).thenAnswer((_) async => null);

        final context = await builder.build(
          conversationHistory: List.generate(
            8,
            (index) => ChatMessage(role: 'user', content: 'message-$index'),
          ),
          currentUserMessage: 'new-message',
          workId: '',
        );

        expect(context.history, hasLength(1));
        expect(context.unsavedData, contains('summary block'));
      },
    );
  });
}
