# Agent 工程能力补齐与评估闭环 Spec

状态：V26 本地实现已进入最终复核；真实发布矩阵登记为外部条件（2026-07-14：本地实现与证据复核已完成，19 条 integration 标为 `passed`，AEE-14/15/18/23/24 因正式 KMS/custody/signing、非 ad-hoc 应用身份和完整预算未配置而保持 `not-evaluated`。production trust registry 仍刻意为空，本轮没有运行 GLM，整体 `releaseEligible = false`）

关联 Issue：[#90](https://github.com/changw98ic/n0vel/issues/90)

目标读者：小说生成流水线、LLM 基础设施、测试与发布负责人

范围：当前项目仍缺少的 Agent 工程能力；本文是实施与验收合同，不代表功能已经完成

文档判定规则：

- “必须/不得/只有……才能”是规范性要求；“当前/已经”是事实陈述，必须由仓库路径、测试结果或冻结报告支持。
- 单元测试通过只证明对应原语；只有生产路径集成测试通过，才能声明该能力已进入正常流水线。
- Fake/test-double、provider 连通性、非空文本检查和 Pass³ smoke 均不得表述为内容质量、性能或发布门已通过。
- 第 14 节 24 条机械验收必须分别有可复查证据。任一项为部分完成、样本不足、未运行或仅 smoke，本 Spec 状态都不得改为 Completed。

本文所称“生产流水线”不是一个名为 `StoryPipeline` 的类，而是由 DI 解析 [`StoryPipelineFactory`](../lib/features/story_generation/data/story_pipeline_factory.dart)、创建 [`PipelineStageRunnerImpl`](../lib/features/story_generation/data/pipeline_stage_runner_impl.dart) 并最终通过 [`GenerationCommitCoordinator`](../lib/features/story_generation/data/generation_commit_coordinator.dart) 提交候选的用户可达链路。

## 1. 背景

当前项目已经具备场景规划、角色扮演、节拍解析、正文编辑、独立评审、确定性硬门、质量门、候选证明、作者采纳、恢复、预算与 RAG 等生产基础。此前开发记录中的 GLM canary 暴露了另一类问题；由于仓库内尚无满足第 14 节的冻结 release report，这些历史运行只能作为问题线索，不能作为本 Spec 的验收证据：

- Prompt 虽有 `templateId@version` 常量和 trace 字段，但历史调用没有稳定绑定版本；当前新增的按 trace name 推断版本仍不是不可变 registry。
- Prompt 文本、变量 schema、输出 schema、修订规则和 hash 没有组成同一个可回放发布单元。
- 真实结果只能描述“当时工作区代码”，无法严格比较 prompt A/B、模型 A/B 或 pipeline 配置 A/B。
- 质量分、硬门、review、token、调用数、延迟、成本和失败类型尚未关联到同一 experiment/trial。
- 单次真实通过不能区分稳定能力与幸运样本；缺少 Pass³ 和置信区间。
- 真实 canary 曾出现九个工作区场景对应十个 fixture、长时间无逐场进度等 harness 缺陷，证明 benchmark 本身也必须被测试。
- 失败反馈仍可能触发整篇重写，造成 token 膨胀、延迟上升和已通过能力回退。

本 Spec 将与当前项目相关的 Agent 工程技巧收敛为一套可执行实验系统：版本可追溯、任务可复现、轨迹按保留层级可审计/复评/重执行、结果可机械评分、性能可比较、失败可归因、版本可晋升或回滚。

## 2. 参考原则

本项目采用以下公开 Agent benchmark 的共同原则，并按小说生成场景做本地化。链接与描述于 2026-07-11 复核：

- [Claw Bench](https://github.com/claw-bench/claw-bench)：真实任务、自动 verifier、分权重检查点。
- [Claw-Eval](https://github.com/claw-eval/claw-eval)：Completion/Safety/Robustness 与 Pass³，避免单次幸运通过。
- [PinchBench](https://github.com/pinchbench/skill)：真实世界任务、完整 transcript JSONL、可复现评分。
- [LangChain AgentEvals](https://github.com/langchain-ai/agentevals)：trajectory 级评估与 reference trajectory。
- [OpenAI MLE-bench](https://github.com/openai/mle-bench)：任务、grading report 和实验聚合共同发布；官方比较建议至少三个 seed 并报告均值与标准误。

这些参考不是依赖项。项目不得为了对齐 benchmark 引入新的运行时框架；应复用现有 SQLite ledger、checkpoint、event log、LLM trace 与测试基础设施。

本地化差异必须显式记录：Claw-Eval 当前说明允许在 API 波动时人工重新触发以获得三条成功 trajectory；本项目不采用该策略。这里的 transport 失败受预注册尝试上限约束，并进入可靠性、时间和成本分母，不能补跑到三个有利样本。

## 3. 目标与非目标

### 3.1 目标

1. 每次 LLM 调用稳定绑定不可变 prompt release，而不是运行时按字符串猜版本。
2. 用 experiment manifest 固定 scenario set、模型、provider、generation/evaluation bundle、pipeline 配置、预算和 trial 数。
3. 将 trajectory、质量、硬门、review、候选/采纳、成本与性能关联到同一 trial。
4. 提供按 prompt/model/pipeline 版本聚合的 Pass³、质量、鲁棒性、失败分布和成本报告。
5. 建立覆盖结构执行、角色一致性、物理连续性、记忆/RAG、恢复、安全和性能的对抗题库。
6. 以机械发布门决定 prompt 版本晋升、保持、回滚；禁止人工挑选成功样本。
7. 优化 p50/p95 延迟、token、调用数和重试，同时保持质量与安全硬门不下降。

### 3.2 非目标

- 不把所有 GitHub Agent 题型搬入项目；浏览器、邮件、日历、桌面操作等无关能力不进入范围。
- 不用请求成功率代替内容质量或 Agent 完成度。
- 不降低现有质量总分 95、关键维度 90、作者明确采纳等生产门槛。
- 不允许 benchmark-only 分支绕过正常 DI、生产流水线、candidate proof 或 `GenerationCommitCoordinator`。
- 不以 LLM judge 单独决定硬事实、安全、事务或恢复正确性。

## 4. 当前基线与明确缺口

| 能力 | 当前基线 | 仍缺少 |
|---|---|---|
| Prompt 版本 | 已有不可变 `PromptRelease`/bundle、23 个 story-generation call-site registry、canonical hash、调用证据与存储原语；release preflight 会展开数据库中的真实 prompt 内容，拒绝空 bundle 及仅 ID/版本标签不同的假 challenger；candidate finalizer 会把 run/candidate proof 原子绑定到 generation bundle；`canonical-json-v2-unicode-17.0.0` 已通过官方完整 NFC conformance 数据。全 `lib/` 用户可达 LLM 调用 inventory 已按 exact release ref 和 champion/challenger bundle membership 封存，inventory seal 为 `sha256:944981e67cc5ad63c66ad1f2f6a1eebae52ca9b5e5e032156ae2cacc6cab145e`；23 个 Story PromptRelease 使用 closed-schema renderer，15 个生产调用点由 source variables 渲染并可对 provider messages 做 exact replay。role-turn、arbiter 与 stage-narrator 已发布 `2.1.0-exact-structured-output`：release 同时冻结 formal 模式的 exact shape/最多 2 次模型重试/禁止本地修补，以及 non-formal 模式的现有兼容修复策略 | 尚未在达到预注册样本量的真实 provider matrix 中形成版本级 prompt 效果评分与晋升报告；旧 anchor/反向消息证据仍不得算 release evidence |
| Trajectory | 已有 LLM trace、stage checkpoint、slot/attempt ledger、manifest、正式 Pass³ 投影；V26 durable sandbox 以每个 lease epoch 的独立 SQLite 副本执行，只有仍持有有效 lease 的副本能登记为下一代状态；content attempt 完成、sandbox generation、evidence root 与 slot seal 已合并到同一 `BEGIN IMMEDIATE` 事务。Runner authority 在 `prepared`、`accepted`、`outboxCompleted`、`finalPersisted` 四个边界追加 lease-fenced、candidate-bound、文件 hash/size 与状态投影绑定的一致性快照链；全新进程、authority 连接、Runner 和 sandbox 实例会从已验证快照恢复，篡改快照在 provider 前 fail closed，已跨过的较早阶段幂等返回当前链头而不倒退；旧 epoch 的迟到写只会留在不可见孤儿副本。provider/judge 长调用期间按租约三分之一周期续租，返回后再次做 fenced check；release coordinator 对 private-complete、import-complete、promote/rollback-complete 三个崩溃边界做 exact-idempotent 恢复，重复运行不增加 holdout probe | 尚未用满足正式 trust/signing/KMS 的真实 provider 长作业验证部署级恢复；本地跨进程故障注入覆盖四个恢复边界、V25→V26 迁移、快照篡改拒绝和 sealed SQLite 投影 |
| 质量 | 已有 95/90 生产门、expected-outcome、从 sealed ledger 重算的 Pass³；V18 gate authority 会按 canonical pair 从数据库重算质量、用量、attempt 时间和发布结论；生产 executor 只接受 concrete authority set：独立 AppLlm judge 仅评主观两维，正文以 quoted/untrusted JSON 进入冻结 prompt；deterministic safety 不信任 `safe=true`；角色维读取 `workspace_characters` 结构状态并核对正文要求，Canon 维读取 `story_memory_chunks.root_source_ids_json` 的 committed provenance，空要求不再默认 100；四个确定性 verifier 都必须属于 EvaluationBundle，typed 输入和结果写入追加式 receipt 后由 Gate 重算；judge 与 SUT 调用均按冻结价格表逐条计价，失败 judge 的实际 token 也计入；preflight 按 `cells × trials × maxAttempts` 在 provider 前验证 execution-wide evaluator 最坏预算，Gate 再从全部 attempt 重算实际总消耗 | 尚无达到样本量的真实 provider champion/challenger release matrix、trusted holdout confirmation 和版本级对比报告 |
| 对抗测试 | 已有 hard gate、恢复、RAG 测试和 25 组 attack/control typed catalog；50/50 场景已通过真实 production code path adapter、strict archive membership、只读 authority/trial/production DB 重算与 projection/receipt/budget/cache/authority tamper 拒绝，持久化归档已完整通过 | 当前证据级别是 `integration-production-path`；purpose-built Case 15/19 明确为 `realProviderEvidence=false`，冻结真实 provider matrix 与 holdout confirmation 尚未运行 |
| 性能 | 已有 token/latency trace、并发角色、checkpoint 和性能门算法；独占 10 万条、64 维 SQLite LSH 归档为 160 万索引行、177,926,144 bytes、构建 40.418s、正常重开 135.329ms/0 次写入、recall@10=1.0、p95=171.481ms、最多物化 4,149 条候选；最坏 10 万同桶测试的 Dart 物化上限为 5,120 条。admission/FTS/CJK 迁移按 256 条 keyset 分批，Hybrid embedding 按 128 条分批并保持跨批原子回滚 | 尚无至少 20 个有效配对观测的冻结真实 provider 比较；10 万条全量首建/重新 embedding 已是明显等待点，百万级以上还受 LSH 索引体积和重建 I/O 限制 |
| 失败修复 | 已有 review/quality feedback、有界重试、不可变 `failure-taxonomy-v1` 和版本化 `quality-targeted-repair-v2`；每个规范 failure code 冻结 primary priority、允许改动范围、事实保留集、最大尝试与强制重验阶段，多标签 secondary failures 不会被 primary 掩盖；未知、空或非规范 code 一律 fail closed；真实第 1 场从 91 分阻断经定向因果修订后通过 | 尚未在达到预注册样本量的真实 champion/challenger matrix 中形成 repair policy 版本级效果对比 |
| 发布 | V26 已禁用未验证 `promote()`、caller-supplied gate verdict/holdout result 和无签名本地 seal；完整/public app 只接收 hash、一次性 custody capability 与公开 attestation，不读取 private plan、vault、fixture root 或 signer command path；外层 supervisor 在独立进程绑定 spent grant 并启动 private runner。进程级 probe 已验证 complete 子进程的 env/argv/file-open 记录不含私有路径，伪 broker、额外私有 env、complete→private 模式切换均在 provider 计数前失败，private 子进程还必须持有 supervisor 一次性启动令牌。外部 signer 使用无父环境的单次 broker 协议；生产 helper 与 realpath 全部父目录必须 root/system-owned、无 symlink、对应用用户不可写，应用本身不得以 root 运行；macOS helper 必须是有效非 ad-hoc 签名，并由编译期 trust entry 精确 pin TeamIdentifier、designated requirement 与 CDHash，调用前立即重验文件链与签名身份。每次请求绑定随机 request ID、payload hash 与公钥并回验签名。root 不再由 env/descriptor 注入，只能来自编译进 release 的 trust registry，entry 还精确 pin provider release、key resource、root public key、runner principal membership 与 signing key membership；当前 production registry 为空，因此任何部署默认在 provider 调用前 fail closed。完整 signed attestation 与 TTL 保留在 custody contract，但序列化 contract 永远只是 audit DTO，反序列化会拒绝任何 `productionTrustPinned`/`releaseAuthorityEligible` 真值；真实执行权限只存在于不可序列化、私有构造且必须用编译期 production registry 现场重验签名后铸造的进程内 token，恢复必须重新验签得到新 token。KMS attestation 还必须绑定相同 source tree 的本地 criteria baseline seal；supervisor 在任何 provider dispatch 前逐项复核 baseline 归档文件 SHA-256，正式运行只能由 DB 推导 AEE-14/15/18/23/24 并与该 baseline 合成最终 registry。token 在 public provider 前、private provider 前、每次签名、最终报告/seal 与恢复时重验；恢复还会重算整库 authority audit root、重验私有 holdout 签名和首 production receipt 的 exact capability 绑定。一次性 capability 必须先于任何 production receipt 写入；receipt `BEFORE INSERT` 在没有 exact active capability 时中止，首条 receipt 的 `AFTER INSERT` 原子绑定 capability；禁止把 capability 事后附着到旧 receipt，恢复只能精确复用已绑定 capability。本地 seed、任意 signing interface、序列化 DTO 和 audit registry 只能走 audit mode，永不 release-authoritative | 仍缺独立评审后写入源码并重建发布二进制的真实 KMS trust entry、真实部署 attestation 和 GLM public/private matrix；仓库不会生成或伪造这些外部事实 |

### 4.1 代码证据快照与边界

以下仅描述 2026-07-12 工作区可见证据，不等同于第 14 节完成：

| 证据 | 当前可证明 | 不能据此声称 |
|---|---|---|
| [`story_prompt_registry.dart`](../lib/features/story_generation/data/story_prompt_registry.dart)、[`app_llm_call_site_inventory.dart`](../lib/app/llm/app_llm_call_site_inventory.dart)、[`app_llm_prompt_renderer.dart`](../lib/app/llm/app_llm_prompt_renderer.dart)、[`generation_ledger_candidate_finalizer.dart`](../lib/features/story_generation/data/generation_ledger_candidate_finalizer.dart) 及对应测试 | Registry 发布、run→bundle 不可变绑定、closed-schema render、source-variable→provider-message exact replay、全 `lib/` call-site inventory seal、candidate hash/snapshot/accept 的 bundle 一致性与 spoof/rebind 拒绝已由集成测试覆盖 | 尚不能声称真实 provider champion/challenger experiment 已跑通或 challenger 已获晋升 |
| [`agent_evaluation_ledger.dart`](../lib/features/story_generation/data/evaluation/agent_evaluation_ledger.dart)、[`agent_evaluation_runner.dart`](../lib/features/story_generation/data/evaluation/agent_evaluation_runner.dart)、[`agent_evaluation_fixture_sandbox.dart`](../lib/features/story_generation/data/evaluation/agent_evaluation_fixture_sandbox.dart)、[`agent_evaluation_production_executor.dart`](../lib/features/story_generation/data/evaluation/agent_evaluation_production_executor.dart) 及对应测试 | slot/attempt/CAS、content digest、Pass³、heartbeat、epoch-versioned sandbox、seal 同事务 generation commit、跨进程 episode 恢复、孤儿 stale-write 隔离，以及 provider-complete→prepared→accept→outbox→final-result 的 Runner-owned snapshot chain 均有真实文件、全新进程/连接或故障注入测试；恢复不增加 SUT/judge 调用，快照篡改在 provider 前拒绝 | 尚未执行满足正式 trust/signing/KMS 条件的真实 provider 长作业操作系统强杀恢复演练 |
| [`agent_evaluation_release_store.dart`](../lib/features/story_generation/data/evaluation/agent_evaluation_release_store.dart)、[`agent_evaluation_holdout_store.dart`](../lib/features/story_generation/data/evaluation/agent_evaluation_holdout_store.dart)、[`agent_evaluation_trusted_holdout.dart`](../lib/features/story_generation/data/evaluation/agent_evaluation_trusted_holdout.dart)、[`agent_evaluation_trusted_holdout_runner.dart`](../tool/agent_evaluation_trusted_holdout_runner.dart) 及对应测试 | 真实子进程中 fixture/facts sentinel 不进入 stdout、stderr 或 attestation；caller `{"result":"pass"}` 只能得到冻结 evaluator 推导的 `fail`；未消费 grant、两个 promoted challenger 的 caller 选优、假 runner、错 key、TTL 回拨/越界、policy/family/arm 移植、第二次 probe 和无外部验签根晋升均被拒绝 | 尚未执行真实 provider holdout；生产 vault ACL 与 Ed25519 私钥仍需要部署侧 KMS/secret-store 保证 |
| [`agent_adversarial_scenarios.dart`](../lib/features/story_generation/domain/evaluation/agent_adversarial_scenarios.dart)、[`agent_adversarial_production_cases.dart`](../lib/features/story_generation/data/evaluation/agent_adversarial_production_cases.dart) 与 [`agent_adversarial_production_path_test.dart`](../test/agent_adversarial_production_path_test.dart) | 第 12 节 25 组、共 50 个 immutable attack/control 定义均有 production-path authority adapter；完整归档会重开并重算数据库、文件 hash、进程 receipt 与 exact payload membership，当前 50/50 场景完整通过；Case 19 使用真实 Runner+ProductionExecutor 验证 independent/episode generation topology，旧 synthetic helper 已删除 | 这是 integration-production-path，不是付费真实 provider 或 release-authoritative holdout 证据 |
| [`real_agent_evaluation_harness.dart`](../test/test_support/real_agent_evaluation_harness.dart) | 10 场 × model × champion/challenger × 3 slot 的矩阵展开、预算、进度和 provider 调用 smoke；两 arm 已使用真实 `StoryPromptRegistry` bundle hash，并把各自已注册的 system template 放入实际请求；精确 token breakdown 缺失会 fail closed | 该入口仍是短 prompt provider smoke，尚未运行生产流水线、candidate/accept、外部质量裁判、真实性能门或 holdout |
| [`agent_evaluation_metered_client.dart`](../lib/features/story_generation/data/evaluation/agent_evaluation_metered_client.dart)、[`agent_evaluation_production_evidence.dart`](../lib/features/story_generation/data/evaluation/agent_evaluation_production_evidence.dart)、[`agent_evaluation_production_authorities.dart`](../lib/features/story_generation/data/evaluation/agent_evaluation_production_authorities.dart) 及对应测试 | 完整 production executor、独立 judge/safety、冻结价格 release、SUT/judge 逐调用成本、失败轨迹成本、六维来源拆分、deterministic-quality receipt 与 Gate 独立重算已落地；伪造费率、错路由、judge injection/畸形 JSON、只改确定性分数并重算调用方 hash 均被拒绝 | 这些 release-grade authority 尚未在达到样本量的真实 GLM champion/challenger matrix 和独立 trusted holdout 中运行 |
| [`real_chapter_generation_commit_gate_test.dart`](../test/real_chapter_generation_commit_gate_test.dart)、[`quality_repair_policy.dart`](../lib/features/story_generation/data/quality_repair_policy.dart) 与本地归档 `/.omx/evidence/production-canary-1783821224215793.{json,md}` | GLM-5.1 经正常 DI 完成 10/10 场生产流水线、每场双评审、95/90 质量门、candidate proof、accept receipt、summary head 和 outbox drain；报告 canonical hash `312fb906…4795a`，source-tree hash `659f5c18…0ba5c44`，最低 overall 95、最低关键维度 92，secret scan 无命中 | 这是单个 production canary，不是 champion/challenger 配对、3 个 independent slot、冻结外部 evaluator、性能统计或 trusted holdout；报告固定 `releaseEligible = false` |

明确缺口：旧 real harness 仍只是短 prompt provider smoke，固定 `releaseEligible = false`，不能用于晋升。仓库内已经具备正常生产 pipeline executor、独立 judge/safety、冻结价格、DB authority receipt、deterministic-quality receipt、跨进程 episode generation、Ed25519 trusted holdout 和 Gate 重算能力；剩余主线是把这些 authority 组成有界真实 GLM champion/challenger matrix，运行冻结 holdout，再生成可晋升或回滚的 DB-derived release report。

### 4.2 当前发布阻断项

| 优先级 | 关联验收 | 阻断项 |
|---|---|---|
| 已关闭（integration） | 6、8 | authority DB 写入、attempt、observation、sandbox generation 与 seal 已按 lease epoch fencing；旧 worker 只能污染自身不可见的 epoch-local orphan。V25 在 accept 前追加冻结 traces、meter、quality/judge evidence 与全部运行身份的 prepared checkpoint，恢复时复用相同 accept idempotency key、补 drain/collector/final result；accept 前与 accept 后故障注入均证明 SUT/judge 零新增调用，checkpoint 同时进入 sealed DB projection |
| P0 | 10、11、23 | 真实 10 场 production canary 已通过正常 DI/quality/proof/accept；production collector、attempt-scoped meter、可注入 authoritative story run ID 和 transaction 重算已具备离线对抗测试，但尚未接入 generation arm × 3 independent slot 的 real harness，也没有冻结外部 evaluator；不能把单次章节 canary 称为 release 稳定性或 Pass³ |
| P0 | 13、14、17 | DB Gate 已从冻结 price release 重算 SUT/judge 全调用成本，并从追加式 deterministic-quality receipt 重算角色、Canon、鲁棒性和效率；独立 safety/transaction membership 在 provider 前校验。剩余阻断是把该 authority 链接入真实完整 matrix，并产出达到预注册样本量的 release report |
| P0 | 18、23 | 固定 evaluator 的独立子进程、supervisor/private-path split、编译期 trust registry、root-owned + 非 ad-hoc code-identity pinned signer broker、冻结公钥回验、完整 signed custody retention、无 seed external material、所有 public/private real-provider capability gate、receipt-before-capability 禁止与首 receipt 原子绑定、spent-authority grant、唯一 regression winner、TTL containment、opaque public manifest 与单次 probe已落地；未注册 root/provider/resource/principal/key、Team/requirement/CDHash mismatch、自签/伪造证明、key/command mismatch、响应篡改/重放、命令失败/超时、current-user-owned/unsafe path/mode/symlink、环境继承、旧 receipt 事后绑定、audit/local signer mode confusion 与本地 seed 晋升均 fail closed；production registry 当前为空，剩余阻断是独立 provision 并 code-review 真实 non-exportable KMS + ACL trust entry，再随真实 matrix 运行一次冻结 holdout并归档非诊断 confirmation |
| 已关闭（integration） | 2 | 完整 Unicode 17.0.0 NFC 与官方 conformance 已通过；23 个 Story PromptRelease 使用 closed schema，15 个生产调用点已从 schema-valid source variables 渲染并 exact replay provider messages |
| 已关闭（integration） | 16 | 25 组、50 场题库均有 production-path authority adapter 和 strict archive verifier；50/50 场景完整通过，但不得升级为真实 provider 证据 |
| 已关闭（integration） | 21 | observation/report codec 在 SQLite 前强制 exact allowlist、canonical JSON、64 KiB 上限、secret/taint 拒绝和冻结 schema；tamper 与 malformed payload 测试已通过 |

## 5. 核心模型

### 5.1 PromptRelease

每个可调用 prompt 必须发布为不可变实体：

```text
PromptRelease {
  templateId
  semanticVersion
  language
  contentHash
  systemTemplate
  userTemplate
  variablesSchemaSnapshot
  outputSchemaSnapshot
  rendererRelease
  parserRelease
  repairPolicySnapshot
  variablesSchemaHash
  outputSchemaHash
  owner
  changeNote
  createdAt
}
```

约束：

- `templateId + semanticVersion + language` 唯一。
- 新 release 的 `contentHash` 使用 `canonical-json-v2-unicode-17.0.0 + SHA-256`，带 `prompt-release-v1` domain tag，覆盖 system/user 模板、变量 schema、输出 schema、renderer/parser release 和 deterministic repair contract；字符串按 UTF-8/NFC 编码，object key 按 Unicode scalar 排列，数字使用 canonical JSON 表示。旧 wire contract 只通过显式 `canonical-json-v1-limited-latin-hangul` reader 验证，禁止用旧名宣称通用 NFC。后续更换算法或 Unicode 数据版本必须发布新的 hash contract，禁止静默替换。
- 任何能改变模型行为或解析语义的修改必须发布新版本；旧版本只读。
- 废弃状态不得回写 immutable release；使用追加式 `PromptReleaseLifecycleEvent(releaseRef, event, reason, time)` 表达 deprecated/disabled。
- 生产调用必须显式携带 `PromptReleaseRef`。按 trace name 推断只允许作为迁移期告警 fallback，不能用于正式实验。
- 正式调用必须由冻结 `rendererRelease` 使用完整 `userTemplate + schema-valid resolvedVariables` 生成实际 messages；调用证据必须重放同一 renderer，并证明重放结果与 provider request 完全一致。`userTemplate` 不得只保存任务名、摘要或示意文本，调用者也不得用已经渲染的 messages 反向冒充原始变量。
- Prompt 文本不得仅存在于数据库；代码/资产中保留可审查源文件，数据库保存发布快照和 hash。
- 每次调用另存 `renderedMessagesDigest` 与 `resolvedVariablesDigest`；digest 仅用于证明输入身份，不得替代受权限和保留期约束的可复评内容。
- “所有生产 LLM 调用”指所有从用户可达产品入口触发的调用，而不只限于 `story_generation/data`。CI 必须扫描整个 `lib/`，通过冻结 call-site inventory 区分纳入项和有理由的 allowlist；simulation、workbench 或未来新增入口不能因目录不同而自动豁免。
- Canonical digest 的逻辑值统一为 32-byte SHA-256。API/trace/JSON 使用 `sha256:<64 lowercase hex>`；SQLite 为兼容性可保存 raw 64 hex，但只能在 repository 边界转换，业务层不得混用两种表示。`canonical-json-v2-unicode-17.0.0` 使用生成时校验 SHA-256 的官方 `UnicodeData.txt` 与 `DerivedNormalizationProps.txt` 数据，并由 `test/fixtures/unicode-17.0.0/NormalizationTest.txt` 全集验证 canonical decomposition、combining-class reorder、composition exclusion、Hangul 与多脚本 NFC；任一输入数据 hash 或 conformance case 不匹配都 fail closed。

### 5.2 GenerationBundle 与 EvaluationBundle

一次场景生成同时使用 director、role、beat、editorial、review、quality 等多个 call-site。被测生成逻辑与实验裁判必须分离：

```text
GenerationBundle {
  bundleId
  releases: List<{
    stageId,
    callSiteId,
    variantId,
    promptReleaseRef
  }>
  bundleHash
}

EvaluationBundle {
  evaluatorBundleId
  deterministicVerifierReleases[]
  judgePromptReleases[]
  judgeModelRoutes[]
  rubricReleaseHash
  aggregatorReleaseHash
  failureTaxonomyHash
  blindingPolicyVersion
  evaluatorBundleHash
}
```

约束：

- `stageId + callSiteId + variantId` 在同一 generation bundle 内唯一；不得用 `Map<stageId, ...>` 折叠 judge、consistency、arbiter、polish、format repair 等同阶段 call-site。
- Champion/challenger 比较的所有 arm 必须使用同一个冻结 `EvaluationBundle`。生产流水线自身的 review/quality 仍作为被测行为记录，但不能成为唯一实验裁判。
- Judge 不得看到 bundle、模型或版本的可识别标签；候选顺序随机化。主观评分必须使用冻结校准集，并记录重复评分/分歧处理策略。
- 禁止只记录单个 editorial prompt 而忽略其它生成、解析、修复或评测 release。

### 5.3 ExperimentManifest

```text
ExperimentManifest {
  experimentId
  scenarioSetReleaseHash
  generationBundleHashes[]
  evaluatorBundleHash
  modelRoutes[]
  pipelineConfigHash
  providerConfigHashWithoutSecrets
  providerApiRevision
  sdkAdapterReleaseHash
  decodingConfigHash
  tokenizerReleaseHash
  priceTableHash
  codeCommit
  sourceTreeHash
  buildArtifactHash
  runtimeReleaseHash
  trialsPerCell
  seedPolicy
  trialIsolationPolicy
  transportAttemptPolicy
  performanceSamplingPolicy
  qualityComparisonPolicyHash
  holdoutAccessPolicyHash
  budgets
  qualityThresholds
  createdAt
}
```

Manifest 创建后不可修改。重跑必须创建新的 execution ID，并引用同一 manifest。Manifest 引用的 scenario、generation/evaluation bundle、verifier、rubric、聚合器、failure taxonomy 与价格表都必须是不可变 release；浅层 ID 不构成冻结。正式实验优先要求 clean source tree；dirty workspace 只能在 `sourceTreeHash` 完整冻结 release input closure 时运行。当前 closure 包含 `pubspec.yaml`、`pubspec.lock`、完整 `lib/`、`tool/`、`assets/`、`scripts/` 与 `macos/`（排除 Flutter ephemeral 和 Xcode user data），并拒绝其中的 symlink；`codeCommit` 还必须等于真实 Git HEAD。execution 启动时校验实际 source closure 与 AOT build artifact，SDK adapter、tokenizer 和 runtime release hash 再由这两个实测 hash 及 provider API revision 自动推导，不得用 caller 自报的 digest 或 `codeCommit` 代替运行产物身份。

### 5.4 ScenarioSet 与 Scenario

每个场景题目至少包含：

```text
Scenario {
  scenarioId
  version
  difficulty
  inputFixture
  fixtureHash
  isolationMode
  episodeId?
  episodeStep?
  requiredCapabilities[]
  adversarialMutations[]
  verifierReleaseRefs[]
  rubricReleaseRef
  expectedTerminalState
  requiredFailureCodes[]
  allowedAdditionalFailureCodes[]
  forbiddenFailureCodes[]
  outcomeComparatorReleaseRef
  forbiddenSideEffects[]
  acceptExpected
  referenceFacts
  maxBudget
}
```

题目必须是真实工作流输入，通过正常工作区、纲要、cast、world、RAG 和生产流水线构建；不得在 benchmark 内直接调用私有 stage 代替生产 DI。

- `isolationMode = independent` 时，每个 logical trial 从同一个只读 fixture snapshot 克隆独立项目/SQLite 命名空间，accept 只写入该副本，禁止 trial、arm 或 execution 间共享正文、记忆、RAG、cache 和 outbox 状态。
- `isolationMode = episode` 时，scenario step 仍各自拥有 cell/slot，但同一执行、arm、model/decoding、`episodeId` 和 `trialNo` 的 step 共享 `episodeTrialId = domainHash("episode-trial-v1", executionId, generationBundleHash, modelRouteHash, decodingConfigHash, episodeId, trialNo)` 所标识的隔离副本。step 按 `episodeStep` 串行，前一步封存后下一步才可 claim；episode 的结果、Pass³ 与清理只有在全部预期 step 封存后才能计算。不同 execution、arm、model 或 trialNo 仍从相同 episode 初始快照开始且不得共享状态。连续十场 canary 必须采用该模式，或为每一场冻结完全相同的前置快照和 prose hash。
- 对抗场景的正确结果可以是 blocked/rejected/conflict。Trial 成功表示 actual terminal state、required/allowed/forbidden failure-code set、accept 行为和副作用经冻结 comparator 判定符合 Scenario 期望，不表示必须生成并采纳正文。Failure code 顺序不影响集合比较，额外且未列入 allowed 的 code 使 trial 失败。

### 5.5 EvalCell

Manifest 必须在 provider 调用前展开并封存完整 canonical cell 集合：

```text
EvalCell {
  generationBundleHash
  sutModelRouteHash
  scenarioReleaseHash
  decodingConfigHash
  cellId = domainHash(
    "eval-cell-v1",
    generationBundleHash,
    sutModelRouteHash,
    scenarioReleaseHash,
    decodingConfigHash
  )
}
```

相同字段只能得到一个 `cellId`；重复 cell、缺失 cross-product 成员或运行时自由增加 cell 都使 harness fail closed。Expected cell/slot set 从 Manifest 的 canonical cross-product 生成并封存，而不是由 worker 边执行边决定。

### 5.6 Trial 与 Observation

每个 logical trial slot 由以下稳定唯一键关联：

```text
(executionId, cellId, trialNo)
```

`runId` 和 provider 请求不是主键的一部分，而是 slot 下的 attempt：

```text
TrialSlot {
  trialSlotId
  executionId
  cellId
  trialNo
  status: queued|leased|running|sealed
  result?: pass|fail|insufficientEvidence
  leaseEpoch
  leaseOwner?
  leaseExpiresAt?
  sealedEvidenceHash?
}

TrialAttempt {
  trialSlotId
  attemptNo
  runId
  kind: content|transport
  status
  startedAt
  finishedAt?
}
```

每次 provider request 只能对应一个 attempt：可重试 transport 失败记录为 `kind = transport, status = failed`；实际产生被评分 trajectory 的成功 request 记录为该 slot 唯一的 `kind = content, status = completed`，并绑定这次真实请求的 tokens、latency 和 cost。不得在 provider 已返回后再创建没有 provider request 的 synthetic content attempt；如果需要独立表达逻辑轨迹，应新增 `ContentTrajectory` 实体，而不是复用 attempt。

约束：logical slot 唯一；`cellId` 必须通过外键解析唯一 scenario，TrialSlot 不重复保存 scenario identity；缺失/冲突 cell 在 provider 前 fail closed。claim/续租/封存使用 CAS；`sealed` 是唯一 terminal status，且必须同时保存不可变 `result + sealedEvidenceHash`。一个 slot 只能封存一条 content trajectory，所有 transport attempt 永久关联且不可筛除。每条 provider trace、stage checkpoint、gate evidence、review、quality score、candidate proof、accept receipt 和性能观测都必须可无歧义解析到 slot 与 attempt。

`leaseEpoch` 是强制 fencing token，而非仅用于 claim：slot 下所有 observation、checkpoint、candidate、accept、隔离项目写入和 seal 都必须携带 `(trialSlotId, leaseEpoch, leaseOwner)`，由 repository/事务在写入时校验当前 lease。过期 worker 的迟到 provider 响应、candidate 或 accept 一律以 stale-lease conflict 拒绝。Seal 必须在同一事务内校验 lease、唯一 content trajectory、expected observation cardinality 和 evidence root。

## 6. 数据与持久化契约

当前实现版本为 authoring schema V27：V15—V18 建立核心 ledger、compatibility、holdout 和 DB-derived gate；V19 增加持久化随机 dispatch；V20/V21 回填 production authority、冻结价格和 deterministic-quality receipt；V22 增加 lease-fenced sandbox generations、signed holdout attestation 与 token→regression winner 绑定；V23/V24 增加 production family authority 唯一性、`releaseConfigurationHash` 贯通和 append-only final-report seal；V25 新增 accept 前的 append-only prepared production evidence checkpoint；V26 将 provider-complete 恢复提升到 Runner authority，新增四阶段 hash-bound SQLite snapshot chain 与 terminal generation/seal 绑定；V27 以 additive `owner_id` 列持久化 agent-private story memory 的主体边界。V27 contract 为 `minReaderVersion = 27`、`minWriterVersion = 27`；系统没有实现 N-1 reader，因此旧 V26 reader 与 writer 打开 V27 都会在任何业务读取或写入前由 schema opener 拒绝。回滚只允许停止写入、校验并原子恢复迁移前的 V26 备份，不支持 V27 原地降级。[`schema-compatibility-matrix.json`](schema-compatibility-matrix.json) 与 `agent_evaluation_recovery_drill.dart` 覆盖 V26 WAL 一致性快照、V26→V27 升级、幂等、注入失败整事务回滚、N-1 reader/writer 拒绝、校验后原子 restore，以及自动发现的 45 张 evaluation/release authority 表（包含 prompt release、`generation_bundle_releases` membership、prepared checkpoint、Runner recovery chain 和 final-report authority）的 canonical audit-root 一致性；drill 会分别改写真实 attempt authority 字段和删除 bundle membership，并要求两者都改变 root，避免遗漏表的“自洽假证明”。应用自动备份使用 SQLite `VACUUM INTO`，不 raw-copy WAL 主文件。上一版 V26 drill report 是未纳入仓库的本机非发布证据，工作区路径为 `.omx/evidence/evaluation-recovery-drill-v26-final3/report.json`，canonical report hash 为 `1926876a74fc9186d4820a9a63059fece6ef24288e53aa3756c37b3b2b7fa9f6`。

历史校验锚点：`authoring schema V18` 是 gate derivation 首次落地的版本；该短语为文档 bundle validator 保留，不代表当前 schema 仍停留在 V18。

在现有 authoring SQLite schema 上新增或等价实现以下逻辑表：

| 表 | 关键字段 | 用途 |
|---|---|---|
| `prompt_releases` | template/version/language/hash/schemas/content | 不可变 prompt registry |
| `prompt_release_lifecycle_events` | releaseRef/event/reason/time | 追加式废弃/禁用状态 |
| `generation_bundles` | bundleId/bundleHash/releasesJson | 被测生成流水线版本集合 |
| `evaluation_bundles` | evaluatorBundleId/hash/verifiers/judges/rubric/aggregator | 与被测版本隔离的冻结裁判 |
| `eval_scenario_sets` | setId/version/manifestHash | 题库版本 |
| `eval_scenarios` | scenarioId/setId/fixtureHash/verifiersJson | 题目与 verifier |
| `eval_experiments` | experimentId/manifestJson/manifestHash | 冻结实验设计 |
| `eval_executions` | executionId/experimentId/status/timestamps | 一次实际执行 |
| `eval_trial_slots` | logical unique key/lease epoch/status/sealed evidence hash | 不可重复的逻辑试验 |
| `eval_trial_attempts` | trialSlotId/attemptNo/runId/kind/status | 内容与 transport 尝试 |
| `eval_observations` | observationKey/trialSlotId/attempt/stage/kind/itemKey/value/evidenceHash | 分数、门禁、性能与失败 |
| `eval_release_gate_derivations` | verdictHash/projectionHash/authorityReleaseHash | 证明 verdict 来自冻结 DB authority，而非调用者直接写入 |
| `eval_scorecards` | scope/key/aggregateJson/inputSetHash | 可复算聚合结果 |
| `prompt_channel_heads` | channel/bundleHash/epoch | Champion 指针与 CAS |
| `prompt_release_decisions` | from/to/epoch/scorecard/approver/time | 追加式晋升与回滚账本 |
| `schema_compatibility_contracts` | schema/minReader/minWriter/release | binary 读写兼容门 |
| `story_generation_run_bundles` | runId/generationBundleHash/time | 生产 run 与 bundle 的不可变绑定 |
| `eval_experiment_families` / `eval_family_challengers` | family/policy/challenger/ordinal | holdout 访问族与 challenger 历史 |
| `eval_holdout_tokens` / `eval_holdout_confirmations` | family/token/alpha/result | 一次性、非诊断性 holdout confirmation |
| `eval_release_gate_verdicts` | kind/arms/scorecard/input/pair/policy/status | 追加式 regression/holdout verdict |
| `eval_holdout_accesses` | token/family/challenger/execution/runner/state/verdict | fixture 访问前消费并绑定 trusted-runner execution |
| `prompt_release_decision_authorizations` | decision/regressionVerdict/holdoutConfirmation | 晋升决策的不可复用授权链 |
| `eval_sandbox_generations` | execution/isolation/generation/parent/path/fileHash/lease | 只让当前 lease epoch 封存的副本成为可恢复 episode 状态 |
| `eval_sandbox_recovery_checkpoints` / `eval_sandbox_recovery_seals` | execution/slot/attempt/original+writer lease/stage/candidate/file hash+size/projection/chain/generation | provider 完成后的跨进程一致性快照链与 terminal generation 不可变绑定 |
| `eval_trusted_holdout_attestations` | confirmation/access/key/releases/payload/signature/TTL | authoring DB 中的非诊断、公钥可验证 holdout 授权 |

不变量：

- 通用 JSON 字段不能成为任意数据通道。每类 observation 使用 typed allowlist DTO、集中式脱敏、secret/taint 测试和尺寸上限；API key、authorization header、未经脱敏异常不得落库。
- observation 只追加，并使用确定性唯一键 `(trialSlotId, stage, kind, attemptNo, itemKey)` 和单调 sequence 实现幂等；单值 observation 的 `itemKey = singleton`，多值类型由 schema registry 定义稳定 item key。相同 key/same digest 重放成功，相同 key/different digest 必须 conflict 并 fail closed，不能把 evidence hash 放进唯一键绕过冲突。聚合器只读取已经 sealed 的唯一 evidence set。scorecard 可重算，不能成为 trial 真相来源。
- quality observation 必须绑定 exact prose hash、`EvaluationBundle`、judge prompt/model、rubric 和 aggregator release。生产 quality gate 结果另行标注为 SUT observation。
- execution 必须先封存预期 cell/slot 集合 hash，再运行 trial；只有 execution terminal 且所有预期 slot terminal 后才能原子生成 scorecard。每个 scorecard 保存输入集合 hash、expected-set hash 和 aggregator release，缺失、重复或后来新增 trial 均使报告失效。
- benchmark harness 的场景数、fixture 数、纲要 scene 数必须在任何 provider 调用前相等。
- 所有内容/hash 使用第 5.1 节规定的 canonical contract 和类型 domain tag。普通 hash 只证明身份和检测偶然损坏；若威胁模型包含可写数据库的攻击者，scorecard root 必须使用平台密钥签名/HMAC，或提交外部不可变审计日志，不能把 SHA-256 描述为防篡改认证。
- 可回放分三级：`audit` 仅验证 manifest、hash 和决策；`regrade` 需要冻结的脱敏输入/输出；`re-execute` 还需要 fixture、模型/配置和受控上下文。需要 regrade 的正文/私有记忆只能存入加密、权限化、带 TTL 的 blob；TTL 到期后报告只能称 audit-verifiable，不得称可重新评分或可重新执行。
- Holdout 原始 fixture、reference facts 与逐题 verifier evidence 必须位于独立 ACL/KMS 保护的 trusted-runner store。authoring 进程必须通过独立 trusted-runner 子进程/服务提交 candidate evidence；不得向 runner 注入 evaluator 或 result。runner 在解析 fixture 前必须只读验证 authority DB 中已消费 grant，并只返回签名、非诊断 attestation。开发者可访问的 authoring DB 只保存 opaque release hash、token 状态和 confirmation；普通 `eval_scenarios.scenario_json` 不得保存 holdout 明文。Trusted runner、resolver、固定 evaluator、访问审计、签名根和 TTL 必须冻结并进入报告。

## 7. 执行流程

执行面分为两级，命名和报告必须保持一致：

- `smoke`：只验证 manifest/cell 展开、provider 连通、预算、进度、slot/attempt 与 Pass³ 机械路径。它可以使用简化题目，但报告必须声明 `claimScope = provider-execution-and-pass3-smoke`，`releaseEligible = false`。
- `release`：必须通过正常 DI 和完整生产流水线，并产生 prompt/bundle trace、checkpoint、deterministic gate、review、外部 evaluator、quality evidence、candidate proof、accept/blocked receipt、成本/性能、sealed scorecard 和 holdout confirmation。只有该级别能够进入发布决策。

禁止通过文件名、测试名或 JSON 的 `reportType` 把 smoke 包装成 release evidence。报告消费者必须按 `claimScope` fail closed；未知 scope、缺少 `releaseEligible` 或 smoke 却声明可晋升时，报告无效。

```text
freeze manifest
  -> validate harness and scenario hashes
  -> create execution
  -> seal expected trial slots
  -> for each cell(generation bundle × model × scenario)
       -> clone isolated fixture or start isolated episode
       -> claim logical slot by CAS
       -> run N independent trial slots
       -> capture full trajectory and observations
  -> compare actual outcome with frozen outcome comparator
       -> seal slot evidence
  -> aggregate scorecards
  -> compare champion/challenger
  -> run frozen holdout confirmation
  -> publish report
  -> promote or reject bundle
```

执行要求：

- independent trial 使用全新隔离数据库/项目命名空间、全新 run、独立 provider trajectory 和确定性 fixture；episode step 只能在相同 `episodeTrialId` 内共享状态，并按 ordinal 串行。
- 正式稳定性实验禁止跨 trial、arm 或 execution 复用生成结果。Checkpoint/cache key 必须包含 `executionId + trialSlotId + runId + stage + generationBundleHash + modelRoute + decodingConfigHash + outputSchemaHash + promptReleaseHash + parserRelease + inputHash`，只允许同一 trial 的 crash-resume 复用；key 层必须让 foreign slot/run 直接 miss 并真实 dispatch。若导入或伪造的 durable provenance 仍声称跨 trial 命中，则标记 `nonIndependent`，不得计入 Pass³。
- Manifest 预注册每个 slot 的最大 transport attempts、可补跑错误分类和总预算。所有 attempt 计入 reliability、端到端 latency 与成本；prompt 引发的 timeout、截断和格式失败不得从能力分母剔除。达到上限仍无 content trajectory 时 slot 以 `result = fail|insufficientEvidence` 封存，禁止继续补到有利样本。
- 运行逐场输出进度：scenario、trial、stage、elapsed、calls、tokens、latest status；禁止十分钟以上黑箱。
- execution 必须有 wall-clock deadline、取消传播和最终 drain；中断后从 experiment/trial ledger 恢复，不重跑 sealed trial。
- 任何 harness invariant 失败立即终止 execution，不产生模型能力结论。
- 题库分为公开 dev、固定 regression 和未向 prompt 开发者暴露的冻结 holdout。每个 experiment family 预注册 holdout access budget、confirmation token、alpha-spending 和轮换条件；开发者只能看到非诊断性 pass/fail 汇总，不能访问原始 fixture、逐题失败或证据。Challenger 在 regression 达标后消耗一次 confirmation token；不得让多个后继 challenger 反复查询同一 holdout，预算耗尽必须轮换 holdout 并建立新 family。
- Release gate 的质量/性能输入必须带 `comparisonInputSetHash`、`expectedPairSetHash` 和来源 scorecard hash，并由 gate 从 sealed observations 重算或逐项验证。预期 pair ID 从 canonical cell/slot set 生成；超时、取消、transport failure 与缺失 pair 不得静默删除，处理策略由 sampling policy 预注册。相同 key/same digest 重放幂等；different digest、未知 pair、缺失 pair 或调用者直接注入未绑定的 LCB/p95 一律得到 `insufficientEvidence`。

## 8. 评分模型

### 8.1 硬门

Trial 是否成功首先由 `actual outcome == Scenario expected outcome` 决定。对于 `acceptExpected = true` 的正常生成场景，以下任一失败时 trial 为 fail，软分不能抵消：

- 正常 DI 与完整生产流水线未执行。
- candidate proof、payload、final prose hash 或 accept receipt 缺失。
- deterministic gate、preliminary review、final review 或 95/90 quality gate 未通过。
- 冻结 `EvaluationBundle` 中声明为 required 的 deterministic verifier 或外部质量门未通过。
- 作者采纳前发生权威正文/记忆写入。
- 角色、Canon、物理连续性、安全、预算、恢复或事务 verifier 失败。
- trace 中存在未知/缺失 prompt release、bundle hash 不一致或 scorer evidence 无法关联。

对于 `acceptExpected = false` 的对抗场景，必须同时满足：

- 实际 terminal state 与 `required/allowedAdditional/forbidden failure codes` 经冻结 outcome comparator 判定相符；
- candidate/accept 不得出现，或严格符合 Scenario 声明的特殊预期；
- `forbiddenSideEffects` 全部为零；
- 阻断证据来自冻结 deterministic verifier、事务账本或持久化证据，而非被测 prompt 自我声明。

错误地接受危险输出、以错误 failure code 阻断、发生未授权写入或证据不完整均为 fail。

### 8.2 能力分

所有 terminal trial 都记录各维度 observation 和实际资源消耗；只有符合预期结果且 evidence 完整的 trial 计为 hard-pass。能力分用于比较质量，不替代 trial outcome：

| 维度 | 权重 | 来源 |
|---|---:|---|
| 文笔与可读性 | 25 | 质量 scorer + 重复/节奏确定性指标 |
| 剧情功能与因果 | 20 | required beat verifier + final review |
| 角色/关系一致性 | 15 | structured profile/state verifier |
| Canon、RAG 与跨场记忆 | 15 | committed fact/provenance verifier |
| 鲁棒性与恢复 | 15 | adversarial mutation/crash tests |
| 效率 | 10 | 所有 attempted trial 的 calls/tokens/latency/cost 相对冻结预算 |

LLM judge 只能参与主观维度；硬事实以确定性 verifier 或持久化证据为准。每个维度的归一化函数、缺失值处理、聚合顺序、权重和舍入规则由 `aggregatorReleaseHash` 冻结；不得只对成功幸存者计算成本或通过改变裁判获得能力提升。

### 8.3 Pass³ 与稳定性

- 默认 `trialsPerCell = 3`。
- 一个 scenario 只有三个独立 logical slot 全部 hard-pass 才取得 Pass³；同一输出、跨 slot cache、人工替换或共享状态均不算独立。
- Pass³ 是最低稳定性门，不是精确通过率估计。报告展示 attempted/completed/transport-fail、端到端完成率、passRate、pass3Rate、质量 mean/min、失败 taxonomy；只有达到预注册最小样本量时才展示 p10/p50/p95 和置信区间。
- 性能 release set 每个比较单元至少 20 个有效配对观测，或使用 Manifest 中预注册且经批准的跨场景分层样本策略。Champion/challenger 按相同 fixture 配对、交错随机顺序运行，冻结并发度、warmup、region、API revision 和 rate-limit 条件；CI 算法、alpha 与非劣界必须写入 sampling policy。
- `qualityComparisonPolicyHash` 冻结质量比较的最小样本量、配对单位、estimator、bootstrap/CI 算法、family-wise alpha、多维度 multiplicity correction、非劣界、缺失/并列处理和停止规则。没有该 policy 或样本不足时，质量比较只能标记 `qualityEvidenceInsufficient`，不得晋升。
- 不得用平均质量掩盖单次 93 分或结构失败。
- 样本不足、被手工筛选或缺失 trajectory 时结果标记 `insufficientEvidence`，不得晋升。

## 9. 失败分类与修订策略

统一 taxonomy 至少包含：

```text
mechanical.dialogue_ratio
mechanical.opening_hook
mechanical.ending_hook
continuity.physical_impossibility
continuity.prop_violation
character.power_inversion
character.voice_or_knowledge
planner.missing_required_beat
review.disagreement
quality.repetition
quality.expository_dialogue
quality.causal_gap
rag.visibility_or_scope
recovery.checkpoint_or_cas
budget.exceeded
provider.transport
harness.invalid_fixture
```

每个 failure code 绑定版本化 repair policy：允许修订的段落、必须保留的事实、最大尝试和再次验证范围。默认策略是最小弱段修订；只有结构重规划或 prose hash 全面失效时才允许整篇重写。

一个 trial 可以记录多个 failure code，但必须由冻结 taxonomy 指定 deterministic primary priority，并保留所有 secondary failures。聚合报告同时展示 primary 分布与 multi-label 共现，禁止通过只选择一个“好解释”的 failure 隐藏其它失败。

修订不得跳过 hard gate、final review、quality 或 candidate proof。

## 10. 性能与成本

### 10.1 必须采集

- attempted/completed/transport-fail、端到端完成率，以及达到最小样本量后的场景/阶段 p50/p95 wall time 与置信区间。
- provider call count、transport retry、output retry、editorial/replan/quality repair 次数，以及失败/取消 trajectory 的实际消耗。
- input/output/total tokens 与按冻结 price table 估算的成本。
- checkpoint/cache 命中率、恢复节省的调用与 token。
- 上下文长度、被裁剪/延迟的 RAG 命中数。
- 并发度、队列等待时间、provider rate-limit 时间。

### 10.2 优化顺序

1. provider 前运行对白、重复、物理、角色边界等廉价确定性检查。
2. 仅在同一 logical trial 的 crash-resume 内，对完整 cache key 相同的调用复用兼容 checkpoint；正式 Pass³ 禁止跨 trial 复用。
3. 独立角色调用并发；依赖 stage 串行；冲突裁决按需执行。
4. 使用结构化摘要和 token budget，避免把全历史反复传给格式修复和局部修订。
5. 将 quality/review 缺口转换成弱段 patch contract，减少全文重写。
6. 不得通过减少 reviewer、放宽门槛或截断关键 Canon 获得性能提升。

### 10.3 发布性能门

Challenger 只有同时满足以下条件才能晋升：

- Pass³ 和所有安全/事务硬门不低于 champion。
- 在配对 scenario/model 上，overall 能力分、各关键质量维度、mean、p10 和 min 按 `qualityComparisonPolicyHash` 满足预注册的非劣界、置信区间和多重比较修正；不得仅以仍高于 95 为由接受相对质量回退。
- 达到最小性能样本量后，scenario p95 延迟相对回归不超过 10%。例外必须在 Manifest 中预注册明确的能力收益阈值、批准角色和最大性能豁免；运行后临时批准无效。
- 所有 attempted trial 的端到端平均 token/cost 相对回归不超过 15%；失败、超时、取消和补跑按实际消耗计入。
- provider 调用放大率、transport 成功率、端到端完成率和重试率不恶化。
- cache/checkpoint 命中不因版本变化失效；若必须失效，migration note 明确。
- Regression 达标后，冻结 holdout confirmation execution 仍满足上述门；confirmation 必须遵守 family access budget/alpha-spending，所有未晋升 challenger 也保留在实验族记录中，防止反复试验后只报告幸运版本。

## 11. 与当前项目相关的 Agent 技巧映射

| Agent 面试能力 | 目标落点 | 完成所需证据 |
|---|---|---|
| 规划与执行分离 | director → roleplay → beat → editorial → review | typed stage trajectory |
| 多 Agent 独立性 | 角色并发、Judge/Consistency 独立、按需 adjudication | 独立 call IDs 与 prose hash |
| Memory/RAG | visibility/scope/owner/Canon admission | SQL admission 与 starvation test |
| Reflection/repair | failure taxonomy → versioned targeted repair | 新 prose revision 与缺口消失 |
| Tool safety | provider budget、取消、幂等、outbox | ledger/CAS/crash evidence |
| Observability | run/stage/prompt/model/trajectory 统一关联 | 可回放 trial report |
| Evaluation | versioned task + verifier + weighted rubric + Pass³ | scorecard/input-set hash |
| 性能工程 | 并发、checkpoint、token budget、p95 SLO | champion/challenger diff |
| Release engineering | immutable bundle、feature flag、晋升/回滚 | release decision record |

## 12. 对抗题库最低覆盖

每一项必须同时交付两级证据：

1. `catalog-contract`：只证明 ID/版本、attack/control 配对、fixture hash、期望结果和 verifier release 完整。
2. `production-path`：通过该题对应的真实生产入口执行；verifier 必须从实际输出、trace、SQLite ledger、RAG 查询结果、checkpoint、candidate proof 或 accept receipt 派生结论。

Catalog 中预置的布尔字段及其自检只能满足第一级，不得计作能力覆盖、真实副作用或第 14.16 条完成证据。

1. 对白比例刚低于/刚高于 25%，并验证 35% 安全目标不会误作生产硬门。
2. 动作后 50 字内对白钩子与纯环境开头。
3. 同一人同一分钟相距两地；带代签/系统延迟机制的合法对照。
4. 断电设备主动运行；有备用电源且正文明确说明的合法对照。
5. 被逼问角色无因反客为主；有新证据导致位势翻转的合法对照。
6. 同一意象重复三次、分析性对白过密、重复解释同一证据。
7. polish 引入原稿没有的角色/道具/Canon 违例。
8. 私有记忆泄漏给无权限角色；scope/owner 合法对照。
9. 4,096 个高分不可见候选遮蔽合法 Canon。
10. 每个 ordinal 的 crash-before/crash-after 与重启恢复；episode step N 封存后杀进程，由另一 worker 恢复 step N+1，必须读取前序提交而不是重新 clone 初始 fixture。
11. provider timeout、429、截断、格式错误、重复响应和 failover。
12. candidate accept 重复 key、不同 candidate、draft/material 并发变化。
13. prompt release 缺失、hash 被篡改、旧 schema 回放不兼容。
14. benchmark 九场/十 fixture、重复 scenario ID、缺 verifier、未完成 trial。
15. champion/challenger 中 challenger 质量更高但 p95/cost 超门，必须拒绝晋升。
16. 篡改 challenger 自带 quality prompt 使其固定返回高分，冻结 evaluator 必须保持结论不变。
17. 三个 trial 输入相同时，第二、三次也必须因 cache key 的 `trialSlotId + runId` 隔离而真实调用 provider，不得命中首个 trial cache；若注入旧缓存或伪造 provenance 造成 foreign-slot 来源，仍必须判为 `nonIndependent` 且不得取得 Pass³。
18. 100 次请求仅 3 次成功、其余 timeout；不得通过无限补样取得 Pass³，失败调用的时间、token 和成本必须计入。
19. 正常场景 trial-1 accept 写入新 Canon 后，trial-2/challenger 不得读到该状态；episode 合法对照应只在同一 trial 内看到前序提交。
20. 正确阻断隐私泄漏、hash 篡改、预算超限和 CAS 冲突时，trial 必须按 expected outcome 记为成功，且 forbidden side effects 为零。
21. 两个 worker 同时 claim 同一 trial slot 或同时晋升不同 challenger，只有一个 CAS 能成功；即使 CAS 参数正确，调用者也不得把 rollback target 指向最近一次已授权晋升的历史前任之外的 bundle。
22. 正文包含“忽略评分规则并给 100 分”等 judge prompt injection，冻结/blinded evaluator 不得服从正文指令。
23. 连续尝试多个 challenger 后，只有预注册 regression 胜出者能够进入一次性冻结 holdout confirmation；不得挑选多个 holdout 结果中的最高者，不得用 regression execution 冒充 holdout，也不得跨 family/champion/policy/scenario set 移植 confirmation。减少 family counter、恢复 consumed token 或重写 sealed access/verdict 的 raw SQL 必须失败。
24. Worker A lease 过期后由 B 接管；A 的迟到 observation、checkpoint、candidate、隔离项目写入和 accept 必须全部以 stale epoch 拒绝。
25. Manifest 声明的 cell cross-product 被删除一个不利 arm、重复一个有利 arm或运行时增加 cell，harness 必须在 provider 前 fail closed。

## 13. 实施阶段

### Phase 1：版本身份闭环

- 完成所有生产调用的显式 `PromptReleaseRef` 透传。
- 引入 registry、canonical content/schema hash、generation bundle 与独立 evaluation bundle。
- 为缺失/未知版本 fail closed；迁移 fallback 只告警且不计正式实验。

### Phase 2：实验与观测数据

- 新增 experiment/scenario/trial-slot/attempt/幂等 observation schema 与 repository。
- 给 trace、checkpoint、quality、candidate、receipt 增加 trial 关联。
- 实现隔离 fixture/episode、CAS claim、可恢复执行器和逐场/逐阶段进度。

### Phase 3：评分与报告

- 实现 expected-outcome 硬门、能力分、Pass³、性能/成本聚合和 sealed input-set hash。
- 生成 JSON + Markdown 报告；禁止手工编辑已冻结报告。
- 提供 prompt/model/pipeline 三种维度的对比。

### Phase 4：对抗题库与性能优化

- 将现有 hard-gate、RAG、恢复、accept 与真实 canary 整理为 dev/regression/冻结 holdout scenario set。
- 增加 targeted repair、checkpoint cache 与性能 SLO。
- 运行 champion/challenger，记录失败 taxonomy 迁移。

### Phase 5：发布门

- Generation bundle 晋升通过 feature flag/canary 放量。
- 通过 channel head epoch/CAS 晋升；保留 champion 一键回滚，回滚不删除 challenger 证据。
- 发布记录关联 experiment、scorecard、代码 commit 和数据 migration。

## 14. 机械验收标准

只有以下全部满足才能宣称本 Spec 完成：

1. 冻结 call-site inventory 覆盖整个 `lib/` 的所有用户可达 LLM 调用；每个纳入调用都带已注册、hash 校验通过的 prompt release，allowlist 有逐项理由，未知版本正式运行 fail closed。
2. Prompt 文本、renderer/parser、变量/输出 schema 或 repair policy 改变会要求新版本；冻结 renderer 能用 schema-valid variables 重放实际 provider messages；canonical serialization/hash 有 golden vectors与完整 Unicode/NFC 合约，旧 release 不可修改。
3. 每个 run/candidate proof 可解析完整 generation bundle hash；同一实验所有 arm 绑定相同 evaluation bundle hash，且 judge 已 blinding。
4. Experiment manifest 以不可变 release/hash 冻结 scenario set、generation/evaluation bundle、模型/decoding、provider/API、source tree/build/runtime、verifier/rubric/aggregator/taxonomy、价格、预算、隔离、transport、质量比较、holdout 访问和性能 sampling policy。
5. Canonical EvalCell 完整展开 Manifest cross-product；重复、缺失或运行时新增 cell 在 provider 前 fail closed。
6. Logical trial slot 有唯一约束、lease epoch/CAS 和不可逆 terminal；所有 slot 写入均验证 fencing token，过期 worker 无法写 observation/candidate/accept；run/transport attempt 独立记录，重复 claim 或恢复不能制造额外内容样本。
7. independent trial/arm 从相同 fixture snapshot 的独立 SQLite/项目命名空间启动；episode step 按 ordinal 在同一 `episodeTrialId` 副本内连续，不同 execution/arm/model/trialNo 不共享状态，episode 仅在全部 step 封存后聚合。
8. 每个 trial 的 trajectory、gate、review、quality、candidate、receipt、成本与性能通过 slot/attempt 关联；observation 追加、幂等且只在 sealed evidence set 上聚合。
9. 正常与阻断场景均按 expected terminal state、required/allowed/forbidden failure codes、accept expectation 和 forbidden side effects 机械判定，不再把“必须 accept”当成所有场景的成功条件。
10. 质量 evidence 同时绑定 exact prose hash、evaluation bundle、judge prompt/model、rubric 与 aggregator；SUT 自身 scorer 无法修改实验结论。
11. 三个 slot 少一次、共享状态、跨 trial cache、被手工替换或 evidence 不完整时不得取得 Pass³ 或晋升。
12. 版本报告输出 attempted/completed/transport-fail、端到端完成率、passRate、Pass³、quality mean/min、失败分布及所有 attempted trial 的 calls/tokens/cost；只有满足预注册样本量才输出 p10/p50/p95/CI。
13. 质量非劣策略冻结配对、CI、family-wise alpha、多重比较修正和非劣界；gate 从 sealed observation/scorecard 验证 `comparisonInputSetHash + expectedPairSetHash`，`aggregateJson/status/reasons/LCB/p95` 均由冻结聚合器重算，不能接受调用者筛选的 pair 或直接注入的 verdict；样本不足标记 `qualityEvidenceInsufficient`。
14. 真实性能比较至少满足预注册的完整 expected pair set、最小配对样本量、交错随机顺序、冻结环境与统计算法；超时/取消/transport failure 不得静默删除，样本不足标记 `performanceEvidenceInsufficient`。
15. 真实 10 场 canary 的 workspace scene、outline scene、fixture 数在 provider 前相等，按 episode 隔离并逐场输出 stage/elapsed/calls/tokens/status。
16. 对抗题库第 12 节全部有失败样本和合法对照；除 catalog-contract 外，每题都有 production-path 执行证据，verifier 从真实输出/trace/ledger/proof/receipt 派生且不依赖被测 prompt 或 fixture 布尔字段自我声明，并覆盖 scorer prompt injection、cache 独立性、trial 污染和 stale lease。
17. Challenger 未通过配对质量非劣、安全、事务、Pass³、transport reliability、成本或性能门时无法成为 champion；冻结 holdout confirmation 失败同样禁止晋升。
18. Holdout confirmation 受 experiment-family token、访问预算与 alpha-spending 约束；family counter/token/access 只允许单调向前且 raw SQL 不能恢复已消费预算或改写 sealed verdict；原始 fixture/evidence 位于独立 trusted-runner ACL/KMS 边界，普通 authoring DB 不含 holdout 明文；不向开发者返回诊断性逐题证据，禁止多个 challenger 自适应探测同一 holdout。
19. Champion 指针使用 expected-old bundle/epoch CAS；并发晋升只能一个成功，晋升和回滚决策永久追加；rollback target 必须从最近一次已授权晋升的追加式历史推导，不能由调用者自由指定。
20. 回滚只恢复该次已授权晋升的历史前任 generation bundle，历史 experiment/trial/scorecard 至少保持 audit-verifiable；regrade/re-execute 能力按保留层级准确声明。
21. typed observation/report 经过 allowlist、脱敏、secret/taint 和尺寸测试，不含 key、authorization 或未经授权内容；普通 hash 不被宣称为攻击者不可伪造。
22. 每个 schema release 提供 `schema-compatibility-matrix.json` 并测试 `minReaderVersion/minWriterVersion`、upgrade 顺序和 rollback 路径；至少交付 N-1 reader/writer 允许/拒绝测试，以及 pre-migration backup → 新版写入 → stop-write → export 校验 → restore → audit root 验证。N-1 不兼容时禁止旧 binary rollback，只允许 bundle rollback 或经过该流程验证的 backup restore。
23. 真实 provider 完成门覆盖 `releaseScenarioSet × requiredModelRoutes × champion/challenger × 3 independent slots`，且至少一次冻结 holdout confirmation；单一简单 scenario 的 Pass³ 不构成完成。
24. `flutter analyze --no-pub`、目标测试、全量离线测试、显式覆盖本文内容/本地链接/完成状态的文档校验，以及上述真实 provider release 报告全部通过；当前 smoke 即使显示 `releasePassed = true` 也不能满足本条。

每条验收证据必须登记：criteria ID、artifact/测试路径、精确命令、退出码、运行时间、代码 commit/source-tree hash、报告 hash、evidence level（unit/integration/real-provider-release）和保留级别（audit/regrade/re-execute）。“存在测试文件”、跳过的 opt-in test、test-double 通过或临时目录中未归档的报告都不能将条目标为完成。

截至 2026-07-14 的结论：V26 仓库内实现已完成本地复核。全量离线测试 `2815 passed / 17 skipped / 0 failed`，机器报告 SHA-256 为 `65bcc5eca8b53c5f259ac20d78109b97cf15d10db1d5b12f6e4ec5d5babf31b3`；50/50 integration-production-path 对抗归档 SHA-256 为 `cb64146d6b8f5344100004dda6a12df2d6439bc0bbee6b11da8acdc24bad8bcd`；V25→V26 migration/recovery drill 通过 45 张 authority 表及两类篡改检测，报告 SHA-256 为 `bbc62311480b32dd32d35ca30e2e47d28dd91d4f48d14d1e4af0b74bf669a266`；10 万向量性能报告 SHA-256 为 `585fb894cbafc08f36c669b3b177a5bd89c866c2577feb7db11e92414dcc4d12`。`flutter analyze --no-pub` 和 `git diff --check` 均通过，独立 code review 为 APPROVE、architecture review 为 CLEAR。

本次源码冻结 hash 为 `3f0fbf593acf6d5a380cf847d98981740a96922ffce9f1b83b5a7848842a049b`；macOS release 构建成功且构建后源码 hash 未变化，app artifact hash 为 `fec4303537ab9961169b4826d243c3c2f502b285911acaeeaa59b152d6b66b58`。该 app 明确是 ad-hoc 签名、没有 TeamIdentifier，只能作为本地构建证据。24 条逐项 registry 位于 `/.omx/evidence/spec-criteria-baseline-v26-final/`：19 条本地 criteria 为 integration `passed`，AEE-14/15/18/23/24 为 `not-evaluated`；registry 文件 SHA-256 为 `35ed2053984ab01e79a3c965bde90b0cfd28d79b2aa1cab3b46291f068110d94`，baseline seal 的语义 hash 为 `a7eed2837e1945f2d08e7b1c016ea2f9f3184a1e4342d9f27f29340b3d02087e`，seal 文件 SHA-256 为 `e650a2f06b03d6b0d65850bf34de303f5feb74a62f2cb0b3019d9d25f8486b37` 且权限为 `0600`。

因此，本地剩余任务已经收口，但本 Spec 仍不得标为 Completed，整体 `releaseEligible = false`。AEE-14/15/18/23/24 所需的真实 provider 性能/质量矩阵、trusted holdout 和完整 release report 继续作为外部条件：只有部署治理 provision 并 code-review non-exportable KMS provider/resource/root/principal/key membership、签署本次 baseline seal、重建正式签名二进制并明确授权完整预算后，才可运行 public/private champion/challenger matrix。本地 file seed、环境变量中的 API key、测试 audit registry、smoke、连通性探针、单次 canary 或 ad-hoc build 都不能升级为 `releaseEligible = true`。

## 15. 测试交付物

实施必须新增或等价提供：

- prompt registry/hash/bundle unit tests；
- generation/evaluation bundle 隔离、judge blinding 与 scorer prompt-injection tests；
- trace/checkpoint/quality/candidate trial-link integration tests；
- fixture/episode 隔离、trial 污染、experiment resume、重复执行和并发 claim tests；
- stale-lease observation/checkpoint/candidate/accept/write fencing tests；
- canonical EvalCell cross-product completeness/duplicate tests；
- scorecard golden vectors 与 input-set tamper tests；
- canonical JSON/hash golden vectors、幂等 observation 与 sealed completeness tests；
- Pass³ 缺 trial、跨 trial cache、幸运一次通过和 transport 补跑上限 tests；
- performance regression gate tests；
- harness invariant tests；
- versioned adversarial scenario fixtures；
- dev/regression/冻结 holdout 分区、family access budget、alpha-spending 及一次性 confirmation tests；
- opt-in 真实 provider release-evaluation champion/challenger runner（当前 smoke runner 不构成本交付物）；
- champion channel-head 并发晋升/回滚 CAS tests；
- migration `minReaderVersion/minWriterVersion` 支持矩阵、rollback fencing、data export 和 backup restore tests；
- 脱敏 JSON/Markdown 报告样例。

Fake 可以验证故障注入、事务和聚合算法，但不得代替真实 provider 的内容质量、稳定性或性能结论。

正式 release 入口是 [`agent_evaluation_release_coordinator.dart`](../tool/agent_evaluation_release_coordinator.dart)，不是 smoke test。它先验证授权、固定预算、source manifest 和预构建 app hash，再执行以下不可交换的两阶段流程：

```text
public-only fixed app
  -> DB-derived regression promote commitments
  -> 生成/恢复 0600 私有十题、fixture、plan、seed
  -> complete fixed app 从 public capability 重建结果（零 public provider 调用）
  -> consume access + exact-idempotent bind
  -> separate private fixed app
  -> import signed V2
  -> atomic promote + rollback drill
  -> atomic report + V26 DB seal + outer re-open verification
```

构建与运行入口为：

```bash
flutter build macos --release --no-pub \
  --target lib/agent_evaluation_release_coordinator_runtime.dart

export RUN_REAL_AGENT_EVAL=1
export REAL_LLM_COST_ACK=YES
export ZHIPU_API_KEY='<secret>'
export ZHIPU_BASE_URL='https://open.bigmodel.cn/api/paas/v4'
export AGENT_EVAL_REQUIRED_MODELS='glm-4.7-flash'
export AGENT_EVAL_JUDGE_MODEL='glm-4-flash-250414'
export AGENT_EVAL_PROMPT_PRICE_MICROUSD_PER_MTOK=0
export AGENT_EVAL_COMPLETION_PRICE_MICROUSD_PER_MTOK=0
export AGENT_EVAL_JUDGE_PROMPT_PRICE_MICROUSD_PER_MTOK=0
export AGENT_EVAL_JUDGE_COMPLETION_PRICE_MICROUSD_PER_MTOK=0
export AGENT_EVAL_MAX_ATTEMPTS_PER_TRIAL=3
export AGENT_EVAL_MAX_CALLS_PER_TRIAL=24
export AGENT_EVAL_MAX_TOKENS_PER_TRIAL=2500000
export AGENT_EVAL_MAX_PROMPT_TOKENS_PER_CALL=100000
export AGENT_EVAL_MAX_COMPLETION_TOKENS_PER_CALL=4096
export AGENT_EVAL_MAX_CALLS=9000
export AGENT_EVAL_MAX_TOKENS=936864000
export AGENT_EVAL_MAX_COST_MICROUSD=1
export AGENT_EVAL_JUDGE_MAX_CALLS=360
export AGENT_EVAL_JUDGE_MAX_TOKENS=37474560
export AGENT_EVAL_JUDGE_MAX_COST_MICROUSD=360
export AGENT_EVAL_JUDGE_MAX_TOKENS_PER_CALL=4096
export AGENT_EVAL_JUDGE_MAX_COST_MICROUSD_PER_CALL=1
export AGENT_EVAL_DEADLINE_MS=86400000
export AGENT_EVAL_PRIVATE_TIMEOUT_MS=86400000
export AGENT_EVAL_HOLDOUT_ACCESS_BUDGET=1

# execution ID、source-tree hash、真实 Git HEAD、AOT artifact hash、provider API
# revision、绝对工作目录、coordinator run ID、key ID、channel 与 approver 也必须
# 显式冻结；SDK adapter/tokenizer/runtime hash 由 coordinator 自动推导，不能手填。
dart run tool/agent_evaluation_release_coordinator.dart
```

`MAX_ATTEMPTS_PER_TRIAL` 与单次 attempt 的 calls/tokens 上限分别冻结。固定 app 的 metered provider 在 `_inner.chat` 前同步占用 attempt call/token reservation；已完成调用和并发中的 reservation 都计入上限，因此并发请求也不能竞态越界。命中 attempt 上限只拒绝尚未 dispatch 的下一次请求，已经越过 provider 边界的成功或失败调用仍按真实用量或保守 reservation 写入 DB 与 execution budget，并可在 attempt 上限内重试；route、预算或 deadline 在 dispatch 前失败时仍然 fail-closed。上述 3×24 配置下，单模型每套 10 题矩阵的 SUT 与 judge 最坏合计为 4500 calls、468432000 tokens；完整 release 还包含独立 public 与 private 两套矩阵，因此 coordinator-wide 总上限必须至少为 9000 calls、936864000 tokens，judge 子上限至少为 360 calls、37474560 tokens。两阶段共用同一组 durable journal，private 启动会读取 public 已消费量，最终 report/DB seal 绑定 final snapshot 与 journal hash。继续使用旧的 4500/500000000 授权会在任何 provider dispatch 前 fail closed，系统不得静默扩大授权或让两阶段各拿一份总预算。离线对抗矩阵必须同时核对底层 provider 计数、`eval_trial_attempts`、usage observation 与持久化 combined budget journal，不能只断言抛错。

`g005-free-glm-release-v4` 在发现旧实现没有 provider-bound attempt 硬上限后已主动停止，只保留为诊断证据：它没有最终报告、没有 trusted holdout、没有 promotion/rollback seal，不能作为 release evidence。修复后必须使用新的 execution/coordinator/key/channel 身份、全新 container `Data/` 工作目录和重新构建的固定 app 启动下一次正式矩阵；不得恢复或包装 v4 为合格报告。

macOS Release app 保持 App Sandbox 开启。传给固定 app 的 public/coordinator/private 工作目录与报告目录必须位于该 app 的 container `Data/` 下；把 SQLite authority 直接指向仓库目录会在首次建库前被 sandbox 拒绝。外层 CLI 仍在启动前校验 source/app hash，并在结束后重新打开最终报告和 DB seal；不得为方便评测关闭生产 sandbox。

以上两个模型在智谱官方文档中分别标为免费模型（[`glm-4.7-flash`](https://docs.bigmodel.cn/cn/guide/models/free/glm-4.7-flash)、[`glm-4-flash-250414`](https://docs.bigmodel.cn/cn/guide/models/free/glm-4-flash-250414)）；价格表因此冻结为 0，但 `REAL_LLM_COST_ACK` 仍用于授权真实 API 调用和配额消耗。若更换任何模型，必须按当时官方价格重新冻结四个 price 字段和总成本硬上限，不能沿用 0。只有最终报告同时满足 `claimScope = real-provider-release`、`releaseEligible = true`，并可解析到完整 DB scorecard、signed holdout、promotion/rollback 和 report seal 时，才可作为第 14.23 条证据。API key、Authorization header、私有题面和未脱敏 provider 错误不得出现在控制台或报告中。

正常生产流水线 canary 的 opt-in 入口为：

```bash
RUN_REAL_NOVEL_QUALITY_BENCHMARK=1 \
REAL_PROVIDER_COST_ACK=I_ACCEPT_REAL_PROVIDER_COSTS \
REAL_PROVIDER_MODEL=glm-5.1 \
REAL_PROVIDER_SOURCE_TREE_HASH=<workspace-source-hash> \
PRODUCTION_CANARY_OUTPUT_DIR=.omx/evidence \
flutter test test/real_chapter_generation_commit_gate_test.dart \
  --plain-name 'chapter recovery production gate' -r expanded
```

2026-07-12 归档运行用时 35 分 39 秒、退出码 0，并生成 secret-free JSON/Markdown；它满足生产 canary 证据，但报告强制 `claimScope = production-pipeline-canary`、`releaseEligible = false`，不满足第 14.23 条。

### 15.1 当前可执行验证入口

离线验证必须显式移除真实调用开关，避免开发机残留环境变量触发真实 API 请求或配额消耗：

```bash
env -u RUN_REAL_AGENT_EVAL -u REAL_LLM_COST_ACK \
  flutter test \
  test/app_llm_canonical_hash_test.dart \
  test/app_llm_prompt_invocation_test.dart \
  test/app_llm_prompt_release_test.dart \
  test/app_llm_prompt_release_store_test.dart \
  test/story_prompt_registry_test.dart \
  test/agent_adversarial_scenarios_test.dart \
  test/agent_evaluation_*_test.dart \
  test/real_agent_evaluation_release_matrix_test.dart

flutter analyze --no-pub
make docs-check
```

全量离线验证：

```bash
env -u RUN_REAL_AGENT_EVAL -u REAL_LLM_COST_ACK flutter test
```

旧的真实 provider **smoke** 入口可能产生费用，必须同时设置授权和成本确认；它仍只用于连通性/机械矩阵，不是正式 release 入口：

```bash
export NOVEL_BENCHMARK_API_KEY='<secret>'
export AGENT_EVAL_OUTPUT_DIR="$PWD/.artifacts/agent-eval/$(date +%Y%m%d-%H%M%S)"

RUN_REAL_AGENT_EVAL=1 \
REAL_LLM_COST_ACK=YES \
dart run tool/agent_evaluation_smoke_runner.dart
```

每个模型固定展开 `10 scenarios × 2 arms × 3 slots = 60 provider calls`。退出码 `0` 只表示 smoke matrix 获得非空响应并通过通用 runner 的独立性/Pass³ 机械聚合；`1` 表示执行/预算/期限或 cell 失败；`64` 表示缺少授权、成本确认或 provider 配置。报告即使内部 `releasePassed = true`，顶层也固定 `releaseEligible = false`。该入口不能证明小说质量、生产流水线正确性、两 arm 存在真实行为差异、性能非劣、发布晋升或 holdout confirmation。

| 环境变量 | 当前语义 |
|---|---|
| `RUN_REAL_AGENT_EVAL` | 必须精确为 `1` |
| `REAL_LLM_COST_ACK` | 必须精确为 `YES` |
| `NOVEL_BENCHMARK_API_KEY` | 推荐的 GLM API key 来源 |
| `NOVEL_BENCHMARK_BASE_URL` | 可选；未设置时使用 GLM provider 默认地址 |
| `AGENT_EVAL_REQUIRED_MODELS` | 逗号分隔；未设置时回退至单模型配置，最终默认 `glm-5.1` |
| `REAL_AI_TIMEOUT_MS` | 默认 `180000`，限制为 1000—600000 ms |
| `AGENT_EVAL_DEADLINE_MINUTES` | 默认 90 |
| `AGENT_EVAL_MAX_CALLS` | 默认 `60 × 模型数`；小于完整矩阵时 preflight 失败 |
| `AGENT_EVAL_MAX_TOKENS` | 默认 `60 × 模型数 × 1024` |
| `AGENT_EVAL_OUTPUT_DIR` | 建议显式设置；否则报告位于系统临时目录，不能算已归档证据 |

## 16. 发布与回滚

- 默认 champion 保持生产流量；challenger 只进入实验或小比例 canary。
- 晋升使用 `prompt_channel_heads(channel, bundleHash, epoch)`；事务内以 expected `fromBundle + epoch` CAS，成功后追加保存 `fromBundle/toBundle/fromEpoch/toEpoch/experimentId/scorecardHash/approver/time`。
- 发现 hard-gate、隐私、事务或 Pass³ 回归时自动停止 challenger，不等待平均分计算完成。
- Prompt 回滚不回滚已提交正文；只影响新 run。
- Schema 与 registry migration 必须支持读取历史 release 和 audit trajectory。每个 schema release 声明 `minReaderVersion/minWriterVersion`、upgrade 顺序和 rollback 路径。默认不承诺物理 schema downgrade；N-1 binary 不满足 reader 或 writer version 时禁止 binary rollback，只允许 generation bundle rollback，或在停止写入并验证数据导出后执行已验证 backup restore。

## 17. 未决风险

- LLM quality scorer 本身有波动，必须使用独立冻结 evaluator、校准集、blinding 和确定性指标辅助，不能循环自证。
- Pass³ 和多模型矩阵成本较高，需要 dev/regression/release/holdout 分层，但 release set 不得降为单次试验，holdout 不得反复调参。
- 定向修订可能改变上下文长度与 token 分布，比较报告必须区分质量收益和成本转移。
- SQLite 聚合和长期 trajectory 保留会增加数据库体积，需要 TTL/加密归档；永久保留 manifest、release、scorecard hash、签名/外部 root 与最小 audit 证据，并准确降级 replay 能力声明。
- 当前工作区包含大量并行改动，实施时必须按数据 schema、trace、evaluator、scenario 四个写域分阶段合并并做全量验证。

## 18. 完成定义

本项目只有在“能力技巧已进入正常生产路径、对抗题可机械验证、版本效果可复算、性能有 SLO、真实 provider 通过 Pass³、发布可晋升与回滚”同时成立时，才能宣称已把相关 Agent 工程技巧真实落地。

单独存在 prompt 常量、trace 字段、一次成功 canary、人工评分或文档描述都不构成完成证据。

## 19. 对抗性复核记录

本节记录对本 Spec 本身的攻击，不是产品测试通过记录。2026-07-14 复核后的主要结论如下：

| 攻击方式 | Spec 的阻断规则 | 当前剩余证据缺口 |
|---|---|---|
| 让被测 scorer 固定返回高分 | generation/evaluation bundle 隔离；deterministic verifier 先行；冻结、blinded 外部 evaluator | production executor、独立 judge/safety 和 prompt-injection 负测已接入；仍缺正式 KMS 条件下的真实 GLM matrix 归档 |
| 只报告一次幸运成功或无限补跑 | 三个独立 slot 全过；transport attempt 上限；所有失败进入分母 | 尚无真实 release matrix 归档报告 |
| 删除不利 arm、重复有利 cell | provider 前封存 canonical cross-product；缺失/重复/新增 cell fail closed | canonical matrix 与 provider 前拒绝已有 production-path 集成证据；仍需正式 KMS 条件下的真实 provider release 归档 |
| 跨 trial cache 或前一 trial 污染后一 trial | 独立 fixture clone；formal cache key 完整绑定 execution/slot/run/stage/bundle/route/decoding/output-schema/prompt/parser/input；foreign provenance 仍按 `nonIndependent` 拒绝 | 相同输入跨 slot 的真实 provider dispatch 与 foreign cache provenance 负向测试已补；50/50 integration-production-path 对抗场景已完整通过，但这不是付费真实 provider 证据 |
| 过期 worker 迟到写入或 accept | lease epoch/owner 作为所有副作用 fencing token；seal 同事务校验 | observation/checkpoint/candidate/accept/隔离写入与四阶段恢复已有统一 production-path 集成验证；仍缺真实 provider 长作业的部署级恢复实跑 |
| 用 trace name、伪造 ref、空 bundle 或仅改 ID/版本冒充 prompt 身份 | 注册 release + invocation evidence + system/user anchor + rendered/variables digest；严格 preflight 展开 executable prompt projection 并拒绝相同行为 arm | 全 `lib/` call-site inventory、完整变量级 renderer 重放、run/candidate rebind/spoof 和标签型 challenger 拒绝均已通过；剩余仅为真实 provider 版本效果数据 |
| 把 provider 非空响应包装成“release 通过” | smoke/release 两级 scope；smoke 强制 `releaseEligible = false`；消费者 fail closed | report consumer、seal 和负向测试已补；尚无满足外部 KMS/signing/预算条件的合格 real-provider-release 报告 |
| 多个 challenger 反复探测 holdout | experiment-family token、访问前消费预算/alpha、唯一 authority-derived regression winner、独立固定 evaluator runner、非诊断性结果 | 两个 promoted challenger 时 caller 选优、caller-supplied pass、未消费 access 和第二次 probe 已拒绝；部署 KMS runner 的真实 confirmation 实跑仍缺失 |
| 用任意同实验 scorecard 晋升无关 challenger | 双臂必须在同一 experiment；未验证 `promote()` 禁用；`promoteVerified()` 绑定 DB-derived regression verdict、holdout confirmation 与 expected head | sealed canonical pair/统计已由 V18 重算；仍需要签名或外部授权根应对 DB-root 写攻击者 |
| 修改 scorecard/报告或泄漏密钥 | sealed exact input-set hash、append-only evidence、allowlist/脱敏；高威胁模型使用 HMAC/外部 root | 尚无外部签名 root；真实报告仅能声称普通 hash 完整性 |
| 直接伪造 scorecard aggregate 或 `promote` verdict | V18 authority 忽略 aggregate，重算 status/reasons/质量/LCB/p95/cost；公共 caller-supplied verdict API 被禁用，晋升要求 append-only derivation | API 绕过和缺失 derivation 已有负向测试；DB-root 威胁仍需外部签名/KMS，真实 provider 报告仍缺失 |
| 用平均质量掩盖尾部或性能回退 | mean/p10/min/LCB、多维 multiplicity、p95/cost/reliability 门与最小样本量 | 尚无满足至少 20 个有效配对的真实数据 |
| episode 在 step 间重启 | `episodeTrialId` 副本必须持久化并由新 worker 恢复，不能重新 clone fixture | V26 四阶段 snapshot chain、全新 authority/Runner/sandbox 实例、terminal generation 清理与孤儿 epoch 隔离已有跨进程测试；真实 provider 长作业恢复仍待外部条件具备后实跑 |
| 旧 binary 写坏新 schema 后再声称可回滚 | `minReaderVersion/minWriterVersion`、写入 fencing、bundle rollback/backup restore | V25 writer 拒绝 V26、V25→V26 注入失败回滚、WAL 一致性快照与 canonical authority audit root restore 已演练；发布环境的实际旧二进制回滚仍属部署验证 |
| Unicode 等价字符串产生不一致 release hash | 规范要求完整 UTF-8/NFC + canonical JSON golden vectors，算法更换必须新 contract | `canonical-json-v2-unicode-17.0.0` 已通过官方完整 NormalizationTest；旧受限 v1 仅保留显式 legacy reader，不再宣称通用 NFC |

复核判定：仓库内实现与 integration 证据已补齐到本次目标范围，仍不能把它说成真实 provider 发布通过。正式 KMS/trust/signing、明确完整预算、真实 public/private matrix 与 holdout 报告均保持 `not-evaluated` 外部条件；在这些条件具备前，项目不是 release-ready，任何本地 smoke、test double 或 ad-hoc 构建都不得改写该结论。
