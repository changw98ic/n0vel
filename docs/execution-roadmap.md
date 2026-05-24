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

## M4: Provider/State Convergence

### 目标
ServiceRegistry 迁移到 Riverpod provider，store 拆分，建立投影层。

### 验收标准
- [ ] ServiceRegistry 完全迁移到 Riverpod
- [ ] Store 拆分为小粒度单元
- [ ] 投影层分离读写

### 依赖
- M1, M2 完成（Workbench 和 pipeline 改造后更容易收敛）

### 风险
- **迁移破坏性**：ServiceRegistry 与 Riverpod 并存期间的一致性
- **Store 拆分复杂度**：跨 store 事务的正确性

### 回滚策略
- Feature flag 控制新旧 provider 切换
- 每个阶段独立 tag

### 任务列表（M4，共 6 个任务）

#### TASK-M4-01: Riverpod 适配一期（ServiceRegistry 迁移准备）
- **目标**: 分析 ServiceRegistry 依赖，制定迁移计划
- **范围**:
  - 新增 `docs/riverpod-migration-plan.md`
  - 分析 `lib/app/di/` 下所有注册
- **相关模块**: DI, service registry
- **Out-of-Scope**: 不开始实际迁移
- **验收标准**:
  - [ ] 迁移计划包含：依赖图、迁移顺序、风险
  - [ ] 每个 service 的迁移策略明确
- **测试/CI 命令**: N/A（分析文档）
- **前置依赖**: M1, M2
- **GitHub Issue/PR 要求**: Issue 标题 "[M4] Riverpod 迁移计划"

#### TASK-M4-02: 核心服务 Riverpod 化
- **目标**: 迁移核心服务到 Riverpod provider
- **范围**:
  - 修改 `lib/app/di/core_registrations.dart`
  - 创建对应的 Riverpod providers
- **相关模块**: DI, core services
- **Out-of-Scope**: 暂不迁移 feature services
- **验收标准**:
  - [ ] AppEventBus, AppLlmClient 等 core services 使用 Riverpod
  - [ ] 双写验证通过（新旧系统并行）
  - [ ] 测试通过
- **测试/CI 命令**: `flutter test lib/app/di/ lib/app/llm/`
- **前置依赖**: M4-01
- **GitHub Issue/PR 要求**: Issue 标题 "[M4] 核心服务 Riverpod 化"

#### TASK-M4-03: Feature services Riverpod 化
- **目标**: 迁移 feature 层服务到 Riverpod
- **范围**:
  - 修改 `lib/app/di/feature_registrations.dart`
  - 创建对应的 Riverpod providers
- **相关模块**: DI, feature services
- **Out-of-Scope**: 暂保留 ServiceRegistry 作为兼容层
- **验收标准**:
  - [ ] 所有 feature services 使用 Riverpod
  - [ ] 移除 ServiceRegistry 依赖（保留兼容层）
  - [ ] 测试通过
- **测试/CI 命令**: `flutter test lib/app/di/`
- **前置依赖**: M4-02
- **GitHub Issue/PR 要求**: Issue 标题 "[M4] Feature 服务 Riverpod 化"

#### TASK-M4-04: Store 拆分与投影层设计
- **目标**: 设计 store 拆分方案和投影层架构
- **范围**:
  - 新增 `docs/store-refactor-design.md`
  - 定义投影层接口
- **相关模块**: app state
- **Out-of-Scope**: 不开始实现拆分
- **验收标准**:
  - [ ] 设计文档包含：拆分边界、投影层 API、迁移路径
  - [ ] 设计经过审阅
- **测试/CI 命令**: N/A（设计文档）
- **前置依赖**: M4-03
- **GitHub Issue/PR 要求**: Issue 标题 "[M4] Store 拆分设计"

#### TASK-M4-05: StoryGenerationRunStore 拆分
- **目标**: 拆分 `StoryGenerationRunStore` 为小粒度单元
- **范围**:
  - 修改 `lib/app/state/story_generation_run_store.dart`
  - 创建子 stores（RunMetadataStore, CandidateStore, PhaseStore）
