# MVP 按角色开始

这份文档用于帮助不同角色快速进入同一套交付基线。

## 工程

先看：

1. [MVP 实现交接稿](/Users/chengwen/dev/novel-wirter/docs/mvp/implementation-handoff.md)
2. [Canonical Frame Map (JSON)](/Users/chengwen/dev/novel-wirter/docs/mvp/canonical-frame-map.json)
3. [MVP 里程碑验收清单](/Users/chengwen/dev/novel-wirter/docs/mvp/milestone-verification-checklist.md)

本地先跑：

```bash
make mvp-docs-check
```

## QA

先看：

1. [MVP 运行时 Smoke Test 清单](/Users/chengwen/dev/novel-wirter/docs/mvp/runtime-smoke-tests.md)
2. [MVP 里程碑验收清单](/Users/chengwen/dev/novel-wirter/docs/mvp/milestone-verification-checklist.md)
3. [MVP 追踪矩阵](/Users/chengwen/dev/novel-wirter/docs/mvp/traceability-matrix.md)

重点：

- 优先跑 `Smoke 01` 到 `Smoke 12`
- 再按 milestone 做结构化回归

## 产品 / 设计

先看：

1. [MVP 设计交付完成度](/Users/chengwen/dev/novel-wirter/docs/mvp/release-readiness.md)
2. [Frame / State Coverage](/Users/chengwen/dev/novel-wirter/docs/mvp/frame-state-coverage.md)
3. [MVP 追踪矩阵](/Users/chengwen/dev/novel-wirter/docs/mvp/traceability-matrix.md)

重点：

- 先核模块范围
- 再核 PRD / frame / smoke 三向一致性

## 自动化 / 工具

先看：

1. [Canonical Frame Map (JSON)](/Users/chengwen/dev/novel-wirter/docs/mvp/canonical-frame-map.json)
2. [Frame / State Coverage (JSON)](/Users/chengwen/dev/novel-wirter/docs/mvp/frame-state-coverage.json)
3. [MVP 追踪矩阵 (JSON)](/Users/chengwen/dev/novel-wirter/docs/mvp/traceability-matrix.json)
4. [MVP 运行时 Smoke Test 清单 (JSON)](/Users/chengwen/dev/novel-wirter/docs/mvp/runtime-smoke-tests.json)
5. [MVP 文档清单 (JSON)](/Users/chengwen/dev/novel-wirter/docs/mvp/doc-manifest.json)

本地先跑：

```bash
make mvp-docs-check
```
