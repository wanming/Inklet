# Selection Actions Design

## Goal

Add Selection Actions to Inklet. When a user selects text in another macOS app and pauses briefly, Inklet shows a small floating menu near the mouse with actions for translation and AI pronunciation.

The first version prioritizes a calm macOS experience, clear privacy boundaries, and predictable behavior. It uses Accessibility to read selected text and intentionally does not use a clipboard fallback.

## User Experience

When the user selects text in another app, Inklet waits about 600 ms. If the selection is stable, readable, non-empty, and within the supported length limit, Inklet shows a small floating menu near the mouse position.

The menu contains two actions:

- Translate
- Pronounce

Selecting Translate keeps the floating UI in place, switches to a loading state, then shows the translated text in the same compact panel.

Selecting Pronounce sends the original selected text to OpenAI text-to-speech and plays the returned audio. The first version pronounces only the original text, not the translated text.

The floating UI closes when the user presses Escape, clicks elsewhere, scrolls, continues typing, changes the frontmost app, opens the main Inklet popover, or clears the selection.

If Inklet cannot read selected text from a particular app, it shows a light one-time notice for that app. Later failures in the same app are silent.

Very long selections are ignored silently in the first version to avoid accidental cost, latency, and disruptive UI.

## Architecture

Selection Actions is a separate pipeline beside the existing main Inklet popover. It reuses existing configuration, provider, permission, and theme patterns where practical.

### SelectionActionMonitor

`SelectionActionMonitor` installs global event monitors and emits semantic events. It does not read text or show UI.

It emits candidate selection events for:

- Mouse-up after drag selection
- Mouse-up after double-click or triple-click selection
- Key-up after keyboard selection gestures such as Shift plus arrow keys

It emits cancellation or dismissal events for:

- Ordinary typing
- Scrolling
- Clicking elsewhere
- Frontmost app changes
- Opening Inklet's main popover

### SelectedTextReader

`SelectedTextReader` reads selected text through macOS Accessibility only.

It first checks Accessibility trust. If trusted, it reads the focused UI element's selected text using the appropriate Accessibility selected-text attribute. It may fall back to the focused window or app only to locate the focused element; it must not use the pasteboard.

It returns structured outcomes:

- Success with selected text
- Permission denied
- Empty selection
- Unsupported element or app
- Missing focused element
- Unexpected Accessibility error

Returned text is trimmed for emptiness checks while preserving meaningful internal line breaks.

### SelectionActionCoordinator

`SelectionActionCoordinator` owns the feature state machine.

Responsibilities:

- Respect the Selection Actions enabled setting
- Ignore Inklet itself as the source app
- Debounce candidate events for about 600 ms
- Cancel pending reads when dismissal events arrive
- Ask `SelectedTextReader` for selected text
- Reject empty, repeated, or too-long text
- Track apps that have already shown an unsupported-selection notice
- Show and hide the floating action panel
- Start translation and pronunciation tasks
- Cancel in-flight work when the panel closes

Repeated selection of the same text should not reopen the panel unless the previous session was dismissed and the user creates a fresh candidate selection event.

### SelectionActionWindowController

`SelectionActionWindowController` displays the floating UI with `NSPanel` and SwiftUI.

The first version uses the mouse-up location for positioning. It does not attempt to compute a precise selected-text rectangle because cross-app Accessibility geometry support is unreliable.

The panel has two primary states:

- Compact menu: Translate and Pronounce
- Translation result: loading, translated text, error state, retry, and copy translated text

The UI should match Inklet's existing restrained macOS style: compact spacing, shared theme colors, consistent typography, no decorative effects, and no oversized cards.

### SelectionTranslationService

`SelectionTranslationService` wraps the existing `TransformationService`.

It uses the currently configured LLM provider, model, temperature, timeout, and API key. It supplies an internal translation prompt that asks the provider to translate the selected text into the configured target language without extra commentary.

Translation failures are shown in the floating panel with a short localized message and a retry action.

### OpenAITTSProvider And SpeechPlaybackService

AI pronunciation uses OpenAI text-to-speech in the first version.

`OpenAITTSProvider` sends the original selected text to OpenAI TTS using the stored OpenAI API key. It returns playable audio data and must never include the API key in surfaced errors.

