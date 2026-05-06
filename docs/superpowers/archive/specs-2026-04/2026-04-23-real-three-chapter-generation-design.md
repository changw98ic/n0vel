# 真实三章小说生成与动态多 Agent 编排设计

## 1. 目标

在当前应用内建立一条可真实运行、可落盘、可导出导入、可人工复查的小说生产链路，覆盖：

- 世界观创建
- 角色构建
- 三章大纲规划
- 按场景分段的动态多 Agent 编排
- 正文生成
- 一致性 / 逻辑 / 文风 / 违禁词审查
- 设定变更后的失效传播与重新编排

本设计的最终目标不是“再做一次 smoke”，而是让系统能够真实跑出三章小说，每章约 `2000` 字，并留下完整可见产物。

## 2. 范围

### In scope

- 真实调用云端 Ollama `/v1`
- 真实使用本地 `setting.json` 配置
- 真实使用现有 store、sqlite、导出导入、日志系统
- 动态角色 agent 编排
- 场景级正文生成与审查
- 章节级聚合与导出导入验证
- 设定变更后的失效传播

### Out of scope

- 通用训练或长期记忆系统
- 自动发布到远端服务
- 图片、封面、插图生成
- 通用故事编辑器重构

## 3. 当前事实与约束

### 3.1 当前已有的真实能力

仓库已经具备以下真实能力：

- 设置保存、连接测试、真实 AI 请求
  - `AppSettingsStore.saveWithFeedback()`
  - `AppSettingsStore.testConnection()`
  - `AppSettingsStore.requestAiCompletion()`
- 项目 / 场景 / 角色 / 世界节点真实存储
  - `AppWorkspaceStore`
- 正文 / AI history / 版本 / scene context 真实存储
  - `AppDraftStore`
  - `AppAiHistoryStore`
  - `AppVersionStore`
  - `AppSceneContextStore`
- 真实导出 / 导入
  - `ProjectTransferService`
- 本地结构化日志
  - `AppEventLog`

### 3.2 当前缺口

当前 `AppSimulationStore` 不是“真实多 Agent 编排引擎”，而是模板驱动的本地状态推进：

- `startSuccessfulRun()` 只是切换模板并通过 timer 推进
- `startFailureRun()` 只是切换失败模板

因此它不能被视为本设计要求的“真实多 Agent 场景模拟”能力，只能保留为旧的演示 / UI 状态模块。

### 3.3 用户明确约束

- 固定 agent 只有 `director` 和 `judge`
- 其他 agent 不能预设角色槽位
- 动态 agent 必须来自当前章节大纲中该场景“有行动 / 对话 / 交互”的角色
- 背景板角色不进入 agent 编排
- 每章按场景分段执行，不整章一次性跑完
- prose 必须由独立正文生成步骤完成，而不是由 `director` 直接收口
- prose 生成完成后，必须执行完整的：
  - 一致性审查
  - 逻辑审查
  - 文风审查
  - 违禁词 / 规则审查
- 如果设定变动，则所有关联正文都必须失效并重新走编排流程

## 4. 方案选项

### 方案 A：扩展现有 Simulation 模板

思路：
在现有 `AppSimulationStore` 上堆更多状态，让它看起来像真实多 agent。

优点：

- 改动表面上最小

缺点：

- 核心模型错误
- 当前模块并不以真实 LLM 编排为边界
- 继续扩展会把模板状态机和真实编排混在一起
- 很难保证真实验证的可追溯性

结论：

- 不采用

### 方案 B：固定角色槽位编排

思路：
写死 `director + protagonist + antagonist + judge` 这种固定 agent 集合。

优点：

- 实现更简单
- prompt 模板容易写

缺点：

- 与用户要求冲突
- 不适用于章节里动态变化的角色组合
- 会在多角色场景里产生错误抽象

结论：

- 不采用

### 方案 C：大纲驱动的动态多 Agent 编排

思路：
固定 `director` 和 `judge`，其他 agent 由当前场景大纲动态解析，按场景运行真实 LLM 编排。

优点：

- 与用户要求完全一致
- 更贴合小说生产流程
- 可直接复用现有 store / log / import-export 底座
- 最适合做真实三章验证

缺点：

