# PRD Status Matrix

Evidence-based implementation status for all MVP PRDs. Last audited: 2026-05-06.

| PRD | Title | Status | Source Files | Lines | Tests | Smoke Coverage |
|-----|-------|--------|-------------|-------|-------|----------------|
| PRD-01 | 项目列表页 | implemented | lib/features/projects/ | 1319 | 0 | Smoke 01, 09, 10 |
| PRD-02 | 写作工作台 | implemented | lib/features/workbench/ | 3947 | 1 | Smoke 01-06, 12 |
| PRD-03 | 模拟过程弹窗 | implemented | lib/features/sandbox/ | 884 | 1 | Smoke 04-06 |
| PRD-04 | 角色库页 | implemented | lib/features/characters/ | 813 | 0 | Smoke 12 |
| PRD-05 | 世界观页 | implemented | lib/features/worldbuilding/ | 757 | 1 | Smoke 12 |
| PRD-06 | 风格面板页 | implemented | lib/features/style/ | 1101 | 1 | Smoke 11 |
| PRD-07 | 审计中心页 | implemented | lib/features/audit/ | 643 | 1 | - |
| PRD-08 | 章节版本页 | implemented | lib/features/versions/ | 178 | 0 | Smoke 08 |
| PRD-09 | 工程导入导出 | implemented | lib/features/import_export/ | 2186 | 0 | Smoke 09-10 |
| PRD-10 | 设置与 自带密钥 | implemented | lib/features/settings/ | 1385 | 7 | Smoke 11 |
| PRD-11 | 纯净阅读态 | implemented | lib/features/reading/ | 560 | 0 | Smoke 07 |

## Key Metrics

- **Total PRDs**: 11 (all implemented)
- **Core engine**: lib/features/story_generation/ (85 files, 21408 lines)
- **Supplemental features**: scenes, setting_summary, production_board, review_tasks, author_feedback
- **Total smoke tests**: 12
- **Test gaps**: PRD-01, PRD-04, PRD-08, PRD-09, PRD-11 have zero feature-level tests

## Open Action Items (from .omx/artifacts/)

| 来源 | 条目 | 优先级 | 状态 |
|--------|------|----------|--------|
| claude-ui-status-20260504 | 空状态启动与种子演示数据不一致导致 7 个测试失败 | P1 | 待处理 |
| provider-routing-investigation-20260504 | RC-4 工作台模拟阻塞提示缺少跳转动作 | P2 | 已修复（模型服务路由实现） |
| provider-routing-investigation-20260504 | RC-5 macOS 构建脆弱性 | P1 | 待处理 |
| formal-macos-flow-runtime-diagnosis-20260504 | 启动时连接在 TIME_WAIT 关闭（遥测 / 密钥校验） | P3 | 排查中 |

## 里程碑映射

| Milestone | Scope | Status |
|-----------|-------|--------|
| M1 | 壳层与主工作台 | Implemented |
| M2 | AI 修改流 | Implemented |
| M3 | 阅读与版本 | Implemented |
| M4 | 模拟与导入导出 | Implemented |
| M5 | 设置与资料页 | Implemented |
