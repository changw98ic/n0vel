/// Language preference for story-generation prompt templates.
///
/// Controls both the system prompts sent to the LLM and the format labels
/// used to parse structured LLM output (e.g. plan lines, review decisions,
/// beat tags).
enum PromptLanguage { zh, en }

/// Language-dependent strings used by the story-generation pipeline.
///
/// Includes system prompt templates and format labels that appear in both
/// prompts and parsers. Each supported language provides a const instance.
class PromptLocale {
  const PromptLocale({
    required this.novelLanguage,
    required this.sysSceneProse,
    required this.sysSceneDirectorPolish,
    required this.sysSceneEditorial,
    required this.sysSceneReviewTemplate,
    required this.sysDynamicRoleAgent,
    required this.sysDynamicRoleAgentWithTools,
    required this.sysSceneBeatResolve,
    required this.sysThoughtExtraction,
    required this.colon,
    required this.targetLabel,
    required this.conflictLabel,
    required this.progressionLabel,
    required this.constraintLabel,
    required this.decisionLabel,
    required this.reasonLabel,
    required this.stanceLabel,
    required this.actionLabel,
    required this.tabooLabel,
    required this.retrievalLabel,
    required this.beatFact,
    required this.beatDialogue,
    required this.beatAction,
    required this.beatInternal,
    required this.beatNarration,
    required this.contributionAction,
    required this.contributionDialogue,
    required this.contributionInteraction,
    required this.pacingSlow,
    required this.pacingMedium,
    required this.pacingFast,
    required this.toneTense,
    required this.toneCalm,
    required this.toneComplex,
    required this.toneNeutral,
    this.tensionKeywords = const [],
    this.calmKeywords = const [],

    // User prompt field labels
    required this.taskLabel,
    required this.sceneLabel,
    required this.sceneShortLabel,
    required this.summaryLabel,
    required this.directorLabel,
    required this.directorPlanLabel,
    required this.roleInputLabel,
    required this.targetLengthLabel,
    required this.charactersUnit,
    required this.currentAttemptLabel,
    required this.noneLabel,
    required this.rewriteFeedbackLabel,
    required this.editorialFeedbackLabel,
    required this.proseLabel,
    required this.reviewLabel,
    required this.rulesOnlyBlocking,
    required this.knownFactsLabel,
    required this.toneFieldLabel,
    required this.pacingFieldLabel,
    required this.contextLabel,
    required this.retrievalContextLabel,
    required this.sceneBeatsLabel,
    required this.listSeparator,
    // Director user-prompt labels
    required this.chapterLabel,
    required this.localPlanLabel,
    required this.formatLabel,
    required this.optionalTag,
    // Director constraint content
    required this.constraintDefaultText,
    required this.constraintWorldNodesText,
    // Director conflict/progression content
    required this.conflictDefaultText,
    required this.conflictSingleCharText,
    required this.namesConjunction,
    required this.conflictMultiCharText,
    required this.progressionDualTemplate,
    // Director character note inferences
    required this.inferMotivationBoth,
    required this.inferMotivationAction,
    required this.inferMotivationDialogue,
    required this.inferMotivationDefault,
    required this.inferEmotionalArcAction,
    required this.inferEmotionalArcDialogue,
    required this.inferEmotionalArcDefault,
    required this.inferKeyActionAction,
    required this.inferKeyActionDialogue,
    required this.inferKeyActionInteraction,
    required this.inferKeyActionDefault,
    // Dynamic role agent labels
    required this.beliefLabel,
    required this.relationshipLabel,
    required this.socialPositionLabel,
    required this.actualInfluenceLabel,
    required this.charMotivationLabel,
    required this.charEmotionalArcLabel,
    required this.charKeyActionLabel,
    required this.roleLabel,
    required this.participationLabel,
    required this.synopsisLabel,
    required this.tensionLabel,
    required this.trustLabel,
    required this.sceneToneLabel,
  });

  /// Human-readable novel language used in system prompts.
  final String novelLanguage;

