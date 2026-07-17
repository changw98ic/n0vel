# Milestone 0 执行协议

> 版本: 1.0
> 创建日期: 2026-05-24
> 里程碑: M0 - Roadmap/Backlog Operationalization

## 目标

建立长期执行计划框架，使后续任务可按 task ID 接力执行。

## 验收标准

- [ ] `docs/execution-roadmap.md` 存在且包含 M0-M8 所有任务
- [ ] 每个任务粒度 <= 1 人天
- [ ] 每个里程碑包含依赖、验收标准、风险、回滚策略
- [ ] 提交信息符合 Lore Commit Protocol
- [ ] 已推送到远端分支
- [ ] 已检查 CI 状态
- [ ] 已生成 deliverable 交付给 Codex

## 风险

- **gh CLI 未认证**：无法创建 GitHub issue，需在 deliverable 中说明
- **CI 配置变更**：如 CI 检查失败需记录原因

## 回滚策略

```bash
# 删除新增的文档
rm docs/execution-roadmap.md docs/milestone-0-protocol.md

# 安全回滚：创建 revert commit
git revert HEAD --no-edit
# 或如需完全删除：删除文件后正常 commit
git add docs/
git commit -m "docs: 回滚 M0 计划文档

Related: 原计划框架已废弃
Scope-risk: 无（仅删除文档）
Tested: git status 显示清理完成"
```

## 执行协议

### 角色分工

- **Codex leader**：负责范围确认、关键路径、整合、最终验证和交付
- **实现代理**：在明确的文件范围内负责代码或文档实现与针对性测试
- **验证代理**：负责独立检查、测试证据和风险回报

### 提交信息格式（Lore Commit Protocol）

```
<type>: <why-first intent line>

<optional detailed bullet points>

Related: <issue-number-or-context>
Confidence: <high|medium|low>
Scope-risk: <risk-assessment>
Tested: <what-was-tested>
Not-tested: <what-not-tested>
```

类型示例：`feat`、`fix`、`refactor`、`docs`、`test`、`chore`、`规划`

M0 提交示例：

```
docs: 建立长期执行计划框架

使后续任务可按 task ID 接力执行 M0-M8

- 创建 docs/execution-roadmap.md 包含 M0-M8 任务拆分
- 创建 docs/milestone-0-protocol.md 定义执行协议
- 每个任务粒度 <= 1 人天，里程碑明确依赖和验收标准

Related: #23
Confidence: high
Scope-risk: low（仅文档）
Tested: 文件存在性验证已通过
Not-tested: CI 验证待 push 后检查
```

### GitHub Issue 要求

每个 durable content 更新（文档、架构、PRD、执行计划）必须有关联 issue：

- Issue 标题格式：`[M<编号>] <任务简述>`
- Issue 内容必须包含：
  - 目标
  - 范围
  - 验收标准
  - 风险

**M0 Issue 示例**：

```markdown
## [M0] 建立长期执行计划框架

### 目标
创建长期执行计划文档，使后续任务可按 task ID 接力执行。

### 范围
- 创建 `docs/execution-roadmap.md`
- 创建 `docs/milestone-0-protocol.md`

### 验收标准
- [ ] 文档包含 M0-M8 所有里程碑
- [ ] 每个任务粒度 <= 1 人天
- [ ] 提交并推送成功

### 风险
- gh CLI 未认证，无法自动创建 issue
```

### CI 检查要求

检查本次变更实际触发的 workflow；如果没有触发，记录路径过滤原因：
- `flutter-analyze-test.yml`（若由代码、测试或依赖变更触发）
- `verify-macos.yml`（若由桌面验证入口、脚本或相关代码变更触发）

CI 失败必须修复后才能继续下一个里程碑。

### 检查命令

```bash
# 验证文件存在
ls -la docs/execution-roadmap.md docs/milestone-0-protocol.md

# 验证 git 状态
git status
git log -1

# 推送主题分支并创建针对主分支的 PR
git push -u origin <topic-branch>
gh pr create --base master --fill --draft

# 检查 CI（需要 gh CLI）
gh run list --limit 5
```

## 任务列表

### TASK-M0-01: 创建长期执行计划框架

- **目标**: 创建 docs/execution-roadmap.md 和 docs/milestone-0-protocol.md
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

## M0 完成标志

当以下条件全部满足时，M0 视为完成：

1. 两个文档文件已创建并推送到主题分支
2. 提交信息符合 Lore Commit Protocol
3. 被触发的 CI 检查通过（或记录未触发/失败原因）
4. PR 中已记录验证证据与已知缺口

## 下一步

M0 完成后，可并行开始：
- **M1**: Daily Writing Studio
- **M2**: Pipeline Runtime Hardening
- **M3**: Open Storage
