#!/usr/bin/env bash
# Usage: gh-milestone.sh issues <milestone>
#
# Lists the issues of a milestone as JSON, with their dependencies parsed.
#
# Subcommands:
#   issues <milestone>   Print a JSON array, sorted by issue number, of
#                        {number, title, labels, state, depends_on}.
#
# <milestone> is a number or a title, passed to gh verbatim. depends_on is the
# sorted, de-duplicated union of "blocked by #n" / "depends on #n" phrases in
# the issue body (lists joined by commas, "and", "&"), task-list items that
# start with #n ("- [ ] #7"), and GitHub's native blockedBy links, minus the
# issue itself. Comments, repo-qualified references and URLs are ignored.
# Exactly 500 results warns that the list may be truncated.
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

# One jq pass: issue list in, output array out. --arg repo is the listed
# repository ("" when unknown); native blockedBy entries that name a different
# repository are dropped.
JQ_FILTER='
  def nums($s): [$s | match("#([0-9]+)"; "g") | .captures[0].string | tonumber];
  def phrase($b):
    [$b | match("(?:^|[^A-Za-z0-9_])(?:blocked by|depends on)[ \t]*:?[ \t]*((?:#[0-9]+(?![0-9A-Za-z_])(?:[ \t]*(?:[,&]|and(?![A-Za-z0-9_]))[ \t]*|[ \t]+)?)+)"; "gi")
     | nums(.captures[0].string)] | add // [];
  def tasks($b):
    [$b | split("\n")[]
     | select(test("^[ \t]*[-*+][ \t]+\\[[ xX]\\][ \t]+#[0-9]+(?![0-9A-Za-z_])"))
     | match("#([0-9]+)") | .captures[0].string | tonumber];
  def native:
    (.blockedBy // [])
    | (if type == "object" then (.nodes // []) else . end)
    | map(select(type == "object")
          | select(($repo == "") or ((.repository.nameWithOwner? // .repository? // $repo) | if type == "string" then . else $repo end) == $repo)
          | .number)
    | map(select(. != null));
  [.[]
   | (.body // "" | gsub("\r"; "")) as $b
   | .number as $n
   | {number: .number,
      title: .title,
      labels: [.labels[]?.name],
      state: .state,
      depends_on: ((phrase($b) + tasks($b) + native) | unique | map(select(. != $n)))}]
  | sort_by(.number)'

cmd_issues() {
  [ $# -eq 1 ] || die "usage: gh-milestone.sh issues <milestone>"
  local m=$1
  [ -n "$m" ] || die "milestone must not be empty"
  case "$m" in
    -*) die "milestone must not start with '-': $m" ;;
  esac
  local raw out count
  raw=$(gh issue list --milestone "$m" --state all --limit "$LIMIT" --json number,title,labels,state,body,blockedBy) || exit 1
  out=$(printf '%s' "$raw" | jq --arg repo "${GH_REPO:-}" "$JQ_FILTER") || die "could not parse the gh issue list output"
  count=$(printf '%s' "$out" | jq 'length') || die "could not count issues"
  if [ "$count" -ge "$LIMIT" ]; then
    warn "received $count issues; the list may be truncated at $LIMIT"
  fi
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
  *) die "unknown subcommand: $sub (see --help)" ;;
esac
