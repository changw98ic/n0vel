# MVP 实现交接稿

本文档用于把当前已经稳定的 UI 设计与高优先级交互规则交接给实现阶段。

## 当前结论

- 静态页面与状态图已经基本齐备。
- 高优先级交互规则已从"待讨论"推进为"可实现规则"。
- 当前更适合转入实现、联调与验证，而不是继续大面积扩写状态图。

## 开始前检查

实现前先执行：

```bash
python3 docs/mvp/validate_mvp_docs.py
```

若未返回 `MVP doc validation: PASSED`，先修文档一致性，再进入编码阶段。

## 实现优先顺序

1. 写作工作台主壳层
2. AI 修改确认流
3. 纯净阅读
4. 模拟过程弹窗
5. 设置与 BYOK
6. 工程导入导出
7. 章节版本
8. 角色库 / 世界观 / 审计中心

## Canonical Frame

### 核心页面

- `Project List` → `nXod8`
- `Writing Workbench` → `47nGt`
- `Style Panel` → `ff8vo`
- `Settings & BYOK` → `DnwrZ`
- `Sandbox Monitor` → `YTrUo`
- `Character Library` → `4KVQe`
- `Worldbuilding` → `dH2Mr`
- `Audit Center` → `p8Lkt`
- `Project Import Export` → `z0mJ1`
- `UI Foundation` → `9gEi3`

### 补充页面

- `Scene Management` → `PIRts`

### 场景管理状态

- `Scene Management / Create Scene` → `aI0tb`
- `Scene Management / Rename Scene` → `GKvUk`
- `Scene Management / Delete Scene Confirm` → `fhYDR`
- `Scene Management / Edit Chapter Label` → `nl6rr`
- `Scene Management / Edit Summary` → `h4puH`
- `Scene Management / Move Scene` → `OiGfq`

### 工作台状态

- `Writing Workbench / Default Hidden` → `WT5mH`
- `Writing Workbench / Resources Open` → `aBO8C`
- `Writing Workbench / AI Selected Tool` → `XBhIG`
- `Writing Workbench / AI Tool Picker Open` → `AMlNT`
- `Writing Workbench / AI Settings Read Failed` → `NqgGR`
- `Writing Workbench / AI Settings Write Failed` → `jbGIZ`
- `Writing Workbench / AI Ready After Recovery` → `aZupZ`
- `Writing Workbench / Create Scene Dialog` → `IhizR`
- `Writing Workbench / Rename Scene Dialog` → `VCoJM`
- `Writing Workbench / Delete Scene Confirm` → `ttVz8`
- `Writing Workbench / Menu Drawer Open` → `i2PgM`
- `Writing Workbench / Missing Character Binding` → `o6hOU`
- `Writing Workbench / Missing Character Reference` → `WmFpE`
- `Writing Workbench / Missing World Reference` → `emCHR`
- `Writing Workbench / API Key Missing` → `y6Ufy`
- `Writing Workbench / No Simulation Yet` → `ea0WQ`
- `Writing Workbench / Overlapping Selections` → `go6Qc`
- `Writing Workbench / AI Modify Failed` → `FPMUS`
- `Writing Workbench / AI Accept Failed` → `eOH82`
- `Writing Workbench / Simulation Completed` → `O5wWx`
- `Writing Workbench / Simulation Failed Summary` → `dSehn`
- `Writing Workbench / Context Synced` → `6RjjP`
- `Writing Workbench / Simulation In Progress` → `4K0UK`
- `Writing Workbench / AI Ready` → `lV0iX`
- `Writing Workbench / AI History Populated` → `bgE7z`

### AI / 版本 / 阅读

- `AI Revision Confirmation / Batch Review` → `XYBaG`
- `AI Revision Confirmation / Three Blocks` → `XkB5L`
- `AI Revision Confirmation / Continue Mode` → `VT3Da`
- `AI Revision Confirmation / All Excluded` → `rQbOu`
- `AI Revision Confirmation / Restore Excluded Block` → `8JkLW`
- `Chapter Versions / Recent Five` → `Ym6ea`
- `Chapter Versions / History AI Expanded` → `PUmdJ`
- `Chapter Versions / Expanded State Remembered` → `uHxFC`
- `Chapter Versions / Single Version` → `v82se`
- `Chapter Versions / Oldest Pending Eviction` → `xY5Bh`
- `Chapter Versions / Pending Save Before Eviction` → `rr4J7`
- `Chapter Versions / Restore Failed` → `XEwpS`
- `Chapter Versions / Restore Success` → `pblhy`
- `Reading Mode / Pure Reader` → `GD63C`
- `Reading Mode / Single Page` → `WGzHM`
- `Reading Mode / Chapter Boundary` → `Cz57s`
- `Reading Mode / Previous Chapter Boundary` → `mDkBH`
- `Reading Mode / No Previous Chapter` → `ATuaL`
- `Reading Mode / No Next Chapter` → `cqffu`

### 全局 Shell 状态

- `Global Shell / Settings File Read Failed` → `cObbS`
- `Global Shell / Settings File Write Failed` → `SGKvq`

### 项目 / 导入导出

