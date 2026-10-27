# Manual Test Checklist

This checklist defines required manual verification; it does not claim that any item has been run.

Record the tested Inklet version, artifact checksum, macOS version, hardware architecture, and result when executing release QA.

## Preparation

- For release testing, install the exact signed artifact from the GitHub Releases DMG. Do not substitute an unsigned archive or a development build.
- For source or local testing, run `scripts/run-local-app.sh` and use `/Applications/Inklet Local.app`. Do not launch a bare SwiftPM executable, a worktree-local `dist/...` app, or an ad-hoc-signed app for routine QA.
- Confirm the local runner uses the stable `com.tomwan.inklet.local` bundle, and do not print or record the configured signing identity.
- Configure a test OpenAI API key in Settings › AI Models. Use non-production text, audio, and credentials.
- Confirm the default writing shortcut is `Option+Space` and the default Dictation hold shortcut is Right Option, unless the test intentionally changes them.
- Use `scripts/reset-rebuild-install.sh` only for intentional local first-launch or permission-reset QA; it removes the selected local state by design.

## Fresh Install And Signed Upgrade

- On each supported macOS version, perform a fresh install from the exact signed release DMG. Confirm Gatekeeper permits the first launch, onboarding appears, and no pre-existing production data is assumed.
- Prepare a populated legacy sandboxed production build with recognized preferences, provider credentials, and History. Perform a signed in-place upgrade that preserves the production bundle identifier and signing requirement.
- Confirm automatic migration copies recognized preferences, imports a missing legacy credential into the production Keychain service, and imports or merges History before normal app state is constructed.
- Confirm the disposable legacy translation cache is not migrated.
- Confirm the legacy source remains unchanged after successful, failed, and repeated migration attempts. Relaunch twice and confirm migration is idempotent: settings do not regress, History records do not duplicate, and existing destination Keychain items are not overwritten.
- Block or deny automatic legacy-container access in a controlled fixture, then confirm Settings presents the assisted import action without crashing startup.
- Exercise assisted import with the correct legacy `Data` folder. Confirm it pauses active workflows, imports only incomplete components while the current file-panel grant is valid, and relaunches if destination data changes.
- Reject a different bundle's container, a symlink, and an arbitrary lookalike folder before contents are imported. Confirm no persistent file-access bookmark is created.
- Postpone or cancel assisted import and confirm the preserved-data notice and Settings action remain available for retry.
- For a same-path signed upgrade, verify retained Accessibility trust and Keychain access rather than assuming either. Confirm the existing production API key can be read and updated after upgrade.
- Confirm data created only after the direct upgrade is not written back into the legacy container.

## Production And Local Isolation

- Run production and local builds concurrently. Change settings, add a History item, create a Selection translation cache entry, and trigger selection diagnostics in each build.
- Confirm settings, History, translation cache, diagnostics, defaults, and Keychain remain isolated in both directions.
- Confirm production uses `~/Library/Application Support/com.tomwan.inklet/`, `~/Library/Preferences/com.tomwan.inklet.plist`, `$TMPDIR/InkletSelectionActions.com.tomwan.inklet.log`, and `Inklet.ProviderAPIKey`.
- Confirm local QA uses `~/Library/Application Support/com.tomwan.inklet.local/`, `~/Library/Preferences/com.tomwan.inklet.local.plist`, `$TMPDIR/InkletSelectionActions.com.tomwan.inklet.local.log`, and `Inklet.Local.ProviderAPIKey`.
- Confirm `history.jsonl` and `selection-translation-cache.json` exist only under the matching bundle-qualified Application Support root.
- Confirm changing or clearing production data does not change local data, and vice versa.

## Permissions And Stable Local Trust

