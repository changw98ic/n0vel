import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/llm/app_llm_client_io.dart';
import 'package:novel_writer/app/state/app_ai_history_storage.dart';
import 'package:novel_writer/app/state/app_draft_storage.dart';
import 'package:novel_writer/app/state/app_scene_context_storage.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_storage_io.dart';
import 'package:novel_writer/app/state/app_simulation_storage.dart';
import 'package:novel_writer/app/state/app_version_storage.dart';
import 'package:novel_writer/app/state/app_workspace_storage.dart';
import 'package:novel_writer/app/state/app_workspace_storage_io.dart';
import 'package:novel_writer/app/state/story_outline_storage.dart';

void main() {
  group('llm value types', () {
    test('messages, requests, and results preserve module state', () {
      const message = AppLlmChatMessage(role: 'user', content: '继续写');
      const request = AppLlmChatRequest(
        baseUrl: 'http://127.0.0.1:8080/v1',
        apiKey: 'sk-test',
        model: 'gpt-5.4',
        timeout: AppLlmTimeoutConfig.uniform(1500),
        messages: [message],
      );
      const success = AppLlmChatResult.success(text: '已续写', latencyMs: 12);
      const failure = AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.server,
        statusCode: 500,
        detail: '服务异常',
      );

      expect(message.toJson(), {'role': 'user', 'content': '继续写'});
      expect(request.baseUrl, 'http://127.0.0.1:8080/v1');
      expect(request.messages.single.content, '继续写');
      expect(success.succeeded, isTrue);
      expect(success.text, '已续写');
      expect(success.latencyMs, 12);
      expect(failure.succeeded, isFalse);
      expect(failure.failureKind, AppLlmFailureKind.server);
      expect(failure.statusCode, 500);
      expect(failure.detail, '服务异常');
    });
  });

  group('in-memory storages', () {
    test(
      'settings storage saves cloned snapshots without persistence warnings',
      () async {
        final storage = InMemoryAppSettingsStorage();

        final saveResult = await storage.save({
          'providerName': 'OpenAI 兼容服务',
          'metadata': {'region': 'cn'},
          'connectTimeoutMs': 10000,
          'sendTimeoutMs': 30000,
          'receiveTimeoutMs': 60000,
        });
        final firstLoad = await storage.load();
        (firstLoad!['metadata'] as Map<String, Object?>)['region'] = 'mutated';
        final secondLoad = await storage.load();

        expect(saveResult.succeededWithoutWarnings, isTrue);
        expect(storage.lastLoadIssue, AppSettingsPersistenceIssue.none);
        expect(storage.lastLoadDetail, isNull);
        expect(
          (secondLoad?['metadata'] as Map<String, Object?>)['region'],
          'cn',
        );
      },
    );

    test(
      'workspace storage saves cloned snapshots and clears all records',
      () async {
        final storage = InMemoryAppWorkspaceStorage();

        await storage.save({
          'projects': [
            {'id': 'project-a', 'title': '项目 A'},
          ],
          'currentProjectId': 'project-a',
        });
        final firstLoad = await storage.load();
        ((firstLoad!['projects'] as List<Object?>).first
                as Map<String, Object?>)['title'] =
            '被篡改';

        final secondLoad = await storage.load();
        expect((secondLoad?['projects'] as List<Object?>), hasLength(1));
        expect(
          ((secondLoad?['projects'] as List<Object?>).first
              as Map<String, Object?>)['title'],
          '项目 A',
        );

        await storage.clear();
        expect(await storage.load(), isNull);
      },
    );

    test(
      'project-scoped in-memory storages isolate data and support targeted clear',
      () async {
        await _expectProjectScopedStorageBehavior(
          storage: InMemoryAppDraftStorage(),
          payloadA: {
            'text': '项目 A 草稿',
            'metadata': {'chapter': 1},
          },
          payloadB: {
            'text': '项目 B 草稿',
            'metadata': {'chapter': 2},
          },
        );
        await _expectProjectScopedStorageBehavior(
          storage: InMemoryAppVersionStorage(),
          payloadA: {
            'entries': [
              {
                'label': 'A1',
                'content': '项目 A 版本',
                'meta': {'order': 1},
              },
            ],
          },
          payloadB: {
            'entries': [
              {
                'label': 'B1',
                'content': '项目 B 版本',
                'meta': {'order': 2},
              },
            ],
          },
        );
        await _expectProjectScopedStorageBehavior(
          storage: InMemoryAppAiHistoryStorage(),
          payloadA: {
            'entries': [
              {
                'prompt': '项目 A 历史',
                'meta': {'scene': '05'},
              },
            ],
          },
          payloadB: {
            'entries': [
              {
                'prompt': '项目 B 历史',
                'meta': {'scene': '07'},
              },
            ],
          },
        );
        await _expectProjectScopedStorageBehavior(
          storage: InMemoryAppSceneContextStorage(),
          payloadA: {
            'sceneSummary': '项目 A 上下文',
            'details': {'chapter': '第一章'},
          },
          payloadB: {
            'sceneSummary': '项目 B 上下文',
            'details': {'chapter': '第二章'},
          },
        );
        await _expectProjectScopedStorageBehavior(
          storage: InMemoryAppSimulationStorage(),
          payloadA: {
            'template': 'completed',
            'extraMessages': [
              {
                'title': 'A',
                'meta': {'turn': 1},
              },
            ],
          },
          payloadB: {
            'template': 'failed',
            'extraMessages': [
              {
                'title': 'B',
                'meta': {'turn': 2},
              },
            ],
          },
        );
        await _expectProjectScopedStorageBehavior(
          storage: InMemoryStoryOutlineStorage(),
          payloadA: {
            'projectId': 'project-a',
            'chapters': [
              {
                'id': 'chapter-a',
                'title': '项目 A 章节',
                'scenes': [
                  {
                    'id': 'scene-a',
                    'title': '项目 A 场景',
                    'cast': [
                      {
                        'characterId': 'char-a',
                        'metadata': {'action': '项目 A 动作'},
                      },
                    ],
                  },
                ],
              },
            ],
          },
          payloadB: {
            'projectId': 'project-b',
            'chapters': [
              {
                'id': 'chapter-b',
                'title': '项目 B 章节',
                'scenes': [
                  {
                    'id': 'scene-b',
                    'title': '项目 B 场景',
                    'cast': [
                      {
                        'characterId': 'char-b',
                        'metadata': {'action': '项目 B 动作'},
                      },
                    ],
                  },
                ],
              },
            ],
          },
        );
      },
    );
  });

  test(
    'default factories resolve to real IO implementations on this platform',
    () {
      expect(createDefaultAppLlmClient(), isA<AppLlmClient>());
      expect(createAppLlmClient(), isA<AppLlmClient>());
      expect(createDefaultAppSettingsStorage(), isA<FileAppSettingsStorage>());
      expect(createDefaultAppDraftStorage(), isA<AppDraftStorage>());
      expect(createDefaultAppVersionStorage(), isA<AppVersionStorage>());
      expect(
        createDefaultAppWorkspaceStorage(),
        isA<SqliteAppWorkspaceStorage>(),
      );
      expect(
        createDefaultAppAiHistoryStorage(),
        isA<AppAiHistoryStorage>(),
      );
      expect(
        createDefaultAppSceneContextStorage(),
        isA<AppSceneContextStorage>(),
      );
      expect(
        createDefaultAppSimulationStorage(),
        isA<AppSimulationStorage>(),
      );
      expect(
        createDefaultStoryOutlineStorage(),
        isA<StoryOutlineStorage>(),
      );
    },
  );
}

