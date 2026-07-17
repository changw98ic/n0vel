import 'simulation_models.dart';

/// Immutable state passed to snapshot builder functions so they remain
/// pure and testable without depending on the store itself.
class SimulationBuildContext {
  const SimulationBuildContext({
    required this.runMode,
    required this.promptOverrides,
    required this.extraMessages,
    required this.sceneLabel,
    required this.currentSceneId,
    this.completedRealRoundsLabel = '00',
  });

  final SimulationRunMode runMode;
  final Map<SimulationParticipant, String> promptOverrides;
  final List<SimulationChatMessage> extraMessages;
  final String sceneLabel;
  final String? currentSceneId;
  final String completedRealRoundsLabel;
}

// ---------------------------------------------------------------------------
// Re-export private enums as public so the builder can reference them.
// ---------------------------------------------------------------------------

/// The internal template state machine.
enum SimulationTemplate {
  none,
  runningStepOne,
  runningStepTwo,
  completed,
  failed,
}

/// Whether the run uses hard-coded templates or real LLM agents.
enum SimulationRunMode { template, realAgents }

// ---------------------------------------------------------------------------
// Snapshot builders — pure functions.
// ---------------------------------------------------------------------------

AppSimulationSnapshot buildSnapshotForTemplate(
  SimulationTemplate template, {
  required SimulationBuildContext context,
  required List<SimulationParticipantSnapshot> participants,
}) {
  return switch (template) {
    SimulationTemplate.none => AppSimulationSnapshot.empty(),
    SimulationTemplate.runningStepOne => buildRunningStepOne(
      context: context,
      participants: participants,
    ),
    SimulationTemplate.runningStepTwo => buildRunningStepTwo(
      context: context,
      participants: participants,
    ),
    SimulationTemplate.completed => buildCompleted(
      context: context,
      participants: participants,
    ),
    SimulationTemplate.failed => buildFailed(
      context: context,
      participants: participants,
    ),
  };
}

AppSimulationSnapshot buildRunningStepOne({
  required SimulationBuildContext context,
  required List<SimulationParticipantSnapshot> participants,
}) {
  if (context.runMode == SimulationRunMode.realAgents) {
    return buildRealAgentSnapshot(
      context: context,
      participants: participants,
      status: SimulationStatus.running,
      headline: 'AI 正在按多角色资料写这一场',
      summary: '正在使用真实 provider 轮转导演、主角和对立角色。',
      stageSummary: '准备真实上下文',
    );
  }
  return AppSimulationSnapshot(
    status: SimulationStatus.running,
    headline: 'AI 正在写这一场',
    summary: '导演已开始分配任务，角色方正在认领。',
    sceneLabel: context.sceneLabel,
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
    participants: participants,
    messages: baseMessages(
      context: context,
      participants: participants,
      includeCharacterDebate: false,
    ),
  );
}

AppSimulationSnapshot buildRunningStepTwo({
  required SimulationBuildContext context,
  required List<SimulationParticipantSnapshot> participants,
}) {
  if (context.runMode == SimulationRunMode.realAgents) {
    return buildRealAgentSnapshot(
      context: context,
      participants: participants,
      status: SimulationStatus.running,
      headline: 'AI 正在按多角色资料写这一场',
      summary: '真实角色回合正在写入持久化记录。',
      stageSummary: '真实多角色讨论进行中',
    );
  }
  return AppSimulationSnapshot(
    status: SimulationStatus.running,
    headline: 'AI 正在写这一场',
    summary: '角色方已经开始讨论，导演正在根据分歧重新调度。',
    sceneLabel: context.sceneLabel,
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
    participants: participants,
    messages: baseMessages(
      context: context,
      participants: participants,
      includeCharacterDebate: true,
    ),
  );
}

