# PRD-实现追踪 Schema（Codex）

## 记录字段

- `prd_id`：PRD 文档编号，如 `prd-02-writing-workbench`
- `feature`：功能名
- `scenario`：验收场景
- `owner_file`：实现文件路径
- `test_ref`：对应测试文件或用例
- `status`：`implemented | partial | missing`
- `evidence`：证据说明（文件/章节）
- `last_review`：评审日期

## 阻断规则

- `status=missing` 在 CI 中视为 Warning（第一阶段）或 Fail（核心链路 PRD）。
- 同一 PRD `feature` 在 7 天内不得连续两次缺失而不更新。