- 需要新增编排层和失效传播层
- 状态机和产物结构要明确设计

结论：

- 采用此方案

## 5. 核心设计

### 5.1 总体架构

新增一条上层“小说生产流水线”，不替换现有底层存储和 AI 客户端：

1. 基础设定层
   - 世界观
   - 角色
   - 三章大纲
2. 场景编排层
   - `director`
   - 动态角色 agent
3. 正文生成层
   - prose 生成
4. 审查层
   - `judge`
   - consistency review
5. 失效传播层
   - invalidation engine
6. 产物与验证层
   - sqlite / logs / 导出导入 / 报告

### 5.2 固定与动态 Agent

固定 agent：

- `director`
  - 负责场景编排
  - 负责任务发放
  - 负责行为指导
- `judge`
  - 负责文风检查
  - 负责违禁词检查
  - 负责规则检查

动态 agent：

- 不预设角色类型
- 每个场景从该场景大纲里抽取“有行动 / 对话 / 交互”的角色
- 这些角色各自成为一个 agent 身份

判定规则：

- 只有背景存在感，没有行动 / 对话 / 交互：不进入 agent
- 有任意行动 / 对话 / 交互：必须进入 agent

### 5.3 场景级执行流

每章按场景执行，每个场景固定跑以下流程：

1. `director` 读取：
   - 世界观
   - 角色设定
   - 该场景大纲
   - 前文摘要
2. `director` 输出场景任务卡
3. 动态角色 agent 按任务卡逐个响应
4. 独立 prose 生成步骤把以上结果转成场景正文草稿
5. `judge` 执行文风 / 禁词 / 规则检查
6. `consistency review` 执行一致性 / 逻辑 / 连续性检查
7. 根据审查结果：
   - 轻问题：重跑 prose
   - 结构问题：回退 `director`，重跑整段场景链路

### 5.4 正文生成职责边界

正文生成不能由 `director` 兼任。

理由：

- `director` 的职责是编排和约束，不是最终 prose 落笔
- prose 生成需要单独优化文风、节奏和叙述流
- 将两者拆开，才能更清晰地区分“编排问题”和“表达问题”

因此 prose 生成必须作为独立步骤存在。

### 5.5 审查职责边界

`judge` 只负责：

- 文风
- 禁词
- 规则
- 输出格式

`consistency review` 只负责：

- 与大纲一致
- 与世界观一致
- 角色行为逻辑一致
- 与前章前场景连续

这样审查失败时可以明确决定是“重写 prose”还是“回退 director”。

## 6. 数据模型

### 6.1 可见运行目录

所有真实运行产物都落到仓库可见目录：

`artifacts/real_validation/three_chapter_run/`

推荐结构：

- `inputs/`
  - `world_bible.md`
  - `character_profiles.md`
  - `three_chapter_outline.md`
- `runtime/`
  - `settings.snapshot.json`
  - `authoring.db`
  - `simulation.db`
  - `telemetry.db`
  - `logs/*.jsonl`
- `chapters/`
  - `chapter-01.md`
  - `chapter-02.md`
  - `chapter-03.md`
- `reviews/`
  - 场景级 `judge` / `consistency` 记录
- `exports/`
  - 导出包
- `imports/`
  - 导入后的第二套可见数据
- `reports/`
  - `run-report.md`
  - `artifact-index.md`

### 6.2 场景运行记录

每个场景都需要保留一份结构化运行记录，至少包含：

- `chapter_id`
- `scene_id`
- `scene_outline`
- `cast`
- `director_brief`
- `character_turns`
- `prose_draft`
- `judge_review`
- `consistency_review`
- `final_scene_text`
- `prose_retry_count`
- `director_retry_count`
- `status`
- `upstream_fingerprint`

关键要求：

- `cast` 只包含动态 agent
- `character_turns` 必须保留真实原始输出
- `prose_draft` 和 `final_scene_text` 分开保存
- 两类审查结果分开保存

### 6.3 章节摘要记录

每章最终还要保留章节级摘要：

- `chapter_id`
- `target_length`
- `actual_length`
- `scene_count`
- `participating_roles`
- `world_nodes_used`
- `history_entries_added`
- `version_snapshot_created`
- `review_passed`
- `final_status`

## 7. 状态机

