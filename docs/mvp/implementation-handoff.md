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
5. 设置与 自带密钥
6. 工程导入导出
7. 章节版本
8. 角色库 / 世界观 / 审计中心

## Canonical Frame

### 核心页面

- `Project List` → `nXod8`
- `写作工作台` → `47nGt`
- `风格面板` → `ff8vo`
- `设置与自带密钥` → `DnwrZ`
- `Sandbox Monitor` → `YTrUo`
- `Character Library` → `4KVQe`
- `Worldbuilding` → `dH2Mr`
- `Audit Center` → `p8Lkt`
- `Project Import Export` → `z0mJ1`
- `UI Foundation` → `9gEi3`

### 补充页面

- `Scene Management` → `PIRts`
- `设定摘要 / 聚合事实` → `Z0240`
- `Production Board / Progress Loop` → `Z0340`
- `Review Tasks / Queue States` → `Z0402`

### 场景管理状态

- `Scene Management / Create Scene` → `aI0tb`
- `Scene Management / Rename Scene` → `GKvUk`
- `Scene Management / 删除场景确认` → `fhYDR`
- `Scene Management / Edit Chapter Label` → `nl6rr`
- `Scene Management / Edit Summary` → `h4puH`
- `Scene Management / Move Scene` → `OiGfq`

### 工作台状态

- `写作工作台 / 默认隐藏` → `WT5mH`
- `写作工作台 / 资源面板打开` → `aBO8C`
- `写作工作台 / AI 工具已选择` → `XBhIG`
- `写作工作台 / AI 工具选择打开` → `AMlNT`
- `写作工作台 / AI 设置 Read Failed` → `NqgGR`
- `写作工作台 / AI 设置 Write Failed` → `jbGIZ`
- `写作工作台 / AI 恢复后可用` → `aZupZ`
- `写作工作台 / 创建场景弹窗` → `IhizR`
- `写作工作台 / 重命名场景弹窗` → `VCoJM`
- `写作工作台 / 删除场景确认` → `ttVz8`
- `写作工作台 / 导航抽屉打开` → `i2PgM`
- `写作工作台 / 完整导航抽屉` → `Z0134`
- `写作工作台 / 缺少角色绑定` → `o6hOU`
- `写作工作台 / 角色引用缺失` → `WmFpE`
- `写作工作台 / 世界观引用缺失` → `emCHR`
- `写作工作台 / 缺少密钥` → `y6Ufy`
- `写作工作台 / 暂无模拟` → `ea0WQ`
- `写作工作台 / 选择范围重叠` → `go6Qc`
- `写作工作台 / AI 修改失败` → `FPMUS`
- `写作工作台 / AI 接受失败` → `eOH82`
- `写作工作台 / 模拟完成` → `O5wWx`
- `写作工作台 / 模拟失败摘要` → `dSehn`
- `写作工作台 / 上下文已同步` → `6RjjP`
- `写作工作台 / 模拟进行中` → `4K0UK`
- `写作工作台 / AI 可用` → `lV0iX`
- `写作工作台 / AI 历史有内容` → `bgE7z`

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

- `Global Shell / 设置 File Read Failed` → `cObbS`
- `Global Shell / 设置 File Write Failed` → `SGKvq`

### 项目 / 导入导出

- `Project List / 空状态` → `MS3Oh`
- `Project List / Search No Results` → `az4YP`
- `Project List / Database Read Failed` → `qW9NX`
- `Project List / Import Failed` → `X4Udf`
- `Project List / Delete Confirm` → `01wqz`
- `Project List / Responsive Shelf Fit` → `Z0073`
- `Project Import Export / Import Success` → `aYhVV`
- `Project Import Export / Export Success` → `4U4Ue`
- `Project Import Export / Overwrite Success` → `XrBiQ`
- `Project Import Export / Overwrite Confirm` → `kJVPV`
- `Project Import Export / Invalid Package` → `YqiXr`
- `Project Import Export / Missing Manifest` → `f4cfp`
- `Project Import Export / No Exportable Project` → `O5g2A`
- `Project Import Export / Major Version Blocked` → `nJ1Vf`
- `Project Import Export / Minor Version Warning` → `sqxPi`
- `Project Import Export / Contained Long Paths` → `Z0194`

### 风格 / 设置 / 模拟

- `风格面板 / 空状态` → `hs0KX`
- `风格面板 / JSON 模式` → `uZkEL`
- `风格面板 / 项目默认已绑定` → `6TNF5`
- `风格面板 / JSON 错误` → `ABdeI`
- `风格面板 / JSON 版本不支持` → `6iQPW`
- `风格面板 / 未知字段已忽略` → `bPxYh`
- `风格面板 / 缺少必填项` → `3sKz3`
- `风格面板 / 校验失败` → `ToU7Z`
- `风格面板 / 风格档案达到上限` → `fjUbH`
- `风格面板 / 场景覆盖提醒` → `tosI5`
- `设置 / 未配置` → `WwWEh`
- `设置 / 缺少密钥` → `6yJaH`
- `设置 / 接口地址无效` → `hroTw`
- `设置 / 缺少模型` → `NVC2a`
- `设置 / 模型不受支持` → `YwhiQ`
- `设置 / 配置读取失败` → `a0Ywa`
- `设置 / 配置写入失败` → `oyTF3`
- `设置 / 重新读取成功` → `sOHyn`
- `设置 / 重新写入成功` → `AGfYb`
- `设置 / 连接超时` → `9Ukuf`
- `设置 / 连接失败` → `URbAX`
- `设置 / 鉴权失败` → `yRdSE`
- `设置 / 模型服务缺少模型` → `1KpPn`
- `设置 / 网络错误` → `BtJNK`
- `设置 / 保存成功` → `HcPSf`
- `设置 / 连接测试成功` → `1ppB0`
- `设置 / 旧配置迁移提醒` → `2W8bB`
- `Simulation Monitor / 空状态` → `fBn5z`
- `Simulation Monitor / Edit Prompt` → `VK4F1`
- `Simulation Monitor / Director Feedback Applied` → `ma61v`
- `Simulation Monitor / Agent No Output` → `JJh0t`
- `Simulation Monitor / Failed` → `GtV8t`
- `Simulation Monitor / Phase Refresh` → `Fekvk`