  // ---------------------------------------------------------------------------
  // System prompt templates
  // ---------------------------------------------------------------------------
  final String sysSceneProse;
  final String sysSceneDirectorPolish;
  final String sysSceneEditorial;

  /// Template for scene review. `{passName}` is replaced at call site.
  final String sysSceneReviewTemplate;
  final String sysDynamicRoleAgent;
  final String sysDynamicRoleAgentWithTools;
  final String sysSceneBeatResolve;
  final String sysThoughtExtraction;

  // ---------------------------------------------------------------------------
  // Format labels (used in prompts AND parsers)
  // ---------------------------------------------------------------------------

  /// Colon separator for structured output (full-width ： vs half-width : ).
  final String colon;

  /// Director plan line labels.
  final String targetLabel;
  final String conflictLabel;
  final String progressionLabel;
  final String constraintLabel;

  /// Review output labels.
  final String decisionLabel;
  final String reasonLabel;

  /// Role agent output labels.
  final String stanceLabel;
  final String actionLabel;
  final String tabooLabel;
  final String retrievalLabel;

  /// Beat type tags.
  final String beatFact;
  final String beatDialogue;
  final String beatAction;
  final String beatInternal;
  final String beatNarration;

  /// Cast contribution labels.
  final String contributionAction;
  final String contributionDialogue;
  final String contributionInteraction;

  /// Pacing labels.
  final String pacingSlow;
  final String pacingMedium;
  final String pacingFast;

  /// Tone labels.
  final String toneTense;
  final String toneCalm;
  final String toneComplex;
  final String toneNeutral;

  /// Keywords that indicate tension in scene summaries.
  final List<String> tensionKeywords;

  /// Keywords that indicate calm in scene summaries.
  final List<String> calmKeywords;

  // ---------------------------------------------------------------------------
  // User prompt field labels (used in LLM user messages)
  // ---------------------------------------------------------------------------

  final String taskLabel;
  final String sceneLabel;
  final String sceneShortLabel;
  final String summaryLabel;
  final String directorLabel;
  final String directorPlanLabel;
  final String roleInputLabel;
  final String targetLengthLabel;
  final String charactersUnit;
  final String currentAttemptLabel;
  final String noneLabel;
  final String rewriteFeedbackLabel;
  final String editorialFeedbackLabel;
  final String proseLabel;
  final String reviewLabel;
  final String rulesOnlyBlocking;
  final String knownFactsLabel;
  final String toneFieldLabel;
  final String pacingFieldLabel;
  final String contextLabel;
  final String retrievalContextLabel;
  final String sceneBeatsLabel;
  final String listSeparator;

  // ---------------------------------------------------------------------------
  // Director user-prompt labels
  // ---------------------------------------------------------------------------
  final String chapterLabel;
  final String localPlanLabel;
  final String formatLabel;
  final String optionalTag;
  final String constraintDefaultText;
  final String constraintWorldNodesText;
  final String conflictDefaultText;
  final String conflictSingleCharText;
  final String namesConjunction;
  final String conflictMultiCharText;
  final String progressionDualTemplate;

  // ---------------------------------------------------------------------------
  // Director character note inference strings
  // ---------------------------------------------------------------------------
  final String inferMotivationBoth;
  final String inferMotivationAction;
  final String inferMotivationDialogue;
  final String inferMotivationDefault;
  final String inferEmotionalArcAction;
  final String inferEmotionalArcDialogue;
  final String inferEmotionalArcDefault;
  final String inferKeyActionAction;
  final String inferKeyActionDialogue;
  final String inferKeyActionInteraction;
  final String inferKeyActionDefault;

  // ---------------------------------------------------------------------------
  // Dynamic role agent labels
  // ---------------------------------------------------------------------------
  final String beliefLabel;
  final String relationshipLabel;
  final String socialPositionLabel;
  final String actualInfluenceLabel;
  final String charMotivationLabel;
  final String charEmotionalArcLabel;
  final String charKeyActionLabel;
  final String roleLabel;
  final String participationLabel;
  final String synopsisLabel;
  final String tensionLabel;
  final String trustLabel;
  final String sceneToneLabel;

