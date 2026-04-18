# AI Config Module

## Scope

AI 模型配置管理：模型参数、函数映射、提示词模板。

## Rules

- 模型配置应支持多 provider 切换和参数调整
- 函数映射需明确定义每个 AIFunction 对应的模型层级（thinking/middle/fast）
- 提示词模板应支持变量替换
- 配置更改应立即生效，无需重启
- 使用统计需按模型、功能和时间维度统计