AppSimulationSnapshot buildCompleted({
  required SimulationBuildContext context,
  required List<SimulationParticipantSnapshot> participants,
}) {
  if (context.runMode == SimulationRunMode.realAgents) {
    return buildRealAgentSnapshot(
      context: context,
      participants: participants,
      status: SimulationStatus.completed,
      headline: 'AI 多角色试写完成',
      summary: '导演、主角和对立角色的真实 provider 输出已收束。',
      stageSummary: '真实多角色讨论已完成',
    );
  }
  return AppSimulationSnapshot(
    status: SimulationStatus.completed,
    headline: 'AI 试写完成',
    summary: '导演调度与角色讨论已收束，新的场景草稿候选已生成。',
    sceneLabel: context.sceneLabel,
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
    participants: participants,
    messages: [
      ...baseMessages(
        context: context,
        participants: participants,
        includeCharacterDebate: true,
      ),
      SimulationChatMessage(
        sender: '柳溪',
        title: '柳溪成稿',
        body:
            '玻璃杯边缘的反光先一步落下来，随后按照"${promptLead(context, SimulationParticipant.liuXi)}"去推进她的追问。',
        tone: SimulationChatTone.focusCharacter,
        alignEnd: true,
        kind: SimulationMessageKind.speech,
      ),
    ],
  );
}

AppSimulationSnapshot buildFailed({
  required SimulationBuildContext context,
  required List<SimulationParticipantSnapshot> participants,
}) {
  if (context.runMode == SimulationRunMode.realAgents) {
    return buildRealAgentSnapshot(
      context: context,
      participants: participants,
      status: SimulationStatus.failed,
      headline: 'AI 多角色试写失败',
      summary: '至少一个真实 provider 回合未返回可用文本。',
      stageSummary: '真实多角色讨论失败',
    );
  }
  return AppSimulationSnapshot(
    status: SimulationStatus.failed,
    headline: '运行失败摘要',
    summary: '状态机拒绝了关键动作，正文未被改写。',
    sceneLabel: context.sceneLabel,
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
    participants: participants,
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
      ...context.extraMessages,
    ],
  );
}

AppSimulationSnapshot buildRealAgentSnapshot({
  required SimulationBuildContext context,
  required List<SimulationParticipantSnapshot> participants,
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
    sceneLabel: context.sceneLabel,
    turnLabel: '真实回合 ${context.completedRealRoundsLabel}',
    turnSummary: '真实 provider · ${participants.length} 个 agent · 至少 2 回合',
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
    participants: participants,
    messages: List<SimulationChatMessage>.unmodifiable(context.extraMessages),
  );
}

// ---------------------------------------------------------------------------
// Participants helper.
// ---------------------------------------------------------------------------

List<SimulationParticipantSnapshot> buildParticipants({
  required SimulationRunMode runMode,
  required Map<SimulationParticipant, String> promptOverrides,
  required List<RealAgentConfig> realAgents,
}) {
  if (runMode == SimulationRunMode.realAgents) {
    return [
      for (final agent in realAgents)
        SimulationParticipantSnapshot(
          participant: agent.participant,
          promptSummary: promptOverrides[agent.participant] ?? agent.prompt,
          statusSummary: agent.goal,
        ),
    ];
  }
  return [
    for (final participant in SimulationParticipant.values)
      SimulationParticipantSnapshot(
        participant: participant,
        promptSummary:
            promptOverrides[participant] ?? participant.defaultPrompt,
        statusSummary: participant.statusSummary,
      ),
  ];
}

// ---------------------------------------------------------------------------
// Message construction helpers.
// ---------------------------------------------------------------------------

List<SimulationChatMessage> baseMessages({
  required SimulationBuildContext context,
  required List<SimulationParticipantSnapshot> participants,
  required bool includeCharacterDebate,
}) {
  final order = discussionOrder(context);
  return [
    SimulationChatMessage(
      sender: '导演',
      title: '任务分配',
      body: [
        _directorTaskLine(context, order[0], '任务 1'),
        _directorTaskLine(context, order[1], '任务 2'),
        _directorTaskLine(context, order[2], '任务 3'),
      ].join('\n'),
      tone: SimulationChatTone.director,
      alignEnd: false,
      kind: SimulationMessageKind.intent,
    ),
    SimulationChatMessage(
      sender: order[0].shortName,
      title: '${order[0].shortName}认领',
      body: _participantMessageBody(context, order[0]),
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
        body: _participantMessageBody(context, order[1]),
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
        body: _participantMessageBody(context, order[2]),
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
        body: _directorAdjustmentBody(context, order),
        tone: SimulationChatTone.director,
        alignEnd: false,
        kind: SimulationMessageKind.summary,
      ),
    ...context.extraMessages,
  ];
}

