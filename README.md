# Fluenta

**Fluenta** is a macOS AI writing popover for turning rough text into clear, natural writing without leaving the app you are already using.

Press a global shortcut, type or paste text, choose a writing mode, let your preferred LLM transform it, then insert the result back into the original text field.

## Languages

- English: this file
- [简体中文](README.zh-CN.md)
- [日本語](README.ja.md)
- [Español](README.es.md)

## What It Does

- Opens from a global macOS hotkey. The default is `Option+Space`.
- Transforms text with built-in prompt modes:
  - Translate to English
  - Improve Writing
  - Make Concise
  - Professional Tone
  - Friendly Reply
  - Custom Prompt
- Inserts generated text back into the previously focused app.
- Restores your clipboard after insertion.
- Lets you edit prompt modes, default mode, model, timeout, temperature, and hotkey.
- Supports multiple LLM providers, including OpenAI, Anthropic, Google Gemini, DeepSeek, Qwen, Moonshot Kimi, Zhipu GLM, MiniMax, SiliconFlow, Volcengine Ark, Tencent Hunyuan, Baichuan, 01.AI Yi, xAI, Groq, Mistral, OpenRouter, Perplexity, Together AI, Cerebras, and custom OpenAI-compatible endpoints.
- Provides English and Chinese app UI localization.

## Current Status

Fluenta is an early MVP. The repository currently includes:

- A Swift Package for the macOS app and core writing engine.
- A menu bar app with a writing popover and settings window.
- Provider adapters and configuration storage.
- Unit tests for core behavior.
- Manual test notes in [docs/manual-test-checklist.md](docs/manual-test-checklist.md).
- Product/design planning notes in `docs/superpowers/`.
- A separate `mac-os-efficiency-tool/` Next.js prototype used for UI exploration.

## Requirements

- macOS 14 or newer.
- Swift 6 toolchain.
- Full Xcode is recommended for XCTest support.
- Accessibility permission for Fluenta, required for returning focus to the previous app and pasting the generated result.
- An API key for at least one configured LLM provider.

## Build And Run

From the repository root:

```bash
swift build
swift run Fluenta
```

Run tests:

```bash
swift test
```

If tests fail because `XCTest` is unavailable, install the full Xcode app instead of using only Command Line Tools.

## First-Time Setup

1. Start the app with `swift run Fluenta`.
2. Open Fluenta from the menu bar and go to Settings.
3. Choose a provider and enter its API key.
4. Confirm the model, timeout, temperature, and default writing mode.
5. Grant Accessibility permission in macOS System Settings when prompted.
6. Focus any text field in another app, press `Option+Space`, enter text, press `Enter` to transform, then press `Enter` again to insert.

## Keyboard Flow

- `Option+Space`: open the writing popover.
- `Enter`: transform the source text, or insert the generated result when a result is already shown.
- `Command+Enter`: insert the original text without calling the model.
- `Escape`: clear the result or close the popover.
- `Command+,`: open Settings while Fluenta is active.

Prompt modes also have default shortcuts such as `Command+1` through `Command+6` in the mode list.

## Repository Layout

```text
Sources/WritingPopoverApp/       macOS app, popover UI, settings UI, menu bar coordination
Sources/WritingPopoverCore/      core config, providers, prompts, hotkeys, insertion, state machine
Tests/WritingPopoverCoreTests/   unit tests for core behavior
docs/                           manual QA and planning documents
mac-os-efficiency-tool/          Next.js UI prototype and design exploration
```

## Development Notes

- Keep provider behavior covered by focused unit tests.
- Use [docs/manual-test-checklist.md](docs/manual-test-checklist.md) before shipping user-facing app changes.
- Treat the clipboard and Accessibility flows carefully; they are central to the app experience.
- The project is still MVP-stage, so README details should track the code rather than future plans.
