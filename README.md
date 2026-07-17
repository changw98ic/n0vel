# Novel Writer

Novel Writer 是一个本地优先的长篇小说写作工作台。它把项目、角色、世界观、场景、参考资料和 AI 写作助手放在同一个地方，帮助作者从资料整理、正文起草到改写、审阅、版本保存和通读检查形成一条完整流程。

![Novel Writer macOS 桌面端 AI 候选审阅截图](docs/assets/real-desktop-ai-review.png)

> **REAL APP SCREENSHOT** — 上图来自 macOS 桌面端运行中的 Workbench，使用临时演示数据和本地演示模型配置，展示 AI 候选稿审阅流程。

当前项目还是开发预览版，暂时没有安装包。普通用户如果想试用，需要先安装 Flutter，然后从源码启动应用。

## 产品定位

`n0vel` 的传播定位是：给长篇小说作者用的本地优先 AI 创作工作台。

它不主打“一键生成小说”，而是强调作者主导的长篇工作流：先管理角色、世界观、场景和伏笔，再让 AI 生成候选稿，最后由作者确认、修订并写入正文。完整推广路线见 [n0vel 推广与增长路线图](docs/growth-roadmap.md)。

## 当前工程状态

当前代码已经具备从场景资料到可审阅候选稿的完整生产路径，但产品仍处于开发预览阶段：

| 能力 | 当前实现 |
| --- | --- |
| 候选稿与提交 | 生成过程使用运行级材料快照；候选稿不会直接覆盖正文。候选证明和待批准写入在展示前封存；作者采纳事务会重新校验证明，再原子提交正文、版本、回执和 outbox。派生的 RAG 索引工作可从 outbox 恢复。 |
| 大纲与连续性 | 有效且包含 `evidenceGroups` 的 `requiredOutlineBeats` 会要求最终正文提供原文证据；同时提供 `continuityLedger` 与 `continuityEntityDeclarations` 时会校验 typed 状态，并由后续场景重载已提交结果。formal execution 或显式 require 标记缺少相应契约时 fail closed；未声明契约时，不宣称系统会自动追踪任意情节事实。 |
| 文本质量门 | 可 finalization 的完整生产候选要求综合分不低于 95、关键维度不低于 90。场内重复、钩子和独立审稿在场景流水线校验；跨场景模板/长片段重复与角色引入由章节级运行和显式质量报告校验，并非所有单场景入口都会自动执行。 |
| 可恢复与审计 | 阶段 checkpoint、REPLAN/修订历史、物理模型调用、并发区间、候选证明、提交回执和失败原因均保留可核验记录。 |
| 本地 Hybrid RAG | 应用默认路径使用 FTS5、中文 unigram/bigram side index 和确定性的 64 维本地 fallback embedding，再经 SQLite LSH 与 cosine 重排。Ollama、LM Studio/llama.cpp、高维 embedding profile 和严格模型/维度绑定目前用于独立语料导入及评测工具，尚不是默认 UI 建库路径。 |

这里的 `95/90` 是“阻止不合格候选进入 finalization”的工程门槛，不是对任意模型输出质量的保证。真实生成效果仍取决于模型、材料完整度和作者反馈；涉及外部 KMS、正式签名身份和完整 provider 预算的 release-evaluation 路径默认关闭，不能由本地 smoke、测试夹具或 API key 存在替代。

## 适合做什么

- 管理多个小说项目。
- 维护角色资料、世界观规则、场景列表和参考材料。
- 在写作工作台中写正文，并让 AI 帮你续写、改写、审阅或润色。
- 在重要改动前保存版本，方便回看或恢复。
- 用阅读模式通读正文，减少编辑界面的干扰。
- 通过导入/导出迁移或备份项目。

## 启动应用

1. 安装 CI 当前固定的 Flutter stable 3.41.9；至少需要满足 `pubspec.yaml` 中的 Flutter/Dart 版本约束。
2. 在终端进入本项目目录。
3. 获取依赖：

```bash
flutter pub get
```

4. 在当前电脑上运行：

```bash
flutter run -d macos
```

如果你使用 Windows 或 Linux，把命令里的 `macos` 换成 `windows` 或 `linux`。当前 Web/Chrome 预览仍受本地 `sqlite3`/`dart:ffi` 依赖限制，建议先用桌面端试用。

想制作本地桌面预览包或了解当前 release 限制，请看 [Desktop Preview Builds](docs/desktop-preview-builds.md)。当前 macOS 预览包是从源码本地构建的 unsigned/not notarized archive，不会包含 API key 或私人项目数据。

## 第一次使用

