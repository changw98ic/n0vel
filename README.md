# n0vel (novel-writer)

## 目录

- [项目是什么](#项目是什么)
- [解决什么问题](#解决什么问题)
- [核心能力（当前版本）](#核心能力当前版本)
- [运行与验证](#运行与验证)
- [实际验证场景（Real Three-Chapter Validation）](#实际验证场景real-three-chapter-validation)
- [5 分钟快速上手（面向新用户）](#5-分钟快速上手面向新用户)
- [典型用户场景](#典型用户场景)
- [项目定位一句话总结](#项目定位一句话总结)
- [系统结构（简化架构）](#系统结构简化架构)
- [最小系统依赖与启动要求](#最小系统依赖与启动要求)
- [核心功能操作路径（从入口到结果）](#核心功能操作路径从入口到结果)
- [截图与演示（待补）](#截图与演示待补)
- [30 秒项目简介（对外可直接使用）](#30-秒项目简介对外可直接使用)
- [Roadmap（开发方向）](#roadmap开发方向)
- [发布说明模板（Release Notes）](#发布说明模板release-notes)
- [版本里程碑（示例）](#版本里程碑示例)
- [外部展示素材目录与命名规范](#外部展示素材目录与命名规范)
- [Executive Summary（对外英文简版）](#executive-summary对外英文简版)
- [贡献与协作（对外）](#贡献与协作对外)
- [许可证](#许可证)
- [项目状态与下一步](#项目状态与下一步)
- [联系方式与支持](#联系方式与支持)
- [GitHub 首页展示模板（可直接替换）](#github-首页展示模板可直接替换)
- [常见问题（FAQ）](#常见问题faq)
- [技术栈](#技术栈)
- [安全与隐私](#安全与隐私)
- [提交记录建议](#提交记录建议)

## 项目是什么

`n0vel` 是一个面向长篇小说创作的 **桌面端 AI 辅助写作系统**，目标是把“灵感 + 大纲 + 世界观 + 角色 + 迭代编辑”整合到一个统一工作区中，帮助作者更快产出稳定、可追溯、可持续迭代的文本。

它不是单一“文本生成器”，而是一个包含完整工作流的写作平台：  
- 你可以先管理项目、章节、世界观与角色；  
- 再用可控的 AI 生成流程推进写作；  
- 最后通过审稿、反馈、版本、导入导出等机制反复打磨内容。

---

## 解决什么问题

独立作者在 AI 创作场景中常见的痛点有三类：

1. 内容分散  
   大纲、人物、章节、提示词、生成记录分散在不同地方，难以形成可维护的长期资产。
2. 写作过程不可控  
3. 版本回退和复盘成本高  
   一次“坏改动”往往难以回溯，缺少结构化审计和反馈闭环。

`n0vel` 的目标是提供“可控、可复现、可编辑、可恢复”的 AI 写作主线，而不是一次性的生成结果。

---

## 核心能力（当前版本）

### 1. 项目工作区
- 多项目管理：按作品拆分工作区，支持独立的角色、章节、场景、设置与元数据。
- 本地持久化：默认本地存储，支持版本记录与备份。

### 2. 角色与世界观建模
- 人物画像/世界观资料结构化存储。  
- 角色与世界观更新会影响后续生成上下文，减少风格和世界设定断层。

3. AI 写作流水线
- 多阶段写作编排：从角色行为、场景构建到润色、复核，多角色协作式生成链路。
- 可追踪的上下文传递：为后续生成准备结构化上下文快照。
- 可恢复执行：支持中断、回看、重跑与结果修复。

### 4. 审核与反馈闭环
- 审核中心：对生成内容进行规则化查看与编辑标注。
- 反馈任务系统：记录创作者反馈，并影响下一轮生成策略。

### 5. 导入导出与兼容性
- 提供项目导入导出能力，支持跨环境迁移与外部工具协作。
- 支持标准化工件与可读化内容导出，便于归档和复用。

### 6. 阅读/排版辅助
- 提供阅读模式与写作辅助页面，覆盖从写作、审阅到复查的常用交互。

### 7. 开发者友好
- 完整的测试体系（单元测试/集成测试）。  
- 明确的验证命令与 CI 流程，保证多端提交一致性。  
- 运行时状态、仿真与文档分层结构，便于持续演进。

---

## 运行与验证

### 本地验证

```bash
make verify-macos
```

等效会执行：

- `flutter analyze`
- `flutter test -r compact`
- `flutter build macos`
- `xcodebuild test -workspace macos/Runner.xcworkspace -scheme Runner -destination "platform=macOS,arch=$(uname -m)"`

仓库的 CI 也使用同样链路（见 `.github/workflows/verify-macos.yml`）以保证行为一致。

### CI 与发布

- 默认分支：`main`  
- 分支风格建议：
  - `feat/<topic>`
  - `fix/<topic>`
  - `docs/<topic>`
  - `chore/<topic>`
  - `release/<version>`

发布与分支流程说明见：[Branch And Release Workflow](/Users/chengwen/dev/novel-wirter/docs/release-workflow.md)

---

## 实际验证场景（Real Three-Chapter Validation）

对于需要验证真实模型端到端表现的场景，可以运行：

```bash
RUN_REAL_STORY_VALIDATION=1 \
flutter test test/real_three_chapter_generation_test.dart
```

该验证将会产出包含输入、章节、审稿与运行快照的工件，便于对比不同策略或模型版本的差异。

> 注意：请使用本地环境变量注入 API 凭据，不要将 token 直接提交到仓库。

---

## 5 分钟快速上手（面向新用户）

1. 克隆仓库并安装依赖

```bash
git clone https://github.com/changw98ic/n0vel.git
cd n0vel
flutter pub get
```

2. 启动桌面应用（以 macOS 为例）

```bash
flutter run -d macos
```

3. 创建你的第一个小说项目
- 打开项目列表，新增一个作品  
- 配置作品设定：题材、叙事风格、世界观背景  
- 补齐主要角色与章节提纲

4. 生成第一段内容
- 进入工作台/章节场景  
- 按写作流程触发生成  
- 在审稿/反馈面板中逐段校对与修正

5. 迭代优化
- 使用反馈任务记录你不满意的段落与修改方向  
- 复用世界观与角色快照，重新生成或润色  
- 回退版本后再继续编辑，保留可追溯历史

6. 导出成果
- 通过导入导出页面导出章节与项目包  
- 备份到本地工程目录，支持后续复用

---

## 典型用户场景

- **独立作者**：从零搭建世界观并持续稳定产出章节。  
- **协作写作**：用多个角色化写作代理（Draft/Review/Polish）分工协作，提高编辑效率。  
- **作品打磨**：在“审稿中心 + 反馈中心”里反复迭代，避免一次性草稿质量问题。  
- **长期维护**：通过项目本地持久化和版本能力，轻松管理多个项目与历史稿件。

---

## 项目定位一句话总结

`n0vel` 不是“让 AI 自动写小说”，而是一个“让 AI 写作过程可控、可迭代、可审计”的桌面创作平台。

---

## 系统结构（简化架构）

```text
作者输入
   |
   v
项目工作区（项目/角色/世界观/章节）
   |
   v
写作上下文层（历史、角色状态、世界观快照）
   |
   v
AI 生成流水线（导演/场景/润色/复核）
   |        |
   |        +--> 审核与反馈中心（人工标注 + 反馈任务）
   v
文本输出（草稿、章节、版本）
   |
   v
持久化与导出（本地存储、导入导出、测试验收）
```

### 目录映射（按职责）

- `lib/app`: 应用主架构、导航、DI、LLM 客户端与核心状态层  
- `lib/features/*`: 按功能域划分（故事生成、角色/世界观、编辑、导入导出、审核、设置）  
- `lib/domain`: 统一领域模型（事件、状态、业务模型）  
- `test`: 验证覆盖（单元/集成/场景级）  
- `docs`: PRD、验收、运行说明、设计手册  
- `web` `macos` `linux` `windows`: 多平台外壳与构建素材  
- `scripts`: 运行与验证辅助脚本  

---

## 适用人群

- 想要用 AI 辅助保持长期创作连贯性的小说作者  
- 想做“作品级”管理而不是“段落级”生成的内容创作者  
- 想研究写作自动化工作流的产品/算法团队  
- 需要稳定本地工作流、可回放和可复盘的独立开发者

---

## 快速常见问题

- 我是新手，先做什么？  
  先看“5 分钟快速上手”，只做创建项目、配置基础设定、生成第一段内容即可。
- 为什么建议本地先 `flutter pub get` 后再跑？  
  这是保证依赖与本地/CI 环境一致的最小步骤。
- 生成结果不稳定怎么办？  
  回到反馈中心标注问题点，使用版本回退后基于同一设定重新生成，提升可重复性。
- 能否与团队协作？  
  当前以本地优先为主，建议通过导出/版本管理与团队共享项目快照进行协作。

---

## 最小系统依赖与启动要求

- Flutter SDK（版本见项目 `pubspec.yaml` 中 `environment` 声明）
- Dart SDK（由 Flutter 附带）
- 支持的平台开发环境：
  - macOS 桌面开发：已提供 `make verify-macos` 的完整验证链路
  - Windows/Linux：可按 Flutter 官方桌面支持环境配置后构建
- 本地可用的版本控制与终端工具（`git`, `bash/zsh`）

建议首轮环境验证：

```bash
flutter --version
flutter doctor
flutter pub get
```

---

## 核心功能操作路径（从入口到结果）

> 以下为功能级路径，按钮名可能随版本迭代有微调。

1. 新建项目与项目信息
   - 打开应用 → `项目列表` → `新建项目` → 填写作品元数据

2. 写作准备
   - 项目主页 → `角色管理` / `世界观` → 补齐人物与设定

3. 内容生成
   - 进入 `工作台` → 选择章节/场景 → 启动生成流程  
   - 通过多阶段面板查看：起草、编辑、润色、审阅

4. 审稿与反馈闭环
   - 生成后在 `审核中心` 查看章节片段  
   - 在 `反馈任务` 中创建修改任务（语气、节奏、矛盾、连续性等）

5. 版本与回滚
   - 在版本/历史区查看快照 → 失败结果回滚 → 重新生成或手工修订

6. 导入导出与归档
   - `项目导入导出` 页面：导入旧项目/导出当前项目包与产物

---

## 截图与演示（待补）

> 你可以把截图放在 `web/` 或 `docs/` 下，然后替换下面占位块。

- ![应用主页占位](docs/placeholders/app-home.png)
- ![生成流程占位](docs/placeholders/pipeline.png)
- ![审核任务占位](docs/placeholders/review-feedback.png)

---

## 30 秒项目简介（对外可直接使用）

`n0vel` 是一款桌面端 AI 辅助长篇小说创作平台。  
它把「项目管理、世界观角色设定、AI 分段生成、人工审核反馈、版本回溯、内容导出」放进一个统一工作区，让作者能持续推进复杂作品，而不是反复在不同工具里拼接信息。

一句话概括：  
**从灵感到成稿，n0vel 提供结构化的写作闭环与可控的 AI 合作体验。**

---

## Roadmap（开发方向）

### 短期（接下来 1-2 个迭代）

- 提升写作主流程可视化入口（新手指引、关键步骤联动）
- 继续强化审稿反馈对生成策略的影响可控性
- 增加默认模板与可复用场景配置，降低首次建模成本
- 优化本地工程导入导出格式稳定性

### 中期（2-4 个迭代）

- 增加团队协作工作流（多作者共享与冲突友好化合并）
- 引入更细粒度的权限与配置剖面（模型、风格、质量策略）
- 产物发布链路（Word/Markdown/ePub）逐步标准化

### 长期（后续版本）

- 建立插件化能力：自定义作家风格插件、评审规则插件
- 引入更强的结构级编辑器（章节树、时间线、伏笔网）
- 打造多平台一致体验，扩展到 Web 与更稳定的移动端场景

---

## 发布说明模板（Release Notes）

可直接复制到发布说明中使用：

```md
## 版本 X.Y.Z

### 更新亮点
- 新增：
- 优化：
- 修复：
- 已知问题：

### 变更清单
- 变更项：
- 影响范围：
- 升级说明：
```

---

## 版本里程碑（示例）

### 已完成
- 完成桌面端基础写作闭环
- 完成角色/世界观/场景的结构化持久化能力
- 完成审核中心与反馈任务的交互链路
- 建立 CI 与 macOS 验证基线

### 进行中
- 完善新手引导与主流程可视化
- 提升生成结果的可复现性与反馈权重控制

### 计划中
- 团队协作与共享权限模型
- 导出格式与发布链路扩展
- 插件化与自定义规则系统

---

## 外部展示素材目录与命名规范

建议将展示图片放在以下路径，并统一命名，便于文档自动引用：

```text
docs/assets/
  ├─ screenshots/
  │   ├─ v1.0-home.png
  │   ├─ v1.0-workspace.png
  │   ├─ v1.0-pipeline.png
  │   └─ v1.0-review-feedback.png
  └─ gifs/
      ├─ v1.0-quick-start.gif
      └─ v1.0-feedback-loop.gif
```

命名规则：
- 文件名包含版本号前缀（如 `v1.0-...`）
- 分类固定：`home`, `workspace`, `pipeline`, `review-feedback`, `quick-start`, `feedback-loop`
- 尺寸以 16:9 为主，宽度建议 1600px，截图文字保持清晰可读

---

## Executive Summary（对外英文简版）

**n0vel** is a desktop-first AI writing platform for long-form fiction.  
It combines project management, character/world-building modeling, controllable AI generation pipelines, review/feedback workflows, and local persistence in one workspace.

The goal is not fully automated text generation.  
Instead, n0vel helps authors keep creativity fast while preserving control, continuity, and editability through a full writing loop:

- create and organize projects and source assets
- generate with structured, multi-step AI pipelines
- review, annotate, and refine outputs through feedback tasks
- export stable outputs and iterate with version history

This repository contains the application surface, domain/state layers, validation coverage, and verification scripts for local-first development and repeatable releases.

---

## 贡献与协作（对外）

- 提交 Issue：优先按复现步骤、期望行为、日志与截图来说明问题。
- 提交 PR：请尽量补齐验证步骤与测试。
- 分支建议：`feat/<topic>`、`fix/<topic>`、`docs/<topic>`、`chore/<topic>`。
- 每次功能提交请尽量同步更新：
  - 相关页面说明
  - 测试用例或验证步骤
  - 变更范围与回退方案

---

## 许可证

如果你要对外发布，请在此处补充许可证信息（例如 MIT / Apache-2.0 / 私有仓库说明）。

---

## 项目状态与下一步

### 当前可用状态

- 桌面端核心写作链路与多模块架构已落地
- 本地开发验证链路已建立并接入 CI
- 版本化文档与项目说明正在持续完善

### 下一步优先项

- 补齐外部展示截图与 Demo 视频
- 提供一套可直接运行的初始化脚手架（脚本/模板）
- 发布 1.0.0 阶段化特性清单与版本说明
- 建立稳定的外部协作提交流程

---

## 联系方式与支持

若对项目有反馈或合作意向，可通过仓库 Issue/PR 与我们对齐需求与变更。  
对接问题建议提供：目标版本、复现步骤、关键日志、截图（如有）。

---

## GitHub 首页展示模板（可直接替换）

你可以直接复制以下片段到仓库首页：

    # n0vel
    
    ![Build](https://img.shields.io/badge/build-passing-green)  
    ![License](https://img.shields.io/badge/license-TODO-blue)
    
    > AI-assisted desktop writing platform for long-form fiction.  
    > Structurize ideas, generate drafts with control, review, and iterate with confidence.
    
    ## Highlights
    
    - Project-first workflow: organize writing projects, characters, worldbuilding, scenes
    - Controlled AI pipeline: multi-stage draft/review polish flow
    - Feedback loop: turn review comments into regenerable tasks
    - Stable local persistence: keep project state and artifacts
    - Cross-platform desktop: macOS / Windows / Linux
    
    ## Installation
    
        git clone https://github.com/changw98ic/n0vel.git
        cd n0vel
        flutter pub get
    
    ## Run
    
        flutter run -d macos
    
    ## Docs
    
    - [Project Overview](/README.md)
    - [Release Workflow](docs/release-workflow.md)
    - [Architecture / MVP Docs](docs/mvp/)
    
    ## Validation
    
    - `make verify-macos`
    
    ## License
    
    Please replace with the final license used by the repository.

---

## 常见问题（FAQ）

### 适合哪些创作者？
偏向长期创作、重视一致性和可复盘的作者，以及希望结合 AI 辅助提效的独立创作团队。

### 是否开箱即用？
项目需要先安装 Flutter 环境并执行 `flutter pub get`，随后即可运行本地验证流程。

### 是否支持多人协同写作？
当前以本地工作流为主，支持项目快照导入导出，适合作为协作起点；多人协作机制将在路线图中逐步加强。

### 生成质量不稳定怎么办？
通过反馈任务标注不稳定片段，回滚版本并在相同上下文下重跑生成，形成可比较的改进闭环。

---

## 技术栈

- 前端框架：Flutter / Dart
- 平台：桌面优先（macOS、Windows、Linux）
- 架构风格：分层特性模块 + 领域模型驱动思路 + 状态持久化
- AI 能力：可插拔 LLM 提供商与网关编排
- 验证链路：Flutter 单元测试 / 集成测试 / macOS 本机验证

## 安全与隐私

- 严禁在仓库中提交 API Key、Access Token、`setting.json` 类明文凭据。
- 建议通过 CI 或本地环境变量注入敏感配置。
- 发布前确认 `.gitignore` 覆盖运行时目录、缓存目录与本地工件目录。

## 提交记录建议

- 提交信息建议使用 `模块: 变更摘要` 或语义化风格（如 `feat: ...`, `fix: ...`, `chore: ...`）。
- 同步更新：
  - 变更的功能说明（README 或 docs）
  - 相关验证命令或测试结果
  - 回退方案（如有）

---

## Release Readiness Checklist（发布前检查）

- [ ] 补齐项目截图与 Demo 链接（或移除占位图）
- [ ] 确认 `README` 目录（ToC）链接正常
- [ ] 确认外部依赖安装说明可复现
- [ ] 确认 `.gitignore` 包含运行态与敏感文件
- [ ] 更新许可证信息
- [ ] 在 `docs/release-workflow.md` 与 `readme` 告知一致

---

## English Quick Overview（英文速览）

`n0vel` is a desktop-first AI-assisted novel writing platform.

- Build and maintain complete project context: characters, worldbuilding, scenes, and chapters.
- Generate draft content with a controllable multi-stage pipeline.
- Review, annotate, and improve results through a dedicated feedback loop.
- Persist project states locally and iterate confidently through versioned outputs.
- Export and migrate your work via built-in import/export tools.

This repository contains the application implementation, test coverage, and a reproducible macOS verification workflow.
