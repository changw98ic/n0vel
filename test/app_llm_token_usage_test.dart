import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';

void main() {
  group('AppLlmTokenUsageStats', () {
    late AppLlmTokenUsageStats stats;

    setUp(() {
      stats = AppLlmTokenUsageStats();
    });

    test('starts empty', () {
      expect(stats.callCount, 0);
      expect(stats.totalPromptTokens, 0);
      expect(stats.totalCompletionTokens, 0);
      expect(stats.totalTokens, 0);
      expect(stats.successfulCallCount, 0);
      expect(stats.failedCallCount, 0);
      expect(stats.records, isEmpty);
    });

    test('records successful result with tokens', () {
      const result = AppLlmChatResult.success(
        text: 'hello',
        latencyMs: 100,
        promptTokens: 10,
        completionTokens: 5,
        totalTokens: 15,
      );
      stats.record(result, model: 'gpt-4');

      expect(stats.callCount, 1);
      expect(stats.totalPromptTokens, 10);
      expect(stats.totalCompletionTokens, 5);
      expect(stats.totalTokens, 15);
      expect(stats.successfulCallCount, 1);
      expect(stats.failedCallCount, 0);
      expect(stats.records.length, 1);

      final record = stats.records.first;
      expect(record.promptTokens, 10);
      expect(record.completionTokens, 5);
      expect(record.totalTokens, 15);
      expect(record.model, 'gpt-4');
      expect(record.succeeded, true);
    });

    test('records failure result without tokens', () {
      const result = AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.network,
        detail: 'timeout',
      );
      stats.record(result, model: 'gpt-3.5');

      expect(stats.callCount, 1);
      expect(stats.totalPromptTokens, 0);
      expect(stats.totalCompletionTokens, 0);
      expect(stats.totalTokens, 0);
      expect(stats.successfulCallCount, 0);
      expect(stats.failedCallCount, 1);

      final record = stats.records.first;
      expect(record.promptTokens, isNull);
      expect(record.completionTokens, isNull);
      expect(record.totalTokens, isNull);
      expect(record.model, 'gpt-3.5');
      expect(record.succeeded, false);
    });

    test('aggregates multiple records', () {
      stats.record(
        const AppLlmChatResult.success(
          text: 'a',
          promptTokens: 10,
          completionTokens: 5,
          totalTokens: 15,
        ),
      );
      stats.record(
        const AppLlmChatResult.success(
          text: 'b',
          promptTokens: 20,
          completionTokens: 8,
          totalTokens: 28,
        ),
      );
      stats.record(
        const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.server,
        ),
      );

      expect(stats.callCount, 3);
      expect(stats.totalPromptTokens, 30);
      expect(stats.totalCompletionTokens, 13);
      expect(stats.totalTokens, 43);
      expect(stats.successfulCallCount, 2);
      expect(stats.failedCallCount, 1);
    });

    test('ignores null token fields when summing', () {
      stats.record(
        const AppLlmChatResult.success(
          text: 'partial',
          promptTokens: 10,
        ),
      );
      expect(stats.totalPromptTokens, 10);
      expect(stats.totalCompletionTokens, 0);
      expect(stats.totalTokens, 0);
    });

    test('clear removes all records', () {
      stats.record(
        const AppLlmChatResult.success(
          text: 'x',
          promptTokens: 1,
          completionTokens: 1,
          totalTokens: 2,
        ),
      );
      stats.clear();
      expect(stats.callCount, 0);
      expect(stats.records, isEmpty);
    });

    group('generateReport', () {
      test('produces correct report from stats', () {
        stats.record(
          const AppLlmChatResult.success(
            text: 'r1',
            promptTokens: 8,
            completionTokens: 4,
            totalTokens: 12,
          ),
          model: 'm1',
        );
        stats.record(
          const AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.timeout,
          ),
          model: 'm2',
        );

        final report = stats.generateReport();
        expect(report.callCount, 2);
        expect(report.successfulCallCount, 1);
        expect(report.failedCallCount, 1);
        expect(report.totalPromptTokens, 8);
        expect(report.totalCompletionTokens, 4);
        expect(report.totalTokens, 12);
        expect(report.generatedAtMs, greaterThan(0));
      });
    });

    group('AppLlmTokenUsageReport', () {
      test('toJson returns expected map', () {
        const report = AppLlmTokenUsageReport(
          totalPromptTokens: 100,
          totalCompletionTokens: 50,
          totalTokens: 150,
          callCount: 3,
          successfulCallCount: 2,
          failedCallCount: 1,
          generatedAtMs: 1700000000000,
        );

        final json = report.toJson();
        expect(json['totalPromptTokens'], 100);
        expect(json['totalCompletionTokens'], 50);
        expect(json['totalTokens'], 150);
        expect(json['callCount'], 3);
        expect(json['successfulCallCount'], 2);
        expect(json['failedCallCount'], 1);
        expect(json['generatedAtMs'], 1700000000000);
      });

      test('toMarkdown contains key metrics', () {
        const report = AppLlmTokenUsageReport(
          totalPromptTokens: 10,
          totalCompletionTokens: 5,
          totalTokens: 15,
          callCount: 2,
          successfulCallCount: 1,
          failedCallCount: 1,
          generatedAtMs: 1700000000000,
        );

        final md = report.toMarkdown();
        expect(md, contains('Token 用量报告'));
        expect(md, contains('总调用次数'));
        expect(md, contains('2'));
        expect(md, contains('成功调用'));
        expect(md, contains('1'));
        expect(md, contains('失败调用'));
        expect(md, contains('1'));
        expect(md, contains('Prompt Tokens'));
        expect(md, contains('10'));
        expect(md, contains('Completion Tokens'));
        expect(md, contains('5'));
        expect(md, contains('Total Tokens'));
        expect(md, contains('15'));
      });
    });

    group('AppLlmTokenUsageRecord', () {
      test('toJson omits null optional fields', () {
        const record = AppLlmTokenUsageRecord(
          promptTokens: 5,
          timestampMs: 1700000000000,
        );
        final json = record.toJson();
        expect(json['promptTokens'], 5);
        expect(json['timestampMs'], 1700000000000);
        expect(json.containsKey('model'), isFalse);
        expect(json.containsKey('succeeded'), isFalse);
      });

      test('toJson includes optional fields when set', () {
        const record = AppLlmTokenUsageRecord(
          promptTokens: 5,
          completionTokens: 3,
          totalTokens: 8,
          timestampMs: 1700000000000,
          model: 'gpt-4',
          succeeded: true,
        );
        final json = record.toJson();
        expect(json['model'], 'gpt-4');
        expect(json['succeeded'], true);
        expect(json['completionTokens'], 3);
        expect(json['totalTokens'], 8);
      });
    });
  });
}