- **相关模块**: story generation run store
- **Out-of-Scope**: 暂不拆分其他 stores
- **验收标准**:
  - [ ] RunStore 委托给子 stores
  - [ ] 子 stores 可独立测试
  - [ ] 现有功能不回归
- **测试/CI 命令**: `flutter test lib/app/state/story_generation_run_store.dart`
- **前置依赖**: M4-04
- **GitHub Issue/PR 要求**: Issue 标题 "[M4] RunStore 拆分"

#### TASK-M4-06: 投影层实现与验证
- **目标**: 实现投影层，验证读写分离
- **范围**:
  - 新增 `lib/app/state/projection/`
  - 实现投影层 providers
- **相关模块**: app state
- **Out-of-Scope**: 暂不迁移所有 stores
- **验收标准**:
  - [ ] 投影层 provider 提供只读视图
  - [ ] 写操作通过 command 模式
  - [ ] 测试覆盖投影层
- **测试/CI 命令**: `flutter test lib/app/state/projection/`
- **前置依赖**: M4-05
- **GitHub Issue/PR 要求**: Issue 标题 "[M4] 投影层实现"

---

## M5: Safety and LLM Ops

### 目标
密钥安全存储，敏感信息脱敏，请求重试策略增强，连接池优化，模型配置管理。

### 验收标准
- [ ] 密钥使用系统 keychain 存储
- [ ] 敏感信息在日志中脱敏
- [ ] LLM 请求支持指数退避重试
- [ ] 请求池限制并发和速率
- [ ] 模型配置可管理

### 依赖
- M2 完成（pipeline 基础稳定后）

### 风险
- **密钥存储平台差异**：macOS/Windows/Linux keychain API 不同
- **脱敏遗漏**：敏感信息泄漏到日志

### 回滚策略
- Keychain 存储失败可回退到文件存储（加密）
- 脱敏失败可紧急 hotfix

### 任务列表（M5，共 4 个任务）

#### TASK-M5-01: Secret 存储收口（keychain 集成）
- **目标**: 使用系统 keychain 存储密钥
- **范围**:
  - 修改 `lib/app/state/app_settings_storage_io_support.dart`
  - 集成平台 keychain API
- **相关模块**: app settings, security
- **Out-of-Scope**: 暂不支持第三方密钥管理
- **验收标准**:
  - [ ] 密钥存储到系统 keychain
  - [ ] 三个平台（macOS/Windows/Linux）支持
  - [ ] 迁移逻辑：旧密钥自动迁移到 keychain
- **测试/CI 命令**: `flutter test integration_test/security_keychain_test.dart`
- **前置依赖**: M2
- **GitHub Issue/PR 要求**: Issue 标题 "[M5] Keychain 密钥存储"

#### TASK-M5-02: 敏感信息脱敏
- **目标**: 日志和 UI 中的敏感信息自动脱敏
- **范围**:
  - 修改 `lib/app/llm/` 日志逻辑
  - 新增脱敏中间件
- **相关模块**: LLM client, telemetry
- **Out-of-Scope**: 暂不脱敏用户生成内容
- **验收标准**:
  - [ ] API key 在日志中显示为 `[REDACTED]`
  - [ ] 敏感 header 脱敏
  - [ ] 脱敏可配置
- **测试/CI 命令**: `flutter test lib/app/llm/redaction_test.dart`
- **前置依赖**: M5-01
- **GitHub Issue/PR 要求**: Issue 标题 "[M5] 敏感信息脱敏"

#### TASK-M5-03: 重试策略与请求池优化
- **目标**: 增强重试策略，优化请求池
- **范围**:
  - 修改 `lib/app/llm/app_llm_request_pool.dart`
  - 实现指数退避重试
- **相关模块**: LLM client, request pool
- **Out-of-Scope**: 暂不实现断路器
- **验收标准**:
  - [ ] 可配置重试策略（次数、退避系数）
  - [ ] 请求池限制并发数
  - [ ] 速率限制可配置
