# 试用准备与已知问题

本文档帮助你从零开始跑起 n0vel，并解决试用过程中最常见的问题。

## 最快启动路径

前提：你的电脑已安装 CI 当前固定的 Flutter stable 3.41.9。若 CI 版本更新，以工作流中的固定版本为准。如果还没有，见下方 [Flutter 安装](#flutter-安装)。

```bash
git clone https://github.com/changw98ic/n0vel.git
cd n0vel
flutter pub get
flutter run -d macos   # Windows 换 windows，Linux 换 linux
```

启动后在 Settings 中配置模型服务（见下方 [模型服务配置](#模型服务配置)），然后就可以创建项目、填写角色/世界观、发起 AI 生成。

## Flutter 安装

n0vel 是 Flutter 桌面应用。推荐使用 CI 当前固定的 Flutter stable 3.41.9，并确保 SDK 满足 `pubspec.yaml` 中的 Flutter/Dart 约束。

1. 前往 [flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install) 选择你的操作系统。
2. 按指引解压并加入 `PATH`。
3. 运行 `flutter doctor`，确认 Desktop 支持已开启。

```bash
flutter doctor
# 确认输出中有 ✓ 的 macOS / Windows / Linux develop 条目
```

如果 `flutter doctor` 显示桌面支持未开启，运行：

```bash
flutter config --enable-macos-desktop   # 或 --enable-windows-desktop / --enable-linux-desktop
```

### 平台命令速查

| 平台 | 启动命令 | 备注 |
| --- | --- | --- |
| macOS | `flutter run -d macos` | 需要 Xcode 及 Command Line Tools |
| Windows | `flutter run -d windows` | 需要 Visual Studio 桌面开发工作负载 |
| Linux | `flutter run -d linux` | 需要 GTK3、pkg-config 等系统依赖，见 `flutter doctor` 提示 |

### 为什么不推荐 Web / Chrome

当前 n0vel 使用 `sqlite3` 通过 `dart:ffi` 做本地存储，这个依赖在 Web/Chrome 上需要额外的 WASM 适配，尚未完成。桌面端是目前唯一稳定的试用路径。

## 模型服务配置

n0vel 不内置模型，你需要提供自己的 OpenAI 兼容 API 服务。

### 配置清单

| 步骤 | 字段 | 填写说明 |
| --- | --- | --- |
| 1 | Model service | 给服务起个名字，如 `OpenAI 兼容服务` |
| 2 | Base URL | API 接口地址，**注意是否需要以 `/v1` 结尾**（大部分服务需要） |
| 3 | Model | 服务商提供的模型 ID，如 `gpt-4o`、`deepseek-chat`，必须和后台完全一致 |
| 4 | API key | 你的密钥 |
| 5 | 连接测试 | 点击测试按钮，通过后再保存 |

### 常见模型配置失败

| 现象 | 先检查 |
| --- | --- |
| 连接测试立刻失败 | API key 是否已填写并保存 |
| 连接超时 | Base URL 是否可达（可在浏览器直接访问试一下）；公司网络是否需要代理 |
| 提示模型不存在 | Model 字段是否和服务商后台的模型 ID 完全一致，注意大小写 |
| 请求成功但返回空 | Base URL 路径是否正确，部分服务不需要 `/v1` 后缀 |
| 生成内容质量差 | 模型是否支持中文；是否使用了过小的模型；角色/世界观资料是否已填写 |

## 数据与隐私

- **本地优先**：所有项目资料（角色、世界观、场景、正文、版本）保存在本机 SQLite 数据库中。
- **AI 请求**：使用 AI 功能时，应用会将请求提示词和必要上下文（角色资料、世界观规则、场景摘要、相关正文片段）发送给你配置的模型服务。
- **不发送的内容**：未参与当前请求的项目资料不会被发送。
- **密钥存储**：API key 保存在本地应用配置中，并仅在调用你配置的模型服务时作为认证信息使用。

选择模型服务时，建议了解服务商的数据处理政策。

## 已知限制

- 暂无安装包，需要从源码运行。
- Web / Chrome 端暂不可用（sqlite3 dart:ffi 限制）。
- AI 生成的内容不会直接覆盖正文，需要作者确认后写入——这是预期行为。
- 运行中修改角色或世界观，当前进行中的 AI 任务可能仍使用启动时的快照；需要最新资料时重新发起生成。
- 项目导入/导出为 JSON 格式，暂不支持 Scrivener、Obsidian 等外部格式。

## 遇到问题？

1. 先查阅上方对应章节。
2. 如果是安装或启动问题，确认 `flutter doctor` 全部通过。
3. 如果是 AI 相关问题，先用连接测试确认模型服务可达。
4. 仍无法解决？请使用 [Author feedback issue 模板](https://github.com/changw98ic/n0vel/issues/new?template=author-feedback.yml) 反馈，我们会跟进。

---

本文档为推广文档/元数据，不涉及应用代码变更。CI 流水线通常只覆盖 lib/ 和 test/ 路径，本文档变更不会触发 CI 运行。
