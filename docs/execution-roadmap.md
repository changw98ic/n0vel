# novel-writer 长期执行计划

> 版本: 1.0
> 创建日期: 2026-05-24
> 负责人: 实现者 (implementation), 审阅者 (review)
> 跟踪 issue: #23

> **范围说明**: 本文档是 n0vel 长期执行的工程技术计划，随 PR #29（promotion milestone）一同提交，作为推广路线图的支撑性运营上下文，而非面向终端用户的营销文档。后续如维护者认为执行计划应独立管理，可拆分到单独 PR。本文档定位始终是：给长篇小说作者用的本地优先 AI 创作工作台的内部工程规划。

## 执行协议

### 角色分工
- **实现者（Implementer）**：负责代码实现、测试、commit
- **审阅者（Reviewer）**：负责审阅、验证、CI 状态检查、回退建议，**不直接实现代码**

### 提交信息格式（Lore Commit Protocol）

```
<type>: <why-first intent line>

<optional detailed bullet points>

Related: <issue-number-or-context>
Confidence: <high|medium|low>
Scope-risk: <risk-assessment>
Tested: <what-was-tested>
Not-tested: <what-not-tested>
Co-Authored-By: [contributor name]
```

### CI 检查要求
- 每次 push 后必须检查 CI 状态
- CI 失败必须修复后才能继续下一个里程碑

### 回滚策略
- 每个里程碑完成后打 tag
- 如需回滚：`git revert <milestone-commit-range>`
- 如已合并：创建 revert PR 或手动 revert

## Milestone 概览

| ID | 名称 | 依赖 | 预估周期 | 风险等级 |
|----|------|------|----------|----------|
| M0 | Roadmap/Backlog Operationalization | 无 | 1 天 | 低 |
| M1 | Daily Writing Studio | M0 | 5 天 | 中 |
| M2 | Pipeline Runtime Hardening | M0 | 4 天 | 中 |
| M3 | Open Storage | M0 | 3 天 | 中 |
| M4 | Provider/State Convergence | M1, M2 | 6 天 | 高 |
| M5 | Safety and LLM Ops | M2 | 4 天 | 中 |
| M6 | Bible/Production UX | M1, M3 | 5 天 | 中 |
| M7 | Git/Local API | M3, M4 | 6 天 | 高 |
| M8 | Ecosystem and Collaboration | M4, M6 | 8 天 | 高 |

## M0: Roadmap/Backlog Operationalization

### 目标
建立长期执行计划框架，使后续贡献者可按 task ID 接力执行。

### 验收标准
- [ ] `docs/execution-roadmap.md` 存在且包含 M0-M8 所有任务
- [ ] 每个任务粒度 <= 1 人天
- [ ] 每个里程碑包含依赖、验收标准、风险、回滚策略
- [ ] 提交信息符合 Lore Commit Protocol
- [ ] 已推送到远端分支
- [ ] 已检查 CI 状态
- [ ] 已生成 deliverable 并提交审阅

### 风险
- **gh CLI 未认证**：无法创建 GitHub issue，需在 deliverable 中说明
- **CI 配置变更**：如 CI 检查失败需记录原因

### 回滚策略
- 删除新增的 docs 文件：`rm docs/execution-roadmap.md docs/milestone-0-protocol.md`
- 安全回滚：`git revert HEAD --no-edit` 或删除文件后正常 commit

### 任务列表（M0 仅一个任务）

#### TASK-M0-01: 创建长期执行计划框架
- **目标**: 创建 docs/execution-roadmap.md 和 docs/milestone-0-protocol.md
- **预计耗时**: 4人时
- **范围**:
  - 创建 `docs/execution-roadmap.md`，包含 M0-M8 完整任务拆分
  - 创建 `docs/milestone-0-protocol.md`，定义执行协议
- **相关模块**: docs/
- **Out-of-Scope**: 不修改 `lib/` 代码，不引入新依赖
- **验收标准**:
  - [ ] 两个文档文件存在且内容完整
  - [ ] 每个任务包含完整元数据（ID、标题、目标、范围、验收标准等）
  - [ ] 提交并推送成功
- **测试/CI 命令**: `git status`, `git log -1`
- **前置依赖**: 无
- **GitHub Issue/PR 要求**: 创建 issue "M0: 建立长期执行计划框架"

## M1: Daily Writing Studio

### 目标
将 Workbench 改造为三栏工作台，实现 AI 候选稿对比和逐段采纳，建立 Run Center 作为工作流状态中心。

