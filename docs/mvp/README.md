# MVP 文档集总览

本目录用于交付小说创作工作台的 MVP 文档，文档受众为研发落地团队。

MVP 固定边界如下：

- Windows 优先
- 本地优先
- 无后端依赖
- BYOK
- Markdown 编辑器
- 单场景模拟
- 叙述重写
- 风格问卷 / JSON 导入
- 工程导出包

MVP 还必须满足一条交互原则：

- 作者保有创作主导权，AI 只提供模拟、重写和建议，不可绕过作者直接固化正文或项目状态。

不进入 MVP 主流程的内容：

- 云同步
- 资产市场
- 审核与支付
- GraphRAG
- 多章自动编排

## 文档目录

- [MVP 文档集总览 (JSON)](/Users/chengwen/dev/novel-wirter/docs/mvp/README.json)
- [MVP 总入口索引 (JSON)](/Users/chengwen/dev/novel-wirter/docs/mvp/mvp-index.json)
- [MVP 架构图](/Users/chengwen/dev/novel-wirter/docs/mvp/mvp-architecture.md)
- [MVP 核心流程与状态流转](/Users/chengwen/dev/novel-wirter/docs/mvp/mvp-core-flows.md)
- [UI 设计稿标准与偏好](/Users/chengwen/dev/novel-wirter/docs/mvp/ui-design-standards.md)
- [Frame / State Coverage](/Users/chengwen/dev/novel-wirter/docs/mvp/frame-state-coverage.md)
- [Frame / State Coverage (JSON)](/Users/chengwen/dev/novel-wirter/docs/mvp/frame-state-coverage.json)
- [Canonical Frame Map (JSON)](/Users/chengwen/dev/novel-wirter/docs/mvp/canonical-frame-map.json)
- [MVP 文档清单 (JSON)](/Users/chengwen/dev/novel-wirter/docs/mvp/doc-manifest.json)
- [Legacy Frame 审计](/Users/chengwen/dev/novel-wirter/docs/mvp/legacy-frame-audit.md)
- [MVP 行为缺口审计](/Users/chengwen/dev/novel-wirter/docs/mvp/behavior-gap-audit.md)
- [MVP 实现交接稿](/Users/chengwen/dev/novel-wirter/docs/mvp/implementation-handoff.md)
- [MVP 实现交接稿 (JSON)](/Users/chengwen/dev/novel-wirter/docs/mvp/implementation-handoff.json)
- [MVP 里程碑验收清单](/Users/chengwen/dev/novel-wirter/docs/mvp/milestone-verification-checklist.md)
- [MVP 里程碑验收清单 (JSON)](/Users/chengwen/dev/novel-wirter/docs/mvp/milestone-verification-checklist.json)
- [MVP 运行时 Smoke Test 清单](/Users/chengwen/dev/novel-wirter/docs/mvp/runtime-smoke-tests.md)
- [MVP 运行时 Smoke Test 清单 (JSON)](/Users/chengwen/dev/novel-wirter/docs/mvp/runtime-smoke-tests.json)
- [MVP 追踪矩阵](/Users/chengwen/dev/novel-wirter/docs/mvp/traceability-matrix.md)
- [MVP 追踪矩阵 (JSON)](/Users/chengwen/dev/novel-wirter/docs/mvp/traceability-matrix.json)
- [MVP 设计交付完成度](/Users/chengwen/dev/novel-wirter/docs/mvp/release-readiness.md)
- [MVP 设计交付完成度 (JSON)](/Users/chengwen/dev/novel-wirter/docs/mvp/release-readiness.json)
- [MVP 文档校验脚本](/Users/chengwen/dev/novel-wirter/docs/mvp/validate_mvp_docs.py)
- [MVP 按角色开始](/Users/chengwen/dev/novel-wirter/docs/mvp/start-here-by-role.md)
- [MVP 按角色开始 (JSON)](/Users/chengwen/dev/novel-wirter/docs/mvp/start-here-by-role.json)
- [风格问卷规格说明](/Users/chengwen/dev/novel-wirter/docs/mvp/style-questionnaire-spec.md)
- [Figma / FigJam 入口清单](/Users/chengwen/dev/novel-wirter/docs/mvp/figma-links.md)
- [PRD 01 项目列表页](/Users/chengwen/dev/novel-wirter/docs/mvp/prd/prd-01-project-list.md)
- [PRD 02 写作工作台](/Users/chengwen/dev/novel-wirter/docs/mvp/prd/prd-02-writing-workbench.md)
- [PRD 03 沙盒监视器页](/Users/chengwen/dev/novel-wirter/docs/mvp/prd/prd-03-sandbox-monitor.md)
- [PRD 04 角色库页](/Users/chengwen/dev/novel-wirter/docs/mvp/prd/prd-04-character-library.md)
- [PRD 05 世界观页](/Users/chengwen/dev/novel-wirter/docs/mvp/prd/prd-05-worldbuilding.md)
- [PRD 06 风格面板页](/Users/chengwen/dev/novel-wirter/docs/mvp/prd/prd-06-style-panel.md)
- [PRD 07 审计中心页](/Users/chengwen/dev/novel-wirter/docs/mvp/prd/prd-07-audit-center.md)
- [PRD 08 版本历史页](/Users/chengwen/dev/novel-wirter/docs/mvp/prd/prd-08-version-history.md)
- [PRD 09 工程导入导出页](/Users/chengwen/dev/novel-wirter/docs/mvp/prd/prd-09-project-import-export.md)
- [PRD 10 设置与 BYOK 页](/Users/chengwen/dev/novel-wirter/docs/mvp/prd/prd-10-settings-byok.md)
- [PRD 11 纯净阅读态](/Users/chengwen/dev/novel-wirter/docs/mvp/prd/prd-11-reading-mode.md)

