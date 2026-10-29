#!/usr/bin/env bash
# Usage: guard-edit.sh < payload.json
#
# PreToolUse hook for Edit and Write. Denies a write to a secret file or to
# anything under .git/; allows everything else. The payload arrives on stdin.
#
# Denied (matched case-insensitively): any path with a .git component; the
# basenames .env and .env.* (except .env.example, .env.sample and
# .env.template), *.pem, *.key, *.p12, *.pfx, id_rsa*, id_ed25519*,
# id_ecdsa*, .netrc, .npmrc, .pgpass and auth.json. A secret-file deny is
# lifted when guard.allow_paths in .aew/config.json lists the path relative to
# the top level of the checkout holding it (the main one or a run worktree);
# matching is exact and case-sensitive, and an unreadable config lifts
# nothing. Git internals are never allowed.
#
# Output: a deny decision as JSON on stdout (exit 0), or nothing to allow.
# The hook never exits 2 and fails open on any error.
# Options: -h, --help

# shellcheck source=../lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
# shellcheck source=../lib/hooks.sh
. "$(dirname "${BASH_SOURCE[0]}")/../lib/hooks.sh"
hook_init "$@"

# allowed <absolute path>: true when guard.allow_paths lists the path. A new
# file's missing directories are walked up to the nearest existing one, which
# is made physical so a symlinked parent (macOS /var) still matches.
allowed() {
  local d=${1%/*} rest=${1##*/} top rel
  while [ -n "$d" ] && [ ! -d "$d" ]; do
    rest="${d##*/}/$rest"
    d=${d%/*}
  done
  d=$(cd "${d:-/}" && pwd -P) || return 1
  top=$(git -C "$d" rev-parse --show-toplevel 2> /dev/null) || return 1
  top=$(cd "$top" && pwd -P) || return 1
  case "$d/" in
    "$top/") rel=$rest ;;
    "$top"/*) rel=${d#"$top"/}/$rest ;;
    *) return 1 ;;
  esac
  jq -e --arg p "$rel" '(.guard.allow_paths // []) | any(.[]; . == $p)' .aew/config.json > /dev/null 2>&1
}

p=$(hook_field .tool_input.file_path) || exit 0
[ -n "$p" ] || exit 0

# file_path is absolute; a relative one is resolved against the payload cwd.
case "$p" in
  /*) ;;
  *) p="$HOOK_CWD/$p" ;;
esac

shopt -s nocasematch

rule=""
case "/$p/" in
  */.git/*) rule="git internals" ;;
esac

if [ -z "$rule" ]; then
  b=${p##*/}
  case "$b" in
    .env.example | .env.sample | .env.template) ;;
    .env | .env.*) rule="env file" ;;
    *.pem | *.key | *.p12 | *.pfx) rule="key or certificate file" ;;
    id_rsa* | id_ed25519* | id_ecdsa*) rule="ssh key" ;;
    .netrc | .npmrc | .pgpass | auth.json) rule="credentials file" ;;
  esac
fi

[ -n "$rule" ] || exit 0

if [ "$rule" = "git internals" ]; then
  reason="aew guard: blocked a write to $p (git internals). aew never edits git internals."
else
  shopt -u nocasematch
  if allowed "$p"; then exit 0; fi
  reason="aew guard: blocked a write to $p ($rule). aew never edits secret files. If this file is committed and holds no secrets, the project owner can list its repo-relative path in guard.allow_paths in .aew/config.json; otherwise ask the owner to create it."
fi
jq -n --arg r "$reason" \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}' || exit 0
exit 0