- **测试/CI 命令**: `flutter test lib/app/llm/app_llm_request_pool_test.dart`
- **前置依赖**: M5-02
- **GitHub Issue/PR 要求**: Issue 标题 "[M5] 重试与请求池优化"

#### TASK-M5-04: 模型配置管理
- **目标**: 实现模型配置的 CRUD 和测试连接
- **范围**:
  - 新增 `lib/app/state/model_profile_store.dart`
  - 实现 model profile 管理 UI
- **相关模块**: settings, LLM client
- **Out-of-Scope**: 暂不支持动态模型路由（M8）
- **验收标准**:
  - [ ] 可添加/编辑/删除模型配置
  - [ ] 可测试连接
  - [ ] 配置持久化
- **测试/CI 命令**: `flutter test lib/app/state/model_profile_store_test.dart`
- **前置依赖**: M5-03
- **GitHub Issue/PR 要求**: Issue 标题 "[M5] 模型配置管理"

---

## M6: Bible/Production UX

### 目标
角色状态卡、伏笔追踪、质量仪表盘、Run dashboard。

### 验收标准
- [ ] 角色状态卡展示当前状态和变化
- [ ] 伏笔追踪管理器
- [ ] Production 仪表盘展示项目进度
- [ ] Run dashboard 展示运行历史

### 依赖
- M1（Workbench 改造后）, M3（导出后）

### 风险
- **角色状态同步**：状态卡与实际运行的一致性
- **伏笔检测复杂度**：自动化伏笔追踪的准确性

### 回滚策略
- Bible 功能为独立模块，可单独禁用
- Production 仪表盘不影响核心写作流程

### 任务列表（M6，共 5 个任务）

#### TASK-M6-01: Bible 角色状态卡
- **目标**: 实现角色状态卡 UI
- **范围**:
  - 新增 `lib/features/characters/presentation/character_state_card.dart`
  - 集成到 Workbench 侧栏
- **相关模块**: characters, workbench
- **Out-of-Scope**: 暂不实现自动状态推导
- **验收标准**:
  - [ ] 状态卡展示：角色名、当前状态、最近变化
  - [ ] 可手动更新状态
  - [ ] 状态历史可查看
- **测试/CI 命令**: `flutter test lib/features/characters/presentation/`
- **前置依赖**: M1, M3
- **GitHub Issue/PR 要求**: Issue 标题 "[M6] 角色状态卡"

#### TASK-M6-02: 伏笔追踪管理器
- **目标**: 实现伏笔的创建、追踪、提醒
- **范围**:
  - 新增 `lib/features/bible/data/foreshadowing_store.dart`
  - 新增伏笔管理 UI
- **相关模块**: bible（新建）
- **Out-of-Scope**: 暂不实现自动伏笔检测
- **验收标准**:
  - [ ] 可创建伏笔（名称、描述、关联章节）
  - [ ] 可标记伏笔状态（未展开/已展开/已废弃）
  - [ ] 相关章节提醒
- **测试/CI 命令**: `flutter test lib/features/bible/`
- **前置依赖**: M6-01
- **GitHub Issue/PR 要求**: Issue 标题 "[M6] 伏笔追踪管理器"

#### TASK-M6-03: Production 仪表盘
- **目标**: 实现项目进度仪表盘
- **范围**:
  - 修改 `lib/features/production_board/presentation/production_board_page.dart`
  - 展示项目统计和进度
- **相关模块**: production board
- **Out-of-Scope**: 暂不实现预测功能
- **验收标准**:
  - [ ] 展示：总字数、章节数、完成度
  - [ ] 展示：每日字数趋势
  - [ ] 可点击章节跳转
- **测试/CI 命令**: `flutter test lib/features/production_board/`
- **前置依赖**: M6-02
- **GitHub Issue/PR 要求**: Issue 标题 "[M6] Production 仪表盘"

#### TASK-M6-04: Quality/run dashboard
- **目标**: 实现 pipeline 运行质量仪表盘
- **范围**:
  - 新增 `lib/features/audit/presentation/run_quality_dashboard.dart`
  - 展示运行历史和质量指标
