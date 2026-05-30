#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "scripts/build-app-store-spike.sh is kept for compatibility."
echo "Use scripts/build-macos-app-bundle.sh for new workflows."

exec "${repo_root}/scripts/build-macos-app-bundle.sh" "$@"
