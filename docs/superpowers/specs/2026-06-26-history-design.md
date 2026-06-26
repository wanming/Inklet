# History Viewer Design

## Summary

Inklet will keep a local history of every successful write, voice, and selection transformation. Each record stores the original text, the resulting text, the source workflow, relevant mode or language metadata, and a creation timestamp. The history is visible from Settings in a new History section.

## Goals

- Save all successful records from write, voice, and selection workflows.
- Preserve both the input text and final output text for later review.
- Make history review available in the existing Settings window with restrained macOS settings styling.
- Keep the data local to the Mac and document the privacy impact.
- Provide focused tests for storage behavior and workflow capture points.

## Non-Goals

- No cloud sync.
- No search, export, or retention limit in the first version.
- No history records for failed, cancelled, empty, or in-progress operations.
- No audio data storage for voice input.

## Assumptions

- "保存所有成功记录" means there is no fixed count limit or automatic pruning.
- Local plaintext storage is acceptable when documented clearly in README and privacy text.
- Manual clearing is required because every successful record is otherwise retained.

## Architecture

Add a small `InkletCore` history model and store:

- `HistoryItem`: codable, equatable, identifiable value with `id`, `createdAt`, `source`, `inputText`, `outputText`, optional `modeName`, optional `targetLanguageName`, optional `model`, and optional `metadata`.
- `HistorySource`: `write`, `voice`, and `selection`.
- `HistoryStore` protocol: `load()`, `append(_:)`, and `clear()`.
- `JSONLHistoryStore`: append-only local store under Application Support, using one JSON object per line.

The app layer injects one store instance into existing coordinators and view models. Capture happens at successful result boundaries, close to where the app already has both source and output text.

## Data Flow

### Write Assistant

`InkletPopoverViewModel.startTransformation(source:)` already receives a successful `TransformationResult` before showing the result. After trimming succeeds and before updating the UI state, append a write history record containing:

- `inputText`: submitted source text.
- `outputText`: `result.outputText`.
- `modeName`: resolved prompt mode localized/display name.
- `model`: configured model.

### Voice Write Assistant

`VoiceInputCoordinator.stop()` already has the raw transcript and the final text before insertion. Add a `RecordHistory` closure dependency to the coordinator. On successful cleanup or raw transcription path, append a voice history record before insertion completes:

- `inputText`: transcript from speech transcription.
- `outputText`: final inserted text.
- `modeName`: cleanup mode name when auto-processing is enabled.
- `model`: configured text model when cleanup is enabled, or speech model when raw transcription is inserted.

If cleanup fails and Inklet inserts the raw transcript as fallback, this is still a successful voice record with matching input and output text and metadata noting the cleanup fallback.

### Selection Assistant

`AppCoordinator.translateCurrentSelection()` already has `currentSelectionText` and the translated string. After successful translation, append a selection history record containing:

- `inputText`: selected text.
- `outputText`: translated text.
- `targetLanguageName`: resolved translation target language.
- `model`: configured model.

Pronunciation-only selection actions do not create history records because they do not produce transformed text.

## UI

Add `SettingsSection.history` with a `clock.arrow.circlepath` icon. The detail panel uses the existing settings layout:

- A compact list of records sorted newest first.
- A segmented source filter: All, Write, Voice, Selection.
- A detail pane or expanded row showing original text and result text in selectable scrollable text areas.
- Icon-only copy controls for original and result text, each with tooltip/help and accessibility label.
- A Clear History button that asks for destructive confirmation before deleting all stored records.
- Empty state copy that explains there is no saved history yet.

The UI keeps stable button sizes. Loading is not needed for normal reads because history is local; if file reading fails, show a localized non-blocking error message and keep Settings usable.

## Localization

All new user-facing copy goes through `InkletLocalization.swift` and must be added to supported language tables. Labels include the History section title, source names, empty state, copy actions, clear action, confirmation title/message, and storage error messages.

## Privacy

History stores user text and AI-generated results as local plaintext in Application Support. Documentation must state:

- Successful write, voice, and selection results are saved locally.
- Voice history stores transcript text and final text, not audio.
- History is not uploaded to Inklet servers.
- The user can clear history from Settings.

## Error Handling

- Append failures should not block transformation, insertion, or translation success.
- Load failures in Settings show a localized message and an empty list.
- Clear failures show a localized message and leave existing records untouched.
- Malformed JSONL lines are skipped so one bad line does not hide the rest of history.

## Testing

Add focused `InkletCoreTests`:

- `JSONLHistoryStore` appends multiple records and loads them in insertion order.
- Clearing history removes all records.
- Malformed lines are skipped while valid records still load.
- `VoiceInputCoordinator` records raw transcription success, cleaned success, and cleanup fallback.

Use existing service tests and manual QA for app-layer capture points that are difficult to unit test without expanding UI seams.

## Verification

- Run targeted history store tests while developing.
- Run targeted voice coordinator tests after adding the history closure.
- Run full `swift test`.
- Run `git diff --check` and inspect `git status`.
