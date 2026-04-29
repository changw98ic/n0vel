# MVP 运行时 Smoke Test 清单

本文档用于在实现阶段或联调阶段，快速验证这套 MVP 是否已经具备“可用”的主流程行为。

与 [MVP 里程碑验收清单](/Users/chengwen/dev/novel-wirter/docs/mvp/milestone-verification-checklist.md) 不同，这里更强调端到端运行结果，而不是单页对齐。

## Smoke 01 工作台打开

### 相关 frame

- `47nGt` `Writing Workbench`
- `WT5mH` `Writing Workbench / Default Hidden`
- `i2PgM` `Writing Workbench / Menu Drawer Open`

### 相关文档

- [PRD 02 写作工作台](/Users/chengwen/dev/novel-wirter/docs/mvp/prd/prd-02-writing-workbench.md)
- [MVP 实现交接稿](/Users/chengwen/dev/novel-wirter/docs/mvp/implementation-handoff.md)

### 前置

- 本地已有至少一个项目
- 可进入 `Writing Workbench`

### 检查步骤

1. 打开任意项目并进入工作台
2. 确认左侧只显示隐藏 `menu drawer` 把手
3. 确认顶部显示 `breadcrumb`
4. 确认右侧工具条存在且可见

### 通过标准

- 正文是主视觉中心
- `menu drawer`、`breadcrumb`、右侧工具条层级清楚

## Smoke 02 AI 改写阻断

### 相关 frame

- `go6Qc` `Writing Workbench / Overlapping Selections`

### 相关文档

- [PRD 02 写作工作台](/Users/chengwen/dev/novel-wirter/docs/mvp/prd/prd-02-writing-workbench.md)

### 前置

- 当前工作台中制造一个重叠选区

### 检查步骤

1. 在正文里创建多个重叠选区
2. 发起一次 AI 修改

### 通过标准

- 请求不发出
- 出现 `Writing Workbench / Overlapping Selections`
- 正文不改动

## Smoke 03 AI 修改确认与恢复

### 相关 frame

- `XYBaG` `AI Revision Confirmation / Batch Review`
- `XkB5L` `AI Revision Confirmation / Three Blocks`
- `8JkLW` `AI Revision Confirmation / Restore Excluded Block`
- `rQbOu` `AI Revision Confirmation / All Excluded`

### 相关文档

- [PRD 02 写作工作台](/Users/chengwen/dev/novel-wirter/docs/mvp/prd/prd-02-writing-workbench.md)

### 前置

- 当前工作台可正常返回 AI 修改结果

### 检查步骤

1. 发起一次包含多个修改块的 AI 修改
2. 在确认弹窗里排除其中一个修改块
3. 恢复该修改块
4. 接受变更

### 通过标准

- 已排除块可恢复
- 接受后只生成 `1` 个章节版本
- 正文只在接受后改动

## Smoke 04 无模拟记录

### 相关 frame

- `ea0WQ` `Writing Workbench / No Simulation Yet`
- `fBn5z` `Simulation Monitor / Empty`

### 相关文档

- [PRD 02 写作工作台](/Users/chengwen/dev/novel-wirter/docs/mvp/prd/prd-02-writing-workbench.md)
- [PRD 03 模拟过程弹窗](/Users/chengwen/dev/novel-wirter/docs/mvp/prd/prd-03-sandbox-monitor.md)

### 前置

- 当前章节从未运行过 `SimulationRun`

### 检查步骤

1. 打开工作台
2. 尝试查看模拟过程

### 通过标准

- 工作台显示轻提示，而不是弹空壳监视器页
- 不打断正文编辑

## Smoke 05 模拟完成回传

### 相关 frame

- `O5wWx` `Writing Workbench / Simulation Completed`
- `YTrUo` `Sandbox Monitor`

### 相关文档

- [PRD 02 写作工作台](/Users/chengwen/dev/novel-wirter/docs/mvp/prd/prd-02-writing-workbench.md)
- [PRD 03 模拟过程弹窗](/Users/chengwen/dev/novel-wirter/docs/mvp/prd/prd-03-sandbox-monitor.md)

### 前置

- 当前章节成功运行一次 `SimulationRun`

### 检查步骤

1. 完成模拟
2. 返回工作台
3. 观察顶部摘要条
4. 从摘要条进入模拟过程

### 通过标准

- 工作台出现完成摘要
- 能再次打开同一轮模拟结果

## Smoke 06 模拟失败回传

### 相关 frame

- `dSehn` `Writing Workbench / Simulation Failed Summary`
- `GtV8t` `Simulation Monitor / Failed`

### 相关文档

- [PRD 02 写作工作台](/Users/chengwen/dev/novel-wirter/docs/mvp/prd/prd-02-writing-workbench.md)
- [PRD 03 模拟过程弹窗](/Users/chengwen/dev/novel-wirter/docs/mvp/prd/prd-03-sandbox-monitor.md)

