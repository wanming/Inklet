# Scripts

This directory is split by workflow. Prefer the smallest script that matches the job.

Use these tracked scripts with [AGENTS.md](../AGENTS.md) and the [shared workflow](../CONTRIBUTING.md#shared-workflow-across-computers) on every computer. Keep durable workflow changes in the repository, and keep machine configuration and secrets local.

## Direct Bundle

- `build-macos-app-bundle.sh` builds and signs an Inklet `.app` in `dist/direct/` by default. Pass `INKLET_OUTPUT_DIR` to select another output directory.
- `verify-direct-app.sh` checks a direct-distribution bundle's identifier, signature, Hardened Runtime, entitlements, privacy metadata, and release signing policy.

## Release Version Checks

Before each app bundle build, increase both values in the root `VERSION` file. Keep `INKLET_BUILD_NUMBER` a positive integer greater than every previously used or reserved build number; never reset it when `INKLET_VERSION` changes. Fetch remote branches (including `main` and active task branches) and tags, inspect all GitHub releases including drafts and prereleases, and coordinate with active worktrees and work on other computers before choosing the next number. Make planned `VERSION` changes visible in pushed task branches before overlapping builds, then recheck before building or releasing.

`check-release-build-number.py` validates `VERSION` and rejects a candidate build number that is less than or equal to any existing `vX.Y.Z-N` tag's build number. Provide a text file with one tag per line, containing all Git tags and all GitHub release tag names, including drafts and prereleases:

```bash
python3 scripts/check-release-build-number.py VERSION /path/to/release-tags.txt
```

The script does not fetch tags or modify `VERSION`. The serialized DMG workflow gathers Git tags and all release tags, then runs this check before building. After packaging, verify the app's `CFBundleShortVersionString` and `CFBundleVersion` match `VERSION`, the release tag/title, and the versioned DMG filename. Correct embedded metadata by rebuilding, signing, notarizing, and regenerating checksums; renaming a release or artifact alone is insufficient.

## Release Notes And Publication

Create `docs/releases/vX.Y.Z-N.md` from [the shared template](../docs/releases/TEMPLATE.md) before each release build. Use the exact `# Inklet X.Y.Z (N)` title matching `VERSION` and the release tag. Write release notes only in English, with concise user-facing bullets under `## Changes`, covering additions, improvements, and fixes. Include relevant upgrade requirements in English in that section. Add a `**Full changelog**` link to the exact comparison from the previous published stable release; omit internal planning, version-only commits, placeholders, and workflow-run boilerplate.

`check-release-notes.py` validates the title, `Changes` section, English-only format, content, and exact comparison link. Supply a flat JSON array of every GitHub release, including drafts and prereleases; the checker selects the previous published stable release from that complete list:

```bash
python3 scripts/check-release-notes.py docs/releases/vX.Y.Z-N.md /path/to/releases.json vX.Y.Z-N owner/repository
```

For the first release, link to `https://github.com/owner/repository/tree/vX.Y.Z-N` instead of a comparison. The checker validates structure; review clarity, shipped scope, and upgrade requirements before publishing. `test-release-notes.py` exercises these checks and the build workflow using synthetic releases, without publishing anything. Pull requests run it alongside `test-release-build-number.py`.

Merge and push the intended changes, `VERSION`, and matching notes to `main`, then dispatch `build-dmg.yml` with `--ref main`. The workflow rejects other branches, validates the notes before building, and passes the tracked file to GitHub as the release description when creating or updating a release. Builds create drafts by default. When explicitly asked to publish, verify the successful build, final assets, and notes, then publish with `draft=false`, `prerelease=false`, and mark it as latest. An already verified draft needs no rebuild or version increment.

## Public Install

- `install.sh` downloads the latest notarized GitHub Releases DMG, verifies its checksum, Gatekeeper acceptance, and app signature, then installs Inklet.

## Local QA

- `run-local-app.sh` is the routine hand-testing path for agents and worktrees. It builds, verifies, installs, and opens `/Applications/Inklet Local.app` with the `com.tomwan.inklet.local` bundle identifier. It uses a stable signing identity so macOS can preserve Accessibility permission across rebuilds.
- `reset-local-state.sh --scope local|production|all` performs an explicitly scoped destructive reset of preferences, Accessibility and Microphone permissions, the matching Keychain API key, app data, and selection diagnostics. Add `--remove-installed-app` to remove only the app selected by the scope, or `--dry-run` to inspect every exact target without changing state.
- `reset-rebuild-install.sh` runs the destructive local first-launch flow: reset only local state, remove `/Applications/Inklet Local.app`, then rebuild, reinstall, and open it through `run-local-app.sh`.

## Checks

- `check-localization.sh` validates permission string files and runs localization coverage, language switching, and native layout regression tests. Add `--snapshots` for a synthetic offscreen UI gallery; it prints the generated HTML path. It does not launch Inklet or read saved writing/history. Settings fixtures can read microphone names and the current permission status.
- `test-direct-distribution.sh` checks the direct-distribution bundle and verifier contracts.
- `test-install-security.sh` checks safety invariants in `install.sh`.
- `test-run-local-app.sh` checks that local app runs use stable signing, local bundle settings, and redacted signing logs.
- `test-reset-local-state.sh` checks exact reset scopes, targets, and destructive-command safety.

## Assets

- `generate-app-icons.swift` regenerates app icon PNGs, preview, and `.icns` from `Assets/PenNib.svg`.