- Deny Accessibility on a fresh install. Confirm onboarding or Settings explains the missing permission, selection reading and insertion do not proceed, and Inklet does not show an empty selection panel.
- Grant Accessibility and confirm generic selection reading, configured copy fallback, focus restoration, and insertion work without any browser-specific permission setup.
- Deny Microphone on the first valid dictation hold. Confirm a clear error appears, capture does not continue, the original draft is restored, and no text is inserted.
- Restore Microphone permission and confirm only a valid hold in the active Writing source editor records audio.
- Confirm permission is not requested when opening Inklet, viewing Settings, entering the mode picker and result editor, or making a short press; Selection Actions must not prompt for Microphone access either.
- No browser Automation prompt may appear during onboarding, selection, double-copy, insertion, or migration. Confirm Inklet is absent from browser Automation grants used by the test account.
- Run `scripts/run-local-app.sh`, exercise Accessibility and Keychain access, then rebuild and reinstall the local app twice through the same script. Confirm `/Applications/Inklet Local.app` keeps the same bundle identity and reuses Accessibility trust and Keychain access without a new approval prompt.

## Core Writing Flow

- TextEdit: focus a text field, press `Option+Space`, search for a prompt mode, use `Up` / `Down` to highlight it, press `Tab` or `Return` to commit it, enter text, press `Enter` to transform, then press `Enter` again to insert the result.
- TextEdit: enter a rough English sentence, improve it, then insert the result.
- Notes: repeat the transform and insert flow.
- Safari or Chrome: repeat the flow in a web text field.
- Open Inklet with text selected in another app and confirm the selected text appears in the source editor after committing a prompt mode.
- Initial focus: each time the popover opens, confirm the mode search field is focused and the source editor is not focused yet.
- Search field layout: at the actual 600-point popover width, confirm the magnifier never overlaps the empty placeholder, caret, typed query, or Chinese IME marked text; clear a query and confirm the native clear button works without overlap.
- Fuzzy ranking: configure `To Simple and Correct English`, `To Chinese Summary`, mixed-case, diacritic-bearing, and Chinese mode names; confirm `ts` finds both built-in modes with Simple first, `tcs` ranks the Chinese mode first, and search supports case-insensitive, diacritic-insensitive, Chinese substring, and Chinese ordered-character matching.
- Arrow navigation: press `Up` / `Down` through filtered modes and confirm the highlight clamps at the first and last result instead of wrapping.
- `Tab` in the launcher: confirm it commits the highlighted mode and focuses the source editor.
- `Return` in the launcher: confirm both main Return and keypad Enter commit the highlighted mode and focus the source editor. Confirm Command-, Shift-, Option-, and Control-modified Return stay in the launcher. During Chinese IME composition, confirm Return accepts the text or candidate without entering the source editor, then a subsequent Return commits the highlighted mode.
- No matches: enter a query with no matching modes, confirm the empty state appears, and confirm `Tab`, Return, and keypad Enter do not advance to the editor.
- Back to modes: after committing a mode from a nonempty query, use the editor's back control and confirm the query clears while the source, any existing result, and the current mode highlight remain.
- Reopen persistence: commit a non-first visible mode, close and reopen the popover, and confirm that last committed mode is highlighted.
- Missing saved mode: hide the last committed mode in Settings, then delete it in a separate pass; each time, reopen the popover and confirm the first visible mode in Settings order is highlighted.
- Change mode with a result: return to the launcher, commit a different mode, and confirm the prior result remains visible with its `Generated with` mode label. Confirm generation waits for a deliberate `Enter`, then regenerates with the newly committed mode.
- Regeneration recovery: force both a provider failure and an `Escape` cancellation while regenerating with a different mode; confirm the prior result remains visible and `Enter` can retry.
- Restore Insert behavior: reselect the mode that generated the existing result and confirm the stale-result label clears and `Enter` inserts the result instead of regenerating it.
- Layered `Escape`: with a result visible, press `Escape` once to return to the source editor, once to return to the mode launcher, and once to close the popover. Confirm each press moves only one level.
- Generation cancellation: press `Escape` while transforming and confirm generation cancels, remains in the editor, and performs no additional back navigation.
- Streaming result: transform a long draft and confirm the result area appears as soon as text starts arriving, grows with the text, keeps the newest line in view once it reaches its maximum height, and shows an `esc` Stop hint in the toolbar. Confirm the final result is editable and matches the streamed text.
- Streaming cancellation: press `Escape` or click Stop while text is streaming and confirm the partial text disappears, the source draft stays, and a prior result from a different mode reappears if one was visible.
- Copy result: with a result visible, click the copy icon at the top-right of the result and confirm the clipboard contains the result, the icon shows a checkmark briefly and then returns, the popover stays open, and long first lines never run under the icon. Confirm the control has a Copy result tooltip (with `⇧⌘C`) and VoiceOver label in English and Chinese. Press `Shift+Command+C` with the source or result editor focused and confirm it copies the result with the same checkmark feedback; confirm plain `Command+C` still copies only selected text, and the shortcut does nothing when there is no result or while generating.
- Launcher capacity and copy: configure more than six visible modes with long English and Chinese names; at the actual 600-point popover width, confirm scrolling reaches every mode and text, icons, and hints do not overlap.
- Pointer interaction: confirm a single click highlights without committing, a double-click commits, and hover and pressed states are visible without changing layout.
- VoiceOver: confirm the search field and every mode have useful labels, the highlighted mode exposes its selected state, and each mode offers a named `Write` action that commits it.
- `Command+Enter`: insert the original source text without calling the provider.
- `Command+Up` / `Command+Down`: cycle through visible prompt modes.
- Missing API key: show an inline error while preserving the source text.
- Network or provider failure: show an inline error while preserving the source text.
- Paste failure: keep the generated result visible so the user can copy or retry.
- Clipboard restoration after insertion: confirm the prior clipboard contents are restored.