### 验收标准
- [ ] Workbench 三栏布局实现（编辑区 / AI 候选区 / 摘要区）
- [ ] AI 候选稿可展示多个版本，支持逐段采纳
- [ ] Run Center 展示所有运行状态，支持恢复和重跑
- [ ] 场景切换守卫：防止未保存切换

### 依赖
- M0 完成

### 风险
- **UI 复杂度**：三栏布局在不同屏幕尺寸下的适配
- **状态同步**：候选稿与正文的状态一致性

### 回滚策略
- Revert PR：`git revert <merge-commit>`
- 如已发布：hotfix 回滚三栏布局，恢复单页模式

### 任务列表（M1，共 5 个任务）

#### TASK-M1-01: Workbench 三栏壳层基础
- **目标**: 实现 Workbench 三栏布局框架
- **预计耗时**: 6人时
- **范围**:
  - 修改 `lib/features/workbench/presentation/workbench_shell_page.dart`
  - 新增三栏布局组件，定义区域划分
- **相关模块**: workbench shell
- **Out-of-Scope**: 暂不处理响应式适配，先固定桌面尺寸
- **验收标准**:
  - [ ] 三栏布局可见：左（编辑区）/ 中（AI 候选区）/ 右（摘要区）
  - [ ] 区域宽度可拖拽调整
  - [ ] `flutter test` 通过
- **测试/CI 命令**: `flutter test lib/features/workbench/presentation/`
- **前置依赖**: M0
- **GitHub Issue/PR 要求**: Issue 标题 "[M1] Workbench 三栏壳层基础"

#### TASK-M1-02: Project Home/Shelf/Studio/Bible/Production IA
- **目标**: 设计并实现项目级导航入口
- **预计耗时**: 6人时
- **范围**:
  - 新增 `ProjectHomePage` 作为项目 Home
  - 集成 Shelf（项目切换）、Studio（工作台入口）、Bible（资料中心）、Production（进度仪表盘）
- **相关模块**: projects, workbench
- **Out-of-Scope**: 不实现 Production 仪表盘细节，仅占位
- **验收标准**:
  - [ ] 从 ProjectList 可进入 ProjectHome
  - [ ] ProjectHome 四个入口可导航
  - [ ] 路由正确配置
- **测试/CI 命令**: `flutter test lib/features/projects/`
- **前置依赖**: M1-01
- **GitHub Issue/PR 要求**: Issue 标题 "[M1] 项目级导航入口"

#### TASK-M1-03: 新建项目向导
- **目标**: 实现新建项目的引导式向导
- **预计耗时**: 6人时
- **范围**:
  - 新增 `ProjectWizardPage`
  - 收集：项目名称、类型、初始角色/世界观
- **相关模块**: projects
- **Out-of-Scope**: 不包含模板选择（M8）
- **验收标准**:
  - [ ] 向导可完成项目创建
  - [ ] 创建后自动进入 Workbench
  - [ ] 必填字段验证
- **测试/CI 命令**: `flutter test lib/features/projects/presentation/project_wizard*`
- **前置依赖**: M1-02
- **GitHub Issue/PR 要求**: Issue 标题 "[M1] 新建项目向导"

#### TASK-M1-04: AI 候选逐段采纳
- **目标**: 实现 AI 候选稿的逐段采纳 UI 和逻辑
- **预计耗时**: 7人时
- **范围**:
  - 修改 `lib/features/workbench/presentation/workbench_ai_controller.dart`
  - 新增候选稿对比组件，支持逐段采纳
- **相关模块**: workbench AI controller, editor pane
- **Out-of-Scope**: 暂不实现批量采纳
- **验收标准**:
  - [ ] 候选稿可按段落展示
  - [ ] 每段可单独采纳/拒绝
  - [ ] 采纳后正文更新
- **测试/CI 命令**: `flutter test lib/features/workbench/presentation/workbench_ai_controller.dart`
- **前置依赖**: M1-01
- **GitHub Issue/PR 要求**: Issue 标题 "[M1] AI 候选逐段采纳"

#### TASK-M1-05: Run Center/场景切换守卫
- **目标**: 建立 Run Center 作为工作流状态中心，实现场景切换守卫
- **预计耗时**: 7人时
- **范围**:
  - 新增 `RunCenterPage`
  - 实现场景切换前的保存检查
- **相关模块**: workbench, scenes, story generation run store
- **Out-of-Scope**: 暂不实现跨场景运行恢复
- **验收标准**:
  - [ ] RunCenter 展示所有运行状态（进行中/已完成/失败）
  - [ ] 可从 RunCenter 恢复失败运行
  - [ ] 场景切换时检查未保存更改
