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

  static const String emptyHeadline = '还没有 AI 试写记录';
  static const String emptySummary = '请先运行一次模拟，再回来查看多角色讨论。';

  static AppSimulationSnapshot empty() {
    return const AppSimulationSnapshot(
      status: SimulationStatus.none,
      headline: emptyHeadline,
      summary: emptySummary,
      sceneLabel: '',
      turnLabel: '第 00 回合',
      turnSummary: '还没有开始生成。',
      footerHint: '补充写作要求后，再让 AI 试写一次。',
      stageSummary: '未开始',
      stages: [],
      participants: [],
      messages: [],
    );
  }
}

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
