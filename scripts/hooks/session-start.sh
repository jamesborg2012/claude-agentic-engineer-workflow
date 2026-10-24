#!/usr/bin/env bash
# Usage: session-start.sh < payload.json
#
# SessionStart hook. When an aew run is in progress (.aew/runs/current points
# at a run that is not done), adds one line of context so the session can
# offer /aew:resume. Silent otherwise. Fires for every source (startup,
# resume, clear, compact, fork), so it does not read the payload's source.
# Never blocks: every path exits 0.
# Options: -h, --help

# shellcheck source=../lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
# shellcheck source=../lib/hooks.sh
. "$(dirname "${BASH_SOURCE[0]}")/../lib/hooks.sh"
hook_init "$@"

root=$HOOK_ROOT
[ -f "$root/.aew/runs/current" ] || exit 0
rd=$(run_dir) || exit 0
[ -f "$rd/state.json" ] || { warn "no state.json for the current run; skipping the hint"; exit 0; }

st=$(jq -r '[.run_id, .stage, .status] | map(tostring) | @tsv' "$rd/state.json" 2> /dev/null) || { warn "unreadable state.json; skipping the hint"; exit 0; }
[ -n "$st" ] || { warn "empty state.json; skipping the hint"; exit 0; }
IFS=$'\t' read -r id stage status <<<"$st" || exit 0
[ "$status" != "done" ] || exit 0

jq -n --arg c "Active aew run $id at stage $stage ($status). Use /aew:resume." \
  '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $c}}'