Future<void> _expectProjectScopedStorageBehavior({
  required dynamic storage,
  required Map<String, Object?> payloadA,
  required Map<String, Object?> payloadB,
}) async {
  await storage.save(payloadA, projectId: 'project-a');
  await storage.save(payloadB, projectId: 'project-b');

  final loadedA =
      await storage.load(projectId: 'project-a') as Map<String, Object?>?;
  expect(loadedA, isNotNull);
  _mutateNestedValue(loadedA!);

  final loadedAAgain =
      await storage.load(projectId: 'project-a') as Map<String, Object?>?;
  final loadedB =
      await storage.load(projectId: 'project-b') as Map<String, Object?>?;
  expect(loadedAAgain, equals(payloadA));
  expect(loadedB, equals(payloadB));

  await storage.clear(projectId: 'project-a');
  expect(await storage.load(projectId: 'project-a'), isNull);
  expect(await storage.load(projectId: 'project-b'), equals(payloadB));

  await storage.clear();
  expect(await storage.load(projectId: 'project-b'), isNull);
}

void _mutateNestedValue(Map<String, Object?> value) {
  for (final entry in value.entries) {
    final nested = entry.value;
    if (nested is Map && nested.isNotEmpty) {
      nested[nested.keys.first] = 'mutated';
      return;
    }
    if (nested is List && nested.isNotEmpty) {
      final first = nested.first;
      if (first is Map && first.isNotEmpty) {
        first[first.keys.first] = 'mutated';
        return;
      }
    }
  }
  value['mutated'] = true;
}
