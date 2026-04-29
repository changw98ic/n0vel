# Legacy Frame 审计

本文档记录当前 `.pen` 画布中已确认的历史残留 frame。

这些 frame 仍然存在于画布顶层，但**不属于正式交付基线**，实现阶段不应作为视觉或交互参考。

## 目的

- 避免研发误用早期探索稿
- 避免自动化脚本把重名旧稿误识别为 canonical frame
- 为后续画布清理提供依据

## 已确认的残留稿

### 1. `Project List / Search No Results`

- 正式基线：`az4YP`
- 历史残留：`UbuvO`
- 判定依据：
  - `az4YP` 具备完整的无结果说明、操作按钮与右侧详情区
  - `UbuvO` 仅剩空壳布局，缺少中间无结果文案与完整右侧内容

### 2. `Settings / Missing API Key`

- 正式基线：`6yJaH`
- 历史残留：`9izFv`
- 判定依据：
  - `6yJaH` 具备完整的缺失说明、中间提示与右侧说明区
  - `9izFv` 仅保留空容器，缺少中间缺失语义和右侧帮助信息

## 使用规则

- 研发实现只参考 [canonical-frame-map.json](/Users/chengwen/dev/novel-wirter/docs/mvp/canonical-frame-map.json)
- 若 frame 名重复，以 `canonical-frame-map.json` 中的 canonical id 为准
- 本文档列出的 legacy frame 不参与实现，不参与验收，不参与 UI 对齐

## 可安全删除候选

以下 frame 当前只作为历史残留存在，若后续进入画布清理阶段，可优先删除：

- `UbuvO`
  - 名称：`Project List / Search No Results`
  - 替代基线：`az4YP`
  - 删除理由：画面不完整，且与 canonical frame 重名

- `9izFv`
  - 名称：`Settings / Missing API Key`
  - 替代基线：`6yJaH`
  - 删除理由：画面不完整，且与 canonical frame 重名

删除前仍建议再做一次人工截图核对，确认实现侧未引用这些旧 id。

## 后续建议

- 后续如需清理画布，可优先删除本文档列出的 legacy frame
- 若新增探索稿，应优先使用临时命名，避免与正式 frame 同名

## 当前结论

- 依据最新一轮顶层 frame 扫描，当前已确认的重复命名残留稿仅有上述两组。
- 其余顶层 frame 当前未发现新的重名正式稿 / 残留稿冲突。
