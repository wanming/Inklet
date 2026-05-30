#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/build-app-store-release.sh [version] [build] [--upload]

Examples:
  scripts/build-app-store-release.sh --upload
  scripts/build-app-store-release.sh 1.0.0 4 --upload

Reads release version from VERSION and local signing settings from .env.local by default.

Required environment variables:
  INKLET_APP_STORE_APP_SIGN_IDENTITY
  INKLET_APP_STORE_INSTALLER_SIGN_IDENTITY
  INKLET_APP_STORE_PROFILE

Required for Apple validation or upload:
  ASC_EMAIL
  ASC_PASSWORD

Options:
  --upload               Upload the package after validation.
  --skip-tests           Skip swift test.
  --skip-apple-validate  Skip xcrun altool validation.
  -h, --help             Show this help.
EOF
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version_file="${INKLET_VERSION_FILE:-${repo_root}/VERSION}"
env_file="${INKLET_ENV_FILE:-${repo_root}/.env.local}"

if [[ -f "$env_file" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$env_file"
  set +a
fi

if [[ -f "$version_file" ]]; then
  # shellcheck disable=SC1090
  source "$version_file"
fi

upload=0
skip_tests=0
skip_apple_validate=0
positionals=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --upload)
      upload=1
      ;;
    --skip-tests)
      skip_tests=1
      ;;
    --skip-apple-validate)
      skip_apple_validate=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      positionals+=("$1")
      ;;
  esac
  shift
done

if [[ "${#positionals[@]}" -gt 2 ]]; then
  echo "Too many positional arguments: ${positionals[*]}" >&2
  usage >&2
  exit 2
fi

version="${positionals[0]:-${INKLET_VERSION:-}}"
build_number="${positionals[1]:-${INKLET_BUILD_NUMBER:-}}"

require_var() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required environment variable: ${name}" >&2
    echo "Set it in ${env_file}." >&2
    exit 2
  fi
}

if [[ -z "${version:-}" || "$version" == --* ]]; then
  echo "Missing version. Pass it as the first argument or set INKLET_VERSION in ${version_file}." >&2
  usage >&2
  exit 2
fi

if [[ -z "${build_number:-}" || "$build_number" == --* ]]; then
  echo "Missing build number. Pass it as the second argument or set INKLET_BUILD_NUMBER in ${version_file}." >&2
  usage >&2
  exit 2
fi

require_var INKLET_APP_STORE_APP_SIGN_IDENTITY
require_var INKLET_APP_STORE_INSTALLER_SIGN_IDENTITY
require_var INKLET_APP_STORE_PROFILE

if [[ ! -f "${INKLET_APP_STORE_PROFILE}" ]]; then
  echo "Provisioning profile not found: ${INKLET_APP_STORE_PROFILE}" >&2
  exit 2
fi

if [[ "$skip_apple_validate" -eq 0 || "$upload" -eq 1 ]]; then
  require_var ASC_EMAIL
  require_var ASC_PASSWORD
fi

out_dir="${INKLET_APP_STORE_OUTPUT_DIR:-${repo_root}/dist/app-store-release}"
app_name="${INKLET_APP_NAME:-Inklet}"
app_path="${out_dir}/${app_name}.app"
pkg_path="${out_dir}/${app_name}-${version}-${build_number}.pkg"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/inklet-app-store-release.XXXXXX")"

cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

profile_plist="${tmp_dir}/profile.plist"
entitlements="${tmp_dir}/entitlements.plist"
expanded_pkg="${tmp_dir}/expanded-pkg"

echo "Preparing ${app_name} ${version} (${build_number}) for Mac App Store..."

if [[ "$skip_tests" -eq 0 ]]; then
  echo "Running swift test..."
  swift test --package-path "$repo_root"
fi

rm -rf "$app_path"
rm -f "$pkg_path"
mkdir -p "$out_dir"

echo "Building app bundle..."
INKLET_SIGN_IDENTITY="${INKLET_APP_STORE_APP_SIGN_IDENTITY}" \
INKLET_VERSION="${version}" \
INKLET_BUILD_NUMBER="${build_number}" \
INKLET_OUTPUT_DIR="${out_dir}" \
"${repo_root}/scripts/build-app-store-spike.sh"

echo "Embedding provisioning profile..."
cp "${INKLET_APP_STORE_PROFILE}" "${app_path}/Contents/embedded.provisionprofile"
security cms -D -i "${INKLET_APP_STORE_PROFILE}" > "$profile_plist"

cp "${repo_root}/StoreSupport/Inklet.entitlements" "$entitlements"
/usr/libexec/PlistBuddy -c "Add :com.apple.application-identifier string $(/usr/libexec/PlistBuddy -c 'Print :Entitlements:com.apple.application-identifier' "$profile_plist")" "$entitlements"
/usr/libexec/PlistBuddy -c "Add :com.apple.developer.team-identifier string $(/usr/libexec/PlistBuddy -c 'Print :Entitlements:com.apple.developer.team-identifier' "$profile_plist")" "$entitlements"
/usr/libexec/PlistBuddy -c "Add :keychain-access-groups array" "$entitlements"
/usr/libexec/PlistBuddy -c "Add :keychain-access-groups:0 string $(/usr/libexec/PlistBuddy -c 'Print :Entitlements:keychain-access-groups:0' "$profile_plist")" "$entitlements"
plutil -lint "$entitlements" >/dev/null

echo "Re-signing app bundle with embedded profile entitlements..."
codesign --force \
  --sign "${INKLET_APP_STORE_APP_SIGN_IDENTITY}" \
  --entitlements "$entitlements" \
  --timestamp \
  "$app_path"

codesign --verify --strict --verbose=2 "$app_path"

echo "Removing extended attributes..."
xattr -cr "$app_path"

echo "Building signed installer package..."
productbuild \
  --component "$app_path" /Applications \
  --sign "${INKLET_APP_STORE_INSTALLER_SIGN_IDENTITY}" \
  "$pkg_path"

echo "Checking package signature..."
pkgutil --check-signature "$pkg_path"

echo "Checking package contents for quarantine attributes..."
pkgutil --expand-full "$pkg_path" "$expanded_pkg"
if xattr -lr "$expanded_pkg" | rg 'com\.apple\.quarantine' >/dev/null; then
  echo "Package contains com.apple.quarantine attributes. Remove them and rebuild." >&2
  exit 1
fi

if [[ "$skip_apple_validate" -eq 0 || "$upload" -eq 1 ]]; then
  echo "Validating with App Store Connect..."
  xcrun altool --validate-app "$pkg_path" -u "$ASC_EMAIL" -p @env:ASC_PASSWORD
fi

if [[ "$upload" -eq 1 ]]; then
  echo "Uploading to App Store Connect..."
  xcrun altool --upload-package "$pkg_path" -u "$ASC_EMAIL" -p @env:ASC_PASSWORD --wait
fi

echo "Done: ${pkg_path}"
