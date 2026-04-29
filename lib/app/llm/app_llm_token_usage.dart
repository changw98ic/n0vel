import 'app_llm_client_types.dart';

class AppLlmTokenUsageRecord {
  const AppLlmTokenUsageRecord({
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
    required this.timestampMs,
    this.model,
    this.succeeded,
  });

  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;
  final int timestampMs;
  final String? model;
  final bool? succeeded;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'promptTokens': promptTokens,
      'completionTokens': completionTokens,
      'totalTokens': totalTokens,
      'timestampMs': timestampMs,
      if (model != null) 'model': model,
      if (succeeded != null) 'succeeded': succeeded,
    };
  }
}

class AppLlmTokenUsageReport {
  const AppLlmTokenUsageReport({
    required this.totalPromptTokens,
    required this.totalCompletionTokens,
    required this.totalTokens,
    required this.callCount,
    required this.successfulCallCount,
    required this.failedCallCount,
    required this.generatedAtMs,
  });

  final int totalPromptTokens;
  final int totalCompletionTokens;
  final int totalTokens;
  final int callCount;
  final int successfulCallCount;
  final int failedCallCount;
  final int generatedAtMs;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'totalPromptTokens': totalPromptTokens,
      'totalCompletionTokens': totalCompletionTokens,
      'totalTokens': totalTokens,
      'callCount': callCount,
      'successfulCallCount': successfulCallCount,
      'failedCallCount': failedCallCount,
      'generatedAtMs': generatedAtMs,
    };
  }

  String toMarkdown() {
    final buffer = StringBuffer();
    buffer.writeln('# Token 用量报告');
    buffer.writeln('');
    buffer.writeln('| 指标 | 数值 |');
    buffer.writeln('|------|------|');
    buffer.writeln('| 总调用次数 | $callCount |');
    buffer.writeln('| 成功调用 | $successfulCallCount |');
    buffer.writeln('| 失败调用 | $failedCallCount |');
    buffer.writeln('| Prompt Tokens | $totalPromptTokens |');
    buffer.writeln('| Completion Tokens | $totalCompletionTokens |');
    buffer.writeln('| Total Tokens | $totalTokens |');
    return buffer.toString();
  }
}

class AppLlmTokenUsageStats {
  final List<AppLlmTokenUsageRecord> _records = <AppLlmTokenUsageRecord>[];

  List<AppLlmTokenUsageRecord> get records => List<AppLlmTokenUsageRecord>.unmodifiable(_records);

  void record(AppLlmChatResult result, {String? model}) {
    final record = AppLlmTokenUsageRecord(
      promptTokens: result.promptTokens,
      completionTokens: result.completionTokens,
      totalTokens: result.totalTokens,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      model: model,
      succeeded: result.succeeded,
    );
    _records.add(record);
  }

  int get totalPromptTokens {
    var sum = 0;
    for (final record in _records) {
      final value = record.promptTokens;
      if (value != null) {
        sum += value;
      }
    }
    return sum;
  }

  int get totalCompletionTokens {
    var sum = 0;
    for (final record in _records) {
      final value = record.completionTokens;
      if (value != null) {
        sum += value;
      }
    }
    return sum;
  }

  int get totalTokens {
    var sum = 0;
    for (final record in _records) {
      final value = record.totalTokens;
      if (value != null) {
        sum += value;
      }
    }
    return sum;
  }

  int get callCount => _records.length;

  int get successfulCallCount {
    var count = 0;
    for (final record in _records) {
      if (record.succeeded == true) {
        count++;
      }
    }
    return count;
  }

  int get failedCallCount {
    var count = 0;
    for (final record in _records) {
      if (record.succeeded == false) {
        count++;
      }
    }
    return count;
  }

  AppLlmTokenUsageReport generateReport() {
    return AppLlmTokenUsageReport(
      totalPromptTokens: totalPromptTokens,
      totalCompletionTokens: totalCompletionTokens,
      totalTokens: totalTokens,
      callCount: callCount,
      successfulCallCount: successfulCallCount,
      failedCallCount: failedCallCount,
      generatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  void clear() {
    _records.clear();
  }
}