## Writing Dictation Matrix

- [ ] Route isolation: confirm Dictation is unavailable in the mode picker and result editor, then confirm it becomes available only after a Prompt Mode is committed and the Writing source editor is active.
- [ ] Gesture lifecycle: test a short press, a valid long hold, release, rapid repeat, and the modifier already held when entering the editor. A short press must do nothing; every valid hold must start at most one session.
- [ ] Physical latency: compare responsiveness with the prior local build; speak immediately after holding the Dictation shortcut, and confirm the beginning of the utterance is preserved.
- [ ] Editing targets: dictate at an empty caret, in the middle and end of text, and over a selection. Repeat with CJK, English, mixed-language text, emoji, and combining marks. Each committed dictation must be one-step undo and redo without disturbing older undo items.
- [ ] Interaction lock: during connecting, listening, fallback recording, finalizing, and recovery, confirm manual editing, caret movement, and selection changes are locked. Confirm the original editability, selection, and focus are restored after success, cancellation, or failure.
- [ ] Escape layers: begin with active IME composition and test marked-text Escape, then active-dictation Escape, then normal Writing Escape navigation. Dictation cancellation must restore the exact attributed draft and selection without moving an extra route level.
- [ ] Realtime outcomes: exercise realtime partial and final events, connection failure while held, fallback success, fallback failure, no speech, and late-event races. Exactly one terminal result may win and late callbacks must not change the restored or committed draft.
- [ ] Devices and permissions: verify the first valid hold permission prompt, permission denial, no input device, an unplugged selected device, and System Default. Opening the popover, choosing a mode, and short presses must not request Microphone permission.
- [ ] Lifecycle cancellation: close the popover, change focus, return to the launcher, use rapid reopen, and quit the app during every active phase. Repeat while capture permission or device startup is still pending; no session may leak into the reopened editor.
- [ ] Retention and diagnostics: verify temporary recovery-file deletion for every terminal path, no draft-only History, unchanged legacy Voice History, and no transcript or audio content, Authorization header, microphone identifier, or temporary path in logs.
- [ ] Presentation and accessibility: at the actual popover width in English and Chinese, test long localized shortcut and microphone names, stable phase icons, VoiceOver labels for the source editor and status, and phase-only announcements that do not read inline error copy twice.
- [ ] Recovery configuration: confirm Advanced Dictation exposes only the recovery model and the recovery endpoint is not editable. Force recovery and confirm exactly one request goes to `https://api.openai.com/v1/audio/transcriptions` with the same existing OpenAI API key as realtime dictation; the temporary recording remains local until that request begins and permits at most one upload.
- [ ] Configuration: clear the shared OpenAI API key and verify the localized error without insertion. Change the Dictation shortcut among Right Command, Left Option, and Left Command; confirm only a hold in the active source editor can start capture.
- [ ] Live Dictation switch: in Settings → Live Dictation, turn the switch off. Confirm the shortcut, microphone, and Advanced Dictation rows dim, the popover hides the hold hint, the About quick-start list drops the voice line, and holding the shortcut in the source editor does nothing. Turn it back on and confirm the previously chosen shortcut is restored and works. Confirm Write Assistant no longer shows any dictation settings.