- **相关模块**: audit, story generation
- **Out-of-Scope**: 暂不实现异常检测
- **验收标准**:
  - [ ] 展示运行历史（成功/失败/平均时长）
  - [ ] 展示模型使用统计
  - [ ] 可筛选和导出
- **测试/CI 命令**: `flutter test lib/features/audit/presentation/`
- **前置依赖**: M6-03
- **GitHub Issue/PR 要求**: Issue 标题 "[M6] Run 质量 dashboard"

#### TASK-M6-05: Bible 与 Production 集成
- **目标**: 将 Bible 和 Production 功能集成到主工作流
- **范围**:
  - 修改路由配置
  - 集成到 ProjectHome
- **相关模块**: routes, project home
- **Out-of-Scope**: 无
- **验收标准**:
  - [ ] 从 Workbench 可快速进入 Bible
  - [ ] Production 仪表盘可从 ProjectHome 进入
  - [ ] 导航流畅
- **测试/CI 命令**: `flutter test integration_test/bible_production_navigation_test.dart`
- **前置依赖**: M6-04
- **GitHub Issue/PR 要求**: Issue 标题 "[M6] Bible/Production 集成"

---

## M7: Git/Local API

### 目标
双向 Markdown/Git 同步，本地 MCP-like server，loopback 能力授权。

### 验收标准
- [ ] Markdown 修改可同步回 SQLite
- [ ] Git commit 可触发项目更新
- [ ] 本地 server 提供项目 API
- [ ] 能力授权机制

### 依赖
- M3（Markdown 基础）, M4（State 收敛后）

### 风险
- **双向同步冲突**：Markdown <-> Git <-> SQLite 三方冲突
- **Server 安全**：本地 server 的能力边界

### 回滚策略
- Git 同步为可选功能
- Server 独立进程，可关闭

### 任务列表（M7，共 6 个任务）

#### TASK-M7-01: Markdown 导入实现
- **目标**: 实现 Markdown 项目导入
- **范围**:
  - 新增 `lib/features/import_export/data/markdown_importer.dart`
  - 实现 M3-03 设计的导入方案
- **相关模块**: import_export
- **Out-of-Scope**: 暂不支持增量导入
- **验收标准**:
  - [ ] 可导入 Markdown 文件树到项目
  - [ ] 冲突解决 UI 可用
  - [ ] 导入后数据正确
- **测试/CI 命令**: `flutter test lib/features/import_export/data/markdown_importer_test.dart`
- **前置依赖**: M3, M4
- **GitHub Issue/PR 要求**: Issue 标题 "[M7] Markdown 导入实现"

#### TASK-M7-02: Git Coordinator
- **目标**: 实现 Git 与项目状态的协调器
- **范围**:
  - 新增 `lib/app/state/git_coordinator.dart`
  - 监听 Git 变化并触发同步
- **相关模块**: app state, import_export
- **Out-of-Scope**: 暂不支持 Git push/pull 集成
- **验收标准**:
  - [ ] 可检测 Git 变更
  - [ ] 可触发 Markdown 导入
  - [ ] 冲突可解决
- **测试/CI 命令**: `flutter test lib/app/state/git_coordinator_test.dart`
- **前置依赖**: M7-01
- **GitHub Issue/PR 要求**: Issue 标题 "[M7] Git Coordinator"

#### TASK-M7-03: 双向同步与冲突解决
- **目标**: 完善 Markdown <-> SQLite 双向同步
- **范围**:
  - 修改 `lib/app/state/pending_overlay_store.dart`
  - 实现双向同步逻辑
- **相关模块**: app state, import_export
- **Out-of-Scope**: 暂不支持自动合并策略
- **验收标准**:
  - [ ] SQLite -> Markdown 导出正确
  - [ ] Markdown -> SQLite 导入正确
  - [ ] 冲突 UI 可展示和选择
- **测试/CI 命令**: `flutter test lib/app/state/pending_overlay_store_test.dart`
- **前置依赖**: M7-02
- **GitHub Issue/PR 要求**: Issue 标题 "[M7] 双向同步"