### 前置

- 当前章节运行一次会失败的 `SimulationRun`

### 检查步骤

1. 触发失败模拟
2. 返回工作台
3. 打开失败详情

### 通过标准

- 工作台出现失败摘要
- 明确说明正文未改动
- 失败详情可再次查看

## Smoke 07 阅读器返回锚点

### 相关 frame

- `GD63C` `Reading Mode / Pure Reader`
- `WGzHM` `Reading Mode / Single Page`
- `mDkBH` `Reading Mode / Previous Chapter Boundary`
- `cqffu` `Reading Mode / No Next Chapter`

### 相关文档

- [PRD 11 纯净阅读态](/Users/chengwen/dev/novel-wirter/docs/mvp/prd/prd-11-reading-mode.md)

### 前置

- 工作台已有明确的滚动位置与光标位置

### 检查步骤

1. 从工作台进入 `Reading Mode`
2. 翻页数次
3. 关闭阅读器

### 通过标准

- 返回到进入前的章节 / Scene
- 滚动位置恢复
- 光标或选区锚点恢复

## Smoke 08 版本恢复

### 相关 frame

- `Ym6ea` `Chapter Versions / Recent Five`
- `XEwpS` `Chapter Versions / Restore Failed`
- `pblhy` `Chapter Versions / Restore Success`
- `rr4J7` `Chapter Versions / Pending Save Before Eviction`

### 相关文档

- [PRD 08 章节版本页](/Users/chengwen/dev/novel-wirter/docs/mvp/prd/prd-08-version-history.md)

### 前置

- 当前章节至少有 2 个可恢复版本

### 检查步骤

1. 进入 `Chapter Versions`
2. 恢复一个历史版本

### 通过标准

- 新增一个“恢复版本”作为当前版本
- 原历史版本仍保留
- 若版本池已满，最旧版本只在恢复结果落盘成功后淘汰

## Smoke 09 导入成功

### 相关 frame

- `aYhVV` `Project Import Export / Import Success`

### 相关文档

- [PRD 09 工程导入导出页](/Users/chengwen/dev/novel-wirter/docs/mvp/prd/prd-09-project-import-export.md)

### 前置

- 准备一个合法工程包

### 检查步骤

1. 在导入导出页执行导入
2. 观察成功摘要
3. 点击 `打开项目`

### 通过标准

- 成功摘要出现
- 明确显示索引刷新完成
- 可直接进入导入后的项目

## Smoke 10 覆盖导入成功

### 相关 frame

- `XrBiQ` `Project Import Export / Overwrite Success`
- `kJVPV` `Project Import Export / Overwrite Confirm`

### 相关文档

- [PRD 09 工程导入导出页](/Users/chengwen/dev/novel-wirter/docs/mvp/prd/prd-09-project-import-export.md)

### 前置

- 准备一个会命中当前项目 ID 的工程包

### 检查步骤

1. 选择覆盖导入
2. 完成确认
3. 观察覆盖成功摘要

### 通过标准

- 旧索引被替换刷新
- 角色 / 世界观 / 风格 / 版本 / 最近写作位置同步更新

## Smoke 11 设置保存后生效

### 相关 frame

- `HcPSf` `Settings / Save Success`
- `DnwrZ` `Settings & BYOK`

### 相关文档

- [PRD 10 设置与 BYOK 页](/Users/chengwen/dev/novel-wirter/docs/mvp/prd/prd-10-settings-byok.md)

### 前置

- 已修改一组有效 Provider 配置

### 检查步骤

1. 保存配置
2. 观察保存成功状态
3. 回到工作台重新发起一次 AI 请求

### 通过标准

- 保存成功后提示“下一次 AI 请求生效”
- 已失败旧请求不会自动重试
- 下一次新请求读取新配置

## Smoke 12 引用失效回收

### 相关 frame

- `WmFpE` `Writing Workbench / Missing Character Reference`
- `emCHR` `Writing Workbench / Missing World Reference`
- `bRkQL` `Character Library / Delete Referenced Confirm`
- `CQycp` `Worldbuilding / Delete Parent Confirm`

### 相关文档

- [PRD 02 写作工作台](/Users/chengwen/dev/novel-wirter/docs/mvp/prd/prd-02-writing-workbench.md)
- [PRD 04 角色库页](/Users/chengwen/dev/novel-wirter/docs/mvp/prd/prd-04-character-library.md)
- [PRD 05 世界观页](/Users/chengwen/dev/novel-wirter/docs/mvp/prd/prd-05-worldbuilding.md)

### 前置

- 删除一个被工作台场景引用的角色或世界观节点

### 检查步骤

1. 删除被引用资料
2. 回到对应工作台场景

### 通过标准

- 工作台出现引用失效提示
- 正文仍可继续编辑
- 相关摘要 / 约束 / 模拟入口进入失效状态
