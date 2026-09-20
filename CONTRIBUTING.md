# Contributing

Thanks for your interest in Inklet. This project is a native macOS Swift app, and contributions are welcome.

## Shared Workflow Across Computers

Use the current tracked [AGENTS.md](AGENTS.md), scripts, and workflow documentation as the shared project conventions. Machine-local preferences and chat memory do not override them; explicit current user instructions still take precedence. Save durable project preferences in the repository in the same change. Optional local agent skills may assist this process; if unavailable, perform equivalent inspection, planning, and verification against the tracked requirements.

Start each task by fetching remote branches (including `main` and active task branches) and tags, inspecting `git status` and local/remote divergence, and reading the current shared instructions. Use a dedicated linked worktree, preserving unfinished branches and unrelated changes rather than resetting them. Push the task branch before continuing on another computer. Keep machine configuration, signing credentials, secrets, and app data local; they are not part of this handoff.

## Development Setup

Requirements:

- macOS 14 or newer.
- Swift 6 toolchain.
- Full Xcode is recommended for XCTest support.

Build:

```bash
swift build
```

Build, install, and run the local app:

```bash
scripts/run-local-app.sh
```

Use the installed `/Applications/Inklet Local.app` for local testing.

This is the routine QA workflow from every worktree. `scripts/run-local-app.sh` builds and verifies the local bundle, installs it at the stable path, and uses the configured stable signing identity so macOS can retain Accessibility and Keychain trust. Do not use an ad-hoc-signed or worktree-local app for routine QA. Use `scripts/reset-rebuild-install.sh` only for intentional first-launch or permission-reset testing because it removes local state by design.

Run tests:

```bash
swift test
```

Run the stricter build used before release:

```bash
swift build -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
```

## Pull Request Guidelines

- Keep changes focused and easy to review.
- Add or update tests for behavior changes.
- Keep user-facing behavior accessible by keyboard.
- Do not commit local build output, `.dmg` files, `.worktrees/`, `.build/`, API keys, tokens, or personal configuration.
- Update documentation when changing install, setup, provider, or release behavior.
- Use English for code, commit subjects, general contributor documentation, and release notes. Keep the English and Chinese READMEs aligned and preserve supported UI translations.

## Distribution And Release Changes

Inklet ships directly as a signed and notarized GitHub Releases DMG. Keep distribution changes aligned with the active scripts documented in [scripts/README.md](scripts/README.md), the standalone installer contract, and the release workflow in [.github/workflows/build-dmg.yml](.github/workflows/build-dmg.yml).

Before overlapping builds on different computers, make planned `VERSION` changes visible in pushed task branches and check other active work before choosing a higher build number. For each release, prepare `docs/releases/vX.Y.Z-N.md` from [the shared template](docs/releases/TEMPLATE.md), with English-only user-facing changes and the comparison from the previous published stable release. Run the [shared release checks](scripts/README.md#release-notes-and-publication), then merge and push the code, `VERSION`, and notes to `main`. The DMG workflow accepts only `main`, validates the tracked notes, and creates a draft by default. Publish as the latest stable release only when explicitly requested, after verifying the successful build, final assets, and notes.

Before proposing a release-sensitive change, run the focused shell contracts, `swift test`, the strict build above, and `git diff --check`. Do not publish or claim a release from local QA results; the release workflow must still complete signing, notarization, stapling, Gatekeeper, mounted-app, and checksum verification for the final artifact.

## Security and Privacy Expectations

- Do not log API keys, prompts, source text, generated text, clipboard contents, or selected text.
- Keep API keys local to the user's machine.
- Treat Accessibility, clipboard, and text insertion flows as sensitive surfaces.

## Manual QA

Before submitting a user-facing change, run through the relevant items in [docs/manual-test-checklist.md](docs/manual-test-checklist.md).
