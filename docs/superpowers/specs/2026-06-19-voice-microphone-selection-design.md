# Voice Microphone Selection Design

## Goal

Add microphone selection to Voice Write Assistant so users can choose System Default or a specific available audio input device for voice dictation.

## Context

Inklet currently records voice dictation through `AudioRecorder`, which uses `AVAudioRecorder`. That records from the system active input device, so it cannot honor an Inklet-specific microphone choice. Settings already persists `VoiceInputConfig`, auto-saves changes, and presents voice controls as compact `settingsRow` pickers. Voice dictation is a sensitive microphone flow, so the change must preserve permission behavior, clear errors, cleanup/transcription flow, and temporary recording cleanup.

## Approaches Considered

1. Change the macOS default input device before recording.
   This would make `AVAudioRecorder` work, but it mutates global system state and could surprise other apps.

2. Keep `AVAudioRecorder` and store the selected device only as a display preference.
   This is low risk but does not actually choose the recording source.

3. Record through `AVCaptureSession` with a selected `AVCaptureDevice`.
   This keeps the choice local to Inklet, uses public AVFoundation APIs for device discovery and file output, and preserves the existing transcription pipeline. This is the recommended design.

## Design

Settings adds a "Microphone" row in Voice Write Assistant, placed after "Voice Shortcut" and before "Speech Preset". The picker always includes "System Default" first, followed by currently available audio input devices from AVFoundation. The picker uses localized labels, autosaves with the existing settings model, and keeps the same width and restrained macOS settings style as nearby voice controls.

`VoiceInputConfig` stores an optional `microphoneDeviceID`. `nil` means System Default. The existing config decoder should continue to fall back to defaults when older configs lack this field, and round trips should preserve a saved concrete device ID.

The app layer owns device discovery because it depends on AVFoundation and live hardware. A small microphone catalog exposes stable menu choices with `id` and `name`, including the default option. If the saved device ID is no longer available, Settings should still show System Default as the effective selection rather than displaying a stale broken item.

Recording switches from `AVAudioRecorder` to an `AVCaptureSession` plus `AVCaptureAudioFileOutput`. At `start`, `AudioRecorder` requests microphone permission, resolves the configured device ID to an available `AVCaptureDevice`, falls back to `AVCaptureDevice.default(for: .audio)` when the setting is System Default or stale, and records a temporary `.m4a` file. At `stop`, it waits for the file output delegate to finish writing before returning the URL to the transcription pipeline. At `cancel`, it stops recording and deletes the temporary file.

## Error Handling

If microphone permission is denied, the existing permission error remains. If no default or selected audio input can be resolved, the existing no-audio-input error remains. If the selected device disappears between Settings and recording, Inklet falls back to System Default; if no default exists, it shows the no-audio-input error. If the capture session cannot add the input/output or cannot start writing, Inklet shows the existing recording-unavailable error.

## Localization And Documentation

Add English and Simplified Chinese localization for the new Settings row, help text, and System Default menu item. Other supported app languages may intentionally fall back to English in the central localization table if they do today for new Settings strings. Update `README.md`, `README.zh-CN.md`, and `docs/manual-test-checklist.md` to mention microphone selection.

## Verification

Add focused core tests for the new config field: default value, decoding older configs, and round-tripping a saved device ID. Run `swift test`. Because live audio devices are hardware-dependent, verify manually by selecting System Default and at least one concrete microphone in Settings, recording dictation, unplugging or disabling the selected device, and confirming fallback/error behavior. Finish with `git diff --check` and `git status`.
