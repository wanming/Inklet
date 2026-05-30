#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -z "${INKLET_SIGN_IDENTITY:-}" && -f "${repo_root}/.env.local" ]]; then
  # shellcheck disable=SC1091
  source "${repo_root}/.env.local"
fi
sign_identity="${INKLET_SIGN_IDENTITY:?Set INKLET_SIGN_IDENTITY to your Apple signing certificate name}"
app_path="${repo_root}/dist/app-store-spike/Inklet.app"
install_path="/Applications/Inklet.app"

echo "Building sandbox Inklet.app..."
INKLET_SIGN_IDENTITY="$sign_identity" "${repo_root}/scripts/build-app-store-spike.sh"

echo "Verifying signature..."
codesign --verify --deep --strict --verbose=2 "$app_path"

echo "Installing ${install_path}..."
osascript -e 'tell application "Inklet" to quit' >/dev/null 2>&1 || true
pkill -x Inklet >/dev/null 2>&1 || true

if [[ -w "/Applications" ]]; then
  rm -rf "$install_path"
  ditto "$app_path" "$install_path"
else
  sudo rm -rf "$install_path"
  sudo ditto "$app_path" "$install_path"
fi

echo "Opening ${install_path}..."
open "$install_path"
