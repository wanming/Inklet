# Inklet

[English](README.md) | [简体中文](README.zh-CN.md)

官网：[gitinklet.app](https://gitinklet.app)

**Turn rough thoughts into clear text.**

**Inklet** 是一款 macOS 写作助手，可以把你输入、粘贴或说出的想法整理成清晰自然的文字，并直接插回正在使用的应用。

你可以用全局快捷键打开写作浮窗，然后在同一份可编辑原文草稿中输入、粘贴或听写。实时听写已合并到写作助手，转写完成后会停留在草稿里，等待你检查和编辑。在 Apple 芯片的 Mac 上，新安装默认在本机识别语音，声音不会离开这台 Mac。

## 演示

观看演示视频：[Inklet on YouTube](https://www.youtube.com/watch?v=F5wmFruo0a4)。

## 安装

GitHub Releases 是 Inklet 唯一支持的发布渠道。请从 [GitHub Releases](https://github.com/wanming/Inklet/releases) 下载最新已签名并完成 Apple 公证的 DMG，打开后把 Inklet 复制到 `/Applications`。

也可以使用下面的安装脚本。安装脚本会下载最新 GitHub Releases DMG 及 checksum，验证 DMG 结构、checksum、Gatekeeper、bundle identifier、Hardened Runtime、effective entitlements 和 App 签名，再把 Inklet 复制到 `/Applications`。

```bash
curl -fsSL https://raw.githubusercontent.com/wanming/Inklet/main/scripts/install.sh | bash
```

## 更新

Inklet 仅通过 GitHub Releases 检查更新。正式版大约每 24 小时从 GitHub 获取一次最新稳定版的公开元数据。只有该 release 已上传 `Inklet.dmg` 时才会提示更新；选择**在 GitHub 上查看**会打开这个 release 的准确页面。Inklet 不会自动下载或安装更新。

正式版和 Inklet Local 都可以从 App 菜单选择**检查更新…**手动检查；Inklet Local 不会安排自动检查。自动检查失败时保持静默，手动检查失败时可选择**重试**。写作、听写、选区动作、迁移、模态窗口或已打开的菜单使 Inklet 忙碌时，自动更新提示会等到 App 空闲后再显示。

更新后第一次打开新版本时，会在 Inklet 空闲时弹出一次简短的**新功能**窗口，不会抢走你正在用的 App 的焦点。新安装或欢迎引导打开时不会出现。菜单栏菜单里的**更新日志**会列出所有版本的更新，并高亮你正在用的版本。

## 首次设置

1. 从 Applications 文件夹打开 Inklet。需要运行源码构建时，请在仓库根目录执行 `scripts/run-local-app.sh`，然后使用 `/Applications/Inklet Local.app`。
2. 点击菜单栏里的 Inklet 图标，打开 Settings。
3. 按 macOS 提示授予 Accessibility 权限。Inklet 用这一个通用权限读取选区、执行已配置的复制备用流程、回到上一个应用并粘贴确认后的结果。系统设置打开期间 Inklet 会留在后台；关闭系统设置后 Inklet 会返回 General 设置页。
4. 新安装后，以及老用户升级到这个版本后的第一次启动，会打开欢迎引导，一步步设置辅助功能、写作模型、实时听写用的麦克风，以及打开 Inklet 和听写的快捷键。在 Apple 芯片的 Mac 上，引导默认选择**内置**模型，确认后在后台下载推荐的模型；写作浮窗会显示下载进度，下载完成后离线也能用。如果想改用云端服务商，在 General 中选择服务商并填写它的 API key。Intel Mac 默认使用 OpenAI，一把 key 处理写作、实时听写、选区翻译和发音。选择其他服务商时，写作和选区翻译使用该服务商；发音，以及选择 OpenAI 识别时的听写，仍需要在单独的可选字段中填写 OpenAI API key。如果想在本机运行写作和翻译、不填任何 key，可以选择**内置**并下载一个模型；如果你已经在用 Ollama 或 LM Studio，也可以直接选择它们（见[本地模型](#本地模型)）。
5. 在 Writing Assistant 中配置模型、写作快捷键、生成参数和 Prompt 模式。实时听写有单独的设置页，可以开启或关闭，选择用**本机**还是 **OpenAI** 识别语音，并选择长按快捷键和麦克风。在 Apple 芯片的 Mac 上，新安装默认使用**本机**，在欢迎引导里开启听写时会下载语音模型；已有配置继续使用 OpenAI，直到你手动切换。使用 OpenAI 时，高级听写只提供恢复模型，不提供端点设置；恢复端点不可编辑。实时模型由 Inklet 固定。
6. 可选：在 Selection Assistant 中配置翻译语言、强制取词模式、AI 发音声音和发音速度，并在设置中试听该声音。
7. 第一次有效长按听写快捷键时授予 Microphone 权限。只打开 Inklet、查看 Settings，或在原文编辑器之外按快捷键都不会请求权限。

## 日常使用

文字输入流程：

1. 在任意应用里聚焦一个文本框。
2. 按 `Option+Space`。
3. 用模糊搜索查找 Prompt 模式（例如 `ts` 可以匹配 `To Chinese Summary`），用 `↑` / `↓` 高亮，然后按 `Tab` 或 `Enter` 确认。
4. 输入或粘贴一段草稿。
5. 按 `Enter` 让 Inklet 处理文本。结果会边生成边显示；按 `Escape` 可停止。
6. 再按一次 `Enter` 插入结果，或按 `Shift+Command+C`（也可点击结果上的复制按钮）改为复制。

听写流程：

1. 用 `Option+Space` **打开写作助手**。
2. **确认一个 Prompt 模式**。模式选择器和结果编辑器中不能开始听写。
3. **把光标放入原文草稿，或选中要替换的文本。** 听写会在光标处插入，或替换选区。
4. **长按已配置的听写快捷键**（默认 Right Option）并正常说话，转写草稿会原位更新。短按不会执行任何操作。如果实时连接失败，继续长按并说话，Inklet 会保留一份临时恢复录音。
5. **松开以完成转写**。使用**本机**识别时，恢复录音也在本机转写。使用 OpenAI 时，如需恢复，Inklet 会使用实时听写所用的同一把现有 OpenAI API key，只向 `https://api.openai.com/v1/audio/transcriptions` 发出一个请求。临时录音在备用请求真正开始前始终只保存在本机，最多上传一次，并在听写会话结束时删除。
6. 检查并编辑听写草稿。听写本身不会运行 Prompt 模式，也不会把文本插入其他 App。
7. **准备好后再按 Return** 运行已确认的 Prompt 模式；只有要插入结果时才再按一次 Return。

听写快捷键仅在原文编辑器内生效，并且只支持长按。你可以在 Settings → 实时听写中把修饰键改为 Right Command、Left Option、Left Command，或直接关闭实时听写。Escape、焦点丢失、关闭浮窗或开始新的原文会话都会取消听写并恢复原草稿。

## 功能

- 使用全局 macOS 快捷键打开。默认是 `Option+Space`。
- 在写作助手原文编辑器处于活动状态时，长按 modifier key 快捷键，把实时听写写入草稿。默认是 Right Option。
- 选中文本并短暂停顿后显示选区动作，可快速翻译、自定义 Translate prompt、使用 AI 发音；翻译结果窗口可调整大小并记住上次尺寸，也会为重复翻译提供 7 天本地缓存。
- 超过 1,500 个字符的选中文本会被忽略，避免误选整页时触发。
- 可直接播放选中文本，也可在翻译结果里分别播放原文和译文。
- 可在 设置 › Selection Assistant › 菜单按钮 中选择选区菜单显示哪些按钮及其顺序。Translate、Pronounce 和任意 Prompt 模式都可以作为按钮；最多同时显示四个，其余放在 **更多** 里。点击 Prompt 模式按钮会用该模式处理选中文本，并在面板中显示结果，可复制和播放。
- 内置文本处理模式：
  - To Simple and Correct English
  - To Chinese Summary
  - Voice Cleanup
- 结果边生成边显示在浮窗中，完成后可插回之前聚焦的应用，或用结果上的复制按钮复制。
- 使用与应用无关、Accessibility 优先的通用选区流程。自动选区动作先通过 macOS Accessibility 读取；只有强制取词设置允许时，才进入按设置启用的临时剪贴板备用读取。每次读取都绑定到捕获的来源进程；来源退出或失去前台焦点时会取消。
- 默认关闭模拟 `Command+C`。菜单复制仍是安全的强制取词备用方式；对于没有可用复制菜单的 App，可以显式开启模拟复制这一高级备用选项，但它可能干扰游戏、远程桌面或虚拟机。
- 临时剪贴板读取会串行执行。只有同一次读取仍持有已观察到的复制结果时，Inklet 才恢复之前的快照；较新的剪贴板内容优先。双击复制触发是被动流程：它只读取用户已经完成的复制，不会再发一次合成复制，也不会恢复更旧的剪贴板数据。右键点击保留原生行为，不会开始选区读取。
- 不包含浏览器专用的选区代码，也不会请求浏览器 Automation。Chrome、Safari、Edge 和原生 App 使用同一条通用流程。
- 可以编辑 Prompt 模式、服务商、模型、自定义 OpenAI 兼容接口地址、timeout、写作快捷键、听写长按快捷键、麦克风、恢复模型、选区翻译语言、选区 Translate prompt、选区菜单按钮、强制取词模式、模拟复制权限、AI 发音声音和 AI 发音速度。
- 在本地 History 中查看成功的写作和选区结果，连续重复项会自动合并，原文/结果文本可选择，可一键复制结果或清空全部历史；旧版 Voice History 仍可读取。
- 写作和翻译可使用 OpenAI、Anthropic、Google Gemini、DeepSeek、阿里通义千问（Alibaba Qwen）、月之暗面 Kimi、智谱 GLM、MiniMax、硅基流动（SiliconFlow）、火山方舟（Volcengine Ark）、腾讯混元、百川、零一万物 Yi、xAI、Groq、Mistral、OpenRouter、Perplexity、Together AI、Cerebras，或任意自定义 OpenAI 兼容接口（例如本地模型服务）。发音始终使用 OpenAI；听写使用实时听写设置中选择的语音识别引擎。
- 写作和翻译可以在本机运行：使用内置引擎（Qwen3.5 4B 或 Gemma 4 E4B，从 Hugging Face 下载一次），或连接本机的 Ollama、LM Studio。不需要 API key，文字不会离开你的 Mac。
- 提供英文、简体中文、繁体中文、日文、韩文、西班牙文、法文、德文、葡萄牙文和意大利文应用界面。
- 紧凑选区菜单以及设置、写作界面中的受限控件会根据译文调整布局；切换语言时刷新已打开的界面并保留写作内容。

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
- Accessibility 权限，用于通用选区读取、按设置启用的复制备用流程、回到上一个应用并粘贴生成结果。
- Microphone 权限，仅在有效长按听写快捷键时用于实时听写。
- OpenAI 或其他受支持服务商的 API key，或者使用本地模型。发音，以及使用 OpenAI 识别的听写，需要 OpenAI API key。

## 本地模型

Inklet 可以用在你 Mac 上运行的模型来写作和翻译，文字不会离开本机，也不需要 API key。

- **内置**（仅限 Apple 芯片，新安装的默认选项）：服务商选择**内置**，选一个模型，点击**下载**。内存 16 GB 及以上的 Mac 默认使用 Gemma 4 E4B（约 4.6 GB），8 GB 推荐 Qwen3.5 4B（约 2.7 GB）。新安装时在欢迎引导里下载；下载期间写作浮窗会显示进度，模型还没下载时浮窗里也有**下载**按钮。下载中断后可以接着下载，使用前会按固定的 SHA-256 校验。选择内置后，打开写作浮窗时 Inklet 会在回环地址上启动内置的 llama.cpp 服务并提前加载模型，通常你输完文字时模型已经就绪。内存 24 GB 及以上的 Mac 会让模型一直常驻，只在系统内存紧张时释放；内存更小的 Mac 空闲 5 分钟后释放模型。
- **本机听写**（仅限 Apple 芯片，新安装的默认选项）：实时听写使用 Qwen3-ASR 0.6B（约 1 GB）识别语音，支持 30 种语言和中英混说。它使用同一个内置 llama.cpp 引擎、单独的服务进程，说话时大约每 0.6 秒重新识别一次，在停顿处把句子定稿。内存 16 GB 及以上的 Mac 会在开启听写期间常驻语音模型；内存更小的 Mac 在打开写作浮窗时加载，空闲 5 分钟后释放。关闭听写或改用 OpenAI 会停止它。
- **Ollama**：安装 [Ollama](https://ollama.com)，运行 `ollama pull qwen3.5:4b`，然后选择 **Ollama**。Inklet 会列出 Ollama 已下载的模型。
- **LM Studio**：在 LM Studio 中启动本地服务（端口 1234）并加载一个模型，然后选择 **LM Studio**。

本地服务商的每次请求至少有 120 秒，让第一次请求有时间加载模型。Inklet 会让本地服务跳过“思考”，让小型推理模型直接给出结果。源码构建通过 `scripts/build-llama-server.sh` 编译内置引擎，需要 `cmake`；如果缺少它，App 仍可运行，内置选项会提示这个版本没有内置引擎。

## 从源码构建和运行

每次构建 app bundle 前，都要递增根目录 `VERSION` 中的 `INKLET_VERSION` 和 `INKLET_BUILD_NUMBER`。通常递增补丁版本；较大变更使用次版本或主版本。构建号必须是大于所有已用构建号的正整数，不能因版本号变化而重置。选择构建号前，请检查最新 `main`、Git tags、所有 GitHub releases（包括草稿）以及正在使用的 worktrees。Inklet 仅通过构建号判断是否有更新。

远端 GitHub DMG 构建只使用 `main` 分支。先将本次改动和更新后的 `VERSION` 合并并推送到 `main`，再以 `--ref main` 触发 `build-dmg.yml`。

正式发布前，确认构建成功并验证最终产物，将占位描述替换为相较上次正式版的中英文更新说明，再发布为最新稳定版。已验证的草稿可直接正式发布，无需重新构建或修改版本号。

DMG 工作流会在构建前检查并拒绝重复或更小的构建号，但不会自动递增这两个值。手动验证方法见[发布版本检查](scripts/README.md#release-version-checks)。修改已打包 app 的版本需要重新构建、签名、公证并生成 checksum；只修改 release 标题或文件名不会更新 app 内的版本。

在仓库根目录运行：

```bash
swift build
scripts/run-local-app.sh
```

日常手动测试请从任意 worktree 使用 `scripts/run-local-app.sh`。它会安装并打开稳定的 `/Applications/Inklet Local.app` 身份，让 macOS 的 Accessibility 和 Keychain 授权可以跨 rebuild 复用。

运行测试：

```bash
swift test
```

如果测试因为 `XCTest` 不可用而失败，请安装完整 Xcode，而不是只安装 Command Line Tools。

使用 `scripts/check-localization.sh` 检查所有界面语言。加上 `--snapshots` 可在 `.build/localization-audit/` 下生成使用模拟数据的原生界面 HTML 截图集，命令会输出文件路径。Pull request 和推送到 `main` 的提交会自动运行全部单元测试和本地化检查。检查范围和仍需手动验证的项目见[本地化检查说明](docs/localization-audit.md)。

## 快捷键

- `Option+Space`：打开写作 popover。
- `Right Option`：写作助手原文编辑器处于活动状态时长按听写。可在 Settings → 实时听写中修改修饰键或关闭实时听写；短按始终不执行操作。
- 模式启动器中的 `↑` / `↓`：在按模糊匹配度排序的 Prompt 模式之间移动高亮。
- 模式启动器中的 `Tab`、`Return` 或小键盘 `Enter`：确认高亮的 Prompt 模式并聚焦源文本编辑器。输入法正在组合文字时，Return 仍用于确认文字或候选项；配合 Command、Shift、Option 或 Control 的 Return 不会确认模式。
- 编辑器中的 `Enter`：处理源文本；插入由当前模式生成的结果；如果可见结果由之前的模式生成，则用刚确认的新模式重新生成。
- `Command+Enter`：不调用模型，直接插入原文。
- `Shift+Command+C`：复制当前结果，浮窗保持打开。
- `Command+Up` / `Command+Down`：切换可见 prompt modes。
- `Escape`：每按一次只返回一层，依次从结果回到源文本编辑器、模式启动器，再关闭 popover。处理文本期间按下会停止生成、丢弃未完成的结果，并停留在编辑器。
- `Command+,`：Inklet 激活时打开 Settings。

搜索不区分大小写和变音符号，并支持按顺序匹配字符。完全匹配和前缀匹配获得最高加权；连续、词首、更靠前及间隔更紧密的匹配通常排名更高。

模式启动器打开时，如果上次确认的 Prompt 模式仍然可见，就会高亮该模式。单击只会高亮模式，双击会确认；返回模式启动器时会保留当前草稿和结果。

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
- 日常手动测试 app 时使用 `scripts/run-local-app.sh`，不要直接运行 SwiftPM 可执行文件或 `open dist/...`，这样本机 Accessibility 和 Keychain 授权会绑定到同一个稳定 app 身份。
- 剪贴板和 Accessibility 流程是核心体验，需要谨慎处理。
- 项目仍处于 MVP 阶段，README 应描述当前代码已经支持的能力，而不是未来计划。

## 本地存储与升级

正式版与本地 QA 版使用按 bundle 标识符隔离的存储，不共享设置、History、翻译缓存、诊断文件或 Keychain 凭据：

- 正式版 Application Support：`~/Library/Application Support/com.tomwan.inklet/`
- 本地版 Application Support：`~/Library/Application Support/com.tomwan.inklet.local/`
- 正式版偏好设置：`~/Library/Preferences/com.tomwan.inklet.plist`
- 本地版偏好设置：`~/Library/Preferences/com.tomwan.inklet.local.plist`
- Provider API keys：对应 Application Support 目录里的 `api-keys.json`，只有你的用户账户能读取，不会进入 Time Machine 备份
- 旧版本使用的 Keychain service：`Inklet.ProviderAPIKey`（正式版）和 `Inklet.Local.ProviderAPIKey`（本地版）

旧版本把 API key 存在 Keychain 里。第一次用到某个 key 时，Inklet 会把它从 Keychain 复制到 `api-keys.json`，并保留 Keychain 里的条目，所以退回旧版本仍然能读到。在 Settings 中修改或清空 key 时，会删除 Keychain 里的副本。

从旧版 sandbox 构建升级后的第一次启动中，Inklet 会自动复制已识别的旧版偏好设置、把 provider API keys 写入对应 Keychain service，并把 History 复制到当前 bundle 的存储中。迁移不会删除或修改旧版来源，因此旧数据仍可用于回滚或恢复。可丢弃的翻译缓存不会迁移。

如果 macOS 阻止自动访问对应的旧容器，Settings 会持续提供**导入旧数据…**操作。辅助导入只接受当前正式版或本地版对应的准确旧版 `Data` 文件夹，只在当前文件选择授权有效期间读取，并且不会保存永久访问 bookmark。

## 隐私

- Inklet 会使用你在设置中选择的服务商及其 API key 处理写作和选区翻译。发音始终使用你的 OpenAI API key 调用 OpenAI。只有在把语音识别选为 OpenAI 时，听写才会使用 OpenAI。
- 使用**本机**语音识别时，听写音频和恢复录音都由本机上的服务处理，不会离开这台 Mac。
- 使用 OpenAI 语音识别时，长按听写快捷键期间，活动麦克风音频会直接流式发送到 OpenAI Realtime 转写服务。Inklet 还会保存一份临时本地恢复录音；它在备用请求真正开始前始终只保存在本机，最多上传一次到 `https://api.openai.com/v1/audio/transcriptions`，使用实时听写所用的同一把现有 OpenAI API key，并在每个会话终止路径中删除。
- API key 按服务商分别存储在你的 Mac 本地。
- 使用内置、Ollama 或 LM Studio 时，写作和翻译请求只发送到你 Mac 上的服务。下载内置模型时，会向 Hugging Face 请求一次所选文件；请求中不包含你的文字、音频、API key 或设置。
- Inklet 使用 Accessibility 权限完成通用选区读取、按设置启用的复制备用流程、回到上一个应用并粘贴文本。
- Inklet 只在写作助手原文编辑器内有效长按听写快捷键时使用 Microphone 权限。听写完成后仍停留在可编辑草稿，不会插入其他 App。
- Inklet 会临时使用剪贴板完成插入和已配置的强制取词备用读取。强制取词仅在 Inklet 的临时复制内容仍是当前内容时恢复原剪贴板，不会覆盖之后发生的外部剪贴板变化。
- Inklet 会把成功的写作和选区原文/结果作为本地 History 保存，直到你在 Settings 中清空；连续重复项会自动跳过。未经处理的听写草稿不会创建 History；已有的旧版 Voice 条目仍可在本机读取。
- 选区动作会捕获来源 App 和选区位置，在读取前和读取期间验证来源，然后通过 Accessibility 读取该 App 的当前选区。如果 Accessibility 没有返回选中文本，设置中的强制取词模式可以短暂调用菜单复制，并通过上面所述的受保护剪贴板事务读取复制出的文本。模拟 `Command+C` 默认关闭，只有显式开启高级选项后才会运行。你可以在设置中关闭强制取词。此流程不会发送针对浏览器的 Apple Events，也不会请求浏览器 Automation。选中文本后快速按两次 `Command+C`，会显式读取你已经完成的复制。Inklet 不会保存仅被选中的文本；只有成功完成的动作会进入本地 History。
- Selection Assistant 会把成功的翻译结果用哈希缓存键在本地缓存 7 天，以加速重复翻译。
- 当本地没有可用缓存时，Selection Assistant 翻译会把选中文本和自定义 Translate 指令发送到你选择的服务商；Prompt 模式按钮会把选中文本和该模式的 prompt 发送到你选择的服务商；AI 发音会把选中文本发送到 OpenAI。
- Inklet 最多每天从 `models.dev` 获取一次公开模型目录。该请求不包含你的文本、音频、API keys 或应用设置。
- 除非你信任 OpenAI 或所选服务商的数据处理政策，否则不要发送私密文本或音频。

## 反馈

在 Inklet 菜单栏菜单中选择 **发送反馈…**，或直接[提交 issue](https://github.com/wanming/Inklet/issues/new/choose)。欢迎报告问题和提出功能建议；请勿在 issue 中粘贴 API key 或私密文本。

## 贡献

请查看 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 安全

漏洞报告和敏感数据说明请查看 [SECURITY.md](SECURITY.md)。

## 许可证

Inklet 使用 [MIT License](LICENSE) 发布。
第三方许可说明见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
