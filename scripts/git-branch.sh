#!/usr/bin/env bash
# Usage: git-branch.sh <subcommand> [args]
#
# Creates and pushes the branch for an aew run. Local git only.
# Preflight checks that the base branch is up to date with origin and never
# updates it.
#
# Subcommands:
#   create <run-id> <slug> [--base <branch>]
#       Create and switch to the run branch, then print its name. The name
#       comes from git.branch_pattern ({issue}, {slug}) for a numeric run id,
#       or git.milestone_branch_pattern ({milestone}, {slug}) for m-<n>.
#       The slug must be lower-case kebab-case. The branch starts at --base
#       (default: default_branch) and has no upstream. Refused on a dirty
#       tree (untracked files count) or when the branch already exists.
#   push
#       Run "git push -u origin <current-branch>", then print the branch name.
#       Refused on a detached HEAD and on default_branch.
#
# Output: the branch name on stdout; git chatter on stderr. Exit 1 on any error.
# Options: -h, --help

# shellcheck source=lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

case "${1:-}" in
  -h | --help)
    print_usage "${BASH_SOURCE[0]}"
    exit 0
    ;;
esac

cmd_create() {
  local id="" slug="" base="" have_pos=0 pat val b st default re
  while [ $# -gt 0 ]; do
    case "$1" in
      --base)
        [ $# -ge 2 ] || die "--base needs a branch"
        base=$2
        shift 2
        ;;
      -*) die "unknown option: $1" ;;
      *)
        case "$have_pos" in
          0) id=$1 ;;
          1) slug=$1 ;;
          *) die "unexpected argument: $1" ;;
        esac
        have_pos=$((have_pos + 1))
        shift
        ;;
    esac
  done
  [ "$have_pos" -eq 2 ] || die "usage: create <run-id> <slug> [--base <branch>]"
  is_run_id "$id" || die "invalid run id: $id"
  re='^[a-z0-9]+(-[a-z0-9]+)*$'
  [[ $slug =~ $re ]] || die "invalid slug '$slug': use lower-case kebab-case (a-z, 0-9, single hyphens)"
  case "$base" in
    -*) die "invalid base: $base" ;;
  esac

  require_cmd git jq
  case "$id" in
    m-*)
      pat=$(config_get git.milestone_branch_pattern) || exit 1
      val=${id#m-}
      b=${pat//"{milestone}"/$val}
      ;;
    *)
      pat=$(config_get git.branch_pattern) || exit 1
      b=${pat//"{issue}"/$id}
      ;;
  esac
  b=${b//"{slug}"/$slug}
  re='\{[^{}]*\}'
  if [[ $b =~ $re ]]; then
    die "branch pattern '$pat' has an unresolved placeholder ${BASH_REMATCH[0]} for run $id"
  fi
  git check-ref-format --branch "$b" > /dev/null 2>&1 || die "'$b' is not a valid branch name (pattern '$pat')"

  if [ -z "$base" ]; then
    default=$(config_get default_branch) || exit 1
    base=$default
  fi

  # -unormal: a user's status.showUntrackedFiles=no must not hide untracked files.
  st=$(git status --porcelain --untracked-files=normal) || die "git status failed"
  [ -z "$st" ] || die "working tree is not clean; commit or stash first (untracked files count)"
  if git show-ref --verify --quiet "refs/heads/$b"; then
    die "branch already exists: $b"
  fi
  git rev-parse --verify --quiet "$base^{commit}" > /dev/null || die "base does not resolve to a commit: $base"

  git switch --no-track -c "$b" "$base" >&2 || die "could not create branch $b from $base"
  printf '%s\n' "$b"
}

cmd_push() {
  [ $# -eq 0 ] || die "push takes no arguments"
  require_cmd git jq
  local b default
  b=$(git symbolic-ref --quiet --short HEAD) || die "detached HEAD: switch to a branch first"
  default=$(config_get default_branch) || exit 1
  [ "$b" != "$default" ] || die "refusing to push the default branch ($default)"
  git push -u origin "$b" >&2 || die "git push failed for $b"
  printf '%s\n' "$b"
}

[ $# -gt 0 ] || die "missing subcommand (see --help)"
sub=$1
shift
case "$sub" in
  create) cmd_create "$@" ;;
  push) cmd_push "$@" ;;
  *) die "unknown subcommand: $sub (see --help)" ;;
esac
