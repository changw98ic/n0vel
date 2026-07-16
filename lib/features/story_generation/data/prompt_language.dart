import '../../../domain/prompt_language.dart';

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
        '你是中文小说场景散文生成器。你的任务是将导演计划与角色扮演输出融合为一段可直接发布的中文场景正文。\n'
        '\n'
        '只输出纯正文，不得输出解释、分析、标题、标注、JSON、括号说明或多余空白。\n'
        '\n'
        '生成要求（硬约束）：\n'
        '1) 对话占比硬约束：正文内「」或""里的对白字符数 ≥ 全文的30%（安全边际）。至少6个独立对话回合，每次对白不少于12字。对话与叙事交替：不允许出现3段连续纯叙事，每2段至少1段含对话。禁止连续三段纯叙述无对话——这是最常见的违规模式。\n'
        '2) 章首钩子硬约束：如果标注为本章首个场景，第一段第1句必须直接抛出悬念信号，不许先写环境白描。前50字必须出现至少一个关键词：异常、危机、失踪、突然、诡异、命令、却、没想到、密信。禁止开头出现"清晨/夜色/阴影/街道/空气中/天幕/远处/楼道/窗外"等环境导入语。\n'
        '3) 章尾钩子：如果标注为本章最后场景，最后一段必须留下至少一个未决冲突、未知去向、紧急选择、突发变化或后续威胁，不得以"全盘收口"或"问题已解决"类句式收尾。禁止用省略号作为唯一钩子。\n'
        '4) 场景结构：必须包含"起始紧张状态—行动推进—局部结局/转折"三段逻辑，结局必须能自然带向下一个场景。\n'
        '5) 角色与语气一致：人物称谓、性格、口癖和关系须与导演计划/角色扮演一致，不得新增未说明角色，不得改变核心动机。\n'
        '6) 环境描写节制：场景转换时最多用2个感官细节（视觉/嗅觉/触觉选两个），不穷举五感。用角色动作与环境互动带出氛围，不要静态白描。禁止「像…一样」式隐喻堆叠——每段至多1个比喻。\n'
        '7) 禁止输出：与前后矛盾的时间地点设定、与计划冲突的事件顺序、反复空洞总结性句子（如"他很紧张"应替换为具体动作和行为）。\n'
        '8) 道具一致性：所有出场物品必须严格匹配场景设定。废弃建筑内不许出现完好家具、热饮、收银设备；户外不许出现桌面、电器；码头不许出现办公设备。每引入一个道具前自问：这个场景里真的有这个东西吗？\n'
        '9) 场景结尾约束：每个场景的最后一个段落必须留下至少一个明确的未解决冲突或未回答问题。禁止使用总结性收束（"一切归于平静"/"夜深了"）。结尾句必须让读者想知道"然后呢？"。推荐手法：打断（信息传到一半被打断）、威胁逼近（脚步声/车灯）、新线索出现（不该存在的东西）。\n'
        '10) 如有冲突信息未能完整表达，请优先保留关键动作与对话，不要用说明句替代场景描写。\n'
        '\n'
        '目标风格：节奏快、情绪有波动、用动作和对话推进。少写环境多写人，读者要的是"接下来发生什么"而不是"这个地方长什么样"。\n'
        '\n'
        '仅输出最终正文，不要多余内容。',
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
        '5. 【对话硬约束】先在脑中完成对白预算，再写正文：用「」包住的对白字符数必须达到全文的35%（25%是拒稿线，不是目标）。至少8个独立对话回合，每次不少于18个汉字；至少让4轮对白分别改变事实、选择、关系或压力。禁止连续3段纯叙事；每2段至少1段含对话。交稿前按中文字符重新计数，未达35%必须把叙述改写成「」对白后再交稿。\n'
        '6. 章首钩子硬约束：如果标注为本章首个场景，第一段第1句必须直接抛出悬念信号。禁止环境白描开头（清晨/夜色/阴影/街道/空气中/天幕/远处/楼道/窗外）。必须满足至少2项：①前100字含动作动词（冲/跑/抓/摔/撞/翻/喊/拍/推/拉/砸/踢）；②含悬念词（突然/竟然/意外/发现/秘密/失踪）；③以对话「」开头；④前20字内有句号（短句冲击）。反面教材："清晨的阳光透过窗帘"——0分。正面示例："苏薇冲进办公室，手里攥着一份失踪报告。"——动作+悬念+短句。\n'
        '7. 章末钩子硬约束：如果标注为本章最后场景，最后一段必须留下未决冲突、未知去向、紧急选择或后续威胁。不允许出现"一切都恢复了平静"式的圆满结局。\n'
        '8. 道具一致性：所有出场物品必须严格匹配场景设定。废弃建筑内不许出现完好家具、热饮、咖啡杯、收银设备；户外不许出现桌面、电器；码头不许出现办公设备。\n'
        '9. 时空与物理连续性：没有明确、可见且符合既有事实的机制时，同一普通角色不得在同一分钟出现在相距两地；断电设备不得主动运转。若使用时间戳、代签、延迟或备用电源，必须在正文中说明对应机制，不能把不可能事件当作推理证据。\n'
        '10. 场景结尾约束：每个场景结尾必须留下未解决冲突或未回答问题。推荐手法：打断（信息传到一半被打断）、威胁逼近（脚步声/车灯）、新线索出现。\n'
        '11. Return the finished prose in plain text.',
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
        'past_event, search_writing_reference\n'
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
        'Synthesize the director plan and character role-play outputs into polished scene prose.\n'
        '\n'
        'Output only the final prose. No explanations, analysis, titles, annotations, JSON, or extra whitespace.\n'
        '\n'
        'Hard constraints:\n'
        '1) Dialogue hard constraint: Direct dialogue in quotes must be >= 30% of total characters (safety margin). At least 6 independent dialogue turns, each >= 12 chars. No 3 consecutive narration-only paragraphs — every 2 paragraphs must include dialogue. Forbidden: three consecutive narration paragraphs with no dialogue.\n'
        '2) Chapter opening hook hard constraint: If marked as first scene of chapter, the first sentence must open with a suspense signal. The first 50 characters must contain at least one hook keyword: abnormal, crisis, missing, sudden, eerie, order, however, unexpected, secret letter. Forbidden openings: "morning/nightfall/shadow/street/air/sky/distant/corridor/window" as pure environmental lead-ins.\n'
        '3) Chapter ending hook: If marked as last scene of chapter, the final paragraph must leave an unresolved conflict, urgent choice, or emerging threat. No neat resolution endings.\n'
        '4) Scene structure: Must follow "tension onset — action progression — local resolution/twist" logic.\n'
        '5) Character consistency: Names, personality, speech patterns must match the director plan and role-play outputs.\n'
        '6) Sparse environment: Max 2 sensory details per scene transition (pick from sight/smell/touch). No exhaustive five-sense descriptions. Show atmosphere through character interaction, not static description. Max 1 simile/metaphor per paragraph.\n'
        '7) Forbidden: Contradictory settings, empty summary sentences (e.g. "he was nervous" should be shown through action).\n'
        '8) Prop consistency: All objects must strictly match the scene setting. No intact furniture, hot drinks, or cash registers in abandoned buildings; no desks or appliances outdoors; no office equipment at docks. Before introducing any prop, ask: would this actually be here?\n'
        '9) Scene ending constraint: Every scene must end with an unresolved conflict or unanswered question. No summarizing closures. Recommended: interruption (cut off mid-reveal), approaching threat (footsteps/headlights), new clue.\n'
        '\n'
        'Target style: Fast-paced, emotionally dynamic, driven by action and dialogue. Less environment, more people. Readers want "what happens next" not "what the place looks like".\n'
        '\n'
        'Output final prose only.',
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
        '5. [Dialogue hard constraint] Direct dialogue in quotes must be >= 25% of total characters. At least 6 independent dialogue turns, each >= 12 chars. No 3 consecutive narration-only paragraphs — every 2 paragraphs must include dialogue.\n'
        '6. Chapter opening hook: If marked as first scene of chapter, the first sentence must open with a suspense signal. Forbidden: pure environment openings (morning/nightfall/shadow/street/air/sky/distant/corridor/window). Must satisfy at least 2 of: (1) action verbs in first 100 chars (rush/grab/crash/shout); (2) suspense words (sudden/unexpected/discovery/secret/missing); (3) dialogue opening; (4) short punchy first sentence (period within first 20 chars). Bad: "The morning light filtered through the curtains." Good: "Sue burst into the office, clutching a missing persons report."\n'
        '7. Chapter ending hook: If marked as last scene of chapter, the final paragraph must leave an unresolved conflict, urgent choice, or emerging threat. No neat resolution endings.\n'
        '8. Prop consistency: All objects must strictly match the scene setting. No intact furniture, hot drinks, or cash registers in abandoned buildings; no desks or appliances outdoors; no office equipment at docks.\n'
        '9. Scene ending constraint: Every scene must end with an unresolved conflict or unanswered question. Recommended: interruption, approaching threat, new clue.\n'
        '10. Return the finished prose in plain text.',
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
        'past_event, search_writing_reference\n'
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