`SpeechPlaybackService` plays the returned audio and stops playback when the panel closes, the user starts another pronunciation, or the app receives a cancellation event.

If no OpenAI API key is configured, Pronounce shows a localized message that points the user to Settings.

## Settings

Add a `Selection Actions` section to Settings.

Settings:

- Enabled: default on. When off, Inklet does not install the selection monitors and does not read selected text.
- Translation Language: default `Follow interface language`.
- AI Pronunciation: read-only explanatory row for the first version, stating that pronunciation uses OpenAI TTS and the OpenAI API key.

Translation Language options:

- Follow interface language
- English
- Simplified Chinese
- Traditional Chinese
- Japanese
- Korean
- Spanish
- French
- German
- Portuguese
- Italian

The Chinese feature name is `选区动作`.

## Privacy

Selection Actions touches sensitive surfaces and should be documented clearly.

Privacy behavior:

- Inklet reads selected text only after detecting that the user appears to have completed a text selection.
- Inklet reads selected text through Accessibility only.
- Inklet does not use the clipboard as a fallback in the first version.
- Inklet does not save selected text.
- Translation sends selected text to the currently configured LLM provider.
- AI pronunciation sends selected text to OpenAI TTS.
- Some apps may not expose selected text through Accessibility; in those apps the menu may not appear.

Update these documents:

- `README.md`
- `README.zh-CN.md`
- `docs/privacy-policy.md`

## Localization

All new user-facing strings must be added to `InkletLocalization.swift` for every supported interface language.

Required strings include:

- Selection Actions
- Enable Selection Actions
- Translation Language
- Follow interface language
- Translate
- Pronounce
- Copy translation
- Retry
- Current app does not support reading selected text
- Selected text is unavailable
- OpenAI API key required for AI pronunciation
- Translation failed
- Pronunciation failed

## Error Handling

Permission denied:

- Do not show the automatic action menu.
- Surface permission state in Settings using existing Accessibility permission patterns.

Unsupported app or element:

- Show one light notice per source app.
- Keep later failures silent.

Empty selection:

- Do nothing.

Too-long selection:

- Do nothing in the first version.

Translation failure:

- Keep the panel open.
- Show a short error and Retry.

Pronunciation failure:

- Keep the compact menu visible.
- Show a short inline error.

Cancellation:

- Close the panel and cancel in-flight translation, TTS, and playback.

## Testing

Add focused unit tests where practical.

`SelectedTextReaderTests`:

- Permission denied returns a permission outcome.
- Empty selected text returns empty.
- Unsupported Accessibility attribute returns unsupported.
- Successful reads trim for emptiness while preserving internal line breaks.

`SelectionActionCoordinatorTests`:

- Candidate events debounce before reading.
- Typing, scrolling, click-away, and app switching cancel pending reads.
- Repeated text does not repeatedly reopen the panel.
- Unsupported read notices are shown only once per app.
- Disabled setting prevents reads and panel display.

`TranslationLanguageTests`:

- Default value is Follow interface language.
- Language display names and prompt target names are correct.
- Interface-language fallback resolves correctly.

`OpenAITTSProviderTests`:

- Request URL, headers, and payload are correct.
- Non-2xx responses surface safe errors.
- Empty audio responses are rejected.
- API keys are not included in errors.

Manual verification:

- Drag selection in TextEdit, Safari, Chrome, Notes, and Mail.
- Double-click word selection.
- Triple-click paragraph selection.
- Shift plus arrow-key selection.
- English and Chinese selected text.
- English and Chinese interface text fit without overlap.
- No Accessibility permission.
- No OpenAI API key.
- Translation failure.
- TTS failure.
- Closing from Escape, click-away, scrolling, typing, app switching, and opening the main Inklet popover.

Final checks:

- `swift test`
- `git diff --check`
- `git status`

## Known Trade-Offs

The first version does not use a clipboard fallback. This protects the user's clipboard and keeps privacy behavior simple, but it reduces coverage. Some apps will not expose selected text through Accessibility, and Selection Actions will not appear there.

The first version positions the menu near the mouse rather than the exact selected-text rectangle. This is more reliable across apps and avoids depending on inconsistent Accessibility geometry support.

AI pronunciation only supports OpenAI TTS in the first version. This keeps the feature focused and avoids adding a new provider abstraction before there is more demand.
