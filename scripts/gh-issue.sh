#!/usr/bin/env bash
# Usage: gh-issue.sh <subcommand> [args]
#
# GitHub issue I/O for the aew orchestrator. The agents never call this;
# only the orchestrator does.
#
# Subcommands:
#   fetch <n> <run-dir>      Read issue <n> with one gh call and write issue.json
#                            and 00-issue-original.md into the existing run dir.
#                            issue.json gains referenced_issues: a sorted,
#                            de-duplicated array of the issue numbers mentioned
#                            in the body and comments.
#   comment <n> <file>       Post the non-empty file as a comment on issue <n>
#                            and print the comment URL.
#
# Exit 1 on any invalid input or gh failure; nothing is written on failure.
# Options: -h, --help

# The jq programs are single-quoted on purpose: $name is a jq variable.
# shellcheck disable=SC2016
# shellcheck source=lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

case "${1:-}" in
  -h | --help)
    print_usage "${BASH_SOURCE[0]}"
    exit 0
    ;;
esac

work=""
trap '[ -z "$work" ] || rm -rf "$work"' EXIT

# check_issue_number <x>: die unless x is a positive integer without a leading zero.
check_issue_number() {
  local re='^[1-9][0-9]*$'
  [[ ${1:-} =~ $re ]] || die "invalid issue number: ${1:-}"
}

# Adds referenced_issues: #n mentions and this repository's own issue URLs,
# without the issue itself. Excludes owner/repo#n, &#35; entities, abc#1
# anchors and hex colours such as #1D76DB.
JQ_REFS='
  . as $i
  | ($i.url | sub("[0-9]+$"; "")) as $prefix
  | ([$i.body // ""] + [($i.comments // [])[] | .body // ""]) as $texts
  | ([$texts[] | scan("(^|[^A-Za-z0-9_&/#])#([1-9][0-9]*)(?![A-Za-z0-9_])") | .[1] | tonumber]
     + [$texts[] | scan("(https://[^\\s/]+/[^\\s/]+/[^\\s/]+/issues/)([1-9][0-9]*)(?![A-Za-z0-9_])")
        | select(.[0] == $prefix) | .[1] | tonumber]) as $refs
  | . + {referenced_issues: ($refs | map(select(. != $i.number)) | unique)}'

JQ_RENDER='
  def item: "#\(.number)"
    + (if (.title // "") != "" then " " + .title else "" end)
    + (if (.state // "") != "" then " (" + .state + ")" else "" end);
  def items: if length == 0 then "none" else map(item) | join("; ") end;
  def nodes: (. // {}) | (.nodes // []);
  def nl: if endswith("\n") then "" else "\n" end;
  def names(f): if length == 0 then "none" else map(f) | join(", ") end;
  (.comments // []) as $c
  | "# #\(.number) \(.title)\n\n"
  + "- **URL:** \(.url)\n"
  + "- **State:** \(.state)\n"
  + "- **Author:** @\(.author.login // "unknown")\n"
  + "- **Labels:** \((.labels // []) | names(.name))\n"
  + "- **Milestone:** \(if .milestone then "\(.milestone.title) (#\(.milestone.number))" else "none" end)\n"
  + "- **Assignees:** \((.assignees // []) | names("@" + .login))\n"
  + "\n## Body\n\n" + (.body // "") + ((.body // "") | nl) + "\n"
  + "## Comments (\($c | length))\n\n"
  + (if ($c | length) == 0 then "None.\n\n"
     else ($c | map("### @\(.author.login // "unknown") — \(.createdAt)\n\n" + (.body // "") + ((.body // "") | nl) + "\n") | join(""))
     end)
  + "## Linked issues\n\n"
  + "- Parent: \([.parent | select(. != null)] | items)\n"
  + "- Blocked by: \(.blockedBy | nodes | items)\n"
  + "- Blocking: \(.blocking | nodes | items)\n"
  + "- Sub-issues: \(.subIssues | nodes | items)\n"
  + "- Closed by pull requests: \((.closedByPullRequestsReferences // []) | items)\n"
  + "\n## Referenced issues\n\n"
  + (if (.referenced_issues | length) == 0 then "none" else (.referenced_issues | map("#\(.)") | join(", ")) end)
  + "\n"'

cmd_fetch() {
  [ $# -eq 2 ] || die "fetch: expected <n> <run-dir>"
  local n=$1 dir=$2
  check_issue_number "$n"
  [ -d "$dir" ] || die "run dir not found: $dir"
  require_cmd gh jq
  work=$(mktemp -d "${TMPDIR:-/tmp}/aew-gh-issue.XXXXXX") || die "cannot create a work dir"
  gh issue view "$n" --json number,title,body,state,url,author,comments,labels,milestone,assignees,blockedBy,blocking,parent,subIssues,closedByPullRequestsReferences > "$work/view.json" || die "gh issue view #$n failed"
  jq "$JQ_REFS" "$work/view.json" > "$work/issue.json" || die "cannot process the response for #$n"
  jq -j "$JQ_RENDER" "$work/issue.json" > "$work/00-issue-original.md" || die "cannot render #$n"
  mv -f "$work/issue.json" "$dir/issue.json" || die "cannot write $dir/issue.json"
  mv -f "$work/00-issue-original.md" "$dir/00-issue-original.md" || die "cannot write $dir/00-issue-original.md"
}

cmd_comment() {
  [ $# -eq 2 ] || die "comment: expected <n> <file>"
  local n=$1 file=$2
  check_issue_number "$n"
  [ -f "$file" ] || die "comment file not found: $file"
  [ -s "$file" ] || die "comment file is empty: $file"
  require_cmd gh
  gh issue comment "$n" --body-file "$file" || die "gh issue comment #$n failed"
}

[ $# -gt 0 ] || die "missing subcommand (see --help)"
sub=$1
shift
case "$sub" in
  fetch) cmd_fetch "$@" ;;
  comment) cmd_comment "$@" ;;
  *) die "unknown subcommand: $sub (see --help)" ;;
esac
