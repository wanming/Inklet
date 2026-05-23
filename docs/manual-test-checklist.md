# Manual Test Checklist

## Preparation

- Launch Inklet from Xcode, `swift run Inklet`, or the installed app bundle.
- Configure an LLM provider and API key in Settings.
- Grant Accessibility permission in macOS System Settings.
- Confirm the default global hotkey is `Option+Space`, unless you intentionally changed it.

## Core Flow

- TextEdit: focus a text field, press `Option+Space`, enter text, press `Enter` to transform, then press `Enter` again to insert the result.
- TextEdit: enter a rough English sentence, improve it, then insert the result.
- Notes: repeat the transform and insert flow.
- Safari or Chrome: repeat the flow in a web text field.
- Selected text: select text in another app, open Inklet, and confirm the selected text appears in the source editor.
- `Command+Enter`: insert the original source text without calling the model.
- `Command+Up` / `Command+Down`: cycle through visible prompt modes.
- `Escape`: close the popover without inserting text.
- Missing API key: show an inline error while preserving the source text.
- Network or provider failure: show an inline error while preserving the source text.
- Paste failure: keep the generated result visible so the user can copy or retry.
- Clipboard restoration: after insertion, confirm the previous clipboard contents are restored.

## Settings

- `Command+,`: open Settings while Inklet is active.
- General: change hotkey, timeout, temperature, language, and appearance.
- Providers: configure one provider, API key, model, and custom OpenAI-compatible endpoint when needed.
- Prompt Modes: add, edit, hide, delete with confirmation, and reorder prompt modes.
- Permissions: verify Accessibility status and the button that opens System Settings.
- Save behavior: confirm changes persist after quitting and reopening Inklet.

## Compatibility Smoke Tests

- Slack or Discord.
- Notion.
- VS Code or Cursor.
- Terminal or iTerm. Record behavior, but do not treat terminal insertion issues as release blockers for the MVP.
