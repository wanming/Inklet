#!/usr/bin/env bash
set -euo pipefail

repo="${INKLET_REPO:-${FLUENTA_REPO:-wanming/Inklet}}"
install_dir="${INKLET_INSTALL_DIR:-${FLUENTA_INSTALL_DIR:-/Applications}}"
app_name="Inklet.app"
legacy_app_name="Fluenta.app"
asset_name="Inklet.dmg"
api_url="https://api.github.com/repos/${repo}/releases"
auth_token="${GITHUB_TOKEN:-${GH_TOKEN:-}}"

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/inklet-install.XXXXXX")"
mount_dir="$(mktemp -d "${TMPDIR:-/tmp}/inklet-mount.XXXXXX")"
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

echo "Downloading Inklet..."

curl_api_args=(-fL --retry 3 --retry-delay 1)
curl_download_args=(-fL --retry 3 --retry-delay 1)
if [[ -n "$auth_token" ]]; then
  curl_api_args+=(
    -H "Authorization: Bearer ${auth_token}"
    -H "Accept: application/vnd.github+json"
  )
  curl_download_args+=(
    -H "Authorization: Bearer ${auth_token}"
    -H "Accept: application/octet-stream"
  )
fi

resolve_asset_url() {
  local requested_asset_name="$1"
  local releases_json
  releases_json="$(curl "${curl_api_args[@]}" "$api_url")"

  if command -v /usr/bin/python3 >/dev/null 2>&1; then
    ASSET_NAME="$requested_asset_name" HAS_AUTH="$([[ -n "$auth_token" ]] && echo 1 || echo 0)" /usr/bin/python3 -c '
import json
import os
import sys

asset_name = os.environ["ASSET_NAME"]
url_key = "url" if os.environ.get("HAS_AUTH") == "1" else "browser_download_url"
for release in json.load(sys.stdin):
    if release.get("draft") or release.get("prerelease"):
        continue
    for asset in release.get("assets", []):
        if asset.get("name") == asset_name:
            print(asset[url_key])
            raise SystemExit(0)
raise SystemExit(1)
' <<<"$releases_json"
    return
  fi

  if command -v /usr/bin/ruby >/dev/null 2>&1; then
    ASSET_NAME="$requested_asset_name" HAS_AUTH="$([[ -n "$auth_token" ]] && echo 1 || echo 0)" /usr/bin/ruby -rjson -e '
asset_name = ENV.fetch("ASSET_NAME")
url_key = ENV["HAS_AUTH"] == "1" ? "url" : "browser_download_url"
JSON.parse(STDIN.read).each do |release|
  next if release["draft"] || release["prerelease"]
  asset = release.fetch("assets", []).find { |candidate| candidate["name"] == asset_name }
  if asset
    puts asset.fetch(url_key)
    exit 0
  end
end
exit 1
' <<<"$releases_json"
    return
  fi

  echo "Could not find python3 or ruby to parse GitHub release metadata." >&2
  return 1
}

dmg_url="$(resolve_asset_url "$asset_name")"
checksum_url="$(resolve_asset_url "${asset_name}.sha256" || true)"

curl "${curl_download_args[@]}" "$dmg_url" -o "$dmg_path"

if [[ -n "$checksum_url" ]] && curl "${curl_download_args[@]}" "$checksum_url" -o "$checksum_path" >/dev/null 2>&1; then
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
osascript -e 'tell application "Inklet" to quit' >/dev/null 2>&1 || true
osascript -e 'tell application "Fluenta" to quit' >/dev/null 2>&1 || true

legacy_target_app="${install_dir}/${legacy_app_name}"

if [[ -w "$install_dir" ]]; then
  rm -rf "$target_app"
  rm -rf "$legacy_target_app"
  ditto "$source_app" "$target_app"
  xattr -dr com.apple.quarantine "$target_app" >/dev/null 2>&1 || true
else
  sudo mkdir -p "$install_dir"
  sudo rm -rf "$target_app"
  sudo rm -rf "$legacy_target_app"
  sudo ditto "$source_app" "$target_app"
  sudo xattr -dr com.apple.quarantine "$target_app" >/dev/null 2>&1 || true
fi

echo "Inklet installed."
echo "Open it from ${target_app}, then grant Accessibility permission when prompted."
