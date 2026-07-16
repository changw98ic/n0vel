# 三章确定性修复审计

## 结论

派生稿已经补齐权威高层提纲中的缺失拍点，并通过当前生产代码的确定性硬门禁。它仍然是**未评分、未发布**的修复候选，不能把旧稿成绩继承到新正文，也不能仅凭本报告宣称达到发布质量。

旧稿质量报告中的场景分数范围为 **88–94**。该范围只描述 `three_chapter_run` 的历史正文；本目录三章已被改写，因此这些分数不适用于派生稿。生产确定性门禁已在 `sceneHardGateReleaseHash=sha256:24af7a88c1a1b4e6bfab417c5f0a795af8eb6bb3cd89bee9c5d23ae44be72074` 下通过。生产发布仍要求评分器对这份最终正文给出综合分 `>= 95`、全部关键维度 `>= 90`；当前状态仍为 `unscored_unreleased`。

## 来源与方法

- 权威提纲：`artifacts/real_validation/three_chapter_run/outline/three_chapter_outline.md`
- 原始三章与历史质量报告的完整 SHA-256：见 `../manifest.json`。
- 修复方式：按权威拍点人工重写到独立目录；旧目录保持不变；不使用旧分数为新稿背书。
- 证据统一：删除 U 盘、存储卡等竞争载体，压痕证据只存在于柳溪的一部手机。
- 验证方式：三章逐场穿过生产 `PipelineStageRunnerImpl` 实际使用的 `ProductionPreQualityGate`；该边界复用 `sceneHardGateViolations`、`PolishCanonVerifier`、`StoryMechanicsVerifier` 与 `NarrativeContinuityVerifier`，并另跑 `AiClicheDetector` 与 `ChapterCrossSceneClicheGate`，没有另写一套宽松规则。
- 持久化证据：`production-pre-quality-evidence.json` 保存 12 个场景的最终正文哈希、门禁证据哈希、边界 release hash、三章跨场景门禁结果和 12 个逐字证据绑定的连续性事件（分布在 11 个场景声明中）；该文件由 `manifest.json` 的 SHA-256 绑定。

## 章节指标

| 章节 | 正文 Unicode 字符 | 正文汉字 | 场景数 | 柳溪首次出现偏移 |
|---|---:|---:|---:|---:|
| chapter-01 | 2711 | 2221 | 4 | 18 |
| chapter-02 | 2932 | 2390 | 4 | 19 |
| chapter-03 | 3178 | 2585 | 4 | 27 |

每章正文均超过 1800 字符，且三章都保留权威提纲指定的四个场景标题。

## 拍点覆盖

- 第一章：纽扣微型定位器被发现；追踪使双方不得不合作；追杀转入集装箱暗巷；原句“底册不在账本里，在档案楼暗门，但你现在去就是送死。”完整保留。
- 第二章：关键三页被撕；柳溪用唯一手机的紫外补光还原压痕；资金代码和归集路径闭环；清道夫焊死低层出入口；天台成为唯一出口。
- 第三章：柳溪与沈渡同时拔枪；价值冲突明确；清道夫使用重机枪；沈渡退出弹匣并放下枪，随后归还同一手机；他从积水里捡回自己的枪、装回弹匣并上膛后以火力掩护上传，中弹翻出护栏；柳溪抓住他；界面确认“上传成功”，十九条清算路径与报社未知内应仍未解决。

## 证据手机状态链

| 事件 | 场景 | 类型 | 持有人 | 位置 | 状态 |
|---|---|---|---|---|---|
| `evidence-phone-introduced` | chapter-01/scene-02 | introduce | 柳溪 | 沈渡面前 | held |
| `evidence-phone-moved-to-table` | chapter-01/scene-03 | relocate | 柳溪 | 桌面 | held |
| `evidence-phone-returned-to-inner-pocket` | chapter-01/scene-03 | relocate | 柳溪 | 内袋 | held |
| `evidence-phone-observed-before-escape` | chapter-01/scene-04 | observe | 柳溪 | 内袋 | held |
| `evidence-phone-observed-in-inner-pocket` | chapter-02/scene-01 | observe | 柳溪 | 内袋 | held |
| `evidence-phone-moved-to-cover` | chapter-02/scene-02 | relocate | 柳溪 | 封皮前 | held |
| `evidence-phone-moved-to-backlight` | chapter-02/scene-03 | relocate | 柳溪 | 柜架背光处 | held |
| `evidence-phone-liuxi-to-shendu` | chapter-02/scene-04 | transfer | 沈渡 | 沈渡手中 | held |
| `evidence-phone-moved-to-waterproof-bag` | chapter-03/scene-01 | relocate | 沈渡 | 胸前防水袋 | held |
| `evidence-phone-drawn-in-hand` | chapter-03/scene-02 | relocate | 沈渡 | 手中 | held |
| `evidence-phone-shendu-to-liuxi` | chapter-03/scene-03 | transfer | 柳溪 | 手中 | held |
| `evidence-phone-upload-observed` | chapter-03/scene-04 | observe | 柳溪 | 手中 | held |

手机从第一章首次实体出现开始进入账本。每个事件都绑定最终正文中唯一出现的逐字证据，并由正式 `continuityEntityDeclarations` 驱动 resulting ledger；测试不再手工塞入手机账本。全文没有 U 盘或存储卡，不存在第二部证据设备。

## 确定性验证

执行命令：

```text
flutter test --no-pub test/repaired_three_chapter_artifact_test.dart
```

结果：3 项测试全部通过。覆盖结果如下：

- 12 个场景的提纲证据组、对白、章首钩子、章尾钩子、场内复沓、polish canon 和 story mechanics 生产 pre-quality 门禁：通过。
- 连续性账本：柳溪 → 沈渡 → 柳溪，0 条发现。
- 跨场景模板与 14 字以上重复片段阻塞项：0。
- 禁用载体 `U盘` / `存储卡`：0 次。
- 未生成 `quality-report.json`，也没有把确定性修复冒充模型评分。

生产接线回归另执行：

```text
flutter test --no-pub test/polish_canon_production_pipeline_test.dart --plain-name 'post-polish hard-gate regression retries then typed-blocks before quality'
```

该测试让 preliminary prose 先通过、再由 polish 引入硬门禁违规；真实 `PipelineStageRunnerImpl` 连续记录两次修订调度，最终以 typed `ProductionPreQualityGateViolation` 阻断，且 final council、质量评分与 finalization 均未运行。

## 剩余发布条件

本审计停在 author-revision provider-free 预检：没有质量分、候选证明或提交回执，且该来源明确 `candidateFinalizationEligible=false`。它只能证明结构、连续性和已编码硬约束通过，不能替代读者审阅或生产质量评分。转为发布候选前必须完成：

1. 将同一最终正文重新送入可候选的 production pipeline-polish 边界并完成 final council。
2. 运行生产评分器，综合分达到 95，且全部关键维度不低于 90。
3. 将真实评分证据与已核验的 `sceneHardGateReleaseHash`、最终正文哈希绑定。
4. 保存可候选门禁、评分与绑定证明后，才能把状态从 `unscored_unreleased` 改为发布候选。