## Generic Selection Matrix

Run every item below in Chrome, Safari, Edge, and a native AppKit text view. Repeat with Force Selection disabled, Menu Copy with simulated `Command+C` off, and Menu Copy with the advanced simulated-copy fallback enabled where the source application supports it.

- Left-button drag selection: the compact menu appears with Translate and Pronounce.
- double-click word selection and triple-click paragraph selection: each produces one stable selection result without immediately dismissing the panel.
- Shift-modified keyboard selection: the same generic Accessibility-first pipeline runs.
- Accessibility success: the temporary clipboard is not changed.
- Accessibility unsupported or empty with Force Selection enabled: the configured temporary copy path reads the same source app.
- Force Selection disabled: no synthetic copy occurs and no empty panel appears when Accessibility cannot read the selection.
- Leave simulated `Command+C` off, exercise a full-screen game or remote desktop, and confirm Inklet never sends a copy shortcut. Then enable the advanced fallback, confirm its warning is visible, and verify a focus change never sends `Command+C` to the newly active app.
- double-copy: press `Command+C` twice quickly and confirm Inklet passively reads the user's copy, issues no third copy, and does not restore older pasteboard data.
- right-click: the source application's native context menu remains usable and no selection read starts. With an Inklet panel already visible, right-click dismisses it without breaking the native menu.
- A protected password field or protected page that rejects copy: no empty Inklet panel appears and the previous clipboard stays unchanged.
- Trigger a focus change to a different app while a read is pending: Inklet cancels and neither copies nor presents text from the newly focused app.
- Exercise a clipboard race by copying different content from the source app or another app while the fallback is pending: the newer clipboard contents win and are not replaced by the saved snapshot.
- Start overlapping selection reads, cancel during the polling delay, and force a timeout. Confirm transactions remain serialized, cleanup finishes, and no stale read restores or presents data.
- No browser Automation prompt appears in any selection scenario.
- Inspect the bundle-qualified selection diagnostic log and confirm repeated event entries are rate-limited and no selected text, clipboard text, or typed characters are recorded.
- Translate selected text and confirm the result remains visible with copy, original-audio, and translated-audio controls.
- Translate the same text with the same settings again and confirm the cached result appears. Confirm a successful action is recorded in Settings > History, but mere selection without an action is not.
- In Settings > Selection Assistant > Menu Buttons, turn on two prompt modes and reorder the list. Select text and confirm the menu shows the buttons in that order, long mode names truncate with a tooltip, and the last enabled button cannot be turned off.
- Turn on five or more buttons and confirm three show inline and the rest open from **More**. Choose each overflow item and confirm it runs; the panel stays open while the More menu is shown.
- Run a prompt mode button: its icon becomes a spinner, the result appears with Copy result and Play result controls, Retry after a failure reruns the same mode, and the run is recorded in History with the mode name.
- Choose Restore Default and confirm the menu returns to Translate and Pronounce.

## Update Checks