1. 打开“设置”。
2. 在“默认模型”里填写模型服务：

| 字段 | 填什么 |
| --- | --- |
| 模型服务 | 给服务起一个容易识别的名字，例如 `OpenAI 兼容服务` |
| 接口地址 | 模型服务的接口地址，很多服务需要以 `/v1` 结尾 |
| 模型 | 服务商提供的模型名称 |
| 密钥 | 你的模型服务密钥 |

常见 OpenAI 兼容服务的示例“接口地址”和“模型”值见 [OpenAI-compatible provider examples](docs/openai-compatible-providers.md)。这些示例不会包含真实密钥；你需要使用自己的密钥。

设置页还提供“多模型服务配置”和“路由规则”等高级能力；首次使用只需先填写“默认模型”，无需配置路由。

3. 超时和并发设置先保持默认；只有请求经常超时或服务商有限流时再调整。
4. 点击连接测试，通过后保存。

应用会把项目资料保存在本机。使用 AI 功能时，请求提示词和必要上下文会发送给你配置的模型服务。

想先了解推荐的项目结构，可以查看 `test/fixtures/sample_project_fixture.json`。这个小型虚构示例包含角色、世界规则、场景和风格说明，不含真实密钥、私人文本或受版权保护的原文。

## 示例项目

不确定怎么填角色、世界观和场景？看一下 [《月潮档案》示例项目](docs/sample-project-moon-tide.md)，它展示了一个已填充资料的长篇小说工作台。

## 推荐写作流程

1. 在项目架上新建或打开一个项目。
2. 先补齐基础资料：

| 资料 | 建议内容 |
| --- | --- |
| Characters | 角色姓名、身份、关系、稳定性格和禁忌设定 |
| Worldbuilding | 世界规则、地点、组织、能力体系和限制 |
| Scenes | 章节或场景标题、目标、冲突和收束方向 |
| Style / References | 想参考的文风、示例片段或写作要求 |

3. 进入 Workbench 正常写正文。
4. 需要 AI 帮忙时打开 AI 工具：

| 操作 | 适合场景 |
| --- | --- |
| Continue | 从当前正文继续往下写 |
| Rewrite | 改写选中的段落 |
| Add selection | 把选中文本作为上下文，让请求更精确 |

5. AI 生成的内容会先作为候选结果出现，确认后再写入正式草稿。
6. 大改前保存版本。
7. 想检查阅读节奏时进入 Reading。
8. 需要备份或迁移时使用 Import / Export。

无选区的 Continue/Rewrite 会进入可恢复的完整场景流水线；带选区的 Rewrite 走局部改写确认流。完整场景流水线执行当前 brief 已启用的确定性门、独立终审和质量门；质量失败默认最多进行两次定向修订，不降低 `95/90` 门槛，耗尽后保留 typed 阻断原因而不生成可提交候选。启用相应硬门的章节级运行还会执行跨场景检查。

## 可核验的三章修复样本

仓库保留了一组来自已归档三章生成记录的派生修复稿，用来回归曾经出现的大纲关键情节遗漏、证据设备状态矛盾和跨场景重复表达问题：

- [三章修复稿与来源说明](artifacts/real_validation/three_chapter_repaired/README.md)
- [确定性修复审计](artifacts/real_validation/three_chapter_repaired/reports/deterministic-repair-audit.md)
- [生产 pre-quality 证据](artifacts/real_validation/three_chapter_repaired/reports/production-pre-quality-evidence.json)

这组派生文本的状态是 `unscored_unreleased`。12 个场景已经通过生产代码共用的 provider-free 确定性门禁，但没有继承旧稿分数，也没有伪造外部模型评分、候选证明或发布回执。只有同一最终正文再经过可候选 production polish、final council，并达到综合分 `>= 95`、关键维度 `>= 90`，才能转为发布候选。

## 主要页面

| 页面 | 用途 |
| --- | --- |
| Shelf | 创建、打开和切换项目 |
| Workbench | 正文写作、AI 辅助、反馈和版本操作 |
| Characters | 角色资料和一致性材料 |
| Worldbuilding | 世界观、地点、组织和规则 |
| Scenes | 场景列表、标题、摘要和顺序 |
| Style / References | 参考资料和风格要求 |
| Audit / Review tasks | 检查问题和后续修订项 |
| Versions | 草稿快照和版本回看 |
| Reading | 低干扰通读 |
| Import / Export | 项目迁移和备份 |
| Settings | 模型服务、密钥、主题、超时和路由设置 |

## 常见问题