- `Project List / Empty` → `MS3Oh`
- `Project List / Search No Results` → `az4YP`
- `Project List / Database Read Failed` → `qW9NX`
- `Project List / Import Failed` → `X4Udf`
- `Project List / Delete Confirm` → `01wqz`
- `Project Import Export / Import Success` → `aYhVV`
- `Project Import Export / Export Success` → `4U4Ue`
- `Project Import Export / Overwrite Success` → `XrBiQ`
- `Project Import Export / Overwrite Confirm` → `kJVPV`
- `Project Import Export / Invalid Package` → `YqiXr`
- `Project Import Export / Missing Manifest` → `f4cfp`
- `Project Import Export / No Exportable Project` → `O5g2A`
- `Project Import Export / Major Version Blocked` → `nJ1Vf`
- `Project Import Export / Minor Version Warning` → `sqxPi`

### 风格 / 设置 / 模拟

- `Style Panel / Empty` → `hs0KX`
- `Style Panel / JSON Mode` → `uZkEL`
- `Style Panel / Project Default Bound` → `6TNF5`
- `Style Panel / JSON Error` → `ABdeI`
- `Style Panel / Unsupported JSON Version` → `6iQPW`
- `Style Panel / Unknown Fields Ignored` → `bPxYh`
- `Style Panel / Missing Required Fields` → `3sKz3`
- `Style Panel / Validation Failed` → `ToU7Z`
- `Style Panel / Max Profiles Reached` → `fjUbH`
- `Style Panel / Scene Override Notice` → `tosI5`
- `Settings / Unconfigured` → `WwWEh`
- `Settings / Missing API Key` → `6yJaH`
- `Settings / Invalid Base URL` → `hroTw`
- `Settings / Missing Model` → `NVC2a`
- `Settings / Unsupported Model` → `YwhiQ`
- `Settings / File Read Failed` → `a0Ywa`
- `Settings / File Write Failed` → `oyTF3`
- `Settings / Retry Read Success` → `sOHyn`
- `Settings / Retry Write Success` → `AGfYb`
- `Settings / Connection Timeout` → `9Ukuf`
- `Settings / Connection Failed` → `URbAX`
- `Settings / Unauthorized` → `yRdSE`
- `Settings / Provider Model Not Found` → `1KpPn`
- `Settings / Network Error` → `BtJNK`
- `Settings / Save Success` → `HcPSf`
- `Settings / Connection Test Success` → `1ppB0`
- `Settings / Legacy Migration Warning` → `2W8bB`
- `Simulation Monitor / Empty` → `fBn5z`
- `Simulation Monitor / Edit Prompt` → `VK4F1`
- `Simulation Monitor / Director Feedback Applied` → `ma61v`
- `Simulation Monitor / Agent No Output` → `JJh0t`
- `Simulation Monitor / Failed` → `GtV8t`
- `Simulation Monitor / Phase Refresh` → `Fekvk`

### 资料页

- `Character Library / Empty` → `qpmBd`
- `Character Library / Search No Results` → `tfAqU`
- `Character Library / Missing Required Fields` → `zlKdA`
- `Character Library / Delete Referenced Confirm` → `bRkQL`
- `Worldbuilding / Empty` → `5HcpF`
- `Worldbuilding / Filter No Results` → `mMbsG`
- `Worldbuilding / Missing Type` → `bJvYY`
- `Worldbuilding / Delete Parent Confirm` → `CQycp`
- `Audit Center / Empty` → `bAyGg`
- `Audit Center / Resolved Feedback` → `THj8i`
- `Audit Center / Ignore Feedback` → `IfzpB`
- `Audit Center / Filter No Results` → `55YHH`
- `Audit Center / Related Draft Missing` → `25jQz`
- `Audit Center / Jump Failed` → `BskXB`

### Dark 变体

- `Scene Management / Dark` → `d3GpN`
- `Scene Management / Create Scene / Dark` → `1gawm`
- `Scene Management / Rename Scene / Dark` → `Wjux2`
- `Scene Management / Delete Scene Confirm / Dark` → `HzUVW`
- `Scene Management / Edit Chapter Label / Dark` → `cnVw7`
- `Scene Management / Edit Summary / Dark` → `4WJJo`
- `Scene Management / Move Scene / Dark` → `kky86`
- `Global Shell / Settings File Read Failed / Dark` → `0TEna`
- `Global Shell / Settings File Write Failed / Dark` → `cnTHD`
- `Project Import Export / Export Success / Dark` → `jxKRn`
- `Settings / Connection Test Success / Dark` → `7ZQrT`
- `Settings / Legacy Migration Warning / Dark` → `lBP5k`
- `Settings / File Read Failed / Dark` → `fpqP8`
- `Settings / File Write Failed / Dark` → `O2KNT`
- `Settings / Retry Read Success / Dark` → `23RSP`
- `Settings / Retry Write Success / Dark` → `PfRrt`
- `Settings / Connection Timeout / Dark` → `LRExZ`
- `Writing Workbench / AI Settings Read Failed / Dark` → `zEinB`
- `Writing Workbench / AI Settings Write Failed / Dark` → `U92jw`
- `Writing Workbench / AI Ready After Recovery / Dark` → `wAiOX`
- `Writing Workbench / Create Scene Dialog / Dark` → `Wves1`
- `Writing Workbench / Rename Scene Dialog / Dark` → `wjCFR`
- `Writing Workbench / Delete Scene Confirm / Dark` → `9EUv4`
- `AI Revision Confirmation / Continue Mode / Dark` → `GLk16`
- `Writing Workbench / AI Accept Failed / Dark` → `XhEGm`
- `Writing Workbench / Simulation In Progress / Dark` → `APFtI`
- `Writing Workbench / AI Ready / Dark` → `aOczr`
- `Writing Workbench / AI History Populated / Dark` → `yo9In`
- `Style Panel / JSON Mode / Dark` → `HURTB`
- `Style Panel / Project Default Bound / Dark` → `hK7Ud`
- `Audit Center / Resolved Feedback / Dark` → `PSDTH`
- `Audit Center / Ignore Feedback / Dark` → `Hqgfj`
- `Simulation Monitor / Edit Prompt / Dark` → `SVryJ`
- `Simulation Monitor / Director Feedback Applied / Dark` → `RRIRw`

