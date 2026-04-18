import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:writing_assistant/core/services/writer_guidance_loader.dart';
import 'package:writing_assistant/core/services/writer_runtime_hooks.dart';

class MockWriterGuidanceLoader extends Mock implements WriterGuidanceLoader {}

void main() {
  group('WriterRuntimeHooks', () {
    late MockWriterGuidanceLoader mockGuidanceLoader;
    late WriterRuntimeHooks hooks;

    setUp(() {
      mockGuidanceLoader = MockWriterGuidanceLoader();
      hooks = WriterRuntimeHooks(guidanceLoader: mockGuidanceLoader);

      when(
        () => mockGuidanceLoader.loadHookGuidance('pre-request-validate'),
      ).thenAnswer((_) async => 'pre hook guidance');
      when(
        () => mockGuidanceLoader.loadHookGuidance('post-response-check'),
      ).thenAnswer((_) async => 'post hook guidance');
    });

    test('flags missing work scope and long context in preflight', () async {
      final result = await hooks.runPreRequestChecks(
        prompt: '请帮我创建第一章',
        workId: '',
        contextContent: 'x' * 7000,
        historyCount: 31,
      );

      expect(result.guidance, 'pre hook guidance');
      expect(result.issues, isNotEmpty);
      expect(result.toPromptSection(), contains('## Pre Request Hook'));
      expect(result.toPromptSection(), contains('## Preflight Checks'));
    });

    test('flags empty or too-short chapter response in postflight', () async {
      final result = await hooks.runPostResponseChecks(
        request: '请直接写第一章正文',
        response: '待补充',
      );

      expect(result.guidance, 'post hook guidance');
      expect(result.issues, isNotEmpty);
      expect(result.toMetadata(), isNotNull);
    });

    group('recovery actions', () {
      test('chapterBody block includes recovery hint', () async {
        final result = await hooks.runPostResponseChecks(
          request: '请直接写第一章正文',
          response: '很短的内容',
          ruleType: HookRuleType.chapterBody,
        );

        expect(result.shouldBlock, isTrue);
        final actions = result.recoveryActions;
        expect(actions, isNotEmpty);
        expect(actions.first.retryHint, contains('200 字'));
        expect(result.toRecoveryPrompt(), contains('修正建议'));
      });

      test('entityBio block with placeholder includes specific recovery', () async {
        final result = await hooks.runPostResponseChecks(
          request: '请创建角色设定简介',
          response: '暂无',
          ruleType: HookRuleType.entityBio,
        );

        expect(result.shouldBlock, isTrue);
        final actions = result.recoveryActions;
        expect(actions, isNotEmpty);
        // "暂无" (2 chars) triggers both length and placeholder checks
        expect(actions.any((a) => a.retryHint.contains('核心特征')), isTrue);
      });

      test('general block with TODO includes recovery hint', () async {
        final result = await hooks.runPostResponseChecks(
          request: '请创建设定',
          response: '这是TODO内容待补充',
        );

        expect(result.shouldBlock, isTrue);
        expect(result.recoveryActions.any((a) => a.retryHint.contains('占位符')), isTrue);
      });

      test('toRecoveryPrompt returns empty string when no issues', () async {
        final result = await hooks.runPostResponseChecks(
          request: '请写内容',
          response: '这是一段足够长的正常响应内容，不包含任何占位符或问题。',
        );

        expect(result.shouldBlock, isFalse);
        expect(result.recoveryActions, isEmpty);
        expect(result.toRecoveryPrompt(), isEmpty);
      });
    });
  });
}
