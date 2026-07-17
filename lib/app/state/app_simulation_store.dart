import 'dart:async';

import 'package:flutter/foundation.dart';

import '../logging/app_event_log.dart';
import 'app_project_scoped_store.dart';
import 'app_settings_store.dart';
import 'app_simulation_storage.dart';
import 'persist_guard.dart';
import 'project_storage.dart';
import 'simulation_models.dart';
import 'simulation_real_agent_runner.dart';
import 'simulation_serialization.dart';
import 'simulation_snapshot_builder.dart';

export 'simulation_models.dart';
export 'simulation_snapshot_builder.dart'
    show RealAgentConfig, kRealSimulationAgents;

class AppSimulationStore extends AppProjectScopedStore {
  AppSimulationStore({
    AppSimulationStorage? storage,
    super.workspaceStore,
    super.eventBus,
    AppEventLog? eventLog,
  }) : _storage = storage ?? createDefaultAppSimulationStorage(),
       _eventLog = eventLog,
       _snapshot = AppSimulationSnapshot.empty(),
       super(fallbackProjectId: 'project-yuechao') {
    onRestore();
  }

  AppSimulationStore.preview(SimulationStatus status)
    : _storage = InMemoryAppSimulationStorage(),
      _eventLog = null,
      _snapshot = AppSimulationSnapshot.empty(),
      super(fallbackProjectId: 'preview') {
    _template = _templateFromStatus(status);
    _snapshot = _buildSnapshot();
    _clearTimers();
  }

  // -- State fields --

  AppSimulationSnapshot _snapshot;
  final AppSimulationStorage _storage;
  final AppEventLog? _eventLog;
  final SimulationRealAgentRunner _realAgentRunner =
      const SimulationRealAgentRunner();

  SimulationTemplate _template = SimulationTemplate.none;
  SimulationRunMode _runMode = SimulationRunMode.template;
  int _runToken = 0;
  final List<Timer> _timers = [];
  final Map<SimulationParticipant, String> _promptOverrides = {};
  final List<SimulationChatMessage> _extraMessages = [];
  String? _activeRunCorrelationId;

  @override
  ProjectStorage get persistenceStorage => _storage;

  // -- Public API --

  AppSimulationSnapshot get snapshot => _snapshot;

  Map<String, Object?> exportJson() => _toJson();

  static AppSimulationSnapshot previewSnapshot(SimulationStatus status) {
    final store = AppSimulationStore.preview(status);
    return store.snapshot;
  }

  void startSuccessfulRun({AppEventLog? eventLog}) {
    _beginTemplateRun(eventLog: eventLog);
    _template = SimulationTemplate.runningStepOne;
    unawaited(
      _logRunEvent(
        eventLog: eventLog,
        action: 'simulation.run.started',
        status: AppEventLogStatus.started,
        message: 'Simulation run started.',
      ),
    );
    _rebuildSnapshot();

    final token = _runToken;
    _schedule(token, const Duration(milliseconds: 280), () {
      _template = SimulationTemplate.runningStepTwo;
      _rebuildSnapshot();
    });
    _schedule(token, const Duration(milliseconds: 720), () {
      _completeRun(
        template: SimulationTemplate.completed,
        action: 'simulation.run.succeeded',
        status: AppEventLogStatus.succeeded,
        message: 'Simulation run completed successfully.',
        eventLog: eventLog,
      );
    });
  }

  void startFailureRun({AppEventLog? eventLog}) {
    _beginTemplateRun(eventLog: eventLog);
    _template = SimulationTemplate.runningStepOne;
    unawaited(
      _logRunEvent(
        eventLog: eventLog,
        action: 'simulation.run.started',
        status: AppEventLogStatus.started,
        message: 'Simulation run started.',
      ),
    );
    _rebuildSnapshot();

    final token = _runToken;
    _schedule(token, const Duration(milliseconds: 480), () {
      _completeRun(
        template: SimulationTemplate.failed,
        action: 'simulation.run.failed',
        status: AppEventLogStatus.failed,
        message: 'Simulation run failed.',
        eventLog: eventLog,
        errorCode: 'simulation_failed',
      );
    });
  }

  void reset({AppEventLog? eventLog}) {
    markMutated();
    _cancelActiveRunIfNeeded(eventLog: eventLog, reason: 'reset');
    _clearTimers();
    _extraMessages.clear();
    _runMode = SimulationRunMode.template;
    _template = SimulationTemplate.none;
    _runToken += 1;
    _activeRunCorrelationId = null;
    _rebuildSnapshot();
  }

  void ensurePreviewRun(SimulationStatus status, {bool notify = true}) {
    if (_template != SimulationTemplate.none ||
        status == SimulationStatus.none) {
      return;
    }
    markMutated();
    _clearTimers();
    _runMode = SimulationRunMode.template;
    _template = _templateFromStatus(status);
    _snapshot = _buildSnapshot();
    if (notify) {
      notifyListeners();
    }
  }

