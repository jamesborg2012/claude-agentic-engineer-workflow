#!/usr/bin/env bash
# Usage: state.sh <subcommand> [args]
#
# Manages the state of the current aew run (.aew/runs/<run-id>/state.json).
# Every write is validated first, then made atomically (temp file and mv),
# and mirrored as one line in log.md where noted.
#
# Subcommands:
#   init <run-id> --issues <n,...> --mode <mode> [--auto] [--title <t>]
#       Create the run dir, state.json, log.md and set it as the current run.
#       Mode bulk also creates issues/<k>/ per issue.
#   get [field]                  Whole state (JSON) or one top-level field.
#   stage <stage> [--note <n>]   Set the stage; status becomes running.
#   status <status> [--note <n>] Set the status; the stage is kept.
#   bump fix_cycle|review_cycle  Increment a counter and print the new value.
#   set <field> <value>          title | branch | base_branch | pr | spec_revision | auto
#   current [set <run-id>|clear] Print, switch or clear the current run.
#   index init <run-id> [--stack-on <k>:<dep>[,<k>:<dep>...]]
#       Write .aew/runs/<run-id>/index.json for a sequential run: every child
#       pending, stack_on null unless given. Refuses if index.json exists.
#   index set <run-id> <issue> <pending|running|done|blocked|failed>
#       Set one child's status; any status may follow any other.
#       index.json is {"run_id","order":[n,...],"children":[{"issue","stack_on","status"}]}.
#       index acts on the run id given, not on .aew/runs/current.
#
# All subcommands except init, "current set" and index act on the run named in
# .aew/runs/current. Stage, status and mode values come from
# templates/state.schema.json. Exit 1 on any invalid input; nothing is written.
# Options: -h, --help

# The jq filters are single-quoted on purpose: $name is a jq variable.
# shellcheck disable=SC2016
# shellcheck source=lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

case "${1:-}" in
  -h | --help)
    print_usage "${BASH_SOURCE[0]}"
    exit 0
    ;;
esac

TMP=""
trap '[ -z "$TMP" ] || rm -f "$TMP"' EXIT

now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# schema_enum stage|status|mode: the allowed values, one per line.
schema_enum() {
  local path out
  case "$1" in
    mode) path='.properties.mode.enum[]' ;;
    *) path=".[\"\$defs\"].$1.enum[]" ;;
  esac
  out=$(jq -r "$path" "$(plugin_root)/templates/state.schema.json") || die "cannot read enum '$1' from state.schema.json"
  [ -n "$out" ] || die "state.schema.json has no enum '$1'"
  printf '%s\n' "$out"
}

# check_enum <name> <value>: die unless value is in the schema enum.
check_enum() {
  local list
  list=$(schema_enum "$1") || exit 1
  printf '%s\n' "$list" | grep -qxF -- "$2" || die "invalid $1: $2"
}

# load_run: sets D to the current run dir and checks state.json is readable.
load_run() {
  D=$(run_dir) || exit 1
  [ -f "$D/state.json" ] || die "no state.json for run ${D##*/}"
  jq -e 'type == "object"' "$D/state.json" > /dev/null 2>&1 || die "state.json is not valid JSON: $D/state.json"
}

# write_state <dir> <jq-filter> [jq-arg…]: atomically replace state.json.
write_state() {
  local dir=$1 filter=$2
  shift 2
  TMP=$(mktemp "$dir/.state.json.XXXXXX") || die "cannot create temp file in $dir"
  jq "$@" "$filter" "$dir/state.json" > "$TMP" || die "cannot update state.json"
  mv -f "$TMP" "$dir/state.json" || die "cannot write $dir/state.json"
  TMP=""
}

# log_line <dir> <stage> <status> <at> [note]
log_line() {
  if [ -n "${5:-}" ]; then
    printf -- '- %s %s %s — %s\n' "$4" "$2" "$3" "$5" >> "$1/log.md"
  else
    printf -- '- %s %s %s\n' "$4" "$2" "$3" >> "$1/log.md"
  fi
}

