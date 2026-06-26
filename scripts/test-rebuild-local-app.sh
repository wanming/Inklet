#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
local_script="${script_dir}/rebuild-local-app.sh"

if [[ ! -f "$local_script" ]]; then
  echo "rebuild-local-app.sh must exist for stable local manual testing." >&2
  exit 1
fi

if ! grep -q 'Inklet Local' "$local_script"; then
  echo "rebuild-local-app.sh must use the stable Inklet Local app name." >&2
  exit 1
fi

if ! grep -q 'com.tomwan.inklet.local' "$local_script"; then
  echo "rebuild-local-app.sh must use the stable local bundle identifier." >&2
  exit 1
fi

if ! grep -q '/Applications/Inklet Local.app' "$local_script"; then
  echo "rebuild-local-app.sh must install to the stable /Applications/Inklet Local.app path." >&2
  exit 1
fi

if ! grep -q 'resolve_sign_identity' "$local_script"; then
  echo "rebuild-local-app.sh must resolve a stable signing identity." >&2
  exit 1
fi

if ! grep -q 'codesign -dvvv "$install_path"' "$local_script"; then
  echo "rebuild-local-app.sh must inspect the installed local app signing identity when available." >&2
  exit 1
fi

if ! grep -q 'security find-identity -v -p codesigning' "$local_script"; then
  echo "rebuild-local-app.sh must verify that the resolved signing identity exists locally." >&2
  exit 1
fi

if grep -q 'INKLET_SIGN_IDENTITY="-"' "$local_script"; then
  echo "rebuild-local-app.sh must not fall back to ad-hoc signing." >&2
  exit 1
fi

if ! grep -q 'build-macos-app-bundle.sh' "$local_script"; then
  echo "rebuild-local-app.sh must build through the shared app bundle script." >&2
  exit 1
fi

if ! grep -q 'codesign --verify --deep --strict' "$local_script"; then
  echo "rebuild-local-app.sh must verify the installed app signature." >&2
  exit 1
fi

if ! grep -q 'open "$install_path"' "$local_script"; then
  echo "rebuild-local-app.sh must open the stable installed app path." >&2
  exit 1
fi

if grep -Eq 'reset-local-state|tccutil reset|security delete-generic-password' "$local_script"; then
  echo "rebuild-local-app.sh must preserve local permissions, preferences, and Keychain items." >&2
  exit 1
fi

echo "rebuild-local-app.sh local workflow checks passed."
