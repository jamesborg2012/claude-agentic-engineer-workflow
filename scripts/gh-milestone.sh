#!/usr/bin/env bash
# Usage: gh-milestone.sh {issues|select} <milestone>
#
# Lists the issues of a milestone as JSON, with their dependencies parsed.
#
# Subcommands:
#   issues <milestone>   Print a JSON array, sorted by issue number, of
#                        {number, title, labels, state, depends_on}.
#   select <milestone>   Print one JSON object (exit 0, also for a cycle or a
#                        stack conflict): milestone {number, title} or null;
#                        issues (open ones, by number) of {number, title,
#                        labels, depends_on, ac_count, stack_on}; closed (issue
#                        numbers); order (dependency order, lowest number first
#                        on ties; null on a cycle); cycle (null, or the numbers
#                        that could not be placed); stack_conflicts ([] or
#                        [{issue, deps}]); recommend (bulk|sequential); reasons
#                        ([] exactly when recommend is bulk).
#
# <milestone> is a number or a title, passed to gh verbatim. depends_on is the
# sorted, de-duplicated union of "blocked by #n" / "depends on #n" phrases in
# the issue body (lists joined by commas, "and", "&"), task-list items that
# start with #n ("- [ ] #7"), and GitHub's native blockedBy links, minus the
# issue itself. Comments, repo-qualified references and URLs are ignored.
# Exactly 500 results warns that the list may be truncated.
#
# select rules. ac_count: lines starting a list item (-, *, +, 1. or 1) after
# 0-3 spaces) between the first heading or bold-only line naming "acceptance
# criteria" and the next heading or bold-only line; null with no such section.
# A dependency blocks unless it is a closed issue of the milestone. Order and
# stacking use only open in-milestone dependencies; stack_on is the dependency
# latest in order, or null with none, or on a stack conflict (a dependency not
# on that chain), and always null on a cycle. recommend is bulk only for 1-5
# open issues, each with at most 5 acceptance criteria (and a list found) and
# no blocking dependency.
# Options: -h, --help

# The jq filter is single-quoted on purpose: $name is a jq variable.
# shellcheck disable=SC2016
# shellcheck source=lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

case "${1:-}" in
  -h | --help)
    print_usage "${BASH_SOURCE[0]}"
    exit 0
    ;;
esac

LIMIT=500