  void updateParticipantPrompt(
    SimulationParticipant participant,
    String prompt,
  ) {
    markMutated();
    final normalized = prompt.trim().replaceFirst(RegExp(r'^认知：\s*'), '');
    if (normalized.isEmpty) {
      _promptOverrides.remove(participant);
    } else {
      _promptOverrides[participant] = normalized;
    }
    if (_template != SimulationTemplate.none) {
      _extraMessages.add(
        SimulationChatMessage(
          sender: '导演',
          title: 'Prompt 更新',
          body: '${participant.shortName} 的认知 Prompt 已更新：$normalized',
          tone: SimulationChatTone.director,
          alignEnd: false,
          kind: SimulationMessageKind.summary,
        ),
      );
    }
    _rebuildSnapshot();
  }

  void sendDirectorFeedback(String feedback) {
    final normalized = feedback.trim();
    if (normalized.isEmpty || _template == SimulationTemplate.none) return;
    markMutated();
    _extraMessages.add(
      SimulationChatMessage(
        sender: '你',
        title: '给导演的补充要求',
        body: normalized,
        tone: SimulationChatTone.user,
        alignEnd: false,
        kind: SimulationMessageKind.summary,
      ),
    );
    _extraMessages.add(
      SimulationChatMessage(
        sender: '导演',
        title: '任务调整',
        body: '收到补充要求：$normalized。接下来会根据这条意见重新分配任务。',
        tone: SimulationChatTone.director,
        alignEnd: false,
        kind: SimulationMessageKind.summary,
      ),
    );
    _rebuildSnapshot();
  }

  void importJson(Map<String, Object?> data) {
    markMutated();
    _clearTimers();
    _template = decodeTemplateName(data['template'] as String?);
    _runMode = decodeRunModeName(data['runMode'] as String?);
    _promptOverrides
      ..clear()
      ..addAll(decodePromptOverrides(data['promptOverrides']));
    _extraMessages
      ..clear()
      ..addAll(decodeMessages(data['extraMessages']));
    _snapshot = _buildSnapshot();
    unawaited(
      safePersist(
        () => _storage.save(_toJson(), projectId: activeProjectId),
        eventBus: eventBus,
      ),
    );
    notifyListeners();
  }

  Future<RealAgentSimulationResult> runRealAgentSession({
    required AppSettingsStore settingsStore,
    required String sceneContext,
    String authorGoal = '',
    int rounds = 2,
    AppEventLog? eventLog,
  }) async {
    markMutated();
    _cancelActiveRunIfNeeded(eventLog: eventLog, reason: 'restarted');
    _clearTimers();
    _extraMessages.clear();
    _promptOverrides
      ..clear()
      ..addAll({
        for (final agent in kRealSimulationAgents)
          agent.participant: agent.prompt,
      });
    _runToken += 1;
    _runMode = SimulationRunMode.realAgents;
    _template = SimulationTemplate.runningStepOne;
    _activeRunCorrelationId = (eventLog ?? _eventLog)?.newCorrelationId(
      'simulation-real-agent-run',
    );
    unawaited(
      _logRunEvent(
        eventLog: eventLog,
        action: 'simulation.real_agents.started',
        status: AppEventLogStatus.started,
        message: 'Real multi-agent simulation started.',
      ),
    );
    _rebuildSnapshot();

    final result = await _realAgentRunner.run(
      settingsStore: settingsStore,
      sceneContext: sceneContext,
      agents: kRealSimulationAgents,
      authorGoal: authorGoal,
      rounds: rounds,
    );

    _extraMessages.addAll(result.messages);

    if (result.succeeded) {
      _completeRun(
        template: SimulationTemplate.completed,
        action: 'simulation.real_agents.succeeded',
        status: AppEventLogStatus.succeeded,
        message: 'Real multi-agent simulation completed successfully.',
        eventLog: eventLog,
      );
    } else {
      _completeRun(
        template: SimulationTemplate.failed,
        action: 'simulation.real_agents.failed',
        status: AppEventLogStatus.failed,
        message:
            'Real multi-agent simulation failed${result.failureDetail != null ? ' with an exception.' : '.'}',
        eventLog: eventLog,
        errorCode: 'exception',
      );
    }
    return result;
  }

  // -- Project-scoped store overrides --

  @override
  void onProjectScopeChanged(String previousProjectId, String nextProjectId) {
    _cancelActiveRunIfNeeded(eventLog: null, reason: 'project_scope_changed');
    _clearTimers();
    _template = SimulationTemplate.none;
    _runMode = SimulationRunMode.template;
    _promptOverrides.clear();
    _extraMessages.clear();
    _snapshot = AppSimulationSnapshot.empty();
    _activeRunCorrelationId = null;
  }

