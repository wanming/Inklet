#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -w "/Applications" ]]; then
  echo "Administrator access is required to replace /Applications/Inklet.app."
  sudo -v
fi

echo "Resetting local Inklet state and removing the installed app..."
"${repo_root}/scripts/reset-local-state.sh" --remove-installed-app

echo
echo "Building, installing, and opening a fresh sandbox app..."
"${repo_root}/scripts/rebuild-sandbox-app.sh"
