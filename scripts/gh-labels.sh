#!/usr/bin/env bash
# Usage: gh-labels.sh <subcommand> [args]
#
# Manages the aew labels on GitHub issues. Agents never call this; the
# orchestrator does. Run "ensure" once before "stage" or "flag", because
# neither creates labels.
#
# Subcommands:
#   ensure                       Create or update the 11 aew labels (idempotent).
#   stage <n> <stage>            Make <stage> the only stage label on issue <n>
#                                (one gh call; none if already correct). Other
#                                labels are never touched. Bare or aew:-prefixed.
#   flag <n> add|remove <flag>   Add or remove spec-revised or
#                                manual-test-required on issue <n>. A no-op
#                                makes no gh call.
#
# Stages: analysing awaiting-input planning awaiting-approval building testing
# documenting ready-for-review blocked. Exit 1 on any invalid input; names are
# validated before any gh call.
# Options: -h, --help

# shellcheck source=lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

case "${1:-}" in
  -h | --help)
    print_usage "${BASH_SOURCE[0]}"
    exit 0
    ;;
esac

# label_table: kind|name|colour|description, the only source of label data.
label_table() {
  cat <<'TABLE'
stage|aew:analysing|1D76DB|aew: spec analysis is running
stage|aew:awaiting-input|FBCA04|aew: waiting for answers to spec questions
stage|aew:planning|0052CC|aew: brief, standards, test plan and plan in progress
stage|aew:awaiting-approval|E4A11B|aew: plan is waiting for approval
stage|aew:building|0075CA|aew: development and code review in progress
stage|aew:testing|006B75|aew: QA is running
stage|aew:documenting|5DA9E9|aew: summary, PR body and retro being written
stage|aew:ready-for-review|0E8A16|aew: PR is open and ready for human review
stage|aew:blocked|B60205|aew: run is blocked and needs a human
flag|aew:spec-revised|8250DF|aew: the spec on this issue was revised (history kept in the body)
flag|aew:manual-test-required|D93F0B|aew: some tests must be run by hand (see the issue body)
TABLE
}

# names_of <kind>: the label names of that kind, one per line.
names_of() {
  label_table | awk -F'|' -v k="$1" '$1 == k { print $2 }'
}

# norm_label <kind> <arg>: print the aew:-prefixed name, or die if unknown.
norm_label() {
  local kind=$1 arg=$2 name valid
  case "$arg" in
    aew:*) name=$arg ;;
    *) name="aew:$arg" ;;
  esac
  valid=$(names_of "$kind") || die "cannot read the label table"
  if ! printf '%s\n' "$valid" | grep -Fxq -- "$name"; then
    die "unknown $kind label: $arg (expected one of: $(printf '%s' "$valid" | tr '\n' ' ' | sed 's/ $//'))"
  fi
  printf '%s\n' "$name"
}

check_issue() {
  case "${1:-}" in
    [1-9] | [1-9]*[0-9]) ;;
    *) die "invalid issue number: ${1:-}" ;;
  esac
  case "$1" in
    *[!0-9]*) die "invalid issue number: $1" ;;
  esac
}

# current_labels <n>: the issue's label names, one per line.
current_labels() {
  gh issue view "$1" --json labels --jq '.labels[].name' || die "gh issue view $1 failed"
}

cmd_ensure() {
  [ $# -eq 0 ] || die "ensure takes no arguments"
  require_cmd gh
  local kind name colour desc
  while IFS='|' read -r kind name colour desc; do
    gh label create "$name" --color "$colour" --description "$desc" --force > /dev/null ||
      die "gh label create $name failed"
  done < <(label_table)
  info "ensured 11 labels"
}

cmd_stage() {
  [ $# -eq 2 ] || die "usage: stage <n> <stage>"
  local n=$1 target labels l remove="" add=1
  check_issue "$n"
  target=$(norm_label stage "$2") || return 1
  require_cmd gh
  labels=$(current_labels "$n") || return 1
  local stages
  stages=$(names_of stage) || die "cannot read the label table"
  while IFS= read -r l; do
    [ -n "$l" ] || continue
    if [ "$l" = "$target" ]; then
      add=0
    elif printf '%s\n' "$stages" | grep -Fxq -- "$l"; then
      remove="${remove:+$remove,}$l"
    fi
  done <<EOF2
$labels
EOF2
  if [ "$add" -eq 0 ] && [ -z "$remove" ]; then
    return 0
  fi
  local args=()
  if [ "$add" -eq 1 ]; then args+=(--add-label "$target"); fi
  if [ -n "$remove" ]; then args+=(--remove-label "$remove"); fi
  gh issue edit "$n" ${args[@]+"${args[@]}"} > /dev/null || die "gh issue edit $n failed"
}

cmd_flag() {
  [ $# -eq 3 ] || die "usage: flag <n> add|remove <flag>"
  local n=$1 action=$2 flag labels present=0
  check_issue "$n"
  case "$action" in
    add | remove) ;;
    *) die "invalid action: $action (expected add or remove)" ;;
  esac
  flag=$(norm_label flag "$3") || return 1
  require_cmd gh
  labels=$(current_labels "$n") || return 1
  if printf '%s\n' "$labels" | grep -Fxq -- "$flag"; then present=1; fi
  if [ "$action" = add ] && [ "$present" -eq 0 ]; then
    gh issue edit "$n" --add-label "$flag" > /dev/null || die "gh issue edit $n failed"
  elif [ "$action" = remove ] && [ "$present" -eq 1 ]; then
    gh issue edit "$n" --remove-label "$flag" > /dev/null || die "gh issue edit $n failed"
  fi
}

sub=${1:-}
[ -n "$sub" ] || die "missing subcommand (see --help)"
shift
case "$sub" in
  ensure) cmd_ensure "$@" ;;
  stage) cmd_stage "$@" ;;
  flag) cmd_flag "$@" ;;
  *) die "unknown subcommand: $sub (see --help)" ;;
esac