# parse_note <args…>: sets NOTE and HAS_NOTE from an optional --note <n>.
parse_note() {
  NOTE=""
  HAS_NOTE=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --note)
        [ $# -ge 2 ] || die "--note needs a value"
        NOTE=$2
        HAS_NOTE=1
        shift 2
        ;;
      *) die "unknown option: $1" ;;
    esac
  done
}

write_current() {
  local runs=$1 id=$2
  TMP=$(mktemp "$runs/.current.XXXXXX") || die "cannot create temp file in $runs"
  printf '%s\n' "$id" > "$TMP"
  mv -f "$TMP" "$runs/current" || die "cannot write $runs/current"
  TMP=""
}

cmd_init() {
  local id=${1:-} issues="" mode="" title="" auto=false a b
  [ -n "$id" ] || die "init: missing run id"
  shift
  while [ $# -gt 0 ]; do
    case "$1" in
      --issues | --mode | --title)
        [ $# -ge 2 ] || die "init: $1 needs a value"
        case "$1" in --issues) issues=$2 ;; --mode) mode=$2 ;; --title) title=$2 ;; esac
        shift 2
        ;;
      --auto)
        auto=true
        shift
        ;;
      *) die "init: unknown option: $1" ;;
    esac
  done
  is_run_id "$id" || die "invalid run id: $id"
  [[ $issues =~ ^[1-9][0-9]*(,[1-9][0-9]*)*$ ]] || die "init: --issues must be comma-separated issue numbers"
  for a in ${issues//,/ }; do
    local seen=0
    for b in ${issues//,/ }; do
      if [ "$a" = "$b" ]; then seen=$((seen + 1)); fi
    done
    [ "$seen" -eq 1 ] || die "init: duplicate issue number: $a"
  done
  [ -n "$mode" ] || die "init: --mode is required"
  check_enum mode "$mode"
  local dir base ts
  dir=$(run_dir "$id") || exit 1
  [ ! -e "$dir/state.json" ] || die "run $id already exists"
  base=$(config_get default_branch) || exit 1
  ts=$(now)
  mkdir -p "$dir" || die "cannot create $dir"
  if [ "$mode" = bulk ]; then
    for a in ${issues//,/ }; do
      mkdir -p "$dir/issues/$a" || die "cannot create $dir/issues/$a"
    done
  fi
  TMP=$(mktemp "$dir/.state.json.XXXXXX") || die "cannot create temp file in $dir"
  jq -n --arg id "$id" --argjson issues "[$issues]" --arg title "$title" --arg mode "$mode" \
    --argjson auto "$auto" --arg base "$base" --arg ts "$ts" '{
      run_id: $id, issues: $issues, title: $title, mode: $mode, auto: $auto,
      stage: "spec_analysis", status: "running", branch: null, base_branch: $base,
      pr: null, spec_revision: 1, fix_cycle: 0, review_cycle: 0,
      started_at: $ts, updated_at: $ts,
      history: [{stage: "spec_analysis", status: "running", at: $ts}]}' > "$TMP" || die "cannot build state.json"
  mv -f "$TMP" "$dir/state.json" || die "cannot write $dir/state.json"
  TMP=""
  log_line "$dir" spec_analysis running "$ts"
  write_current "${dir%/*}" "$id"
}

cmd_get() {
  local f=${1:-}
  load_run
  if [ -z "$f" ]; then
    jq . "$D/state.json" || die "cannot read state.json"
    return 0
  fi
  jq -e --arg f "$f" '.properties | has($f)' "$(plugin_root)/templates/state.schema.json" > /dev/null 2>&1 || die "unknown field: $f"
  jq -r --arg f "$f" '.[$f] | if type == "string" then . else tojson end' "$D/state.json" || die "cannot read field: $f"
}

cmd_transition() {
  local kind=$1 val=${2:-} ts stage status
  [ -n "$val" ] || die "$kind: missing value"
  shift 2
  parse_note "$@"
  check_enum "$kind" "$val"
  load_run
  ts=$(now)
  if [ "$kind" = stage ]; then
    stage=$val
    status=running
  else
    stage=$(jq -r .stage "$D/state.json") || die "cannot read state.json"
    status=$val
  fi
  write_state "$D" '.stage = $s | .status = $t | .updated_at = $at
    | .history += [{stage: $s, status: $t, at: $at} + (if $h == "1" then {note: $n} else {} end)]' \
    --arg s "$stage" --arg t "$status" --arg at "$ts" --arg h "$HAS_NOTE" --arg n "$NOTE"
  log_line "$D" "$stage" "$status" "$ts" "$NOTE"
}

cmd_bump() {
  local n=${1:-} new
  [ -n "$n" ] || die "bump: missing counter name"
  case "$n" in
    fix_cycle | review_cycle) ;;
    *) die "bump: cannot bump '$n' (fix_cycle or review_cycle)" ;;
  esac
  load_run
  write_state "$D" '.[$n] += 1 | .updated_at = $at' --arg n "$n" --arg at "$(now)"
  new=$(jq -r --arg n "$n" '.[$n]' "$D/state.json") || die "cannot read state.json"
  printf '%s\n' "$new"
}

