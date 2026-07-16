import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/app_workspace_storage.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';
import 'package:novel_writer/app/state/story_outline_storage.dart';
import 'package:novel_writer/app/state/story_outline_store.dart';
import 'package:novel_writer/features/story_generation/data/scene_hard_gates.dart';
import 'package:novel_writer/features/story_generation/data/story_material_snapshot_builder.dart';
import 'package:novel_writer/features/story_generation/domain/outline_plan_models.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';

void main() {
  group('scene outline fidelity hard gate', () {
    test('requires an alias from every evidence group', () {
      final brief = _briefWithMetadata(const {
        'requiredOutlineBeats': <Object?>[
          <String, Object?>{
            'id': 'tracker-reveal',
            'description': '发现追踪器后转入暗巷。',
            'evidenceGroups': <Object?>[
              <String>['微型定位器', '追踪器'],
              <String>['集装箱暗巷', '暗巷'],
            ],
          },
        ],
      });

      final missing = sceneHardGateViolations(
        brief: brief,
        proseText: '「风衣里果然藏着追踪器。」沈渡说。',
      );
      expect(
        missing,
        contains(
          isA<HardGateViolation>().having(
            (item) => item.text,
            'text',
            allOf(contains('大纲'), contains('tracker-reveal')),
          ),
        ),
      );

      final complete = sceneHardGateViolations(
        brief: brief,
        proseText: '「风衣里果然藏着微型定位器。」沈渡把人拉进暗巷。',
      );
      expect(complete.where((item) => item.text.contains('大纲')), isEmpty);
    });

    test(
      'fails closed for malformed required contracts only in strict mode',
      () {
        const malformed = <String, Object?>{
          'requiredOutlineBeats': <Object?>[
            <String, Object?>{
              'id': 'missing-evidence',
              'description': '必须出现的大纲转折。',
            },
          ],
        };
        final legacy = sceneHardGateViolations(
          brief: _briefWithMetadata(malformed),
          proseText: '「我们走。」他说。',
        );
        expect(legacy.where((item) => item.text.contains('大纲')), isEmpty);

        final formal = sceneHardGateViolations(
          brief: _briefWithMetadata(malformed, formalExecution: true),
          proseText: '「我们走。」他说。',
        );
        expect(
          formal,
          contains(
            isA<HardGateViolation>().having(
              (item) => item.text,
              'text',
              allOf(contains('大纲'), contains('missing-evidence')),
            ),
          ),
        );

        final formalMissingContract = sceneHardGateViolations(
          brief: _briefWithMetadata(const {}, formalExecution: true),
          proseText: '「我们走。」他说。',
        );
        expect(
          formalMissingContract.any((item) => item.text.contains('大纲')),
          isTrue,
        );

        final explicitlyRequired = sceneHardGateViolations(
          brief: _briefWithMetadata(const {'requireOutlineFidelity': true}),
          proseText: '「我们走。」他说。',
        );
        expect(
          explicitlyRequired.any((item) => item.text.contains('大纲')),
          isTrue,
        );

        for (final malformedGroup in <Object?>[
          <Object?>['微型定位器', 42],
          <Object?>['微型定位器', '   '],
          <Object?>['微型定位器', ' 微型定位器 '],
        ]) {
          final mixedAliasContract = sceneHardGateViolations(
            brief: _briefWithMetadata(<String, Object?>{
              'requiredOutlineBeats': <Object?>[
                <String, Object?>{
                  'id': 'strict-alias-shape',
                  'description': '发现微型定位器。',
                  'evidenceGroups': <Object?>[malformedGroup],
                },
              ],
            }, formalExecution: true),
            proseText: '柳溪发现微型定位器。',
          );
          expect(
            mixedAliasContract.any((item) => item.text.contains('契约无效')),
            isTrue,
            reason: 'strict evidence groups must reject $malformedGroup',
          );
        }

        for (final malformedBeat in <Map<String, Object?>>[
          <String, Object?>{
            'id': 42,
            'description': '发现微型定位器。',
            'evidenceGroups': <Object?>[
              <String>['微型定位器'],
            ],
          },
          <String, Object?>{
            'id': 'strict-text-fields',
            'description': true,
            'evidenceGroups': <Object?>[
              <String>['微型定位器'],
            ],
          },
        ]) {
          final nonStringTextContract = sceneHardGateViolations(
            brief: _briefWithMetadata(<String, Object?>{
              'requiredOutlineBeats': <Object?>[malformedBeat],
            }, formalExecution: true),
            proseText: '柳溪发现微型定位器。',
          );
          expect(
            nonStringTextContract.any((item) => item.text.contains('契约无效')),
            isTrue,
            reason: 'strict beat text fields must reject $malformedBeat',
          );
        }
      },
    );
  });

  group('StoryMaterialSnapshotBuilder outline fidelity', () {
    test('keeps matching explicit evidence ahead of runtime summaries', () {
      final workspace = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final outline = StoryOutlineStore(
        storage: InMemoryStoryOutlineStorage(),
        workspaceStore: workspace,
      );
      addTearDown(workspace.dispose);
      addTearDown(outline.dispose);
      final scene = workspace.currentScene;

      const authoritative = <Object?>[
        <String, Object?>{
          'id': 'legacy-explicit-beat',
          'description': '权威大纲转折。',
          'evidenceGroups': <Object?>[
            <String>['铁门', '焊死'],
          ],
        },
      ];
      outline.replaceSnapshot(
        StoryOutlineSnapshot(
          projectId: workspace.currentProjectId,
          chapters: [
            StoryOutlineChapterSnapshot(
              id: scene.chapterLabel,
              title: '权威章节',
              summary: '权威章节摘要',
              scenes: [
                StoryOutlineSceneSnapshot(
                  id: scene.id,
                  title: '权威场景',
                  summary: '焊死铁门前必须抢出钥匙页。',
                  metadata: const {
                    'requiredOutlineBeats': authoritative,
                    'requireOutlineFidelity': true,
                  },
                ),
                const StoryOutlineSceneSnapshot(
                  id: 'other-scene',
                  title: '邻场',
                  summary: '不应注入。',
                  metadata: {
                    'requiredOutlineBeats': <Object?>[
                      <String, Object?>{
                        'id': 'wrong-neighbour-beat',
                        'description': '错误场景。',
                        'evidenceGroups': <Object?>[
                          <String>['错误'],
                        ],
                      },
                    ],
                  },
                ),
              ],
            ),
          ],
          executablePlan: NovelPlan(
            id: 'novel-plan',
            projectId: workspace.currentProjectId,
            title: '执行大纲',
            premise: '测试',
            chapters: [
              ChapterPlan(
                id: 'chapter-plan',
                novelPlanId: 'novel-plan',
                title: '执行章节',
                summary: '执行章节摘要',
                scenes: [
                  ScenePlan(
                    id: scene.id,
                    chapterPlanId: 'chapter-plan',
                    title: '执行场景',
                    summary: '执行计划中的完整场景摘要。',
                    povCharacterId: '',
                    beats: [
                      BeatPlan(
                        id: 'plan-description-only',
                        scenePlanId: scene.id,
                        sequence: 1,
                        beatType: 'action',
                        content: '执行计划节拍描述。',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      final brief = const StoryMaterialSnapshotBuilder().buildSceneBrief(
        workspaceStore: workspace,
        outlineStore: outline,
        runtimeMetadata: const {
          'requiredOutlineBeats': <Object?>[
            <String, Object?>{
              'id': 'runtime-simplified-beat',
              'description': '简化后的运行时摘要。',
            },
          ],
        },
      );

      expect(brief.sceneSummary, '执行计划中的完整场景摘要。');
      expect(brief.metadata['requiredOutlineBeats'], authoritative);
      expect(brief.metadata['requireOutlineFidelity'], isTrue);
      expect(
        brief.metadata['requiredOutlineBeats'].toString(),
        isNot(contains('runtime-simplified-beat')),
      );
      expect(
        brief.metadata['requiredOutlineBeats'].toString(),
        isNot(contains('wrong-neighbour-beat')),
      );
    });

    test('structures executable beats without inventing evidence aliases', () {
      final workspace = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final outline = StoryOutlineStore(
        storage: InMemoryStoryOutlineStorage(),
        workspaceStore: workspace,
      );
      addTearDown(workspace.dispose);
      addTearDown(outline.dispose);
      final scene = workspace.currentScene;
      outline.replaceSnapshot(
        StoryOutlineSnapshot(
          projectId: workspace.currentProjectId,
          executablePlan: NovelPlan(
            id: 'novel-plan',
            projectId: workspace.currentProjectId,
            title: '执行大纲',
            premise: '测试',
            chapters: [
              ChapterPlan(
                id: 'chapter-plan',
                novelPlanId: 'novel-plan',
                title: '执行章节',
                summary: '摘要',
                scenes: [
                  ScenePlan(
                    id: scene.id,
                    chapterPlanId: 'chapter-plan',
                    title: '执行场景',
                    summary: '完整摘要',
                    povCharacterId: '',
                    beats: [
                      BeatPlan(
                        id: 'beat-key-pages',
                        scenePlanId: scene.id,
                        sequence: 1,
                        beatType: 'reveal',
                        content: '撕下关键页并显出隐形印记。',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      final brief = const StoryMaterialSnapshotBuilder().buildSceneBrief(
        workspaceStore: workspace,
        outlineStore: outline,
      );
      final beats = brief.metadata['requiredOutlineBeats'] as List<Object?>;
      final beat = beats.single as Map<Object?, Object?>;

      expect(beat['id'], 'beat-key-pages');
      expect(beat['description'], '撕下关键页并显出隐形印记。');
      expect(beat.containsKey('evidenceGroups'), isFalse);
    });
  });
}

SceneBrief _briefWithMetadata(
  Map<String, Object?> metadata, {
  bool formalExecution = false,
}) {
  return SceneBrief(
    chapterId: 'chapter-01',
    chapterTitle: '第一章',
    sceneId: 'scene-02',
    sceneTitle: '场景',
    sceneSummary: '摘要',
    sceneIndex: 1,
    totalScenesInChapter: 3,
    formalExecution: formalExecution,
    metadata: metadata,
  );
}
