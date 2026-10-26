#!/usr/bin/env bash
set -euo pipefail

scope_name=""
remove_installed_app=0
keep_models=0
dry_run=0

usage() {
  cat <<'EOF'
Usage: scripts/reset-local-state.sh --scope local|production|all [options]

Reset the selected Inklet preferences, permissions, API keys (the local key
file and every provider's Keychain item), data directories, and temporary
selection diagnostics. A scope is always required.

Options:
  --scope local|production|all
                          Select the exact app state to reset.
  --remove-installed-app  Also delete the selected app from /Applications.
  --keep-models           Keep downloaded built-in models; remove everything else
                          in Application Support.
  --dry-run               Print the selected targets and commands without running them.
  -h, --help              Show this help.
EOF
}

fail_usage() {
  echo "$1" >&2
  usage >&2
  exit 1
}

print_command() {
  printf '+'
  printf ' %q' "$@"
  printf '\n'
}

run() {
  print_command "$@"
  if [[ "$dry_run" == "0" ]]; then
    "$@"
  fi
}

run_silently_allow_failure() {
  print_command "$@"
  if [[ "$dry_run" == "0" ]]; then
    "$@" >/dev/null 2>&1 || true
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope)
      if [[ $# -lt 2 ]]; then
        fail_usage "Missing value for --scope."
      fi
      if [[ -n "$scope_name" ]]; then
        fail_usage "Specify --scope exactly once."
      fi
      scope_name="$2"
      shift 2
      ;;
    --remove-installed-app)
      remove_installed_app=1
      shift
      ;;
    --keep-models)
      keep_models=1
      shift
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail_usage "Unknown argument: $1"
      ;;
  esac
done

if [[ -z "$scope_name" ]]; then
  fail_usage "Missing required --scope local|production|all."
fi
case "$scope_name" in
  local|production|all)
    ;;
  *)
    fail_usage "Unknown scope: ${scope_name}"
    ;;
esac

canonicalize_base_directory() {
  local label="$1"
  local candidate="$2"
  local canonical_path

  if [[ -z "$candidate" || "$candidate" != /* || "$candidate" == *$'\n'* ||
    ! -d "$candidate" ]]; then
    echo "${label} must be an existing absolute directory." >&2
    return 1
  fi
  if ! canonical_path="$(cd -P -- "$candidate" 2>/dev/null && pwd -P)"; then
    echo "${label} could not be resolved safely." >&2
    return 1
  fi
  if [[ -z "$canonical_path" || "$canonical_path" != /* || "$canonical_path" == "/" ||
    "$canonical_path" == *$'\n'* || "$canonical_path" == *//* ]]; then
    echo "${label} must resolve to a non-root absolute directory." >&2
    return 1
  fi
  case "/${canonical_path#/}/" in
    */./*|*/../*)
      echo "${label} could not be canonicalized safely." >&2
      return 1
      ;;
  esac

  printf '%s\n' "$canonical_path"
}

if ! home_directory="$(canonicalize_base_directory HOME "${HOME:-}")"; then
  exit 1
fi
if ! temporary_directory="$(canonicalize_base_directory TMPDIR "${TMPDIR:-/tmp}")"; then
  exit 1
fi
if ! applications_directory="$(canonicalize_base_directory Applications "/Applications")"; then
  exit 1
fi
if [[ "$applications_directory" != "/Applications" ]]; then
  echo "Applications must resolve to /Applications." >&2
  exit 1
fi

validate_exact_target() {
  local label="$1"
  local target="$2"
  local base_directory="$3"
  local expected_target="$4"

  if [[ -z "$target" || "$target" != /* || "$target" == "/" ||
    "$target" == "$base_directory" || "$target" != "${base_directory}/"* ||
    "$target" != "$expected_target" || "$target" == *$'\n'* || "$target" == *//* ]]; then
    echo "Unsafe ${label} reset target." >&2
    exit 1
  fi
  case "/${target#/}/" in
    */./*|*/../*)
      echo "Unsafe ${label} reset target." >&2
      exit 1
      ;;
  esac
}

validate_target_parent_chain() {
  local label="$1"
  local target="$2"
  local base_directory="$3"
  local target_parent
  local remaining_path
  local path_component
  local current_path

  if [[ -L "$base_directory" || ! -d "$base_directory" ]]; then
    echo "Unsafe ${label} reset target parent." >&2
    exit 1
  fi

  target_parent="${target%/*}"
  if [[ "$target_parent" == "$base_directory" ]]; then
    return
  fi
  if [[ "$target_parent" != "${base_directory}/"* ]]; then
    echo "Unsafe ${label} reset target parent." >&2
    exit 1
  fi

  remaining_path="${target_parent:$(( ${#base_directory} + 1 ))}"
  current_path="$base_directory"
  while [[ -n "$remaining_path" ]]; do
    path_component="${remaining_path%%/*}"
    if [[ "$remaining_path" == */* ]]; then
      remaining_path="${remaining_path#*/}"
    else
      remaining_path=""
    fi
    if [[ -z "$path_component" || "$path_component" == "." || "$path_component" == ".." ]]; then
      echo "Unsafe ${label} reset target parent." >&2
      exit 1
    fi

    current_path="${current_path}/${path_component}"
    if [[ -L "$current_path" || ( -e "$current_path" && ! -d "$current_path" ) ]]; then
      echo "Unsafe ${label} reset target parent." >&2
      exit 1
    fi
  done
}