  // ---------------------------------------------------------------------------
  // Formatting helpers
  // ---------------------------------------------------------------------------

  /// Format a belief entry for the prompt.
  String formatBelief(String targetId, String aspect, String value) {
    return this == PromptLocale.zh
        ? '关于$targetId的$aspect=$value'
        : '$aspect regarding $targetId=$value';
  }

  /// Format a relationship entry for the prompt.
  String formatRelationship(
    String charA,
    String charB,
    String label,
    int tension,
    int trust,
  ) {
    return '$charA↔$charB=$label($tensionLabel$tension/$trustLabel$trust)';
  }

  // ---------------------------------------------------------------------------
  // Convenience helpers
  // ---------------------------------------------------------------------------

  /// All five beat tags as a set for validation.
  Set<String> get beatTags => {
    beatFact,
    beatDialogue,
    beatAction,
    beatInternal,
    beatNarration,
  };

  /// Chinese locale — the original prompt language.
  static const zh = PromptLocale(
    novelLanguage: 'Chinese',
    colon: '：',
    sysSceneProse:
        'You are a scene prose generator for a Chinese novel. '
        'Return the finished scene prose in plain text.',
    sysSceneDirectorPolish:
        'You are a scene plan polisher for a Chinese novel. '
        'Use this 4-line plan shape:\n'
        '目标：...\n'
        '冲突：...\n'
        '推进：...\n'
        '约束：...\n'
        'Polish the existing plan. Make each line concrete and specific — '
        'reference character roles, tension dynamics, and turning points. '
        'Keep the structure and stay brief.',
    sysSceneEditorial:
        'You are a scene editor for a Chinese novel. '
        'You receive roleplay prose fragments plus resolved scene beats and '
        'polish them into coherent prose. Guidance:\n'
        '1. Use the roleplay draft as the primary prose base when present.\n'
        '2. Preserve every beat\'s factual content exactly.\n'
        '3. Add connective tissue and sensory detail around the fragments.\n'
        '4. Keep all beat facts present and aligned; keep character actions, dialogue order, and scene facts aligned.\n'
        '5. Return the finished prose in plain text.',
    sysSceneReviewTemplate:
        'You are a {passName} for a Chinese novel. '
        'Use this 2-line review shape:\n'
        '决定：PASS or 决定：REWRITE_PROSE or 决定：REPLAN_SCENE\n'
        '原因：...\n'
        'Focus on blocking issues. Keep the second line brief.',
    sysDynamicRoleAgent:
        'You are a dynamic role agent for a Chinese novel scene. '
        'Use this 3-line role brief:\n'
        '立场：...\n'
        '动作：...\n'
        '禁忌：...\n'
        'Keep every line concrete and brief.',
    sysDynamicRoleAgentWithTools:
        'You are a dynamic role agent for a Chinese novel scene. '
        'Use 3 core lines plus optional retrieval lines:\n'
        '立场：...\n'
        '动作：...\n'
        '禁忌：...\n'
        '检索：tool_name|query|purpose (optional, repeat for multiple)\n'
        'Retrieval tool options: character_profile, relationship, world_setting, '
        'past_event\n'
        'Keep every line concrete and brief.',
    sysSceneBeatResolve:
        'You are a scene beat resolver for a Chinese novel. '
        'Output one beat per line, each starting with a type tag:\n'
        '[事实] [对白] [动作] [心理] [叙述]\n'
        'Followed by @characterId and then the content.\n'
        'Example: [对白] @char01 你怎么来了\n'
        'Example: [动作] @char02 转身走向窗边\n'
        'Example: [事实] @narrator 此时已是深夜\n'
        'Use beat lines for the response.',
    sysThoughtExtraction:
        'You are a story analysis assistant. Given scene prose, beat contents, '
        'and review reasons, extract thought atoms as a JSON array. Each object '
        'with fields: thoughtType (persona|plotCausality|stateChange|foreshadowing|'
        'style|worldConsistency), content (string), confidence (0.0-1.0), '
        'sourceIds (string array), rootSourceIds (string array), '
        'tags (string array). Return the JSON array.',
    targetLabel: '目标',
    conflictLabel: '冲突',
    progressionLabel: '推进',
    constraintLabel: '约束',
    decisionLabel: '决定',
    reasonLabel: '原因',
    stanceLabel: '立场',
    actionLabel: '动作',
    tabooLabel: '禁忌',
    retrievalLabel: '检索',
    beatFact: '事实',
    beatDialogue: '对白',
    beatAction: '动作',
    beatInternal: '心理',
    beatNarration: '叙述',
    contributionAction: '行动',
    contributionDialogue: '对白',
    contributionInteraction: '互动',
    pacingSlow: '缓慢铺陈',
    pacingMedium: '中等推进',
    pacingFast: '快速推进',
    toneTense: '紧张',
    toneCalm: '平和',
    toneComplex: '复杂',
    toneNeutral: '中性',
    tensionKeywords: ['逼', '拦', '冲突', '对峙', '威胁', '危险', '紧迫', '追', '逃'],
    calmKeywords: ['回忆', '叙述', '平静', '日常', '闲聊', '宁静'],
    taskLabel: '任务',
    sceneLabel: '场景',
    sceneShortLabel: '场',
    summaryLabel: '摘要',
    directorLabel: '导演',
    directorPlanLabel: '导演计划',
    roleInputLabel: '角色输入',
    targetLengthLabel: '目标字数',
    charactersUnit: '汉字',
    currentAttemptLabel: '当前尝试',
    noneLabel: '无',
    rewriteFeedbackLabel: '复写反馈',
    editorialFeedbackLabel: '编辑反馈',
    proseLabel: '正文',
    reviewLabel: '评审',
    rulesOnlyBlocking: '规则：聚焦阻塞问题，正文改写交给后续步骤',
    knownFactsLabel: '已知事实',
    toneFieldLabel: '基调',
    pacingFieldLabel: '节奏',
    contextLabel: '上下文',
    retrievalContextLabel: '检索上下文',
    sceneBeatsLabel: '场景拍',
    listSeparator: '；',
    chapterLabel: '章',
    localPlanLabel: '本地计划',
    formatLabel: '格式',
    optionalTag: '可选',
    constraintDefaultText: '遵守当前世界观和角色设定',
    constraintWorldNodesText: '遵守{nodes}相关规则',
    conflictDefaultText: '围绕场景目标推进',
    conflictSingleCharText: '{name}({role})在目标上面临内外压力',
    namesConjunction: '与',
    conflictMultiCharText: '{names}在目标上相互施压',
    progressionDualTemplate: '{first}施压→{second}反应→{core}',
    inferMotivationBoth: '主动推进场景目标',
    inferMotivationAction: '通过行动影响局势',
    inferMotivationDialogue: '通过对话表达立场',
    inferMotivationDefault: '参与场景推进',
    inferEmotionalArcAction: '坚定→施压→达成或受挫',
    inferEmotionalArcDialogue: '试探→交锋→表态',
    inferEmotionalArcDefault: '跟随场景节奏',
    inferKeyActionAction: '采取关键行动改变局势',
    inferKeyActionDialogue: '说出关键台词推动冲突',
    inferKeyActionInteraction: '与他人互动揭示信息',
    inferKeyActionDefault: '按角色设定行动',
    beliefLabel: '信念',
    relationshipLabel: '关系',
    socialPositionLabel: '社会地位',
    actualInfluenceLabel: '实际影响力',
    charMotivationLabel: '角色动机',
    charEmotionalArcLabel: '情绪弧线',
    charKeyActionLabel: '关键动作',
    roleLabel: '角色',
    participationLabel: '参与',
    synopsisLabel: '梗概',
    tensionLabel: '张力',
    trustLabel: '信任',
    sceneToneLabel: '场景基调',
  );