cmd_set() {
  [ $# -ge 2 ] || die "set: usage: set <field> <value>"
  local f=$1 v=$2 spec types min jv
  case "$f" in
    title | branch | base_branch | pr | spec_revision | auto) ;;
    *) die "field cannot be set: $f" ;;
  esac
  spec=$(jq -r --arg f "$f" '.properties[$f] | ((.type | if type == "array" then . else [.] end | join(",")) + "|" + ((.minimum // "") | tostring))' \
    "$(plugin_root)/templates/state.schema.json") || die "cannot read schema for field: $f"
  types=${spec%%|*}
  min=${spec#*|}
  case ",$types," in
    *,integer,*)
      if [ "$v" = null ] && [[ ",$types," == *,null,* ]]; then
        jv=null
      else
        [[ $v =~ ^-?[0-9]{1,15}$ ]] || die "invalid value for $f: $v"
        if [ -n "$min" ] && [ "$v" -lt "$min" ]; then die "invalid value for $f: $v"; fi
        jv=$(jq -n --arg s "$v" '$s | tonumber') || die "invalid value for $f: $v"
      fi
      ;;
    *,boolean,*)
      case "$v" in
        true | false) jv=$v ;;
        *) die "invalid value for $f: $v" ;;
      esac
      ;;
    *)
      if [ "$v" = null ]; then
        [[ ",$types," == *,null,* ]] || die "invalid value for $f: $v"
        jv=null
      else
        jv=$(jq -n --arg s "$v" '$s') || die "invalid value for $f: $v"
      fi
      ;;
  esac
  load_run
  write_state "$D" '.[$f] = $v | .updated_at = $at' --arg f "$f" --argjson v "$jv" --arg at "$(now)"
}

cmd_current() {
  local root runs id d
  case "${1:-}" in
    "")
      d=$(run_dir) || exit 1
      printf '%s\n' "${d##*/}"
      ;;
    set)
      id=${2:-}
      [ -n "$id" ] || die "current set: missing run id"
      d=$(run_dir "$id") || exit 1
      [ -f "$d/state.json" ] || die "no state.json for run $id"
      write_current "${d%/*}" "$id"
      ;;
    clear)
      root=$(repo_root) || exit 1
      runs=$root/.aew/runs
      rm -f "$runs/current"
      ;;
    *) die "current: unknown argument: $1" ;;
  esac
}

