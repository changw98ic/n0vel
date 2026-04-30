import 'dart:async';

import 'package:flutter/widgets.dart';

import '../logging/app_event_log.dart';
import '../llm/app_llm_client.dart';
import 'app_project_scoped_store.dart';
import 'app_settings_store.dart';
import 'app_simulation_storage.dart';

enum SimulationStatus { none, running, completed, failed }

enum SimulationStageStatus { pending, active, completed, failed }

enum SimulationParticipant { director, liuXi, yueRen, fuXingzhou, stateMachine }

extension SimulationParticipantCopy on SimulationParticipant {
  String get displayLabel => switch (this) {
    SimulationParticipant.director => '导演 · 调度',
    SimulationParticipant.liuXi => '柳溪 · 焦点',
    SimulationParticipant.yueRen => '岳人 · 对峙',
    SimulationParticipant.fuXingzhou => '傅行舟 · 压力',
    SimulationParticipant.stateMachine => '状态机 · 裁决',
  };

  String get shortName => switch (this) {
    SimulationParticipant.director => '导演',
    SimulationParticipant.liuXi => '柳溪',
    SimulationParticipant.yueRen => '岳人',
    SimulationParticipant.fuXingzhou => '傅行舟',
    SimulationParticipant.stateMachine => '状态机',
  };

  String get defaultPrompt => switch (this) {
    SimulationParticipant.director => '先拆任务，再调节冲突节奏。',
    SimulationParticipant.liuXi => '先抬出异常，再决定追问力度。',
    SimulationParticipant.yueRen => '把回避和试探放在同一轮里。',
    SimulationParticipant.fuXingzhou => '门口压力保持存在，并转移到新的阻力上。',
    SimulationParticipant.stateMachine => '校验前提，保持角色发言归属清楚。',
  };

  String get statusSummary => switch (this) {
    SimulationParticipant.director => '已分配 3 个任务',
    SimulationParticipant.liuXi => '已认领任务 1',
    SimulationParticipant.yueRen => '提出反向意见',
    SimulationParticipant.fuXingzhou => '补充约束细节',
    SimulationParticipant.stateMachine => '持续校验动作前提',
  };
}

enum SimulationChatTone {
  director,
  focusCharacter,
  supportingCharacter,
  stateMachine,
  user,
}

enum SimulationMessageKind { speech, intent, verdict, summary }

class SimulationStageSnapshot {
  const SimulationStageSnapshot({required this.label, required this.status});

  final String label;
  final SimulationStageStatus status;
}

class SimulationParticipantSnapshot {
  const SimulationParticipantSnapshot({
    required this.participant,
    required this.promptSummary,
    required this.statusSummary,
  });

  final SimulationParticipant participant;
  final String promptSummary;
  final String statusSummary;
}

class SimulationChatMessage {
  const SimulationChatMessage({
    required this.sender,
    required this.title,
    required this.body,
    required this.tone,
    required this.alignEnd,
    this.kind = SimulationMessageKind.speech,
  });

  final String sender;
  final String title;
  final String body;
  final SimulationChatTone tone;
  final bool alignEnd;
  final SimulationMessageKind kind;
}

class AppSimulationSnapshot {
  const AppSimulationSnapshot({
    required this.status,
    required this.headline,
    required this.summary,
    required this.sceneLabel,
    required this.turnLabel,
    required this.turnSummary,
    required this.footerHint,
    required this.stageSummary,
    required this.stages,
    required this.participants,
    required this.messages,
  });

  final SimulationStatus status;
  final String headline;
  final String summary;
  final String sceneLabel;
  final String turnLabel;
  final String turnSummary;
  final String footerHint;
  final String stageSummary;
  final List<SimulationStageSnapshot> stages;
  final List<SimulationParticipantSnapshot> participants;
  final List<SimulationChatMessage> messages;

  bool get hasRun => status != SimulationStatus.none;

  SimulationParticipantSnapshot participantSnapshot(
    SimulationParticipant participant,
  ) {
    return participants.firstWhere(
      (candidate) => candidate.participant == participant,
    );
  }

  static const String emptyHeadline = '暂无模拟记录';
  static const String emptySummary = '请先运行一次模拟，再回来查看多角色讨论。';

  static AppSimulationSnapshot empty() {
    return const AppSimulationSnapshot(
      status: SimulationStatus.none,
      headline: emptyHeadline,
      summary: emptySummary,
      sceneLabel: '月潮回声 / 第三章 / 场景 05',
      turnLabel: '第 00 回合',
      turnSummary: '尚未开始模拟。',
      footerHint: '给导演补充要求后，再开始一次新的模拟。',
      stageSummary: '未开始',
      stages: [],
      participants: [],
      messages: [],
    );
  }
}

enum _SimulationTemplate {
  none,
  runningStepOne,
  runningStepTwo,
  completed,
  failed,
}

