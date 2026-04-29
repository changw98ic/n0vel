# MVP 追踪矩阵

本文档用于把 PRD、canonical frame 与运行时 smoke test 串起来，便于研发、QA 与产品在同一份基线上核对实现范围。

## 页面级追踪

| 模块 | PRD | 主 frame | 关键状态 / 补充 frame | 运行时 smoke |
| --- | --- | --- | --- | --- |
| 项目列表 | `prd-01-project-list.md` | `nXod8` | `MS3Oh` `az4YP` `qW9NX` `X4Udf` `01wqz` | `Smoke 01` `Smoke 09` `Smoke 10` |
| 写作工作台 | `prd-02-writing-workbench.md` | `47nGt` | `WT5mH` `aBO8C` `XBhIG` `AMlNT` `i2PgM` `y6Ufy` `ea0WQ` `go6Qc` `FPMUS` `O5wWx` `dSehn` `6RjjP` `WmFpE` `emCHR` `4K0UK` `lV0iX` `bgE7z` | `Smoke 01` `Smoke 02` `Smoke 04` `Smoke 05` `Smoke 06` `Smoke 12` |
| 模拟过程弹窗 | `prd-03-sandbox-monitor.md` | `YTrUo` | `fBn5z` `JJh0t` `GtV8t` `Fekvk` | `Smoke 04` `Smoke 05` `Smoke 06` |
| 角色库 | `prd-04-character-library.md` | `4KVQe` | `qpmBd` `tfAqU` `zlKdA` `bRkQL` | `Smoke 12` |
| 世界观 | `prd-05-worldbuilding.md` | `dH2Mr` | `5HcpF` `mMbsG` `bJvYY` `CQycp` | `Smoke 12` |
| 风格面板 | `prd-06-style-panel.md` | `ff8vo` | `hs0KX` `ABdeI` `6iQPW` `bPxYh` `3sKz3` `ToU7Z` `fjUbH` `tosI5` | 可作为 `Smoke 11` 前置校验 |
| 审计中心 | `prd-07-audit-center.md` | `p8Lkt` | `bAyGg` `55YHH` `25jQz` `BskXB` | 可作为资料 / 写作联调补充检查 |
| 章节版本 | `prd-08-version-history.md` | `Ym6ea` | `PUmdJ` `uHxFC` `v82se` `xY5Bh` `rr4J7` `XEwpS` `pblhy` | `Smoke 08` |
| 工程导入导出 | `prd-09-project-import-export.md` | `z0mJ1` | `aYhVV` `XrBiQ` `kJVPV` `YqiXr` `f4cfp` `O5g2A` `nJ1Vf` `sqxPi` `4U4Ue` | `Smoke 09` `Smoke 10` |
| 设置与 BYOK | `prd-10-settings-byok.md` | `DnwrZ` | `WwWEh` `6yJaH` `hroTw` `NVC2a` `YwhiQ` `URbAX` `yRdSE` `1KpPn` `BtJNK` `HcPSf` `1ppB0` `2W8bB` | `Smoke 11` |
| 纯净阅读 | `prd-11-reading-mode.md` | `GD63C` | `WGzHM` `Cz57s` `mDkBH` `ATuaL` `cqffu` | `Smoke 07` |

## 补充页面级追踪

| 模块 | 设计来源 | 主 frame | 关键状态 / 补充 frame | 运行时 evidence |
| --- | --- | --- | --- | --- |
| 场景管理 | 运行时补充页面 | `PIRts` | `aI0tb` `GKvUk` `fhYDR` `nl6rr` `h4puH` `OiGfq` | `test/scene_surfaces_test.dart` |

## 交互专项追踪