bundle_ids=()
app_names=()
application_support_paths=()
legacy_container_paths=()
keychain_services=()
diagnostic_paths=()
installed_apps=()
preference_paths=()
# Every provider preset ID in Sources/InkletCore/LLMProviderPreset.swift, because API keys
# are stored per provider. test-reset-local-state.sh keeps this list in sync.
keychain_accounts=(
  openai custom-openai-compatible inklet-built-in ollama lm-studio anthropic gemini
  deepseek qwen moonshot zhipu minimax siliconflow volcengine tencent-hunyuan baichuan
  lingyiwanwu xai groq mistral openrouter perplexity together cerebras
)

append_scope() {
  local selected_scope="$1"
  local bundle_id
  local app_name
  local keychain_service
  local installed_app
  local application_support_path
  local legacy_container_path
  local preference_path
  local diagnostic_path

  case "$selected_scope" in
    local)
      bundle_id="com.tomwan.inklet.local"
      app_name="Inklet Local"
      keychain_service="Inklet.Local.ProviderAPIKey"
      installed_app="${applications_directory}/Inklet Local.app"
      ;;
    production)
      bundle_id="com.tomwan.inklet"
      app_name="Inklet"
      keychain_service="Inklet.ProviderAPIKey"
      installed_app="${applications_directory}/Inklet.app"
      ;;
  esac

  application_support_path="${home_directory}/Library/Application Support/${bundle_id}"
  legacy_container_path="${home_directory}/Library/Containers/${bundle_id}"
  preference_path="${home_directory}/Library/Preferences/${bundle_id}"
  diagnostic_path="${temporary_directory}/InkletSelectionActions.${bundle_id}.log"

  validate_exact_target \
    "Application Support" \
    "$application_support_path" \
    "$home_directory" \
    "${home_directory}/Library/Application Support/${bundle_id}"
  validate_exact_target \
    "legacy container" \
    "$legacy_container_path" \
    "$home_directory" \
    "${home_directory}/Library/Containers/${bundle_id}"
  validate_exact_target \
    "diagnostics" \
    "$diagnostic_path" \
    "$temporary_directory" \
    "${temporary_directory}/InkletSelectionActions.${bundle_id}.log"
  validate_exact_target \
    "installed app" \
    "$installed_app" \
    "/Applications" \
    "$installed_app"

  validate_target_parent_chain \
    "Application Support" \
    "$application_support_path" \
    "$home_directory"
  validate_target_parent_chain \
    "legacy container" \
    "$legacy_container_path" \
    "$home_directory"
  validate_target_parent_chain \
    "diagnostics" \
    "$diagnostic_path" \
    "$temporary_directory"
  validate_target_parent_chain \
    "installed app" \
    "$installed_app" \
    "$applications_directory"

  bundle_ids+=("$bundle_id")
  app_names+=("$app_name")
  application_support_paths+=("$application_support_path")
  legacy_container_paths+=("$legacy_container_path")
  preference_paths+=("$preference_path")
  keychain_services+=("$keychain_service")
  diagnostic_paths+=("$diagnostic_path")
  installed_apps+=("$installed_app")
}