#### TASK-M7-04: 本地 MCP-like server 设计
- **目标**: 设计本地 server 的 API 规范
- **范围**:
  - 新增 `docs/local-server-api-design.md`
  - 定义 API 端点和能力
- **相关模块**: docs
- **Out-of-Scope**: 不实现 server
- **验收标准**:
  - [ ] API 设计包含：项目 CRUD、场景 CRUD、生成触发
  - [ ] 能力模型定义
  - [ ] 设计经过审阅
- **测试/CI 命令**: N/A（设计文档）
- **前置依赖**: M7-03
- **GitHub Issue/PR 要求**: Issue 标题 "[M7] 本地 server API 设计"

#### TASK-M7-05: Local server 实现
- **目标**: 实现本地 HTTP server
- **范围**:
  - 新增 `lib/app/server/`
  - 实现 server 主循环
- **相关模块**: app server（新建）
- **Out-of-Scope**: 暂不实现所有 API 端点
- **验收标准**:
  - [ ] Server 可启动和监听
  - [ ] 健康检查端点可用
  - [ ] 项目列表端点可用
- **测试/CI 命令**: `flutter test lib/app/server/`
- **前置依赖**: M7-04
- **GitHub Issue/PR 要求**: Issue 标题 "[M7] 本地 server 实现"

#### TASK-M7-06: Capability auth 授权机制
- **目标**: 实现 server 能力授权
- **范围**:
  - 新增 `lib/app/server/capability_auth.dart`
  - 定义和检查能力权限
- **相关模块**: app server
- **Out-of-Scope**: 暂不支持第三方 client 认证
- **验收标准**:
  - [ ] 能力模型定义（read, write, generate）
  - [ ] 授权检查正确
  - [ ] 日志记录授权决策
- **测试/CI 命令**: `flutter test lib/app/server/capability_auth_test.dart`
- **前置依赖**: M7-05
- **GitHub Issue/PR 要求**: Issue 标题 "[M7] 能力授权机制"

---

## M8: Ecosystem and Collaboration

### 目标
插件系统、模板市场、多项目 lore graph、review package、质量-成本自动路由。

### 验收标准
- [ ] 插件可加载和执行
- [ ] 模板可安装和应用
- [ ] 多项目关系图可展示
- [ ] Review package 可导出
- [ ] 模型路由策略生效

### 依赖
- M4（State 收敛）, M6（Bible/Production）, M7（Local API）

### 风险
- **插件沙箱**：插件安全性
- **模板分发**：模板来源可信度
- **关系图复杂度**：跨项目推理的正确性

### 回滚策略
- 插件系统可禁用
- 模板市场为可选功能
- 模型路由可回退到手动选择

### 任务列表（M8，共 8 个任务）

#### TASK-M8-01: 插件系统设计
- **目标**: 设计插件系统架构
- **范围**:
  - 新增 `docs/plugin-system-design.md`
  - 定义插件接口和沙箱
- **相关模块**: docs
- **Out-of-Scope**: 不实现插件系统
- **验收标准**:
  - [ ] 设计包含：插件 API、沙箱机制、生命周期
  - [ ] 安全模型定义
  - [ ] 设计经过审阅
- **测试/CI 命令**: N/A（设计文档）
- **前置依赖**: M4, M6, M7
- **GitHub Issue/PR 要求**: Issue 标题 "[M8] 插件系统设计"

#### TASK-M8-02: 插件系统核心实现
- **目标**: 实现插件加载和执行
- **范围**:
  - 新增 `lib/app/plugin/`
  - 实现插件管理器
- **相关模块**: app plugin（新建）
- **Out-of-Scope**: 暂不支持远程插件
- **验收标准**:
  - [ ] 可加载本地插件
  - [ ] 插件可注册扩展点
  - [ ] 沙箱隔离生效
- **测试/CI 命令**: `flutter test lib/app/plugin/`
- **前置依赖**: M8-01
- **GitHub Issue/PR 要求**: Issue 标题 "[M8] 插件系统核心"