| 问题 | 先检查什么 |
| --- | --- |
| AI 请求立刻失败 | 密钥是否填写并保存 |
| 连接不上模型服务 | 接口地址是否正确，是否需要 `/v1` |
| 提示模型不存在 | 模型是否和服务商后台里的模型 ID 完全一致 |
| 请求很慢或超时 | 适当调大接收超时，或降低并发上限 |
| AI 没有直接覆盖正文 | 这是预期行为，生成结果需要先确认再写入草稿 |
| 生成时修改了角色或世界观 | 当前运行可能仍使用启动时的快照；需要最新资料时重新发起生成 |

更详细的安装排查、平台差异和模型配置说明见 [试用准备与已知问题](docs/trial-readiness.md)。

## 试用反馈

现阶段最需要验证的是：谁会用、为什么用、能否成功跑起来、是否能生成第一份候选稿、作者是否愿意采纳或继续反馈。

如果你是小说作者或 AI 写作爱好者，欢迎用 [Author feedback issue 模板](.github/ISSUE_TEMPLATE/author-feedback.yml) 反馈：

- 你的写作类型和最大痛点。
- 是否成功安装并创建项目。
- 是否填写角色、世界观或场景。
- 是否完成一次 AI 生成或改写。
- 候选稿确认流程是否比直接覆盖正文更安心。
- 哪个功能最影响你继续使用。

## 给开发者

首次拉取代码后先获取依赖；后续验证使用 `--no-pub`，避免测试过程隐式改变锁文件：

```bash
flutter pub get
flutter analyze --no-pub
flutter test --no-pub -r compact
make docs-check
```

上面的完整 `flutter test` 会包含较长的评估、恢复和 release-evidence 测试；其中真实 provider 用例需要显式授权和完整运行时配置，未授权时会按测试设计跳过。日常快速基线可先运行 `flutter analyze --no-pub` 和 `make docs-check`，再按改动范围选择测试文件。

文本生成质量与三章证据的聚焦回归：

```bash
flutter test --no-pub \
  -r compact \
  test/story_generation_quality_regression_test.dart \
  test/quality_gate_pipeline_adversarial_test.dart \
  test/repaired_three_chapter_artifact_test.dart
```

可选的 `make rag-vector-eval` 会运行 10 万条、64 维确定性向量基准；它用于验证 SQLite LSH 的召回、候选上限、重开行为和写入守恒，不代表高维 embedding 模型的语义质量。独立语料导入/评测工具使用 `VectorEmbeddingProfile` 绑定 provider、model digest 与 dimension；应用默认 RAG 仍使用本地 64 维 fallback。

架构说明在 [docs/architecture.md](docs/architecture.md)，产品需求在 [docs/prd.md](docs/prd.md)。章节恢复与提交契约见 [Chapter Generation Recovery Spec](docs/chapter-generation-recovery-spec.md)，Agent 评估与 release-evidence 边界见 [Agent Engineering Evaluation Spec](docs/agent-engineering-evaluation-spec.md)。

桌面预览构建和本地 macOS 打包说明见 [Desktop Preview Builds](docs/desktop-preview-builds.md)。

macOS 上还可以运行 `make verify-macos` 执行仓库固定的完整桌面验证入口。

推广素材位于 `docs/assets/`，详细清单和真实性标签见 [ASSET_MANIFEST.md](docs/assets/ASSET_MANIFEST.md)：

| 用途 | 文件 | 说明 |
| --- | --- | --- |
| README 真实截图 | `real-desktop-ai-review.png` | REAL APP SCREENSHOT |
| README 旧预览占位图 | `novel-writer-preview.png` | MOCK PLACEHOLDER |
| GitHub social preview | `social-preview.png` | MOCK PLACEHOLDER |
| 视频标题/CTA/摘要卡 | `title-card.png` `cta-card.png` `summary-card.png` | STATIC DESIGN ASSET |
| 视频章节叠加图 | `section-overlay-01.png` ~ `section-overlay-05.png` | STATIC DESIGN ASSET |

除 `real-desktop-ai-review.png` 外，其余素材均为程序生成的静态设计占位图或视频叠加图，不应当被描述为真实应用截图。

所有持久化内容更新都要在 GitHub issue 中留下记录。当前规则记录在 [issue #2](https://github.com/changw98ic/n0vel/issues/2)，README 基础更新记录在 [issue #3](https://github.com/changw98ic/n0vel/issues/3)，当前架构分析报告在 [issue #4](https://github.com/changw98ic/n0vel/issues/4)，推广与私测准备记录在 [issue #5](https://github.com/changw98ic/n0vel/issues/5)，真实桌面截图记录在 [issue #6](https://github.com/changw98ic/n0vel/issues/6)。
