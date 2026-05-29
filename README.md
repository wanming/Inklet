# Inklet

[English](README.md) | [简体中文](README.zh-CN.md)

**Inklet** is a macOS writing assistant that helps you turn typed, pasted, or spoken thoughts into clear text without leaving the app you are already using.

Use the global shortcut to open a small writing popover, or tap the voice shortcut to dictate a short phrase. Inklet can rewrite, summarize, clean up speech transcription, and insert the result back into the text field you were using.

## Demo

Watch the demo video: [Inklet on YouTube](https://www.youtube.com/watch?v=F5wmFruo0a4).

## Install

Download the latest signed and notarized DMG from GitHub Releases, or use the install script below. The script downloads the latest DMG, verifies its checksum, and copies Inklet to `/Applications`.

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

## First-Time Setup

1. Open Inklet from your Applications folder, or start it from source with `swift run Inklet`.
2. Click the Inklet menu bar icon and open Settings.
3. Choose an LLM provider and enter its API key.
4. Confirm the model and prompt modes you want to use.
5. Optional: configure Voice settings with a speech API key, speech preset, voice shortcut, and cleanup mode.
6. Grant Accessibility permission when macOS asks. Inklet needs this to return focus to the previous app and paste the result.
7. Grant Input Monitoring permission if you use the voice shortcut while another app is active.
8. Grant Microphone permission the first time you use voice dictation.

## Everyday Use

Text workflow:

1. Focus any text field in another app.
2. Press `Option+Space`.
3. Type or paste rough text.
4. Press `Enter` to transform it.
5. Press `Enter` again to insert the result.

Voice workflow:

1. Focus any text field in another app.
2. Tap Right Option once to start recording.
3. Speak a short phrase.
4. Tap Right Option again to stop recording.
5. Inklet transcribes the audio, optionally cleans up the transcript with the selected prompt mode, and inserts the final text.

The default voice shortcut is Right Option. You can change it to Right Command, Left Option, Left Command, or Disabled in Settings.

## What It Does

- Opens from a global macOS hotkey. The default is `Option+Space`.
- Starts short voice dictation from a single modifier-key tap. The default voice shortcut is Right Option.
- Transforms text with built-in prompt modes:
  - To Simple and Correct English
  - To Chinese Summary
  - Voice Cleanup
- Inserts generated text back into the previously focused app.
- Restores your clipboard after insertion.
- Lets you edit prompt modes, model, timeout, temperature, hotkey, voice shortcut, speech preset, speech endpoint, and speech model.
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
- Input Monitoring permission for detecting the voice shortcut while another app is active.
- Microphone permission for voice dictation.
- An API key for at least one configured LLM provider.
- A speech transcription API key for voice dictation.

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
