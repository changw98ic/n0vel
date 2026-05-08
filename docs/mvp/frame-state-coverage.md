# 画面状态覆盖

本文档记录当前 `.pen` 画布中已经落地的顶层页面与状态图，用于确保设计稿、PRD 和交付范围一致。

## 核心页面

- `Project List`
- `Sandbox Monitor`
- `写作工作台`
- `风格面板`
- `设置与自带密钥`
- `UI Foundation`
- `Character Library`
- `Worldbuilding`
- `Audit Center`
- `Project Import Export`

## 补充页面

- `Scene Management`
- `设定摘要 / 聚合事实`
- `Production Board / Progress Loop`
- `Review Tasks / Queue States`

## 场景管理状态

- `Scene Management / Create Scene`
- `Scene Management / Rename Scene`
- `Scene Management / 删除场景确认`
- `Scene Management / Edit Chapter Label`
- `Scene Management / Edit Summary`
- `Scene Management / Move Scene`

## 工作台状态

- `写作工作台 / 默认隐藏`
- `写作工作台 / 资源面板打开`
- `写作工作台 / AI 工具已选择`
- `写作工作台 / AI 工具选择打开`
- `写作工作台 / AI 设置 Read Failed`
- `写作工作台 / AI 设置 Write Failed`
- `写作工作台 / AI 恢复后可用`
- `写作工作台 / 创建场景弹窗`
- `写作工作台 / 重命名场景弹窗`
- `写作工作台 / 删除场景确认`
- `写作工作台 / 导航抽屉打开`
- `写作工作台 / 完整导航抽屉`
- `写作工作台 / 缺少角色绑定`
- `写作工作台 / AI 修改失败`
- `写作工作台 / AI 接受失败`
- `写作工作台 / 缺少密钥`
- `写作工作台 / 暂无模拟`
- `写作工作台 / 选择范围重叠`
- `写作工作台 / 模拟完成`
- `写作工作台 / 模拟失败摘要`
- `写作工作台 / 上下文已同步`
- `写作工作台 / 角色引用缺失`
- `写作工作台 / 世界观引用缺失`
- `写作工作台 / 模拟进行中`
- `写作工作台 / AI 可用`
- `写作工作台 / AI 历史有内容`

## AI / 编辑流状态

- `AI Revision Confirmation / Batch Review`
- `AI Revision Confirmation / Three Blocks`
- `AI Revision Confirmation / Continue Mode`
- `AI Revision Confirmation / All Excluded`
- `AI Revision Confirmation / Restore Excluded Block`

## 全局 Shell 状态

- `Global Shell / 设置 File Read Failed`
- `Global Shell / 设置 File Write Failed`

## UI 对齐补充状态

- `Project List / Responsive Shelf Fit`
- `Project Import Export / Contained Long Paths`

## 提示 / 轻警告状态

- `风格面板 / 场景覆盖提醒`
- `风格面板 / 未知字段已忽略`
- `Project Import Export / Minor Version Warning`

## 成功 / 完成状态

- `Project Import Export / Import Success`
- `Project Import Export / Export Success`
- `Project Import Export / Overwrite Success`
- `设置 / 重新读取成功`
- `设置 / 重新写入成功`
- `设置 / 保存成功`
- `设置 / 连接测试成功`

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

- `风格面板 / JSON 模式`
- `风格面板 / 项目默认已绑定`

## 空状态

- `Project List / 空状态`
- `Project List / Search No Results`
- `Audit Center / 空状态`
- `Audit Center / Filter No Results`
- `Character Library / 空状态`
- `Character Library / Search No Results`
- `Worldbuilding / 空状态`
- `Worldbuilding / Filter No Results`
- `风格面板 / 空状态`
- `设置 / 未配置`
- `Simulation Monitor / 空状态`

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
- `风格面板 / JSON 错误`
- `风格面板 / JSON 版本不支持`
- `风格面板 / 缺少必填项`
- `风格面板 / 校验失败`
- `风格面板 / 风格档案达到上限`
- `设置 / 配置读取失败`
- `设置 / 配置写入失败`
- `设置 / 连接失败`
- `设置 / 连接超时`
- `设置 / 缺少密钥`
- `设置 / 接口地址无效`
- `设置 / 缺少模型`
- `设置 / 模型不受支持`
- `设置 / 鉴权失败`
- `设置 / 模型服务缺少模型`
- `设置 / 网络错误`
- `设置 / 旧配置迁移提醒`
- `Project List / Database Read Failed`
- `Project List / Import Failed`
- `Project List / Delete Confirm`
- `Project Import Export / Overwrite Confirm`
- `Project Import Export / Invalid Package`
- `Project Import Export / Missing Manifest`
- `Character Library / 缺少必填项`
- `Worldbuilding / Missing Type`
- `Worldbuilding / Delete Parent Confirm`
- `Character Library / Delete Referenced Confirm`

## 深色 变体

- `Scene Management / 深色`
- `Scene Management / Create Scene / 深色`
- `Scene Management / Rename Scene / 深色`
- `Scene Management / 删除场景确认 / 深色`
- `Scene Management / Edit Chapter Label / 深色`
- `Scene Management / Edit Summary / 深色`
- `Scene Management / Move Scene / 深色`
- `Global Shell / 设置 File Read Failed / 深色`
- `Global Shell / 设置 File Write Failed / 深色`
- `Project Import Export / Export Success / 深色`
- `设置 / 连接测试成功 / 深色`
- `设置 / 旧配置迁移提醒 / 深色`
- `设置 / 配置读取失败 / 深色`
- `设置 / 配置写入失败 / 深色`
- `设置 / 重新读取成功 / 深色`
- `设置 / 重新写入成功 / 深色`
- `设置 / 连接超时 / 深色`
- `写作工作台 / AI 设置 Read Failed / 深色`
- `写作工作台 / AI 设置 Write Failed / 深色`
- `写作工作台 / AI 恢复后可用 / 深色`
- `写作工作台 / 创建场景弹窗 / 深色`
- `写作工作台 / 重命名场景弹窗 / 深色`
- `写作工作台 / 删除场景确认 / 深色`
- `AI Revision Confirmation / Continue Mode / 深色`
- `写作工作台 / AI 接受失败 / 深色`
- `写作工作台 / 模拟进行中 / 深色`
- `写作工作台 / AI 可用 / 深色`
- `写作工作台 / AI 历史有内容 / 深色`
- `风格面板 / JSON 模式 / 深色`
- `风格面板 / 项目默认已绑定 / 深色`
- `Audit Center / Resolved Feedback / 深色`
- `Audit Center / Ignore Feedback / 深色`
- `Simulation Monitor / Edit Prompt / 深色`
- `Simulation Monitor / Director Feedback Applied / 深色`

## 说明

- 所有工作台相关页面已统一使用左侧自动隐藏 `menu drawer` 把手。
- 项目结构导航统一通过 `breadcrumb` 表达，不再放进 `menu drawer`。
- 版本页遵循"最近 5 个版本"的策略。
- AI 修改流遵循"整包确认、可逐段排除、接受后只生成 1 个章节版本"的策略。
- 画布中存在少量早期重名探索稿，当前以较新的可用版本为准：
  - `Project List / Search No Results` 以 `az4YP` 为准，旧稿 `UbuvO` 不作为交付基线。
  - `设置 / 缺少密钥` 以 `6yJaH` 为准，旧稿 `9izFv` 不作为交付基线。