# One jq pass: issue list in, output array out. Each issue's own repository
# comes from its url (gh 2.103 nodes carry repository.nameWithOwner), falling
# back to $GH_REPO ([HOST/]OWNER/REPO); native blockedBy entries that name a
# different repository are dropped. With neither known, all are merged.
JQ_FILTER='
  def nums($s): [$s | match("#([0-9]+)"; "g") | .captures[0].string | tonumber];
  def phrase($b):
    [$b | match("(?:^|[^A-Za-z0-9_])(?:blocked by|depends on)[ \t]*:?[ \t]*((?:#[0-9]+(?![0-9A-Za-z_])(?:[ \t]*(?:[,&]|and(?![A-Za-z0-9_]))[ \t]*|[ \t]+)?)+)"; "gi")
     | nums(.captures[0].string)] | add // [];
  def tasks($b):
    [$b | split("\n")[]
     | select(test("^[ \t]*[-*+][ \t]+\\[[ xX]\\][ \t]+#[0-9]+(?![0-9A-Za-z_])"))
     | match("#([0-9]+)") | .captures[0].string | tonumber];
  def own_repo:
    ((.url // "") | capture("^https?://[^/]+/(?<r>[^/]+/[^/]+)/issues/[0-9]+") | .r)
    // ($repo | split("/") | .[-2:] | join("/"));
  def native($r):
    (.blockedBy // [])
    | (if type == "object" then (.nodes // []) else . end)
    | map(select(type == "object")
          | select(($r == "")
                   or ((.repository | if type == "object" then .nameWithOwner elif type == "string" then . else null end)
                       | if type == "string" then ascii_downcase == ($r | ascii_downcase) else true end))
          | .number)
    | map(select(. != null));
  [.[]
   | (.body // "" | gsub("\r"; "")) as $b
   | .number as $n
   | own_repo as $r
   | {number: .number,
      title: .title,
      labels: [.labels[]?.name],
      state: .state,
      depends_on: ((phrase($b) + tasks($b) + native($r)) | unique | map(select(. != $n)))}]
  | sort_by(.number)'

# list_issues <subcommand> <args...>: validates the arguments, calls gh once
# and leaves the raw listing in $RAW (warns at the limit).
list_issues() {
  local sub=$1
  shift
  [ $# -eq 1 ] || die "usage: gh-milestone.sh $sub <milestone>"
  local m=$1
  [ -n "$m" ] || die "milestone must not be empty"
  case "$m" in
    -*) die "milestone must not start with '-': $m" ;;
  esac
  local count
  RAW=$(gh issue list --milestone "$m" --state all --limit "$LIMIT" --json number,title,labels,state,body,blockedBy,url,milestone) || exit 1
  count=$(printf '%s' "$RAW" | jq 'length') || die "could not parse the gh issue list output"
  if [ "$count" -ge "$LIMIT" ]; then
    warn "received $count issues; the list may be truncated at $LIMIT"
  fi
}

cmd_issues() {
  list_issues issues "$@"
  local out
  out=$(printf '%s' "$RAW" | jq --arg repo "${GH_REPO:-}" "$JQ_FILTER") || die "could not parse the gh issue list output"
  printf '%s\n' "$out"
}

# select: the issues filter above runs inside this program ($listed); the
# acceptance-criteria count reads the raw bodies ($raw).
SELECT_JQ='
  def isb: test("^ {0,3}#{1,6}([ \t]|$)") or test("^ {0,3}\\*\\*.+\\*\\*:?[ \t]*$");
  def acs($b):
    ($b // "" | gsub("\r"; "") | split("\n")) as $l
    | ([range(0; $l | length) | select($l[.] | isb and test("acceptance criteria"; "i"))] | .[0]) as $o
    | if $o == null then null
      else ([range($o + 1; $l | length) | select($l[.] | isb)] | .[0] // ($l | length)) as $e
        | [range($o + 1; $e) | select($l[.] | test("^ {0,3}([-*+]|[0-9]+[.)]) "))] | length
      end;
  def chain($x; $s):
    ($s[$x | tostring]) as $p | if $p == null then [$x] else [$x] + chain($p; $s) end;
  def kahn($nums; $deps):
    reduce range(0; $nums | length) as $_ ({placed: [], rem: $nums, done: false};
      if .done then .
      else .placed as $p
        | [.rem[] | select(. as $k | $deps[$k | tostring] | all(.[]; . as $d | $p | index($d) != null))] as $ready
        | if ($ready | length) == 0 then .done = true
          else ($ready | min) as $x | .placed += [$x] | .rem -= [$x] end
      end);
  . as $raw
  | ('"$JQ_FILTER"') as $listed
  | [$listed[] | select(.state == "OPEN")] as $open
  | ([$listed[] | select(.state == "CLOSED") | .number] | sort) as $closed
  | ($open | map(.number)) as $nums
  | (reduce $open[] as $o ({}; .[$o.number | tostring] = [$o.depends_on[] | select(. as $d | $nums | index($d) != null)])) as $ideps
  | (reduce $raw[] as $r ({}; .[$r.number | tostring] = acs($r.body))) as $ac
  | kahn($nums; $ideps) as $k
  | (($k.rem | length) > 0) as $cyc
  | (if $cyc then {s: {}, c: []}
     else reduce $k.placed[] as $x ({s: {}, c: []};
       $ideps[$x | tostring] as $d
       | if ($d | length) == 0 then .s[$x | tostring] = null
         else ($d | max_by(. as $y | $k.placed | index($y))) as $latest
           | chain($latest; .s) as $ch
           | if ($d | all(.[]; . as $y | $ch | index($y) != null)) then .s[$x | tostring] = $latest
             else .s[$x | tostring] = null | .c += [{issue: $x, deps: $d}] end
         end)
     end) as $st
  | ([$open[] | .number as $n | $ac[$n | tostring] as $a
      | (if $a == null then ["#\($n): no acceptance-criteria list found"]
         elif $a > 5 then ["#\($n) has \($a) acceptance criteria"] else [] end)
        + ([.depends_on[] | select(. as $d | $closed | index($d) == null)] as $b
           | if ($b | length) > 0 then ["#\($n) depends on \($b | map("#\(.)") | join(", "))"] else [] end)
     ] | add // []) as $per
  | ((if ($nums | length) == 0 then ["no open issues"]
      elif ($nums | length) > 5 then ["\($nums | length) open issues (more than 5)"] else [] end) + $per) as $reasons
  | {milestone: ([$raw[].milestone | select(. != null)] | .[0] | if . == null then null else {number, title} end),
     issues: [$open[] | {number, title, labels, depends_on, ac_count: $ac[.number | tostring], stack_on: $st.s[.number | tostring]}],
     closed: $closed,
     order: (if $cyc then null else $k.placed end),
     cycle: (if $cyc then $k.rem else null end),
     stack_conflicts: ($st.c | sort_by(.issue)),
     recommend: (if ($reasons | length) == 0 then "bulk" else "sequential" end),
     reasons: $reasons}'

cmd_select() {
  list_issues select "$@"
  local out
  out=$(printf '%s' "$RAW" | jq --arg repo "${GH_REPO:-}" "$SELECT_JQ") || die "could not parse the gh issue list output"
  printf '%s\n' "$out"
}

[ $# -gt 0 ] || die "missing subcommand (see --help)"
sub=$1
shift
case "$sub" in
  issues)
    require_cmd gh jq
    cmd_issues "$@"
    ;;
  select)
    require_cmd gh jq
    cmd_select "$@"
    ;;
  *) die "unknown subcommand: $sub (see --help)" ;;
esac
