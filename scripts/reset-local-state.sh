#!/usr/bin/env bash
set -euo pipefail

remove_installed_app=0
dry_run=0

usage() {
  cat <<'EOF'
Usage: scripts/reset-local-state.sh [--remove-installed-app] [--dry-run]

Reset Inklet preferences, permissions, legacy Keychain API keys, and temporary
voice recordings. By default, the installed /Applications/Inklet.app is kept.

Options:
  --remove-installed-app  Also delete /Applications/Inklet.app.
  --dry-run               Print commands without running them.
  -h, --help              Show this help.
EOF
}

run() {
  printf '+'
  printf ' %q' "$@"
  printf '\n'
  if [[ "$dry_run" == "0" ]]; then
    "$@"
  fi
}

run_if_present() {
  if [[ "$dry_run" == "1" ]] || "$@" >/dev/null 2>&1; then
    run "$@"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --remove-installed-app)
      remove_installed_app=1
      ;;
    --dry-run)
      dry_run=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

bundle_ids=(
  "com.tomwan.inklet"
  "com.inklet.app"
)

keychain_services=(
  "Inklet.OpenAI"
  "Inklet.CustomOpenAICompatible"
  "Inklet.Anthropic"
  "Inklet.Gemini"
  "Inklet.DeepSeek"
  "Inklet.Qwen"
  "Inklet.Moonshot"
  "Inklet.Zhipu"
  "Inklet.MiniMax"
  "Inklet.SiliconFlow"
  "Inklet.Volcengine"
  "Inklet.TencentHunyuan"
  "Inklet.Baichuan"
  "Inklet.Lingyiwanwu"
  "Inklet.xAI"
  "Inklet.Groq"
  "Inklet.Mistral"
  "Inklet.OpenRouter"
  "Inklet.Perplexity"
  "Inklet.Together"
  "Inklet.Cerebras"
)

echo "Resetting Inklet local state..."

run osascript -e 'tell application "Inklet" to quit' || true
run pkill -x Inklet || true

for bundle_id in "${bundle_ids[@]}"; do
  run defaults delete "$bundle_id" || true
  run tccutil reset Accessibility "$bundle_id" || true
  run tccutil reset Microphone "$bundle_id" || true
done

for service in "${keychain_services[@]}"; do
  run_if_present security delete-generic-password -s "$service"
done

tmp_dir="${TMPDIR:-/tmp}"
if [[ "$dry_run" == "1" ]]; then
  echo "+ find ${tmp_dir} -maxdepth 1 -name 'inklet-voice-*.m4a' -delete"
else
  find "$tmp_dir" -maxdepth 1 -name 'inklet-voice-*.m4a' -delete
fi

if [[ "$remove_installed_app" == "1" && -d "/Applications/Inklet.app" ]]; then
  run sudo rm -rf "/Applications/Inklet.app"
fi

echo "Inklet local state reset."
