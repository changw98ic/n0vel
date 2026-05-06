# 质量门禁与风险分级（v1）

## P0（阻断，必须修复）

1. **测试与发布门禁未闭环**
- 现状：P0 漏洞未清零会导致“可演示但不可上线”
- 验收：主干/PR 的 P0 关键用例为 0
- owner：Claude（修复）/ Codex（规则）

2. **安全与密钥治理缺口**
- 现状：配置存储与密钥生命周期、审计未形成商用基线
- 验收：敏感配置不出现明文、密钥与错误路径可审计
- owner：Claude（落地）/ Codex（清单）

## P1（发布前必须达标）

3. **运营治理缺失**
- 现状：成本、限流、重试降级、告警闭环未统一
- 验收：配置预算阈值、异常告警、降级路径可验证
- owner：Claude（实施）/ Codex（指标规范）

4. **PRD 与实现追踪已自动化（部分完成）**
- 现状：validate_mvp_docs.py + CI blocking gate 已接入，PRD status-matrix 已基于代码证据建立
- 验收：PR/提交触发 PRD-代码映射校验，缺口阻断或预警（部分完成，待扩展）
- owner：Claude（自动化扩展）

5. **作者工作流体验不足**
- 现状：版本历史、回滚、批注闭环不足
- 验收：主链路支持“生成-编辑-对比-回滚”
- owner：Claude（UI 实现）/ Codex（交互验收）

6. **A11y 与响应式不完整**
- 现状：可访问性与多端体验缺少统一验收
- 验收：键盘、语义、断点、字号、对比度通过清单
- owner：Claude（改造）/ Codex（验收）

7. **质量量化不足**
- 现状：叙事/人物/节奏指标缺少可解释评分
- 验收：每章产出可追溯评分与解释
- owner：Claude（计算与展示）/ Codex（指标定义）

## P2（优化项，进入发布后迭代）

8. **设计系统约束强制性不足**
- 现状：标准存在但未完全工程化
- 验收：新增/改动页面必须走 token 与组件契约
- owner：Claude（落地）/ Codex（契约）

## W0 阻断映射（mvp-blocking-checks）

### 自动化阻断（`MVP Blocking Checks`）

| 目标门禁 | 对应文档条目 | 自动化检查 | 阻断条件 |
| --- | --- | --- | --- |
| 关键测试与静态检查闭环 | P0-1 | `.github/workflows/mvp-blocking-checks.yml` -> `flutter analyze --no-pub` | 失败即阻断 |
| 核心回归测试通过 | P0-1 | `.github/workflows/mvp-blocking-checks.yml` -> `flutter test --no-pub -r compact` | 失败即阻断 |
| MVP 文档规范校验 | P1-4（可上抬为 P0） | `.github/workflows/mvp-blocking-checks.yml` -> `make mvp-docs-check` | 失败即阻断 |

### 非自动化（发布前必须手工确认）

| 目标门禁 | 对应文档条目 | 发布前要求 |
| --- | --- | --- |
| 安全与密钥治理缺口 | P0-2 | `docs/roadmap/security-baseline-checklist.md` 达成并通过 2 名以上复核 |
| 运营治理缺失 | P1-3 | `docs/roadmap/ops-metrics-spec.md` 与应急动作清单对齐 |
| PRD-实现追踪缺失 | P1-4 | `.github/workflows/mvp-docs-check.yml` 与追踪脚本（W4 输出）联动通过 |
| 作者工作流体验不足 | P1-5 | `docs/roadmap/writing-workbench-spec.md` 与主流程演练记录一致 |
| A11y 与响应式不足 | P1-6 | `docs/roadmap/a11y-responsive-checklist.md` 通过复核签字 |
| 质量量化不足 | P1-7 | `docs/roadmap/quality-metrics-spec.md` 与章节评分报告可核验 |
| 设计系统约束 | P2-8 | 关键页面有 token/组件契约变更记录与评审 |

## W0 一致性复核规则

- 所有 P0 条目必须至少有一条阻断检查（自动化或手工确认）并且有 owner。
- 未能覆盖的 P0 项目必须在发布前补齐对应检查，再上马下游功能提交。
- 发生 CI 失败时，必须先完成 P0 关闭闭环后才允许继续合并。

### W0 一致性签核入口（必读）

- 发布前由此文档与 [W0 一致性签核清单](./w0-consistency-signoff.md)联动复核，双方签核通过后方可进入下一版本窗。
- `w0-consistency-signoff.md` 记录本地发布前 P0 覆盖、证据链接与关闭时间，签核条目与本文件需一致。