- Online, use both app-menu locations in a production build and choose **Check for Updates…** against the current release. Confirm both menu items change to the same disabled checking state, then a manual result says Inklet is up to date.
- Online, check manually from Inklet Local against the current release and confirm the same up-to-date feedback is available.
- Run `swift test --filter GitHubReleaseUpdateCheckerTests`. These automated fixtures cover malformed release tags and URLs, draft and prerelease responses, missing and non-uploaded `Inklet.dmg` assets, a stable response with an uploaded `Inklet.dmg`, and empty notes and long release notes as text behavior only. Production and Inklet Local have no live-app fixture switch, so these tests do not verify alert layout or readability.
- Only when GitHub publishes a genuinely newer stable release with an uploaded `Inklet.dmg` than the running build, check from the live app. Confirm the alert shows the latest version and build, current version, useful release name, and release-note excerpt.
- With that genuinely newer stable release, choose **View on GitHub** and confirm the exact GitHub Release URL opens in the default browser. Repeat with **Later** and confirm the alert dismisses. In both cases, confirm no DMG or other asset is downloaded or installed.
- Go offline and check manually. Confirm the failure alert contains no internal details, **Retry** starts one new manual request after the first finishes, and **Cancel** dismisses it. Trigger an automatic check offline and confirm the failure is silent.
- In a production build, confirm an automatic check is attempted about once every 24 hours and is not repeated on each launch after a failed attempt. Confirm Inklet Local never schedules automatic checks while its manual command continues to work.
- While a genuinely newer stable release is live, make a due production automatic check complete separately during a writing transformation, dictation, Selection Actions panel, migration, tracked menu, and modal window. Confirm the alert does not interrupt or dismiss the active workflow, then appears exactly once after Inklet becomes idle in each case.
- Repeat automatic-check deferral while holding Shift or the left mouse button inside Inklet, and while holding Shift in another app, switching to Inklet, then releasing it. Confirm releasing the gesture allows the pending alert to appear once other blockers are clear, without triggering Selection Actions inside Inklet.
- Repeat the menu, checking-state, update-available, up-to-date, failure, Retry, and Later paths in English, Simplified Chinese, Traditional Chinese, Japanese, Korean, Spanish, French, German, Portuguese, and Italian. Confirm each resolves without fallback and that Chinese and English copy fits without overlap.
- If no genuinely newer stable release is live, the newer-release alert, **View on GitHub**, **Later**, deferred automatic alert, and update-available localization interactions remain unverified, not passed. Without a fixture-capable app build, empty-note fallback layout and long-note visual readability also remain unverified unless the genuinely newer live release itself has that exact note shape. Record those limitations explicitly; automated fixtures are not a substitute for live-app checks.
- What's New: with the guide already finished, install a build whose `CFBundleShortVersionString` is newer and listed in `WhatsNewCatalog`. Confirm the window appears once about three seconds after launch without taking focus from the app in front, waits while the writing popover is open, does not appear again on the next launch, and that **Changelog** in the menu bar menu lists every release newest first with the running version highlighted. Confirm a new install shows only the welcome guide.

## Settings And History

- `Command+,`: open Settings while Inklet is active.
- General: change language and appearance.
- AI Models: configure the OpenAI API key in the API keys card. Check that each feature page (Write Assistant, Live Dictation, Selection Assistant) names its engine and that "Change in AI Models" opens this page.
- Provider: switch to another provider (for example DeepSeek), enter its key in the API keys card, and confirm the OpenAI API Key row stays for text to speech and OpenAI dictation, and that clearing the provider key shows a missing-key warning under the text engine. Transform text in the popover and translate a selection with that provider; confirm dictation and pronunciation still use the OpenAI key. Choose Custom (OpenAI Compatible), set a local endpoint, and transform text. Switch back to OpenAI and confirm the shared key and default model return. Check the AI Models page in English and Chinese for fit.
- Write Assistant: configure the model for the selected provider, writing shortcut, and timeout.
- Writing Assistant: configure the Dictation hold shortcut and microphone. In Advanced Dictation, confirm only the recovery model is available and there is no endpoint field.
- Selection Assistant: configure translation language, Translate prompt, Force Selection mode, pronunciation voice, and speed; preview the voice.
- Prompt Modes: add, edit, hide, delete with confirmation, and reorder modes.
- Permissions: verify Accessibility status and the System Settings button. Inklet should not steal focus while System Settings is open; close it and confirm the existing Settings window returns with refreshed status.
- History: confirm successful Write and Selection results appear newest first. Repeat identical consecutive actions and confirm duplicates collapse; add a different item and then repeat the original to confirm it is retained. Dictation alone must add nothing.
- History: filter by Write and Selection, then confirm imported legacy Voice entries and the Voice filter remain readable. Select source/result text, copy result text, clear History, and confirm the empty state.
- Feedback: choose **Send Feedback…** from the menu bar menu and confirm the browser opens the GitHub new-issue chooser with the bug report and feature request forms. Check the item label in English and Chinese.
- Save behavior: quit and reopen Inklet and confirm changes persist in the matching bundle's defaults.

