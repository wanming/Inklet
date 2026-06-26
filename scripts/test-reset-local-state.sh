#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
reset_output="$("${script_dir}/reset-local-state.sh" --dry-run)"

if ! grep -q 'security delete-generic-password -s Inklet.ProviderAPIKey' <<<"$reset_output"; then
  echo "reset-local-state.sh must delete current Keychain API keys." >&2
  exit 1
fi

if ! grep -q 'defaults delete com.tomwan.inklet.local' <<<"$reset_output"; then
  echo "reset-local-state.sh must reset the stable local app preferences." >&2
  exit 1
fi

if ! grep -q 'tccutil reset Accessibility com.tomwan.inklet.local' <<<"$reset_output"; then
  echo "reset-local-state.sh must reset stable local app Accessibility permission." >&2
  exit 1
fi

remove_output="$("${script_dir}/reset-local-state.sh" --dry-run --remove-installed-app)"
if ! grep -Eq '/Applications/Inklet\\? Local\.app' <<<"$remove_output"; then
  echo "reset-local-state.sh --remove-installed-app must remove the stable local app." >&2
  exit 1
fi

echo "reset-local-state.sh checks passed."
