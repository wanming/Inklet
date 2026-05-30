# Inklet

[English](README.md) | [简体中文](README.zh-CN.md)

**Turn rough thoughts into clear text.**

**Inklet** 是一款 macOS 写作助手，可以把你输入、粘贴或说出的想法整理成清晰自然的文字，并直接插回正在使用的应用。

你可以用全局快捷键打开一个小型写作窗口，也可以用语音快捷键录入一小段话。Inklet 能改写、总结、清理语音转写内容，并把结果插入回原来的文本框。

## 演示

观看演示视频：[Inklet on YouTube](https://www.youtube.com/watch?v=F5wmFruo0a4)。

## 安装

从 GitHub Releases 下载最新已签名并公证的 DMG，或使用下面的安装脚本。脚本会下载最新 DMG，校验 checksum，并复制 Inklet 到 `/Applications`。

```bash
curl -fsSL https://raw.githubusercontent.com/wanming/Inklet/main/scripts/install.sh | bash
```

如果你从私有 fork 或私有 release 安装，需要传入有仓库读取权限的 GitHub token：

```bash
export GITHUB_TOKEN="$(gh auth token)"
curl -fsSL -H "Authorization: Bearer $GITHUB_TOKEN" \
  https://raw.githubusercontent.com/wanming/Inklet/main/scripts/install.sh | bash
```

安装到其他目录：

```bash
curl -fsSL https://raw.githubusercontent.com/wanming/Inklet/main/scripts/install.sh | \
  INKLET_INSTALL_DIR="$HOME/Applications" bash
```

## 首次设置

1. 从 Applications 文件夹打开 Inklet，或者在源码目录运行 `swift run Inklet`。
2. 点击菜单栏里的 Inklet 图标，打开 Settings。
3. 按 macOS 提示授予 Accessibility 权限。Inklet 需要这个权限来回到上一个应用并粘贴结果。系统设置打开期间 Inklet 会留在后台；关闭系统设置后 Inklet 会返回 provider 设置页。
4. 选择一个 LLM provider，并填写它的 API key。
5. 确认你想使用的模型和 prompt modes。
6. 可选：在 Voice 设置里配置 speech API key、speech preset、语音快捷键和 cleanup mode。
7. 第一次使用语音输入时，请授予 Microphone 权限。

## 日常使用

文字输入流程：

1. 在任意应用里聚焦一个文本框。
2. 按 `Option+Space`。
3. 输入或粘贴一段草稿。
4. 按 `Enter` 让 Inklet 处理文本。
5. 再按一次 `Enter` 插入结果。

语音输入流程：

1. 在任意应用里聚焦一个文本框。
2. 轻按一次 Right Option 开始录音。
3. 说一小段话。
4. 再轻按一次 Right Option 停止录音。
5. Inklet 会转写音频，可选地用所选 prompt mode 清理转写内容，然后插入最终文本。

默认语音快捷键是 Right Option。你可以在 Settings 中改成 Right Command、Left Option、Left Command，或直接关闭。

## 功能

- 使用全局 macOS 快捷键打开。默认是 `Option+Space`。
- 用单个 modifier key 轻按开始短语音输入。默认语音快捷键是 Right Option。
- 内置文本处理模式：
  - To Simple and Correct English
  - To Chinese Summary
  - Voice Cleanup
- 把生成结果插回之前聚焦的应用。
- 插入后恢复你的剪贴板内容。
- 可以编辑 prompt modes、模型、timeout、temperature、热键、语音快捷键、speech preset、speech endpoint 和 speech model。
- 支持多个 LLM provider，包括 OpenAI、Anthropic、Google Gemini、DeepSeek、Qwen、Moonshot Kimi、Zhipu GLM、MiniMax、SiliconFlow、Volcengine Ark、Tencent Hunyuan、Baichuan、01.AI Yi、xAI、Groq、Mistral、OpenRouter、Perplexity、Together AI、Cerebras，以及自定义 OpenAI-compatible endpoint。
- 提供英文和中文应用界面。

## 当前状态

Inklet 是早期 MVP。当前仓库包含：

- macOS app 和核心写作引擎的 Swift Package。
- 带写作 popover 和设置窗口的菜单栏应用。
- Provider adapters 和配置存储。
- 核心行为的单元测试。
- 手动测试说明：[docs/manual-test-checklist.md](docs/manual-test-checklist.md)。

## 系统要求

- macOS 14 或更新版本。
- Swift 6 toolchain。
- 推荐安装完整 Xcode，以获得 XCTest 支持。
- Accessibility 权限，用于回到上一个应用并粘贴生成结果。
- Microphone 权限，用于语音输入。
- 至少一个已配置 LLM provider 的 API key。
- 语音输入需要 speech transcription API key。

## 从源码构建和运行

在仓库根目录运行：

```bash
swift build
swift run Inklet
```

运行测试：

```bash
swift test
```

如果测试因为 `XCTest` 不可用而失败，请安装完整 Xcode，而不是只安装 Command Line Tools。

## 快捷键

- `Option+Space`：打开写作 popover。
- `Right Option`：默认开始或停止语音输入。可以在 Settings 中修改或关闭。
- `Enter`：处理源文本；如果已经显示结果，则插入生成结果。
- `Command+Enter`：不调用模型，直接插入原文。
- `Command+Up` / `Command+Down`：切换可见 prompt modes。
- `Escape`：清空结果或关闭 popover。
- `Command+,`：Inklet 激活时打开 Settings。

Prompt modes 默认也可以使用 `Command+1` 到 `Command+6` 这样的快捷键。
Popover 打开时会默认选中 Settings 里第一个可见的 prompt mode。

## 仓库结构

```text
Sources/InkletApp/       macOS app, popover UI, settings UI, menu bar coordination
Sources/InkletCore/      core config, providers, prompts, hotkeys, insertion, state machine
Tests/InkletCoreTests/   unit tests for core behavior
docs/                    手动测试说明和隐私政策
```

## 开发说明

- Provider 行为应保持有聚焦的单元测试覆盖。
- 发布用户可见的 app 改动前，请使用 [docs/manual-test-checklist.md](docs/manual-test-checklist.md)。
- 剪贴板和 Accessibility 流程是核心体验，需要谨慎处理。
- 项目仍处于 MVP 阶段，README 应描述当前代码已经支持的能力，而不是未来计划。

## 隐私

- Inklet 使用你配置的 provider API key 调用所选 LLM provider。
- 使用语音输入时，临时音频会发送到你配置的 speech transcription provider。
- API keys 存储在你的 Mac 本地。
- Speech API keys 存储在你的 Mac 本地。
- Inklet 使用 Accessibility 权限回到上一个应用并粘贴文本。
- Inklet 只在录音语音输入时使用 Microphone 权限。
- Inklet 会临时使用剪贴板完成插入，然后恢复之前的剪贴板内容。
- Inklet 最多每天从 `models.dev` 获取一次公开模型目录。该请求不包含你的文本、音频、API keys 或应用设置。
- 除非你信任某个 provider 的数据处理政策，否则不要向它发送私密文本或音频。

## 贡献

请查看 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 安全

漏洞报告和敏感数据说明请查看 [SECURITY.md](SECURITY.md)。

## 许可证

Inklet 使用 [MIT License](LICENSE) 发布。
