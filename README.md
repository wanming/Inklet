# Inklet

**Inklet** is a macOS AI writing popover for turning rough text into clear, natural writing without leaving the app you are already using.

Press a global shortcut, type or paste text, choose a writing mode, let your preferred LLM transform it, then insert the result back into the original text field.

## Demo

Watch the demo video: [Inklet on YouTube](https://www.youtube.com/watch?v=F5wmFruo0a4).

## What It Does

- Opens from a global macOS hotkey. The default is `Option+Space`.
- Starts short voice dictation from a single modifier-key tap. The default voice shortcut is Right Option.
- Transforms text with built-in prompt modes:
  - To Simple and Correct English
  - To Chinese Summary
  - Voice Cleanup
- Inserts generated text back into the previously focused app.
- Restores your clipboard after insertion.
- Lets you edit prompt modes, model, timeout, temperature, hotkey, voice shortcut, speech endpoint, and speech model.
- Supports multiple LLM providers, including OpenAI, Anthropic, Google Gemini, DeepSeek, Qwen, Moonshot Kimi, Zhipu GLM, MiniMax, SiliconFlow, Volcengine Ark, Tencent Hunyuan, Baichuan, 01.AI Yi, xAI, Groq, Mistral, OpenRouter, Perplexity, Together AI, Cerebras, and custom OpenAI-compatible endpoints.
- Provides English and Chinese app UI localization.

## Current Status

Inklet is an early MVP. The repository currently includes:

- A Swift Package for the macOS app and core writing engine.
- A menu bar app with a writing popover and settings window.
- Provider adapters and configuration storage.
- Unit tests for core behavior.
- Manual test notes in [docs/manual-test-checklist.md](docs/manual-test-checklist.md).

## Requirements

- macOS 14 or newer.
- Swift 6 toolchain.
- Full Xcode is recommended for XCTest support.
- Accessibility permission for Inklet, required for returning focus to the previous app and pasting the generated result.
- Microphone permission for voice dictation.
- An API key for at least one configured LLM provider.
- A speech transcription API key for voice dictation.

## Install

Until Inklet has Developer ID signing and notarization, the easiest install path is the script below. It downloads the latest DMG, verifies its checksum, copies Inklet to `/Applications`, and removes the macOS quarantine flag that can otherwise show a misleading "damaged" warning.

```bash
curl -fsSL https://raw.githubusercontent.com/wanming/Inklet/main/scripts/install.sh | bash
```

If you are installing from a private fork or private release, pass a GitHub token that can read that repository:

```bash
export GITHUB_TOKEN="$(gh auth token)"
curl -fsSL -H "Authorization: Bearer $GITHUB_TOKEN" \
  https://raw.githubusercontent.com/wanming/Inklet/main/scripts/install.sh | bash
```

To install somewhere else:

```bash
curl -fsSL https://raw.githubusercontent.com/wanming/Inklet/main/scripts/install.sh | \
  INKLET_INSTALL_DIR="$HOME/Applications" bash
```

## Build And Run

From the repository root:

```bash
swift build
swift run Inklet
```

Run tests:

```bash
swift test
```

If tests fail because `XCTest` is unavailable, install the full Xcode app instead of using only Command Line Tools.

## First-Time Setup

1. Start the app with `swift run Inklet`.
2. Open Inklet from the menu bar and go to Settings.
3. Choose a provider and enter its API key.
4. Confirm the model, timeout, temperature, and prompt mode order.
5. Configure Voice settings if you want dictation, including the speech API key and speech model.
6. Grant Accessibility permission in macOS System Settings when prompted.
7. Grant Microphone permission when using voice dictation for the first time.
8. Focus any text field in another app, press `Option+Space`, enter text, press `Enter` to transform, then press `Enter` again to insert.
9. For voice dictation, focus any text field in another app, tap Right Option, speak a short phrase, then tap Right Option again to transcribe, clean up, and insert.

## Keyboard Flow

- `Option+Space`: open the writing popover.
- `Right Option`: start or stop voice dictation by default. This can be changed or disabled in Settings.
- `Enter`: transform the source text, or insert the generated result when a result is already shown.
- `Command+Enter`: insert the original text without calling the model.
- `Command+Up` / `Command+Down`: cycle through visible prompt modes.
- `Escape`: clear the result or close the popover.
- `Command+,`: open Settings while Inklet is active.

Prompt modes also have default shortcuts such as `Command+1` through `Command+6` in the mode list.
The first visible prompt mode in Settings is selected when the popover opens.

## Repository Layout

```text
Sources/InkletApp/       macOS app, popover UI, settings UI, menu bar coordination
Sources/InkletCore/      core config, providers, prompts, hotkeys, insertion, state machine
Tests/InkletCoreTests/   unit tests for core behavior
docs/                           manual QA and planning documents
```

## Development Notes

- Keep provider behavior covered by focused unit tests.
- Use [docs/manual-test-checklist.md](docs/manual-test-checklist.md) before shipping user-facing app changes.
- Treat the clipboard and Accessibility flows carefully; they are central to the app experience.
- The project is still MVP-stage, so README details should track the code rather than future plans.

## Privacy

- Inklet uses your configured provider API key to call the selected LLM provider.
- Voice dictation sends temporary audio to the configured speech transcription provider.
- API keys are stored locally on your Mac.
- Speech API keys are stored locally on your Mac.
- Inklet uses Accessibility permission to return focus to the previous app and paste text.
- Inklet uses Microphone permission only while recording voice dictation.
- Inklet temporarily uses the clipboard for insertion and then restores the previous clipboard contents.
- Do not send private text or audio to a provider unless you trust that provider's data handling policies.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Security

See [SECURITY.md](SECURITY.md) for vulnerability reporting and sensitive data guidance.

## License

Inklet is released under the [MIT License](LICENSE).
