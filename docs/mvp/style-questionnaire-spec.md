# 风格问卷规格说明

本文档用于把 MVP 的“风格问卷”细化成可直接开发的字段表、问卷分支逻辑、校验规则和 `StyleProfile` 映射规则。

适用范围：

- MVP
- 中文写作
- 本地客户端
- 问卷模式创建 `StyleProfile`

不适用范围：

- 文本自动抽取风格
- LoRA / 微调
- 多语言风格问卷

## 1. 目标

风格问卷的目标不是模拟某位作者，而是帮助作者以结构化方式声明：

- 这本书希望呈现怎样的语言面貌
- 当前项目偏向哪类叙事视角和节奏
- 生成时应该优先强化哪些表达特征
- 生成时必须避免哪些表达习惯

风格问卷的输出固定为：

- 一个可预览的 `StyleProfile`
- 一个可序列化的 `StyleProfileJson`

## 2. 问卷结构

问卷固定拆为 6 个区块：

1. 基础定位
2. 叙事视角
3. 语言与节奏
4. 对话与描写
5. 情绪与氛围
6. 禁忌与额外说明

问卷 UI 建议采用：

- 单页分组折叠表单
- 必填字段实时校验
- 右侧实时预览 `StyleProfile`

## 3. 字段表

### 3.1 基础定位

| 字段 ID | 标签 | 类型 | 必填 | 可选值 / 规则 | 默认值 | 映射字段 |
| --- | --- | --- | --- | --- | --- | --- |
| `profile_name` | 风格名称 | text | 是 | 2-30 字 | 空 | `name` |
| `language` | 写作语言 | enum | 是 | MVP 固定 `zh-CN` | `zh-CN` | `language` |
| `genre_tags` | 主要体裁 | multi-select | 是 | 1-3 项；`玄幻/仙侠/科幻/悬疑/惊悚/现实/言情/历史/校园/都市` | 空 | `genre_tags` |
| `audience_tone` | 阅读感受 | multi-select | 否 | 最多 3 项；`热血/压抑/轻快/冷峻/浪漫/黑暗/史诗/日常` | 空 | `tone_keywords` |

### 3.2 叙事视角

| 字段 ID | 标签 | 类型 | 必填 | 可选值 / 规则 | 默认值 | 映射字段 |
| --- | --- | --- | --- | --- | --- | --- |
| `pov_mode` | 叙事视角 | enum | 是 | `first_person_limited` / `third_person_limited` / `third_person_multi` | `third_person_limited` | `pov_mode` |
| `narrative_distance` | 叙事距离 | enum | 是 | `close` / `medium` / `far` | `close` | `narrative_distance` |
| `inner_monologue_ratio` | 心理描写比例 | enum | 是 | `low` / `medium` / `high` | `medium` | 归一化后影响 `description_density` 与预览说明 |

### 3.3 语言与节奏

| 字段 ID | 标签 | 类型 | 必填 | 可选值 / 规则 | 默认值 | 映射字段 |
| --- | --- | --- | --- | --- | --- | --- |
| `sentence_length_preference` | 句长偏好 | enum | 是 | `short` / `short_medium` / `balanced` / `medium_long` | `balanced` | `sentence_length_preference` |
| `rhythm_profile` | 节奏轮廓 | enum | 是 | `tight` / `balanced` / `slow_burn` | `balanced` | `rhythm_profile` |
| `lexical_density` | 词汇浓度 | enum | 否 | `plain` / `balanced` / `dense` | `balanced` | 预览辅助字段，不单独落 `StyleProfile` |
| `metaphor_intensity` | 比喻密度 | enum | 否 | `low` / `medium` / `high` | `low` | 预览辅助字段 |

### 3.4 对话与描写

