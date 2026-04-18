# Hook: Pre Request Validate

## Trigger

模型请求发出之前。

## Checks

- 当前任务类型是否明确
- workId 是否存在或允许为空
- 是否需要装载已存事实
- 是否存在明显超长上下文

## Result

- 通过则进入模型调用
- 不通过则先补齐输入或缩减上下文
