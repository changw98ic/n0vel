# MVP 里程碑验收清单

本文档用于配合 [MVP 实现交接稿](/Users/chengwen/dev/novel-wirter/docs/mvp/implementation-handoff.md)，帮助研发在每个里程碑完成后做一致性检查。

## M1 壳层与主工作台

### 需对齐的 frame

- `Writing Workbench` → `47nGt`
- `Writing Workbench / Default Hidden` → `WT5mH`
- `Writing Workbench / Menu Drawer Open` → `i2PgM`
- `Writing Workbench / API Key Missing` → `y6Ufy`
- `Writing Workbench / Missing Character Binding` → `o6hOU`
- `Writing Workbench / Missing Character Reference` → `WmFpE`
- `Writing Workbench / Missing World Reference` → `emCHR`

### 验收项

- 左侧 `menu drawer` 默认仅显示贴边把手，展开后只包含 `Dashboard / 编辑工作台 / 设置`
- 顶部使用 `breadcrumb` 表达项目结构，不把项目结构塞回 `menu drawer`
- 右侧工具条只承载工作工具，不承担全局导航
- 工作台阻断态都保留正文上下文，不跳转独立页面
- `API Key Missing`、角色引用失效、世界观引用失效都能在工作台内就地提示

## M2 AI 修改流

### 需对齐的 frame

- `Writing Workbench / AI Selected Tool` → `XBhIG`
- `Writing Workbench / AI Tool Picker Open` → `AMlNT`
- `Writing Workbench / Overlapping Selections` → `go6Qc`
- `Writing Workbench / AI Modify Failed` → `FPMUS`
- `AI Revision Confirmation / Batch Review` → `XYBaG`
- `AI Revision Confirmation / Three Blocks` → `XkB5L`
- `AI Revision Confirmation / All Excluded` → `rQbOu`
- `AI Revision Confirmation / Restore Excluded Block` → `8JkLW`

### 验收项

- 输入框内 `+` 可以打开工具选择层
- 工具箱是单选，不允许同一轮同时带多个工具
- AI 返回结果后必须先进入确认弹窗，不能直接改正文
- 逐段排除后仍按一整轮只生成 `1` 个章节版本
- 已排除块支持恢复
- 全部排除后必须阻止提交
- 选区重叠时必须阻止请求发出
- AI 修改失败时必须明确说明正文未改动、版本未生成

## M3 阅读与版本

### 需对齐的 frame

- `Reading Mode / Pure Reader` → `GD63C`
- `Reading Mode / Single Page` → `WGzHM`
- `Reading Mode / Chapter Boundary` → `Cz57s`
- `Reading Mode / Previous Chapter Boundary` → `mDkBH`
- `Reading Mode / No Previous Chapter` → `ATuaL`
- `Reading Mode / No Next Chapter` → `cqffu`
- `Chapter Versions / Recent Five` → `Ym6ea`
- `Chapter Versions / Expanded State Remembered` → `uHxFC`
- `Chapter Versions / Pending Save Before Eviction` → `rr4J7`
- `Chapter Versions / Restore Failed` → `XEwpS`
- `Chapter Versions / Restore Success` → `pblhy`

### 验收项

- 进入纯净阅读后是独立视图，不是工作台内嵌层
- 退出纯净阅读能按 `章节 -> 滚动位置 -> 光标锚点` 顺序恢复
- 单页阅读态不会显示空白分页器
- 首章 / 终章边界都要有独立提示
- 版本池始终最多显示最近 `5` 个版本
- 最旧版本只在新版本落盘成功后才淘汰
- 恢复旧版本会生成一个新的当前版本，而不是覆写历史版本
- 历史 AI 变更的展开 / 折叠状态按版本记忆

## M4 模拟与导入导出

### 需对齐的 frame

- `Sandbox Monitor` → `YTrUo`
- `Simulation Monitor / Empty` → `fBn5z`
- `Simulation Monitor / Agent No Output` → `JJh0t`
- `Simulation Monitor / Failed` → `GtV8t`
- `Simulation Monitor / Phase Refresh` → `Fekvk`
- `Project Import Export` → `z0mJ1`
- `Project Import Export / Import Success` → `aYhVV`
- `Project Import Export / Overwrite Success` → `XrBiQ`
- `Project Import Export / Overwrite Confirm` → `kJVPV`
- `Project Import Export / Missing Manifest` → `f4cfp`
- `Project Import Export / Major Version Blocked` → `nJ1Vf`
- `Project Import Export / Minor Version Warning` → `sqxPi`
- `Project Import Export / No Exportable Project` → `O5g2A`

### 验收项

- 模拟过程是工作台上的弹窗，不是单独页面导航
- 模拟运行中采用分阶段整批刷新，不做逐字流式抖动
- 模拟完成 / 失败后，工作台都能收到轻摘要回传
- 导入成功后必须有明确的成功摘要态
- 覆盖导入成功后必须明确说明旧索引已被替换刷新
- `manifest.json` 缺失、`schema_major` 不一致必须使用专用阻断态
- `schema_minor` 不一致只能做轻警告，不能误做阻断

## M5 设置与资料页

### 需对齐的 frame

- `Settings & BYOK` → `DnwrZ`
- `Settings / Unconfigured` → `WwWEh`
- `Settings / Missing API Key` → `6yJaH`
- `Settings / Missing Model` → `NVC2a`
- `Settings / Invalid Base URL` → `hroTw`
- `Settings / Unsupported Model` → `YwhiQ`
- `Settings / Connection Failed` → `URbAX`
- `Settings / Unauthorized` → `yRdSE`
- `Settings / Provider Model Not Found` → `1KpPn`
- `Settings / Network Error` → `BtJNK`
- `Settings / Save Success` → `HcPSf`
- `Character Library` / `Worldbuilding` / `Audit Center` 及其关键状态

### 验收项

- 设置保存成功后，新配置只对下一次 AI 请求生效
- 已失败请求不会自动重试
- `401/403`、`404 model_not_found`、`DNS/网络错误` 要映射成不同错误态
- 角色与世界观保存成功后，工作台相关摘要立即刷新
- 必填字段缺失时，高亮缺失字段并阻止索引写入
- 删除被引用资料后，工作台必须出现失效引用提示

## 建议执行方式

- 每完成一个里程碑，就按本清单逐项走一遍
- UI 对齐优先参考 [implementation-handoff.md](/Users/chengwen/dev/novel-wirter/docs/mvp/implementation-handoff.md)
- 状态归类优先参考 [frame-state-coverage.md](/Users/chengwen/dev/novel-wirter/docs/mvp/frame-state-coverage.md)
- 若实现与 frame 不一致，优先修实现，不要先改 PRD 迁就代码
