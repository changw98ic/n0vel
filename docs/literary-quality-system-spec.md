# 跨题材长篇文学质量系统规格

| 元数据 | 值 |
|---|---|
| 状态 | Accepted specification；implementation not started |
| 版本 | 1.0 |
| 日期 | 2026-07-20 |
| 适用仓库 | `changw98ic/n0vel` |
| GitHub 记录 | [changw98ic/n0vel#100](https://github.com/changw98ic/n0vel/issues/100) |
| 实施范围 | 场景/章节生成、项目文风、质量评测、定向修复、长篇账本、读者效果校准 |
| 本轮边界 | 规格与真实模型基线，不修改生产逻辑或现有阈值 |

## 0. 执行摘要

本规格把目标定义为“跨题材的名作级控制力”，而不是“古风”或模仿某位作者。系统必须同时做到：

1. **主线稳定**：核心叙事承诺、阶段目标和因果推进不漂移。
2. **叙事稳定**：人物动机、POV 知识边界、世界规则、关系、物件、伏笔和后果可追踪且不冲突。
3. **文风可变**：每个项目拥有自己的叙述距离、语域、修辞来源、句法密度、对白策略和节奏曲线。
4. **节奏服从场景功能**：快慢不是统一指标；偏离项目平均值可以是有效选择。
5. **深层效果可验证**：叙事引力、认知参与、人物占有感、世界自主感、情绪沉淀、价值压力、重读增值和项目不可替代性，必须通过长篇与盲评证据验证。

核心决策：不直接删除现有 `overall >= 95 / critical >= 90`，也不继续让它控制所有自动迭代。新系统先以影子模式并行运行，再按校准证据切换：

| 层级 | 决策 | 是否能被其他分数抵消 |
|---|---|---|
| 硬正确性与合规 | Pass/Fail | 不能 |
| 场景工艺 | 85/90/92/95 分层候选状态 | 可以定向修复，不能掩盖硬错误 |
| 项目文风适配 | 对齐、风格选择、有效偏离、失配 | 不与“好坏”混成一个数 |
| 读者效果 | 自动代理 + 盲评 + 长篇审计 | 不作为单场景硬门 |
| 名作级控制力 | 20–50 章证据包 | 不能由单次 LLM 高分宣称 |

`95/90` 的结论因此是：**对普通生成迭代过严，对“达到名作质感”的证明又远远不够**。它保留为独立复审后的 `sceneReleaseCandidate` 门槛；普通自动生成使用 `draftKeep`、`autoCandidate`、`highCandidate` 三层状态。评分器版本认证、单场候选、章节质量和整书发布证据是四个不同对象，不能互相冒充。

---

## 1. 背景与现状证据

### 1.1 当前系统已经具备的能力

- 当前质量报告硬编码 `overallMinimum = 95`、`criticalMinimum = 90`，所有关键维度都必须过线；此外还包含吸引力、重复和收尾等非分数门，迁移时必须保留：[scene_quality_reporter.dart](../lib/features/story_generation/data/scene_quality_reporter.dart#L10)。
- 质量失败最多触发两次修复：[generation_pipeline_config.dart](../lib/features/story_generation/data/generation_pipeline_config.dart#L13)、[pipeline_stage_runner_impl.dart](../lib/features/story_generation/data/pipeline_stage_runner_impl.dart#L1055)。
- 当前步骤 8 是确定性门，步骤 9 是最终 council，步骤 10 是派生写入清单，步骤 11 是质量门，步骤 12 是无 provider 的 finalization：[generation_stage_checkpoint_codec.dart](../lib/features/story_generation/data/generation_stage_checkpoint_codec.dart#L17)、[pipeline_stage_runner_impl.dart](../lib/features/story_generation/data/pipeline_stage_runner_impl.dart#L997)。
- `SceneBrief`、`SceneTaskCard`、`NarrativeArcState`、认知更新器和 continuity ledger 已经承载大量叙事状态，只是尚未被统一成质量合同：[scene_runtime_models.dart](../lib/features/story_generation/data/scene_runtime_models.dart#L8)、[narrative_arc_models.dart](../lib/features/story_generation/data/narrative_arc_models.dart#L63)、[scene_cognition_updater.dart](../lib/features/story_generation/data/scene_cognition_updater.dart#L5)。
- `GenerationLedgerSqliteStore` 已经明确 ledger 是 durable authority，并通过 proof、pending write、receipt 和 committed continuity 保护作者接受边界：[generation_ledger.dart](../lib/features/story_generation/data/generation_ledger.dart#L35)、[generation_ledger_candidate_finalizer.dart](../lib/features/story_generation/data/generation_ledger_candidate_finalizer.dart#L162)。
- 当前风格 profile 能表达类型、POV、叙述距离、节奏、句长、对白比例、描写密度、情绪强度、语气和禁用模式：[style_reference_config.dart](../lib/features/story_generation/data/style_reference_config.dart#L1)。

### 1.2 当前缺口

1. 硬错误、工艺弱点、风格选择和有效偏离被压进同一个分数，导致处置错误。
2. `94` 分可以触发整场 editorial retry，即使没有明确缺陷；修复可能破坏已经正确的叙事。
3. 当前风格相似度主要依赖句长、对白、标点和句型分布，只能做表层诊断，不能证明项目声音。
4. 当前 scorer 明确只评 supplied scene，因此无法证明跨章伏笔、人物弧、情绪沉淀或重读增值。
5. 参考库默认绑定具体作品标签；现有本地语料缺少统一的授权/来源 manifest，不能作为正式生产模仿目标。
6. 当前实测分布说明 `95` 可达，但还没有被校准：旧三章报告 12 个场景均值约 `91.58`、范围 `88–94`、没有 95；真实 provider canary 出现 95–96，但它是 non-release 证据，且不含完整长篇/风格校准。

### 1.3 2026-07-20 合入前真实模型基线

规格合入前按 issue #100 的前置条件执行了一次新的真实模型原创生成。正式三场 production canary 在网络请求发出前被运行策略拒绝，因为该入口会向第三方发送仓库提示模板与场景上下文；没有绕过该拒绝。随后改用数据边界更窄的合成 canary：只向智谱 Coding Plan 端点（Anthropic Messages 兼容协议）/ `glm-5.2` 发送现场编写的原创低魔西幻悬疑提示，不包含仓库源码、项目正文、参考作品原文或用户数据。

| 项目 | 结果 |
|---|---|
| provider response | 成功；`model=glm-5.2`，`stop_reason=end_turn` |
| token | input 210；output 2299；web search 0 |
| 正文规模 | 从正文标题行至 EOF 按 CJK Unified Ideographs 基本区 `U+4E00–U+9FFF` 统计为 2468 个汉字（含标题），落在提示要求的 2200–2800 字区间 |
| 合同遵循 | 第三人称限知、目标/阻碍/转折/代价/新悬念、物件/空间主链、节奏转换和无元叙事均通过；低魔题材兑现偏弱 |
| 读者口径 agent 评审 | overall 86；文笔 86、连贯 88、人物能动性 84、完整度 89、节奏 83、项目声音 82、深层效果 84 |
| 对抗 agent 评审 | overall 85；指出说明性过强、因果过度宣判、低魔信号不足、短句模板感与潮汐措辞含混 |
| 分层决策 | `draftKeep`；不满足 `autoCandidate >=90`，更不满足 `sceneReleaseCandidate >=95` |

这次基线的意义不是证明系统已经达到目标，而是验证评分校准问题确实存在：该章主线和物件连续性成立、具备可修价值，如果只有 legacy 95 门就会被当作失败整场重试；但它距离发布质感也明显不足，不能因“结构完整”而虚报 90–95。V2 必须保留该候选并把说明性过强、题材兑现、因果证据与节奏模板感转成可定位的 craft/style finding。这里的 85/86 是两次 agent 读者口径 spot-check，不是人类盲评，也不进入 `EvaluatorPolicyCertification`。

证据边界：本次 canary 证明真实模型调用、单章提示遵循与读者口径评分 spot-check，不证明生产 DI、candidate proof/receipt、secret-free production report、人类盲评、三章稳定性或 20–50 章长篇效果。响应 ID 为 `msg_2026072018232751a638820c4e4f40`。正文 section 的规范化方式是：UTF-8/LF，从 `# 旧水闸的灯` 标题行读取至 EOF，保留结尾换行；其 SHA-256 为 `2b53e16b8bc290b7da29652e3af6bed41f430e35eb7ef16e566712b571cee645`。完整 Markdown artifact SHA-256 为 `2195794f209d3f9de246b4fbbcb0f253a1b883250559c5591419d487a6da48f9`，合成请求文件为 `52c9ead1e1dc8554a7f667ef22a4a65364435e9eb6cdb50e56077a9ee4dbc8a7`，captured response metadata 为 `f6ee8f52d87a5542eae3a3ef03986c79002543f693edb10b640b6a0ea3713bf4`，评审报告为 `ed999ed1c5d0eedc6c806d3d9d4542d8771bb6dfc84375b6378c522e0bf2d6f8`，production-canary refusal 记录为 `89d23cb2b2c25f01540a4ac6f2be4ee392d0caacce11be7b8ced97876b91e022`。原始正文、合成请求、响应元数据和双 agent 评审报告保存在本地 `.omx/evidence/literary-quality-spec-canary-20260720/`；该目录按仓库策略不纳入版本控制，issue 记录保留可审计摘要。

---

## 2. 目标、非目标与术语

### 2.1 产品目标

- G1：不同题材共用同一套叙事正确性底座。
- G2：不同项目拥有可持久化、可版本化、可解释的独有声音。
- G3：慢热、留白、粗粝、厚重铺陈、快速回报等风格选择不被平均模板误杀。
- G4：每次自动修复有证据、有范围、有不变量、有重验清单。
- G5：长篇状态只在候选被作者接受后写入权威 ledger。
- G6：评分器的版本、输入合同、文本哈希、置信度和分歧均可审计。
- G7：发布声明依赖校准语料、双评审、盲评和 20–50 章审计，不依赖单一高分。
- G8：所有参考材料有可验证 provenance；未知授权语料默认不进入生成上下文或校准集。

### 2.2 非目标

- 不提供“模仿某作者”模式，不以作者名作为生成目标。
- 不建立统一“高级文风”；项目可以商业、冷峻、粗粝、史诗、诙谐或极简。
- 不把句长、对白比例或标点相似度当作文学质量。
- 不让自动评分器覆盖作者对审美选择的最终决定。
- 不在第一阶段重排流水线阶段序号或重写 SQLite schema。
- 不承诺一次评分达到 95 就等于“名作级”。
- 不把未知授权的本地小说语料用于训练、长摘录、近似仿写或正式发布证据。

### 2.3 固定不变量

以下规则跨题材固定：

- 核心叙事承诺和阶段问题可追踪。
- 因果、时间、空间、世界规则、POV、知识边界一致。
- 人物选择来自已知欲望、恐惧、利益、承诺、创伤或误判。
- 信息释放公平：可以隐藏，不得事后临时改规则欺骗读者。
- 选择产生可追踪后果；伏笔和承诺不得静默遗弃。
- 每场必须产生至少一个可说明的状态变化，或记录“有意暂停”的原因和回收窗口。
- 节奏必须服务场景功能并形成对比，而不是固定快或固定慢。

### 2.4 项目级变量

- 叙述距离与 POV 模式。
- 句长、句法复杂度、段落密度和停顿方式。
- 对白、动作、心理、说明、环境描写的比例。
- 词汇语域、修辞来源、感官偏好和情绪温度。
- 悬念延迟、爽点回报、信息密度、高潮间隔和留白程度。
- 幽默、庄重、粗粝、抒情、技术感、神话感的权重。

### 2.5 深层读者效果

| 效果 | 操作定义 | 主要证据 |
|---|---|---|
| 叙事引力 | 读者形成清晰但未完成的问题 | 继续阅读 A/B、当前问题复述 |
| 认知参与 | 读者会推理、误判并修正 | 线索公平性、推理答案分布 |
| 人物占有感 | 读者能预判、担心、辩护或失望 | 隐名声纹、选择预测、延迟回忆 |
| 世界自主感 | 角色不在场时，势力和规则仍在运转 | offscreen force ledger |
| 情绪沉淀 | 情绪跨章累积或转化，而非一次性刺激 | 情绪 residue、24 小时记忆 |
| 价值压力 | 关键选择具有不可免费撤销的代价 | choice/consequence ledger |
| 重读增值 | 后文能重解释前文细节 | planted/recontextualized 链接 |
| 项目不可替代性 | 换人物、世界或项目后文本不再成立 | voice attribution、swap test |

---

## 3. 质量本体与处置规则

### 3.1 Finding 分类

```dart
enum QualityFindingClass {
  hardError,
  craftWeakness,
  styleChoice,
  effectiveDeviation,
}

enum QualitySeverity { blocker, major, minor, note }

enum QualityAxis {
  causality,
  timeline,
  spatialContinuity,
  worldRule,
  pov,
  characterKnowledge,
  characterMotivation,
  relationship,
  objectState,
  corePromise,
  foreshadowing,
  prose,
  paragraphFunction,
  scenePressure,
  informationControl,
  characterVoice,
  rhythm,
  projectVoice,
  readerEffect,
  provenance,
}
```

| 分类 | 定义 | 默认动作 |
|---|---|---|
| `hardError` | 事实、因果、POV、规则、核心承诺或合规边界被破坏 | 阻断；定向修复或重新规划 |
| `craftWeakness` | 场景成立但压力、句子、人物转折、信息释放等不够有效 | 定向修复；不默认整场重写 |
| `styleChoice` | 慢热、留白、粗粝、反高潮、高密度、低对白等项目允许选择 | 保留；不得当作错误扣分 |
| `effectiveDeviation` | 为当前场景功能故意偏离项目常态，且效果成立 | 保留并记录理由 |

硬规则：

- `hardError` 不能被漂亮文笔或高综合分抵消。
- `styleChoice` 只有在违反当前 `ProjectVoiceProfile` 时才能转成 `craftWeakness`，不能直接转成硬错误。
- `effectiveDeviation` 必须指出其场景功能、证据和预计回归常态的位置。
- `effectiveDeviation` 只能来自 `SceneCraftContract.allowedDeviations` 的事前计划，或事后经独立复审/作者 `AuthorStyleOverride` 接受；评分器不能自行用它为缺陷免责。
- 低分若没有 finding code、证据范围和修复建议，评测结果无效，先重评而不是重写文本。

### 3.2 Finding 证据合同

```dart
final class QualityFinding {
  String findingId;
  QualityFindingClass findingClass;
  QualitySeverity severity;
  QualityAxis axis;
  String code;
  String claim;
  List<TextEvidenceSpan> evidence;
  List<String> contractRefs;
  double calibratedConfidence; // 0..1；模型自报值不得写入此字段
  RepairAction suggestedAction;
  String? effectiveFunction;
}

final class TextEvidenceSpan {
  int startOffset;
  int endOffset;
  String excerptDigest;
  String localExcerpt; // 只在私有质量报告中；遥测不得携带
}
```

验收：`blocker` 和 `major` finding 必须至少有一个文本证据或一个明确的合同/ledger 冲突引用；否则 parser 判为 invalid evaluation。

---

## 4. 目标架构与权威边界

系统由五个模型层和一个基于现有 generation ledger 的长篇投影组成，不创建“巨型总状态对象”，也不创建第二套权威存储。

| 对象 | 作用域 | 权威性 | 可否重建 | 主要消费者 |
|---|---|---|---|---|
| `NarrativeContractChain` | 项目/篇章/场景 | 当前 revision 权威输入链 | 否 | director、硬门、finalizer |
| `ProjectVoiceProfile` | 项目 | 工作区权威配置 | 否 | prompt、编辑、风格评测 |
| `SceneCraftContract` | 场景 revision | 当前写作意图权威 | 可由叙事合同重新规划 | roleplay、narrator、editor、review |
| `ReaderState` | 场景/章节后 | 派生缓存 | 是 | director、reader probe、UI |
| `LayeredQualityResult` | 精确 prose revision | 证据对象 | 可重评，不可跨 hash 复用 | repair、gate、report、finalizer |
| `LongFormLedgerProjection` | 项目全程 | proof/receipt/committed-continuity 的类型化投影 | 是 | 后续场景、恢复、审计 |

唯一 durable authority 仍是当前 `GenerationLedgerSqliteStore` 中经过 proof、pending write、author receipt 和 committed continuity 验证的记录。下面的 long-form 模型只给这些记录提供领域语义，不能绕过现有提交链。

### 4.1 NarrativeContractChain

主线稳定使用三级不可跳过的父子链，而不是让每个场景重新生成一份 `corePromise`。

```dart
final class ProjectNarrativeCharter {
  int schemaVersion;
  String charterId;
  int revision;
  String charterHash;
  String? previousCharterHash;
  String projectId;
  String corePromiseId;
  String corePromiseStatement;
  List<String> centralTensionIds;
  List<String> invariantWorldRuleRefs;
  List<String> invariantPovRules;
  String transformationPolicy;
  String? transitionReceiptId;
}

final class ArcContract {
  int schemaVersion;
  String arcContractId;
  int revision;
  String arcContractHash;
  String projectCharterId;
  String projectCharterHash;
  String? previousArcContractHash;
  String arcId;
  String phaseGoalId;
  String phaseGoalStatement;
  String currentNarrativeQuestion;
  String entryCondition;
  String exitCondition;
  List<String> activePromiseIds;
  List<String> payoffWindowIds;
  String? transitionReceiptId;
}

final class SceneNarrativeContract {
  int schemaVersion;
  String sceneContractId;
  int revision;
  String sceneContractHash;
  String projectCharterHash;
  String arcContractHash;
  String previousAcceptedSceneContractHash;
  String corePromiseId;
  String phaseGoalId;
  String chapterId;
  String sceneId;
  int sceneIndex;
  String sceneContribution;
  PovPolicy povPolicy;
  List<String> worldRuleRefs;
  List<String> requiredFactRefs;
  List<String> forbiddenContradictions;
  List<String> activePromiseIds;
  List<String> payoffWindowIds;
  List<String> requiredStateChangeTypes;
  List<String> castIds;
  String sourceLedgerHash;
  int repairBudget;
  int replanBudget;
}

final class NarrativeTransitionProposal {
  String proposalId;
  String fromContractHash;
  String proposedContractHash;
  String transitionKind; // phaseAdvance, promiseTransform, charterRevision
  String reason;
  List<String> affectedPromiseIds;
  List<String> affectedLedgerEntryIds;
  String authorDecision; // pending, accepted, rejected
  String? authorReceiptId;
}
```

规则：

- `ProjectNarrativeCharter` 是核心叙事承诺的稳定锚；`ArcContract` 只能引用其 hash；`SceneNarrativeContract` 必须引用已接受的 charter、arc 和上一场 contract hash。
- scene contract 由现有 `SceneBrief`、outline、workspace 和 committed ledger 适配生成。
- drafting 开始后不可原地修改；需要变更时创建新 revision 和新 hash。
- 模型不得直接改写 `corePromiseId`、charter 或 phase。变化先成为 `NarrativeTransitionProposal`，只有带作者 receipt 的 accepted proposal 才能成为新的父合同。
- 未授权的 core promise/phase 变化是 `hardError.corePromise`；带合法 receipt 的阶段转换必须通过。
- metadata 只能装非规范扩展，不能藏 canonical 事实。
- 场景可以通过因果、人物、认知、关系、世界、主题/意象任一状态变化服务主线；不要求每场都推进外部事件。

### 4.2 ProjectVoiceProfile

```dart
final class ProjectVoiceProfile {
  int schemaVersion;
  String profileId;
  String projectId;
  String profileHash;
  String displayName; // 仅 UI 使用，不进入生成 prompt
  int styleIntensity; // 0..100
  List<String> genreTags;
  PovMode povMode;
  NarrativeDistancePolicy narrativeDistance;
  RegisterPolicy lexiconRegister;
  List<String> metaphorDomains;
  List<String> sensoryPriorities;
  RhythmPolicy rhythm;
  DialoguePolicy dialogue;
  DensityPolicy descriptionDensity;
  EmotionalTemperature emotionalTemperature;
  List<VoiceConstraint> voiceConstraints;
  String projectOwnedNotes; // 必须通过 imitation-intent lint
  List<String> tabooPatterns;
  List<AllowedDeviation> allowedDeviations;
  List<String> provenanceRefs;
  String promptReleaseHash;
}
```

`RhythmPolicy` 至少包含：

- 场景类型到句长/段落/信息密度的范围，而不是单个固定平均值。
- `slowBurn`、`fastReward`、`wave`、`epicAccumulation`、`custom` 等曲线。
- 高压、缓冲、铺垫、回收、余波场景的差异规则。
- 允许偏离的范围、功能和持续窗口。

规则：

- profile 描述“这个项目如何说话”，不描述“像谁”；schema 不提供 `targetAuthor`、`targetWork` 或 `imitate` 字段。
- `displayName`、source title、creator、`provenanceRefs` 和原始 `projectOwnedNotes` 永不由 prompt renderer 直接渲染。renderer 只接收通过 lint 的结构化 voice fields。
- 第三方来源产生的每条 voice constraint 必须保留 source id；除 user-owned/project-owned 来源外，单一来源不得占全部 constraint 的 40% 以上。
- 表层统计只产生 diagnostic；不能单独阻断。
- profile 变更不能修改人物动机、世界规则或核心承诺。

### 4.3 SceneCraftContract

```dart
final class SceneCraftContract {
  int schemaVersion;
  String craftId;
  String sceneContractId;
  String sceneContractHash;
  String voiceProfileId;
  String voiceProfileHash;
  int revision;
  SceneFunction primaryFunction;
  List<SceneFunction> secondaryFunctions;
  String sceneGoal;
  String blockingConflict;
  String progression;
  String exitCondition;
  List<String> plannedBeats;
  List<StateChangeTarget> desiredStateChanges;
  List<String> requiredReveals;
  List<String> requiredWithholds;
  String readerQuestionBefore;
  String readerQuestionAfterTarget;
  PressureCurve pressureCurve;
  RhythmIntent rhythmIntent;
  List<String> invariantsToPreserve;
  List<AllowedDeviation> allowedDeviations;
  int targetedRepairBudget;
  int fullRewriteBudget;
}
```

规则：

- 由 director 在步骤 1 生成，并适配现有 `SceneTaskCard` / `SceneDirectorOutput`。
- 不得发明 `NarrativeContractChain` 或 ledger 中不存在的新事实。
- 每次修订递增 `revision`；修复只修改白名单字段/文本范围。

### 4.4 ReaderState

```dart
final class ReaderState {
  int schemaVersion;
  String readerStateId;
  String projectId;
  String chapterId;
  String sceneId;
  String runId;
  int candidateRevision;
  int commitOrdinal;
  String sourceProseHash;
  String sourceQualityEvidenceHash;
  Set<String> knownFactIds;
  Set<String> activeQuestionIds;
  Set<String> expectedPayoffIds;
  Set<String> intendedMisbeliefIds;
  List<EmotionalResidue> emotionalResidue;
  List<String> empathyTargetIds;
  List<String> continuationHookIds;
  ReaderEstimate<double> curiosity;
  ReaderEstimate<double> narratorTrust;
  ReaderEstimate<double> attentionLoad;
  String sourceLedgerHash;
  String sourceReviewHash;
}

final class ReaderEstimate<T> {
  T value;
  String source; // ledgerDerived, modelProxy, humanStudy
  String method;
  int sampleSize;
  double calibratedConfidence;
  List<String> evidenceRefs;
}
```

规则：

- `ReaderState` 是派生缓存，不是事实真源；只能从经过 receipt 验证的 ledger writes、accepted prose hash 和 review/quality evidence 重建。
- 候选被拒绝时，不更新权威 reader state。
- subjective 字段必须使用 `ReaderEstimate` 区分模型代理与真实读者观察；模型自报置信度不等于 calibrated confidence。
- 模型预测不能反向覆盖人物/世界事实。

### 4.5 LongFormLedgerProjection

这是现有 generation ledger 上的可回放领域投影，不是新真源。每个条目必须能够追溯到精确 proof/receipt 链：

```dart
final class LongFormLedgerEntry {
  String entryId;
  LedgerKind kind; // promise, characterArc, relationship, worldForce,
                   // consequence, motif, rule, informationBoundary
  String ownerId;
  String introducedAtSceneId;
  String lastAdvancedAtSceneId;
  LedgerStatus status; // open, pressured, transformed, paid, abandonedWithReason
  String statement;
  List<String> evidenceRefs;
  String? expectedResolutionWindow;
  String? parentEntryId;
  String runId;
  int candidateRevision;
  int sourceProseRevision;
  String finalProseHash;
  String pendingWriteSetHash;
  String receiptId;
  int committedAtMs;
  int commitOrdinal;
}
```

写入边界：

1. 生成、review 和步骤 10 只能创建 pending writes。
2. 步骤 12 只能形成 candidate proof/payload，不得把候选当成已接受事实。
3. 只有作者接受候选并产生 commit receipt 后，pending writes 才进入 committed continuity；`LongFormLedgerProjection` 从这些已提交记录重建。
4. 被拒绝或过期候选不得影响后续场景。
5. `StoryGenerationRunSnapshot` 仍是恢复/UI 快照，不能替代 proof 或 receipt。

### 4.6 LayeredQualityResult

```dart
final class LayeredQualityResult {
  int schemaVersion;
  String evidenceId;
  String evidenceHash;
  String proseHash;
  String projectCharterHash;
  String arcContractHash;
  String sceneContractHash;
  String voiceProfileHash;
  String ledgerSnapshotHash;
  String rubricVersion;
  String promptReleaseHash;
  String thresholdPolicyVersion;
  DeterministicGateRef deterministicGate;
  SemanticHardReviewResult semanticHardReview;
  CraftScore craft;
  StyleFitResult styleFit;
  ReaderEffectProbeResult readerEffect;
  LongFormEvidenceRef? longForm;
  List<QualityFinding> findings;
  List<EvaluatorVerdict> evaluatorVerdicts;
  double calibratedConfidence;
  double? evaluatorSelfConfidence; // 仅诊断，不参与 gate
  SceneCandidateDecision decision;
  RepairDirective? repair;
  int createdAtMs;
}
```

任何一个输入 hash 变化都使结果过期。`calibratedConfidence` 取证据完备度、该 finding class 的历史校准下界、重复/双评审一致度三者的最小值；不得直接使用 evaluator 自报值。

绑定规则：

- `legacy95`：现有 `qualityEvidenceHash` 和 candidate proof 完全不变。
- `shadowV2`：V2 结果生成独立 `shadowEvidenceHash`，只写 checkpoint/telemetry，不进入 candidate hash、proof、repair、finalization 或 author acceptance。
- `enforceV2`：`LayeredQualityResult.evidenceHash` 对 prose/contract/voice/ledger/rubric 全部字段做 canonical hash，并复用现有 `CandidateProofRecord.qualityEvidenceHash` 作为 acceptance anchor。Phase 1 不扩展 `acceptCurrentCandidate()` 参数面。
- finalization 只消费与精确 revision 绑定的 enforced quality evidence；shadow evidence 永远不是 acceptance proof。

Phase 1 中 enforceV2 的额外 hashes 只作为 `qualityEvidenceHash` 的构成项；commit/accept 仍只读取现有 `CandidateProofRecord.qualityEvidenceHash`，直到后续 additive schema migration 显式扩展 acceptance 输入面。

### 4.7 Supporting contracts

#### SourceLedgerEntry

```dart
final class SourceLedgerEntry {
  String sourceId;
  String title;
  String? creator;
  SourceLicenseStatus licenseStatus;
  Set<AllowedSourceUse> allowedUses;
  String provenanceUri;
  String provenanceHash;
  String jurisdiction;
  int determinationDateMs;
  int? excerptLimitChars;
  bool attributionRequired;
  String reviewedBy;
  int reviewedAtMs;
}
```

#### AuthorStyleOverride

```dart
final class AuthorStyleOverride {
  String overrideId;
  String projectId;
  String? sceneId;
  String findingCode;
  String voiceProfileHash;
  String reason;
  OverrideScope scope;
  int createdAtMs;
  int? expiresAtMs;
}
```

作者 override 只能接受审美选择、有效偏离或非合规工艺弱点；不能把硬正确性冲突或未知授权风险标记为安全发布。

### 4.8 Wire schema 与 canonical 规则

所有 enum 以以下 lowerCamel 字符串落盘；未知 enum fail closed，不映射到相邻值：

```text
PovMode = firstPersonLimited | thirdPersonLimited | rotatingLimited |
          omniscient | custom
NarrativeDistancePolicy = close | medium | far | variable
RegisterPolicy = colloquial | neutral | elevated | archaic | technical |
                 mixed | custom
SceneFunction = advancePlot | revealCharacter | alterRelationship |
                revealInformation | buildWorldPressure | plantPromise |
                pressurePromise | payPromise | emotionalAftermath |
                thematicCounterpoint | transition
PressureCurve = rising | falling | wave | reversal | plateauWithReason
RepairAction = blockAndReplan | targetedRepair | alignVoice | accept |
               acceptWithNote | rescore | manualReview
StyleFitDecision = aligned | plannedDeviation | approvedDeviation | mismatch
ReferenceUsage = off | abstractFeaturesOnly | licensedExcerpts |
                 userOwnedFullContext | localAnalysisOnly
SourceLicenseStatus = publicDomain | userOwned | licensed | restricted | unknown
AllowedSourceUse = abstractFeatures | shortExcerpt | fullContext |
                   calibration | localRiskScan | training
OverrideScope = sceneRevision | scene | chapter | project
RepairOperation = replaceSpan | deleteSpan | insertBridge | reorderParagraph |
                  alignRegister | restoreFact | restoreMotivation |
                  rewriteWholeScene
LedgerKind = promise | characterArc | relationship | worldForce |
             consequence | motif | rule | informationBoundary
LedgerStatus = open | pressured | transformed | paid | abandonedWithReason
EmotionalTemperature = cold | restrained | neutral | warm | intense | variable
```

Supporting wire shapes：

```dart
final class PovPolicy {
  PovMode mode;
  List<String> allowedPovCharacterIds;
  bool allowFreeIndirectDiscourse;
  bool allowUnreliableNarrator;
  bool allowTimelineReordering;
  List<String> declaredKnowledgeExceptions;
}

final class AllowedDeviation {
  String deviationId;
  String axis;
  String intendedFunction;
  String startCondition;
  String endCondition;
  String authorizedBy; // sceneContract, independentReview, authorOverride
}

final class VoiceConstraint {
  String axis;
  String operator; // prefer, avoid, range, requireContrast
  Object value;
  List<String> sourceIds;
}

final class NumericRange {
  double minimum;
  double maximum;
  String unit;
}

final class RhythmPolicy {
  String curve; // slowBurn, fastReward, wave, epicAccumulation, custom
  Map<String, NumericRange> sentenceLengthBySceneFunction;
  Map<String, NumericRange> paragraphDensityBySceneFunction;
  Map<String, NumericRange> informationDensityBySceneFunction;
  List<AllowedDeviation> allowedDeviations;
}

final class DialoguePolicy {
  NumericRange ratio;
  String cadence;
  List<String> speakerDifferentiationRules;
}

final class DensityPolicy {
  NumericRange descriptionRatio;
  NumericRange interiorityRatio;
  NumericRange expositionRatio;
}

final class StateChangeTarget {
  String targetId;
  String type; // causal, character, knowledge, relationship, world, theme
  String beforeRef;
  String intendedAfter;
  bool required;
}

final class RhythmIntent {
  String sceneFunction;
  String pressureMovement;
  String intendedReaderEffect;
  List<String> allowedDeviationIds;
}

final class CraftScore {
  Map<String, double> dimensions; // exact seven-key allowlist
  double craftOverall;
  double criticalMinimum;
}

final class StyleFitResult {
  StyleFitDecision decision;
  Map<String, String> axisExplanations;
  List<String> deviationIds;
  List<String> evidenceRefs;
}

final class DeterministicGateRef {
  String evidenceHash;
  bool passed;
  List<String> failureCodes;
}

final class SemanticHardReviewResult {
  bool passed;
  List<String> hardFindingIds;
  double calibratedConfidence;
}

final class ReaderEffectProbeResult {
  Map<String, ReaderEstimate<double>> effectEstimates;
  List<String> warnings;
}

final class LongFormEvidenceRef {
  String artifactHash;
  String chapterRange;
  String committedLedgerHash;
}

final class EvaluatorVerdict {
  String evaluatorIdHash;
  String evaluatorRelease;
  double craftOverall;
  List<String> findingIds;
  double calibratedConfidence;
}

final class MetricWithInterval {
  double point;
  double ci95Low;
  double ci95High;
  int sampleSize;
}
```

Canonical JSON 规则：

- key 按 Unicode code point 排序；set 先去重再按字符串排序后编码为 array。
- 必填字段不得为 null；可选字段缺失与显式 null 统一编码为“省略”。
- 空字符串不得代表 unknown；使用明确 enum/nullable field。
- hash 输入必须包含 `schemaVersion`；不能包含绝对本地路径、UI display name 或时间戳（证据对象的 `createdAtMs` 除外，且不进入内容 identity hash）。
- legacy reader 对缺失新字段使用文档指定默认值；不能猜测新的 enum。

### 4.9 新旧模型桥接与 acceptance anchor

| 新对象 | 现有来源/适配器 | Phase 1 承载点 | Acceptance anchor |
|---|---|---|---|
| `ProjectNarrativeCharter` | workspace outline + author settings | safe contract payload | charter hash，经 author transition receipt |
| `ArcContract` | `NarrativeArcState` + outline phase | safe contract payload | arc hash + parent charter hash |
| `SceneNarrativeContract` | `SceneBrief` + committed continuity | ordinal 0/1 payload | scene contract hash + parent hashes |
| `ProjectVoiceProfile` | `StyleProfileRecord` + `ProjectStyleState` | workspace/profile adapter | voice profile hash |
| `SceneCraftContract` | `SceneTaskCard` + `SceneDirectorOutput` | ordinal 1 typed payload | craft hash，被 quality evidence 吸收 |
| deterministic hard evidence | `ProductionPreQualityEvidence` | ordinal 8 | existing deterministic evidence hash |
| semantic hard/craft/style | `SceneReviewResult` + V2 evaluator | ordinal 9/11 | enforceV2 quality evidence hash |
| `ReaderState` | committed `readerStateDelta` writes | rebuildable cache | receipt + commit ordinal + source hashes |
| `LongFormLedgerProjection` | committed `longFormLedgerDelta` writes | generation ledger projection | existing proof/receipt/pending-write chain |
| legacy score | `SceneQualityScore` | ordinal 11 | unchanged in legacy95/shadowV2 |

桥接层是单向的：旧对象仍是 Phase 1 的运行载体，新对象提供 canonical semantics/hash；同一事实不能在两个地方独立修改。

---

## 5. 流水线接入规格

第一阶段不增加或重排 checkpoint ordinal。所有新逻辑在现有边界内增量接入，以避免恢复链和 proof 迁移风险。

| 当前阶段 | 新职责 | 写入 |
|---|---|---|
| 0 `context_enrichment` | 读取 committed ledger、voice profile、source policy；组装 `NarrativeContractChain` | 合同 checkpoint metadata |
| 1 `director` | 生成 `SceneCraftContract` | typed artifact / canonical hash |
| 2 `roleplay` | 消费角色状态、voice、reader state；不得改合同 | 临时 role intent |
| 3 `stage_narration` | 依 POV/叙述距离控制信息释放 | 临时 narration artifact |
| 4 `beat_resolution` | 验证 planned beats 与 state-change target | resolved beat evidence |
| 5 `editorial` | 按 craft contract 产出草稿；修复时只改白名单 | prose revision |
| 6 `preliminary_review` | 分类初步 finding；不做发布判定 | review evidence |
| 7 `polish` | 语言润色但保留叙事不变量 | polished prose |
| 8 `deterministic_gate` | 只执行 provider-free、可重复的 canon/story-mechanics/source/similarity 硬门 | deterministic evidence hash |
| 9 `final_review` | 审精确 polished revision；输出 finding 与 refinement guidance | council evidence |
| 10 `prose_derived_extraction` | 提取 reader-state/long-form pending writes | pending manifest，仅候选态 |
| 11 `quality_gate` | semantic hard review、craft、style、reader proxy；legacy 与 layered evaluator 按 mode 运行 | quality evidence payload |
| 12 `finalization` | 保持 provider-free；绑定精确 hash 和当前 enforced policy | proof/payload/checkpoint |

`stageId` 字符串和 ordinal 0–12 均不得重命名或重排；codec 对 ordinal/stageId 不匹配继续 fail closed。Phase 1 只允许 additive payload。

### 5.1 Finding axis 的执行边界

| 轴/检查 | 执行边界 | 是否 provider-free | 失败如何绑定 |
|---|---|---:|---|
| schema/hash/stale evidence | ordinal 8/12 | 是 | deterministic blocker |
| 已声明实体、时间、物件、地点状态冲突 | ordinal 8 | 是 | `ProductionPreQualityEvidence` |
| outline/contract parent hash/core promise ID 不匹配 | ordinal 8 | 是 | deterministic blocker |
| source manifest admission、excerpt limit | retrieval 前 + ordinal 8 复核 | 是 | source-policy evidence |
| 与已加载参考的 exact/near-reproduction 风险 | ordinal 8 | 是 | similarity risk evidence |
| 因果充分性、人物动机、信息公平性 | ordinal 9/11 | 否 | semantic hard finding |
| 复杂 POV/不可靠叙述/自由间接引语判定 | ordinal 9/11，必须读取 `PovPolicy` | 否 | semantic finding/adjudication |
| prose/paragraph/pressure/voice/information craft | ordinal 11 | 否 | craft finding/score |
| rhythm/project voice | ordinal 11 | 否 | categorical style fit，不进入 craft overall |
| reader effects | ordinal 11 proxy；milestone workflow | 否/人工 | proxy 或 release artifact，不单独 hard-block scene |
| finalizer | ordinal 12 | 是 | 只验证必需 evidence/hash/status，不重新判断文学内容 |

“hardError”描述严重度，不等于“deterministic”。ordinal 8 只承载确定性子集；需要语义判断的硬错误由独立 evaluator/仲裁产生，不能伪装成 provider-free 事实。

### 5.2 Gate mode

```dart
enum LiteraryQualityGateMode {
  legacy95,
  shadowV2,
  enforceV2,
}
```

- `legacy95`：完全保持当前行为。
- `shadowV2`：现有 95/90 仍决定 pass/fail；新结果只记录、不影响重试、finalization 或作者候选。
- `enforceV2`：新分层策略决定候选状态；legacy 分数只做对照。
- 回滚：配置改回 `legacy95`，不需要数据回滚；保留已生成的 shadow evidence 供分析。

默认值在校准通过前必须是 `legacy95`。任何 workspace 进入 `enforceV2` 必须显式记录 threshold policy version。

### 5.3 不变的安全边界

- 步骤 8 失败不能进入步骤 12。
- provider/parse failure fail closed。
- finalization 不调用 provider。
- 失败 revision 不能复用旧 quality evidence。
- checkpoint、snapshot 不能替代 candidate proof/author commit receipt。
- shadow 评测失败不得改变 legacy production 结果，但必须记录失败原因和成本。

---

## 6. 候选状态与阈值政策

### 6.1 四种不同的决策对象

```dart
final class EvaluatorPolicyCertification {
  String certificationId;
  String rubricVersion;
  String promptReleaseHash;
  String evaluatorModelRelease;
  String thresholdPolicyVersion;
  String status; // development, beta, certified, revoked
  String calibrationArtifactHash;
  String blindReviewArtifactHash;
  Map<String, MetricWithInterval> metrics;
  int certifiedAtMs;
}

final class SceneCandidateDecision {
  SceneCandidateStatus status;
  String reasonCode;
  double craftOverall;
  double criticalCraftMinimum;
  StyleFitDecision styleFit;
  List<String> findingIds;
  String evaluatorCertificationId;
}

final class ChapterQualityDecision {
  String chapterId;
  String status; // blocked, draftEligible, releaseEligible, manualReview
  List<String> sceneEvidenceHashes;
  String narrativeChainHash;
  List<String> unresolvedMajorFindingIds;
  String chapterAuditHash;
}

final class BookQualityDecision {
  String projectId;
  String status; // blocked, draftEligible, releaseEvidencePassed, manualReview
  List<String> chapterDecisionHashes;
  String evaluatorCertificationId;
  String blindReviewArtifactHash;
  String longFormAuditArtifactHash;
}
```

- `EvaluatorPolicyCertification` 认证 scorer/rubric 版本是否可信。
- `SceneCandidateDecision` 只判断精确 prose revision。
- `ChapterQualityDecision` 聚合已接受场景和本章 contract/ledger。
- `BookQualityDecision` 才能绑定盲评、长篇审计并形成 `releaseEvidencePassed`。

高分场景不能自动推出章节可发布；高分章节也不能自动推出整书具备深层效果。

### 6.2 Craft 轴、公式与 style 分离

V2 中的 `craftOverall` 只聚合场景工艺，不包含 `rhythmFit`、`projectVoiceFit`、reader effect 或 hard correctness：

| Craft 维度 | 权重 |
|---|---:|
| `prosePrecision` | 0.18 |
| `paragraphFunction` | 0.12 |
| `scenePressure` | 0.18 |
| `characterVoice` | 0.15 |
| `informationControl` | 0.15 |
| `coherence` | 0.12 |
| `completenessAndTurn` | 0.10 |

```text
craftOverall = Σ(dimensionScore × dimensionWeight)
```

- 七个维度必须全部存在且为 0–100；缺失、NaN、越界或 warning 使 evaluation invalid，禁止补零或用均值填充。
- `criticalCraftMinimum` 是七维最小值。
- `prosePrecision` 可以指出机械性断裂、无意重复和失控句法，但不能因为句子“长/短”本身扣分。
- `StyleFitResult` 单独给出 `aligned | plannedDeviation | approvedDeviation | mismatch`，并分别解释 rhythm、register、distance、density、dialogue、imagery。
- style/rhythm 不进入 `craftOverall`。未批准的 `mismatch` 可以触发定向修复；planned/approved deviation 不降低 craft 等级。
- faithfulness 的事实冲突进入 deterministic/semantic hard review；非冲突的细微忠实度建议作为 finding 展示，不参与 craft 平均。

这样，同一份叙事正确、工艺相当的 slow-burn 与 fast-reward 文本应得到相近 craft 结论，但得到不同、各自合理的 rhythm 解释。

### 6.3 场景状态机

```dart
enum SceneCandidateStatus {
  blocked,
  repairRequired,
  draftKeep,
  autoCandidate,
  highCandidate,
  sceneReleaseCandidate,
  manualReview,
}
```

| 状态 | 初始阈值 v1 | 使用方式 |
|---|---|---|
| `blocked` | deterministic 或 semantic hard gate 失败 | 不进入候选；修复合同/文本或重规划 |
| `repairRequired` | hard pass，但 craft overall <85、critical <80、major 数超限，或 unapproved style mismatch | 只产 working revision/repair directive |
| `draftKeep` | craft overall ≥85、critical ≥80 | 可保留和编辑，不产生 authoritative candidate proof |
| `autoCandidate` | craft overall ≥90、critical ≥85、major ≤2、calibrated confidence ≥0.70 | standard 的最低 durable candidate 档 |
| `highCandidate` | craft overall ≥92、critical ≥88、major ≤1、calibrated confidence ≥0.75；或 95+ 但 publication review 尚未完成 | 高质量候选 |
| `sceneReleaseCandidate` | craft overall ≥95、critical ≥90、无 major、双评审一致、calibrated confidence 均 ≥0.80，且 evaluator policy 已 certified | 单场发布候选；不包含盲评/长篇结论 |
| `manualReview` | 重评后仍 invalid、评审冲突、低置信度、预算耗尽、作者要求或边界不清 | 等待作者/编辑/仲裁 |

完整、互斥的决策优先级：

1. schema/parser/stale-hash 无效：独立重评一次；仍无效 → `manualReview`。
2. deterministic 或 semantic hard finding 成立 → `blocked`。
3. 双评审产生 class 冲突、分差超限或低置信度 → `manualReview`。
4. `craftOverall <85`、`critical <80`、当前分档 major 超限或 unapproved style mismatch → `repairRequired`；预算耗尽 → `manualReview`。
5. 85–<90 → `draftKeep`。
6. 90–<92 且 major ≤2 → `autoCandidate`。
7. 92–<95 且 major ≤1 → `highCandidate`。
8. ≥95、critical ≥90、无 major：publication prerequisites 齐全 → `sceneReleaseCandidate`；否则 → `highCandidate`，reason=`publicationReviewPending`。

任何有效输入恰好落入一个状态。reader-effect proxy 只写观察结果，不参与上述单场状态分支。

阈值说明：

- 这是 `threshold-policy-v1-calibration` 的初始值，不是假定真理。
- `enforceV2` 前必须用 gold fixtures、历史样本、真实 provider、盲评共同校准。
- 不再使用一个 overall 作为所有阶段的唯一决策；硬门、style choice、reader effects 独立展示。
- 项目 standing quality target `95` 被保留在 publication 层，不降低最终质量目标。

### 6.4 Gate mode、strictness 与 proof/finalization

| Gate mode | 状态 | 是否调用 `GenerationLedgerCandidateFinalizer` | 是否可 author receipt commit |
|---|---|---:|---:|
| `legacy95` | 由现有 95/90 判定 | 仅 legacy pass | 是，保持现状 |
| `shadowV2` | V2 状态只观察 | 完全按 legacy pass；shadow 不影响 proof | 完全按 legacy |
| `enforceV2` | `blocked/repairRequired/draftKeep/manualReview` | 否 | 否 |
| `enforceV2` | `autoCandidate/highCandidate/sceneReleaseCandidate` | 取决于 strictness 最低档 | 产生 proof 后才可 |

| `QualityStrictness` | 自动 finalization 最低状态 | 自动修复预算 | 评审要求 |
|---|---|---:|---|
| `draft` | 不自动 finalization；作者可显式提交 `autoCandidate+` | 0 | 单评审/代理 |
| `standard` | `autoCandidate` | targeted 1 | 单个 certified evaluator |
| `strict` | `highCandidate` | targeted 2 | 单评审；分歧抽查 |
| `publication` | `sceneReleaseCandidate` | targeted 2、full rewrite 最多 1 且需允许 | 双评审 + certified policy |

`draftKeep` 只进入非权威 working draft；90–91 的 `autoCandidate` 可由作者接受进入正文草稿，92–94 为 `highCandidate`。任何 durable 叙事写入仍必须经过 candidate proof 和 author receipt。

### 6.5 章节与整书聚合

`ChapterQualityDecision.releaseEligible` 必须同时满足：

- 本章所有已接受场景无 hard blocker、无 `repairRequired/manualReview`。
- publication 模式下所有场景为 `sceneReleaseCandidate`，或存在不能覆盖 hard/compliance 的显式 editor release waiver。
- `NarrativeContractChain` parent hash 连续，未经授权的 core promise/phase 变化为 0。
- 章节至少产生一个 accepted state change；所有 due major promises 有状态更新。
- chapter-level continuity、repetition、attractiveness 和 ending evidence 通过。

`BookQualityDecision.releaseEvidencePassed` 还必须满足：

- evaluator policy 为 `certified`。
- 所有目标章节 `releaseEligible`。
- blind-review artifact 通过。
- long-form audit artifact 通过。
- 无来源/近似复现 blocker。

例如：

- `96 + 因果硬错误` → `blocked`。
- `94 + 无硬错误 + minor weakness` → `highCandidate` 或一次定向修复，不整场重写。
- `91 + 符合 profile 的慢热` → 至少 `autoCandidate`，慢不能单独成为失败理由。
- `95 + publication 复审尚未运行` → `highCandidate(publicationReviewPending)`。
- `95 + 低置信度/双评审冲突` → `manualReview`，不能成为 scene release candidate。

---

## 7. 定向修复规格

```dart
final class RepairDirective {
  String directiveId;
  List<String> findingIds;
  List<TextEvidenceSpan> targetSpans;
  Set<RepairOperation> allowedOperations;
  List<String> invariantsToPreserve;
  List<String> forbiddenChanges;
  List<String> requiredRevalidationStages;
  String expectedImprovement;
  int maxAttempts;
  bool fullRewriteAllowed;
  String planHash;
}
```

### 7.1 默认策略

| 情况 | 动作 | 预算 |
|---|---|---|
| 硬错误位于文本 | 最小范围修复；重跑步骤 8、9、11 | 最多 2 次 |
| 合同本身矛盾 | 回到步骤 1 重规划，不让 editor 猜 | 最多 1 次 replan |
| 工艺 major/minor | 优先 targeted patch；重跑受影响门 | standard 最多 1 次，publication 最多 2 次 |
| 风格失配 | 仅按 project profile 修正，不改故事事实 | 最多 1 次 |
| 风格选择/有效偏离 | 保留；必要时记录 author override | 0 次 |
| 低分但无具体 finding | 评测无效；独立重评 | 最多 1 次 |
| 修复预算耗尽 | 保存候选和证据，转 `manualReview` | 禁止无限重写 |

`shadowV2` 中 V2 repair directive 只记录或在隔离副本上离线演练，绝不能改变 production prose、legacy retry、proof 或 finalization。V2 定向修复只在 `enforceV2`（或专门的非生产实验 run）生效。

`fullRewriteAllowed` 默认 `false`。只有满足以下全部条件才可为 `true`：

- 作者模式为 `publication` 且设置为 `fullAllowed`；
- 多个 major finding 覆盖超过 40% 文本，局部补丁会造成更大风险；
- repair plan 列出必须保留的事实、节拍、声纹和有效句段；
- full rewrite 总预算最多 1 次。

“覆盖超过 40%”是 versioned policy heuristic，必须在 calibration artifact 中报告命中率和回归率；它不是文学规律。

修复后如果 narrative/voice/prose hash 任一变化，旧评测全部作废。若需要改变 core promise 或 phase，不能以 repair 名义直接改合同，必须走 `NarrativeTransitionProposal + author receipt`。

---

## 8. 评分器校准与分歧处理

### 8.1 Gold fixture 语料

进入 opt-in `enforceV2` beta 前，至少建立 300 个有 provenance 的 gold fixture，覆盖至少 5 类项目声音。优先使用：

- 项目自有或用户授权文本。
- 公版/明确许可文本。
- 为测试专门创作的合成正负样本。
- 当前历史输出及其人工标注。

禁止把授权未知的名作片段作为生产 gold truth。

最低样本族：

| 样本族 | 最低数量 | 预期 |
|---|---:|---|
| 因果/主线硬错误 | 25 | 全部 blocker |
| POV/知识越界 | 25 | 全部 blocker |
| 世界规则/物件/时间冲突 | 25 | 全部 blocker |
| 人物动机/关系崩坏 | 25 | blocker 或 major |
| 场景工艺弱点 | 50 | targeted repair |
| 慢热/快速回报/厚重铺陈等风格选择 | 50 | accept |
| 有效节奏偏离 | 30 | accept with note |
| 表面漂亮但结构空心 | 30 | major，不得 release |
| 高分伪装坏样本 | 20 | release 通过率 0 |
| 跨题材边界样本 | 每种声音 ≥20 | 不向单一风格收敛 |

表中前九类是 primary quality label，最低数合计 280；每个 fixture 只能计入一个 primary quality label。`跨题材/voice` 和实验叙事是正交标签，可与 primary label 重叠；每个 fixture 至少一个 voice tag。unique fixture 总数仍必须 ≥300，不能通过重复计数满足。

非硬错误对照集必须覆盖：不可靠叙述者、回溯/非线性时间、多 POV、自由间接引语、预先声明的世界规则例外，每类至少 10 个。这些 fixture 必须带相应 `PovPolicy`/contract 声明，预期不被误阻断。

评分 anchor 必须包含 60、75、85、90、95 五档，每档说明“具体缺陷数量和严重度”，不能只写形容词。

正式把 `EvaluatorPolicyCertification.status` 设为 `certified` 前，还需累计至少 300 个独立、人工仲裁的 hard-positive 决策和 300 个 non-hard 决策。开发 fixture 可以计入，但同一个 item 在同一指标分母中只能出现一次。

### 8.2 双评审

publication 模式默认两个相互独立的 evaluator。输入隐藏模型名、生成顺序和旧分数。

自动接受条件：

- 两者 deterministic ref 有效且 semantic hard review 均 pass；
- craftOverall 差值 ≤5；
- finding 分类无实质冲突；
- calibrated confidence 均 ≥0.80；
- 两者都同意 `sceneReleaseCandidate`。

分歧规则：

- 差值 6–8：不能 release；使用较低候选等级或进入人工复审。
- 差值 >8：必须仲裁。
- 任一 evaluator 给 blocker：必须仲裁，仲裁前阻断。
- `styleChoice` 与 `hardError` 冲突：必须仲裁。
- 任一置信度 <0.65：必须仲裁。
- 仲裁不得看到哪个 evaluator 更“权威”，只看证据与合同。

### 8.3 稳定性、误杀与漂移

- scorer/rubric 发布认证时，同一文本、同一合同、同一 rubric 重评 5 次：craftOverall 标准差目标 ≤3；finding class 一致率 ≥80%。普通 PR/普通生成不重复跑 5 次。
- 新 scorer 相对稳定版分布整体偏移超过 5 分，且没有 rubric migration note：阻断发布。
- hard-error recall 点估计 ≥98%，Wilson 95% CI 下界 ≥95%。
- hard-error precision 点估计 ≥95%，Wilson 95% CI 下界 ≥90%。
- non-hard false-block rate 点估计 ≤5%，Wilson 95% CI 上界 ≤8%。
- 随机人工审计中的 blocker overturn rate 点估计 ≤5%，Wilson 95% CI 上界 ≤10%，N≥100；不能只抽取争议样本。
- 风格选择误杀率 ≤5%，95% CI 上界 ≤8%。
- 有效偏离误杀率 ≤10%。
- 高分伪装坏样本的 release 通过率必须为 0。
- 人工双评审 Cohen's kappa ≥0.60；低于该值说明 rubric 尚不稳定。

只报告 recall 不合格：把所有文本都判 blocker 的 evaluator 会因为 precision/false-block/overturn 失败而无法认证。

### 8.4 Calibration artifact

CI 只校验 artifact schema、hash 和阈值；人工标注不会伪装成普通 unit test。

```json
{
  "artifactVersion": "literary-calibration-v1",
  "rubricVersion": "...",
  "thresholdPolicyVersion": "...",
  "corpusHash": "...",
  "uniqueItemCount": 0,
  "primaryClassCounts": {},
  "voiceTagCounts": {},
  "metrics": {
    "hardRecall": {"point": 0, "ci95Low": 0, "ci95High": 0, "n": 0},
    "hardPrecision": {"point": 0, "ci95Low": 0, "ci95High": 0, "n": 0},
    "falseBlock": {"point": 0, "ci95Low": 0, "ci95High": 0, "n": 0},
    "styleFalseBlock": {"point": 0, "ci95Low": 0, "ci95High": 0, "n": 0},
    "overturn": {"point": 0, "ci95Low": 0, "ci95High": 0, "n": 0}
  },
  "repeatability": {},
  "reviewAgreement": {},
  "driftFromCertificationId": "...",
  "passed": false
}
```

---

## 9. 读者效果与长篇证据

### 9.1 自动代理（标准模式）

每场/每章可计算，但默认不做硬门：

- 当前最想知道的问题是否清晰。
- 线索是否支持推理而非事后改规则。
- 隐去姓名后人物语言/选择是否可区分。
- 情绪是否继承、转化或有意清空。
- 场景是否创建/推进/转化/回收一个 open loop。
- 是否存在可被后文重解释的 hook，并记录 future use。
- 世界中至少一个 offscreen force 是否持续运作。

代理结果只能产生 `craftWeakness`、`styleChoice` 或 milestone warning，不能独立形成 hard error。

### 9.2 盲评协议（发布/里程碑模式）

- 每次评分器发布至少 30 个 800–1500 中文字段落 pair；每个 pair 至少 5 个独立判断，整轮至少 10 名不同评审。
- 使用 randomized paired A/B；当前版本与 baseline 的左右/先后顺序 counterbalanced，baseline 版本/hash 固定写入 artifact。
- 按题材、场景功能和项目 voice 分层抽样，去除模型名、版本、生成顺序和明显识别标签。
- 混入 baseline、当前版本、明确授权的人工参考或内部人工样本，以及故意坏样本；原文不得进入公共 artifact。
- 问题固定为：继续阅读意愿、当前关心问题、人物声纹、模板感/出戏点、finding 分类。
- ties、弃答、无效答和 24 小时随访流失单独报告；流失率 >20% 时延迟记忆指标无效。

初始门槛：

- 当前版本相对 baseline 的非平局继续阅读胜率点估计 ≥60%，stratified bootstrap 95% CI 下界 ≥52%。
- 故意坏样本识别率 ≥85%。
- 主要人物隐名声纹辨认率 ≥70%。
- “不知道该关心什么”的回答比例 ≤20%。
- 24 小时后至少 50% 完成随访的读者能回忆一个人物、选择或意象；必须同时报告初始入组分母和流失率。

### 9.3 八种深层效果的 release evidence

| 效果 | Scope/证据 | 初始门槛 | 失败处置 |
|---|---|---|---|
| 叙事引力 | blind paired A/B | 胜率与 CI 达到 9.2 | scorer/manuscript 不获 release evidence；不自动重写全书 |
| 认知参与 | 读者复述当前推理 + gold clue refs | ≥70% 给出至少一个有文本依据的推断；事后无依据答案不计 | 修 reader-question/信息控制，复测相关章 |
| 人物占有感 | 隐名声纹 + 选择预测 | 主要角色 top-1 ≥70% | 修人物声纹/动机，不改主线合同 |
| 世界自主感 | offscreen-force ledger audit | 计划窗口到期的 offscreen forces ≥80% 有状态推进/作用证据 | 补世界压力或记录合法休眠原因 |
| 情绪沉淀 | 24h recall + target alignment | recall ≥50%；目标情绪/余味对齐 ≥60% | 章节级诊断，不单场 hard block |
| 价值压力 | choice/consequence ledger + 读者识别 | major choice 100% 有明确成本/后果；≥70% 读者能说出核心代价 | 阻止 book release evidence，定向修后果链 |
| 重读增值 | planted→recontextualized links + blind reread | 20–50 章至少 5 条有效链接；≥60% 复读者识别意义变化 | 只修相关 plant/payoff 链 |
| 项目不可替代性 | ≥3 项目 voice attribution + project-swap test | 正确 voice top-1 ≥70%；“无损移植到另一项目”比例 ≤30% | 回到 ProjectVoiceProfile/角色/world specificity |

这些门槛属于 `BookQualityDecision`/`EvaluatorPolicyCertification`，不是 `SceneCandidateDecision` 的隐含分项。代理评分失败最多产生 milestone warning；真实读者证据失败阻止 release evidence，但不把整部作品自动改写。

### 9.4 20–50 章长篇审计

“名作级控制力”必须另外满足：

- 核心承诺漂移 blocker = 0。
- 世界规则和 POV 边界 blocker = 0。
- 随机抽 10 章做删除测试，至少 8 章能指出不可删除的状态变化；删除测试仅作诊断，不否定有意留白。
- 只把 `expectedProgressionWindow/expectedResolutionWindow` 落入本次审计范围的 open loops 计入到期分母；其中至少 70% 被推进、转化或回收。
- 到期 major open loops 中 90% 有状态更新；不得静默遗弃。窗口在 50 章之后的慢热/史诗 long loop 不计失败，但必须有 tracking rationale、next pressure plan 和父合同引用。
- 连续 3 场无新增、转化、加压或回收时触发主线停滞 warning。
- 至少 5 处后文对前文形成可验证的 recontextualization。
- 每 5 章至少存在一个读者能稳定复述的关切问题。
- 主要角色隐名辨认率 ≥70%。

该证据包的结论名为 `masteryEvidenceCandidate`，不得写成“系统证明了名作”。最终文学判断仍归作者和真实读者。

### 9.5 人工与长篇 artifact

人工 study 由 release owner 发起，至少两名与实现者不同的 reviewer 审核 provenance/排盲/统计；CI 只验证 artifact schema、hash、分母和门槛计算。

```json
{
  "artifactVersion": "blind-review-v1",
  "rubricVersion": "...",
  "baselineHash": "...",
  "candidateSetHash": "...",
  "pairCount": 30,
  "judgmentCount": 150,
  "uniqueReviewerCount": 10,
  "strata": {},
  "currentWins": 0,
  "baselineWins": 0,
  "ties": 0,
  "invalid": 0,
  "continueWinRate": 0,
  "bootstrapCi95": [0, 0],
  "badSampleRecognition": 0,
  "voiceRecognition": 0,
  "delayedRecall": {"enrolled": 0, "completed": 0, "rate": 0},
  "reviewerIdHashes": [],
  "studyProtocolHash": "...",
  "randomizationCommitmentHash": "...",
  "blindingManifestHash": "...",
  "rawJudgmentSetHash": "...",
  "statisticsCodeHash": "...",
  "adjudicationLogHash": "...",
  "releaseOwnerIdHash": "...",
  "implementationOwnerIdHashes": [],
  "independentAudit": {
    "reviewerIdHashes": ["...", "..."],
    "conflictCheckPassed": [true, true],
    "provenanceDecision": "approved",
    "blindingDecision": "approved",
    "statisticsDecision": "approved",
    "attestationHashes": ["...", "..."]
  },
  "passed": false
}
```

```json
{
  "artifactVersion": "long-form-audit-v1",
  "projectId": "...",
  "chapterRange": [1, 30],
  "bookContractHash": "...",
  "committedLedgerHash": "...",
  "dueOpenLoopCount": 0,
  "advancedDueOpenLoopCount": 0,
  "dueMajorLoopCount": 0,
  "updatedDueMajorLoopCount": 0,
  "outsideWindowTrackedCount": 0,
  "corePromiseBlockers": [],
  "worldOrPovBlockers": [],
  "recontextualizationLinks": [],
  "deepEffectMetrics": {},
  "evidenceHashes": [],
  "passed": false
}
```

---

## 10. 参考语料、版权与项目声音

### 10.1 Source policy

| `licenseStatus` | 允许用途 | 禁止用途 |
|---|---|---|
| `publicDomain` | manifest 允许范围内的分析、引用、校准 | 超出 manifest 的用途 |
| `userOwned` | 用户明确授权的生成上下文、profile、校准 | 超出用户授权范围 |
| `licensed` | 严格按许可用途 | 许可外使用 |
| `restricted` | 元数据清点、人工研究结论 | 原文进入 prompt、训练、长摘录、近似仿写 |
| `unknown` | inventory only | 生成、校准、训练、excerpt、发布证据 |

规则：

- 没有 `SourceLedgerEntry` 的 corpus 在新系统中视为 `unknown`。
- 当前 `assets/novels` 与派生 `artifacts/writing_reference/*` 在来源清单补齐前不得作为 `enforceV2` 的生产参考或 gold fixture。
- `artifacts/writing_reference/*/manifest.json` 如果只描述分段/索引处理过程，不等于本规格的 source ledger；只有符合 `source_manifest.schema.json`、包含 license/allowed-use/provenance review 的记录才具有准入效力。
- 不设置所谓“低于多少相似度就一定合法”的法律安全线；相似度检测只是产品风险门，不是法律结论。
- prompt 使用抽象机制：叙述距离、节奏、信息释放、句法密度、修辞域、人物声纹，而不是“仿某作者”。
- 公共报告只记录 source id、license status、hash 和允许用途，不复制原文。

### 10.2 Runtime admission boundary

| 边界 | 输入 | 无 manifest / `unknown` | `restricted` | 明确允许的 source |
|---|---|---|---|---|
| `GenerationPipelineConfig.fromWorkspace()` | selected style/profile | 产生 disabled/neutral approved bundle + reason code | 只保留已人工审阅的抽象字段 | 按 allowed uses 生成 bundle |
| `MaterialReferenceRetriever` | root/source ids | 空返回，`sourceAdmissionDenied` | 禁止 excerpt/root retrieval | top-k 与 excerpt 上限内返回 |
| `StoryPromptRegistry` | approved bundle | 不渲染 reference section | 只渲染无来源名的结构化抽象约束 | 只渲染 allowlisted fields/excerpts |
| `SceneQualityScorer/V2 evaluator` | voice profile | 不得自行按 root 读取原文 | 只评项目 profile，不评“像作品” | 仍只评项目 profile |
| fixture loader | source ids | fail closed | 不能成为 gold prose | 校验 provenance hash 后载入 |

实现必须引入 `SourceAdmissionResolver` 和 `ApprovedStyleReferenceBundle`，让 retriever/prompt/scorer 无法绕开统一决策。`legacy95` 只表示质量 gate 兼容，不为 unknown source 提供豁免；WP0 的 source-policy 启用可能改变旧 prompt，必须在 baseline/migration report 中明确记录。

`ReferenceUsage` 行为：

| 模式 | 行为 |
|---|---|
| `off` | 不读取 source/profile reference，只保留项目手写约束 |
| `abstractFeaturesOnly` | 默认；只传结构化抽象字段，不传 title/creator/raw excerpt |
| `licensedExcerpts` | 仅 source ledger 明确允许时，按每源/每场上限传递并记录 hash |
| `userOwnedFullContext` | 仅 user-owned 且有明确授权范围时使用 |
| `localAnalysisOnly` | 只做本地诊断/风险扫描，结果不进入生成 prompt |

### 10.3 去作者化与近似复现风险门

去作者化必须进入 WP0/WP1，而不是等到 UI 改版：

1. `ProjectVoiceProfile` schema 无 author/work imitation target。
2. `ImitationIntentLinter` 检查 profile 自由文本和渲染后 prompt：匹配“模仿/仿写/像某作者/某作品文风”等意图，或 source ledger 中 creator/title token 作为生成目标时 fail closed；允许用户提及参考，但必须先转换成抽象机制并移除名字。
3. prompt renderer 永不渲染 `displayName`、creator、title、root path 或 provenance label。
4. 第三方 voice constraints 执行单源支配限制；user-owned/project-owned 自有声音不受该限制。
5. 生成后运行 versioned `NearReproductionRiskPolicy`。初始产品风险线：与第三方参考出现 ≥40 个连续相同 CJK 字符 → blocker；24–39 字符或 normalized char 8-gram containment ≥0.20 → manual review。常用短语 allowlist、标点/空白规范化和来源许可范围必须记录。
6. 这些阈值是保守产品门，不是法律 safe harbor；上线前以合法测试集校准 false positive。

必须新增对抗样本：作者名目标、作品名目标、换同义词的近似仿写请求、单作品支配 profile、参考原句续写、合法自有 voice。前五类应拒绝/抽象化/转人工，最后一类应正常通过。

### 10.4 项目声音建立流程

1. 作者选择类型与目标读者体验。
2. 用结构化问项或用户自有样稿生成 `ProjectVoiceProfile`。
3. 从多个合法来源提炼抽象机制，避免单一作品过拟合。
4. 生成 3–5 个短样，作者标记“像本项目/不像本项目”。
5. 锁定 profile hash 后进入章节生成。
6. 只有作者主动更新 profile，场景间才允许长期声音改变。

---

## 11. 作者控制面

```dart
enum QualityStrictness { draft, standard, strict, publication }
enum AutoRepairMode { off, targetedOnly, fullAllowed }
enum ReaderEffectMode { off, proxy, milestone }
enum ReferenceUsage {
  off,
  abstractFeaturesOnly,
  licensedExcerpts,
  userOwnedFullContext,
  localAnalysisOnly,
}
```

默认值：

- `strictness = standard`
- `autoRepair = targetedOnly`
- `readerEffect = proxy`
- `referenceUsage = abstractFeaturesOnly`
- `styleIntensity = 50`（新项目；legacy 项目按第 12.1 节迁移）
- `qualityGateMode = legacy95`，校准期 workspace 可显式选择 `shadowV2`

UI/报告必须分别展示：

- 硬错误。
- 工艺弱点及证据范围。
- 项目文风贴合度。
- 风格选择和有效偏离。
- reader-effect proxy。
- 当前候选状态、置信度、评审分歧和修复预算。

作者可以：

- 显式接受 90–91 的 `autoCandidate` 或 92–94 的 `highCandidate` 进入正文草稿；是否自动 finalization 仍服从 strictness。
- 将审美争议标记为项目允许的 style override。
- 关闭自动修复或只允许定向修复。
- 要求 publication 双评审。

作者不能：

- 把未知授权风险标记为“已合规”。
- 让 style override 覆盖因果、世界规则、POV 或核心承诺硬冲突。
- 让被拒绝候选的 ledger 变化污染后续场景。

---

## 12. 持久化、兼容与迁移

### 12.1 Phase 1：无 schema migration

- 新 DTO 先作为 typed wrapper/adapters 接在现有 `SceneBrief`、`SceneTaskCard`、`SceneReviewResult`、`SceneQualityScore` 上。
- `NarrativeContractChain`、`SceneCraftContract` 和 hash 写入安全的 checkpoint payload。
- `LayeredQualityResult` 写入 ordinal 11；`shadowV2` 使用独立 shadow payload/hash，既不改变 legacy score，也不进入 candidate proof。
- `enforceV2` 才把完整 layered result hash 映射到现有 `qualityEvidenceHash`；不新增 Phase 1 acceptance 参数。
- `ReaderState` 作为可重建缓存；long-form 更新先使用现有 pending write/committed continuity 机制。
- 所有 `fromJson` 容忍缺失新字段；所有 canonical hash 使用稳定 key 顺序。

### 12.2 Legacy style profile 迁移

`StyleProfileRecord + ProjectStyleState` 到 `ProjectVoiceProfile` 的 adapter 必须唯一：

| Legacy | V2 |
|---|---|
| selected profile id | `profileId` |
| profile UI name | `displayName`，不进入 prompt/hash |
| `genre_tags` | sorted `genreTags` |
| `pov_mode` | `PovMode`；未知值 → `custom` + linted extension |
| `narrative_distance` | `NarrativeDistancePolicy` |
| `rhythm_profile` / sentence/dialogue/description fields | `RhythmPolicy` / `DialoguePolicy` / `DensityPolicy` |
| `tone_keywords` / taboo | structured `VoiceConstraint` / `tabooPatterns` |
| style intensity 0/1/2/≥3 | 0/34/67/100，先 clamp 到 0–3 |
| reference root/source | 只转成 `provenanceRefs`；必须通过 source admission，绝对路径不进 hash |

- 新项目默认 intensity=50；已存在项目保留映射结果，不静默改成 50。
- profile hash 对规范化后的结构字段和经过 sanitizer 的 sorted extensions 做 canonical hash；不包含 UI name、title、creator、root path。
- 无 profile 或 source admission 被拒绝时生成 `neutralProjectVoiceProfile`，并在 migration report 记录 reason；不能静默退回具体作品默认库。
- adapter round-trip 测试必须证明 legacy JSON 可读、V2 保存稳定、再次加载 hash 不变。

### 12.3 Pending write schema 与 rebuild

WP6 增加两个 allowlisted write kind；在 `shadowV2` 只能生成非权威诊断，不得进入 pending-write set。只有 `enforceV2` 的 passing candidate 可以随 proof 暂存，author receipt 后提交。

```json
{
  "writeKind": "readerStateDelta",
  "schemaVersion": 1,
  "baseCommitOrdinal": 0,
  "sourceSceneId": "...",
  "sourceProseHash": "...",
  "sourceQualityEvidenceHash": "...",
  "knownFactAdds": [],
  "knownFactRemovals": [],
  "questionUpserts": [],
  "questionClosures": [],
  "payoffExpectationChanges": [],
  "misbeliefChanges": [],
  "emotionalResidueChanges": [],
  "continuationHookChanges": []
}
```

```json
{
  "writeKind": "longFormLedgerDelta",
  "schemaVersion": 1,
  "baseLedgerHash": "...",
  "sourceSceneId": "...",
  "sourceProseHash": "...",
  "sourceQualityEvidenceHash": "...",
  "upserts": [
    {
      "entryId": "...",
      "previousEntryHash": "...",
      "operation": "create|pressure|transform|pay|abandonWithReason",
      "payload": {},
      "evidenceRefs": []
    }
  ]
}
```

Rebuild algorithm：

1. 按项目声明的 narrative scene order 读取 committed continuity；commit ordinal 只选择同一 scene 的最新 accepted revision，不能重排不同 scene。
2. 对每个 row 验证 run、proof、receipt、finalProseHash、pendingWriteSetHash 和 payload canonical hash。
3. 按 narrative order 应用 `longFormLedgerDelta`；`previousEntryHash/baseLedgerHash` 不匹配即 fail closed。
4. 再应用 `readerStateDelta`，验证 `baseCommitOrdinal` 和 source hashes。
5. 计算 projection/cache hash；与 snapshot 不一致时丢弃 snapshot 并重建，绝不反向覆盖 ledger。
6. 遇到 gap、重复 commit ordinal、未知 operation 或非法状态转换时停止恢复并报告 invariant violation。

Phase 1 的既有 `roleplaySession`、`characterDelta`、`sceneSummaryContribution` 仍保持原职责；新 projection 可以引用它们，不得复制并成为人物事实的第二真源。

### 12.4 Phase 2：需要审计/查询时再规范化

建议新表：

1. `story_generation_contracts`
   - PK：`(run_id, prose_revision, contract_kind, contract_revision)`
   - 字段：schema version、canonical JSON、hash、created time。
2. `story_generation_quality_evidence`
   - PK：`(run_id, prose_revision, evaluator_id, rubric_version)`
   - 字段：input hashes、finding JSON、scores、decision、calibrated confidence、created time。
3. `story_generation_source_ledger`
   - PK：`source_id`
   - 字段：license status、allowed uses、provenance hash、review record。
4. `story_generation_author_overrides`
   - PK：`override_id`
   - 字段：scope、finding code、profile hash、reason、expiry。

迁移只允许 additive；旧数据库读取时默认 `legacy95`。如果新表不存在，应用可启动并退回 legacy 行为。

### 12.5 Cache key

评测缓存键必须至少包含：

```text
proseHash
+ projectCharterHash
+ arcContractHash
+ sceneContractHash
+ voiceProfileHash
+ ledgerSnapshotHash
+ rubricVersion
+ promptReleaseHash
+ evaluatorModelRelease
```

任一项变化则 cache miss。不能仅凭 prose hash 复用，因为同一文本在不同合同/项目声音下可能得出不同结论。

---

## 13. 观测、成本与隐私

### 13.1 遥测字段

- gate mode、rubric version、threshold policy version。
- prose/project-charter/arc/scene-contract/voice/ledger hashes；不记录 raw prose。
- finding 各类计数、严重度、轴、decision。
- blocked/repair/draft/auto/high/scene-release/manual 各状态比例，以及 chapter/book decision。
- legacy vs V2 分歧、平均分差、仲裁率。
- targeted repair 次数、full rewrite 次数、修复成功率、回归失败率。
- author accept/override/reject/revert。
- provider call、token、latency、cache hit、预算耗尽原因。
- score distribution、hard precision/recall、false block、人工 overturn 与版本漂移。

公共 artifact 不得包含 secret、provider 原始请求/响应、私有记忆全文或参考原文。

### 13.2 样本统计规则

- N <20：只报告 mean/min/max，不报告 p95 或置信区间。
- N ≥30：可报告 bootstrap confidence interval。
- N ≥100：可用于 beta/运行漂移判断；正式 evaluator certification 仍服从第 8.1/8.3 节的分层样本和 CI 要求。

### 13.3 成本预算

- `shadowV2` 每个精确 prose revision 最多增加 1 次 shadow evaluator call，并按完整 cache key 去重。
- standard 模式：一次评测 + 最多一次无证据重评/定向修复复评；shadow 下定向修复仅离线演练。
- publication 模式：两个独立 evaluator；只有触发分歧才增加一次 adjudicator。
- targeted repair：standard 最多 1 次，publication 最多 2 次。
- full rewrite：最多 1 次，且默认关闭。
- 预算耗尽转 `manualReview`，不得循环调用。

---

## 14. 实施工作包

### WP0：基线与来源清单

目标：锁定当前行为并切断未授权参考风险。

改动面：

- `lib/features/story_generation/data/style_reference_config.dart`
- `lib/features/story_generation/data/material_reference_retriever.dart`
- `lib/features/story_generation/data/novel_corpus_importer.dart`
- 新 `lib/features/story_generation/domain/source_ledger_models.dart`
- 新 `lib/features/story_generation/data/source_admission_resolver.dart`
- 新 `lib/features/story_generation/data/imitation_intent_linter.dart`
- 新 `lib/features/story_generation/data/near_reproduction_risk_policy.dart`
- 新 `assets/novels/source_manifest.schema.json`
- 对应 source-policy、prompt-lint、named-author adversarial、near-reproduction tests

退出条件：所有生产 reference root 有 source-ledger manifest；processing manifest 不能冒充授权；unknown corpus 不进入 prompt；作者/作品目标被抽象化或拒绝。quality gate/finalization 行为不变；因安全准入导致的 prompt 差异必须进入 migration report，不能声称字节级 generation baseline 不变。

### WP1：模型与阈值政策

目标：增加三级 narrative contract、typed wire schemas、finding taxonomy、四层 decision object 和 policy，不接管 gate。

改动面：

- 新 `lib/features/story_generation/domain/literary_quality_models.dart`
- 新 `lib/features/story_generation/data/literary_quality_policy.dart`
- `scene_runtime_models.dart` / `scene_task_card.dart` adapters
- `generation_pipeline_config.dart`

退出条件：canonical JSON/hash、parent-chain/transition receipt、完整互斥状态机单测通过；默认 `legacy95`；旧 JSON 可读取。

### WP2：分层 evaluator 与 fixture harness

目标：生成结构化 finding、craft、style、reader proxy 和 calibrated confidence。

改动面：

- `story_prompt_registry.dart`
- `scene_quality_scorer.dart`
- 新 `scene_literary_quality_evaluator.dart`
- 新 `test/fixtures/story_quality/**`
- parser、classification、calibration tests

退出条件：300 个 development fixtures 达到 beta 门槛；实验叙事负控不被误杀；无证据 blocker 被 parser 拒绝。正式 certification 的 600 个 hard/non-hard 决策可跨后续运行累计，不能由 300 fixture 假装满足。

### WP3：shadowV2 接入

目标：在 ordinal 11 并行记录，不改变 production pass/fail。

改动面：

- `generation_pipeline_config.dart`
- `pipeline_stage_runner_impl.dart`
- `scene_quality_reporter.dart`
- checkpoint/recovery tests

退出条件：legacy 与 shadow 同场景可比较；shadow hash 不进入 candidate proof/pending writes；shadow failure 不改变 retry/finalization/acceptance；回滚为 config-only。

### WP4：定向修复

目标：由 finding 生成受限 repair directive，替代 overall 低一分的整场重写；production 动作只在 enforceV2 生效。

改动面：

- `quality_repair_policy.dart`
- `pipeline_stage_runner_impl.dart`
- `scene_review_models.dart`
- targeted repair/adversarial tests

退出条件：shadow 只输出 directive；enforceV2 中 94 无硬错误不触发 full rewrite；修复保持合同不变量；预算耗尽转人工。

### WP5：项目声音与作者控制

目标：完成 legacy style profile → project voice profile 迁移，并提供 override/strictness 控制；去作者化硬边界已在 WP0 生效。

改动面：

- workspace style models/serialization
- `style_reference_config.dart`
- `style_panel_page.dart`
- quality report/presentation
- profile migration/UI tests

退出条件：同一剧情在 slow-burn 与 fast-reward profile 下得到不同节奏判断，但相同硬正确性判断。

### WP6：ReaderState 与 LongFormLedgerProjection

目标：把 open loop、人物弧、后果、世界势力、情绪和 recontextualization 纳入 accepted ledger。

改动面：

- `narrative_arc_models.dart` / `narrative_arc_tracker.dart`
- `scene_cognition_updater.dart`
- `chapter_context_bridge.dart`
- `generation_ledger_models.dart`
- `generation_ledger_candidate_finalizer.dart`
- pending-write allowlist/codecs
- long-form audit runner/tests

退出条件：两个 write kind 的 proof/receipt/payload schema 可验证；rejected/shadow candidate 不污染 ledger；reader state 可按 narrative order 重建；20–50 章审计可输出机器报告。

### WP7：enforceV2 与发布门

目标：在校准达标后切换候选政策，并把 scene/chapter/book decision 映射到现有 proof/finalization/acceptance。

改动面：

- `pipeline_stage_runner_impl.dart`
- `steps/finalization_step.dart`
- `scene_quality_reporter.dart`
- release/canary/evaluation authorities

退出条件：所有发布准入条件通过；各 candidate status 的 proof 行为有集成测试；workspace 可单独启用；切回 legacy 无数据迁移。

依赖顺序：`WP0 → WP1 → WP2 → WP3 → WP4/WP5 → WP6 → WP7`。WP4 与 WP5 在 WP3 后可并行。每个 WP 默认单独 PR；WP3 未合入并证明零副作用前不得启动 WP7。

---

## 15. 测试规格

### 15.1 Unit

建议新增：

- `test/literary_quality_models_test.dart`
- `test/literary_quality_policy_test.dart`
- `test/literary_quality_classification_test.dart`
- `test/literary_quality_disagreement_test.dart`
- `test/literary_quality_repair_directive_test.dart`
- `test/project_voice_profile_test.dart`
- `test/source_ledger_policy_test.dart`
- `test/reader_state_rebuild_test.dart`
- `test/narrative_contract_chain_test.dart`
- `test/literary_quality_candidate_state_test.dart`
- `test/imitation_intent_linter_test.dart`
- `test/near_reproduction_risk_policy_test.dart`
- `test/literary_quality_artifact_schema_test.dart`

必须验证：

- canonical serialization/hash 稳定。
- 缺失/旧版字段向后兼容。
- 四类 finding 正确区分。
- hard error 永远优先于分数。
- style choice/effective deviation 不误阻断。
- 无证据 major/blocker 无效。
- author override 不能压制硬门/合规。
- cache key 对任一输入版本变化失效。
- 所有有效组合恰好命中一个 `SceneCandidateStatus`；hard-pass 且 <85、95 但缺 publication review、invalid evidence 均有唯一结果。
- `craftOverall` 权重精确为 1.0，缺维度 fail closed，style/rhythm 不进入公式。
- contract parent hash 连续；未经 receipt 的 core promise/phase 改写被阻断，合法 transition receipt 通过。
- legacy style intensity 0/1/2/3 映射为 0/34/67/100，round-trip hash 稳定。
- `readerStateDelta/longFormLedgerDelta` codec、状态转换和 rebuild ordering 可验证。

### 15.2 Integration

| Case | 预期 |
|---|---|
| shadowV2 + legacy 94 | 与当前一样由 legacy 阻断；同时记录 V2 decision，不改变副作用 |
| enforceV2 + 94 + minor | high candidate 或 targeted repair，不 full rewrite |
| 96 + 因果硬错 | blocked；无 finalization proof |
| 91 + profile 允许 slow burn | 不因慢而失败 |
| 同剧情 slow-burn vs fast-reward | hard/craft 结论一致；style/rhythm 解释不同且都可 aligned |
| 93 + 人物转折弱 | 生成带 span/invariant 的 repair directive |
| 95 + publication review 未运行 | high candidate + `publicationReviewPending` |
| 95 + calibrated confidence 低 | manual review，不成为 scene release candidate |
| 双评审差值 >8 | 仲裁 |
| effective deviation 未事前声明 | 不能自行免责；转 style choice pending/repair |
| effective deviation 有 contract/author 授权 | preserve with evidence |
| quality evidence prose hash 过期 | fail closed |
| 未授权修改 core promise | blocked；无 proof |
| 带 transition receipt 的 phase advance | parent chain 更新并通过 |
| shadow result/hash/reader delta | 不进入 candidate proof、pending write 或 acceptance |
| rejected candidate | committed ledger 无变化 |
| accepted candidate | receipt、pending writes、continuity 原子一致 |
| unknown source | 检索返回空/安全拒绝 |
| author/work imitation target | prompt lint 拒绝或抽象化，名字不进入 rendered prompt |
| 不可靠叙述/非线性/多 POV/自由间接引语合法 fixture | 按 contract 通过，不误判 hard error |
| 配置切回 legacy95 | 不需迁移即可恢复旧 gate |

需要保留并扩展现有：

- `quality_gate_pipeline_adversarial_test.dart`
- `finalization_step_quality_contract_test.dart`
- `scene_quality_scorer_test.dart`
- `scene_quality_reporter_test.dart`
- `quality_repair_policy_test.dart`
- `story_generation_quality_regression_test.dart`
- `real_chapter_generation_commit_gate_test.dart`

### 15.3 E2E 与 real-provider

1. 短程：至少 5 种项目声音，各 3 章、每章 3–5 场。
   - hard gate pass 率 100%。
   - auto candidate 率 ≥80%。
   - 报告 style block count；每个 style block 需人工抽检并给 gold label。`style false block ≤5%` 只在有标注分母的 calibration set 计算，不能从无 gold 的 E2E 自行推断。
2. 中程：至少 mystery/progression/epic 三类，各 10 章。
   - 核心承诺不断链。
   - open loop/人物/世界账本一致。
3. 长程：单项目连续 20–50 章。
   - 通过第 9.4 节审计。
4. real-provider smoke：3 场景，显式授权和成本确认，报告 secret-free，校准完成前 `releaseEligible=false`。
5. real-provider quality canary：30 场景，hard gate 100%、auto candidate ≥80%、high candidate ≥50%、每场 major finding 均值 ≤1、分数漂移 ≤5 或有 migration note；`sceneReleaseCandidate` 比例只报告，不作为 beta 阻断线。

### 15.4 验证命令

以下新文件在对应 WP 合入后才存在。实施 PR 应用真实变更路径运行 formatter；WP1 的可复制示例：

```bash
dart format --output=none --set-exit-if-changed lib/features/story_generation/domain/literary_quality_models.dart lib/features/story_generation/data/literary_quality_policy.dart test/literary_quality_models_test.dart test/literary_quality_policy_test.dart
flutter analyze --no-pub
flutter test test/literary_quality_models_test.dart
flutter test test/literary_quality_policy_test.dart
flutter test test/quality_gate_pipeline_adversarial_test.dart
flutter test test/finalization_step_quality_contract_test.dart
flutter test test/story_generation_quality_regression_test.dart
```

在新测试尚未创建的早期 WP，只运行已经存在且与该 WP 相关的回归测试，不允许把“文件不存在”当成通过。涉及 ledger、恢复或序列化时，再运行相关 storage/recovery 全集；涉及真实 provider 时保持现有显式授权和 non-release 安全边界。盲评/24h/长篇人工步骤不在普通 CI 伪造执行；CI 验证其 artifact schema、hash、统计重算和 release gate。

---

## 16. Rollout 与回滚

### Phase 0：基线冻结

- 保存现有 pass/block、分数分布、重试数、成本、latency、finalization 成功率。
- 给历史 88–94、95+、明显坏样本补人工标签。
- 完成 source manifest；未知来源禁用。

退出：基线报告和 fixture schema 可重跑；source-policy 导致的 prompt 差异与 quality-gate baseline 分开记录。

### Phase 1：模型与 shadow

- 合入 WP1–WP3。
- 默认 legacy95；选定测试 workspace 开 shadowV2。
- 连续至少 100 个 scene revisions 收集同场差异。

退出：shadow 不改变 retry、prose、pending writes、proof、finalization 或 acceptance；schema/parser/secret-free 全绿。

### Phase 2：校准与定向修复

- 完成 300 fixture、双评审稳定性、历史回归。
- 在 shadow report 或隔离副本演练 targeted repair；production gate/legacy retry 不变。
- 评估 projected whole rewrite 率、隔离修复后回归率和人工偏好。

退出：beta calibration artifact 达到 point metrics；hard precision/recall、false block、风格误杀全部报告；高分坏样本 scene release=0。

### Phase 3：受控 enforceV2

- 只对内部/显式 opt-in workspace 开启。
- standard 使用分层候选；publication 保留 95/90 + 双评审。
- 观察至少 30 个真实场景和 3 个三章 run。
- 只有本阶段才允许 V2 targeted repair 改 production candidate。

beta 退出：无 hard regression；auto candidate ≥80%；high candidate ≥50%；major finding 均值 ≤1；作者 revert 没有异常上升。

从 opt-in beta 升为默认 `enforceV2` 还必须满足：

- `EvaluatorPolicyCertification.status=certified`，包括至少 300 hard-positive + 300 non-hard adjudicated decisions 及 CI 门槛。
- 累计至少 100 个真实 scene revisions，覆盖至少 5 种项目声音；不得只由单一题材贡献。
- 至少 5 个独立三章 run 通过恢复、proof、acceptance 与 ledger consistency。
- shadow→enforce 的 migration/rollback 演练通过。

### Phase 4：长篇与发布证据

- 接入 reader state、long-form ledger projection、blind review 和 20–50 章审计。
- 只有完整证据包通过，才能对外使用“长篇质量已验证”措辞。

### 回滚触发

- hard error 漏检增加。
- hard precision、false-block 或人工 overturn 越过认证上限。
- 未授权 core-promise/phase 变化被接受。
- style false block 相对稳定版上升 >3 个百分点。
- scorer 分布无解释漂移 >5。
- shadow/enforce 造成 ledger/proof/hash 不一致。
- latency/cost 超过预算且无降级路径。
- 任何 secret 或未授权原文进入公共报告/生成上下文。

回滚动作：quality gate 配置切回 `legacy95`，关闭 V2 evaluator 与自动定向修复；不删除 shadow evidence；运行 legacy gate 与 ledger consistency tests。source admission、secret redaction 和 imitation/near-reproduction 安全门不得因质量 gate 回滚而关闭。

---

## 17. 验收标准

- AC-001：`shadowV2` 下所有现有 95/90 pass/fail、retry、finalization、candidate proof 和 acceptance 结果不变；shadow hash 不进入权威链。
- AC-002：任何 hard error 即使 craftOverall=100 也无法产生 candidate proof。
- AC-003：`enforceV2` 下 90–94 且无硬错误的场景不会仅因低于 95 触发 full rewrite。
- AC-004：符合 profile 的慢热、留白、高密度或低对白样本不被误判为 hard error。
- AC-005：effective deviation 只有事前 contract 声明或独立复审/作者 override 才被保留，并有功能、证据和回归窗口。
- AC-006：所有 blocker/major finding 有文本 span 或合同/ledger 引用；否则重评。
- AC-007：repair directive 明确 target span、允许操作、不变量和重验阶段。
- AC-008：修复后旧 prose/hash 的 quality evidence 无法复用。
- AC-009：rejected/expired/shadow candidate 不改变 committed continuity 或 long-form projection。
- AC-010：author acceptance 仍通过 proof + receipt 原子提交。
- AC-011：`ReaderState` 可以凭经过 proof/receipt 验证的 accepted ledger、source prose/evidence hash 和 narrative order 重建；snapshot 只可加速，不可成为必需真源。
- AC-012：profile 切换只改变 voice/rhythm 判断，不改变硬正确性结论。
- AC-013：没有 source-ledger manifest 的语料不进入 prompt、gold fixtures 或正式发布证据；processing manifest 不具备准入效力。
- AC-014：author override 不能压制 hard correctness 或 provenance blocker。
- AC-015：质量报告分别展示 hard/craft/style/reader/long-form，不只展示 overall。
- AC-016：公共报告和遥测不含 raw prose、secret、私有 memory 或参考原文。
- AC-017：hard recall/precision、non-hard false block、style false block、人工 overturn 的点估计、N 和 95% CI 全部达到第 8.3 节门槛。
- AC-018：scorer release 测试中同输入重评 craftOverall 标准差 ≤3，分类一致率 ≥80%；模型自报 confidence 不参与 gate。
- AC-019：blind-review artifact 的 paired sampling、评审数、CI、坏样本识别、声纹和延迟记忆达到第 9.2/9.5 节门槛；它属于 evaluator/book release gate，不属于单场状态。
- AC-020：20–50 章 audit artifact 满足第 9.4/9.5 节，且无主线/世界/POV blocker。
- AC-021：Phase 1 不改变 ordinal 0–12 映射，旧 checkpoint 可恢复或安全重算。
- AC-022：finalization 继续 provider-free，且只接受精确 revision 的 passing evidence。
- AC-023：切回 `legacy95` 是配置级操作，不要求数据回滚。
- AC-024：达到自动修复预算后进入 manual review，不发生无限循环。
- AC-025：未经 author transition receipt 修改 `corePromiseId`、project charter 或 phase 必须阻断；合法 transition proposal/receipt 可推进父合同链。
- AC-026：所有有效评测恰好命中一个 scene status；hard-pass 且 <85、95 但缺复审、invalid after rescore 都有唯一结果。
- AC-027：craftOverall 只按七维固定权重计算，不包含 style/rhythm；同 craft 的 slow-burn/fast-reward 只改变 style 解释。
- AC-028：`legacy95/shadowV2/enforceV2 × strictness × scene status` 的 finalization/proof/receipt 行为全部有集成覆盖。
- AC-029：作者/作品模仿目标、单第三方来源支配和近似复现风险被结构化拒绝、抽象化或转人工；合法 user-owned voice 通过。
- AC-030：不可靠叙述、非线性时间、多 POV、自由间接引语和声明过的规则例外负控不被误判为硬错。
- AC-031：`EvaluatorPolicyCertification`、`SceneCandidateDecision`、`ChapterQualityDecision`、`BookQualityDecision` 分别序列化、判定和测试，不互相冒充。
- AC-032：八种深层效果各有 scope、证据来源、样本数、阈值、失败处置和 artifact 字段。

---

## 18. 风险与缓解

| 风险 | 后果 | 缓解 |
|---|---|---|
| LLM judge 漂移 | 阈值失真、版本间不可比 | 版本化 rubric、gold fixtures、重复性测试、分布漂移门 |
| “全判 blocker”的假严格 | recall 看似很高、可用文本被误杀 | precision、false-block、overturn、实验叙事负控和 CI 同时门禁 |
| 文风同质化 | 所有题材被优化成同一种“顺滑” | project voice、style choice/effective deviation、跨题材 fixture |
| 合同过度约束 | 文本正确但僵硬 | 允许主题/认知贡献、有意暂停、author override、reader evidence |
| 自动修复破坏正确段落 | 越修越差 | span repair、invariants、exact-hash 重验、full rewrite 默认关闭 |
| 成本/延迟增长 | 生成不可用 | shadow cache、双评审只在 publication、预算耗尽转人工 |
| ledger 权威混乱 | 后续章节被拒稿污染 | pending write + proof + receipt 边界不变，reader state 派生化 |
| 合法叙事实验被误判 | 不可靠叙述、多 POV、非线性文本被抹平 | contract-declared policies、语义仲裁、专门负控 fixture |
| 版权/provenance 不清 | 合规与声誉风险 | unknown 默认禁用、source ledger、抽象机制而非作者模仿 |
| 分数被误当文学真理 | 错误产品承诺 | 分层报告；mastery 依赖盲评和长篇证据 |

---

## 19. Definition of Done

一次完整实施只有同时满足以下条件才算完成：

1. 数据合同、hash、兼容读取和 authority 边界通过单测。
2. legacy95、shadowV2、enforceV2 三种模式有集成覆盖。
3. 300 个合法 provenance development fixture 达到 beta 门槛；正式 certification 累计 300 hard-positive + 300 non-hard 独立决策并满足 CI。
4. hard error 的 recall/precision/false-block/overturn，以及 style choice/effective deviation 的误判率达标。
5. targeted repair 不改变未授权范围和叙事不变量。
6. checkpoint/recovery/finalization/proof/receipt 全链路通过。
7. real-provider smoke 仍保持显式授权、成本确认、secret-free、non-release 边界。
8. 盲评与 20–50 章长篇审计形成可复验 artifact。
9. 观测面能解释每次 gate、repair、override、disagreement 和 drift。
10. 回滚演练证明切回 legacy95 后系统可继续生成和恢复。
11. project charter→arc→scene parent chain、transition proposal 和 author receipt 全链路通过。
12. evaluator/scene/chapter/book 四层 decision 与 proof/finalization 映射通过。
13. source admission、prompt lint、单源支配和 near-reproduction 风险测试通过。
14. 八种深层效果均落入可复验的人类/长篇 artifact。

在第 8、14 项完成前，产品最多可以宣称“分层质量系统通过技术校准”，不能宣称“已达到某名作或名作级文学效果”。

---

## 20. 仓库落地说明

本规格由 [changw98ic/n0vel#100](https://github.com/changw98ic/n0vel/issues/100) 跟踪，并合入 `docs/literary-quality-system-spec.md`。第 14–17 节已经同时承担 PRD、工作包、测试矩阵与验收合同；实施时可按 WP 拆成独立 PR，但不得把拆分后的局部文档当作新的权威源。

issue 必须记录：新真实模型基线、正文评审结论、文档路径、验证结果、已知风险以及后续实施 PR。`.omx/evidence/` 只保留本地 secret-free 运行证据，不作为仓库中唯一可追溯记录。

本规格没有要求立即更改生产阈值；第一个实现 PR 必须只做 WP0/WP1 或 shadow，不得直接切 `enforceV2`。
