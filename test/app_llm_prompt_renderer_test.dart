import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_prompt_release.dart';
import 'package:novel_writer/app/llm/app_llm_prompt_renderer.dart';

void main() {
  test('frozen renderer validates schema and renders exact messages', () {
    final release = _release();
    final rendered = AppLlmPromptRendererRegistry.builtIn.render(
      release: release,
      resolvedVariables: const <String, Object?>{
        'scene': '雨夜',
        'attempt': 2,
        'feedback': '加强因果',
      },
    );

    expect(rendered.messages, hasLength(2));
    expect(rendered.messages[0].role, 'system');
    expect(rendered.messages[0].content, release.systemTemplate);
    expect(rendered.messages[1].role, 'user');
    expect(rendered.messages[1].content, '场景：雨夜\n尝试：2\n反馈：加强因果\n');
  });

  test('schema-valid variable text may contain template-looking braces', () {
    final release = _release();
    final rendered = AppLlmPromptRendererRegistry.builtIn.render(
      release: release,
      resolvedVariables: const <String, Object?>{
        'scene': '正文含 {{literal}} 和 }}',
        'attempt': 2,
        'feedback': '',
      },
    );

    expect(rendered.messages.last.content, '场景：正文含 {{literal}} 和 }}\n尝试：2\n');
  });

  test('missing, extra, and wrong-type variables fail closed', () {
    final release = _release();
    for (final variables in <Map<String, Object?>>[
      const <String, Object?>{'scene': '雨夜', 'attempt': 2},
      const <String, Object?>{
        'scene': '雨夜',
        'attempt': 2,
        'feedback': '',
        'extra': true,
      },
      const <String, Object?>{'scene': '雨夜', 'attempt': '2', 'feedback': ''},
    ]) {
      expect(
        () => AppLlmPromptRendererRegistry.builtIn.render(
          release: release,
          resolvedVariables: variables,
        ),
        throwsFormatException,
      );
    }
  });

  test('rendered messages cannot be smuggled back as variables', () {
    final release = PromptRelease(
      templateId: 'forbidden',
      semanticVersion: '1.0.0',
      language: 'zh',
      systemTemplate: 'system',
      userTemplate: '{{renderedMessages}}',
      variablesSchemaSnapshot: const <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'required': <String>['renderedMessages'],
        'properties': <String, Object?>{
          'renderedMessages': <String, Object?>{'type': 'string'},
        },
      },
      outputSchemaSnapshot: const <String, Object?>{'type': 'string'},
      rendererRelease: AppLlmPromptRendererRegistry.strictRendererRelease,
      parserRelease: 'parser-v1',
      repairPolicySnapshot: const <String, Object?>{'maxAttempts': 1},
      owner: 'test',
      changeNote: 'negative',
      createdAt: DateTime.utc(2026, 7, 13),
    );

    expect(
      () => AppLlmPromptRendererRegistry.builtIn.render(
        release: release,
        resolvedVariables: const <String, Object?>{
          'renderedMessages': 'system/user',
        },
      ),
      throwsFormatException,
    );
  });

  test('unknown renderer and unused schema property fail closed', () {
    final release = _release(rendererRelease: 'unknown-renderer-v9');
    expect(
      () => AppLlmPromptRendererRegistry.builtIn.render(
        release: release,
        resolvedVariables: const <String, Object?>{
          'scene': '雨夜',
          'attempt': 2,
          'feedback': '',
        },
      ),
      throwsStateError,
    );

    final unused = _release(
      variablesSchema: const <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'required': <String>['scene', 'attempt', 'feedback', 'unused'],
        'properties': <String, Object?>{
          'scene': <String, Object?>{'type': 'string'},
          'attempt': <String, Object?>{'type': 'integer'},
          'feedback': <String, Object?>{'type': 'string'},
          'unused': <String, Object?>{'type': 'string'},
        },
      },
    );
    expect(
      () => AppLlmPromptRendererRegistry.builtIn.render(
        release: unused,
        resolvedVariables: const <String, Object?>{
          'scene': '雨夜',
          'attempt': 2,
          'feedback': '',
          'unused': 'hidden',
        },
      ),
      throwsFormatException,
    );
  });

  test('mutating a release to another registered renderer cannot replay', () {
    final mutated = _release(rendererRelease: 'judge-renderer-v1');

    expect(
      () => AppLlmPromptRendererRegistry.builtIn.render(
        release: mutated,
        resolvedVariables: const <String, Object?>{
          'scene': '雨夜',
          'attempt': 2,
          'feedback': '加强因果',
        },
      ),
      throwsFormatException,
    );
  });

  test('nested and crossed optional blocks fail closed', () {
    for (final template in const <String>[
      '{{?feedback}}反馈：{{?scene}}{{scene}}{{/scene}}{{/feedback}}{{attempt}}',
      '{{?feedback}}反馈：{{?scene}}{{scene}}{{/feedback}}{{/scene}}{{attempt}}',
    ]) {
      final release = _release(userTemplate: template);
      expect(
        () => AppLlmPromptRendererRegistry.builtIn.render(
          release: release,
          resolvedVariables: const <String, Object?>{
            'scene': '雨夜',
            'attempt': 2,
            'feedback': '加强因果',
          },
        ),
        throwsFormatException,
        reason: template,
      );
    }
  });
}

PromptRelease _release({
  String rendererRelease = AppLlmPromptRendererRegistry.strictRendererRelease,
  String userTemplate =
      '场景：{{scene}}\n尝试：{{attempt}}\n'
      '{{?feedback}}反馈：{{feedback}}\n{{/feedback}}',
  Object? variablesSchema = const <String, Object?>{
    'type': 'object',
    'additionalProperties': false,
    'required': <String>['scene', 'attempt', 'feedback'],
    'properties': <String, Object?>{
      'scene': <String, Object?>{'type': 'string'},
      'attempt': <String, Object?>{'type': 'integer'},
      'feedback': <String, Object?>{'type': 'string'},
    },
  },
}) => PromptRelease(
  templateId: 'renderer-test',
  semanticVersion: '1.0.0',
  language: 'zh',
  systemTemplate: 'frozen system',
  userTemplate: userTemplate,
  variablesSchemaSnapshot: variablesSchema,
  outputSchemaSnapshot: const <String, Object?>{'type': 'string'},
  rendererRelease: rendererRelease,
  parserRelease: 'parser-v1',
  repairPolicySnapshot: const <String, Object?>{'maxAttempts': 1},
  owner: 'test',
  changeNote: 'renderer test',
  createdAt: DateTime.utc(2026, 7, 13),
);
