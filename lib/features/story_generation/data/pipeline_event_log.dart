import 'dart:convert';
import 'dart:io';

import '../domain/contracts/event_log.dart';
import '../domain/contracts/stage_runner.dart';

/// Maximum events held in the in-memory ring buffer.
const int _defaultRingBufferSize = 1024;

/// Concrete [PipelineEventLog] with JSONL persistence and in-memory ring buffer.
///
/// Reuses the JSONL pattern from [AppEventLogStorage] but is scoped to
/// pipeline events only.
class PipelineEventLogImpl extends PipelineEventLog {
  PipelineEventLogImpl({
    String? jsonlPath,
    int ringBufferSize = _defaultRingBufferSize,
  }) : _jsonlPath = jsonlPath,
       _ringBufferSize = ringBufferSize;

  final String? _jsonlPath;
  final int _ringBufferSize;
  final List<PipelineEvent> _buffer = [];
  IOSink? _sink;
  bool _flushing = false;

  @override
  void emit(PipelineEvent event) {
    _buffer.add(event);
    if (_buffer.length > _ringBufferSize) {
      _buffer.removeAt(0);
    }
    if (_jsonlPath != null) {
      _appendToFile(event);
    }
  }

  @override
  List<PipelineEvent> query({
    String? stageId,
    String? eventType,
    FailureCode? failureCode,
  }) {
    return _buffer.where((e) {
      if (stageId != null && e.stageId != stageId) return false;
      if (eventType != null && e.eventType != eventType) return false;
      if (failureCode != null && e.failureCode != failureCode) return false;
      return true;
    }).toList();
  }

  @override
  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      await _sink?.flush();
    } finally {
      _flushing = false;
    }
  }

  void _appendToFile(PipelineEvent event) {
    final path = _jsonlPath;
    if (path == null) return;
    _sink ??= File(path).openWrite(mode: FileMode.append);
    _sink!.writeln(jsonEncode(event.toJson()));
  }

  /// Release resources. Call when the log is no longer needed.
  Future<void> dispose() async {
    await flush();
    await _sink?.close();
    _sink = null;
  }
}