- **测试/CI 命令**: `flutter test lib/features/workbench/presentation/run_center*`
- **前置依赖**: M1-04
- **GitHub Issue/PR 要求**: Issue 标题 "[M1] Run Center 与场景切换守卫"

---

## M2: Pipeline Runtime Hardening

### 目标
抽取 PipelineDefinition 和 preset，实现重试/恢复机制，增强可观测性，建立 golden harness。

### 验收标准
- [ ] PipelineDefinition 与实现分离
- [ ] LLM 请求支持自动重试
- [ ] 运行失败可恢复
- [ ] Pipeline 状态面板可观察
- [ ] Golden harness 测试覆盖

### 依赖
- M0 完成

### 风险
- **Pipeline 解耦复杂度**：现有 `PipelineStageRunnerImpl` 强耦合
- **状态恢复一致性**：恢复时状态重建的正确性

### 回滚策略
- Feature flag 控制 PipelineDefinition 切换
- Golden harness 失败不阻塞主流程

### 任务列表（M2，共 4 个任务）

#### TASK-M2-01: PipelineDefinition/preset 抽取
- **目标**: 将 pipeline 定义从实现中抽取为独立数据结构
- **预计耗时**: 6人时
- **范围**:
  - 新增 `lib/features/story_generation/data/pipeline_definition.dart`
  - 定义 preset 结构
- **相关模块**: story generation, pipeline stage runner
- **Out-of-Scope**: 暂不实现用户自定义 pipeline
- **验收标准**:
  - [ ] `PipelineDefinition` 类定义清晰
  - [ ] 内置 preset 可加载
  - [ ] 现有九阶段 pipeline 可通过定义重建
- **测试/CI 命令**: `flutter test lib/features/story_generation/data/pipeline_definition.dart`
- **前置依赖**: M0
- **GitHub Issue/PR 要求**: Issue 标题 "[M2] PipelineDefinition 抽取"

#### TASK-M2-02: LLM retry/request pool 策略
- **目标**: 实现 LLM 请求的自动重试和连接池
- **预计耗时**: 6人时
- **范围**:
  - 修改 `lib/app/llm/app_llm_client.dart`
  - 新增 retry policy 和 request pool
- **相关模块**: LLM client
- **Out-of-Scope**: 暂不实现跨模型重试
- **验收标准**:
  - [ ] 可配置重试次数和退避策略
  - [ ] 请求池限制并发数
  - [ ] 重试日志可观察
- **测试/CI 命令**: `flutter test lib/app/llm/`
- **前置依赖**: M2-01
- **GitHub Issue/PR 要求**: Issue 标题 "[M2] LLM 重试和请求池"

#### TASK-M2-03: Pipeline 重试/恢复/状态面板
- **目标**: 增强 pipeline 运行时的可观测性和恢复能力
- **预计耗时**: 7人时
- **范围**:
  - 修改 `lib/features/story_generation/data/pipeline_stage_runner_impl.dart`
  - 新增状态面板组件
- **相关模块**: pipeline stage runner, story generation run store
- **Out-of-Scope**: 暂不实现跨会话恢复
- **验收标准**:
  - [ ] 失败阶段可自动重试
  - [ ] 运行状态实时展示
  - [ ] 可从断点恢复
- **测试/CI 命令**: `flutter test lib/features/story_generation/data/`
- **前置依赖**: M2-02
- **GitHub Issue/PR 要求**: Issue 标题 "[M2] Pipeline 可观测性"

#### TASK-M2-04: Pipeline golden harness
- **目标**: 建立 pipeline 的 golden 测试工具集
- **预计耗时**: 5人时
- **范围**:
  - 新增 `test/golden/pipeline_golden_harness.dart`
  - 定义 golden 输入/输出规范
- **相关模块**: story generation
- **Out-of-Scope**: 暂不覆盖所有 pipeline 变体
- **验收标准**:
  - [ ] 至少 3 个 golden 测试用例
  - [ ] Golden 文件版本化
  - [ ] `flutter test` 更新 golden 命令文档化
- **测试/CI 命令**: `flutter test --update-goldens test/golden/`
- **前置依赖**: M2-03
- **GitHub Issue/PR 要求**: Issue 标题 "[M2] Pipeline golden harness"

---

## M3: Open Storage

### 目标
实现 Markdown mirror 导出，建立 pending overlay 机制，规划导入方案。

### 验收标准
- [ ] 项目可导出为 Markdown 格式
- [ ] Pending 编辑可 overlay 在导出之上
- [ ] 导入计划文档完成

