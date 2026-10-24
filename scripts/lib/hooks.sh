#!/usr/bin/env bash
# Usage: . scripts/lib/hooks.sh
#
# Shared preamble for the aew hook scripts. Source it after common.sh; do not
# run it. Sourcing defines functions only: no output, no traps.
#
# Every hook script calls `hook_init "$@"` first. It handles --help, then
# installs a fail-open EXIT trap, then reads and validates the payload and
# resolves the project. After hook_init every failure exits 0 (a hook must
# never block by accident), and a hook is silent outside an aew project.
#
# Functions:
#   hook_init [arg...]   argument handling, fail-open trap, payload, project
#   hook_field <path>    a raw string from the payload ("" when absent or null)
#
# Globals set by hook_init: HOOK_PAYLOAD, HOOK_CWD (where the tool runs; may be
# a linked worktree), HOOK_ROOT (main worktree root), HOOK_STOP_ACTIVE.
#
# bash 3.2 does not apply set -e inside functions called from a condition, so
# callers check failures explicitly (x=$(fn) || exit 0) and never write
# `local x=$(...)`.

# shellcheck source=common.sh
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

HOOK_PAYLOAD=""
HOOK_CWD=""
HOOK_ROOT=""
HOOK_STOP_ACTIVE=""

# EXIT trap: whatever happened after hook_init started, allow the action.
_hook_exit() {
  local s=$?
  trap - EXIT
  if [ "$s" -ne 0 ]; then warn "unexpected error (status $s); failing open"; fi
  exit 0
}

hook_init() {
  # 1. Arguments come before the trap so that a bad argument still exits 1.
  case "${1:-}" in
    -h | --help)
      print_usage "$0"
      exit 0
      ;;
    "") ;;
    *) die "unexpected argument: $1 (hooks take their payload on stdin)" ;;
  esac

  # 2. From here on every path exits 0.
  trap _hook_exit EXIT

  # 3. No jq, no hook.
  if ! command -v jq > /dev/null 2>&1; then
    warn "jq not found; aew hooks are disabled"
    exit 0
  fi

  # 4. Payload. jq exits 0 on empty input, so reject that explicitly. The
  # never-empty field goes first: tab is IFS whitespace and would collapse a
  # leading empty field.
  local parsed
  HOOK_PAYLOAD=$(cat) || HOOK_PAYLOAD=""
  if [ -z "$HOOK_PAYLOAD" ] ||
    ! parsed=$(jq -r '[(.stop_hook_active == true | tostring), (.cwd // "" | tostring)] | @tsv' <<<"$HOOK_PAYLOAD" 2> /dev/null); then
    warn "unreadable hook payload; failing open"
    exit 0
  fi
  IFS=$'\t' read -r HOOK_STOP_ACTIVE HOOK_CWD <<<"$parsed" || true

  # 5. A stop already blocked once must not be blocked again.
  if [ "$HOOK_STOP_ACTIVE" = "true" ]; then
    warn "stop_hook_active is set; allowing the stop"
    exit 0
  fi

  # 6. Project: CLAUDE_PROJECT_DIR, else the payload cwd, else $PWD. Not a git
  # repo means not an aew project, so stay silent.
  local dir=${CLAUDE_PROJECT_DIR:-${HOOK_CWD:-$PWD}}
  HOOK_ROOT=$(repo_root "$dir" 2> /dev/null) || exit 0

  # 7. Only repos with .aew/config.json are active.
  if [ ! -f "$HOOK_ROOT/.aew/config.json" ]; then
    if [ -d "$HOOK_ROOT/.aew" ]; then
      warn ".aew/config.json is missing; aew hooks are disabled (run /aew:init)"
    fi
    exit 0
  fi

  # 8. So config_get and run_dir resolve against the project.
  cd "$HOOK_ROOT" || exit 0
  HOOK_CWD=${HOOK_CWD:-$dir}
  return 0
}

hook_field() {
  jq -r "$1 // empty" <<<"$HOOK_PAYLOAD"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then lib_main "$0" "$@"; fi
