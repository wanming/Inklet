# Security Policy

## Supported Versions

Fluenta is currently an early MVP. Security fixes target the latest commit on `main`.

## Reporting a Vulnerability

Please report security issues privately instead of opening a public issue.

If GitHub private vulnerability reporting is enabled for this repository, use that flow. Otherwise, contact the repository owner directly through GitHub.

Please include:

- A clear description of the issue.
- Steps to reproduce.
- Affected macOS version, Fluenta version or commit, and relevant provider configuration.
- Any logs or screenshots that do not include secrets or private user text.

## Sensitive Data

Fluenta handles text that users type, select, transform, and paste. It also stores provider API keys locally. Security-sensitive areas include:

- API key storage.
- Clipboard preservation and restoration.
- Accessibility permission usage.
- Selected text capture.
- Provider request construction.

Do not include real API keys, private text, or personal data in bug reports.
