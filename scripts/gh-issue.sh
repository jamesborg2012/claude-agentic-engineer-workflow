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
#   revise <n> <spec-file> <version>
#                            Record spec version <version> (>= 2) in the body of
#                            issue <n>: the spec goes on top and the earlier
#                            versions follow in collapsed blocks; v1 is the
#                            author's original body, kept byte for byte.
#                            Running it again with the same input changes nothing.
#                            Refuses (exit 1, no edit) on a regressed or skipped
#                            version, malformed aew blocks, a file containing an
#                            aew marker line or invalid UTF-8, or a body over
#                            65,536 characters.
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

lib=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P) || die "cannot resolve the script directory"
lib=$lib/lib

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

# check_content_file <file>: die unless it is a non-empty, valid UTF-8 file.
check_content_file() {
  [ -f "$1" ] || die "file not found: $1"
  [ -s "$1" ] || die "file is empty: $1"
  jq -n -j --rawfile c "$1" '$c' | cmp -s - "$1" || die "$1 is not valid UTF-8; refusing to edit"
}

# rewrite_body <n> <op> <file> <version>: read issue <n>'s body, run the
# issue-body.jq transform and, when the result differs, write it back. Prints
# nothing on stdout; returns 0 and sets rewrite_changed to 1 (edited) or 0
# (unchanged). Dies on a refusal or a gh failure.
rewrite_body() {
  local n=$1 op=$2 file=$3 version=$4 rc=0
  require_cmd gh jq cmp
  work=$(mktemp -d "${TMPDIR:-/tmp}/aew-gh-issue.XXXXXX") || die "cannot create a work dir"
  gh issue view "$n" --json body > "$work/view.json" || die "gh issue view #$n failed"
  jq -j '.body // ""' "$work/view.json" > "$work/old" || die "cannot read the body of #$n"
  jq -n -j --slurpfile view "$work/view.json" --rawfile content "$file" \
    --arg op "$op" --argjson version "$version" --argjson limit 65536 --argjson issue "$n" \
    -f "$lib/issue-body.jq" > "$work/new" 2> "$work/err" || rc=$?
  case $rc in
    0) ;;
    5) die "$(cat "$work/err")" ;;
    *) die "internal error in issue-body.jq" ;;
  esac
  if cmp -s "$work/old" "$work/new"; then
    rewrite_changed=0
    return 0
  fi
  gh issue edit "$n" --body-file "$work/new" || die "gh issue edit #$n failed"
  rewrite_changed=1
}

cmd_revise() {
  [ $# -eq 3 ] || die "revise: expected <n> <spec-file> <version>"
  local n=$1 file=$2 v=$3 re='^(0|[1-9][0-9]*)$'
  check_issue_number "$n"
  [[ $v =~ $re ]] || die "invalid version: $v"
  [ "$v" -ge 2 ] || die "version must be >= 2 (v1 is the author's original)"
  check_content_file "$file"
  rewrite_changed=0
  rewrite_body "$n" revise "$file" "$v" || exit 1
  if [ "$rewrite_changed" -eq 1 ]; then
    info "issue #$n body revised to spec v$v"
  else
    info "issue #$n body unchanged (spec v$v)"
  fi
}

[ $# -gt 0 ] || die "missing subcommand (see --help)"
sub=$1
shift
case "$sub" in
  fetch) cmd_fetch "$@" ;;
  comment) cmd_comment "$@" ;;
  revise) cmd_revise "$@" ;;
  *) die "unknown subcommand: $sub (see --help)" ;;
esac