remove_application_support_except_models() {
  local application_support_path="$1"
  local entry

  if [[ -L "$application_support_path" || ! -d "$application_support_path" ]]; then
    return
  fi
  shopt -s dotglob nullglob
  for entry in "${application_support_path}"/*; do
    if [[ "${entry##*/}" == "Models" ]]; then
      continue
    fi
    run rm -rf "$entry"
  done
  shopt -u dotglob nullglob
}

case "$scope_name" in
  local)
    append_scope local
    ;;
  production)
    append_scope production
    ;;
  all)
    append_scope local
    append_scope production
    ;;
esac

echo "Selected destructive reset scope: ${scope_name}"
for target_index in "${!bundle_ids[@]}"; do
  echo "Target:"
  echo "  Bundle ID: ${bundle_ids[$target_index]}"
  echo "  Application Support: ${application_support_paths[$target_index]}"
  echo "  Legacy container: ${legacy_container_paths[$target_index]}"
  echo "  Preferences: ${preference_paths[$target_index]}"
  echo "  Keychain service: ${keychain_services[$target_index]}"
  echo "  Diagnostics: ${diagnostic_paths[$target_index]}"
  echo "  Installed app: ${installed_apps[$target_index]}"
done
if [[ "$keep_models" == "1" ]]; then
  echo "Built-in models: kept"
else
  echo "Built-in models: removed"
fi
if [[ "$remove_installed_app" == "1" ]]; then
  echo "Installed app removal: requested"
else
  echo "Installed app removal: not requested"
fi

# Completion markers of LegacySandboxDataMigrator (LegacyMigrationVersions are all 1).
legacy_migration_keys=(
  "Inklet.LegacySandboxMigration.preferencesVersion"
  "Inklet.LegacySandboxMigration.credentialsVersion"
  "Inklet.LegacySandboxMigration.historyVersion"
)

for target_index in "${!bundle_ids[@]}"; do
  bundle_id="${bundle_ids[$target_index]}"
  app_name="${app_names[$target_index]}"

  run_silently_allow_failure osascript -e "tell application \"${app_name}\" to quit"
  run_silently_allow_failure pkill -x "$app_name"
  run_silently_allow_failure defaults delete "$bundle_id"
  # When a legacy sandbox container exists, the bundle ID can resolve to the container's
  # preferences, so also delete the unsandboxed plist by path.
  run_silently_allow_failure defaults delete "${preference_paths[$target_index]}"
  run_silently_allow_failure tccutil reset Accessibility "$bundle_id"
  run_silently_allow_failure tccutil reset Microphone "$bundle_id"
  for keychain_account in "${keychain_accounts[@]}"; do
    run_silently_allow_failure \
      security delete-generic-password \
      -s "${keychain_services[$target_index]}" \
      -a "$keychain_account"
  done
  if [[ "$keep_models" == "1" ]]; then
    remove_application_support_except_models "${application_support_paths[$target_index]}"
  else
    run rm -rf "${application_support_paths[$target_index]}"
  fi
  run_silently_allow_failure rm -rf "${legacy_container_paths[$target_index]}"
  # macOS can protect an old sandbox container from deletion. Mark its data as already imported,
  # so the next launch starts like a new install instead of bringing the old settings back.
  if [[ "$dry_run" == "0" && -e "${legacy_container_paths[$target_index]}" ]]; then
    echo "Legacy container is protected by macOS; kept and marked as already imported."
    for migration_key in "${legacy_migration_keys[@]}"; do
      run defaults write "${preference_paths[$target_index]}" "$migration_key" -int 1
    done
  fi
  run rm -f "${diagnostic_paths[$target_index]}"

  if [[ "$remove_installed_app" == "1" ]]; then
    if [[ -w "/Applications" ]]; then
      run rm -rf "${installed_apps[$target_index]}"
    else
      run sudo rm -rf "${installed_apps[$target_index]}"
    fi
  fi
done

echo "Inklet ${scope_name} state reset."
