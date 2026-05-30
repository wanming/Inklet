#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
install_script="${script_dir}/install.sh"

if grep -q 'continuing without checksum verification' "$install_script"; then
  echo "install.sh must not continue when checksum verification is unavailable." >&2
  exit 1
fi

if ! grep -q 'Could not download checksum asset' "$install_script"; then
  echo "install.sh must fail explicitly when the checksum asset cannot be downloaded." >&2
  exit 1
fi

if grep -Eq 'xattr .*com\.apple\.quarantine' "$install_script"; then
  echo "install.sh must preserve the downloaded app quarantine attribute." >&2
  exit 1
fi

echo "install.sh security checks passed."
