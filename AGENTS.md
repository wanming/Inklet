# Agent Instructions

Before any response or action, use the relevant `superpowers` skill.

## Workflow

- Inspect relevant files and `git status` before editing. Preserve unrelated user work.
- State relevant assumptions before editing, and ask only when a safe assumption is not possible.
- Prefer the smallest surgical change that satisfies the request; avoid speculative abstractions and unrelated refactors.
- Match existing Swift, SwiftUI, naming, formatting, and file-organization patterns before introducing anything new.
- Add or update focused tests for behavior changes when practical.

## Product Quality

- Treat localization as part of every user-facing copy change. Update all supported language tables, or explicitly document an intentional fallback.
- Keep UI consistent with the existing Inklet style: restrained macOS settings aesthetics, shared theme colors, consistent typography, spacing, controls, and alignment.
- Favor clarity over decoration. Do not add flashy effects, oversized cards, gradients, or new visual motifs unless the product already uses them.
- For SwiftUI layout changes, verify text fits in Chinese and English, avoids overlap, and behaves at the app's actual window size.
- Treat Accessibility, clipboard, text insertion, voice audio, and API key flows as sensitive surfaces.

## Documentation And Privacy

- Update `README.md` and `README.zh-CN.md` when changing features, setup, permissions, providers, install steps, or release behavior.
- Keep public documentation accurate to shipped behavior. Remove stale instructions in the same change.
- Never commit personal or private operational data: names, personal email or phone numbers, Team IDs, reviewer credentials, API keys, certificates, signing identities, or submission notes.
- Store local-only notes under `.private/`. Store secrets in Keychain, `.env.local`, or the relevant external service.
- Add an ignore rule before creating a new private local artifact. Never commit `.private/`, `.env.local`, `*.p8`, `*.p12`, provisioning profiles, or generated packages.

## Verification

- Define verification before editing, then run the narrowest relevant checks.
- Run `swift test` for code changes. Use targeted app launches and the manual checklist for user-facing workflows.
- For release-sensitive changes, also run strict builds, signature checks, or script checks as applicable.
- Before finishing, inspect `git diff --check` and `git status`. Report any unverified area or remaining risk.

## Commits

- Keep each commit focused on one logical purpose. Do not mix cleanup with unrelated behavior changes.
- Use an English imperative subject, sentence case, no trailing period, ideally under 72 characters. Example: `Fix installer checksum validation`.
- Review the staged diff before committing. Exclude generated files, local configuration, credentials, and unrelated user changes.
