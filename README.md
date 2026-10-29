# Inklet

[English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [Español](README.es.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Português](README.pt-BR.md) | [Italiano](README.it.md)

Homepage: [getinklet.app](https://getinklet.app)

**Turn rough thoughts into clear text.**

**Inklet** is a macOS writing assistant that helps you turn typed, pasted, or spoken thoughts into clear text without leaving the app you are already using.

Use the global shortcut to open the writing popover, then type, paste, or dictate into the same editable source draft. Realtime dictation stays inside Writing Assistant so you can review the transcript before deciding whether to transform or insert it. On Apple silicon, new installs recognize speech on your Mac, so your voice never leaves it.

## Install

GitHub Releases is Inklet's only supported distribution channel. Download the latest signed and notarized DMG from [GitHub Releases](https://github.com/wanming/Inklet/releases), open it, and copy Inklet to `/Applications`.

Alternatively, use the install script below. The install script downloads the latest GitHub Releases DMG and checksum, verifies the DMG structure, checksum, Gatekeeper acceptance, bundle identifier, Hardened Runtime, effective entitlements, and app signature, and then copies Inklet to `/Applications`.

```bash
curl -fsSL https://raw.githubusercontent.com/wanming/Inklet/main/scripts/install.sh | bash
```

## Updates

Inklet uses GitHub Releases as its only update source. Production builds check GitHub for public metadata for the latest stable release about once every 24 hours. An update is announced only after that release has an uploaded `Inklet.dmg`; **View on GitHub** opens that exact release page. **Install and Relaunch** in the notice downloads and installs that release right away. With **Install updates automatically** on in Settings › General, which is the default, Inklet does this by itself: it downloads `Inklet.dmg` in the background, makes sure the disk image passes Gatekeeper and the app inside is signed by the same developer as the one running, then replaces the app and restarts once you aren't using Inklet. If you quit Inklet first, the update is put in place without reopening it. When Inklet can't replace itself (for example without write access to its folder), or a download or check fails, you get the notice instead, and an install that didn't take is never retried on its own. The notice shows that release's notes in your interface language, or in English when they aren't translated.

Use **Check for Updates…** from the app menu to check manually in either the production app or Inklet Local. Inklet Local never schedules automatic checks or installs updates. Automatic check failures are silent, while a manual check offers **Retry**. If writing, dictation, Selection Actions, migration, a modal, or an open menu makes Inklet busy, an automatic update notice or install waits until the app is idle.

To try new features early, turn on **Beta updates** in Settings › General. Inklet then reads the list of recent public releases instead of only the latest stable one, so it also offers beta versions published as GitHub prereleases. A beta shows **Beta** next to its version. Turning the switch off doesn't move you back: Inklet stays on the beta until a newer stable release is out.

After you update, the first launch of the new version shows a short **What's New** window once, when Inklet is idle and without taking focus from the app you're using. It doesn't appear on a new install or while the welcome guide is open. **Changelog** in the menu bar menu lists every release, with the version you're running highlighted.

## First-Time Setup

1. Open Inklet from your Applications folder. For a source build, run `scripts/run-local-app.sh` from the repository root, then use `/Applications/Inklet Local.app`.
2. Click the Inklet menu bar icon and open Settings.
3. Grant Accessibility permission when macOS asks. Inklet uses this one generic permission to read selections, perform a configured copy fallback, return focus to the previous app, and paste confirmed results. Inklet stays in the background while System Settings is open and returns to General settings when you close it.
4. On a new install, and once after updating to this version, a welcome guide walks through the interface language (new installs follow the system language), Accessibility, the writing model, the microphone for Live Dictation, and the shortcuts for opening Inklet and dictating, then introduces the bar that appears next to selected text. To walk through it again anytime, choose **Welcome Guide** in the menu bar menu; every step starts from your current settings. On Apple silicon it suggests **Built-in** with the recommended model and downloads it in the background when you keep it; the writing popover shows the progress and works offline once it finishes. To use a cloud provider instead, choose it in Settings › AI Models and enter its API key. With OpenAI, the default on Intel Macs, one key covers writing, realtime dictation, selection translation, and pronunciation. With any other provider, writing and selection translation use that provider, while dictation and pronunciation, when you choose OpenAI for them, still need an OpenAI API key in the API keys card on the same page. To run writing and translation on your Mac without any key, choose **Built-in** and download a model, or choose **Ollama** or **LM Studio** if you already run one of them (see [Local Models](#local-models)).
5. Configure Writing Assistant with the model, writing shortcut, generation settings, and prompt modes you want to use. Live Dictation has its own Settings page: turn it on or off, choose **On this Mac** or **OpenAI** for speech recognition, and choose the hold shortcut and microphone. On Apple silicon, new installs use **On this Mac**, and the welcome guide downloads its speech model when you turn on dictation there; existing setups keep OpenAI until you switch. With OpenAI, Advanced Dictation exposes only the recovery model; the recovery endpoint is not editable. The realtime model is fixed by Inklet.
6. Optional: configure Selection Assistant with a translation language, Force Selection mode, AI pronunciation voice, and pronunciation speed, then preview the voice in Settings.
7. Grant Microphone permission on the first valid Dictation hold. Opening Inklet, visiting Settings, or pressing the Dictation shortcut outside the active source editor does not request it.

## Everyday Use

Text workflow:

1. Focus any text field in another app.
2. Press `Option+Space`.
3. Fuzzy-search for a prompt mode (for example, `ts` can match `To Simple and Correct English`), use `Up` / `Down` to highlight it, then press `Tab` or `Enter` to commit the mode.
4. Type or paste rough text.
5. Press `Enter` to transform it. The result appears as it is generated; press `Escape` to stop.
6. Press `Enter` again to insert the result, or press `Shift+Command+C` (or click the copy button on the result) to copy it instead.

Dictation workflow:

1. **Open Writing Assistant** with `Option+Space`.
2. **Confirm a Prompt Mode**. Dictation is unavailable in the mode picker and result editor.
3. **Put the caret in the source draft, or select text to replace.** Dictation inserts at the caret or replaces the selection.
4. **Hold the configured Dictation shortcut** (Right Option by default) and speak normally while the draft updates in place. A short press does nothing. If the realtime connection fails, keep holding and speaking while Inklet keeps one temporary recovery recording.
5. **Release to finalize** the transcript. With **On this Mac**, recovery transcribes the recording on your Mac. With OpenAI, if recovery is needed, Inklet sends one request to `https://api.openai.com/v1/audio/transcriptions` with the same existing OpenAI API key used by realtime dictation. The temporary recording remains local until the fallback request actually begins, is uploaded at most once, and is deleted when the session ends.
6. Review and edit the dictated draft. Dictation by itself does not run the Prompt Mode or insert text into another app.
7. **Press Return only when ready** to run the confirmed Prompt Mode; press Return again only when you want to insert the result.

The Dictation shortcut is source-local and hold-only. You can change its modifier key to Right Command, Left Option, or Left Command, or turn dictation off entirely, in Settings → Live Dictation. Escape, focus loss, popover closure, or opening another source session cancels dictation and restores the original draft.

## What It Does

- Opens from a global macOS hotkey. The default is `Option+Space`.
- Streams realtime dictation into the active Writing Assistant source editor while a modifier-key shortcut is held. The default is Right Option.
- Shows Selection Actions after you select text in another Mac app and pause briefly, with EasyDict-style selection reading, quick translation, a customizable Translate prompt, AI pronunciation, resizable translation results that remember their last size, and 7-day local caching for repeated translations.
- Drag the selection bar or its result anywhere when it covers something; clicks still work, and the next selection places it near the text again.
- Ignores selected text longer than 1,500 characters to avoid accidental long-page triggers.
- Plays selected text directly, and can play both the original text and translated text from the translation result.
- Lets you choose which buttons the selection menu shows and in what order, under Settings › Selection Assistant › Menu Buttons. Translate, Pronounce, and any prompt mode can be a button; up to four show at once and the rest go under **More**. A prompt mode button runs that mode on the selected text and shows the result in the panel with copy and playback controls.
- Transforms text with built-in prompt modes:
  - To Simple and Correct English (into your Writing Language, set in Settings › General; English by default)
  - Summarize (into your Translation Language, which follows the interface language by default)
  - To Chinese, To Japanese, and so on (translates into your Translation Language; for a single word it shows the meaning, pronunciation, and example sentences)
  - Voice Cleanup
  - Built-in mode names stay in English in every interface language, so the same letters find them; they name your languages until you rename them.
- Streams the result into the popover as it is generated, then inserts it back into the previously focused app or copies it with the result's copy button.
- Uses one application-agnostic, Accessibility-first selection path. Automatic Selection Actions first ask macOS Accessibility for the selection, then use the configured temporary clipboard fallback only when Force Selection permits it. Each read stays bound to the captured source process and cancels if that process exits or loses focus.
- Keeps simulated `Command+C` off by default. Menu Copy remains the safe Force Selection fallback; you can explicitly enable simulated copy as an advanced fallback for apps without a usable Copy menu, but it may interfere with games, remote desktops, or virtual machines.
- Serializes temporary clipboard reads and restores the prior snapshot only while the same read still owns the observed copy result; newer clipboard contents win. The double-copy trigger is passive: it consumes the copy the user already made without issuing another synthetic copy or restoring older clipboard data. Right-click remains native and never starts a selection read.
- Does not use browser-specific selection code and does not request browser Automation. Chrome, Safari, Edge, and native apps use the same generic path.
- Lets you edit prompt modes, provider, model, custom OpenAI-compatible endpoint, timeout, writing shortcut, Dictation hold shortcut, microphone, recovery model, selection translation language, selection Translate prompt, selection menu buttons, Force Selection mode, simulated-copy permission, AI pronunciation voice, and AI pronunciation speed.
- Shows local History for successful Write and Selection results, with consecutive duplicate entries collapsed, selectable source/result text, a result copy control, and a clear-all action. Existing legacy Voice entries remain readable.
- Writes and translates with OpenAI, Anthropic, Google Gemini, DeepSeek, Alibaba Qwen, Moonshot Kimi, Zhipu GLM, MiniMax, SiliconFlow, Volcengine Ark, Tencent Hunyuan, Baichuan, 01.AI Yi, xAI, Groq, Mistral, OpenRouter, Perplexity, Together AI, Cerebras, or any custom OpenAI-compatible endpoint, such as a local model server. Pronunciation uses the engine chosen under Text to speech in AI Models: the macOS system voice (the default on new installs, offline and free) or OpenAI. Dictation uses the speech recognition engine chosen in Live Dictation.
- Runs writing and translation on your Mac with the built-in engine (Qwen3.5 4B or Gemma 4 E4B, downloaded once from Hugging Face), or with a local Ollama or LM Studio server. No API key is needed, and text stays on your Mac.
- Provides English, Simplified Chinese, Traditional Chinese, Japanese, Korean, Spanish, French, German, Portuguese, and Italian app UI localization.
- Adapts compact selection menus and constrained settings/writing controls to translated labels; language changes refresh open UI while preserving writing content.

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
- Accessibility permission for Inklet, required for generic selection reading, configured copy fallback, returning focus to the previous app, and pasting the generated result.
- Microphone permission for realtime dictation while the shortcut is held.
- An API key for OpenAI or another supported provider, or a local model. Pronunciation and dictation need an OpenAI API key only when set to OpenAI.

## Local Models

Inklet can write and translate with a model that runs on your Mac, so your text never leaves it and no API key is needed.

- **Built-in** (Apple silicon only, and the default on new installs): choose **Built-in** as the provider, pick a model, and click **Download**. Gemma 4 E4B (about 4.6 GB) is the default for Macs with 16 GB of memory or more; Qwen3.5 4B (about 2.7 GB) is recommended for 8 GB. On a new install the welcome guide downloads it, and while a model is downloading the writing popover shows its progress, with a **Download** button if the model isn't there yet. Downloads resume after an interruption and are checked against a pinned SHA-256 before use. When you open the writing popover with Built-in selected, Inklet starts its bundled llama.cpp server on the loopback address only and loads the model, so it is usually ready by the time you submit. On Macs with 24 GB of memory or more the model stays loaded and is released only when macOS runs short of memory; on smaller Macs the server releases it after five idle minutes.
- **Dictation on this Mac** (Apple silicon only, and the default on new installs): Live Dictation recognizes speech with Qwen3-ASR 0.6B (about 1 GB), which understands 30 languages and Chinese mixed with English. It runs on the same bundled llama.cpp engine in a separate server, re-transcribes what you are saying about every 0.6 seconds while you speak, and fixes each sentence at a pause. On Macs with 16 GB of memory or more the speech model stays loaded while dictation is on; on smaller Macs it loads when the writing popover opens and is released after five idle minutes. Turning dictation off, or choosing OpenAI, stops it. When Inklet or macOS uses Traditional Chinese, Chinese dictation is written in Traditional characters.
- **Ollama**: install [Ollama](https://ollama.com), run `ollama pull qwen3.5:4b`, then choose **Ollama**. Inklet lists the models Ollama has downloaded.
- **LM Studio**: start LM Studio's local server on port 1234, load a model, then choose **LM Studio**.

Local providers get at least 120 seconds per request so the first request can load the model. Inklet asks local servers to skip "thinking" so small reasoning models answer directly. Source builds compile the built-in engine with `scripts/build-llama-server.sh`, which needs `cmake`; if it is missing, the app still runs and the Built-in option explains that the engine is not included.

## Build And Run

Before each app bundle build, increase both `INKLET_VERSION` and `INKLET_BUILD_NUMBER` in the root `VERSION` file. Normally increment the patch version; use minor or major increments for larger changes. The build number must remain a positive integer greater than every previously used build number, including across marketing versions. Check the latest `main`, Git tags, all GitHub releases (including drafts), and active worktrees before choosing it. Inklet uses this build number alone to decide whether an update is newer.

Run remote GitHub DMG builds only from `main`, after merging and pushing the intended changes and updated `VERSION`. Dispatch `build-dmg.yml` with `--ref main`.

For an official release, verify the successful build and final assets, replace the placeholder description with Chinese and English changes since the previous published stable release, and publish as the latest stable release. An already verified draft can be published without rebuilding or changing its version.

The DMG workflow checks for reused or lower build numbers before building; it does not increment either value automatically. See [release version checks](scripts/README.md#release-version-checks) for manual validation. Changing a packaged app's version requires rebuilding, signing, notarizing, and regenerating checksums; changing only the release title or filename does not update the app.

From the repository root:

```bash
swift build
scripts/run-local-app.sh
```

Use `scripts/run-local-app.sh` for routine manual app testing from any worktree. It installs and opens the stable `/Applications/Inklet Local.app` identity so macOS Accessibility and Keychain trust can be reused across rebuilds.

Run tests:

```bash
swift test
```

If tests fail because `XCTest` is unavailable, install the full Xcode app instead of using only Command Line Tools.

Check all UI languages with `scripts/check-localization.sh`. Add `--snapshots` to generate a local HTML gallery of synthetic native UI fixtures under `.build/localization-audit/`; the command prints its path. Pull requests and pushes to `main` run the full unit test suite and the localization checks automatically. See [localization coverage and remaining manual checks](docs/localization-audit.md).

## Keyboard Flow

- `Option+Space`: open the writing popover.
- `Right Option`: hold for Dictation while the Writing Assistant source editor is active. Change the modifier or turn dictation off in Settings → Live Dictation; a short press remains inert.
- `Up` / `Down` in the mode launcher: move the highlight through fuzzy-ranked prompt modes.
- `Tab`, `Return`, or keypad `Enter` in the mode launcher: commit the highlighted prompt mode and focus the source editor. Return remains available to confirm text or an IME candidate during active composition; Return with Command, Shift, Option, or Control does not commit a mode.
- `Enter` in the editor: transform the source text, insert a result generated by the current mode, or regenerate a stale result from a previous mode with the newly committed mode.
- `Command+Enter`: insert the original text without calling the model.
- `Shift+Command+C`: copy the visible result without closing the popover.
- `Command+Up` / `Command+Down`: cycle through visible prompt modes.
- Hold `Command` on its own: show every shortcut in the action bar. The bar otherwise shows only the dictation hint and the main button; all shortcuts work either way.
- `Escape`: move back one level per press, from the result to the source editor, then to the mode launcher, then close the popover. While transforming, it stops generation, discards the partial result, and stays in the editor.
- `Command+,`: open Settings while Inklet is active.

Search is case- and diacritic-insensitive and supports ordered-character matching. Exact and prefix matches receive the strongest boosts; consecutive, word-start, earlier, and tighter matches generally rank higher.

When the mode launcher opens, the last committed prompt mode is highlighted if it is still visible. A single click highlights a mode; a double-click commits it. Returning to the launcher keeps the current draft and result.

## Repository Layout

```text
Sources/InkletApp/       macOS app, popover UI, settings UI, menu bar coordination
Sources/InkletCore/      core config, providers, prompts, hotkeys, insertion, state machine
Tests/InkletCoreTests/   unit tests for core behavior
docs/                           manual QA and privacy policy
```

## Development Notes

- Keep provider behavior covered by focused unit tests.
- Use [docs/manual-test-checklist.md](docs/manual-test-checklist.md) before shipping user-facing app changes.
- Use `scripts/run-local-app.sh` instead of a bare SwiftPM executable or `open dist/...` for routine app hand-testing, so local Accessibility and Keychain approvals stay attached to one stable app identity.
- Treat the clipboard and Accessibility flows carefully; they are central to the app experience.
- The project is still MVP-stage, so README details should track the code rather than future plans.

## Local Storage And Upgrades

Production and local QA builds use bundle-qualified storage and do not share settings, History, translation cache, diagnostics, or Keychain credentials:

- Production Application Support: `~/Library/Application Support/com.tomwan.inklet/`
- Local Application Support: `~/Library/Application Support/com.tomwan.inklet.local/`
- Production preferences: `~/Library/Preferences/com.tomwan.inklet.plist`
- Local preferences: `~/Library/Preferences/com.tomwan.inklet.local.plist`
- Provider API keys: `api-keys.json` in the matching Application Support folder, readable only by your user account and excluded from Time Machine backups
- Keychain services used by earlier versions: `Inklet.ProviderAPIKey` (production) and `Inklet.Local.ProviderAPIKey` (local)

Earlier versions kept API keys in the Keychain. The first time a key is needed, Inklet copies it from the Keychain into `api-keys.json` and leaves the Keychain item in place, so going back to an earlier version still finds it. Changing or clearing a key in Settings removes the Keychain copy.

On first launch after upgrading from the legacy sandboxed build, Inklet automatically copies recognized legacy preferences, provider API keys into the matching Keychain service, and History into the current bundle's storage. It does not delete or modify the legacy source, so the old data remains available for rollback or recovery. The disposable translation cache is not migrated.

If macOS blocks automatic access to the matching legacy container, Settings keeps an **Import Old Data…** action available. The assisted import validates the exact legacy `Data` folder for the running production or local bundle, reads it only while the current file-panel grant is valid, and does not save a persistent access bookmark.

## Privacy

- Inklet sends writing and selection translation requests to the provider you choose in Settings, using that provider's API key. With the macOS system voice, pronunciation reads text on your Mac; it uses OpenAI, with your OpenAI API key, only when you choose OpenAI for text to speech. Dictation uses OpenAI only when you choose it as the speech recognition engine.
- With **On this Mac** speech recognition, dictation audio and its recovery recording are processed by a server on your Mac and never leave it.
- With OpenAI speech recognition, while you hold the Dictation shortcut, active microphone audio is streamed directly to OpenAI Realtime transcription. Inklet also keeps one temporary local recovery recording. It remains local until the fallback request actually begins, is uploaded at most once to `https://api.openai.com/v1/audio/transcriptions` using the same existing OpenAI API key used by realtime dictation, and is deleted on every terminal session path.
- Your API keys are stored locally on your Mac, one per provider.
- With the Built-in, Ollama, or LM Studio provider, writing and translation requests go only to a server on your Mac. Downloading a built-in model sends one request to Hugging Face for the chosen file; it does not include your text, audio, API keys, or settings.
- Inklet uses Accessibility permission for generic selection reading, configured copy fallback, returning focus to the previous app, and pasting text.
- Inklet uses Microphone permission only during a valid Dictation hold in the active Writing Assistant source editor. Finishing dictation leaves an editable draft and does not insert into another app.
- Inklet temporarily uses the clipboard for insertion and configured Force Selection fallback reads. A Force Selection read restores the previous clipboard only if Inklet's temporary copied value is still current, and does not overwrite a later external clipboard change.
- Inklet saves successful Write and Selection source/result text locally in History until you clear it in Settings, while skipping consecutive duplicate entries. An unprocessed dictated draft creates no History entry; existing legacy Voice entries remain locally readable.
- Selection Actions capture the source app and selection location, validate that source before and during the read, and use Accessibility to read its current selection. If Accessibility does not return selected text, the configured Force Selection mode can briefly invoke menu Copy and read the resulting clipboard text through the protected transaction described above. Simulated `Command+C` is off by default and runs only after an explicit advanced opt-in. You can turn Force Selection off in Settings. This path sends no browser-targeted Apple Events and does not request browser Automation. Pressing `Command+C` twice quickly after selecting text explicitly reads the copy you already made. Inklet does not save merely selected text unless a successful action is recorded in local History.
- Selection Assistant caches successful translation results locally for 7 days using hashed cache keys to speed repeated translations.
- Selection Assistant translation sends selected text and your custom Translate instructions to your selected provider when no local cached translation is available; a prompt mode button sends selected text and that mode's prompt to your selected provider; pronunciation sends selected text to OpenAI only when OpenAI is the text to speech engine.
- Inklet fetches the public model catalog from `models.dev` at most once per day. This request does not include your text, audio, API keys, or app settings.
- Do not send private text or audio to OpenAI or your selected provider unless you trust their data handling policies.

## Feedback

Choose **Send Feedback…** from the Inklet menu bar menu, or [open an issue](https://github.com/wanming/Inklet/issues/new/choose). Bug reports and feature ideas are welcome; never paste API keys or private text into an issue.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Security

See [SECURITY.md](SECURITY.md) for vulnerability reporting and sensitive data guidance.

## License

Inklet is released under the [MIT License](LICENSE).
Third-party notices are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
