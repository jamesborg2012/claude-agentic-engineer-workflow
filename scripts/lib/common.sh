#!/usr/bin/env bash
# Usage: . scripts/lib/common.sh
#
# Shared library for the aew scripts and hooks. Source it; do not run it.
# Sourcing enables strict mode and defines functions only: no output, no
# git or jq calls, no traps.
#
# Functions:
#   info <msg...>            stderr: "<script>: <msg>"
#   warn <msg...>            stderr: "<script>: warning: <msg>"
#   die <msg...>             stderr: "<script>: error: <msg>", then exit 1
#   require_cmd <cmd>...     die naming the first command missing from PATH
#   plugin_root              plugin root ($CLAUDE_PLUGIN_ROOT, else from this file)
#   repo_root [dir]          main worktree root of the git repo containing dir
#   config_get <dotted.path> value from .aew/config.json, else the schema default
#   is_run_id <s>            success if s is a valid run id (N or m-N)
#   run_dir [run-id]         .aew/runs/<id> (default: the current run)
#   print_usage <file>       print the file's "Usage:" header block (for --help)
#   lib_main <file> [arg...] entry point for libraries that are executed directly
#
# bash 3.2 does not apply set -e inside $(...) or in functions called from a
# condition, so every function checks its own failures explicitly.

set -euo pipefail

# shellcheck disable=SC2034  # read by plugin_root; set once so a later cd cannot break it
_AEW_COMMON_LOADED=1
_AEW_COMMON_PATH=${BASH_SOURCE[0]}
case "$_AEW_COMMON_PATH" in
  /*) ;;
  *) _AEW_COMMON_PATH=$PWD/$_AEW_COMMON_PATH ;;
esac

info() { printf '%s: %s\n' "${0##*/}" "$*" >&2; }

warn() { printf '%s: warning: %s\n' "${0##*/}" "$*" >&2; }

die() {
  printf '%s: error: %s\n' "${0##*/}" "$*" >&2
  exit 1
}

require_cmd() {
  local c
  for c in "$@"; do
    command -v "$c" > /dev/null 2>&1 || die "required command not found: $c"
  done
  return 0
}

plugin_root() {
  if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
    local r=$CLAUDE_PLUGIN_ROOT
    while [ "${#r}" -gt 1 ] && [ "${r%/}" != "$r" ]; do r=${r%/}; done
    printf '%s\n' "$r"
    return 0
  fi
  local d=${_AEW_COMMON_PATH%/*}
  (cd "$d/../.." && pwd -P) || die "cannot resolve plugin root from $_AEW_COMMON_PATH"
}

repo_root() {
  local d=${1:-$PWD} gc top
  gc=$(git -C "$d" rev-parse --path-format=absolute --git-common-dir 2> /dev/null) || die "not inside a git repository: $d"
  if [ "${gc##*/}" = ".git" ]; then
    (cd "${gc%/*}" && pwd -P) || die "cannot resolve repository root: $gc"
  else
    top=$(git -C "$d" rev-parse --show-toplevel 2> /dev/null) || die "not inside a git repository: $d"
    (cd "$top" && pwd -P) || die "cannot resolve repository root: $top"
  fi
}

config_get() {
  local path=${1:-} re='^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*$'
  [[ $path =~ $re ]] || die "config: invalid path '$path'"
  local root schema cfg rc=0 out
  root=$(repo_root) || return 1
  schema="$(plugin_root)/templates/config.schema.json" || return 1
  [ -f "$schema" ] || die "config: schema not found: $schema"
  cfg=$root/.aew/config.json
  [ -f "$cfg" ] || cfg=/dev/null
  out=$(jq -r -n --slurpfile cfg "$cfg" --slurpfile sch "$schema" --arg p "$path" '
    ($p | split(".")) as $k
    | ($k | length) as $n
    | (try ($cfg[0] | getpath($k)) catch null) as $v
    | (if $v != null then [$v]
       else [range($n; 0; -1) as $i
             | (try ($sch[0] | getpath([$k[:$i][] | ("properties", .)] + ["default"]) | getpath($k[$i:])) catch null)
             | select(. != null)]
       end) as $found
    | if ($found | length) == 0 then halt_error(3)
      else $found[0] | if type == "string" then . else tojson end
      end' 2> /dev/null) || rc=$?
  case "$rc" in
    0) printf '%s\n' "$out" ;;
    3) die "config: no value or default for '$path'" ;;
    *) die "config: invalid JSON in $cfg" ;;
  esac
}

is_run_id() {
  local re='^([1-9][0-9]*|m-[1-9][0-9]*)$'
  [[ ${1:-} =~ $re ]]
}

run_dir() {
  local id=${1:-} root line cur
  root=$(repo_root) || return 1
  if [ -z "$id" ]; then
    cur=$root/.aew/runs/current
    [ -f "$cur" ] || die "no current run (.aew/runs/current not set)"
    line=""
    IFS= read -r line < "$cur" || [ -n "$line" ] || true
    while [ -n "$line" ]; do
      case "$line" in
        *[[:space:]]) line=${line%?} ;;
        *) break ;;
      esac
    done
    [ -n "$line" ] || die "no current run (.aew/runs/current not set)"
    id=$line
  fi
  is_run_id "$id" || die "invalid run id: $id"
  printf '%s\n' "$root/.aew/runs/$id"
}

print_usage() {
  local line first=1
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$first" -eq 1 ]; then
      first=0
      continue
    fi
    case "$line" in
      "#") printf '\n' ;;
      "# "*) printf '%s\n' "${line#\# }" ;;
      *) break ;;
    esac
  done < "$1"
}

lib_main() {
  local file=$1
  case "${2:-}" in
    -h | --help)
      print_usage "$file"
      exit 0
      ;;
  esac
  die "${file##*/} is a library: source it, don't run it"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then lib_main "$0" "$@"; fi
