# 安全基线验收清单（Codex）

> 目标：把安全基线条目与实现、测试和发布门禁直接绑定，形成 W2 可核查证据。

| 条目 | 控制要求 | 实现与证据 | 当前状态 |
| --- | --- | --- | --- |
| 明文禁存 | API Key 与敏感字段不应明文写入 settings.json | `SettingsJsonCipher` 对持久化内容进行 AES-256-GCM 信封封装；`test/app_settings_storage_io_test.dart` 验证写入内容不含 `sk-` 明文与 `apiKey` 字段。 | 已覆盖（W2） |
| 密钥生命周期与最小权限 | 首次运行生成随机 32 字节密钥；支持 `.settings.key` 存储；最小权限写入 | `SettingsJsonCipher._loadSecretKey` 负责初始化与校验；非 Windows 自动 `chmod 600`。 | 已覆盖（W2） |
| 鉴权/配额/网络/超时分类可观察 | 配置测试与请求失败分类可区分，并保留可观测输出 | `AppSettingsStore._connectionStateFromChatResult` 覆盖 `unauthorized/timeouts/modelNotFound/network/rateLimited`；`test/app_settings_store_test.dart` 与 `test/settings_persistence_test.dart` 覆盖保存/连接反馈。 | 已覆盖（W1/W2） |
| 配置变更可追踪 | 关键配置变化需有日志元信息记录（时间、动作、脱敏参数） | `AppSettingsStore._scheduleSettingsLog` 在保存/重试/连接测试中写入 `app_event_log`，并在测试中验证元数据脱敏。 | 已覆盖（W2） |
| 安全回归覆盖 | 覆盖缺失配置、错误 token、存储损坏与 key mismatch 场景 | `test/app_settings_storage_io_test.dart`：`malformed json`、`non-object json`、`corrupted ciphertext`、`key mismatch`、`write failures`。 | 已覆盖（W1） |
| 审计与撤销路径 | 支持异常诊断展示、人工复制、重试与恢复流程 | `AppSettingsStore.feedback/diagnostic`、`retrySecureStoreAccess`、设置页诊断复制与重试按钮；`test/settings_persistence_test.dart` 覆盖对应 UI 与日志行为。 | 已覆盖（W1） |

## W2 阻断映射

- 自动阻断：`flutter test`、`flutter analyze`、`make mvp-docs-check`（见 `docs/roadmap/quality-gates.md` / `.github/workflows/mvp-blocking-checks.yml`）。
- 手工复核：本清单每次更新需在 `docs/roadmap/w0-consistency-signoff.md` 记录通过时间与复核结论。

### 复核口径

- 当前状态基于代码路径与测试结果评估，不足项必须在下一次 PRD 实现里程碑补齐前置。