  /// English locale.
  static const en = PromptLocale(
    novelLanguage: 'English',
    colon: ': ',
    sysSceneProse:
        'You are a scene prose generator for an English novel. '
        'Return the finished scene prose in plain text.',
    sysSceneDirectorPolish:
        'You are a scene plan polisher for an English novel. '
        'Use this 4-line plan shape:\n'
        'Target: ...\n'
        'Conflict: ...\n'
        'Progression: ...\n'
        'Constraint: ...\n'
        'Polish the existing plan. Make each line concrete and specific — '
        'reference character roles, tension dynamics, and turning points. '
        'Keep the structure and stay brief.',
    sysSceneEditorial:
        'You are a scene editor for an English novel. '
        'You receive roleplay prose fragments plus resolved scene beats and '
        'polish them into coherent prose. Guidance:\n'
        '1. Use the roleplay draft as the primary prose base when present.\n'
        '2. Preserve every beat\'s factual content exactly.\n'
        '3. Add connective tissue and sensory detail around the fragments.\n'
        '4. Keep all beat facts present and aligned; keep character actions, dialogue order, and scene facts aligned.\n'
        '5. Return the finished prose in plain text.',
    sysSceneReviewTemplate:
        'You are a {passName} for an English novel. '
        'Use this 2-line review shape:\n'
        'Decision: PASS or Decision: REWRITE_PROSE or Decision: REPLAN_SCENE\n'
        'Reason: ...\n'
        'Focus on blocking issues. Keep the second line brief.',
    sysDynamicRoleAgent:
        'You are a dynamic role agent for an English novel scene. '
        'Use this 3-line role brief:\n'
        'Stance: ...\n'
        'Action: ...\n'
        'Taboo: ...\n'
        'Keep every line concrete and brief.',
    sysDynamicRoleAgentWithTools:
        'You are a dynamic role agent for an English novel scene. '
        'Use 3 core lines plus optional retrieval lines:\n'
        'Stance: ...\n'
        'Action: ...\n'
        'Taboo: ...\n'
        'Retrieval: tool_name|query|purpose (optional, repeat for multiple)\n'
        'Retrieval tool options: character_profile, relationship, world_setting, '
        'past_event\n'
        'Keep every line concrete and brief.',
    sysSceneBeatResolve:
        'You are a scene beat resolver for an English novel. '
        'Output one beat per line, each starting with a type tag:\n'
        '[Fact] [Dialogue] [Action] [Internal] [Narration]\n'
        'Followed by @characterId and then the content.\n'
        'Example: [Dialogue] @char01 What are you doing here?\n'
        'Example: [Action] @char02 turns and walks to the window\n'
        'Example: [Fact] @narrator It was already late at night\n'
        'Use beat lines for the response.',
    sysThoughtExtraction:
        'You are a story analysis assistant. Given scene prose, beat contents, '
        'and review reasons, extract thought atoms as a JSON array. Each object '
        'with fields: thoughtType (persona|plotCausality|stateChange|foreshadowing|'
        'style|worldConsistency), content (string), confidence (0.0-1.0), '
        'sourceIds (string array), rootSourceIds (string array), '
        'tags (string array). Return the JSON array.',
    targetLabel: 'Target',
    conflictLabel: 'Conflict',
    progressionLabel: 'Progression',
    constraintLabel: 'Constraint',
    decisionLabel: 'Decision',
    reasonLabel: 'Reason',
    stanceLabel: 'Stance',
    actionLabel: 'Action',
    tabooLabel: 'Taboo',
    retrievalLabel: 'Retrieval',
    beatFact: 'Fact',
    beatDialogue: 'Dialogue',
    beatAction: 'Action',
    beatInternal: 'Internal',
    beatNarration: 'Narration',
    contributionAction: 'Action',
    contributionDialogue: 'Dialogue',
    contributionInteraction: 'Interaction',
    pacingSlow: 'Slow build-up',
    pacingMedium: 'Medium pace',
    pacingFast: 'Fast pace',
    toneTense: 'Tense',
    toneCalm: 'Calm',
    toneComplex: 'Complex',
    toneNeutral: 'Neutral',
    tensionKeywords: [
      'force',
      'block',
      'conflict',
      'confront',
      'threat',
      'danger',
      'urgent',
      'chase',
      'escape',
    ],
    calmKeywords: ['memory', 'narration', 'calm', 'daily', 'chat', 'peaceful'],
    taskLabel: 'Task',
    sceneLabel: 'Scene',
    sceneShortLabel: 'Scene',
    summaryLabel: 'Summary',
    directorLabel: 'Director',
    directorPlanLabel: 'Director plan',
    roleInputLabel: 'Role input',
    targetLengthLabel: 'Target length',
    charactersUnit: 'characters',
    currentAttemptLabel: 'Current attempt',
    noneLabel: 'None',
    rewriteFeedbackLabel: 'Rewrite feedback',
    editorialFeedbackLabel: 'Editorial feedback',
    proseLabel: 'Prose',
    reviewLabel: 'Review',
    rulesOnlyBlocking:
        'Rules: focus on blocking issues; prose rewriting happens in later steps',
    knownFactsLabel: 'Known facts',
    toneFieldLabel: 'Tone',
    pacingFieldLabel: 'Pacing',
    contextLabel: 'Context',
    retrievalContextLabel: 'Retrieval context',
    sceneBeatsLabel: 'Scene beats',
    listSeparator: '; ',
    chapterLabel: 'Chapter',
    localPlanLabel: 'Local plan',
    formatLabel: 'Format',
    optionalTag: 'optional',
    constraintDefaultText: 'Follow current worldview and character settings',
    constraintWorldNodesText: 'Follow rules related to {nodes}',
    conflictDefaultText: 'Drive toward scene goal',
    conflictSingleCharText:
        '{name}({role}) faces internal and external pressure',
    namesConjunction: 'and',
    conflictMultiCharText: '{names} exert mutual pressure toward the goal',
    progressionDualTemplate: '{first} presses → {second} reacts → {core}',
    inferMotivationBoth: 'Actively drive scene goal',
    inferMotivationAction: 'Influence situation through action',
    inferMotivationDialogue: 'Express stance through dialogue',
    inferMotivationDefault: 'Participate in scene progression',
    inferEmotionalArcAction: 'Firm → Press → Achieve or setback',
    inferEmotionalArcDialogue: 'Probe → Clash → State position',
    inferEmotionalArcDefault: 'Follow scene rhythm',
    inferKeyActionAction: 'Take key action to change situation',
    inferKeyActionDialogue: 'Deliver key line to drive conflict',
    inferKeyActionInteraction: 'Interact with others to reveal information',
    inferKeyActionDefault: 'Act according to character setting',
    beliefLabel: 'Beliefs',
    relationshipLabel: 'Relationships',
    socialPositionLabel: 'Social position',
    actualInfluenceLabel: 'Actual influence',
    charMotivationLabel: 'Character motivation',
    charEmotionalArcLabel: 'Emotional arc',
    charKeyActionLabel: 'Key action',
    roleLabel: 'Role',
    participationLabel: 'Participation',
    synopsisLabel: 'Synopsis',
    tensionLabel: 'tension',
    trustLabel: 'trust',
    sceneToneLabel: 'Scene tone',
  );

  /// Resolve a [PromptLanguage] to its const [PromptLocale].
  static const Map<PromptLanguage, PromptLocale> _map = {
    PromptLanguage.zh: PromptLocale.zh,
    PromptLanguage.en: PromptLocale.en,
  };

  /// Look up the locale for [language].
  static PromptLocale forLanguage(PromptLanguage language) => _map[language]!;
}