## Local Models

- New install on Apple silicon (reset local state and move downloaded models aside): confirm the welcome guide opens in the Mac's system language, its first step switches the interface language immediately, the Accessibility step turns to Allowed after granting it in System Settings, the model step suggests **Built-in** with the model for this Mac's memory, **Download and Continue** starts the download, the microphone step asks for access, the model step records a new writing hotkey and the dictation step picks the hold key, both working right after the guide, and **Start Writing** opens the writing popover with the download's progress, which then transforms text once it finishes. Quit midway and confirm the guide opens again on the next launch. On an Intel Mac, confirm the model step offers only the cloud model. With an API key already saved, confirm the guide still opens once after the update, offers to keep the current provider, and leaves it as it was.
- Built-in on Apple silicon: choose **Built-in**, confirm the recommended model matches this Mac's memory, download it, cancel midway, download again, and confirm it resumes rather than restarting.
- After the download shows **Ready**, transform text and translate a selection with Wi-Fi turned off. The first request may take longer while the model loads.
- Switch between Qwen3.5 4B and Gemma 4 E4B, delete one model, and confirm writing then asks you to download it.
- On a Mac with less than 24 GB, leave Inklet idle for more than five minutes and confirm Activity Monitor shows `llama-server` releasing its memory. On 24 GB or more, confirm the model stays loaded and the first request after a long pause answers without a reload delay. Open the writing popover after a pause and confirm the model starts loading before you submit. Quit Inklet and confirm `llama-server` exits.
- Ollama: with Ollama closed, choose **Ollama** and confirm the connection row says it can't reach Ollama; open Ollama, click **Refresh**, and confirm the downloaded models appear. Transform text and confirm no thinking text appears in the result.
- LM Studio: repeat the Ollama check with LM Studio's local server.
- Confirm the API key field is hidden for local providers and the optional OpenAI key field still controls dictation and pronunciation.
- On-device dictation, new install on Apple silicon: in the welcome guide's Live Dictation step, confirm it names the speech model and its size, and that allowing the microphone (or continuing with it already allowed) starts the speech model download while **Set Up Later** does not. Confirm Live Dictation settings show **On this Mac** and the writing popover shows the download's own strip. Upgrade a setup saved by an older build and confirm it keeps **OpenAI**.
- With **On this Mac** and the speech model ready, turn Wi-Fi off and dictate Chinese, English, and Chinese mixed with English. Confirm the draft updates while you speak, earlier words may be corrected, each sentence settles after a pause, and release leaves one undoable dictation.
- Delete the speech model and hold the shortcut: confirm the error says to download it in Live Dictation settings and the popover offers **Download**. Choose **OpenAI** and confirm the Advanced Dictation recovery model appears again and dictation streams to OpenAI.
- Speech model residency: on 16 GB or more, confirm a second `llama-server` for the speech model starts at launch while dictation is on, stays loaded through long pauses, and exits when you turn dictation off or choose OpenAI. On smaller Macs, confirm it starts when the writing popover opens and releases its memory after five idle minutes. Quit Inklet and confirm both servers exit.

## Language Switching And Layout

