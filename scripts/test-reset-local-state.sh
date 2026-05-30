#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
reset_output="$("${script_dir}/reset-local-state.sh" --dry-run)"

if ! grep -q 'security delete-generic-password -s Inklet.ProviderAPIKey' <<<"$reset_output"; then
  echo "reset-local-state.sh must delete current Keychain API keys." >&2
  exit 1
fi

echo "reset-local-state.sh checks passed."