## 统一术语

- 页面：用户可导航访问的独立视图，例如“写作工作台”。
- 功能区：页面内部的布局区域，例如左侧导航区、正文编辑区。
- 流程：跨页面或跨功能区的端到端操作链路。
- 类型：领域对象名称，使用统一的公开类型名。
- 接口边界：客户端内部的适配器或服务边界，用于隔离实现。

文档中统一使用以下公开类型名：

- `NovelProject`
- `Chapter`
- `Scene`
- `SceneDraft`
- `Character`
- `WorldNode`
- `StyleProfile`
- `StyleProfileJson`
- `SimulationRun`
- `InteractionLog`
- `WorldStateSnapshot`
- `LlmProviderConfig`
- `ProjectExportPackage`

文档中统一使用以下 MVP 接口边界：

- `AppLlmClient`
- `AppLlmProviderAdapters`
- `AppWorkspaceStore` style normalization
- `ChapterGenerationOrchestrator`
- `SceneRoleplayRuntime`
- `SceneStateResolver`
- `ProjectTransferService`

## 风格配置入口

MVP 中 `StyleProfile` 只允许通过以下两种方式创建：

- `风格问卷`
  - 作者通过结构化问卷填写风格偏好，由系统生成 `StyleProfile`
- `StyleProfile JSON`
  - 作者导入符合约定字段的 JSON 文件，由系统校验后生成 `StyleProfile`

MVP 中不支持以下风格入口：

- 通过 TXT / Markdown 参考文本自动抽取风格
- 通过外部作品片段做 few-shot 风格拟合
- 通过模型微调或 LoRA 训练风格

## 统一状态命名

所有页面仅使用以下状态基线，并在此基础上增加页面特有状态：

- `loading`
- `empty`
- `ready`
- `running`
- `success`
- `error`

与模拟相关的流程状态统一为：

- `idle`
- `context_ready`
- `simulating`
- `narrating`
- `reviewing`
- `completed`
- `failed`

## 统一交付要求

- 架构图中的未来扩展项只做灰色占位，不定义协议细节。
- 页面级 PRD 必须包含低保真线框布局。
- 验收标准必须可以直接转为测试用例。
- 文档之间不得混用同义术语造成歧义。

## 验证命令

在继续修改 MVP 文档或交付研发前，先运行：

```bash
make mvp-docs-check
```

如果不使用 `make`，也可以直接运行：

```bash
python docs/mvp/validate_mvp_docs.py
```

通过标准：

- 输出 `MVP doc validation: PASSED`
- `top_level_docs`、`prd_docs`、`canonical_frame_names`、`canonical_frame_ids`、`smoke_tests` 都有值

已接入 CI：

- `.github/workflows/mvp-docs-check.yml`
- 修改 `docs/mvp/**` 后会自动执行同一条校验命令

如需按运行时路径做联调，参考：

- [MVP 运行时 Smoke Test 清单](/Users/chengwen/dev/novel-wirter/docs/mvp/runtime-smoke-tests.md)
- [MVP 里程碑验收清单](/Users/chengwen/dev/novel-wirter/docs/mvp/milestone-verification-checklist.md)

## 作者交互权基线

MVP 中作者拥有以下明确交互权：

- 发起权：决定何时运行模拟、何时重写、何时保存、何时导出。
- 观察权：查看回合日志、动作提案、状态机裁决和版本变化。
- 中止权：在模拟过程中暂停、继续或中止当前 `SimulationRun`。
- 否决权：拒绝当前正文草稿，不接受系统默认结果。
- 重试权：要求重新叙述、重新模拟或局部重写。
- 编辑权：直接修改正文、角色卡、世界观、场景卡和风格绑定。
- 落盘确认权：只有在作者接受后，AI 生成的正文才作为主草稿继续使用。

不属于 MVP 的作者交互权：

- 以“God Mode”实时插入事件
- 以“Character Override”直接接管角色发言
- 从中间回合回滚并局部续跑模拟

以上能力可在后续版本进入，但不作为 MVP 强制实现。