- Run `scripts/check-localization.sh --snapshots` and inspect the printed HTML gallery. Run `swift test` as well; record automated results separately from live checks below.
- Cycle through all ten interface languages at the actual window size. At minimum, compare English, both Chinese variants, German, French and Portuguese for width expansion; include Japanese and Korean font rendering.
- Keep Settings open while switching. Inspect every sidebar section, long shortcut names, permission instructions, migration actions, History timestamps, prompt editing/deletion, and About links. Check Light and Dark appearance for overlap, truncation and reachable controls.
- Keep a writing draft and result, change language, and return. Both must survive; inspect launcher search/highlight, actions, long dictation status and multiline errors. Verify keyboard shortcuts and focus still work.
- Text to speech: on a new install, Settings › AI Models › Text to speech shows macOS system voice and no key warning. Pronounce an English, Simplified Chinese, Traditional Chinese, and Japanese selection and confirm each is read in its own language, with the speaker icon going to playing and back to idle when it ends; pressing Pronounce again restarts it, and Escape or dismissing the panel stops it. Move the speed slider and confirm the next reading is slower or faster. Preview in Selection Assistant › Pronunciation reads the preview sentence. Switch to OpenAI and confirm the voice picker returns, the missing-key warning shows without an OpenAI key, and Pronounce uses OpenAI. Update from a config saved by 2.0.0: with an OpenAI key it keeps OpenAI; without one it switches to the system voice on the first launch, and choosing OpenAI again afterwards sticks across relaunches.
- Inspect Translate/Pronounce in every language: compact padding, complete labels, stable button sizes during loading/playing, dismissal and retry. In a translation result, check copy/original audio/translated audio states and retained text while resizing.
- Reopen menus, About, update and migration dialogs after switching. Check localized title/action/help/VoiceOver labels, errors, confirmations and cancellation. Check system-language preference order, including English ahead of another supported language.
- Mark any unavailable permission, migration, update, playback or error state as unverified. Synthetic snapshots do not verify these live flows or translation quality.

## Design Language

- Compare the writing popover, mode picker, selection bar and translation card with `docs/DESIGN.md` and its linked canvas in Light and Dark appearance.
- In System Settings > Appearance, switch the accent color through blue, purple, pink, red, orange, yellow, green and graphite with the popover open. The primary button, mode chip icon, selected mode row and listening waveform follow the accent; button text stays readable (dark text on orange, yellow and green).
- Hover every icon button, shortcut hint, mode row and selection bar button: each shows a neutral fill, and every icon-only control has a tooltip.
- Turn on Reduce Motion and check that results appear with a fade only.
- Open Settings: the window has the system traffic lights and drags from its top strip, Esc closes it, there is no custom close button, and the selected sidebar item is a neutral fill with an accent icon. Check every pane in Chinese and English, Light and Dark.
- In Prompt modes, long names such as "To Simple and Correct English" show in full; the visibility and delete icons appear on hover or selection, a hidden mode keeps its crossed-out eye and dims its name, reordering by drag still works, and delete asks for confirmation and is unavailable when only one mode is left.
- Open About and check the tile, title, links and copyright in both appearances.

## Exact Signed Release Matrix

Run the fresh-install and signed-upgrade sections using the exact final DMG and supported hardware on macOS 14.x, macOS 15.x, and macOS 26.x. Record automatic versus assisted migration results separately for every OS version.

- Run `hdiutil verify` on the final DMG and require success.
- Run `xcrun stapler validate` on the final DMG and require a valid staple.
- Assess the DMG with Gatekeeper as an openable primary-signature artifact, mount it read-only, and assess the mounted app with Gatekeeper as executable.
- Verify the DMG signature, the app's deep strict signature, Hardened Runtime, production bundle identifier, and every architecture of the executable.
- Inspect effective entitlements on the final signed app: audio input is present; App Sandbox and Automation Apple Events are absent; no unexpected entitlement is present.
- Confirm the mounted app has no embedded provisioning profile and no store receipt, and the DMG contains only `Inklet.app` plus the expected `/Applications` link.
- Run the standalone installer against the final release assets. Confirm it requires and verifies the checksum, DMG, mounted payload, signature, Gatekeeper, Hardened Runtime, and effective entitlements before replacing `/Applications/Inklet.app`.
- Confirm quarantine is preserved through download and installation; do not clear extended attributes or bypass Gatekeeper.
- Verify first launch, automatic or assisted migration, Accessibility, first valid dictation hold, Keychain read/update, settings, History, and repeat-launch behavior from the installed final artifact.

## Compatibility Notes

- Smoke-test Slack or Discord, Notion, VS Code or Cursor, Terminal or iTerm, and any application changed by the release.
- Record unsupported protected-content or terminal behavior precisely. Do not turn an observed limitation into a claim that the entire matrix passed.
