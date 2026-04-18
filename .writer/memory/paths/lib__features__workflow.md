# Path Memory: lib/features/workflow

## Scope

适用于工作流任务、节点执行、检查点与结果恢复相关逻辑。

## Path Rules

- 工作流上下文必须可恢复。
- 节点状态、检查点和最终结果应分层存储。
- 该区域的模型调用优先装载 workflow 模块记忆与 workflow skill。
