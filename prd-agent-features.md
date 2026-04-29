# PRD: LLM Agent 先进特性集成

## 项目背景

novel_writer 是一个 Flutter 小说写作应用，核心功能是 LLM 驱动的故事生成。当前架构已具备：
- 多角色并行 turn-based role play（`AgentTurnController`）
- 6 个知识检索工具（`KnowledgeToolRegistry`）
- Context Capsule 作用域信息系统
- 4-pass 场景审查（judge/consistency/readerFlow/lexicon）
- Belief/Presentation/Relationship/SocialPosition 状态模型
- Replan 和 rewrite 循环

## 理论基础（2024-2026 LLM Agent 研究）

| 领域 | 关键论文/方法 | 核心思想 |
|------|-------------|---------|
| Self-Reflection | Reflexion (Shinn et al. 2023), Self-Refine (Madaan et al. 2023) | Agent 通过结构化自我反思改进输出质量，反馈不是简单的 pass/fail 而是具体可操作的改进指令 |
| Multi-Agent Debate | Multi-Agent Debate (Du et al. 2024), MAD | 多个 LLM 实例从不同视角辩论，通过 adversarial 交互提升推理质量 |
| Prompt Chaining | Chain-of-Thought, Tree-of-Thought (Yao et al. 2024) | 复杂任务分解为链式子任务，每个子任务有明确的输入/输出契约 |
| Agentic RAG | Adaptive RAG (Jeong et al. 2024), CRAG (Yan et al. 2024) | 检索不再是静态的，而是根据任务进展动态规划和执行 |
| Narrative Generation | RecurrentGPT (Zhou et al. 2024), DOC (Interactive Fiction) | 长篇叙事需要跨场景的情节记忆和主题连贯性追踪 |
| Plan-and-Execute | Plan-and-Solve (Wang et al. 2024), LATS (Zhou et al. 2024) | 先规划后执行，规划可以动态修正 |
| Tool Learning | Toolformer (Schick et al. 2024), Gorilla (Patil et al. 2024) | LLM 学会何时、如何使用工具，包括工具链组合 |
| Prompt Optimization | DSPy (Khattab et al. 2024), OPRO (Yang et al. 2024) | 自动优化 prompt 而非手工调参 |

---

## Feature 1: 结构化自我精炼循环（Structured Self-Refine）

**优先级**: P0 | **来源**: Self-Refine, Reflexion

**现状问题**:
- `SceneReviewCoordinator` 的 4-pass 审查产生 `PASS/REWRITE_PROSE/REPLAN_SCENE` 三种决定
- rewrite 循环只传递 `review.feedback`（一句话），没有结构化的改进指引
- 角色不知道上次哪里做得不好，无法针对性改进

**方案**:
在 `SceneReviewResult` 中新增结构化 refinement 指引：

```dart
class RefinementGuidance {
  final List<String> plotIssues;       // 情节逻辑问题
  final List<String> consistencyFixes; // 一致性修正
  final List<String> styleTargets;     // 风格目标
  final List<String> preserve;         // 必须保留的亮点
  final String focusInstruction;       // 一句话聚焦指令
}
```

审查完成后，如果决定是 `rewriteProse`，自动生成结构化指引而非只传 feedback 字符串。SceneEditor 和 ScenePolishPass 在重写时消费这些指引。

**改动范围**: `SceneReviewCoordinator`, `SceneReviewResult`, `ChapterGenerationOrchestrator`

---

## Feature 2: 叙事弧线追踪器（Narrative Arc Tracker）

**优先级**: P0 | **来源**: RecurrentGPT, Plan-and-Execute

**现状问题**:
- 场景之间完全独立，没有跨场景的情节线追踪
- 无法追踪伏笔（foreshadowing）的埋设与回收
- 导演规划时看不到"这部小说到目前为止的主题走向"

**方案**:
新增 `NarrativeArcTracker`，在章节层面维护：

```dart
class NarrativeArcState {
  final List<PlotThread> activeThreads;     // 活跃的情节线
  final List<ResolvedThread> closedThreads;  // 已回收的情节线
  final List<Foreshadowing> pendingForeshadowing; // 待回收伏笔
  final List<String> thematicArcs;           // 主题弧线
  final int chapterIndex;                    // 当前章节位置
}

class PlotThread {
  final String id;
  final String description;
  final String status; // rising, climax, falling, resolved
  final List<String> involvedCharacters;
  final String introducedInScene;
}

class Foreshadowing {
  final String id;
  final String hint;
  final String plannedPayoff;
  final String plantedInScene;
  final String? resolvedInScene;
  final int urgency; // 0=relaxed, 1=should address soon, 2=overdue
}
```

每个场景完成后，`NarrativeArcTracker` 从 `SceneRuntimeOutput` 中提取情节线变化，更新 arc state。下一个场景的 `SceneBrief` 携带 arc state 作为上下文。

**改动范围**: 新增文件, `SceneBrief` 扩展, `ChapterGenerationOrchestrator` 集成

---

## Feature 3: 自适应导演规划（Adaptive Director）

**优先级**: P1 | **来源**: Plan-and-Solve, LATS

**现状问题**:
- `SceneDirectorOrchestrator` 只看当前场景的 brief 和 cast
- 不考虑前面场景的审查结果模式（比如连续多个场景 consistency 挂在同一个问题上）
- 导演 prompt 是静态的，不会根据历史表现调整策略

**方案**:
在导演规划时注入"导演记忆"——最近 N 个场景的审查摘要和写作策略调整：

```dart
class DirectorMemory {
  final List<SceneReviewDigest> recentReviews; // 最近场景的审查摘要
  final List<String> learnedConstraints;        // 从审查中学习的额外约束
  final String strategyAdjustment;              // 策略调整建议
}

class SceneReviewDigest {
  final String sceneId;
  final SceneReviewDecision decision;
  final List<String> issues;       // 提取的问题列表
  final List<String> strengths;    // 亮点
  final int proseAttempts;
}
```

导演 prompt 中新增"历史教训"部分，使规划能够规避重复错误。

**改动范围**: `SceneDirectorOrchestrator`, `ChapterGenerationOrchestrator`, 新增 model

---

## Feature 4: 对话式角色辩论（In-Character Debate）

**优先级**: P2 | **来源**: Multi-Agent Debate

**现状问题**:
- 角色之间只在 resolved beats 层面交互，没有直接的对抗性对话
- 角色行为由单个 LLM call 决定，缺乏多视角碰撞

**方案**:
在关键冲突场景中，让两个对立角色进行 1-2 轮 debate（通过 LLM），然后由 scene state resolver 综合双方立场裁定结果。这不是每次都启用，而是由 director 的 task card 触发。

---

## Feature 5: 动态工具扩展（Dynamic Tool Expansion）

**优先级**: P2 | **来源**: Toolformer, Gorilla

**现状问题**:
- 6 个检索工具是硬编码的
- 角色无法动态请求新的信息类型

**方案**:
允许角色通过结构化 intent 描述新的信息需求，`KnowledgeToolRegistry` 动态合成 capsule（基于已有 knowledge atoms 的组合检索）。

---

## 实施优先级

| Feature | 价值 | 实施复杂度 | 依赖 |
|---------|------|-----------|------|
| F1: 结构化自我精炼 | 高 | 中 | 无 |
| F2: 叙事弧线追踪器 | 高 | 中 | 无 |
| F3: 自适应导演 | 中 | 低 | F1 (消费 review digest) |
| F4: 角色辩论 | 中 | 高 | F2 (需要 arc context) |
| F5: 动态工具扩展 | 低 | 高 | 无 |

**推荐首批实施**: F1 + F2 + F3