| 交互 | 主要 frame | 相关 PRD | 相关 smoke |
| --- | --- | --- | --- |
| AI 修改确认 / 排除 / 恢复 | `XYBaG` `XkB5L` `rQbOu` `8JkLW` | `prd-02-writing-workbench.md` | `Smoke 03` |
| AI 续写确认 / 接受失败 | `VT3Da` `eOH82` | `prd-02-writing-workbench.md` | `test/workbench_shell_test.dart` AI 审核与接受失败流 |
| 工作台 AI 阻塞 | `y6Ufy` `go6Qc` `FPMUS` | `prd-02-writing-workbench.md` | `Smoke 02` |
| 工作台 AI 配置恢复 | `NqgGR` `jbGIZ` `aZupZ` | `prd-02-writing-workbench.md` `prd-10-settings-byok.md` | `test/workbench_shell_test.dart` AI 快捷面板恢复流 |
| 工作台资料面板场景对话框 | `IhizR` `VCoJM` `ttVz8` | `prd-02-writing-workbench.md` | `test/workbench_shell_test.dart` 资源面板场景操作 |
| 模拟回传 | `O5wWx` `dSehn` `YTrUo` | `prd-02-writing-workbench.md` `prd-03-sandbox-monitor.md` | `Smoke 05` `Smoke 06` |
| 模拟器互动态 | `VK4F1` `ma61v` | `prd-03-sandbox-monitor.md` | `test/workbench_shell_test.dart` Prompt 编辑与导演反馈 |
| 阅读返回锚点 | `GD63C` `WGzHM` `mDkBH` `cqffu` | `prd-11-reading-mode.md` | `Smoke 07` |
| 版本恢复与淘汰 | `Ym6ea` `rr4J7` `XEwpS` `pblhy` | `prd-08-version-history.md` | `Smoke 08` |
| 导入成功 / 覆盖成功 | `aYhVV` `XrBiQ` | `prd-09-project-import-export.md` | `Smoke 09` `Smoke 10` |
| 设置保存 / 恢复 / 超时 | `HcPSf` `a0Ywa` `oyTF3` `sOHyn` `AGfYb` `9Ukuf` | `prd-10-settings-byok.md` | `Smoke 11` + `test/settings_persistence_test.dart` |
| 全局壳层配置告警 | `cObbS` `SGKvq` | 壳层级补充状态 | `test/project_surfaces_test.dart` 与 `test/settings_persistence_test.dart` 的全局配置警告 |
| 风格输入动态态 | `uZkEL` `6TNF5` | `prd-06-style-panel.md` | `test/style_panel_test.dart` JSON 模式与项目绑定反馈 |
| 审计处理反馈 | `THj8i` `IfzpB` | `prd-07-audit-center.md` | `test/reference_surfaces_test.dart` 审计处理反馈 |
| 引用失效回收 | `WmFpE` `emCHR` | `prd-02-writing-workbench.md` `prd-04-character-library.md` `prd-05-worldbuilding.md` | `Smoke 12` |
| 工作台 AI 历史与就绪态 | `4K0UK` `lV0iX` `bgE7z` | `prd-02-writing-workbench.md` | `test/workbench_shell_test.dart` AI 历史与就绪流 |
| 场景移动 | `OiGfq` | 运行时补充页面 | `test/scene_surfaces_test.dart` 场景移动操作 |
| 设置连接测试与迁移警告 | `1ppB0` `2W8bB` | `prd-10-settings-byok.md` | `Smoke 11` + `test/settings_persistence_test.dart` |
| 工程导出成功 | `4U4Ue` | `prd-09-project-import-export.md` | `Smoke 09` |

## 使用建议

- 研发排期时：先看 [implementation-handoff.md](/Users/chengwen/dev/novel-wirter/docs/mvp/implementation-handoff.md)
- 做状态对齐时：看 [frame-state-coverage.md](/Users/chengwen/dev/novel-wirter/docs/mvp/frame-state-coverage.md)
- 做 frame 精确引用时：看 [canonical-frame-map.json](/Users/chengwen/dev/novel-wirter/docs/mvp/canonical-frame-map.json)
- 跑联调时：看 [runtime-smoke-tests.md](/Users/chengwen/dev/novel-wirter/docs/mvp/runtime-smoke-tests.md)