### 7.1 场景状态

场景主状态：

- `pending`
- `directing`
- `role_running`
- `drafting`
- `reviewing`
- `passed`
- `invalidated`
- `blocked`

附加状态：

- `judge_status = pending | passed | failed`
- `consistency_status = pending | passed | soft_failed | hard_failed`

处理规则：

- `judge failed` -> 重跑 prose
- `consistency soft_failed` -> 重跑 prose
- `consistency hard_failed` -> 回退 director
- prose 重写超过 `2` 次 -> `blocked`
- director 回退超过 `2` 次 -> `blocked`

### 7.2 章节状态

章节状态：

- `pending`
- `in_progress`
- `reviewing`
- `passed`
- `invalidated`
- `blocked`

聚合规则：

- 任一场景运行中 -> `in_progress`
- 全场景 prose 产出后进入章节总审 -> `reviewing`
- 全场景 `passed` 且字数达标 -> `passed`
- 任一已通过场景因上游变更失效 -> `invalidated`
- 任一关键场景 `blocked` -> `blocked`

## 8. 失效传播

### 8.1 基本规则

任何实质性设定变更都视为上游事实变更。

一旦上游事实变更：

- 所有关联场景从 `passed` 变为 `invalidated`
- 所有关联章节从 `passed` 变为 `invalidated`
- 旧 prose 保留，但不再视为当前有效版本
- 必须重新走编排流程

### 8.2 传播范围

#### 世界观变更

- 找出引用该世界规则 / 世界节点的场景
- 这些场景 `invalidated`

#### 角色设定变更

- 找出该角色在其中有行动 / 对话 / 交互的场景
- 这些场景 `invalidated`

#### 大纲变更

- 对应章节全部场景 `invalidated`

#### 全局文风规则变更

- 默认所有章节 `invalidated`

## 9. 持久化与复用边界

### 9.1 直接复用

- `AppSettingsStore`
- `AppWorkspaceStore`
- `AppDraftStore`
- `AppAiHistoryStore`
- `AppVersionStore`
- `AppSceneContextStore`
- `ProjectTransferService`
- `AppEventLog`

### 9.2 必须新增

- `StoryOutlineStore` 或等价大纲模块
- `SceneCastResolver`
- `SceneDirectorOrchestrator`
- `DynamicRoleAgentRunner`
- `SceneProseGenerator`
- `SceneReviewCoordinator`
- `InvalidationEngine`
- `ArtifactRecorder`

### 9.3 明确不复用

- 不把 `AppSimulationStore` 当作真实多 Agent 引擎继续扩展

## 10. 三章真实验证执行顺序

1. 建立小说 brief
2. 生成世界观并冻结
3. 生成角色设定并冻结
4. 生成三章大纲，拆到场景级
5. 逐章、逐场景运行真实编排
6. 每章完成后做章节级连续性更新
7. 三章完成后做整体验收
8. 导出 source 项目
9. 导入到 target 目录
10. 生成最终报告

## 11. 验收标准

- 真实 provider 连接成功
- 真实生成 3 章正文
- 每章正文长度 `1800-2200` 汉字
- 每章按场景运行动态多 agent
- 每场景都有：
  - director 输出
  - 动态角色输出
  - prose 草稿
  - judge review
  - consistency review
- 三章都写入真实 draft
- 三章都生成 version snapshot
- 三章都留下 AI history
- 三章都能在 store 重建后恢复
- 导出包成功生成
- 导入到第二套可见目录后数据正确恢复

## 12. 风险

- 真实多 agent 编排会显著增加 token 消耗
- 每章 2000 字级别生成可能出现长度波动
- 一旦 invalidation 规则过宽，重跑成本会明显上升
- 如果角色 / 世界观引用关系记录不清，失效传播可能不准

## 13. 设计决策摘要

### Decision

采用“大纲驱动的动态多 Agent 编排”。

### Why

- 满足用户对动态角色的要求
- 满足按场景分段的执行方式
- 满足设定变更后正文失效重编排的约束
- 最大化复用现有真实模块

### Consequences

- 需要新增上层编排和失效传播模块
- 不能继续把当前 simulation 模板当作真实编排
- 真实三章验证会成为一条较重但可信的生产链路
