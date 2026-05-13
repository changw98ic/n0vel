import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/knowledge_tool_registry.dart';
import 'package:novel_writer/features/story_generation/data/material_reference_retriever.dart';
import 'package:novel_writer/features/story_generation/data/retrieval_controller.dart';
import 'package:novel_writer/features/story_generation/data/scene_pipeline_models.dart';
import 'package:novel_writer/features/story_generation/data/story_generation_models.dart';

void main() {
  group('MaterialReferenceRetriever', () {
    late Directory tempDir;
    late MaterialReferenceRetriever retriever;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('material_ref_test_');
      _writeJsonl('${tempDir.path}/refined_scenes.jsonl', [
        {
          'chunk_id': 'jianlai_ch0001_sc001',
          'primary_tag': 'dialogue_subtext',
          'tags': [
            {'id': 'dialogue_subtext', 'rationale': 'must not leak'},
            {'id': 'emotion_suppressed'},
          ],
          'retrieval_roles': ['subtext', 'dialogue_rhythm'],
          'use_when': '需要写对白潜台词时',
          'quality_flags': ['good_style_reference'],
          'anti_ai_lessons': ['never expose'],
          'avoid_using_for': 'never expose',
          'dont': 'never expose',
          'beats': ['never expose'],
          'skeleton': 'never expose',
          'technique': 'never expose',
          'lesson': 'never expose',
          'advice': 'never expose',
        },
        {
          'chunk_id': 'jianlai_ch0001_sc002',
          'primary_tag': 'worldbuilding_custom_rule',
          'tags': [
            {'id': 'worldbuilding_custom_rule'},
          ],
          'retrieval_roles': ['world_rule_exposition'],
          'use_when': '需要借民俗展现世界观时',
          'quality_flags': ['good_style_reference'],
        },
      ]);
      _writeJsonl('${tempDir.path}/rag_contextual_atoms.jsonl', [
        {
          'parent_scene_id': 'jianlai_ch0001_sc001',
          'generation_reference_text': '他停了停，把没说出口的话咽回去，只用一句轻话试探对方。',
          'primary_tag': 'dialogue_subtext',
          'tags': [
            {
              'id': 'dialogue_subtext',
              'signals': ['strip'],
            },
          ],
          'quality_flags': ['semantic_atom'],
          'advice': 'never expose',
        },
        {
          'parent_scene_id': 'jianlai_ch0001_sc002',
          'generation_reference_text': '小镇旧俗在暮色里铺开，人物动作顺手带出规矩。',
          'primary_tag': 'worldbuilding_custom_rule',
          'tags': [
            {'id': 'worldbuilding_custom_rule'},
          ],
          'quality_flags': ['semantic_atom'],
        },
      ]);
      retriever = MaterialReferenceRetriever(rootPath: tempDir.path);
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test(
      'returns safe metadata and fallback excerpt without guidance fields',
      () {
        final result = retriever.searchSync(
          const MaterialReferenceQuery(
            query: '对白 潜台词',
            retrievalRoles: ['subtext'],
            limit: 20,
          ),
        );

        expect(result.source, MaterialReferenceSource.refinedScenes.name);
        expect(result.hits, isNotEmpty);
        expect(result.hits.length, lessThanOrEqualTo(12));
        final hit = result.hits.first;
        expect(hit.chunkId, 'jianlai_ch0001_sc001');
        expect(hit.tags, contains('dialogue_subtext'));
        expect(hit.tags, isNot(contains('must not leak')));
        expect(hit.retrievalRoles, contains('subtext'));
        expect(hit.excerpt, contains('没说出口'));

        final encoded = jsonEncode(result.toJson());
        expect(encoded, isNot(contains('anti_ai_lessons')));
        expect(encoded, isNot(contains('avoid_using_for')));
        expect(encoded, isNot(contains('dont')));
        expect(encoded, isNot(contains('beats')));
        expect(encoded, isNot(contains('skeleton')));
        expect(encoded, isNot(contains('technique')));
        expect(encoded, isNot(contains('lesson')));
        expect(encoded, isNot(contains('advice')));
        expect(encoded, isNot(contains('rationale')));
        expect(encoded, isNot(contains('signals')));
      },
    );

    test('clamps configured max limit to twelve and truncates excerpts', () {
      _writeJsonl('${tempDir.path}/refined_scenes.jsonl', [
        for (var i = 0; i < 20; i += 1)
          {
            'chunk_id': 'bulk_$i',
            'primary_tag': 'dialogue_subtext',
            'tags': [
              {'id': 'dialogue_subtext'},
            ],
            'retrieval_roles': ['subtext'],
            'use_when': '需要写对白潜台词时',
            'excerpt': '长句${List.filled(80, '一').join()}',
          },
      ]);
      final looseRetriever = MaterialReferenceRetriever(
        rootPath: tempDir.path,
        defaultLimit: 30,
        maxLimit: 99,
        excerptCharLimit: 32,
      );

      final result = looseRetriever.searchSync(
        const MaterialReferenceQuery(query: 'dialogue_subtext', limit: 99),
      );

      expect(result.hits, hasLength(12));
      expect(result.hits.first.excerpt.length, lessThanOrEqualTo(32));
      expect(result.hits.first.excerpt, endsWith('...'));
    });

    test('does not use legacy vector text field as retrieval text', () {
      final legacyTextKey = ['embedding', 'text'].join('_');
      _writeJsonl('${tempDir.path}/refined_scenes.jsonl', [
        {
          'chunk_id': 'legacy_only',
          'primary_tag': 'dialogue_subtext',
          'tags': [
            {'id': 'dialogue_subtext'},
          ],
          'retrieval_roles': ['subtext'],
          'use_when': '需要写对白潜台词时',
          legacyTextKey: 'legacy text should not be used',
        },
      ]);

      final result = retriever.searchSync(
        const MaterialReferenceQuery(query: 'legacy', limit: 5),
      );

      expect(result.hits, isEmpty);
    });

    test('registers as in-app knowledge tool', () async {
      final registry = KnowledgeToolRegistry(
        tools: createMaterialReferenceTools(retriever: retriever),
      );

      expect(registry.hasTool(kWritingReferenceToolName), isTrue);
      final capsule = await registry.call(kWritingReferenceToolName, {
        'query': '民俗 世界观',
        'tags': ['worldbuilding_custom_rule'],
      });

      expect(capsule.sourceTool, kWritingReferenceToolName);
      expect(capsule.summary, contains('jianlai_ch0001_sc002'));
      expect(capsule.summary, isNot(contains('advice')));
    });

    test('roleplay default registry includes writing reference tool', () async {
      final registry = KnowledgeToolRegistry.roleplayDefaults(
        materialReferenceRetriever: retriever,
      );

      expect(registry.hasTool(kWritingReferenceToolName), isTrue);
      final capsule = await registry.call(kWritingReferenceToolName, {
        'query': '对白 潜台词',
      });

      expect(capsule.sourceTool, kWritingReferenceToolName);
      expect(capsule.summary, contains('jianlai_ch0001_sc001'));
      expect(capsule.summary, isNot(contains('avoid_using_for')));
    });

    test(
      'scene retrieval controller resolves prompt-driven writing reference',
      () {
        final controller = RetrievalController(
          materialReferenceRetriever: retriever,
        );
        final taskCard = _taskCard();
        final roleTurn = RolePlayTurnOutput.fromDynamicAgentOutput(
          const DynamicRoleAgentOutput(
            characterId: 'c1',
            name: '角色',
            text:
                '立场：试探\n动作：开口\n禁忌：直白\n'
                '检索：search_writing_reference|对白 潜台词|需要写对白潜台词时',
          ),
        );
        final capsules = controller.resolve(
          taskCard: taskCard,
          turns: [roleTurn],
        );

        expect(roleTurn.retrievalIntents, hasLength(1));
        expect(
          roleTurn.retrievalIntents.first.toolName,
          LightRetrievalIntent.kToolWritingReference,
        );
        expect(capsules, hasLength(1));
        expect(capsules.first.intent.toolName, kWritingReferenceToolName);
        expect(capsules.first.summary, contains('jianlai_ch0001_sc001'));
        expect(capsules.first.summary, isNot(contains('lesson')));
      },
    );
  });
}

void _writeJsonl(String path, List<Map<String, Object?>> records) {
  File(path).writeAsStringSync(records.map(jsonEncode).join('\n'));
}

SceneTaskCard _taskCard() {
  return SceneTaskCard(
    brief: SceneBrief(
      chapterId: 'ch1',
      chapterTitle: 'chapter',
      sceneId: 'sc1',
      sceneTitle: 'test',
      sceneSummary: 'summary',
      targetBeat: 'beat',
    ),
    cast: [
      ResolvedSceneCastMember(
        characterId: 'c1',
        name: '角色',
        role: '主角',
        contributions: [SceneCastContribution.action],
      ),
    ],
    directorPlan: 'plan',
  );
}
