import 'package:novel_writer/features/story_generation/domain/contracts/event_log.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/stage_runner.dart';

/// In-memory [PipelineEventLog] for tests — no disk I/O.
class FakePipelineEventLog extends PipelineEventLog {
  final List<PipelineEvent> _events = [];

  @override
  void emit(PipelineEvent event) => _events.add(event);

  @override
  List<PipelineEvent> query({
    String? stageId,
    String? eventType,
    FailureCode? failureCode,
  }) {
    return _events.where((e) {
      if (stageId != null && e.stageId != stageId) return false;
      if (eventType != null && e.eventType != eventType) return false;
      if (failureCode != null && e.failureCode != failureCode) return false;
      return true;
    }).toList();
  }

  @override
  Future<void> flush() async {}

  /// Direct access for test assertions.
  List<PipelineEvent> get events => List.unmodifiable(_events);

  /// Number of events emitted.
  int get length => _events.length;

  /// Clear all events.
  void clear() => _events.clear();
}
