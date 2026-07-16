# 三章修复派生产物

本目录是对 `../three_chapter_run/` 的派生修复稿，不覆盖、不改写原始生成记录。修复依据为原目录中的权威高层提纲：

- 来源：`../three_chapter_run/outline/three_chapter_outline.md`
- 本地副本：`outline/three_chapter_outline.md`
- 原始正文：`../three_chapter_run/chapters/`
- 历史评分：`../three_chapter_run/reports/quality-report.md`

## 产物范围

- `chapters/chapter-01.md`：补齐纽扣微型定位器、被迫合作、集装箱暗巷与档案楼警告。
- `chapters/chapter-02.md`：补齐关键撕页、手机紫外压痕、资金密码、焊死入口与天台唯一出口。
- `chapters/chapter-03.md`：补齐拔枪价值冲突、清道夫重火力、归还证据手机、掩护上传、中弹坠边与上传成功。
- `manifest.json`：固定来源与派生章节的 SHA-256，并记录本次确定性门禁实际核验的 `sceneHardGateReleaseHash`。
- `reports/deterministic-repair-audit.md`：面向读者的确定性修复审计，不给派生文本虚构模型评分。
- `reports/deterministic-repair-audit.json`：同一审计的机器可读版本。
- `reports/production-pre-quality-evidence.json`：由生产 `PipelineStageRunnerImpl` 共用的 provider-free pre-quality 边界逐场重算，绑定 12 个最终正文哈希、章节跨场景门禁和证据手机从第一章首次出现开始的 12 个 typed 连续性事件；不包含质量分、候选证明或提交回执。

## 证据物约束

全稿只有一个承载底册证据的设备：柳溪的手机。第一章首次实体出现时由 exact-prose `introduce` 事件建立手机身份，随后以 `relocate` / `observe` 保持位置；第二章继续记录采集位置，撤向天台时以 `transfer` 交给沈渡；第三章记录防水袋与手中位置，再以 `transfer` 交还柳溪并以 `observe` 确认上传时状态。正文不再出现 U 盘、存储卡或第二部证据设备，测试也不再手工预置账本。

## 发布状态

本目录是人工修复候选稿，目前未评分、未发布。它只走到生产 `ProductionPreQualityGate` 的 author-revision 预检入口；该入口永远不能直接生成 candidate proof。下一阶段是 `pipeline_polish_revalidation`：把同一最终正文重新送入可候选的生产 polish 边界，再执行 final council 与生产评分。旧稿的 88–94 分仅是历史结果，不能迁移或冒充本稿成绩。只有可候选边界证据通过、生产评分器给出综合分 `>= 95` 且全部关键维度 `>= 90` 后，才可转为发布候选。
