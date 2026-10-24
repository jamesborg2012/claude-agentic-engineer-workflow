#!/usr/bin/env bash
# Usage: gh-pr.sh <subcommand> [args]
#
# Pull request operations for the orchestrator. Agents never call this.
#
# Subcommands:
#   create <run-id> <body-file> [--base <branch>] [--draft]
#       Open a PR from the run's branch. The base is --base, else the run's
#       base_branch. Placeholder "Closes #<issue>" lines are removed and a
#       "Closes #n" line is added for each run issue the body does not already
#       close. Prints the PR number. The body file is never modified.
#   update <pr> <body-file> [--run <run-id>]
#       Replace the PR body. With --run, the same closing-line fix as create
#       is applied first.
#   ready <pr>
#       Mark a draft PR ready for review.
#   comment <pr> <file>
#       Add a comment to the PR.
#
# Run state is read from .aew/runs/<run-id>/state.json (issues, title, branch,
# base_branch) and never written. There is no "PR already exists" lookup: check
# state.pr before calling create. Exit 1 on any invalid input, before any gh call.
# Options: -h, --help

# shellcheck source=lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

case "${1:-}" in
  -h | --help)
    print_usage "${BASH_SOURCE[0]}"
    exit 0
    ;;
esac

require_cmd gh jq awk

TMP=""
trap '[ -z "$TMP" ] || rm -f "$TMP"' EXIT

# need_file <path>: die unless it is a non-empty regular file.
need_file() {
  [ -f "$1" ] || die "no such file: $1"
  [ -s "$1" ] || die "file is empty: $1"
}

need_pr() {
  local re='^[1-9][0-9]*$'
  [[ ${1:-} =~ $re ]] || die "invalid PR number: ${1:-}"
}

# run_state <run-id>: sets ISSUES (space separated), TITLE, BRANCH, BASE from state.json.
run_state() {
  local id=$1 d out
  is_run_id "$id" || die "invalid run id: $id"
  d=$(run_dir "$id") || exit 1
  [ -f "$d/state.json" ] || die "no state.json for run $id"
  out=$(jq -r '(.issues | map(tostring) | join(" ")), (.title // ""), (.branch // ""), (.base_branch // "")' "$d/state.json") ||
    die "cannot read $d/state.json"
  {
    IFS= read -r ISSUES
    IFS= read -r TITLE
    IFS= read -r BRANCH
    IFS= read -r BASE
  } <<EOF2
$out
EOF2
}

# normalise_body <body-file> <issues>: writes the fixed body to a new temp file (TMP).
# Removes placeholder lines (a closing keyword plus "#<issue>" and nothing else;
# prose that merely mentions "#<issue>" is kept), then appends "Closes #n" for each issue
# not already covered by a closing keyword, in the body's line ending.
normalise_body() {
  TMP=$(mktemp "${TMPDIR:-/tmp}/aew-pr.XXXXXX") || die "cannot create a temp file"
  awk -v issues="$2" '
    { raw[NR] = $0; if ($0 ~ /\r$/) crlf = 1 }
    END {
      eol = crlf ? "\r\n" : "\n"
      n = split(issues, ids, " ")
      for (i = 1; i <= NR; i++) {
        l = raw[i]; sub(/\r$/, "", l)
        if (tolower(l) ~ /^[ \t]*(close[sd]?|fix(es|ed)?|resolve[sd]?)[ \t]*:?[ \t]*#<issue>[ \t]*$/) continue
        kept[++k] = l
      }
      for (i = 1; i <= k; i++) printf "%s%s", kept[i], eol
      for (j = 1; j <= n; j++) {
        re = "(^|[^a-z0-9_])(close[sd]?|fix(es|ed)?|resolve[sd]?)[ \t]*:?[ \t]*#" ids[j] "([^0-9]|$)"
        covered = 0
        for (i = 1; i <= k; i++) if (tolower(kept[i]) ~ re) { covered = 1; break }
        if (!covered) printf "Closes #%s%s", ids[j], eol
      }
    }' "$1" > "$TMP" || die "cannot normalise $1"
}

cmd_create() {
  local id="" file="" base="" draft=0 arg
  while [ $# -gt 0 ]; do
    arg=$1
    case "$arg" in
      --base)
        [ $# -ge 2 ] && [ -n "$2" ] || die "--base needs a value"
        base=$2
        shift 2
        ;;
      --draft)
        draft=1
        shift
        ;;
      -*) die "unknown option: $arg" ;;
      *)
        if [ -z "$id" ]; then id=$arg
        elif [ -z "$file" ]; then file=$arg
        else die "unexpected argument: $arg"
        fi
        shift
        ;;
    esac
  done
  [ -n "$id" ] && [ -n "$file" ] || die "usage: gh-pr.sh create <run-id> <body-file> [--base <branch>] [--draft]"
  run_state "$id"
  need_file "$file"
  [ -n "$BRANCH" ] || die "run $id has no branch (state.sh set branch <name>)"
  [ -n "$TITLE" ] || die "run $id has an empty title (state.sh set title <title>)"
  [ -n "$base" ] || base=$BASE
  [ -n "$base" ] || die "run $id has no base_branch and no --base was given"
  normalise_body "$file" "$ISSUES"
  local args=(--head "$BRANCH" --base "$base" --title "$TITLE" --body-file "$TMP")
  if [ "$draft" -eq 1 ]; then args+=(--draft); fi
  local url num
  url=$(gh pr create "${args[@]}") || exit 1
  num=$(printf '%s\n' "$url" | sed -n 's#.*/pull/\([0-9][0-9]*\)[[:space:]]*$#\1#p' | tail -n 1) || exit 1
  [ -n "$num" ] || die "could not find a PR number in gh output: $url"
  printf '%s\n' "$num"
}

cmd_update() {
  local pr="" file="" run="" have_run=0 arg
  while [ $# -gt 0 ]; do
    arg=$1
    case "$arg" in
      --run)
        [ $# -ge 2 ] && [ -n "$2" ] || die "--run needs a value"
        run=$2
        have_run=1
        shift 2
        ;;
      -*) die "unknown option: $arg" ;;
      *)
        if [ -z "$pr" ]; then pr=$arg
        elif [ -z "$file" ]; then file=$arg
        else die "unexpected argument: $arg"
        fi
        shift
        ;;
    esac
  done
  [ -n "$pr" ] && [ -n "$file" ] || die "usage: gh-pr.sh update <pr> <body-file> [--run <run-id>]"
  need_pr "$pr"
  need_file "$file"
  if [ "$have_run" -eq 1 ]; then
    run_state "$run"
    normalise_body "$file" "$ISSUES"
    file=$TMP
  fi
  gh pr edit "$pr" --body-file "$file" || exit 1
}

cmd_ready() {
  [ $# -eq 1 ] || die "usage: gh-pr.sh ready <pr>"
  need_pr "$1"
  gh pr ready "$1" || exit 1
}

cmd_comment() {
  [ $# -eq 2 ] || die "usage: gh-pr.sh comment <pr> <file>"
  need_pr "$1"
  need_file "$2"
  gh pr comment "$1" --body-file "$2" || exit 1
}

[ $# -ge 1 ] || die "missing subcommand (see --help)"
sub=$1
shift
case "$sub" in
  create) cmd_create "$@" ;;
  update) cmd_update "$@" ;;
  ready) cmd_ready "$@" ;;
  comment) cmd_comment "$@" ;;
  *) die "unknown subcommand: $sub (see --help)" ;;
esac
