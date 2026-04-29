# Frame / State Coverage

本文档记录当前 `.pen` 画布中已经落地的顶层页面与状态图，用于确保设计稿、PRD 和交付范围一致。

## 核心页面

- `Project List`
- `Sandbox Monitor`
- `Writing Workbench`
- `Style Panel`
- `Settings & BYOK`
- `UI Foundation`
- `Character Library`
- `Worldbuilding`
- `Audit Center`
- `Project Import Export`

## 补充页面

- `Scene Management`

## 场景管理状态

- `Scene Management / Create Scene`
- `Scene Management / Rename Scene`
- `Scene Management / Delete Scene Confirm`
- `Scene Management / Edit Chapter Label`
- `Scene Management / Edit Summary`
- `Scene Management / Move Scene`

## 工作台状态

- `Writing Workbench / Default Hidden`
- `Writing Workbench / Resources Open`
- `Writing Workbench / AI Selected Tool`
- `Writing Workbench / AI Tool Picker Open`
- `Writing Workbench / AI Settings Read Failed`
- `Writing Workbench / AI Settings Write Failed`
- `Writing Workbench / AI Ready After Recovery`
- `Writing Workbench / Create Scene Dialog`
- `Writing Workbench / Rename Scene Dialog`
- `Writing Workbench / Delete Scene Confirm`
- `Writing Workbench / Menu Drawer Open`
- `Writing Workbench / Missing Character Binding`
- `Writing Workbench / AI Modify Failed`
- `Writing Workbench / AI Accept Failed`
- `Writing Workbench / API Key Missing`
- `Writing Workbench / No Simulation Yet`
- `Writing Workbench / Overlapping Selections`
- `Writing Workbench / Simulation Completed`
- `Writing Workbench / Simulation Failed Summary`
- `Writing Workbench / Context Synced`
- `Writing Workbench / Missing Character Reference`
- `Writing Workbench / Missing World Reference`
- `Writing Workbench / Simulation In Progress`
- `Writing Workbench / AI Ready`
- `Writing Workbench / AI History Populated`

## AI / 编辑流状态

- `AI Revision Confirmation / Batch Review`
- `AI Revision Confirmation / Three Blocks`
- `AI Revision Confirmation / Continue Mode`
- `AI Revision Confirmation / All Excluded`
- `AI Revision Confirmation / Restore Excluded Block`

## 全局 Shell 状态

- `Global Shell / Settings File Read Failed`
- `Global Shell / Settings File Write Failed`

## 提示 / 轻警告状态

- `Style Panel / Scene Override Notice`
- `Style Panel / Unknown Fields Ignored`
- `Project Import Export / Minor Version Warning`

## 成功 / 完成状态

- `Project Import Export / Import Success`
- `Project Import Export / Export Success`
- `Project Import Export / Overwrite Success`
- `Settings / Retry Read Success`
- `Settings / Retry Write Success`
- `Settings / Save Success`
- `Settings / Connection Test Success`

## 风格 / 导入阻断状态

- `Project Import Export / Major Version Blocked`
- `Project Import Export / No Exportable Project`

## 阅读与版本状态

- `Reading Mode / Pure Reader`
- `Reading Mode / Single Page`
- `Reading Mode / Chapter Boundary`
- `Reading Mode / Previous Chapter Boundary`
- `Reading Mode / No Previous Chapter`
- `Reading Mode / No Next Chapter`
- `Chapter Versions / Recent Five`
- `Chapter Versions / History AI Expanded`
- `Chapter Versions / Expanded State Remembered`
- `Chapter Versions / Single Version`
- `Chapter Versions / Oldest Pending Eviction`
- `Chapter Versions / Pending Save Before Eviction`
- `Chapter Versions / Restore Failed`
- `Chapter Versions / Restore Success`

## 风格面板动态状态

- `Style Panel / JSON Mode`
- `Style Panel / Project Default Bound`

## 空状态

- `Project List / Empty`
- `Project List / Search No Results`
- `Audit Center / Empty`
- `Audit Center / Filter No Results`
- `Character Library / Empty`
- `Character Library / Search No Results`
- `Worldbuilding / Empty`
- `Worldbuilding / Filter No Results`
- `Style Panel / Empty`
- `Settings / Unconfigured`
- `Simulation Monitor / Empty`