# cmd_index init|set: own .aew/runs/<run-id>/index.json (explicit run id, never current).
cmd_index() {
  local op=${1:-} id dir res a so="" issue st
  case "$op" in
    init | set) ;;
    "") die "index: missing subcommand (init or set)" ;;
    *) die "index: unknown subcommand: $op" ;;
  esac
  shift
  id=${1:-}
  [ -n "$id" ] || die "index $op: missing run id"
  shift
  is_run_id "$id" || die "invalid run id: $id"
  dir=$(run_dir "$id") || exit 1
  [ -f "$dir/state.json" ] || die "no state.json for run $id"
  jq -e 'type == "object"' "$dir/state.json" > /dev/null 2>&1 || die "state.json is not valid JSON: $dir/state.json"
  jq -e '.mode == "sequential"' "$dir/state.json" > /dev/null || die "index: run $id is not a sequential run"
  if [ "$op" = init ]; then
    local has_so=0
    while [ $# -gt 0 ]; do
      case "$1" in
        --stack-on)
          [ $# -ge 2 ] || die "index init: --stack-on needs a value"
          so=$2
          has_so=1
          shift 2
          ;;
        *) die "index init: unknown option: $1" ;;
      esac
    done
    [ ! -e "$dir/index.json" ] || die "index.json already exists for run $id"
    if [ "$has_so" -eq 1 ]; then
      [[ $so =~ ^[1-9][0-9]*:[1-9][0-9]*(,[1-9][0-9]*:[1-9][0-9]*)*$ ]] || die "index init: --stack-on must be <k>:<dep>[,<k>:<dep>...]"
    fi
    res=$(jq -c --arg so "$so" '
      .issues as $o
      | ($so | if . == "" then [] else split(",") | map(split(":") | {k: (.[0] | tonumber), d: (.[1] | tonumber)}) end) as $p
      | ($p | map(.k)) as $ks
      | if ($ks | length) != ($ks | unique | length) then {err: "index init: repeated issue in --stack-on"}
        elif any($p[]; (.k as $k | $o | index($k)) == null) then {err: "index init: --stack-on issue is not in the run"}
        elif any($p[]; (.d as $d | $o | index($d)) == null) then {err: "index init: --stack-on dependency is not in the run"}
        elif any($p[]; (.d as $d | $o | index($d)) >= (.k as $k | $o | index($k))) then {err: "index init: --stack-on dependency must come earlier in the run order"}
        else {run_id, order: $o, children: [$o[] as $i | {issue: $i, stack_on: (($p[] | select(.k == $i) | .d) // null), status: "pending"}]}
        end' "$dir/state.json") || die "cannot build index.json"
  else
    [ $# -eq 2 ] || die "index set: usage: index set <run-id> <issue> <status>"
    issue=$1
    st=$2
    [[ $issue =~ ^[1-9][0-9]*$ ]] || die "index set: invalid issue: $issue"
    case "$st" in
      pending | running | done | blocked | failed) ;;
      *) die "index set: invalid status: $st" ;;
    esac
    [ -f "$dir/index.json" ] || die "no index.json for run $id"
    jq -e 'type == "object" and (.children | type == "array")' "$dir/index.json" > /dev/null 2>&1 || die "index.json is not valid: $dir/index.json"
    jq -e --argjson i "$issue" 'any(.children[]; .issue == $i)' "$dir/index.json" > /dev/null || die "index set: issue $issue is not in run $id"
    if jq -e --argjson i "$issue" --arg s "$st" 'any(.children[]; .issue == $i and .status == $s)' "$dir/index.json" > /dev/null; then
      return 0
    fi
    res=$(jq -c --argjson i "$issue" --arg s "$st" '.children |= map(if .issue == $i then .status = $s else . end)' "$dir/index.json") || die "cannot update index.json"
  fi
  a=$(printf '%s' "$res" | jq -r '.err // empty') || die "cannot build index.json"
  [ -z "$a" ] || die "$a"
  TMP=$(mktemp "$dir/.index.json.XXXXXX") || die "cannot create temp file in $dir"
  printf '%s\n' "$res" | jq . > "$TMP" || die "cannot write index.json"
  mv -f "$TMP" "$dir/index.json" || die "cannot write $dir/index.json"
  TMP=""
}

[ $# -gt 0 ] || die "missing subcommand (see --help)"
sub=$1
shift
case "$sub" in
  init | get | stage | status | bump | set | current | index) ;;
  *) die "unknown subcommand: $sub (see --help)" ;;
esac
require_cmd jq git

case "$sub" in
  init) cmd_init "$@" ;;
  get) cmd_get "$@" ;;
  stage | status) cmd_transition "$sub" "$@" ;;
  bump) cmd_bump "$@" ;;
  set) cmd_set "$@" ;;
  current) cmd_current "$@" ;;
  index) cmd_index "$@" ;;
esac