## 实现提醒

- 优先按上面的 canonical frame 实现，不要参考已知旧探索稿。
- 工作台相关状态默认都应保留正文上下文，不要误做成整页跳转。
- 阻断态、轻提示态、完成态已经在 [frame-state-coverage.md](/Users/chengwen/dev/novel-wirter/docs/mvp/frame-state-coverage.md) 中分层。
- 如果后续继续补画布，优先新增正式命名 frame，不要复用旧探索稿名字。

## Legacy 注意项

当前画布内存在少量重名但已废弃的早期探索稿，研发实现时不要误用：

- `Project List / Search No Results`
  - 正式基线：`az4YP`
  - 废弃探索稿：`UbuvO`
  - 判定依据：`UbuvO` 画面不完整，缺少中间无结果文案与右侧详情区

- `Settings / Missing API Key`
  - 正式基线：`6yJaH`
  - 废弃探索稿：`9izFv`
  - 判定依据：`9izFv` 画面不完整，缺少中间缺失说明与右侧说明区

## 里程碑建议

### M1 壳层与主工作台

- 覆盖：
  - `Writing Workbench`
  - `Writing Workbench / Default Hidden`
  - `Writing Workbench / Menu Drawer Open`
  - `Writing Workbench / API Key Missing`
  - `Writing Workbench / Missing Character Binding`
  - `Writing Workbench / Missing Character Reference`
  - `Writing Workbench / Missing World Reference`
- 完成标准：
  - 左侧隐藏 `menu drawer`、顶部 `breadcrumb`、右侧工具条都稳定
  - 正文编辑区可持续保持主视觉中心
  - 所有工作台阻断 / 轻提示态都不打断正文上下文

### M2 AI 修改流

- 覆盖：
  - `Writing Workbench / AI Selected Tool`
  - `Writing Workbench / AI Tool Picker Open`
  - `Writing Workbench / Overlapping Selections`
  - `Writing Workbench / AI Modify Failed`
  - `AI Revision Confirmation / Batch Review`
  - `AI Revision Confirmation / Three Blocks`
  - `AI Revision Confirmation / All Excluded`
  - `AI Revision Confirmation / Restore Excluded Block`
- 完成标准：
  - 选区、排除、恢复、接受、拒绝语义全部闭环
  - 失败态不改正文、不落版本

### M3 阅读与版本

- 覆盖：
  - `Reading Mode / Pure Reader`
  - `Reading Mode / Single Page`
  - `Reading Mode / Chapter Boundary`
  - `Reading Mode / Previous Chapter Boundary`
  - `Reading Mode / No Previous Chapter`
  - `Reading Mode / No Next Chapter`
  - `Chapter Versions / Recent Five`
  - `Chapter Versions / Expanded State Remembered`
  - `Chapter Versions / Pending Save Before Eviction`
  - `Chapter Versions / Restore Failed`
  - `Chapter Versions / Restore Success`
- 完成标准：
  - 阅读返回锚点恢复
  - 最近 5 个版本策略稳定
  - 历史 AI 展开 / 记忆逻辑稳定

### M4 模拟与导入导出

- 覆盖：
  - `Sandbox Monitor`
  - `Simulation Monitor / Empty`
  - `Simulation Monitor / Agent No Output`
  - `Simulation Monitor / Failed`
  - `Simulation Monitor / Phase Refresh`
  - `Project Import Export`
  - `Project Import Export / Import Success`
  - `Project Import Export / Overwrite Success`
  - `Project Import Export / Overwrite Confirm`
  - `Project Import Export / Missing Manifest`
  - `Project Import Export / Major Version Blocked`
  - `Project Import Export / Minor Version Warning`
  - `Project Import Export / No Exportable Project`
- 完成标准：
  - `SimulationRun` 回传和刷新模式稳定
  - 导入成功 / 覆盖成功后的索引刷新稳定
  - 导入阻断态和轻警告态清晰分层