  @override
  Future<void> onRestore() async {
    final restoreVersion = mutationVersion;
    final data = await _storage.load(projectId: activeProjectId);
    if (data == null) return;
    if (restoreVersion != mutationVersion) return;
    _template = decodeTemplateName(data['template'] as String?);
    _runMode = decodeRunModeName(data['runMode'] as String?);
    _promptOverrides
      ..clear()
      ..addAll(decodePromptOverrides(data['promptOverrides']));
    _extraMessages
      ..clear()
      ..addAll(decodeMessages(data['extraMessages']));
    _snapshot = _buildSnapshot();
    notifyListeners();
  }

  @override
  Future<void> clearDeletedProjectScope(String projectId) =>
      _storage.clearProject(projectId);

  @override
  void dispose() {
    _clearTimers();
    super.dispose();
  }

  // -- Private helpers --

  void _beginTemplateRun({AppEventLog? eventLog}) {
    markMutated();
    _cancelActiveRunIfNeeded(eventLog: eventLog, reason: 'restarted');
    _clearTimers();
    _extraMessages.clear();
    _runMode = SimulationRunMode.template;
    _runToken += 1;
    _activeRunCorrelationId = (eventLog ?? _eventLog)?.newCorrelationId(
      'simulation-run',
    );
  }

  void _schedule(int token, Duration delay, VoidCallback update) {
    late final Timer timer;
    timer = Timer(delay, () {
      _timers.remove(timer);
      if (token != _runToken) return;
      update();
      notifyListeners();
    });
    _timers.add(timer);
  }

  void _clearTimers() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }

  void _completeRun({
    required SimulationTemplate template,
    required String action,
    required AppEventLogStatus status,
    required String message,
    AppEventLog? eventLog,
    String? errorCode,
  }) {
    _template = template;
    unawaited(
      _logRunEvent(
        eventLog: eventLog,
        action: action,
        status: status,
        message: message,
        errorCode: errorCode,
      ),
    );
    _rebuildSnapshot();
    _activeRunCorrelationId = null;
  }

  void _cancelActiveRunIfNeeded({
    AppEventLog? eventLog,
    required String reason,
  }) {
    if (_template != SimulationTemplate.runningStepOne &&
        _template != SimulationTemplate.runningStepTwo) {
      return;
    }
    unawaited(
      _logRunEvent(
        eventLog: eventLog,
        action: 'simulation.run.cancelled',
        status: AppEventLogStatus.cancelled,
        message: 'Simulation run was cancelled.',
        errorCode: reason,
      ),
    );
    _activeRunCorrelationId = null;
  }

  SimulationBuildContext get _buildContext => SimulationBuildContext(
    runMode: _runMode,
    promptOverrides: Map.unmodifiable(_promptOverrides),
    extraMessages: List.unmodifiable(_extraMessages),
    sceneLabel: _currentSceneLabel(),
    currentSceneId: _currentSceneId,
    completedRealRoundsLabel: completedRealRoundsLabel(_extraMessages),
  );

  AppSimulationSnapshot _buildSnapshot() {
    final participants = buildParticipants(
      runMode: _runMode,
      promptOverrides: _promptOverrides,
      realAgents: kRealSimulationAgents,
    );
    return buildSnapshotForTemplate(
      _template,
      context: _buildContext,
      participants: participants,
    );
  }

  void _rebuildSnapshot() {
    _snapshot = _buildSnapshot();
    unawaited(
      safePersist(
        () => _storage.save(_toJson(), projectId: activeProjectId),
        eventBus: eventBus,
      ),
    );
    notifyListeners();
  }

  Map<String, Object?> _toJson() => encodeSimulationJson(
    template: _template,
    runMode: _runMode,
    promptOverrides: _promptOverrides,
    extraMessages: _extraMessages,
  );

  String _currentSceneLabel() {
    final ws = workspaceStore;
    if (ws == null || ws.currentProjectId.isEmpty) return '';
    return ws.currentProjectBreadcrumb;
  }

  String? get _currentSceneId {
    final ws = workspaceStore;
    if (ws == null || ws.currentProjectId.isEmpty) return null;
    return ws.currentProject.sceneId;
  }

  static SimulationTemplate _templateFromStatus(SimulationStatus status) =>
      switch (status) {
        SimulationStatus.running => SimulationTemplate.runningStepOne,
        SimulationStatus.completed => SimulationTemplate.completed,
        SimulationStatus.failed => SimulationTemplate.failed,
        SimulationStatus.none => SimulationTemplate.none,
      };

  Future<void> _logRunEvent({
    required String action,
    required AppEventLogStatus status,
    required String message,
    AppEventLog? eventLog,
    String? errorCode,
  }) {
    final log = eventLog ?? _eventLog;
    if (log == null) return Future<void>.value();
    return log.logBestEffort(
      level: status == AppEventLogStatus.failed
          ? AppEventLogLevel.error
          : AppEventLogLevel.info,
      category: AppEventLogCategory.simulation,
      action: action,
      status: status,
      message: message,
      correlationId: _activeRunCorrelationId,
      projectId: activeProjectId,
      sceneId: _currentSceneId,
      errorCode: errorCode,
      metadata: {'template': _template.name},
    );
  }
}
