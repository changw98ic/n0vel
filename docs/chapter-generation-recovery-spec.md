# 章节生成生产闭环修复 Spec

- 状态：Consensus approved
- 关联 Issue：[#90](https://github.com/changw98ic/n0vel/issues/90)
- 范围：规划文档；本 Spec 不代表实现已经完成

## 1. 背景

当前仓库同时存在工作台单次 AI 请求和 `StoryPipeline` 两套章节生成语义。正常工作台生成没有经过完整流水线；完整流水线缺少首次启动入口，生产 `SceneBrief` 丢失角色与场景结构，最终 `prose` 没有进入可采纳候选；未采纳内容可能提前写入长期记忆；跨章摘要、Canon、RAG admission、质量门禁、取消、恢复与修订状态也没有形成一致闭环。

本 Spec 将生产章节生成收敛为一个可持久化、可恢复、可审查、作者明确采纳后才提交权威状态的场景级流程。

## 2. 目标与非目标

### 2.1 目标

1. 工作台“AI 写本场”统一进入 `StoryPipeline`；行内改写保留为独立轻量功能，但不得冒充章节生成。
2. 从纲要、角色、世界设定和当前场景构造完整 `SceneBrief`。
3. 最终正文持久化为不可变候选证明，重启后仍可查看、拒绝或采纳。
4. 作者采纳是正文、版本、反馈、角色记忆、thought、章节摘要等权威状态的唯一提交边界。
5. 质量门默认总分不低于 95，关键维度不低于 90；失败、缺分或解析异常一律 fail closed。
6. 支持全链路取消、受限重试、原子预算、typed checkpoint 和逐阶段恢复。
7. 让 Canon、visibility、scope、owner 和 tags 在 SQLite 候选截断前完成 admission。
8. 提供可机械验证的迁移、并发、崩溃恢复、真实模型质量和可观测性门禁。

### 2.2 非目标

- 本轮不提供“一键生成整章”或同章多场并发。每次 run 只生成当前场景。
- 本轮不引入外部向量数据库或分布式事务。
- 本轮不允许 fake、固定分数或 mock responder 代替真实 provider 质量结论。
- 本轮不自动提交候选；作者没有明确采纳时，权威正文和长期记忆必须保持不变。

## 3. 核心原则

1. **作者意图是 commit boundary。** AI 评审通过不等于作者采纳。
2. **一个动作只有一条生产语义路径。** “AI 写本场”只能走完整 `StoryPipeline`。
3. **最终文本拥有最终证据。** Hard gate、终审和质量分都必须绑定同一正文 hash。
4. **权威状态与恢复缓存分离。** Checkpoint 可丢弃、可重算，不得决定候选或提交真相。
5. **Derived 数据可以滞后，authoritative 数据不得分裂。** RAG 索引通过幂等 outbox 最终一致。

## 4. 产品行为

### 4.1 启动

- 工作台只在当前项目、章节和场景都有效时启用“AI 写本场”。
- 同一 `sceneScopeId` 同时最多存在一个 active run；重复点击返回现有 run，不启动第二套 provider 请求。
- `SceneBrief` 必须包含 `sceneIndex`、`totalScenesInChapter`、`targetLength`、`targetBeat`、`cast`、人物档案、知识边界和世界节点。

### 4.2 候选

- 所有质量门通过后才能创建 `CandidateProof`。
- 候选正文、评审详情等大体积 payload 可以按保留策略清理；proof、commit receipt 和必要身份 tombstone 永久保留。
- UI 只有在持久化候选正文成功后才能显示“候选稿已生成”。

### 4.3 采纳与拒绝

- 采纳必须经过单个共享 SQLite 事务和 CAS 校验。
- 拒绝、取消、失败或过期候选不得写入权威正文、角色记忆、thought 或章节摘要。
- 重复提交同一 idempotency key 和同一候选返回原 receipt；同 key 不同候选必须冲突。

## 5. 流水线

生产顺序固定为 ordinal 0–12：

| Ordinal | 阶段 | Provider | 可恢复产物 |
|---:|---|---|---|
| 0 | Context enrichment | 否 | 结构化上下文与 material digest |
| 1 | Director planning | 是 | 导演计划 |
| 2 | Roleplay | 是 | staged roleplay / character deltas |
| 3 | Stage narration | 是 | 叙事骨架 |
| 4 | Beat resolution | 是 | 节拍结果 |
| 5 | Editorial draft | 是 | working prose revision |
| 6 | Preliminary review | 是 | 独立初审证据 |
| 7 | Polish | 是 | polished prose revision |
| 8 | Deterministic gates | 否 | exact-prose hard-gate evidence |
| 9 | Final council review | 是 | 独立终审证据 |
| 10 | Prose-derived extraction | 是 | staged thought/arc/contribution writes |
| 11 | Quality gate | 是/确定性聚合 | exact-prose quality evidence |
| 12 | Finalization | 否 | proof、payload、manifest、run pointer |

Finalization 必须零 provider 调用，并在一个事务中创建 proof、payload 和 current-candidate pointer。

## 6. 状态机

主要状态：

`queued -> running -> preliminaryReviewBlocked | finalReviewBlocked | qualityBlocked | budgetBlocked | candidateReady -> committed | rejected | cancelled | failed`

约束：

- `preliminaryReviewBlocked`、`finalReviewBlocked` 和 `qualityBlocked` 引用 working prose/checkpoint，不伪造 candidate proof。
- Reviewer 对同一 reviewer、同一 prose revision 最多尝试 2 次。耗尽后旧 revision 只能查看、取消或由作者编辑生成新 revision，不能通过重启重置次数。
- `budgetBlocked` 是该 run 的硬终态，只能取消或新建 run；不能在原 run 内补充预算继续请求。
- 恢复器根据最新连续、兼容、hash 验证通过的 checkpoint ordinal 跳转到下一阶段。损坏或不兼容的 checkpoint 只能被丢弃并重算。

## 7. 数据契约

V9 需要至少覆盖以下逻辑实体：

| 实体 | 作用 |
|---|---|
| Run ledger | run 身份、状态、当前 prose/candidate revision、material/base-draft digest |
| Working prose revisions | 编辑稿/润色稿及来源 hash；未通过全部门禁时不构成候选 |
| Candidate namespaces | 为 pending writes 预留稳定 revision namespace |
| Candidate proofs | 永久保存 candidate hash、source prose、hard gate、终审、质量和 manifest hashes |
| Candidate payloads | 可过期的正文与详细证据 |
| Pending writes | staged memory/outbox payload 的唯一真源；PK 为 `(runId,candidateRevision,writeId)` |
| Commit receipts | accept idempotency、稳定 version ID、candidate proof、draft/material CAS 结果 |
| Revision leases | 规范化作者反馈租约和 owner/CAS |
| Budget ledger | provider call/token/cost 的原子 reservation、settlement 和 crash recovery |
| Event ledger | 重启后仍可按 run/stage 查询的脱敏事件 |
| Outbox | RAG/派生索引的幂等最终一致任务 |
| Chapter summary revisions | 绑定 `sceneCommitSetHash` 的不可变摘要与 current head |

### 7.1 Candidate namespace 不变量

- 每个 manifest 条目都必须解析到 proof 相同的 `(runId,candidateRevision)`。
- 手工改稿从 N 生成 N+1 时，兼容的 `preProse` artifact 必须在 N+1 下以新 deterministic `writeId` 重新物化；payload/hash 可以复用，但不得引用 N 的 row。
- 所有 `proseDerived` writes 必须基于 N+1 正文重新计算。
- N+1 accept 不得 fallback、引用或提升任何 N pending row。

### 7.2 生命周期

- Proof-bearing working revision、namespace、proof 和 receipt 永久保留最小 tombstone。
- Candidate payload、review/quality evidence、checkpoint 和 staged pending payload 按明确 TTL 清理。
- 无 proof 的父 revision/namespace 可以级联删除；有 proof 的父记录受 FK `RESTRICT`，清理器直接删除允许过期的子记录。

## 8. 质量契约

1. Preliminary reviewer 与 final council 必须是独立 provider 调用，不能复制同一次 combined review。
2. Final council 必须在 polish 和 deterministic gates 之后执行。
3. 默认 `overallScore >= 95`，每个 critical dimension `>= 90`。
4. 缺失分数、解析失败、scorer 异常、证据 hash 不匹配或 evaluator 不可用都进入阻断状态。
5. 手工编辑产生新 `proseRevision`，必须重新执行 deterministic gate → final review → extraction → quality。
6. `CandidateProof` 和 accept CAS 必须包含 exact prose hash、gate evidence hash、final council hash 和 quality hash。

## 9. 预算、取消与重试

- 默认单 run 硬上限：48 次 provider calls、160,000 tokens、USD 5 估算成本。
- 每次 provider 调用前必须在 SQLite 原子预留预算；完成、失败或 abandoned 后结算。
- Provider 无法提供准确价格时使用版本化价格表估算；无法估算则 fail closed，不能绕过成本门。
- Cancellation token 必须传到所有 provider stage；取消后禁止新的 reservation 和权威写入。
- Transport retry、review revision 和新 run 是不同预算维度，不能通过重启或编辑隐式清零。

## 10. Author accept 事务

`BEGIN IMMEDIATE` 后必须完成：

1. 校验 run owner、状态、candidate revision/hash、accept key。
2. 校验 base draft、material digest、feedback lease、hard gate、final council 和 quality evidence。
3. 校验 manifest 中所有 pending writes 属于同一 namespace，且 payload hash 一致。
4. 写正文、稳定 version ID、committed memory、反馈状态和 commit receipt。
5. 如果本次提交改变了完整章节的 committed receipt set，按新的 `sceneCommitSetHash` 追加 deterministic summary revision 并更新 head。
6. 标记 run committed，并写入幂等 outbox。
7. 提交事务。

SQLite 事务完成后才允许 UI 显示已采纳。RAG 处理失败时显示 `indexPending`，不得回滚已提交正文。

## 11. RAG 与连续性

- 文档 admission 字段必须结构化保存：project、tier、visibility、owner、scope ancestry 和普通 tags。
- `requiredTagGroups`、`boostTags` 属于 query contract，不存成文档 tag 类型。
- visibility/scope/required tags 必须在 FTS/ANN 候选上限截断前由 SQL admission；boost 只在 admission 后参与打分。
- 必须验证超过 4,096 个不可见/不合格高分候选不会遮蔽合法 Canon。
- Authoritative chapter summary 只由 accept 事务基于 committed receipt/contribution set 生成；LLM enrichment 只能作为带 provenance 的 derived overlay，不能覆盖权威摘要。

## 12. 迁移与发布

实施分阶段进行：

1. V9 schema、repository 和双读兼容；不切生产入口。
2. 完整 `SceneBrief` 与统一工作台入口，保留 feature flag 回退。
3. 纯 pipeline stages、独立 review、95 分质量门和 staged writes。
4. Candidate proof、author accept coordinator、receipt、反馈 lease 和 outbox。
5. RAG admission、Canon 分层、chapter summary revisions。
6. Cancellation、budget ledger、typed recovery、event ledger 和 retention worker。
7. 真实 provider canary 与分阶段放量。

迁移必须在备份数据库上通过 upgrade、rollback/read compatibility、崩溃注入和重复执行测试。V27 不提供 N-1 reader：V26 reader 与 writer 都必须拒绝 V27 数据库；forward-only rollback 必须停止写入并恢复迁移前的 V26 备份，禁止原地降级。切换入口前，旧工作台生成路径只能作为 feature-flag rollback，不能与新路径同时写权威状态。

## 13. 机械验收摘要

实现只有同时满足以下条件才能宣称完成：

1. 正常工作台按钮确实调用 `StoryPipeline`，不是直接单次 completion。
2. 生产 `SceneBrief` 带完整 cast、profile、scene index、target 和 world context。
3. 成功 UI 状态对应可重启恢复的同一候选正文。
4. 拒绝、取消、失败和过期候选对权威正文/记忆产生零写入。
5. 重复 accept 幂等；同 key 不同 candidate fail closed。
6. Draft 或 material 并发变化返回 typed conflict，并保留候选供用户处理。
7. 每个 ordinal 都通过 crash-before/crash-after resume 测试。
8. Reviewer attempts、run budget 和 provider reservation 在重启/并发后不超限。
9. 手工改稿重跑 hard gate、终审、extraction 和质量门。
10. Candidate N+1 的 manifest 中同时存在 N+1 preProse 与 proseDerived rows，且提升零条 N rows。
11. Finalization 期间 provider 调用数严格为 0。
12. 质量总分低于 95、关键维度低于 90、缺分或解析异常均不能产生 `candidateReady`。
13. Preliminary/final reviewers 是独立调用；polish 后正文必须重新终审。
14. RAG visibility/scope/tag admission 在候选截断前生效，并通过 4,096 starvation 用例。
15. 章节完成后重新采纳某场会生成新 summary revision，下一章读取新 head。
16. FK 开启时 retention cleanup 保留 proof/receipt/tombstone，清除允许过期的子数据。
17. 真实 provider benchmark 通过正常 DI、完整 pipeline 和 accept coordinator，质量门默认 95；fake 不得替代。
18. `flutter analyze --no-pub`、目标测试、全量离线测试、迁移测试和文档校验全部通过。

完整测试矩阵见本地规划产物：

- `.omx/plans/test-spec-chapter-generation-recovery.md`
- `.omx/plans/prd-chapter-generation-recovery.md`

## 14. 实施交接

推荐使用 `$ultragoal` 保存分阶段完成账本，并用 `$team` 并行执行以下受限 lane：

- Schema/transaction executor：V9、receipt、lease、budget、event、outbox。
- Pipeline executor：统一入口、完整 brief、staged writes、取消和恢复。
- Context/RAG executor：Canon、admission、summary revisions。
- Test engineer：unit/integration/E2E/failure injection/real-provider gate。
- Code reviewer/Verifier：共享文件冲突、数据兼容和最终证据审计。

Team 关闭前必须提供 schema migration、事务失败注入、全阶段恢复、真实入口 E2E、质量门与全量离线测试证据；Ultragoal 再将这些证据记录为 durable checkpoints。`$ralph` 仅作为用户明确选择的单所有者持续验证后备方案。

## 15. 剩余非阻断风险

- V9 schema 和事务协调器改动面大，必须按共享文件所有权分阶段合并。
- 真实 provider benchmark 受凭证、费用和模型波动影响；未获得真实证据时不得宣称完整完成。
- 95 分门槛可能提高 `qualityBlocked` 比例和延迟，需要观察分数、重试、预算和人工采纳率。
- SQLite 写锁和 outbox 延迟仍是运行风险，需通过短事务、lease recovery 和故障注入控制。
- Checkpoint/pending payload 的落盘与加密策略需要在实现安全审查中确认。

## 16. 共识记录

- Architect：`APPROVE`
- Critic：`APPROVE`
- Consensus gate：`complete`
- Durable handoff：`.omx/state/ralplan/chapter-generation-recovery-handoff.json`
- 本 Spec 产出阶段未修改生产代码或测试代码，也未启动实现。
