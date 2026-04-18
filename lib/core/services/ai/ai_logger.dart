import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// AI 模型输入输出文件日志服务
/// 将每次 AI 调用的请求和响应完整记录到 JSONL 日志文件中
class AILogger {
  AILogger._();
  static final AILogger instance = AILogger._();

  Directory? _logDir;
  bool _initialized = false;

  /// 日志保留天数
  static const int _retentionDays = 7;

  /// 确保日志目录存在
  Future<Directory> _ensureLogDir() async {
    if (_logDir != null && _initialized) return _logDir!;

    final baseDir = await getApplicationDocumentsDirectory();
    _logDir = Directory(p.join(baseDir.path, 'writing_assistant', 'ai_logs'));
    if (!await _logDir!.exists()) {
      await _logDir!.create(recursive: true);
    }
    _initialized = true;
    return _logDir!;
  }

  /// 获取当天日志文件路径
  Future<File> _getLogFile() async {
    final dir = await _ensureLogDir();
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return File(p.join(dir.path, 'ai_$dateStr.log'));
  }

  /// 写入一条日志记录（异步，不阻塞主流程）
  Future<void> _write(Map<String, dynamic> record) async {
    try {
      final file = await _getLogFile();
      record['timestamp'] = DateTime.now().toIso8601String();
      final line = jsonEncode(record);
      await file.writeAsString(
        '$line\n',
        mode: FileMode.append,
        flush: false,
      );
    } catch (_) {
      // 日志写入失败不应影响业务流程
    }
  }

  /// 记录 AI 请求
  Future<void> logRequest({
    required String requestId,
    required String functionType,
    required String modelId,
    String? systemPrompt,
    required String userPrompt,
    double temperature = 1.0,
    int? maxTokens,
    List<Map<String, dynamic>>? tools,
  }) async {
    final record = <String, dynamic>{
      'type': 'request',
      'requestId': requestId,
      'function': functionType,
      'modelId': modelId,
      'systemPrompt': systemPrompt,
      'userPrompt': userPrompt,
      'temperature': temperature,
      if (maxTokens != null) 'maxTokens': maxTokens,
      if (tools != null) 'tools': tools,
    };
    await _write(record);
    unawaited(_cleanupOldLogs());
  }

  /// 记录 AI 响应
  Future<void> logResponse({
    required String requestId,
    required String functionType,
    required String modelId,
    required String content,
    String? thinking,
    List<Map<String, dynamic>>? toolCalls,
    required int inputTokens,
    required int outputTokens,
    required int responseTimeMs,
    String? requestIdFromProvider,
  }) async {
    final record = <String, dynamic>{
      'type': 'response',
      'requestId': requestId,
      'function': functionType,
      'modelId': modelId,
      'content': content,
      if (thinking != null) 'thinking': thinking,
      if (toolCalls != null && toolCalls.isNotEmpty) 'toolCalls': toolCalls,
      'inputTokens': inputTokens,
      'outputTokens': outputTokens,
      'responseTimeMs': responseTimeMs,
      if (requestIdFromProvider != null)
        'providerRequestId': requestIdFromProvider,
    };
    await _write(record);
  }

  /// 记录流式响应完成
  Future<void> logStreamResponse({
    required String requestId,
    required String functionType,
    required String modelId,
    required String content,
    required int inputTokens,
    required int outputTokens,
    required int responseTimeMs,
  }) async {
    final record = <String, dynamic>{
      'type': 'stream_response',
      'requestId': requestId,
      'function': functionType,
      'modelId': modelId,
      'content': content,
      'inputTokens': inputTokens,
      'outputTokens': outputTokens,
      'responseTimeMs': responseTimeMs,
    };
    await _write(record);
  }

  /// 记录 AI 错误
  Future<void> logError({
    required String requestId,
    required String functionType,
    required String modelId,
    required String error,
    int? statusCode,
    int responseTimeMs = 0,
  }) async {
    final record = <String, dynamic>{
      'type': 'error',
      'requestId': requestId,
      'function': functionType,
      'modelId': modelId,
      'error': error,
      if (statusCode != null) 'statusCode': statusCode,
      'responseTimeMs': responseTimeMs,
    };
    await _write(record);
  }

  /// 记录 Agent 迭代
  Future<void> logAgentIteration({
    required String requestId,
    required int iteration,
    required String content,
    String? thinking,
    List<Map<String, dynamic>>? toolCalls,
    Map<String, dynamic>? toolResult,
  }) async {
    final record = <String, dynamic>{
      'type': 'agent_iteration',
      'requestId': requestId,
      'iteration': iteration,
      'content': content,
      if (thinking != null) 'thinking': thinking,
      if (toolCalls != null && toolCalls.isNotEmpty) 'toolCalls': toolCalls,
      if (toolResult != null) 'toolResult': toolResult,
    };
    await _write(record);
  }

  /// 清理过期日志文件
  Future<void> _cleanupOldLogs() async {
    try {
      final dir = _logDir;
      if (dir == null) return;

      final cutoff = DateTime.now().subtract(Duration(days: _retentionDays));
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.log')) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoff)) {
            await entity.delete();
          }
        }
      }
    } catch (_) {
      // 清理失败不影响业务
    }
  }
}

/// 避免 await 警告的辅助函数
void unawaited(Future<void>? future) {}