| 字段 ID | 标签 | 类型 | 必填 | 可选值 / 规则 | 默认值 | 映射字段 |
| --- | --- | --- | --- | --- | --- | --- |
| `dialogue_ratio` | 对话比例 | enum | 是 | `low` / `medium` / `high` | `medium` | `dialogue_ratio` |
| `description_density` | 描写密度 | enum | 是 | `low` / `medium` / `high` | `medium` | `description_density` |
| `action_focus` | 动作优先度 | enum | 否 | `low` / `medium` / `high` | `medium` | 预览辅助字段 |
| `sensory_focus` | 感官描写重点 | multi-select | 否 | 最多 3 项；`视觉/听觉/触觉/嗅觉/温度/空间感` | 空 | 预览辅助字段 |

### 3.5 情绪与氛围

| 字段 ID | 标签 | 类型 | 必填 | 可选值 / 规则 | 默认值 | 映射字段 |
| --- | --- | --- | --- | --- | --- | --- |
| `emotional_intensity` | 情绪强度 | enum | 是 | `low` / `medium` / `medium_high` / `high` | `medium` | `emotional_intensity` |
| `tone_keywords` | 氛围关键词 | multi-select | 否 | 最多 5 项；`克制/锋利/湿冷/压迫/幽默/温柔/残酷/疏离/明亮` | 空 | `tone_keywords` |
| `violence_explicitness` | 暴力呈现程度 | enum | 否 | `avoid` / `suggestive` / `explicit` | `suggestive` | 预览辅助字段 |

### 3.6 禁忌与额外说明

| 字段 ID | 标签 | 类型 | 必填 | 可选值 / 规则 | 默认值 | 映射字段 |
| --- | --- | --- | --- | --- | --- | --- |
| `taboo_patterns` | 禁忌表达 | multi-select + custom | 是 | 预设项最多 10 项，可自定义 5 项 | 空 | `taboo_patterns` |
| `custom_notes` | 额外风格说明 | textarea | 否 | 最多 200 字 | 空 | `notes` |

预设禁忌表达建议包括：

- 过度抒情
- 全知解释
- 堆砌成语
- 口号式对白
- 现代网络热梗
- 空泛形容词
- 连续感叹号
- 滥用排比
- 过度总结人物心理
- 把氛围写成背景说明

## 4. 问卷分支逻辑

### 4.1 分支总则

- 问卷默认展示全部核心字段。
- 仅对少数字段做条件展开，避免 UI 过于复杂。
- 条件字段不改变主结构，只补充更细的偏好。

### 4.2 分支规则

1. 当 `pov_mode = first_person_limited`
   - 显示附加提示：
     - “请减少上帝视角解释”
     - “优先保持主观感知”
   - `narrative_distance` 默认锁定为 `close`，仍允许作者手动改为 `medium`

2. 当 `genre_tags` 包含 `悬疑` 或 `惊悚`
   - 展开附加字段 `suspense_release_rate`
   - 类型：enum
   - 可选值：`slow` / `balanced` / `fast`
   - 仅用于预览与提示组装，不进入 `StyleProfileJson 1.0` 必填字段

3. 当 `genre_tags` 包含 `言情`
   - 展开附加字段 `relationship_tension`
   - 类型：enum
   - 可选值：`low` / `medium` / `high`
   - 仅用于提示组装

4. 当 `dialogue_ratio = high`
   - 展开附加字段 `dialogue_style`
   - 类型：multi-select
   - 可选值：`短促` / `试探` / `含蓄` / `攻击性` / `日常感`

5. 当 `description_density = high`
   - 展开附加字段 `description_focus`
   - 类型：multi-select
   - 可选值：`环境` / `动作` / `心理` / `服饰` / `光线`

6. 当 `taboo_patterns` 选择“自定义”
   - 展开 `custom_taboo_patterns`
   - 类型：tag-input
   - 最多 5 项

## 5. 校验逻辑

### 5.1 阻断型校验

以下条件不满足时，禁止生成 `StyleProfile`：

- `profile_name` 为空
- `genre_tags` 数量为 0
- `pov_mode` 为空
- `dialogue_ratio` 为空
- `description_density` 为空
- `emotional_intensity` 为空
- `rhythm_profile` 为空
- `taboo_patterns` 未填写任何项