#### TASK-M8-03: 模板市场基础
- **目标**: 实现模板的安装和应用
- **范围**:
  - 新增 `lib/app/template/`
  - 实现模板加载和应用逻辑
- **相关模块**: app template（新建）
- **Out-of-Scope**: 暂不支持远程模板市场
- **验收标准**:
  - [ ] 可安装本地模板
  - [ ] 模板可应用到新项目
  - [ ] 内置模板可用
- **测试/CI 命令**: `flutter test lib/app/template/`
- **前置依赖**: M8-02
- **GitHub Issue/PR 要求**: Issue 标题 "[M8] 模板市场基础"

#### TASK-M8-04: 多项目 lore graph
- **目标**: 实现跨项目的关系图
- **范围**:
  - 新增 `lib/app/lore/lore_graph.dart`
  - 新增关系图 UI
- **相关模块**: lore（新建）
- **Out-of-Scope**: 暂不支持自动关系推导
- **验收标准**:
  - [ ] 可展示多个项目的关系
  - [ ] 可手动添加关系
  - [ ] 图形可视化
- **测试/CI 命令**: `flutter test lib/app/lore/`
- **前置依赖**: M8-03
- **GitHub Issue/PR 要求**: Issue 标题 "[M8] 多项目 lore graph"

#### TASK-M8-05: Review package 导出
- **目标**: 实现 review package 的导出格式
- **范围**:
  - 新增 `lib/features/audit/data/review_package.dart`
  - 定义 review package 格式
- **相关模块**: audit
- **Out-of-Scope**: 暂不支持 review package 导入
- **验收标准**:
  - [ ] 可导出 review package（包含问题、建议、元数据）
  - [ ] 格式文档化
  - [ ] 可分享
- **测试/CI 命令**: `flutter test lib/features/audit/data/review_package_test.dart`
- **前置依赖**: M8-04
- **GitHub Issue/PR 要求**: Issue 标题 "[M8] Review package 导出"

#### TASK-M8-06: 质量-成本自动路由设计
- **目标**: 设计模型路由策略
- **范围**:
  - 新增 `docs/model-routing-design.md`
  - 定义路由算法
- **相关模块**: docs, LLM client
- **Out-of-Scope**: 不实现路由
- **验收标准**:
  - [ ] 设计包含：质量阈值、成本目标、路由规则
  - [ ] 设计经过审阅
- **测试/CI 命令**: N/A（设计文档）
- **前置依赖**: M8-05
- **GitHub Issue/PR 要求**: Issue 标题 "[M8] 模型路由设计"

#### TASK-M8-07: 质量-成本路由实现
- **目标**: 实现模型路由器
- **范围**:
  - 新增 `lib/app/llm/model_router.dart`
  - 实现路由逻辑
- **相关模块**: LLM client
- **Out-of-Scope**: 暂不支持动态学习
- **验收标准**:
  - [ ] 根据任务类型路由到不同模型
  - [ ] 质量阈值可配置
  - [ ] 成本统计准确
- **测试/CI 命令**: `flutter test lib/app/llm/model_router_test.dart`
- **前置依赖**: M8-06
- **GitHub Issue/PR 要求**: Issue 标题 "[M8] 模型路由实现"

#### TASK-M8-08: 生态集成与验证
- **目标**: 将所有生态功能集成并验证
- **范围**:
  - 集成插件、模板、lore graph、review package
  - 端到端验证
- **相关模块**: 多个模块
- **Out-of-Scope**: 无
- **验收标准**:
  - [ ] 插件可在完整流程中使用
  - [ ] 模板可从新建项目向导应用
  - [ ] Lore graph 可展示跨项目关系
  - [ ] Review package 可导出和查看
  - [ ] 模型路由正确工作
- **测试/CI 命令**: `flutter test integration_test/ecosystem_e2e_test.dart`
- **前置依赖**: M8-07
- **GitHub Issue/PR 要求**: Issue 标题 "[M8] 生态集成验证"

---


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
