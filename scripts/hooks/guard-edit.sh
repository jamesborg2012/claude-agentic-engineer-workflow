#!/usr/bin/env bash
# Usage: guard-edit.sh < payload.json
#
# PreToolUse hook for Edit and Write. Denies a write to a secret file or to
# anything under .git/; allows everything else. The payload arrives on stdin.
#
# Denied (matched case-insensitively): any path with a .git component; the
# basenames .env and .env.* (except .env.example, .env.sample and
# .env.template), *.pem, *.key, *.p12, *.pfx, id_rsa*, id_ed25519*,
# id_ecdsa*, .netrc, .npmrc, .pgpass and auth.json.
#
# Output: a deny decision as JSON on stdout (exit 0), or nothing to allow.
# The hook never exits 2 and fails open on any error.
# Options: -h, --help

# shellcheck source=../lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
# shellcheck source=../lib/hooks.sh
. "$(dirname "${BASH_SOURCE[0]}")/../lib/hooks.sh"
hook_init "$@"

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

reason="aew guard: blocked a write to $p ($rule). Secrets and git internals are never edited by aew; ask James."
jq -n --arg r "$reason" \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}' || exit 0
exit 0