### 资料页

- `Character Library / 空状态` → `qpmBd`
- `Character Library / Search No Results` → `tfAqU`
- `Character Library / 缺少必填项` → `zlKdA`
- `Character Library / Delete Referenced Confirm` → `bRkQL`
- `Worldbuilding / 空状态` → `5HcpF`
- `Worldbuilding / Filter No Results` → `mMbsG`
- `Worldbuilding / Missing Type` → `bJvYY`
- `Worldbuilding / Delete Parent Confirm` → `CQycp`
- `Audit Center / 空状态` → `bAyGg`
- `Audit Center / Resolved Feedback` → `THj8i`
- `Audit Center / Ignore Feedback` → `IfzpB`
- `Audit Center / Filter No Results` → `55YHH`
- `Audit Center / Related Draft Missing` → `25jQz`
- `Audit Center / Jump Failed` → `BskXB`

### 深色 变体

- `Scene Management / 深色` → `d3GpN`
- `Scene Management / Create Scene / 深色` → `1gawm`
- `Scene Management / Rename Scene / 深色` → `Wjux2`
- `Scene Management / 删除场景确认 / 深色` → `HzUVW`
- `Scene Management / Edit Chapter Label / 深色` → `cnVw7`
- `Scene Management / Edit Summary / 深色` → `4WJJo`
- `Scene Management / Move Scene / 深色` → `kky86`
- `Global Shell / 设置 File Read Failed / 深色` → `0TEna`
- `Global Shell / 设置 File Write Failed / 深色` → `cnTHD`
- `Project Import Export / Export Success / 深色` → `jxKRn`
- `设置 / 连接测试成功 / 深色` → `7ZQrT`
- `设置 / 旧配置迁移提醒 / 深色` → `lBP5k`
- `设置 / 配置读取失败 / 深色` → `fpqP8`
- `设置 / 配置写入失败 / 深色` → `O2KNT`
- `设置 / 重新读取成功 / 深色` → `23RSP`
- `设置 / 重新写入成功 / 深色` → `PfRrt`
- `设置 / 连接超时 / 深色` → `LRExZ`
- `写作工作台 / AI 设置 Read Failed / 深色` → `zEinB`
- `写作工作台 / AI 设置 Write Failed / 深色` → `U92jw`
- `写作工作台 / AI 恢复后可用 / 深色` → `wAiOX`
- `写作工作台 / 创建场景弹窗 / 深色` → `Wves1`
- `写作工作台 / 重命名场景弹窗 / 深色` → `wjCFR`
- `写作工作台 / 删除场景确认 / 深色` → `9EUv4`
- `AI Revision Confirmation / Continue Mode / 深色` → `GLk16`
- `写作工作台 / AI 接受失败 / 深色` → `XhEGm`
- `写作工作台 / 模拟进行中 / 深色` → `APFtI`
- `写作工作台 / AI 可用 / 深色` → `aOczr`
- `写作工作台 / AI 历史有内容 / 深色` → `yo9In`
- `风格面板 / JSON 模式 / 深色` → `HURTB`
- `风格面板 / 项目默认已绑定 / 深色` → `hK7Ud`
- `Audit Center / Resolved Feedback / 深色` → `PSDTH`
- `Audit Center / Ignore Feedback / 深色` → `Hqgfj`
- `Simulation Monitor / Edit Prompt / 深色` → `SVryJ`
- `Simulation Monitor / Director Feedback Applied / 深色` → `RRIRw`

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

- `设置 / 缺少密钥`
  - 正式基线：`6yJaH`
  - 废弃探索稿：`9izFv`
  - 判定依据：`9izFv` 画面不完整，缺少中间缺失说明与右侧说明区

## 里程碑建议

### M1 壳层与主工作台

- 覆盖：
  - `写作工作台`
  - `写作工作台 / 默认隐藏`
  - `写作工作台 / 导航抽屉打开`
  - `写作工作台 / 缺少密钥`
  - `写作工作台 / 缺少角色绑定`
  - `写作工作台 / 角色引用缺失`
  - `写作工作台 / 世界观引用缺失`
- 完成标准：
  - 左侧隐藏 `menu drawer`、顶部 `breadcrumb`、右侧工具条都稳定
  - 正文编辑区可持续保持主视觉中心
  - 所有工作台阻断 / 轻提示态都不打断正文上下文

### M2 AI 修改流

- 覆盖：
  - `写作工作台 / AI 工具已选择`
  - `写作工作台 / AI 工具选择打开`
  - `写作工作台 / 选择范围重叠`
  - `写作工作台 / AI 修改失败`
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
  - `Simulation Monitor / 空状态`
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
