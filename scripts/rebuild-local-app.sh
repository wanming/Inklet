#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="${INKLET_ENV_FILE:-${repo_root}/.env.local}"
app_name="${INKLET_LOCAL_APP_NAME:-Inklet Local}"
bundle_id="${INKLET_LOCAL_BUNDLE_ID:-com.tomwan.inklet.local}"
output_dir="${INKLET_LOCAL_OUTPUT_DIR:-${repo_root}/dist/local}"
install_path="${INKLET_LOCAL_INSTALL_PATH:-/Applications/Inklet Local.app}"

if [[ -z "${INKLET_SIGN_IDENTITY:-}" && -f "$env_file" ]]; then
  # shellcheck disable=SC1090
  source "$env_file"
fi

app_path="${output_dir}/${app_name}.app"

resolve_sign_identity() {
  if [[ -n "${INKLET_SIGN_IDENTITY:-}" ]]; then
    printf '%s\n' "$INKLET_SIGN_IDENTITY"
    return 0
  fi

  if [[ -d "$install_path" ]]; then
    local installed_identity
    installed_identity="$(
      codesign -dvvv "$install_path" 2>&1 \
        | awk -F= '/^Authority=Developer ID Application:/ { print $2; exit }'
    )"
    if [[ -n "$installed_identity" ]] \
      && security find-identity -v -p codesigning 2>/dev/null | grep -Fq "\"${installed_identity}\""; then
      printf '%s\n' "$installed_identity"
      return 0
    fi
  fi

  cat >&2 <<'EOF'
Set INKLET_SIGN_IDENTITY in .env.local or the environment to keep local Accessibility and Keychain trust stable.
If /Applications/Inklet Local.app already exists and its signing certificate is available in Keychain, this script can reuse it automatically.
EOF
  return 1
}

sign_identity="$(resolve_sign_identity)"

echo "Building stable local ${app_name}.app..."
INKLET_APP_NAME="$app_name" \
INKLET_BUNDLE_ID="$bundle_id" \
INKLET_SIGN_IDENTITY="$sign_identity" \
INKLET_OUTPUT_DIR="$output_dir" \
  "${repo_root}/scripts/build-macos-app-bundle.sh"

echo "Quitting any running ${app_name} instance..."
osascript -e "tell application \"${app_name}\" to quit" >/dev/null 2>&1 || true
pkill -f "${install_path}/Contents/MacOS/${app_name}" >/dev/null 2>&1 || true

echo "Installing ${install_path}..."
if [[ -w "$(dirname "$install_path")" ]]; then
  rm -rf "$install_path"
  ditto "$app_path" "$install_path"
else
  sudo rm -rf "$install_path"
  sudo ditto "$app_path" "$install_path"
fi

echo "Verifying installed app signature..."
codesign --verify --deep --strict --verbose=2 "$install_path"

echo "Opening ${install_path}..."
open "$install_path"
