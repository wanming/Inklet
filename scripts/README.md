# Scripts

This directory is split by workflow. Prefer the smallest script that matches the job.

## Release

- `build-app-store-release.sh` builds, signs, validates, and optionally uploads a Mac App Store `.pkg`.
- `build-macos-app-bundle.sh` builds a signed `.app` bundle in `dist/app-store-spike/` or the output directory you pass with `INKLET_OUTPUT_DIR`.
- `build-app-store-spike.sh` is a backwards-compatible wrapper for `build-macos-app-bundle.sh`.

## Public Install

- `install.sh` downloads the latest notarized GitHub Releases DMG, verifies checksum, checks Gatekeeper and app signature, then installs Inklet.

## Local QA

- `rebuild-sandbox-app.sh` builds, verifies, installs to `/Applications/Inklet.app`, and opens the app. It preserves local Inklet preferences and Keychain data.
- `run-local-app.sh` is the default routine hand-testing path for agents and worktrees. It builds, verifies, installs, and opens `/Applications/Inklet Local.app` with the `com.tomwan.inklet.local` bundle identifier. It requires a stable signing identity by default so macOS can preserve Accessibility permission across rebuilds.
- `reset-local-state.sh` resets preferences, Accessibility and Microphone permissions, Keychain API keys, and temporary voice recordings.
- `reset-rebuild-install.sh` runs the full destructive first-launch flow: reset local state, remove `/Applications/Inklet.app`, rebuild, reinstall, and open.

## Checks

- `test-install-security.sh` checks safety invariants in `install.sh`.
- `test-run-local-app.sh` checks that local app runs use stable signing, local bundle settings, and redacted signing logs.
- `test-reset-local-state.sh` checks that local reset covers current Keychain API keys.

## Assets

- `generate-app-icons.swift` regenerates app icon PNGs, preview, and `.icns` from `Assets/PenNib.svg`.
