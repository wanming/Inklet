# Selection Translate Custom Prompt Design

## Goal

Allow users to customize the Selection Actions Translate prompt while keeping the existing Translate button, target-language setting, translation result UI, and Pronounce behavior intact.

## Approved Approach

Store a dedicated Selection Translate prompt in `SelectionActionsConfig`.

This keeps selection translation independent from the main popover Prompt Modes, avoids adding a second prompt-management system, and preserves existing user settings. Existing configs decode with the current built-in translation prompt as the default.

## User Experience

Settings adds a multiline prompt editor in the Selection Actions section below Translation Language. The row label is concise, such as `Translate Prompt`, with localized help text that explains the prompt controls the selected-text Translate action.

The editor uses the existing restrained settings style:

- Compact multiline text field with stable height.
- A small `Restore Default` button beside or below the editor.
- Autosave continues to apply changes through the existing settings model.

The Selection Actions popover does not add new controls. It still shows the compact first menu with Translate and Pronounce. Translate still replaces its icon with loading feedback while work is in flight, then shows the translated text or the existing translation error state.

## Prompt Behavior

The default prompt remains equivalent to the current hardcoded prompt:

```text
Translate the user's selected text into {targetLanguage}.
Preserve the original meaning, names, numbers, formatting, and tone.
Do not add explanations, alternatives, quotes, markdown, or commentary.
Return only the translated text.
```

`{targetLanguage}` is the only supported placeholder in this change. It resolves from the existing Translation Language setting, including `Follow interface language`.

Selected text is not interpolated into the system prompt. It remains the user input passed to the existing transformation service.

If the saved prompt is empty or whitespace-only, translation falls back to the default prompt. This avoids blocking autosave or leaving Translate unusable because of an accidental blank editor.

## Architecture

`SelectionActionsConfig` gains a `translationPrompt` string with:

- A public default prompt constant.
- A helper that returns the effective prompt for a resolved target language.
- Codable migration that fills the default for older saved configs.

`SelectionTranslationService` changes from constructing a fixed internal prompt from only the target language to accepting an effective system prompt. It still wraps `TransformationService` and still returns only the provider output text.

`AppCoordinator.translateCurrentSelection()` loads the config, resolves the target language as it does today, asks the config for the effective translate prompt, and passes that prompt to `SelectionTranslationService`.

`SettingsView` adds the editor and restore button to `selectionActionsPanel`. The restore button writes the default prompt back into config and saves through the existing autosave path.

## Localization

All new user-facing strings are added for every language currently supported by `InkletLocalization.swift`:

- Settings row label for Translate Prompt.
- Help text describing the Selection Translate prompt.
- Restore Default button label.
- Placeholder or prompt editor accessibility text if the UI needs one.

Documentation updates cover English and Simplified Chinese README files because this changes a user-facing feature.

## Privacy

The privacy model does not change. Selection Translate already sends selected text to the configured LLM provider. The custom prompt is stored locally in the app config and is sent with translation requests, so documentation should mention that customized Translate instructions are part of the translation request.

## Error Handling

Existing runtime states remain unchanged:

- Loading feedback stays on the Translate button/menu state.
- Successful responses show translated text.
- Translation failures show the localized translation failure state with Retry.
- Cancellation closes the panel and cancels in-flight work.

Blank prompt handling is non-disruptive: use the default prompt at request time.

## Testing

Add focused tests for:

- Default `SelectionActionsConfig` includes the default translation prompt.
- Old saved configs decode with the default translation prompt.
- Config round-trips preserve a customized translation prompt.
- Effective prompt replaces `{targetLanguage}` and falls back to the default when blank.
- `SelectionTranslationService` uses the passed system prompt when creating its hidden prompt mode.

Run `swift test`, `git diff --check`, and `git status` before finishing implementation.