### 5.2 警告型校验

以下条件允许继续，但必须提示作者：

- `dialogue_ratio = high` 且 `description_density = high`
  - 提示：正文可能过满，建议降低其中一项
- `sentence_length_preference = medium_long` 且 `rhythm_profile = tight`
  - 提示：句长与节奏目标可能冲突
- `pov_mode = third_person_multi` 且 `narrative_distance = close`
  - 提示：多视角贴近叙述会增加一致性控制难度

### 5.3 自动归一化

以下字段在写入 `StyleProfile` 前需要归一化：

- 空白字符串去除首尾空格
- 多选项去重
- 自定义禁忌表达去除空值
- `tone_keywords` 超过 5 项时保留前 5 项

## 6. StyleProfile 映射逻辑

问卷并不是所有字段都直接落到 `StyleProfile`，MVP 采用“核心字段入库，辅助字段用于提示拼装”的策略。

### 6.1 直接映射字段

| 问卷字段 | StyleProfile 字段 |
| --- | --- |
| `profile_name` | `name` |
| `language` | `language` |
| `genre_tags` | `genre_tags` |
| `pov_mode` | `pov_mode` |
| `sentence_length_preference` | `sentence_length_preference` |
| `dialogue_ratio` | `dialogue_ratio` |
| `description_density` | `description_density` |
| `emotional_intensity` | `emotional_intensity` |
| `rhythm_profile` | `rhythm_profile` |
| `taboo_patterns` | `taboo_patterns` |
| `tone_keywords` | `tone_keywords` |
| `narrative_distance` | `narrative_distance` |
| `custom_notes` | `notes` |

### 6.2 仅用于提示组装的辅助字段

- `inner_monologue_ratio`
- `lexical_density`
- `metaphor_intensity`
- `action_focus`
- `sensory_focus`
- `violence_explicitness`
- `suspense_release_rate`
- `relationship_tension`
- `dialogue_style`
- `description_focus`

这些字段不要求进入 `StyleProfileJson 1.0` 的固定 schema，但可以被客户端内部预览和提示拼装逻辑消费。

## 7. 问卷到 JSON 的转换

问卷提交后，客户端要生成一份规范化的 `StyleProfileJson`。

最小输出示例：

```json
{
  "version": "1.0",
  "name": "克制压迫感第三人称悬疑",
  "language": "zh-CN",
  "genre_tags": ["悬疑"],
  "pov_mode": "third_person_limited",
  "dialogue_ratio": "medium",
  "description_density": "medium",
  "emotional_intensity": "medium_high",
  "rhythm_profile": "tight",
  "taboo_patterns": ["全知解释", "空泛形容词"],
  "sentence_length_preference": "short_medium",
  "tone_keywords": ["压迫", "克制", "湿冷"],
  "narrative_distance": "close",
  "notes": "优先通过动作和环境传达紧张，不直接讲解人物心理。"
}
```

## 8. 前端实现建议

### 8.1 表单组件

- 文本框：`profile_name`
- 单选：大部分 enum 字段
- 多选标签：`genre_tags`、`tone_keywords`、`sensory_focus`
- 标签输入：`custom_taboo_patterns`
- 文本域：`custom_notes`

### 8.2 交互细节

- 每个区块标题旁显示“是否已完成”
- 顶部固定一个完成度进度条
- 问卷右侧实时展示风格摘要卡
- 提交按钮文案固定为：`生成 StyleProfile`

### 8.3 草稿机制

- 问卷未提交前，允许保存在本地临时状态
- 切出页面返回后恢复上次未提交内容
- 只有点击 `生成 StyleProfile` 后才创建正式风格配置

## 9. 验收标准

- 作者在 3 分钟内能完成一份基础风格问卷
- 未填写必填项时，不会生成 `StyleProfile`
- 分支字段只在满足条件时出现
- 问卷生成的 `StyleProfileJson` 可被风格面板页重新导入
- 问卷生成的风格配置可直接绑定到项目或场景
