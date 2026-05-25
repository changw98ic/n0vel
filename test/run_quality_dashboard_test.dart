import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_writer/app/llm/app_llm_call_trace.dart';
import 'package:novel_writer/app/state/story_generation_run_store.dart';
import 'package:novel_writer/app/theme/app_theme.dart';
import 'package:novel_writer/features/audit/presentation/run_quality_dashboard.dart';

void main() {
  test('builder aggregates run quality and model usage metrics', () {
    final snapshot = const RunQualityDashboardSnapshotBuilder().build(
      history: const [
        RunQualityHistoryEntry(
          runId: 'run-success',
          sceneId: 'scene-a',
          sceneLabel: '第 1 章 · 码头',
          status: StoryGenerationRunStatus.completed,
          startedAtMs: 1710000000000,
          durationMs: 1000,
          model: 'gpt-fast',
          stageCount: 9,
          failedStageCount: 0,
          summary: '通过全部 hard gates',
        ),
        RunQualityHistoryEntry(
          runId: 'run-failed',
          sceneId: 'scene-b',
          sceneLabel: '第 1 章 · 仓库',
          status: StoryGenerationRunStatus.failed,
          startedAtMs: 1710000005000,
          durationMs: 3000,
          model: 'gpt-fast',
          stageCount: 9,
          failedStageCount: 2,
          summary: 'Review hard gate 失败',
        ),
      ],
      modelTraces: const [
        AppLlmCallTraceEntry(
          timestampMs: 1710000000000,
          traceName: 'stage.narration',
          model: 'gpt-fast',
          host: 'localhost',
          messageCount: 4,
          maxTokens: 2000,
          succeeded: true,
          latencyMs: 500,
          promptTokens: 700,
          completionTokens: 300,
          totalTokens: 1000,
          estimatedPromptTokens: 700,
          estimatedCompletionTokens: 300,
          promptChars: 2800,
          completionChars: 1200,
          metadata: {},
        ),
        AppLlmCallTraceEntry(
          timestampMs: 1710000003000,
          traceName: 'stage.review',
          model: 'gpt-fast',
          host: 'localhost',
          messageCount: 2,
          maxTokens: 1000,
          succeeded: false,
          latencyMs: 1500,
          promptTokens: null,
          completionTokens: null,
          totalTokens: null,
          estimatedPromptTokens: 250,
          estimatedCompletionTokens: 50,
          promptChars: 1000,
          completionChars: 200,
          metadata: {},
        ),
      ],
    );

    expect(snapshot.metrics.totalRuns, 2);
    expect(snapshot.metrics.successCount, 1);
    expect(snapshot.metrics.failureCount, 1);
    expect(snapshot.metrics.averageDurationMs, 2000);
    expect(snapshot.metrics.successRateLabel, '50%');
    expect(snapshot.modelUsage.single.model, 'gpt-fast');
    expect(snapshot.modelUsage.single.callCount, 2);
    expect(snapshot.modelUsage.single.failureCount, 1);
    expect(snapshot.modelUsage.single.totalTokens, 1300);
    expect(snapshot.modelUsage.single.averageLatencyMs, 1000);
  });

  testWidgets('dashboard renders metrics, filters failed runs, and exports', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const RunQualityDashboardPage(
            currentSnapshot: StoryGenerationRunSnapshot(
              status: StoryGenerationRunStatus.idle,
              sceneId: '',
              sceneLabel: '',
              headline: '',
              summary: '',
              stageSummary: '',
            ),
            history: [
              RunQualityHistoryEntry(
                runId: 'run-success',
                sceneId: 'scene-a',
                sceneLabel: '第 1 章 · 码头',
                status: StoryGenerationRunStatus.completed,
                startedAtMs: 1710000000000,
                durationMs: 1000,
                model: 'gpt-fast',
                stageCount: 9,
                failedStageCount: 0,
                summary: '通过全部 hard gates',
              ),
              RunQualityHistoryEntry(
                runId: 'run-failed',
                sceneId: 'scene-b',
                sceneLabel: '第 1 章 · 仓库',
                status: StoryGenerationRunStatus.failed,
                startedAtMs: 1710000005000,
                durationMs: 3000,
                model: 'gpt-fast',
                stageCount: 9,
                failedStageCount: 2,
                summary: 'Review hard gate 失败',
              ),
            ],
            modelTraces: [
              AppLlmCallTraceEntry(
                timestampMs: 1710000000000,
                traceName: 'stage.narration',
                model: 'gpt-fast',
                host: 'localhost',
                messageCount: 4,
                maxTokens: 2000,
                succeeded: true,
                latencyMs: 500,
                promptTokens: 700,
                completionTokens: 300,
                totalTokens: 1000,
                estimatedPromptTokens: 700,
                estimatedCompletionTokens: 300,
                promptChars: 2800,
                completionChars: 1200,
                metadata: {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(RunQualityDashboardPage.titleKey), findsOneWidget);
    expect(find.byKey(RunQualityDashboardPage.metricsKey), findsOneWidget);
    expect(find.byKey(RunQualityDashboardPage.historyKey), findsOneWidget);
    expect(find.byKey(RunQualityDashboardPage.modelUsageKey), findsOneWidget);
    expect(find.textContaining('成功 1'), findsOneWidget);
    expect(find.textContaining('失败 1'), findsOneWidget);
    expect(find.textContaining('平均耗时 2.0s'), findsOneWidget);
    expect(find.text('gpt-fast'), findsAtLeastNWidgets(1));
    expect(find.text('第 1 章 · 码头'), findsOneWidget);

    await tester.tap(find.byKey(RunQualityDashboardPage.failedFilterKey));
    await tester.pump();

    expect(find.text('第 1 章 · 仓库'), findsOneWidget);
    expect(find.text('第 1 章 · 码头'), findsNothing);

    await tester.tap(find.byKey(RunQualityDashboardPage.exportButtonKey));
    await tester.pump();

    expect(
      find.byKey(RunQualityDashboardPage.exportPreviewKey),
      findsOneWidget,
    );
    expect(find.textContaining('## Run Quality Export'), findsOneWidget);
    expect(find.textContaining('gpt-fast'), findsWidgets);
  });

  testWidgets('dashboard supports compact vertical layout', (tester) async {
    tester.view.physicalSize = const Size(720, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const RunQualityDashboardPage(
            currentSnapshot: StoryGenerationRunSnapshot(
              status: StoryGenerationRunStatus.idle,
              sceneId: '',
              sceneLabel: '',
              headline: '',
              summary: '',
              stageSummary: '',
            ),
            history: [
              RunQualityHistoryEntry(
                runId: 'run-success',
                sceneId: 'scene-a',
                sceneLabel: '第 1 章 · 码头',
                status: StoryGenerationRunStatus.completed,
                startedAtMs: 1710000000000,
                durationMs: 1000,
                model: 'gpt-fast',
                stageCount: 9,
                failedStageCount: 0,
                summary: '通过全部 hard gates',
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(RunQualityDashboardPage.metricsKey), findsOneWidget);
    expect(find.byKey(RunQualityDashboardPage.historyKey), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(RunQualityDashboardPage.modelUsageKey),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(RunQualityDashboardPage.modelUsageKey), findsOneWidget);
  });
}
