import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/story_generation_run_store.dart';
import 'package:novel_writer/features/story_generation/data/pipeline_definition.dart';

void main() {
  group('StoryGenerationRunStageSnapshot', () {
    test(
      'fromPreset creates pending stages from BuiltInPresets.defaultNineStage',
      () {
        const preset = BuiltInPresets.defaultNineStage;
        final timeline = StoryGenerationRunStageSnapshot.fromPreset(preset);

        expect(timeline, hasLength(9));

        expect(timeline[0].stageId, PipelineStageId.contextEnrichment);
        expect(timeline[0].label, '上下文增强');
        expect(timeline[0].status, StoryGenerationRunStageStatus.pending);

        expect(timeline[1].stageId, PipelineStageId.scenePlanning);
        expect(timeline[1].label, '场景规划');
        expect(timeline[1].status, StoryGenerationRunStageStatus.pending);

        expect(timeline[2].stageId, PipelineStageId.roleplay);
        expect(timeline[2].label, '角色扮演');

        expect(timeline[3].stageId, PipelineStageId.stageNarration);
        expect(timeline[3].label, '舞台旁白');

        expect(timeline[4].stageId, PipelineStageId.beatResolution);
        expect(timeline[4].label, '节奏解析');

        expect(timeline[5].stageId, PipelineStageId.editorial);
        expect(timeline[5].label, '编辑草稿');

        expect(timeline[6].stageId, PipelineStageId.review);
        expect(timeline[6].label, '质量审查');

        expect(timeline[7].stageId, PipelineStageId.polish);
        expect(timeline[7].label, '润色');

        expect(timeline[8].stageId, PipelineStageId.finalization);
        expect(timeline[8].label, '收尾');
      },
    );

    test('toJson and fromJson roundtrip preserves all fields', () {
      const original = StoryGenerationRunStageSnapshot(
        stageId: PipelineStageId.scenePlanning,
        label: '场景规划',
        status: StoryGenerationRunStageStatus.failed,
        attempt: 2,
        failureCode: 'orchestrator',
        summary: '强制失败',
      );

      final json = original.toJson();
      final restored = StoryGenerationRunStageSnapshot.fromJson(json);

      expect(restored.stageId, original.stageId);
      expect(restored.label, original.label);
      expect(restored.status, original.status);
      expect(restored.attempt, original.attempt);
      expect(restored.failureCode, original.failureCode);
      expect(restored.summary, original.summary);
    });

    test('fromJson with missing fields uses defaults', () {
      final json = {
        'stageId': 'contextEnrichment',
        'label': '上下文增强',
        // status missing -> defaults to pending
        // attempt missing -> defaults to 1
        // failureCode missing -> defaults to null
        // summary missing -> defaults to null
      };

      final restored = StoryGenerationRunStageSnapshot.fromJson(json);

      expect(restored.stageId, PipelineStageId.contextEnrichment);
      expect(restored.label, '上下文增强');
      expect(restored.status, StoryGenerationRunStageStatus.pending);
      expect(restored.attempt, 1);
      expect(restored.failureCode, isNull);
      expect(restored.summary, isNull);
    });

    test('copyWith creates new instance with updated fields', () {
      const original = StoryGenerationRunStageSnapshot(
        stageId: PipelineStageId.roleplay,
        label: '角色扮演',
        status: StoryGenerationRunStageStatus.pending,
      );

      final updated = original.copyWith(
        status: StoryGenerationRunStageStatus.completed,
        attempt: 1,
      );

      expect(updated.stageId, original.stageId);
      expect(updated.label, original.label);
      expect(updated.status, StoryGenerationRunStageStatus.completed);
      expect(updated.attempt, 1);
    });
  });

  group('StoryGenerationRunSnapshot stageTimeline JSON persistence', () {
    test('toJson includes stageTimeline field', () {
      const snapshot = StoryGenerationRunSnapshot(
        status: StoryGenerationRunStatus.running,
        sceneId: 'scene-1',
        sceneLabel: 'Chapter 1 / Scene 1',
        headline: 'AI 正在准备本章',
        summary: '正在整理章节目标',
        stageSummary: '正在准备候选稿',
        stageTimeline: [
          StoryGenerationRunStageSnapshot(
            stageId: PipelineStageId.contextEnrichment,
            label: '上下文增强',
            status: StoryGenerationRunStageStatus.completed,
          ),
          StoryGenerationRunStageSnapshot(
            stageId: PipelineStageId.scenePlanning,
            label: '场景规划',
            status: StoryGenerationRunStageStatus.running,
          ),
        ],
      );

      final json = snapshot.toJson();

      expect(json['stageTimeline'], isNotNull);
      final timelineJson = json['stageTimeline'] as List<Object?>;
      expect(timelineJson, hasLength(2));
      expect(timelineJson[0], isA<Map>());
      expect(timelineJson[1], isA<Map>());
    });

    test('fromJson with stageTimeline field restores timeline', () {
      final json = {
        'status': 'running',
        'sceneId': 'scene-1',
        'sceneLabel': 'Chapter 1 / Scene 1',
        'headline': 'AI 正在准备本章',
        'summary': '正在整理章节目标',
        'stageSummary': '正在准备候选稿',
        'stageTimeline': [
          {
            'stageId': 'contextEnrichment',
            'label': '上下文增强',
            'status': 'completed',
            'attempt': 1,
          },
          {
            'stageId': 'scenePlanning',
            'label': '场景规划',
            'status': 'running',
            'attempt': 1,
          },
        ],
      };

      final restored = StoryGenerationRunSnapshot.fromJson(json);

      expect(restored.stageTimeline, hasLength(2));
      expect(
        restored.stageTimeline[0].stageId,
        PipelineStageId.contextEnrichment,
      );
      expect(
        restored.stageTimeline[0].status,
        StoryGenerationRunStageStatus.completed,
      );
      expect(restored.stageTimeline[1].stageId, PipelineStageId.scenePlanning);
      expect(
        restored.stageTimeline[1].status,
        StoryGenerationRunStageStatus.running,
      );
    });

    test('fromJson without stageTimeline field uses empty list', () {
      final json = {
        'status': 'running',
        'sceneId': 'scene-1',
        'sceneLabel': 'Chapter 1 / Scene 1',
        'headline': 'AI 正在准备本章',
        'summary': '正在整理章节目标',
        'stageSummary': '正在准备候选稿',
        // stageTimeline missing
      };

      final restored = StoryGenerationRunSnapshot.fromJson(json);

      expect(restored.stageTimeline, isEmpty);
    });

    test('full snapshot JSON roundtrip preserves stageTimeline', () {
      const original = StoryGenerationRunSnapshot(
        status: StoryGenerationRunStatus.failed,
        phase: StoryGenerationRunPhase.fail,
        sceneId: 'scene-1',
        sceneLabel: 'Chapter 1 / Scene 1',
        headline: 'AI 试写失败',
        summary: '试写未完成',
        stageSummary: '失败',
        errorDetail: 'force-failure',
        stageTimeline: [
          StoryGenerationRunStageSnapshot(
            stageId: PipelineStageId.contextEnrichment,
            label: '上下文增强',
            status: StoryGenerationRunStageStatus.completed,
          ),
          StoryGenerationRunStageSnapshot(
            stageId: PipelineStageId.scenePlanning,
            label: '场景规划',
            status: StoryGenerationRunStageStatus.failed,
            failureCode: 'orchestrator',
            summary: '强制失败',
          ),
        ],
      );

      final json = original.toJson();
      final restored = StoryGenerationRunSnapshot.fromJson(json);

      expect(restored.status, original.status);
      expect(restored.phase, original.phase);
      expect(restored.sceneId, original.sceneId);
      expect(restored.sceneLabel, original.sceneLabel);
      expect(restored.headline, original.headline);
      expect(restored.summary, original.summary);
      expect(restored.stageSummary, original.stageSummary);
      expect(restored.errorDetail, original.errorDetail);
      expect(restored.stageTimeline, hasLength(original.stageTimeline.length));

      for (var i = 0; i < original.stageTimeline.length; i++) {
        expect(
          restored.stageTimeline[i].stageId,
          original.stageTimeline[i].stageId,
          reason: 'stageTimeline[$i].stageId',
        );
        expect(
          restored.stageTimeline[i].label,
          original.stageTimeline[i].label,
          reason: 'stageTimeline[$i].label',
        );
        expect(
          restored.stageTimeline[i].status,
          original.stageTimeline[i].status,
          reason: 'stageTimeline[$i].status',
        );
        expect(
          restored.stageTimeline[i].failureCode,
          original.stageTimeline[i].failureCode,
          reason: 'stageTimeline[$i].failureCode',
        );
        expect(
          restored.stageTimeline[i].summary,
          original.stageTimeline[i].summary,
          reason: 'stageTimeline[$i].summary',
        );
      }
    });
  });

  group('StoryGenerationRunSnapshot.copyWith preserves stageTimeline', () {
    test('copyWith without stageTimeline preserves original timeline', () {
      const original = StoryGenerationRunSnapshot(
        status: StoryGenerationRunStatus.running,
        sceneId: 'scene-1',
        sceneLabel: 'Chapter 1 / Scene 1',
        headline: 'AI 正在准备本章',
        summary: '正在整理章节目标',
        stageSummary: '正在准备候选稿',
        stageTimeline: [
          StoryGenerationRunStageSnapshot(
            stageId: PipelineStageId.contextEnrichment,
            label: '上下文增强',
            status: StoryGenerationRunStageStatus.completed,
          ),
        ],
      );

      final updated = original.copyWith(
        status: StoryGenerationRunStatus.completed,
      );

      expect(updated.stageTimeline, hasLength(1));
      expect(
        updated.stageTimeline[0].stageId,
        PipelineStageId.contextEnrichment,
      );
      expect(
        updated.stageTimeline[0].status,
        StoryGenerationRunStageStatus.completed,
      );
      expect(updated.status, StoryGenerationRunStatus.completed);
    });

    test('copyWith with stageTimeline replaces timeline', () {
      const original = StoryGenerationRunSnapshot(
        status: StoryGenerationRunStatus.running,
        sceneId: 'scene-1',
        sceneLabel: 'Chapter 1 / Scene 1',
        headline: 'AI 正在准备本章',
        summary: '正在整理章节目标',
        stageSummary: '正在准备候选稿',
        stageTimeline: [],
      );

      const newTimeline = [
        StoryGenerationRunStageSnapshot(
          stageId: PipelineStageId.scenePlanning,
          label: '场景规划',
          status: StoryGenerationRunStageStatus.failed,
          failureCode: 'orchestrator',
        ),
      ];

      final updated = original.copyWith(stageTimeline: newTimeline);

      expect(updated.stageTimeline, hasLength(1));
      expect(updated.stageTimeline[0].stageId, PipelineStageId.scenePlanning);
      expect(
        updated.stageTimeline[0].status,
        StoryGenerationRunStageStatus.failed,
      );
      expect(updated.stageTimeline[0].failureCode, 'orchestrator');
    });
  });

  group('StoryGenerationRunStageStatus enum values', () {
    test('has four status values', () {
      expect(StoryGenerationRunStageStatus.values, hasLength(4));
      expect(
        StoryGenerationRunStageStatus.values,
        contains(StoryGenerationRunStageStatus.pending),
      );
      expect(
        StoryGenerationRunStageStatus.values,
        contains(StoryGenerationRunStageStatus.running),
      );
      expect(
        StoryGenerationRunStageStatus.values,
        contains(StoryGenerationRunStageStatus.completed),
      );
      expect(
        StoryGenerationRunStageStatus.values,
        contains(StoryGenerationRunStageStatus.failed),
      );
    });
  });
}
