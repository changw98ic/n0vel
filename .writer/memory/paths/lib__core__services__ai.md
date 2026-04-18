# Path Memory: lib/core/services/ai

## Scope

适用于核心 AI 服务、上下文管理、工具调用与 Agent 编排相关逻辑。

## Path Rules

- 该区域负责模型请求编排，不应成为业务规则的唯一真相源。
- 默认 system prompt 可以存在兜底，但产品规则应优先来自 `writer.md` 与 `.writer/`。
- 上下文装载、工具调用、压缩与审查应尽量解耦。
