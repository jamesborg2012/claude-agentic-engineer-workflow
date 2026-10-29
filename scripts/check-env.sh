#!/usr/bin/env bash
# Usage: check-env.sh <05-plan.md>
#
# Check that the environment has what the plan's work needs, before the plan
# gate and again when develop starts. Run it from the project. No gh, no run
# state, no network; it writes nothing.
#
# Reads two things from the plan (HTML comments are ignored):
#   - the "## Environment" section, one requirement per line:
#       - tool: <command> [<major>]   on PATH; with <major>, the first number
#                                     of `<command> --version` must equal it
#       - service: docker             the Docker daemon answers `docker info`
#     "None." and blank lines are skipped. Any other line fails as unreadable,
#     and a command name that is not a plain word is never run. A plan with no
#     Environment section has nothing to check there.
#   - every "Owner hand-off: <path>:" line (backticks around the path are
#     allowed): the file must exist in the project, or guard.allow_paths in
#     .aew/config.json must list it, because the edit guard refuses it.
#
# Every problem prints one "FAIL: <reason>" line on stdout.
#
# Options: -h, --help
#
# Exit status: 0 every check passed; 1 a check failed (or no argument /
# unknown option, as for every aew script); 2 unreadable plan (message on
# stderr).

# shellcheck source=lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

case "${1:-}" in
  -h | --help)
    print_usage "${BASH_SOURCE[0]}"
    exit 0
    ;;
  -*) die "unknown option: $1" ;;
  "") die "missing argument: <05-plan.md>" ;;
esac
[ $# -eq 1 ] || die "unexpected argument: $2"

require_cmd awk jq git

PLAN=$1
if [ ! -f "$PLAN" ] || [ ! -r "$PLAN" ]; then
  printf '%s: error: cannot read %s\n' "${0##*/}" "$PLAN" >&2
  exit 2
fi

ROOT=$(repo_root)
FAILED=0

fail() {
  printf 'FAIL: %s\n' "$*"
  FAILED=1
}

# The plan with HTML comments removed, including comments over several lines.
TEXT=$(awk '{
  line = $0; out = ""
  while (1) {
    if (inc) { i = index(line, "-->"); if (!i) { line = ""; break }; line = substr(line, i + 3); inc = 0 }
    i = index(line, "<!--"); if (!i) { out = out line; break }
    out = out substr(line, 1, i - 1); line = substr(line, i + 4); inc = 1
  }
  print out
}' "$PLAN")

# check_tool <command> [<major>]
check_tool() {
  local name=$1 want=${2:-} ver
  if ! command -v "$name" > /dev/null 2>&1; then
    fail "tool $name is not on PATH"
    return 0
  fi
  [ -n "$want" ] || return 0
  ver=$("$name" --version 2> /dev/null | head -n 1) || ver=""
  if [[ $ver =~ ([0-9]+) ]]; then
    [ "${BASH_REMATCH[1]}" = "$want" ] || fail "tool $name is version ${BASH_REMATCH[1]}, the plan needs $want"
  else
    fail "tool $name printed no version, the plan needs $want"
  fi
  return 0
}

check_docker() {
  if ! command -v docker > /dev/null 2>&1; then
    fail "service docker: docker is not on PATH"
  elif ! docker info > /dev/null 2>&1; then
    fail "service docker is not answering: start Docker (Docker Desktop, OrbStack or colima)"
  fi
  return 0
}

tool_re='^- tool: ([A-Za-z0-9][A-Za-z0-9._+-]*)( ([0-9]+))?$'
while IFS= read -r line; do
  line=$(printf '%s' "$line" | sed -E 's/[[:space:]]+$//')
  case "$line" in
    "" | "None.") continue ;;
    "- service: docker")
      check_docker
      continue
      ;;
  esac
  if [[ $line =~ $tool_re ]]; then
    check_tool "${BASH_REMATCH[1]}" "${BASH_REMATCH[3]}"
  else
    fail "unreadable environment line: $line"
  fi
done < <(awk '/^## Environment[[:space:]]*$/{f=1; next} /^## /{f=0} f' <<< "$TEXT")

# shellcheck disable=SC2016  # the backticks are literal: a path may be quoted as code
handoff_re='Owner hand-off:[[:space:]]+`?([^`:[:space:]]+)`?:'
while IFS= read -r line; do
  [[ $line =~ $handoff_re ]] || continue
  p=${BASH_REMATCH[1]}
  [ -e "$ROOT/$p" ] && continue
  jq -e --arg p "$p" '(.guard.allow_paths // []) | any(.[]; . == $p)' "$ROOT/.aew/config.json" > /dev/null 2>&1 && continue
  fail "owner hand-off $p does not exist and aew may not write it: create it, or list it in guard.allow_paths in .aew/config.json"
done <<< "$TEXT"

exit "$FAILED"