### 依赖
- M0 完成

### 风险
- **双向一致性**：Markdown <-> SQLite 同步复杂度
- **冲突解决**：pending overlay 与源文件的冲突

### 回滚策略
- Markdown 导出为可选功能
- 导入失败不影响 SQLite 主数据

### 任务列表（M3，共 3 个任务）

#### TASK-M3-01: Markdown mirror 导出
- **目标**: 实现项目数据的 Markdown 格式导出
- **预计耗时**: 6人时
- **范围**:
  - 新增 `lib/features/import_export/data/markdown_exporter.dart`
  - 定义 Markdown 文件结构（章节、角色、世界观）
- **相关模块**: import_export, project stores
- **Out-of-Scope**: 暂不实现 Markdown 格式规范文档
- **验收标准**:
  - [ ] 可导出完整项目为 Markdown 文件树
  - [ ] 导出包含：章节、角色、世界观、场景
  - [ ] 导出后文件可读可编辑
- **测试/CI 命令**: `flutter test lib/features/import_export/data/`
- **前置依赖**: M0
- **GitHub Issue/PR 要求**: Issue 标题 "[M3] Markdown mirror 导出"

#### TASK-M3-02: Pending overlay 机制
- **目标**: 实现 SQLite 数据与 Markdown 导出之间的 pending 状态 overlay
- **预计耗时**: 6人时
- **范围**:
  - 新增 `lib/app/state/pending_overlay_store.dart`
  - 定义 pending 状态合并逻辑
- **相关模块**: app state, import_export
- **Out-of-Scope**: 暂不实现自动同步
- **验收标准**:
  - [ ] 可识别 SQLite 与 Markdown 的差异
  - [ ] Pending 状态可展示
  - [ ] 可选择保留哪一方
- **测试/CI 命令**: `flutter test lib/app/state/pending_overlay_store.dart`
- **前置依赖**: M3-01
- **GitHub Issue/PR 要求**: Issue 标题 "[M3] Pending overlay 机制"

#### TASK-M3-03: 导入方案设计文档
- **目标**: 设计 Markdown 导入的技术方案
- **预计耗时**: 3人时
- **范围**:
  - 新增 `docs/markdown-import-plan.md`
- **相关模块**: docs
- **Out-of-Scope**: 不实现导入功能（留待 M7）
- **验收标准**:
  - [ ] 文档包含：解析策略、冲突解决、边界情况
  - [ ] 文档包含与 pending overlay 的集成方案
  - [ ] 文档经过审阅
- **测试/CI 命令**: N/A（文档）
- **前置依赖**: M3-02
- **GitHub Issue/PR 要求**: Issue 标题 "[M3] 导入方案设计"

## Deferred Milestones (M4–M8)

The following milestones are planned but not yet in active development.
Full task detail will be restored when each milestone becomes active.

| ID | 名称 | 依赖 | 任务数 | 预估 | 风险 |
|----|------|------|--------|------|------|
| M4 | Provider/State Convergence — ServiceRegistry 迁移到 Riverpod，store 拆分，投影层 | M1, M2 | 6 | 6d | 高 |
| M5 | Safety and LLM Ops — 密钥 keychain 存储，敏感信息脱敏，重试/连接池，模型配置 | M2 | 4 | 4d | 中 |
| M6 | Bible/Production UX — 角色状态卡，伏笔追踪，质量仪表盘，Run dashboard | M1, M3 | 5 | 5d | 中 |
| M7 | Git/Local API — 双向 Markdown/Git 同步，本地 server，能力授权 | M3, M4 | 6 | 6d | 高 |
| M8 | Ecosystem and Collaboration — 插件系统，模板，lore graph，review package，模型路由 | M4, M6 | 8 | 8d | 高 |

Full task specifications are archived in git history at commit eb81bbf.

## 执行检查清单

### 每个任务完成后
- [ ] 代码修改完成
- [ ] 本地测试通过
- [ ] Commit 信息符合 Lore Commit Protocol
- [ ] Diff 可读且小

### 每个里程碑完成后
- [ ] 所有任务完成
- [ ] Push 到远端分支
- [ ] CI 检查通过
- [ ] 提交审阅
- [ ] 审阅通过
- [ ] 合并到主分支或创建 PR

### 遇到阻塞时
- [ ] 记录阻塞原因
- [ ] 创建 GitHub issue（如可能）
- [ ] 在 deliverable 中说明
- [ ] 寻求绕过方案或降级方案
