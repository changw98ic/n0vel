# WP3-A 三章三臂真实生成实验合同

| 元数据 | 值 |
|---|---|
| 状态 | Accepted experiment contract；implementation in progress |
| 版本 | 1.0 |
| 日期 | 2026-07-21 |
| GitHub 记录 | [changw98ic/n0vel#108](https://github.com/changw98ic/n0vel/issues/108) |
| 上位规格 | [跨题材长篇文学质量系统规格](literary-quality-system-spec.md) |
| 适用范围 | 新作品前三章、A/B/C 三臂真实生成、匿名盲评与架构取舍 |
| 证据等级 | 方向性架构证据；不是统计认证、evaluator certification 或出版证明 |

## 0. 决策摘要

本工作包不先假定多 Agent 更好，也不先把完整新架构接入默认生产链。它用同一部新作品、同一份冻结的前三章大纲和同一模型配置回答三个问题：

1. 单一持续 Narrator 是否比当前生成架构更少 AI 味、更有统一叙述声音；
2. 受限角色 Agent 是否在不损伤文风的前提下，进一步提高人物主体性和跨章行为一致性；
3. 任何质量提升是否足以抵偿额外调用、延迟和故障面。

实验结论只允许决定“继续实现、降级为可选路径或删除复杂度”。三次生成和十五张盲评票仍是小样本，不能使用“统计证明”“名作级”或“已校准”措辞。

旧 `95/90` 分数可以作为诊断结果保存，但不得驱动参赛正文重写，也不得作为本实验主指标。上位规格已明确：读者效果和长篇控制力不能由单场高分推出，[95/90 对普通生成过严、对名作质感证明又不足](literary-quality-system-spec.md#0-执行摘要)。

## 1. 当前基线与证据边界

### 1.1 已存在的生产骨架

当前 `PipelineStageRunnerImpl` 依次执行 context enrichment、director planning、roleplay、stage narration、beat resolution、editorial、review、polish、quality scoring 和 provider-free finalization。场景候选随后由 ledger finalizer 形成 proof，并由作者采纳事务写入 draft、version、pending writes 和 receipt。

可复用边界包括：

- 场景执行入口：[story_generation_run_store.dart](../lib/app/state/story_generation_run_store.dart#L399)；
- 主阶段编排：[pipeline_stage_runner_impl.dart](../lib/features/story_generation/data/pipeline_stage_runner_impl.dart#L639)；
- 单一 runner factory：[story_pipeline_factory.dart](../lib/features/story_generation/data/story_pipeline_factory.dart#L4)；
- 角色可见上下文：[character_visible_context_builder.dart](../lib/features/story_generation/data/character_visible_context_builder.dart#L10)；
- 候选 proof：[generation_ledger_models.dart](../lib/features/story_generation/data/generation_ledger_models.dart#L168)；
- 作者采纳事务：[generation_commit_coordinator.dart](../lib/features/story_generation/data/generation_commit_coordinator.dart#L67)。

三臂必须共享这条编排骨架、ledger、预算和证据接口。禁止复制三套 pipeline，再用三套不同的 checkpoint、commit 或错误处理逻辑制造不可比较结果。

### 1.2 旧三章入口不能直接充当本实验

`test/real_three_chapter_generation_test.dart` 能生成真实三章大纲、运行每章多 Agent simulation、生成正文并保存 trace、SQLite、export 和 report，但它有四个限制：

1. 真实 provider 入口现在由 `AgentEvaluationRealProviderEntryGate` fail closed，旧测试会 skip；正式真实入口归 release coordinator 管理；
2. 世界设定和人物资源来自测试内固定 seed，不是本实验要求的全新模型作品；
3. 它使用当前 review/quality/retry 行为，质量失败可能改变参赛正文；
4. 默认 artifact root 固定为 `artifacts/real_validation/three_chapter_run`，启动时会清空该专用目录，不适合保存多臂、多 trial 的不可变证据。

因此旧产物 `artifacts/real_validation/three_chapter_run/**` 和 `three_chapter_repaired/**` 只能用于缺陷发现与基线映射，不能进入 #108 盲评或胜负统计。

### 1.3 生产观察不是公平实验臂

允许额外记录一次未修改的 production-default 运行，观察实际用户今天会得到的结果，记为 `P`。`P` 可以包含现有质量修复和重试，但只作产品现状说明，不进入 A/B/C 因果票数。

正式实验中的 A/B/C 必须共用 no-content-redraw 与 no-evaluator-feedback 政策。否则 A 使用多次质量修复而 B/C 只生成一次，或反过来，胜负将混合架构差异与采样预算差异。

## 2. 三个实验臂

### 2.1 共同权限边界

| 参与者 | 可以决定 | 不可以决定 |
|---|---|---|
| Outline/Director | 固定主线锚点、场景目标、约束、POV、允许变化范围 | 最终逐句正文 |
| Character Agent | 角色在世界内的感知、价值优先级、行动、话语或沉默、不确定性 | 最终叙述、他人内心、事实是否成立、作者级场景功能 |
| World Resolver | 可观察后果、公共事实、角色可知状态的变化 | 文体、句法、修辞、最终段落 |
| Narrative Surface Owner | 场景全部正文、注意力顺序、对白措辞、句子和段落节奏 | 改写冻结主线、读取未授权私密状态 |
| Evaluator/Reader | findings、偏好票、证据与发布建议 | 修改参赛正文或触发内容重抽 |

每个场景只能有一个完整正文生成调用。Actor、director、resolver、reviewer 的文本不得被拼接成最终小说段落。

### 2.2 A：当前架构，统一实验政策

A 保留当前 context、director、roleplay、stage narration、beat resolution 与 editorial 关系，用于测量当前架构本身。实验 overlay 必须关闭内容质量驱动的 prose retry、editorial repair 和 quality repair；已有 review 与 `legacy95` 只在正文封存后作为诊断运行。

A 不是字节级当前生产体验；未修改 production-default 行为由 `P` 单独记录。A 的意义是让三个臂拥有相同的单次内容机会。

### 2.3 B：场景合同 + 单一持续 Narrator

B 使用同一 context、冻结 outline 和 scene contract，但不运行角色 Agent，也不运行会写第二份叙述文本的 stage。每场由同一个项目级 Narrative Surface Owner 读取：

- 当前 POV 可知事实；
- 已提交的世界、关系、物件和后果；
- 冻结场景目标与允许变化范围；
- 项目声音、Narrator 注意力与母题状态；
- 前文精确必要片段和带来源的摘要。

Narrator 一次写出完整场景。跨场景持续性不是复用聊天历史，而是显式、可哈希的 narrator state：注意力偏好、叙述距离、长期意象、当前读者问题和已积累的情绪 residue。

### 2.4 C：受限角色决策 + World Resolver + 单一持续 Narrator

C 与 B 共用同一个 Narrative Surface Owner、同一 scene contract 和同一输出预算。差异只在正文生成前增加角色决策与世界裁定：

```text
冻结场景合同
→ 每个角色只接收世界内可见信息
→ 角色输出感知 / 价值优先级 / 行动 / 话语或沉默 / 不确定性
→ World Resolver 决定可观察后果和知识变化
→ 过滤后的 NarratorInputProjection
→ 单一 Narrative Surface Owner 写完整场景
```

角色输出不得强制包含“潜台词”“真实动机”或作者级解释。角色可以误解自己、没有明确意图、保持沉默或选择不行动。任何 private thought 都只是有时间戳的人物局部认知，不自动成为世界事实或永久身份。

## 3. 冻结输入与允许变化

### 3.1 冻结对象

在三臂开始前必须由真实配置模型创建一部全新原创作品，并冻结：

- `projectBibleHash`：题材、世界规则、核心冲突和非模仿声明；
- `characterProfileSetHash`：角色起始欲望、恐惧、关系、知识和不可见信息；
- `threeChapterOutlineHash`：第一至第三章目标、转折、代价、余波和跨章承诺；
- `orderedSceneSetHash`：每章 3–5 场的顺序、POV、目标与主线锚点；
- `projectVoiceProfileHash` 与 `narratorStateGenesisHash`；
- `modelRouteHash`：实际 provider、解析后的 model identity 和 failover policy；
- `decodingConfigHash`：temperature、top-p、max tokens、seed policy；
- `contextBudgetHash`、`promptReleaseSetHash` 和 `retryPolicyHash`；
- 各臂预声明的 provider call、token、费用和 wall-time 上限。

如果 provider 不支持 seed，必须记录 `seedPolicy=unsupported`、独立 `trialId` 和实际 response IDs，不能伪称可重复字节输出。

### 3.2 固定主线与角色选择

固定的是三章宏观承诺、关键事实和不可越过的结束状态，不是每个中间动作。角色可以改变路线、代价、关系状态、信息暴露方式和局部结果。若某个角色选择会破坏固定主线，resolver 必须明确记录 `rejectedByMainlineConstraint`，不能把它悄悄改写成角色自愿配合。

### 3.3 公平资源边界

- 三臂使用同一实际 provider/model、采样参数、scene output token 上限和相同冻结输入；
- 角色决策额外调用必须单独计入 C 的成本，不能隐藏在“上下文准备”中；
- 每臂总预算在首个调用前封存，运行后不得扩大；
- C 若超过 B 的 2 倍 provider calls 或 token 成本，只能得出“可能有质量方向、但不适合默认化”，除非 #108 另行接受成本目标变更。

## 4. No-content-redraw 与反馈隔离

> 实现门（2026-07-22）：单次物理派发、write-ahead attempt 与永久收据只是本节的传输/证据基座，尚不等于可运行实验。三臂执行器必须先做到“首个 surface prose 一产生就封存”；preliminary review、final council 或 `legacy95` 的低分和改写建议只能附加诊断，不能让该正文从槽位消失。这个 sample-preservation gate 未通过前，禁止启动真实 A/B/C 生成。

### 4.1 一个逻辑内容槽只能产生一个参赛候选

逻辑内容槽由 `experimentId + trialNo + arm + chapterOrdinal + sceneOrdinal + surfaceOwnerReleaseHash` 唯一确定。同一槽最多一个 `finalProseHash`。任何第二份可读正文都不能替换第一份进入盲评。

### 4.2 失败分类

| 失败 | 是否允许 provider 重试 | 处理 |
|---|---:|---|
| 明确 pre-dispatch 或由冻结的 provider-specific rejection contract 明确证明无 provider completion 的 transport 失败 | 是，最多 2 次 | 全部 attempts 入账，失败也消耗预算 |
| provider 是否完成无法判定 | 否 | 槽记为 `indeterminate`，该 repeat 无效 |
| actor/resolver 严格结构输出错误 | 仅允许本地无语义修复；不得重新采样新决策 | 无法本地修复则 arm hard fail |
| prose 截断、空洞、太短、太长、违约或质量差 | 否 | 封存原文并记录 finding/hard error |
| evaluator 低分或 reader 不喜欢 | 否 | 只记录，不修改正文 |
| 预算耗尽 | 否 | 槽记为 `budgetDenied`，不得追加预算救活 |

传输 retry 总额度不得超过预期 provider calls 的 20%。没有早成功规则，不得因出现一份好稿而停止其他预声明 trial。

HTTP `429` 或 `5xx` 状态本身不是“provider 未完成”的证明：响应可能来自代理层，也不能排除上游已经开始或完成生成。通用 OpenAI-compatible transport 因此一律把这类失败视为 completion 不确定；只有实验前冻结、可机器验证且由具体 provider 明确担保语义的 rejection contract，才可以签发 `confirmedNoCompletion` 并授权重试。错误文案、调用方回调和 HTTP 状态码都不能自行制造这份证明。

### 4.3 评价与生成完全隔离

每份正文先计算 artifact digest 并封存，之后才允许运行 deterministic hard checks、legacy score、V2 evaluator 或盲评。任何 evaluator finding、分数、盲评意见或人工修改进入后续生成上下文，都会使相应 repeat 无效。

## 5. 证据合同

本实验复用现有 `ExperimentManifest`、`AgentEvaluationLedger`、`CandidateProofRecord`、execution budget 和 typed provider evidence，不另建无法对账的平行证据系统。新增的三章 envelope 至少包含：

```json
{
  "schemaVersion": "three-chapter-three-arm-evidence-v1",
  "experimentId": "...",
  "issue": 108,
  "manifestHash": "...",
  "frozenProjectHash": "...",
  "expectedSlotSetHash": "...",
  "arms": [
    {
      "armIdHash": "...",
      "generationFingerprint": "...",
      "modelRouteHash": "...",
      "decodingConfigHash": "...",
      "promptReleaseSetHash": "..."
    }
  ],
  "trialSlots": [
    {
      "trialSlotId": "...",
      "runId": "...",
      "attempts": [],
      "finalProseHash": "...",
      "providerCallSetHash": "...",
      "costEvidenceHash": "...",
      "contentRedrawAllowed": false
    }
  ],
  "blinding": {
    "policyVersion": "...",
    "anonymousPackageHash": "...",
    "armMappingHash": "..."
  },
  "ballots": [],
  "budgetFinalSnapshotHash": "..."
}
```

必须能从原始 artifact 重算：

- `generationFingerprint`：实际渲染 prompt、prompt release、provider/model、采样参数、arm policy、scene/narrator/visibility contract、实际注入上下文；
- `evaluationFingerprint`：judge prompt、rubric、judge model、blinding policy 和被评正文 digest；
- `artifactDigest`：精确 UTF-8/LF 字节；
- `expectedSlotSetHash`：`orderedSceneSet` 中的场景总数 × 3 arms × 3 trials 的所有预声明 scene slots；三章只是稿件聚合边界，不能代替实际场景槽计数；
- `providerCallSetHash` 与 `costEvidenceHash`：成功、失败和 retry 全部调用。

时间戳、trace ID、UI display name 和未注入模型的数据库记录不得进入 generation identity。任何会改变模型语义输入的字段不得留在 identity 之外。

原始文本和调用证据保存在本地 secret-free evidence 目录；GitHub issue 只记录无密钥摘要、hash、命令、结论和已知缺口。

## 6. 匿名化与盲评

### 6.1 生成设计

1. Trial 1 / pilot：A/B/C 各生成一次完整前三章。只要三臂和证据均有效，这次运行就是权威三次重复中的第一次，必须进入 `expectedSlotSetHash`、九份稿件和后续五张 ballot，不能因质量差降格为“试跑”后重抽。
2. Trial 2–3 / confirmatory：除隐私泄漏、证据污染、预算安全失败等预声明硬早停外，A/B/C 各再生成 2 次，补足 3 次独立完整前三章生成。
3. 每个 trial 使用同一冻结项目，但独立 `trialId`；三臂在同一 trial 中共享相同输入 identity。

最低有效生成量为 9 份完整三章稿。未完成 9 份时只能报告 `pilot` 或 `incomplete`，不得据此更改默认生产架构。

如果 Trial 1 因 pre-dispatch、harness、证据映射或外部 provider 故障而整体无效，必须保留原 `trialId`、全部 attempts 和无效原因；修复后只能以新 `trialId` 重新开始 A/B/C 整个 trial，不能只替换某臂或某个低质量场景。因正文质量差、低分或读者不喜欢而重跑 Trial 1 永远禁止。无效 Trial 1 不进入权威 `expectedSlotSetHash`、十五张 ballot 或早停票数，但其 attempts 仍进入总成本与失败报告。

### 6.2 匿名包

匿名化只删除流程元数据、arm/model/provider 标识并统一外层标题格式，不修改小说正文。每个 trial 都随机映射三个 opaque labels；mapping 在 judge 输入之外单独封存。匿名包生成前后的正文 hash 必须可证明只发生了允许的包装变化。

### 6.3 最低评审量

每个 trial 至少 5 名独立盲评者，对同一 trial 的 A/B/C 三份三章稿完成一张完整 ballot。三个 trials 最低 15 张票。

每张 ballot 必须包含：

- A/B/C 强制排序和唯一“最愿意继续读”选择；
- AI 痕迹、人物主体性、叙述声音、节奏适配各 1–5；
- 至少 2 个跨章承诺、伏笔、物件、关系或后果的延续判断；
- 硬连续性/POV/隐私错误清单；
- 至少一条精确文本证据，不接受只有总评。

LLM reader 只能作为 reader proxy，不能评审由同一模型身份和同一生成上下文产生的候选。每个 trial 至少需要 1 张真实人类盲评票；缺少人类票时只能形成 development evidence，不能改变默认生产路径。至少一名人类评审在 24 小时后记录仍记得的人物选择、未决问题和具体细节；否则不得声称情绪沉淀或延迟回忆得到改善。

## 7. 指标与判定

### 7.1 主指标

主指标是匿名“更愿意继续读”配对胜负：`B>A`、`C>B` 和 `C>A`。每张三项强制排序 ballot 会产生三个一致的 pairwise decisions。

本实验不报告 p-value、p95、置信区间或带两位小数的“文学质量总分”。只报告原始票数、每个 trial 的胜负、median、硬错误、成本和证据引用。

### 7.2 方向性胜出门槛

只有同时满足以下条件，才允许称某臂对另一臂“取得方向性优势”：

- 15 张票中至少赢 10 张；
- 至少 2/3 trials 内获得多数；
- 硬连续性、POV 和隐私错误总数不高于对手；
- 所有 manifest、hash、attempt、budget 和 blinding 证据完整；
- 至少 3 张来自真实人类的有效 ballot，每个 trial 至少 1 张。

### 7.3 架构决策

| 结果 | 决策 |
|---|---|
| B 胜 A，C 不胜 B | 默认候选为持续单 Narrator；多 Agent 不进入默认路径 |
| C 胜 B 且 C 胜 A，成本不超过 B 的 2 倍 | C 可进入后续默认化审查 |
| C 改善人物但不胜继续阅读/叙述声音 | Character Agent 仅用于规划或显式复杂场景 |
| B/C 均不胜 A | 停止增加 Agent 层，转向模型能力、Narrator prompt 和大纲质量 |
| 机器评价偏好与人类票方向冲突 | 不晋级 evaluator 或生成策略，转人工分析 |
| 无任何 pair 达到门槛 | 结论为不确定，保持当前默认架构 |

C 即使质量胜出，但 provider calls 或 token 成本超过 B 的 2 倍，也只能作为高复杂场景可选路径，不能直接默认化。

十五张 ballot 只够形成 #108 的方向性架构选择，不是默认链或 release-class 证据。胜出的实现最多进入 shadow、可选路径或后续默认化审查；改变生产默认值仍必须满足上位规格至少 30 个成对盲评项、10 名不同评审者，以及 WP3/WP7 的发布与回滚门。不得把同一批十五张票重复计入更高层门槛来制造样本量。

## 8. 早停、无效和禁止性结论

### 8.1 允许早停

- 发现任何非 POV 私密信息泄漏或具名作者模仿/近似复现风险；
- evidence、anonymous mapping 或冻结输入被污染且无法从未运行 slot 重新开始完整 trial；
- 达到预声明预算上限；
- 前 10 张有效票中某 pair 仅赢 4 张或更少，剩余 5 张即使全胜也无法达到 10/15；这只能停止该 pair 的成功判定，不能把未生成内容伪装成失败样本；
- provider 外部故障使同一冻结模型配置无法继续，运行标记 `invalid`，不判任何臂失败。

没有质量上的早成功规则。

### 8.2 实验无效条件

- 评审者知道 arm、prompt、model 或调用数量身份；
- 任一参赛 prose 被质量反馈、人工修稿或第二次内容采样替换；
- 三臂使用不同 project/outline/scene/voice identity 或不同 surface token 上限；
- 生成模型评审自己的输出，或 judge 使用生成时的隐藏上下文；
- 缺失正文 digest、prompt/config fingerprint、attempt log、budget snapshot 或 ballot 原始记录；
- 只保存最佳候选，丢弃失败、低分或中断样本；
- 用旧 `three_chapter_run`、repaired artifact、fake、fixture 或 mock 代替新真实作品。

### 8.3 允许与禁止的结论

允许：

- “在 #108 冻结条件下，C 对 B 获得 11/15 的方向性继续阅读偏好。”
- “C 的人物主体性更强，但成本超过默认化上限，因此只保留为复杂场景路径。”

禁止：

- “多 Agent 已被统计证明优于单 Agent。”
- “机器分达到 95，所以已经达到名作质感。”
- “一次真实 smoke 证明长篇稳定。”

## 9. 实现 seam 与回归边界

### 9.1 单 pipeline、三种填充策略

后续实现应增加一个 typed arm policy，优先挂在 `GenerationPipelineConfig` 或正式 experiment manifest。`PipelineStageRunnerImpl` 只在 stage 选择和输入投影处分流：

- A：保留当前 stage 关系，关闭内容修复；
- B：跳过 roleplay 和第二叙述阶段，由单 surface owner 直接消费 scene/narrator contracts；
- C：用 `CharacterVisibleContextBuilder` 前的 World Resolver seam 生成受限决策，再投影给与 B 相同的 surface owner。

`SceneBrief`、ledger、candidate proof、attempt evidence、budget 和 final artifact envelope 必须共用。禁止为 B/C 复制 candidate finalization 或 commit coordinator。

### 9.2 现有证据设施复用

- 冻结 manifest：[agent_evaluation_manifest.dart](../lib/features/story_generation/data/evaluation/agent_evaluation_manifest.dart#L195)；
- append-only attempts：[agent_evaluation_ledger.dart](../lib/features/story_generation/data/evaluation/agent_evaluation_ledger.dart#L80)；
- 预算 snapshot：[agent_evaluation_execution_budget.dart](../lib/features/story_generation/data/evaluation/agent_evaluation_execution_budget.dart#L51)；
- provider call/cost evidence：[agent_evaluation_typed_evidence.dart](../lib/features/story_generation/data/evaluation/agent_evaluation_typed_evidence.dart#L226)；
- 匿名 evaluator bundle：[app_llm_prompt_release.dart](../lib/app/llm/app_llm_prompt_release.dart#L226)。

## 10. G001 退出条件

G001 仅在以下证据齐备时完成：

- #108 为 open implementation record；
- 旧 Ultragoal 的五个状态文件已归档到 `.omx/archive/ultragoal-20260716-quality-gates/`，归档 `README.md` 记录逐文件 SHA-256；本次 G001–G009 九个实施微目标由新的 `.omx/ultragoal/goals.json` 与 `.omx/ultragoal/ledger.jsonl` 单独记录，可用 `omx ultragoal status --json` 核对；
- 本合同定义三臂、生产观察、冻结输入、no-redraw、反馈隔离、evidence、盲评、判定、早停和无效条件；
- 当前真实三章入口、正式 provider gate、pipeline、ledger 和旧 artifact 边界均有代码引用；
- 文档链接和 Markdown bundle 校验通过；
- 独立 reviewer 确认合同不会用一次 smoke、机器自评或 legacy95 冒充架构胜出。

G001 不修改生产生成逻辑，不运行真实模型，不声称任何实验臂已经获胜。完成 G001 只表示实验合同和记录工件可实施，不表示 #108 已达到合入条件；九份完整三章稿、十五张有效盲评票和真实人类票属于第 11 节的最终合入门，不属于 G001 退出证据。

## 11. #108 最终合入门

#108 只有在 G001–G009 全部完成后才能合入。最终证据必须同时包括：

- 本合同要求的九份完整三章稿、十五张有效盲评票、真实人类票、不可变 evidence envelope 和因果判定；
- 与变更范围相称的单元、集成、静态分析和真实 provider 验证全部通过；
- `$ai-slop-cleaner` 清理完成，并在清理后重跑受影响验证；
- 独立 `code-reviewer` 给出 `APPROVE`；
- 独立 `architect` 给出 `CLEAR`；
- GitHub #108 更新最终 commit/PR、验证命令、原始计数、已知缺口和未泄露密钥的 evidence 摘要。

缺少其中任一项，均只能报告 `implementation in progress` 或 `experiment incomplete`，不得合入或改变默认生产路径。
