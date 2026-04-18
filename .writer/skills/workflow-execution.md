# Workflow Execution Skill

## Goal

按阶段执行工作流任务，并保证中间状态可恢复、最终结果可追踪。

## Required Checks

- 输入变量是否完整
- 节点顺序是否满足依赖关系
- 是否需要从 checkpoint 恢复
- 是否需要审查节点给出通过/重做结论

## Output Rules

- 执行过程应保留关键状态
- 节点失败必须返回可诊断错误
- 最终输出必须区分过程数据与最终结果
