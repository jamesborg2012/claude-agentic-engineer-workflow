#!/usr/bin/env bash
# Usage: gate-subagent.sh < payload.json
#
# SubagentStop gate for aew:developer and aew:qa-engineer. Reads the hook
# payload on stdin. When the subagent stops without a valid artefact it prints
# {"decision":"block","reason":...} and exits 0, so the subagent gets one
# corrective turn (a second stop has stop_hook_active set and is allowed).
#
#   developer   newest 06-dev-report*.md exists, is not older than state.json,
#               ends with a valid return block, and (STATUS ok only) has a
#               filled-in row in its "## Commands run" table.
#   qa-engineer 04-qa-test-plan.md (stage plan or qa_test_plan) or
#               08-qa-report-<fix_cycle + 1>.md (stage qa) exists and ends with
#               a valid return block.
#
# Every other agent, stage or failure allows the stop (exit 0, no output).
# Options: -h, --help
# shellcheck source=../lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
# shellcheck source=../lib/hooks.sh
. "$(dirname "${BASH_SOURCE[0]}")/../lib/hooks.sh"
hook_init "$@"

RUN_ID=""

# block <reason> <template-name>: print the block decision and stop (exit 0).
block() {
  local root msg
  root=$(plugin_root) || root="<plugin_root>"
  msg="aew gate: $1 Use the template at $root/templates/artefacts/$2.md and end the file with the return block (STATUS, ARTEFACTS, SUMMARY, NEXT)."
  jq -n --arg r "$msg" '{decision: "block", reason: $r}' || exit 0
  exit 0
}

# valid_return_block <file>: the last four non-blank lines must be STATUS,
# ARTEFACTS, SUMMARY, NEXT in that order. Prints the status value on success,
# or a one-line reason on failure (returns 1).
valid_return_block() {
  local last l1 l2 l3 l4 n
  local re_status='^STATUS:[[:space:]]*(ok|needs_input|blocked|failed)[[:space:]]*$'
  local re_status_any='^STATUS:'
  local re_artefacts='^ARTEFACTS:[[:space:]]*[^[:space:]]'
  local re_summary='^SUMMARY:[[:space:]]*[^[:space:]]'
  local re_next='^NEXT:[[:space:]]*[^[:space:]]'
  local shape="last 4 non-blank lines are not STATUS/ARTEFACTS/SUMMARY/NEXT"
  last=$(awk '{ sub(/\r$/, "") } /[^[:space:]]/ { a[++n] = $0 } END { for (i = (n > 3 ? n - 3 : 1); i <= n; i++) print a[i] }' "$1") || last=""
  n=0
  if [ -n "$last" ]; then n=$(printf '%s\n' "$last" | grep -c '') || n=0; fi
  if [ "$n" -ne 4 ]; then
    echo "$shape"
    return 1
  fi
  { IFS= read -r l1; IFS= read -r l2; IFS= read -r l3; IFS= read -r l4; } <<<"$last" || true
  if ! [[ $l1 =~ $re_status_any ]] || ! [[ $l2 =~ ^ARTEFACTS: ]] || ! [[ $l3 =~ ^SUMMARY: ]] || ! [[ $l4 =~ ^NEXT: ]]; then
    echo "$shape"
    return 1
  fi
  if ! [[ $l1 =~ $re_status ]]; then
    echo "STATUS must be one of ok, needs_input, blocked, failed"
    return 1
  fi
  if ! [[ $l2 =~ $re_artefacts ]] || ! [[ $l3 =~ $re_summary ]] || ! [[ $l4 =~ $re_next ]]; then
    echo "ARTEFACTS, SUMMARY and NEXT must each have a value"
    return 1
  fi
  l1=${l1#STATUS:}
  l1=${l1//[[:space:]]/}
  echo "$l1"
}

# commands_filled <file>: true when "## Commands run" has a table row whose
# command and result are both filled in (not empty, not a <placeholder>).
commands_filled() {
  awk '
    function trim(s) { gsub(/^[ \t\r]+|[ \t\r]+$/, "", s); return s }
    /^## Commands run/ { inside = 1; next }
    /^## / { inside = 0 }
    inside && /^\|/ {
      if ($0 ~ /^\|[-: |]+\|[ \t\r]*$/) next
      n = split($0, c, "|")
      a = trim(c[2]); b = trim(c[3])
      if (a == "Command") next
      if (a != "" && b != "" && a !~ /^<.*>$/ && b !~ /^<.*>$/) found = 1
    }
    END { exit found ? 0 : 1 }
  ' "$1"
}

gate_developer() {
  local rd=$1 f newest="" out status
  for f in "$rd"/06-dev-report*.md; do
    [ -f "$f" ] || continue
    if [ -z "$newest" ] || [ "$f" -nt "$newest" ]; then newest=$f; fi
  done
  if [ -z "$newest" ]; then
    block "no 06-dev-report*.md in .aew/runs/$RUN_ID/." dev-report
  fi
  if [ "$rd/state.json" -nt "$newest" ]; then
    block ".aew/runs/$RUN_ID/${newest##*/} predates the current run state (an earlier cycle); write this cycle's report." dev-report
  fi
  if out=$(valid_return_block "$newest"); then
    status=$out
  else
    block ".aew/runs/$RUN_ID/${newest##*/}: $out." dev-report
  fi
  if [ "$status" = "ok" ] && ! commands_filled "$newest"; then
    block ".aew/runs/$RUN_ID/${newest##*/}: STATUS ok but the ## Commands run table has no filled-in row (command and result)." dev-report
  fi
  return 0
}

gate_qa() {
  local rd=$1 stage=$2 cycle=$3 name tpl out
  case "$stage" in
    plan | qa_test_plan)
      name=04-qa-test-plan.md
      tpl=qa-test-plan
      ;;
    qa)
      name=08-qa-report-$((cycle + 1)).md
      tpl=qa-report
      ;;
    *)
      warn "qa-engineer stopped at stage $stage; not gating"
      exit 0
      ;;
  esac
  if [ ! -f "$rd/$name" ]; then
    block ".aew/runs/$RUN_ID/$name is missing." "$tpl"
  fi
  if ! out=$(valid_return_block "$rd/$name"); then
    block ".aew/runs/$RUN_ID/$name: $out." "$tpl"
  fi
  return 0
}

agent=$(hook_field .agent_type) || exit 0
case "$agent" in
  aew:developer | aew:qa-engineer) ;;
  *) exit 0 ;;
esac

if [ ! -f "$HOOK_ROOT/.aew/runs/current" ]; then
  warn "no current aew run; not gating"
  exit 0
fi
rd=$(run_dir) || exit 0
RUN_ID=${rd##*/}
if [ ! -f "$rd/state.json" ]; then
  warn "state file missing; not gating"
  exit 0
fi
# fix_cycle goes first: it is never empty, and a leading empty field would collapse.
st=$(jq -r '[(.fix_cycle // 0 | tostring), (.stage // "")] | @tsv' "$rd/state.json" 2> /dev/null) || {
  warn "unreadable state file; not gating"
  exit 0
}
IFS=$'\t' read -r fix_cycle stage <<<"$st" || true
case "$fix_cycle" in
  '' | *[!0-9]*) fix_cycle=0 ;;
esac
if [ -z "$stage" ]; then
  warn "unreadable state file (no stage); not gating"
  exit 0
fi

case "$agent" in
  aew:developer) gate_developer "$rd" ;;
  aew:qa-engineer) gate_qa "$rd" "$stage" "$fix_cycle" ;;
esac
exit 0
