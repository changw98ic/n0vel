# Timeline Module

## Scope

故事事件时间线管理：事件排序、冲突检测。

## Rules

- 事件应按故事内时间自动排序
- 冲突检测需关注时间重叠和逻辑矛盾
- 过滤功能应支持按类型和重要性筛选
- 视图切换应保持当前过滤状态
- 时间线提取使用 AIFunction.timelineExtract
