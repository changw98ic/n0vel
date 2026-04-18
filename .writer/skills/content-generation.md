# Content Generation Skill

## Goal

生成小说文本和从文本中提取结构化设定信息。

## Required Checks

- 生成模式必须明确（continuation/dialogue/scene/custom）
- 提取类型必须明确（characters/locations/items/events/all）
- 输入内容必须充分，避免在信息不足时生成
- 提取结果需关联到指定作品（若提供 work_id）

## Output Rules

- 生成文本应保持与上下文的风格一致性
- 提取结果应保持结构化格式，便于后续创建实体
- 生成内容长度应符合用户要求
- 所有生成内容应通过 safety gate 检查
- 提取的实体信息应包含足够的属性字段，避免只返回名称列表
