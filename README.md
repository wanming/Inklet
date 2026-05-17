# Fluenta

Fluenta 是一个 macOS AI 写作浮窗。用户通过全局快捷键唤起浮窗，输入中文或英文原文，选择或自动解析 prompt mode，调用 LLM 转换后，把结果插入到原来的输入框。

当前仓库处于 MVP 早期阶段，已包含：

- 中文产品设计 spec。
- 实现计划。
- Swift Package 骨架。
- 最小核心状态机测试。

## 目标体验

```text
全局快捷键 -> 输入原文 -> LLM 转换 -> 插入当前 App
```

## 开发

```bash
swift test
swift build
```

注意：当前机器如果只有 Command Line Tools 而没有完整 Xcode，`XCTest` 可能不可用；安装完整 Xcode 后再运行测试。