String promptLead(
  SimulationBuildContext context,
  SimulationParticipant participant,
) {
  final prompt = _promptFor(context, participant).trim();
  if (prompt.isEmpty) {
    return participant.defaultPrompt;
  }
  return prompt.split(RegExp(r'[。.!?]')).first.trim();
}

// ---------------------------------------------------------------------------
// Private helpers.
// ---------------------------------------------------------------------------

String _promptFor(
  SimulationBuildContext context,
  SimulationParticipant participant,
) {
  return context.promptOverrides[participant] ?? participant.defaultPrompt;
}

List<SimulationParticipant> discussionOrder(SimulationBuildContext context) {
  final order = <SimulationParticipant>[
    SimulationParticipant.liuXi,
    SimulationParticipant.yueRen,
    SimulationParticipant.fuXingzhou,
  ];

  final latestUserFeedback = context.extraMessages
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

String _directorTaskLine(
  SimulationBuildContext context,
  SimulationParticipant participant,
  String prefix,
) {
  return '$prefix：${participant.shortName}围绕"${promptLead(context, participant)}"推进当前回合。';
}

String _participantMessageBody(
  SimulationBuildContext context,
  SimulationParticipant participant,
) {
  final prompt = promptLead(context, participant);
  return switch (participant) {
    SimulationParticipant.liuXi => '我先认领当前任务。会先按"$prompt"来处理，再决定追问力度。',
    SimulationParticipant.yueRen => '我倾向于把"$prompt"放进同一轮讨论里，不建议太快推进到摊牌。',
    SimulationParticipant.fuXingzhou => '门口压力要继续保留，我会按"$prompt"补足这一层存在感。',
    _ => prompt,
  };
}

String _directorAdjustmentBody(
  SimulationBuildContext context,
  List<SimulationParticipant> order,
) {
  if (order.length < 2) {
    return '收到讨论，当前回合保持原任务分配。';
  }
  return '收到讨论：${order.first.shortName}先保持"${promptLead(context, order.first)}"，'
      '${order[1].shortName}随后围绕"${promptLead(context, order[1])}"补位。';
}

/// Real agent configuration — shared between the snapshot builder and the
/// real-agent runner.
class RealAgentConfig {
  const RealAgentConfig({
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

/// The fixed set of real agents used in multi-agent simulation.
const List<RealAgentConfig> kRealSimulationAgents = [
  RealAgentConfig(
    key: 'director',
    label: 'director',
    goal: '拆解场景目标和冲突',
    prompt: '先明确场景目标、冲突节奏和正文生成必须遵守的约束。',
    tone: SimulationChatTone.director,
    alignEnd: false,
    participant: SimulationParticipant.director,
  ),
  RealAgentConfig(
    key: 'protagonist',
    label: 'protagonist',
    goal: '给出主角行动、情绪和隐性目标',
    prompt: '从主角视角提出行动选择、情绪变化和不愿明说的真实目标。',
    tone: SimulationChatTone.focusCharacter,
    alignEnd: true,
    participant: SimulationParticipant.liuXi,
  ),
  RealAgentConfig(
    key: 'antagonist',
    label: 'antagonist',
    goal: '给出对立行动和隐性阻力',
    prompt: '从对立力量视角提出阻碍、误导、代价和下一步压力。',
    tone: SimulationChatTone.supportingCharacter,
    alignEnd: true,
    participant: SimulationParticipant.yueRen,
  ),
];

/// Compute the label for the highest completed real-agent round.
String completedRealRoundsLabel(List<SimulationChatMessage> extraMessages) {
  final rounds = extraMessages
      .map((message) => RegExp(r'真实回合 (\d+)').firstMatch(message.title))
      .whereType<RegExpMatch>()
      .map((match) => int.tryParse(match.group(1) ?? '') ?? 0)
      .fold<int>(0, (max, value) => value > max ? value : max);
  return rounds.toString().padLeft(2, '0');
}