## 审计反馈状态

- `Audit Center / Resolved Feedback`
- `Audit Center / Ignore Feedback`

## 模拟交互状态

- `Simulation Monitor / Edit Prompt`
- `Simulation Monitor / Director Feedback Applied`

## 错误 / 限制 / 确认状态

- `Audit Center / Related Draft Missing`
- `Audit Center / Jump Failed`
- `Simulation Monitor / Agent No Output`
- `Simulation Monitor / Failed`
- `Simulation Monitor / Phase Refresh`
- `Style Panel / JSON Error`
- `Style Panel / Unsupported JSON Version`
- `Style Panel / Missing Required Fields`
- `Style Panel / Validation Failed`
- `Style Panel / Max Profiles Reached`
- `Settings / File Read Failed`
- `Settings / File Write Failed`
- `Settings / Connection Failed`
- `Settings / Connection Timeout`
- `Settings / Missing API Key`
- `Settings / Invalid Base URL`
- `Settings / Missing Model`
- `Settings / Unsupported Model`
- `Settings / Unauthorized`
- `Settings / Provider Model Not Found`
- `Settings / Network Error`
- `Settings / Legacy Migration Warning`
- `Project List / Database Read Failed`
- `Project List / Import Failed`
- `Project List / Delete Confirm`
- `Project Import Export / Overwrite Confirm`
- `Project Import Export / Invalid Package`
- `Project Import Export / Missing Manifest`
- `Character Library / Missing Required Fields`
- `Worldbuilding / Missing Type`
- `Worldbuilding / Delete Parent Confirm`
- `Character Library / Delete Referenced Confirm`

## Dark 变体

- `Scene Management / Dark`
- `Scene Management / Create Scene / Dark`
- `Scene Management / Rename Scene / Dark`
- `Scene Management / Delete Scene Confirm / Dark`
- `Scene Management / Edit Chapter Label / Dark`
- `Scene Management / Edit Summary / Dark`
- `Scene Management / Move Scene / Dark`
- `Global Shell / Settings File Read Failed / Dark`
- `Global Shell / Settings File Write Failed / Dark`
- `Project Import Export / Export Success / Dark`
- `Settings / Connection Test Success / Dark`
- `Settings / Legacy Migration Warning / Dark`
- `Settings / File Read Failed / Dark`
- `Settings / File Write Failed / Dark`
- `Settings / Retry Read Success / Dark`
- `Settings / Retry Write Success / Dark`
- `Settings / Connection Timeout / Dark`
- `Writing Workbench / AI Settings Read Failed / Dark`
- `Writing Workbench / AI Settings Write Failed / Dark`
- `Writing Workbench / AI Ready After Recovery / Dark`
- `Writing Workbench / Create Scene Dialog / Dark`
- `Writing Workbench / Rename Scene Dialog / Dark`
- `Writing Workbench / Delete Scene Confirm / Dark`
- `AI Revision Confirmation / Continue Mode / Dark`
- `Writing Workbench / AI Accept Failed / Dark`
- `Writing Workbench / Simulation In Progress / Dark`
- `Writing Workbench / AI Ready / Dark`
- `Writing Workbench / AI History Populated / Dark`
- `Style Panel / JSON Mode / Dark`
- `Style Panel / Project Default Bound / Dark`
- `Audit Center / Resolved Feedback / Dark`
- `Audit Center / Ignore Feedback / Dark`
- `Simulation Monitor / Edit Prompt / Dark`
- `Simulation Monitor / Director Feedback Applied / Dark`

## 说明

- 所有工作台相关页面已统一使用左侧自动隐藏 `menu drawer` 把手。
- 项目结构导航统一通过 `breadcrumb` 表达，不再放进 `menu drawer`。
- 版本页遵循"最近 5 个版本"的策略。
- AI 修改流遵循"整包确认、可逐段排除、接受后只生成 1 个章节版本"的策略。
- 画布中存在少量早期重名探索稿，当前以较新的可用版本为准：
  - `Project List / Search No Results` 以 `az4YP` 为准，旧稿 `UbuvO` 不作为交付基线。
  - `Settings / Missing API Key` 以 `6yJaH` 为准，旧稿 `9izFv` 不作为交付基线。
