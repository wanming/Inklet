# 手动测试清单

## 准备

- 从 Xcode 或 `swift run Fluenta` 启动 App。
- 在设置里配置 OpenAI API key。
- 在 macOS System Settings 中授予 Accessibility 权限。
- 默认快捷键为 Option+Space。

## 核心流程

- TextEdit：聚焦输入框，按 Option+Space，输入中文，Enter 转换，再 Enter 插入英文。
- TextEdit：输入英文病句，Enter 润色，再 Enter 插入。
- Notes：重复中文转英文流程。
- Safari 或 Chrome：在网页文本框中重复中文转英文流程。
- Cmd+Enter：不调用 LLM，直接插入原文。
- Escape：关闭浮窗，不插入内容。
- 缺少 API key：显示错误，原文不丢失。
- 断网或 provider 失败：显示错误，原文不丢失。
- 粘贴失败：保留生成结果，并允许复制。
- 插入后剪贴板恢复为插入前内容。

## 观察性兼容

- Slack 或 Discord。
- Notion。
- VS Code 或 Cursor。
- Terminal 或 iTerm，只记录表现，不作为 MVP 阻断项。
