#!/usr/bin/env bash
set -euo pipefail

repo="${FLUENTA_REPO:-wanming/Fluenta}"
install_dir="${FLUENTA_INSTALL_DIR:-/Applications}"
app_name="Fluenta.app"
asset_name="Fluenta.dmg"
base_url="https://github.com/${repo}/releases/latest/download"

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/fluenta-install.XXXXXX")"
mount_dir="$(mktemp -d "${TMPDIR:-/tmp}/fluenta-mount.XXXXXX")"
dmg_path="${tmp_dir}/${asset_name}"
checksum_path="${tmp_dir}/${asset_name}.sha256"
mounted=0

cleanup() {
  if [[ "$mounted" == "1" ]]; then
    hdiutil detach "$mount_dir" -quiet >/dev/null 2>&1 || true
  fi
  rm -rf "$tmp_dir" "$mount_dir"
}
trap cleanup EXIT

echo "Downloading Fluenta..."
curl -fL --retry 3 --retry-delay 1 "${base_url}/${asset_name}" -o "$dmg_path"

if curl -fL --retry 3 --retry-delay 1 "${base_url}/${asset_name}.sha256" -o "$checksum_path" >/dev/null 2>&1; then
  expected_hash="$(awk '{print $1}' "$checksum_path")"
  actual_hash="$(shasum -a 256 "$dmg_path" | awk '{print $1}')"
  if [[ "$expected_hash" != "$actual_hash" ]]; then
    echo "Checksum verification failed." >&2
    echo "Expected: $expected_hash" >&2
    echo "Actual:   $actual_hash" >&2
    exit 1
  fi
  echo "Checksum verified."
else
  echo "No checksum found; continuing without checksum verification."
fi

echo "Mounting DMG..."
hdiutil attach "$dmg_path" -mountpoint "$mount_dir" -nobrowse -quiet
mounted=1

source_app="${mount_dir}/${app_name}"
if [[ ! -d "$source_app" ]]; then
  source_app="$(find "$mount_dir" -maxdepth 2 -name "$app_name" -type d -print -quit)"
fi

if [[ -z "${source_app:-}" || ! -d "$source_app" ]]; then
  echo "Could not find ${app_name} in the DMG." >&2
  exit 1
fi

target_app="${install_dir}/${app_name}"

echo "Installing to ${target_app}..."
osascript -e 'tell application "Fluenta" to quit' >/dev/null 2>&1 || true

if [[ -w "$install_dir" ]]; then
  rm -rf "$target_app"
  ditto "$source_app" "$target_app"
  xattr -dr com.apple.quarantine "$target_app" >/dev/null 2>&1 || true
else
  sudo mkdir -p "$install_dir"
  sudo rm -rf "$target_app"
  sudo ditto "$source_app" "$target_app"
  sudo xattr -dr com.apple.quarantine "$target_app" >/dev/null 2>&1 || true
fi

echo "Fluenta installed."
echo "Open it from ${target_app}, then grant Accessibility permission when prompted."
