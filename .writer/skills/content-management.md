# Content Management Skill

## Goal

创建、列出和管理作品与卷的结构，以及在作品中搜索内容。

## Required Checks

- 创建作品时必须有名称
- 创建卷时必须有 work_id 和名称
- 搜索查询应足够具体，避免返回过多结果
- list 操作无需额外参数即可执行

## Output Rules

- 创建操作必须返回明确的对象 ID 和名称
- 列表操作应按逻辑顺序展示（如卷按 sortOrder）
- 搜索结果应按相关性排序，标明匹配类型
- 所有操作都应包含错误处理和状态反馈
- 作品简介必须通过 safety gate 检查，不接受占位内容
