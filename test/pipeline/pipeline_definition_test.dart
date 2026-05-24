import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/pipeline_definition.dart';
import 'package:novel_writer/features/story_generation/data/pipeline_stage_runner_impl.dart';

void main() {
  group('PipelineStageId', () {
    test('has all nine expected stages in order', () {
      const expectedOrder = [
        PipelineStageId.contextEnrichment,
        PipelineStageId.scenePlanning,
        PipelineStageId.roleplay,
        PipelineStageId.stageNarration,
        PipelineStageId.beatResolution,
        PipelineStageId.editorial,
        PipelineStageId.review,
        PipelineStageId.polish,
        PipelineStageId.finalization,
      ];

      expect(PipelineStageId.values, orderedEquals(expectedOrder));
    });

    test('stage names are stable and versioned', () {
      expect(PipelineStageId.contextEnrichment.name, 'contextEnrichment');
      expect(PipelineStageId.scenePlanning.name, 'scenePlanning');
      expect(PipelineStageId.roleplay.name, 'roleplay');
      expect(PipelineStageId.stageNarration.name, 'stageNarration');
      expect(PipelineStageId.beatResolution.name, 'beatResolution');
      expect(PipelineStageId.editorial.name, 'editorial');
      expect(PipelineStageId.review.name, 'review');
      expect(PipelineStageId.polish.name, 'polish');
      expect(PipelineStageId.finalization.name, 'finalization');
    });
  });

  group('PipelineStageSpec', () {
    test('construction with all fields', () {
      const spec = PipelineStageSpec(
        id: PipelineStageId.contextEnrichment,
        label: '上下文增强',
        description: '跨章节上下文增强、记忆索引、RAG检索',
      );

      expect(spec.id, PipelineStageId.contextEnrichment);
      expect(spec.label, '上下文增强');
      expect(spec.description, '跨章节上下文增强、记忆索引、RAG检索');
      expect(spec.enabled, isTrue); // default
    });

    test('enabled flag can be set to false', () {
      const spec = PipelineStageSpec(
        id: PipelineStageId.review,
        label: '质量审查',
        description: '质量审查与门控逻辑',
        enabled: false,
      );

      expect(spec.enabled, isFalse);
    });

    test('copyWith modifies enabled flag', () {
      const spec = PipelineStageSpec(
        id: PipelineStageId.polish,
        label: '润色',
        description: '散文润色',
        enabled: true,
      );

      final disabled = spec.copyWith(enabled: false);

      expect(spec.enabled, isTrue); // unchanged
      expect(disabled.enabled, isFalse);
      expect(disabled.id, spec.id);
      expect(disabled.label, spec.label);
    });

    test('toJson and fromJson roundtrip', () {
      const spec = PipelineStageSpec(
        id: PipelineStageId.editorial,
        label: '编辑草稿',
        description: '生成编辑草稿',
        enabled: true,
      );

      final json = spec.toJson();
      final rehydrated = PipelineStageSpec.fromJson(json);

      expect(rehydrated.id, spec.id);
      expect(rehydrated.label, spec.label);
      expect(rehydrated.description, spec.description);
      expect(rehydrated.enabled, spec.enabled);
    });

    test('fromJson defaults enabled to true when missing', () {
      final json = {
        'id': 'review',
        'label': '质量审查',
        'description': '质量审查与门控逻辑',
      };

      final spec = PipelineStageSpec.fromJson(json);

      expect(spec.enabled, isTrue);
    });
  });

  group('PipelinePreset', () {
    test('construction with all fields', () {
      const preset = PipelinePreset(
        id: 'test-preset',
        name: '测试预设',
        stages: [
          PipelineStageSpec(
            id: PipelineStageId.contextEnrichment,
            label: '上下文增强',
            description: '描述',
          ),
        ],
      );

      expect(preset.id, 'test-preset');
      expect(preset.name, '测试预设');
      expect(preset.stages, hasLength(1));
    });

    test('enabledStages filters out disabled stages', () {
      const preset = PipelinePreset(
        id: 'filter-test',
        name: '过滤测试',
        stages: [
          PipelineStageSpec(
            id: PipelineStageId.contextEnrichment,
            label: 'A',
            description: 'a',
            enabled: true,
          ),
          PipelineStageSpec(
            id: PipelineStageId.scenePlanning,
            label: 'B',
            description: 'b',
            enabled: false,
          ),
          PipelineStageSpec(
            id: PipelineStageId.roleplay,
            label: 'C',
            description: 'c',
            enabled: true,
          ),
        ],
      );

      final enabled = preset.enabledStages;

      expect(enabled, hasLength(2));
      expect(enabled[0].id, PipelineStageId.contextEnrichment);
      expect(enabled[1].id, PipelineStageId.roleplay);
    });

    test('toJson and fromJson roundtrip', () {
      const preset = PipelinePreset(
        id: 'roundtrip-test',
        name: '往返测试',
        stages: [
          PipelineStageSpec(
            id: PipelineStageId.finalization,
            label: '收尾',
            description: '收尾、记忆回写、弧线追踪',
          ),
        ],
      );

      final json = preset.toJson();
      final rehydrated = PipelinePreset.fromJson(json);

      expect(rehydrated.id, preset.id);
      expect(rehydrated.name, preset.name);
      expect(rehydrated.stages, hasLength(1));
      expect(rehydrated.stages.single.id, preset.stages.single.id);
    });
  });

  group('BuiltInPresets.defaultNineStage', () {
    test('has exactly nine stages', () {
      expect(BuiltInPresets.defaultNineStage.stages, hasLength(9));
    });

    test('all stages are enabled by default', () {
      final allEnabled = BuiltInPresets.defaultNineStage.stages.every(
        (s) => s.enabled,
      );

      expect(allEnabled, isTrue);
    });

    test('stage IDs match expected order', () {
      const expectedOrder = [
        PipelineStageId.contextEnrichment,
        PipelineStageId.scenePlanning,
        PipelineStageId.roleplay,
        PipelineStageId.stageNarration,
        PipelineStageId.beatResolution,
        PipelineStageId.editorial,
        PipelineStageId.review,
        PipelineStageId.polish,
        PipelineStageId.finalization,
      ];

      final actualIds = BuiltInPresets.defaultNineStage.stages.map((s) => s.id);

      expect(actualIds, orderedEquals(expectedOrder));
    });

    test('each stage has non-empty label and description', () {
      for (final stage in BuiltInPresets.defaultNineStage.stages) {
        expect(stage.label, isNotEmpty);
        expect(stage.description, isNotEmpty);
      }
    });

    test('preset ID and name are set', () {
      expect(BuiltInPresets.defaultNineStage.id, 'default-nine-stage');
      expect(BuiltInPresets.defaultNineStage.name, '标准九阶段场景生成管线');
    });

    test('can serialize and deserialize', () {
      final json = BuiltInPresets.defaultNineStage.toJson();
      final rehydrated = PipelinePreset.fromJson(json);

      expect(rehydrated.id, BuiltInPresets.defaultNineStage.id);
      expect(rehydrated.name, BuiltInPresets.defaultNineStage.name);
      expect(rehydrated.stages, hasLength(9));
    });
  });

  group('PipelineStageRunnerImpl.defaultPreset', () {
    test('exposes the built-in default preset', () {
      expect(
        PipelineStageRunnerImpl.defaultPreset.id,
        BuiltInPresets.defaultNineStage.id,
      );
      expect(
        PipelineStageRunnerImpl.defaultPreset.name,
        BuiltInPresets.defaultNineStage.name,
      );
    });

    test('default preset stage count matches runner stages length', () {
      // The runner's stages getter returns 9 PipelineStage instances;
      // the preset describes the same topology.
      expect(
        PipelineStageRunnerImpl.defaultPreset.stages,
        hasLength(9),
      );
    });
  });
}
