# Claude 任务清单（代码，按周）

## W0
- 落地 CI 阻断规则：关键失败项 fail 分支
- 文件：`.github/workflows/mvp-blocking-checks.yml`

## W1
- 识别并修复 P0 阻断测试，补齐缺失用例
- 文件：`test/` 相关测试文件

## W2
- 完成敏感配置安全加固（加密/读取边界/错误分类）
- 重点文件：
  - `lib/app/state/app_settings_store.dart`
  - `lib/app/state/app_settings_storage_io.dart`
  - `lib/app/state/settings_json_cipher.dart`
  - `test/app_settings_store_test.dart`

## W3
- 接入运营治理钩子（请求追踪、失败重试、预算、告警）
- 重点文件：
  - `lib/app/state/app_llm_client_io.dart`
  - `lib/features/story_generation/data/chapter_generation_orchestrator.dart`

## W4
- 上线 PRD-实现映射校验脚本与 CI 集成
- 重点文件：
  - `docs/mvp/traceability-matrix.md`（若采用机器可读映射层）
  - `docs/mvp/traceability-matrix.json`（或新增映射清单）
  - `.github/workflows/mvp-docs-check.yml`
  - `docs/mvp/scripts/*`（新增校验脚本）

## W5-W6
- 实现写作工作台核心体验（版本对比、回滚、批注）
- 涉及文件：`lib/app/*`、`lib/features/*`、`lib/main.dart`

## W7
- A11y/响应式改造与回归
- 涉及文件：`lib/theme/*`、`lib/features/*`

## W8
- 接入章节质量评分字段并可视化
- 重点文件：
  - `lib/features/story_generation/data/chapter_generation_orchestrator.dart`
  - `lib/features/story_generation/data/scene_review_models.dart`
  - `lib/features/story_generation/data/narrative_arc_tracker.dart`

## W9
- 将 UI 设计系统与 token 规范落地
- 重点文件：`lib/theme/*`、`lib/ui/*`

## W10
- 收口回归、文档对应、最终 CI 清理
- 文件：本次全量改动相关代码/测试/脚本文件

## 交付要求
- 每项代码改动必须有至少一条对应验收标准
- 每项代码改动需要新增或更新回归用例