enum _SimulationRunMode { template, realAgents }

class RealAgentSimulationResult {
  const RealAgentSimulationResult({
    required this.succeeded,
    required this.messages,
    this.failureDetail,
  });

  final bool succeeded;
  final List<SimulationChatMessage> messages;
  final String? failureDetail;
}

class _RealSimulationAgent {
  const _RealSimulationAgent({
    required this.key,
    required this.label,
    required this.goal,
    required this.prompt,
    required this.tone,
    required this.alignEnd,
    required this.participant,
  });

  final String key;
  final String label;
  final String goal;
  final String prompt;
  final SimulationChatTone tone;
  final bool alignEnd;
  final SimulationParticipant participant;
}

class AppSimulationStore extends AppProjectScopedStore {
  AppSimulationStore({
    AppSimulationStorage? storage,
    super.workspaceStore,
    AppEventLog? eventLog,
  }) : _storage =
           storage ??
           debugStorageOverride ??
           createDefaultAppSimulationStorage(),
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
    _template = switch (status) {
      SimulationStatus.none => _SimulationTemplate.none,
      SimulationStatus.running => _SimulationTemplate.runningStepOne,
      SimulationStatus.completed => _SimulationTemplate.completed,
      SimulationStatus.failed => _SimulationTemplate.failed,
    };
    _rebuildSnapshot();
    _clearTimers();
  }

  AppSimulationSnapshot _snapshot;
  final AppSimulationStorage _storage;
  final AppEventLog? _eventLog;
  _SimulationTemplate _template = _SimulationTemplate.none;
  int _runToken = 0;
  final List<Timer> _timers = [];
  final Map<SimulationParticipant, String> _promptOverrides = {};
  final List<SimulationChatMessage> _extraMessages = [];
  _SimulationRunMode _runMode = _SimulationRunMode.template;
  String? _activeRunCorrelationId;

  @visibleForTesting
  static AppSimulationStorage? debugStorageOverride;

  AppSimulationSnapshot get snapshot => _snapshot;

  Map<String, Object?> exportJson() => _toJson();

  static AppSimulationSnapshot previewSnapshot(SimulationStatus status) {
    final store = AppSimulationStore.preview(status);
    return store.snapshot;
  }

  void startSuccessfulRun({AppEventLog? eventLog}) {
    markMutated();
    _cancelActiveRunIfNeeded(eventLog: eventLog, reason: 'restarted');
    _clearTimers();
    _extraMessages.clear();
    _runMode = _SimulationRunMode.template;
    _runToken += 1;
    final token = _runToken;
    _activeRunCorrelationId = (eventLog ?? _eventLog)?.newCorrelationId(
      'simulation-run',
    );
    _template = _SimulationTemplate.runningStepOne;
    unawaited(
      _logRunEvent(
        eventLog: eventLog,
        action: 'simulation.run.started',
        status: AppEventLogStatus.started,
        message: 'Simulation run started.',
      ),
    );
    _rebuildSnapshot();

    _schedule(token, const Duration(milliseconds: 280), () {
      _template = _SimulationTemplate.runningStepTwo;
      _rebuildSnapshot();
    });
    _schedule(token, const Duration(milliseconds: 720), () {
      _completeRun(
        template: _SimulationTemplate.completed,
        action: 'simulation.run.succeeded',
        status: AppEventLogStatus.succeeded,
        message: 'Simulation run completed successfully.',
        eventLog: eventLog,
      );
    });
  }

  void startFailureRun({AppEventLog? eventLog}) {
    markMutated();
    _cancelActiveRunIfNeeded(eventLog: eventLog, reason: 'restarted');
    _clearTimers();
    _extraMessages.clear();
    _runMode = _SimulationRunMode.template;
    _runToken += 1;
    final token = _runToken;
    _activeRunCorrelationId = (eventLog ?? _eventLog)?.newCorrelationId(
      'simulation-run',
    );
    _template = _SimulationTemplate.runningStepOne;
    unawaited(
      _logRunEvent(
        eventLog: eventLog,
        action: 'simulation.run.started',
        status: AppEventLogStatus.started,
        message: 'Simulation run started.',
      ),
    );
    _rebuildSnapshot();

    _schedule(token, const Duration(milliseconds: 480), () {
      _completeRun(
        template: _SimulationTemplate.failed,
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
    _runMode = _SimulationRunMode.template;
    _template = _SimulationTemplate.none;
    _runToken += 1;
    _activeRunCorrelationId = null;
    _rebuildSnapshot();
  }

  void ensurePreviewRun(SimulationStatus status, {bool notify = true}) {
    if (_template != _SimulationTemplate.none ||
        status == SimulationStatus.none) {
      return;
    }
    markMutated();
    _clearTimers();
    _runMode = _SimulationRunMode.template;
    _template = switch (status) {
      SimulationStatus.none => _SimulationTemplate.none,
      SimulationStatus.running => _SimulationTemplate.runningStepOne,
      SimulationStatus.completed => _SimulationTemplate.completed,
      SimulationStatus.failed => _SimulationTemplate.failed,
    };
    _snapshot = switch (_template) {
      _SimulationTemplate.none => AppSimulationSnapshot.empty(),
      _SimulationTemplate.runningStepOne => _buildRunningStepOne(),
      _SimulationTemplate.runningStepTwo => _buildRunningStepTwo(),
      _SimulationTemplate.completed => _buildCompleted(),
      _SimulationTemplate.failed => _buildFailed(),
    };
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
    if (_template != _SimulationTemplate.none) {
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
    if (normalized.isEmpty || _template == _SimulationTemplate.none) {
      return;
    }
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
    _template = _templateFromName(data['template'] as String?);
    _runMode = _runModeFromName(data['runMode'] as String?);
    _promptOverrides
      ..clear()
      ..addAll(_decodePromptOverrides(data['promptOverrides']));
    _extraMessages
      ..clear()
      ..addAll(_decodeMessages(data['extraMessages']));
    _snapshot = switch (_template) {
      _SimulationTemplate.none => AppSimulationSnapshot.empty(),
      _SimulationTemplate.runningStepOne => _buildRunningStepOne(),
      _SimulationTemplate.runningStepTwo => _buildRunningStepTwo(),
      _SimulationTemplate.completed => _buildCompleted(),
      _SimulationTemplate.failed => _buildFailed(),
    };
    unawaited(_storage.save(_toJson(), projectId: activeProjectId));
    notifyListeners();
  }

  @override
  void onProjectScopeChanged(String previousProjectId, String nextProjectId) {
    _cancelActiveRunIfNeeded(eventLog: null, reason: 'project_scope_changed');
    _clearTimers();
    _template = _SimulationTemplate.none;
    _runMode = _SimulationRunMode.template;
    _promptOverrides.clear();
    _extraMessages.clear();
    _snapshot = AppSimulationSnapshot.empty();
    _activeRunCorrelationId = null;
  }

  @override
  Future<void> onRestore() async {
    final restoreVersion = mutationVersion;
    final data = await _storage.load(projectId: activeProjectId);
    if (data == null) {
      return;
    }
    if (restoreVersion != mutationVersion) {
      return;
    }
    _template = _templateFromName(data['template'] as String?);
    _runMode = _runModeFromName(data['runMode'] as String?);
    _promptOverrides
      ..clear()
      ..addAll(_decodePromptOverrides(data['promptOverrides']));
    _extraMessages
      ..clear()
      ..addAll(_decodeMessages(data['extraMessages']));
    _snapshot = switch (_template) {
      _SimulationTemplate.none => AppSimulationSnapshot.empty(),
      _SimulationTemplate.runningStepOne => _buildRunningStepOne(),
      _SimulationTemplate.runningStepTwo => _buildRunningStepTwo(),
      _SimulationTemplate.completed => _buildCompleted(),
      _SimulationTemplate.failed => _buildFailed(),
    };
    notifyListeners();
  }

  @override
  void dispose() {
    _clearTimers();
    super.dispose();
  }

  Future<RealAgentSimulationResult> runRealAgentSession({
    required AppSettingsStore settingsStore,
    required String sceneContext,
    String authorGoal = '',
    int rounds = 2,
    AppEventLog? eventLog,
  }) async {
    final normalizedContext = sceneContext.trim();
    if (normalizedContext.isEmpty) {
      throw ArgumentError.value(
        sceneContext,
        'sceneContext',
        'must not be empty',
      );
    }
    if (rounds < 1) {
      throw ArgumentError.value(rounds, 'rounds', 'must be greater than zero');
    }

    markMutated();
    _cancelActiveRunIfNeeded(eventLog: eventLog, reason: 'restarted');
    _clearTimers();
    _extraMessages.clear();
    _promptOverrides
      ..clear()
      ..addAll({
        for (final agent in _realAgents) agent.participant: agent.prompt,
      });
    _runToken += 1;
    _runMode = _SimulationRunMode.realAgents;
    _template = _SimulationTemplate.runningStepOne;
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

    final transcript = <SimulationChatMessage>[];
    final priorOutputs = <String>[];
    try {
      for (var round = 1; round <= rounds; round++) {
        _template = _SimulationTemplate.runningStepTwo;

        final results = await Future.wait(
          _realAgents.map(
            (agent) => _requestAgentWithRetry(
              settingsStore: settingsStore,
              messages: _messagesForRealAgent(
                agent: agent,
                round: round,
                rounds: rounds,
                sceneContext: normalizedContext,
                authorGoal: authorGoal.trim(),
                priorOutputs: priorOutputs,
              ),
            ),
          ),
        );

        for (var i = 0; i < _realAgents.length; i++) {
          final agent = _realAgents[i];
          final result = results[i];
          if (!result.succeeded || result.text == null) {
            final detail =
                result.detail ?? result.failureKind?.name ?? 'empty response';
            _extraMessages.add(
              SimulationChatMessage(
                sender: agent.label,
                title: '真实回合 $round · 调用失败',
                body: detail,
                tone: agent.tone,
                alignEnd: agent.alignEnd,
                kind: SimulationMessageKind.verdict,
              ),
            );
            _completeRun(
              template: _SimulationTemplate.failed,
              action: 'simulation.real_agents.failed',
              status: AppEventLogStatus.failed,
              message: 'Real multi-agent simulation failed.',
              eventLog: eventLog,
              errorCode: result.failureKind?.name ?? 'empty_response',
            );
            return RealAgentSimulationResult(
              succeeded: false,
              messages: List<SimulationChatMessage>.unmodifiable(
                _extraMessages,
              ),
              failureDetail: detail,
            );
          }

          final text = result.text!.trim();
          final message = SimulationChatMessage(
            sender: agent.label,
            title: '真实回合 $round · ${agent.goal}',
            body: text,
            tone: agent.tone,
            alignEnd: agent.alignEnd,
            kind: agent.key == 'director'
                ? SimulationMessageKind.intent
                : SimulationMessageKind.speech,
          );
          transcript.add(message);
          _extraMessages.add(message);
          priorOutputs.add('${agent.label}：$text');
        }
        _rebuildSnapshot();
      }

      _completeRun(
        template: _SimulationTemplate.completed,
        action: 'simulation.real_agents.succeeded',
        status: AppEventLogStatus.succeeded,
        message: 'Real multi-agent simulation completed successfully.',
        eventLog: eventLog,
      );
      return RealAgentSimulationResult(
        succeeded: true,
        messages: List<SimulationChatMessage>.unmodifiable(transcript),
      );
    } catch (error) {
      _extraMessages.add(
        SimulationChatMessage(
          sender: '系统',
          title: '真实多 Agent 调用异常',
          body: error.toString(),
          tone: SimulationChatTone.stateMachine,
          alignEnd: false,
          kind: SimulationMessageKind.verdict,
        ),
      );
      _completeRun(
        template: _SimulationTemplate.failed,
        action: 'simulation.real_agents.failed',
        status: AppEventLogStatus.failed,
        message: 'Real multi-agent simulation failed with an exception.',
        eventLog: eventLog,
        errorCode: 'exception',
      );
      return RealAgentSimulationResult(
        succeeded: false,
        messages: List<SimulationChatMessage>.unmodifiable(_extraMessages),
        failureDetail: error.toString(),
      );
    }
  }

  void _schedule(int token, Duration delay, VoidCallback update) {
    late final Timer timer;
    timer = Timer(delay, () {
      _timers.remove(timer);
      if (token != _runToken) {
        return;
      }
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
    required _SimulationTemplate template,
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
    if (_template != _SimulationTemplate.runningStepOne &&
        _template != _SimulationTemplate.runningStepTwo) {
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

  void _rebuildSnapshot() {
    _snapshot = switch (_template) {
      _SimulationTemplate.none => AppSimulationSnapshot.empty(),
      _SimulationTemplate.runningStepOne => _buildRunningStepOne(),
      _SimulationTemplate.runningStepTwo => _buildRunningStepTwo(),
      _SimulationTemplate.completed => _buildCompleted(),
      _SimulationTemplate.failed => _buildFailed(),
    };
    unawaited(_storage.save(_toJson(), projectId: activeProjectId));
    notifyListeners();
  }

  Map<String, Object?> _toJson() {
    return {
      'template': _template.name,
      'runMode': _runMode.name,
      'promptOverrides': {
        for (final entry in _promptOverrides.entries)
          entry.key.name: entry.value,
      },
      'extraMessages': [
        for (final message in _extraMessages)
          {
            'sender': message.sender,
            'title': message.title,
            'body': message.body,
            'tone': message.tone.name,
            'alignEnd': message.alignEnd,
            'kind': message.kind.name,
          },
      ],
    };
  }

  _SimulationTemplate _templateFromName(String? name) {
    return switch (name) {
      'runningStepOne' => _SimulationTemplate.runningStepOne,
      'runningStepTwo' => _SimulationTemplate.runningStepTwo,
      'completed' => _SimulationTemplate.completed,
      'failed' => _SimulationTemplate.failed,
      _ => _SimulationTemplate.none,
    };
  }

  _SimulationRunMode _runModeFromName(String? name) {
    return switch (name) {
      'realAgents' => _SimulationRunMode.realAgents,
      _ => _SimulationRunMode.template,
    };
  }

  Map<SimulationParticipant, String> _decodePromptOverrides(Object? raw) {
    if (raw is! Map) {
      return const {};
    }
    final result = <SimulationParticipant, String>{};
    for (final entry in raw.entries) {
      final participant = SimulationParticipant.values.where(
        (candidate) => candidate.name == entry.key.toString(),
      );
      if (participant.isEmpty || entry.value is! String) {
        continue;
      }
      result[participant.first] = entry.value as String;
    }
    return result;
  }

  List<SimulationChatMessage> _decodeMessages(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    final messages = <SimulationChatMessage>[];
    for (final item in raw) {
      if (item is! Map) {
        continue;
      }
      final toneName = item['tone']?.toString();
      final tone = SimulationChatTone.values.where(
        (candidate) => candidate.name == toneName,
      );
      if (tone.isEmpty) {
        continue;
      }
      messages.add(
        SimulationChatMessage(
          sender: item['sender']?.toString() ?? '',
          title: item['title']?.toString() ?? '',
          body: item['body']?.toString() ?? '',
          tone: tone.first,
          alignEnd: item['alignEnd'] == true,
          kind: _messageKindFromName(item['kind']?.toString()),
        ),
      );
    }
    return messages;
  }

  List<SimulationParticipantSnapshot> _participants() {
    if (_runMode == _SimulationRunMode.realAgents) {
      return [
        for (final agent in _realAgents)
          SimulationParticipantSnapshot(
            participant: agent.participant,
            promptSummary: _promptOverrides[agent.participant] ?? agent.prompt,
            statusSummary: agent.goal,
          ),
      ];
    }
    return [
      for (final participant in SimulationParticipant.values)
        SimulationParticipantSnapshot(
          participant: participant,
          promptSummary:
              _promptOverrides[participant] ?? participant.defaultPrompt,
          statusSummary: participant.statusSummary,
        ),
    ];
  }

  String _promptFor(SimulationParticipant participant) {
    return _promptOverrides[participant] ?? participant.defaultPrompt;
  }

  String _promptLead(SimulationParticipant participant) {
    final prompt = _promptFor(participant).trim();
    if (prompt.isEmpty) {
      return participant.defaultPrompt;
    }
    return prompt.split(RegExp(r'[。.!?]')).first.trim();
  }

  List<SimulationParticipant> _discussionOrder() {
    final order = <SimulationParticipant>[
      SimulationParticipant.liuXi,
      SimulationParticipant.yueRen,
      SimulationParticipant.fuXingzhou,
    ];

    final latestUserFeedback = _extraMessages
        .where((message) => message.sender == '你')
        .map((message) => message.body)
        .lastOrNull;

    if (latestUserFeedback == null) {
      return order;
    }

    for (final participant in order) {
      if (latestUserFeedback.contains(participant.shortName)) {
        return [
          participant,
          ...order.where((candidate) => candidate != participant),
        ];
      }
    }

    return order;
  }

  String _directorTaskLine(SimulationParticipant participant, String prefix) {
    return '$prefix：${participant.shortName}围绕"${_promptLead(participant)}"推进当前回合。';
  }

  String _participantMessageBody(SimulationParticipant participant) {
    final prompt = _promptLead(participant);
    return switch (participant) {
      SimulationParticipant.liuXi => '我先认领当前任务。会先按"$prompt"来处理，再决定追问力度。',
      SimulationParticipant.yueRen => '我倾向于把"$prompt"放进同一轮讨论里，不建议太快推进到摊牌。',
      SimulationParticipant.fuXingzhou => '门口压力要继续保留，我会按"$prompt"补足这一层存在感。',
      _ => prompt,
    };
  }

  String _directorAdjustmentBody(List<SimulationParticipant> order) {
    if (order.length < 2) {
      return '收到讨论，当前回合保持原任务分配。';
    }
    return '收到讨论：${order.first.shortName}先保持"${_promptLead(order.first)}"，'
        '${order[1].shortName}随后围绕"${_promptLead(order[1])}"补位。';
  }

  List<SimulationChatMessage> _baseMessages({
    required bool includeCharacterDebate,
  }) {
    final order = _discussionOrder();
    return [
      SimulationChatMessage(
        sender: '导演',
        title: '任务分配',
        body: [
          _directorTaskLine(order[0], '任务 1'),
          _directorTaskLine(order[1], '任务 2'),
          _directorTaskLine(order[2], '任务 3'),
        ].join('\n'),
        tone: SimulationChatTone.director,
        alignEnd: false,
        kind: SimulationMessageKind.intent,
      ),
      SimulationChatMessage(
        sender: order[0].shortName,
        title: '${order[0].shortName}认领',
        body: _participantMessageBody(order[0]),
        tone: order[0] == SimulationParticipant.liuXi
            ? SimulationChatTone.focusCharacter
            : SimulationChatTone.supportingCharacter,
        alignEnd: true,
        kind: SimulationMessageKind.speech,
      ),
      if (includeCharacterDebate)
        SimulationChatMessage(
          sender: order[1].shortName,
          title: '${order[1].shortName}讨论',
          body: _participantMessageBody(order[1]),
          tone: order[1] == SimulationParticipant.liuXi
              ? SimulationChatTone.focusCharacter
              : SimulationChatTone.supportingCharacter,
          alignEnd: true,
          kind: SimulationMessageKind.speech,
        ),
      if (includeCharacterDebate)
        SimulationChatMessage(
          sender: order[2].shortName,
          title: '${order[2].shortName}补充',
          body: _participantMessageBody(order[2]),
          tone: order[2] == SimulationParticipant.liuXi
              ? SimulationChatTone.focusCharacter
              : SimulationChatTone.supportingCharacter,
          alignEnd: true,
          kind: SimulationMessageKind.speech,
        ),
      if (includeCharacterDebate)
        const SimulationChatMessage(
          sender: '状态机',
          title: '约束反馈',
          body: '证人仍处于回避状态，不允许直接进入合作分支；门口压力成立。',
          tone: SimulationChatTone.stateMachine,
          alignEnd: false,
          kind: SimulationMessageKind.verdict,
        ),
      if (includeCharacterDebate)
        SimulationChatMessage(
          sender: '导演',
          title: '任务调整',
          body: _directorAdjustmentBody(order),
          tone: SimulationChatTone.director,
          alignEnd: false,
          kind: SimulationMessageKind.summary,
        ),
      ..._extraMessages,
    ];
  }

  String _currentSceneLabel() {
    final ws = workspaceStore;
    if (ws == null || ws.currentProjectId.isEmpty) {
      return '月潮回声 / 第三章 / 场景 05';
    }
    return ws.currentProjectBreadcrumb;
  }

  AppSimulationSnapshot _buildRunningStepOne() {
    if (_runMode == _SimulationRunMode.realAgents) {
      return _buildRealAgentSnapshot(
        status: SimulationStatus.running,
        headline: '真实多 Agent 模拟进行中',
        summary: '正在使用真实 provider 轮转导演、主角和对立角色。',
        stageSummary: '准备真实上下文',
      );
    }
    return AppSimulationSnapshot(
      status: SimulationStatus.running,
      headline: '模拟进行中',
      summary: '导演已开始分配任务，角色方正在认领。',
      sceneLabel: _currentSceneLabel(),
      turnLabel: '第 05 回合',
      turnSummary: '第 05 回合 · 4 方协同 · 柳溪正在回应',
      footerHint: '在线列表里的认知 Prompt 可随时编辑，修改会先反馈给导演。',
      stageSummary: '准备上下文进行中',
      stages: const [
        SimulationStageSnapshot(
          label: '准备上下文',
          status: SimulationStageStatus.active,
        ),
        SimulationStageSnapshot(
          label: '多角色讨论',
          status: SimulationStageStatus.pending,
        ),
        SimulationStageSnapshot(
          label: '叙述改写',
          status: SimulationStageStatus.pending,
        ),
      ],
      participants: _participants(),
      messages: _baseMessages(includeCharacterDebate: false),
    );
  }

  AppSimulationSnapshot _buildRunningStepTwo() {
    if (_runMode == _SimulationRunMode.realAgents) {
      return _buildRealAgentSnapshot(
        status: SimulationStatus.running,
        headline: '真实多 Agent 模拟进行中',
        summary: '真实角色回合正在写入持久化记录。',
        stageSummary: '真实多角色讨论进行中',
      );
    }
    return AppSimulationSnapshot(
      status: SimulationStatus.running,
      headline: '模拟进行中',
      summary: '角色方已经开始讨论，导演正在根据分歧重新调度。',
      sceneLabel: _currentSceneLabel(),
      turnLabel: '第 05 回合',
      turnSummary: '第 05 回合 · 4 方协同 · 柳溪正在回应',
      footerHint: '在线列表里的认知 Prompt 可随时编辑，修改会先反馈给导演。',
      stageSummary: '多角色讨论进行中',
      stages: const [
        SimulationStageSnapshot(
          label: '准备上下文',
          status: SimulationStageStatus.completed,
        ),
        SimulationStageSnapshot(
          label: '多角色讨论',
          status: SimulationStageStatus.active,
        ),
        SimulationStageSnapshot(
          label: '叙述改写',
          status: SimulationStageStatus.pending,
        ),
      ],
      participants: _participants(),
      messages: _baseMessages(includeCharacterDebate: true),
    );
  }

  AppSimulationSnapshot _buildCompleted() {
    if (_runMode == _SimulationRunMode.realAgents) {
      return _buildRealAgentSnapshot(
        status: SimulationStatus.completed,
        headline: '真实多 Agent 模拟已完成',
        summary: '导演、主角和对立角色的真实 provider 输出已收束。',
        stageSummary: '真实多角色讨论已完成',
      );
    }
    return AppSimulationSnapshot(
      status: SimulationStatus.completed,
      headline: '模拟已完成',
      summary: '导演调度与角色讨论已收束，新的场景草稿候选已生成。',
      sceneLabel: _currentSceneLabel(),
      turnLabel: '第 05 回合',
      turnSummary: '第 05 回合 · 4 方协同 · 叙述已完成',
      footerHint: '在线列表里的认知 Prompt 可随时编辑，修改会先反馈给导演。',
      stageSummary: '叙述改写已完成',
      stages: const [
        SimulationStageSnapshot(
          label: '准备上下文',
          status: SimulationStageStatus.completed,
        ),
        SimulationStageSnapshot(
          label: '多角色讨论',
          status: SimulationStageStatus.completed,
        ),
        SimulationStageSnapshot(
          label: '叙述改写',
          status: SimulationStageStatus.completed,
        ),
      ],
      participants: _participants(),
      messages: [
        ..._baseMessages(includeCharacterDebate: true),
        SimulationChatMessage(
          sender: '柳溪',
          title: '柳溪成稿',
          body:
              '玻璃杯边缘的反光先一步落下来，随后按照"${_promptLead(SimulationParticipant.liuXi)}"去推进她的追问。',
          tone: SimulationChatTone.focusCharacter,
          alignEnd: true,
          kind: SimulationMessageKind.speech,
        ),
      ],
    );
  }

  AppSimulationSnapshot _buildFailed() {
    if (_runMode == _SimulationRunMode.realAgents) {
      return _buildRealAgentSnapshot(
        status: SimulationStatus.failed,
        headline: '真实多 Agent 模拟失败',
        summary: '至少一个真实 provider 回合未返回可用文本。',
        stageSummary: '真实多角色讨论失败',
      );
    }
    return AppSimulationSnapshot(
      status: SimulationStatus.failed,
      headline: '运行失败摘要',
      summary: '状态机拒绝了关键动作，正文未被改写。',
      sceneLabel: _currentSceneLabel(),
      turnLabel: '第 05 回合',
      turnSummary: '第 05 回合 · 4 方协同 · 裁决失败',
      footerHint: '修改意见仍然会先发给导演，再重新分配任务。',
      stageSummary: '多角色讨论失败',
      stages: const [
        SimulationStageSnapshot(
          label: '准备上下文',
          status: SimulationStageStatus.completed,
        ),
        SimulationStageSnapshot(
          label: '多角色讨论',
          status: SimulationStageStatus.failed,
        ),
        SimulationStageSnapshot(
          label: '叙述改写',
          status: SimulationStageStatus.failed,
        ),
      ],
      participants: _participants(),
      messages: [
        const SimulationChatMessage(
          sender: '导演',
          title: '任务分配',
          body: '导演已分配 3 个任务，但关键动作在裁决阶段被拦截。',
          tone: SimulationChatTone.director,
          alignEnd: false,
          kind: SimulationMessageKind.intent,
        ),
        const SimulationChatMessage(
          sender: '状态机',
          title: '约束反馈',
          body: '证人背后通道被锁死，当前动作意图被拒绝，正文不会被改写。',
          tone: SimulationChatTone.stateMachine,
          alignEnd: false,
          kind: SimulationMessageKind.verdict,
        ),
        ..._extraMessages,
      ],
    );
  }

  AppSimulationSnapshot _buildRealAgentSnapshot({
    required SimulationStatus status,
    required String headline,
    required String summary,
    required String stageSummary,
  }) {
    final discussionStatus = switch (status) {
      SimulationStatus.completed => SimulationStageStatus.completed,
      SimulationStatus.failed => SimulationStageStatus.failed,
      SimulationStatus.running => SimulationStageStatus.active,
      SimulationStatus.none => SimulationStageStatus.pending,
    };
    return AppSimulationSnapshot(
      status: status,
      headline: headline,
      summary: summary,
      sceneLabel: _currentSceneLabel(),
      turnLabel: '真实回合 ${_completedRealRoundsLabel()}',
      turnSummary: '真实 provider · ${_realAgents.length} 个 agent · 至少 2 回合',
      footerHint: '这些消息来自真实 AI 请求，可作为正文生成前的输入。',
      stageSummary: stageSummary,
      stages: [
        const SimulationStageSnapshot(
          label: '准备上下文',
          status: SimulationStageStatus.completed,
        ),
        SimulationStageSnapshot(label: '多角色讨论', status: discussionStatus),
        SimulationStageSnapshot(
          label: '正文输入沉淀',
          status: status == SimulationStatus.completed
              ? SimulationStageStatus.completed
              : status == SimulationStatus.failed
              ? SimulationStageStatus.failed
              : SimulationStageStatus.pending,
        ),
      ],
      participants: _participants(),
      messages: List<SimulationChatMessage>.unmodifiable(_extraMessages),
    );
  }

  String _completedRealRoundsLabel() {
    final rounds = _extraMessages
        .map((message) => RegExp(r'真实回合 (\d+)').firstMatch(message.title))
        .whereType<RegExpMatch>()
        .map((match) => int.tryParse(match.group(1) ?? '') ?? 0)
        .fold<int>(0, (max, value) => value > max ? value : max);
    return rounds.toString().padLeft(2, '0');
  }

  Future<AppLlmChatResult> _requestAgentWithRetry({
    required AppSettingsStore settingsStore,
    required List<AppLlmChatMessage> messages,
    int maxRetries = 3,
  }) async {
    var retries = 0;
    while (true) {
      final result = await settingsStore.requestAiCompletion(
        messages: messages,
      );
      if (result.succeeded || retries >= maxRetries) {
        return result;
      }
      final kind = result.failureKind;
      if (kind != AppLlmFailureKind.network &&
          kind != AppLlmFailureKind.timeout &&
          kind != AppLlmFailureKind.server) {
        return result;
      }
      retries += 1;
      await Future<void>.delayed(
        Duration(milliseconds: 500 * (1 << (retries - 1))),
      );
    }
  }

  List<AppLlmChatMessage> _messagesForRealAgent({
    required _RealSimulationAgent agent,
    required int round,
    required int rounds,
    required String sceneContext,
    required String authorGoal,
    required List<String> priorOutputs,
  }) {
    return [
      AppLlmChatMessage(
        role: 'system',
        content: [
          '你是小说场景模拟中的真实多 Agent 角色：${agent.label}。',
          '你的目标：${agent.goal}。',
          '你的固定 prompt：${agent.prompt}',
          '输出本回合可被正文生成引用的中文内容，保持角色现场判断口吻。',
        ].join('\n'),
      ),
      AppLlmChatMessage(
        role: 'user',
        content: [
          '任务：真实多 Agent 场景模拟',
          '回合：$round/$rounds',
          if (authorGoal.isNotEmpty) '作者目标：$authorGoal',
          '场景上下文：$sceneContext',
          if (priorOutputs.isNotEmpty) '此前回合输出：\n${priorOutputs.join('\n')}',
          '请给出 ${agent.label} 本回合的判断、行动/阻力、以及对正文生成的约束。',
        ].join('\n\n'),
      ),
    ];
  }

  static const List<_RealSimulationAgent> _realAgents = [
    _RealSimulationAgent(
      key: 'director',
      label: 'director',
      goal: '拆解场景目标和冲突',
      prompt: '先明确场景目标、冲突节奏和正文生成必须遵守的约束。',
      tone: SimulationChatTone.director,
      alignEnd: false,
      participant: SimulationParticipant.director,
    ),
    _RealSimulationAgent(
      key: 'protagonist',
      label: 'protagonist',
      goal: '给出主角行动、情绪和隐性目标',
      prompt: '从主角视角提出行动选择、情绪变化和不愿明说的真实目标。',
      tone: SimulationChatTone.focusCharacter,
      alignEnd: true,
      participant: SimulationParticipant.liuXi,
    ),
    _RealSimulationAgent(
      key: 'antagonist',
      label: 'antagonist',
      goal: '给出对立行动和隐性阻力',
      prompt: '从对立力量视角提出阻碍、误导、代价和下一步压力。',
      tone: SimulationChatTone.supportingCharacter,
      alignEnd: true,
      participant: SimulationParticipant.yueRen,
    ),
  ];

  SimulationMessageKind _messageKindFromName(String? name) {
    return switch (name) {
      'intent' => SimulationMessageKind.intent,
      'verdict' => SimulationMessageKind.verdict,
      'summary' => SimulationMessageKind.summary,
      _ => SimulationMessageKind.speech,
    };
  }

  String? get _currentSceneId {
    final ws = workspaceStore;
    if (ws == null || ws.currentProjectId.isEmpty) {
      return null;
    }
    return ws.currentProject.sceneId;
  }

  Future<void> _logRunEvent({
    required String action,
    required AppEventLogStatus status,
    required String message,
    AppEventLog? eventLog,
    String? errorCode,
  }) {
    final log = eventLog ?? _eventLog;
    if (log == null) {
      return Future<void>.value();
    }
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

class AppSimulationScope extends InheritedNotifier<AppSimulationStore> {
  const AppSimulationScope({
    super.key,
    required AppSimulationStore store,
    required super.child,
  }) : super(notifier: store);

  static AppSimulationStore of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppSimulationScope>();
    assert(scope != null, 'AppSimulationScope is missing in the widget tree.');
    return scope!.notifier!;
  }
}
