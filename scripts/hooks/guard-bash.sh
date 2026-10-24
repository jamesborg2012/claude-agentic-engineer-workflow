#!/usr/bin/env bash
# Usage: guard-bash.sh < payload.json
#
# PreToolUse hook for the Bash tool (DESIGN section 11). Denies, with a reason,
# commands aew must never run: pushes to the default branch, force pushes,
# `gh pr merge`, `gh repo delete`, `git reset --hard` on the default branch,
# `git clean -fdx`, recursive `rm` outside the project (or of a `.git` path),
# and any `gh` command from an aew agent.
# Active only in repos with .aew/config.json; every failure allows.
# A deny is `hookSpecificOutput.permissionDecision: "deny"` on exit 0.
#
# Rules, in the order the parser applies them:
# - Backslash-newline continuations are joined. The command is split into
#   segments on &&, ||, |, ; and newlines, then into tokens. Quotes,
#   backslashes, redirections (also when glued to a word, as in main>log) and
#   leading ( { and trailing ) } are stripped, and a & (lone or glued) ends a
#   command. Prefix words (VAR=x, sudo, env, command, nohup, time, nice,
#   timeout and its duration, if, then, ...) are skipped. The command is the
#   basename of the first token.
# - `cd <dir>` (or pushd) moves the working directory for later segments; a
#   dir holding $ or a backtick makes later relative rm targets unknown.
# - git: `-C <dir>` sets the directory whose branch the rules below check;
#   other global options (-c, --git-dir, ...) are skipped. push: force flags
#   (--forc* abbreviations, --force-if-includes, a short cluster containing f,
#   a +refspec) are denied, as is --all/--mirror, any refspec whose destination
#   is the default branch, and a bare push while on it. reset --hard (or --ha,
#   --har) is denied on the default branch. clean is denied when the flags give
#   f, d and lower-case x.
# - The branch used by those rules is the target of the latest `git switch` or
#   `git checkout` in the same command (the new name for -c/-C/-b/-B), else the
#   branch checked out at hook time.
# - gh: inside an aew agent (the payload's agent_type starts with aew:) every
#   gh command is denied, because only the orchestrator talks to GitHub.
#   Otherwise `pr merge` and `repo delete` are denied.
# - rm: a recursive rm is denied when a target has a .git path component
#   or a dot-glob matching .git (.*, .g*) ("rm of git internals"), holds an
#   unexpanded variable or substitution, or is not strictly inside the repo's
#   top level (so `/`, `~`, `..`, `*` at the root and the repo root are
#   denied). One comma brace group ({a,b}) is expanded; more are denied.
#
# Limits: a heuristic safety net, not a sandbox. It does not look inside
# `bash -c`, `sh -c`, `eval`, $(...) or backticks, aliases, functions or
# xargs, does not parse `sudo`/`env`/`exec` options that take a value, and
# does not resolve `git -C "$dir"` or `gh api` calls. Quoted text containing
# ; | & or && is split too, and heredoc lines are scanned as commands, so
# false positives are possible.
# The agent gh rule matches the gh command itself, so an agent calling the
# plugin's scripts/gh-*.sh wrappers by path is not caught (agent prompts
# never name them).

# shellcheck source=../lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
# shellcheck source=../lib/hooks.sh
. "$(dirname "${BASH_SOURCE[0]}")/../lib/hooks.sh"

DEFAULT_BRANCH=""
SWITCHED=""
CURSEG=""
CT=()
A=()
AN=0
CANON=""
CWD_UNKNOWN=0
ecwd=""
AGENT_TYPE=""

# An unbound variable or a syntax error fails open silently (bash 3.2), so
# every array expansion that can be empty is written ${a[@]+"${a[@]}"} and every
# function ends with an explicit return 0.

deny() {
  local r="aew guard: blocked $1 in \"$CURSEG\"${2-. aew never does this; if it is needed, James runs it himself.}"
  jq -n --arg r "$r" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}' || exit 0
  exit 0
}

need_default() {
  if [ -z "$DEFAULT_BRANCH" ]; then
    DEFAULT_BRANCH=$(config_get default_branch) || {
      warn "cannot read default_branch; failing open"
      exit 0
    }
  fi
  return 0
}

branch_of() {
  local b
  b=$(git -C "$1" symbolic-ref --short -q HEAD 2> /dev/null) || b=""
  printf '%s\n' "$b"
  return 0
}

toplevel_of() {
  local t
  t=$(git -C "$1" rev-parse --show-toplevel 2> /dev/null) || t=""
  if [ -n "$t" ]; then t=$(cd "$t" 2> /dev/null && pwd -P) || t=""; fi
  printf '%s\n' "$t"
  return 0
}

# The branch the rules compare against: the latest switch target, else HEAD's.
eff_branch() {
  if [ -n "$SWITCHED" ]; then
    printf '%s\n' "$SWITCHED"
  else
    branch_of "$1"
  fi
  return 0
}

# resolve_dir <base> <path>: physical path when it exists, else the joined path.
resolve_dir() {
  local p=$2 r
  case "$p" in
    /*) ;;
    *) p=$1/$p ;;
  esac
  if r=$(cd "$p" 2> /dev/null && pwd -P); then printf '%s\n' "$r"; else printf '%s\n' "$p"; fi
  return 0
}

# canon_path <path> <base>: sets CANON, lexically normalised with the nearest
# existing ancestor made physical (macOS /var is /private/var).
canon_path() {
  local p=$1 s="" part rest="" q base parts
  parts=()
  case "$p" in
    /*) ;;
    *) p=$2/$p ;;
  esac
  IFS=/ read -r -a parts <<< "$p" || true
  for part in ${parts[@]+"${parts[@]}"}; do
    case "$part" in
      '' | .) ;;
      ..) s=${s%/*} ;;
      *) s=$s/$part ;;
    esac
  done
  q=$s
  while [ -n "$q" ] && [ ! -d "$q" ]; do
    rest=/${q##*/}$rest
    q=${q%/*}
  done
  base=""
  if [ -n "$q" ]; then base=$(cd "$q" 2> /dev/null && pwd -P) || base=$q; fi
  if [ "$base" = "/" ]; then base=""; fi
  CANON=$base$rest
  if [ -z "$CANON" ]; then CANON=/; fi
  return 0
}

# rm_glob_git: deny when a component of CANON is a glob that matches .git
# (.*, .g*, .[g]it). Without a leading dot a glob never matches a dotfile.
rm_glob_git() {
  local c comps g=.git
  comps=()
  IFS=/ read -r -a comps <<< "$CANON" || true
  for c in ${comps[@]+"${comps[@]}"}; do
    case "$c" in
      .*['*?[']*)
        # shellcheck disable=SC2254  # $c is matched as a glob on purpose
        case "$g" in
          $c) deny "rm of git internals" ;;
        esac
        ;;
    esac
  done
  return 0
}

# rm_expand_braces: expands one comma brace group per target in guard_rm's
# targets ({a,b}, .{git,x}). The tokeniser has already dropped a trailing }.
# A target with a second or nested group is denied.
rm_expand_braces() {
  local k=0 t pre rest body suf a alts ex ne=0
  ex=()
  while [ "$k" -lt "$nt" ]; do
    t=${targets[$k]}
    k=$((k + 1))
    case "$t" in
      *\{*,*)
        pre=${t%%\{*}
        rest=${t#*\{}
        case "$rest" in
          *\}*)
            body=${rest%%\}*}
            suf=${rest#*\}}
            ;;
          *)
            body=$rest
            suf=""
            ;;
        esac
        case "$body$suf" in
          *\{*) deny "rm with more than one brace expansion" ;;
        esac
        alts=()
        IFS=, read -r -a alts <<< "$body" || true
        for a in ${alts[@]+"${alts[@]}"}; do
          ex[ne]=$pre$a$suf
          ne=$((ne + 1))
        done
        case "$body" in
          *,)
            ex[ne]=$pre$suf
            ne=$((ne + 1))
            ;;
        esac
        ;;
      *)
        ex[ne]=$t
        ne=$((ne + 1))
        ;;
    esac
  done
  targets=(${ex[@]+"${ex[@]}"})
  nt=$ne
  return 0
}

guard_rm() {
  local j=0 t rec=0 endopt=0 targets nt=0 k top hp
  targets=()
  while [ "$j" -lt "$AN" ]; do
    t=${A[$j]}
    j=$((j + 1))
    if [ "$endopt" -eq 1 ]; then
      targets[nt]=$t
      nt=$((nt + 1))
      continue
    fi
    case "$t" in
      --) endopt=1 ;;
      # GNU rm accepts abbreviations (--rec); it has no other --r option.
      --r*) rec=1 ;;
      --*) ;;
      -[!-]*)
        case "$t" in
          *r* | *R*) rec=1 ;;
        esac
        ;;
      *)
        targets[nt]=$t
        nt=$((nt + 1))
        ;;
    esac
  done
  if [ "$rec" -eq 0 ]; then return 0; fi
  rm_expand_braces
  k=0
  while [ "$k" -lt "$nt" ]; do
    t=${targets[$k]}
    k=$((k + 1))
    case "$t" in
      *'$'* | *'`'*) deny "rm with an unexpanded variable or command substitution" ;;
    esac
    # shellcheck disable=SC2088  # a literal ~ is matched on purpose
    case "$t" in
      '~') t=${HOME:-/nonexistent} ;;
      '~/'*) t=${HOME:-/nonexistent}/${t:2} ;;
      '~'*) deny "rm of a ~user path" ;;
    esac
    case "$t" in
      /*) ;;
      *) if [ "$CWD_UNKNOWN" -eq 1 ]; then deny "recursive rm after cd to an unexpanded path"; fi ;;
    esac
    # A last component of only * (*, **) means everything in its directory.
    case "${t##*/}" in
      '' | *[!*]*) ;;
      *)
        case "$t" in
          */*) t=${t%/*} ;;
          *) t=. ;;
        esac
        if [ -z "$t" ]; then t=/; fi
        ;;
    esac
    canon_path "$t" "$ecwd"
    case "/$CANON/" in
      */.git/*) deny "rm of git internals" ;;
    esac
    rm_glob_git
    top=$(toplevel_of "$ecwd")
    if [ -z "$top" ]; then deny "recursive rm outside a git repository"; fi
    hp=$(cd "${HOME:-/nonexistent}" 2> /dev/null && pwd -P) || hp=${HOME:-/nonexistent}
    if [ "$CANON" = "$hp" ] || [ "$CANON" = "${HOME:-/nonexistent}" ]; then deny "recursive rm of the home directory"; fi
    case "$CANON" in
      "$top"/*) ;;
      *) deny "recursive rm outside the project" ;;
    esac
  done
  return 0
}

guard_gh() {
  local j=0 t p1="" p2=""
  case "$AGENT_TYPE" in
    aew:*) deny "gh from an aew agent" " (only the orchestrator talks to GitHub; put the request in your NEXT line)" ;;
  esac
  while [ "$j" -lt "$AN" ]; do
    t=${A[$j]}
    case "$t" in
      -R | --repo) j=$((j + 1)) ;;
      -*) ;;
      *)
        if [ -z "$p1" ]; then p1=$t; elif [ -z "$p2" ]; then p2=$t; fi
        ;;
    esac
    j=$((j + 1))
  done
  if [ "$p1" = "pr" ] && [ "$p2" = "merge" ]; then deny "gh pr merge"; fi
  if [ "$p1" = "repo" ] && [ "$p2" = "delete" ]; then deny "gh repo delete"; fi
  return 0
}

# git_push <first-arg-index> <git dir>
git_push() {
  local j=$1 gdir=$2 t endopt=0 force=0 all=0 np=0 k r dest br pos first=1
  pos=()
  while [ "$j" -lt "$AN" ]; do
    t=${A[$j]}
    j=$((j + 1))
    if [ "$endopt" -eq 1 ]; then
      pos[np]=$t
      np=$((np + 1))
      continue
    fi
    case "$t" in
      --) endopt=1 ;;
      -o | --push-option | --receive-pack | --exec) j=$((j + 1)) ;;
      # With --repo every positional is a refspec.
      --repo)
        j=$((j + 1))
        first=0
        ;;
      --repo=*) first=0 ;;
      # git accepts unambiguous abbreviations (--force-w is --force-with-lease).
      --forc*) force=1 ;;
      --all | --mirror) all=1 ;;
      --*) ;;
      -[!-]*)
        case "$t" in
          *f*) force=1 ;;
        esac
        ;;
      *)
        pos[np]=$t
        np=$((np + 1))
        ;;
    esac
  done
  if [ "$force" -eq 1 ]; then deny "force push"; fi
  k=$first
  while [ "$k" -lt "$np" ]; do
    case "${pos[$k]}" in
      +*) deny "force push" ;;
    esac
    k=$((k + 1))
  done
  need_default
  if [ "$all" -eq 1 ]; then deny "push of every branch includes '$DEFAULT_BRANCH'"; fi
  if [ "$np" -le "$first" ]; then
    br=$(eff_branch "$gdir")
    if [ "$br" = "$DEFAULT_BRANCH" ]; then deny "push to the default branch ($DEFAULT_BRANCH)"; fi
    return 0
  fi
  k=$first
  while [ "$k" -lt "$np" ]; do
    r=${pos[$k]}
    k=$((k + 1))
    dest=${r##*:}
    dest=${dest#refs/heads/}
    case "$dest" in
      HEAD | @) dest=$(eff_branch "$gdir") ;;
    esac
    if [ "$dest" = "$DEFAULT_BRANCH" ]; then deny "push to the default branch ($DEFAULT_BRANCH)"; fi
  done
  return 0
}

git_reset() {
  local j=$1 gdir=$2 hard=0 br
  while [ "$j" -lt "$AN" ]; do
    case "${A[$j]}" in
      --ha | --har | --hard) hard=1 ;;
    esac
    j=$((j + 1))
  done
  if [ "$hard" -eq 0 ]; then return 0; fi
  need_default
  br=$(eff_branch "$gdir")
  if [ "$br" = "$DEFAULT_BRANCH" ]; then deny "git reset --hard on the default branch ($DEFAULT_BRANCH)"; fi
  return 0
}

git_clean() {
  local j=$1 t letters=""
  while [ "$j" -lt "$AN" ]; do
    t=${A[$j]}
    j=$((j + 1))
    case "$t" in
      --f | --fo | --for | --forc | --force) letters="${letters}f" ;;
      --*) ;;
      -[!-]*) letters="$letters${t#-}" ;;
    esac
  done
  case "$letters" in
    *f*)
      case "$letters" in
        *d*)
          case "$letters" in
            *x*) deny "git clean -fdx" ;;
          esac
          ;;
      esac
      ;;
  esac
  return 0
}

# git_switch <first-arg-index> <git dir>: records the target of the latest
# switch/checkout in SWITCHED. A `--` argument means a file checkout.
git_switch() {
  local j=$1 gdir=$2 t newb="" pick="" dd=0
  while [ "$j" -lt "$AN" ]; do
    t=${A[$j]}
    j=$((j + 1))
    case "$t" in
      --) dd=1 ;;
      -c | -C | -b | -B | --create | --force-create | --orphan)
        if [ "$j" -lt "$AN" ]; then newb=${A[$j]}; fi
        j=$((j + 1))
        ;;
      -*) ;;
      *)
        if [ -z "$pick" ]; then pick=$t; fi
        ;;
    esac
  done
  if [ "$dd" -eq 1 ]; then return 0; fi
  if [ -n "$newb" ]; then
    SWITCHED=$newb
    return 0
  fi
  if [ -z "$pick" ]; then return 0; fi
  need_default
  # A positional that is not a local branch may be a file; leave the target alone.
  if [ "$pick" = "$DEFAULT_BRANCH" ]; then
    SWITCHED=$pick
  elif git -C "$gdir" show-ref --verify -q "refs/heads/$pick" 2> /dev/null; then
    SWITCHED=$pick
  fi
  return 0
}

guard_git() {
  local j=0 t gdir=$ecwd sub
  while [ "$j" -lt "$AN" ]; do
    t=${A[$j]}
    case "$t" in
      -C)
        j=$((j + 1))
        if [ "$j" -lt "$AN" ]; then gdir=$(resolve_dir "$gdir" "${A[$j]}"); fi
        j=$((j + 1))
        ;;
      -c | --git-dir | --work-tree | --namespace | --config-env) j=$((j + 2)) ;;
      -*) j=$((j + 1)) ;;
      *) break ;;
    esac
  done
  if [ "$j" -ge "$AN" ]; then return 0; fi
  sub=${A[$j]}
  j=$((j + 1))
  case "$sub" in
    push) git_push "$j" "$gdir" ;;
    reset) git_reset "$j" "$gdir" ;;
    clean) git_clean "$j" ;;
    switch | checkout) git_switch "$j" "$gdir" ;;
  esac
  return 0
}

do_cd() {
  local j=0 t target="" d
  while [ "$j" -lt "$AN" ]; do
    t=${A[$j]}
    j=$((j + 1))
    case "$t" in
      --) ;;
      -*) ;;
      *)
        target=$t
        break
        ;;
    esac
  done
  # shellcheck disable=SC2088  # a literal ~ is matched on purpose
  case "$target" in
    *'$'* | *'`'*)
      # Unknown directory: later relative rm targets are denied.
      CWD_UNKNOWN=1
      return 0
      ;;
    -) return 0 ;;
    '') target=${HOME:-} ;;
    '~') target=${HOME:-} ;;
    '~/'*) target=${HOME:-}/${target:2} ;;
  esac
  if [ -z "$target" ]; then return 0; fi
  if d=$(cd "$ecwd" 2> /dev/null && cd "$target" 2> /dev/null && pwd -P); then
    ecwd=$d
    case "$target" in
      /*) CWD_UNKNOWN=0 ;;
    esac
  fi
  return 0
}

# check_cmd: CT holds one command's tokens.
check_cmd() {
  local n=${#CT[@]} i=0 t optskip=0 pfx="" dur=0 base
  if [ "$n" -eq 0 ]; then return 0; fi
  while [ "$i" -lt "$n" ]; do
    t=${CT[$i]}
    if [[ $t =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
      i=$((i + 1))
      continue
    fi
    if [ "$optskip" -eq 1 ]; then
      case "$pfx:$t" in
        timeout:-s | timeout:-k | nice:-n)
          i=$((i + 2))
          continue
          ;;
        *:-*)
          i=$((i + 1))
          continue
          ;;
      esac
    fi
    # timeout's DURATION operand comes before the command.
    if [ "$dur" -eq 1 ]; then
      dur=0
      i=$((i + 1))
      continue
    fi
    case "$t" in
      sudo | env | command | time | nice | timeout)
        optskip=1
        pfx=$t
        if [ "$t" = timeout ]; then dur=1; fi
        i=$((i + 1))
        ;;
      builtin | exec | nohup | '!' | if | then | elif | else | do | while | until) i=$((i + 1)) ;;
      *) break ;;
    esac
  done
  if [ "$i" -ge "$n" ]; then return 0; fi
  base=${CT[$i]##*/}
  A=()
  AN=0
  i=$((i + 1))
  while [ "$i" -lt "$n" ]; do
    A[AN]=${CT[$i]}
    AN=$((AN + 1))
    i=$((i + 1))
  done
  case "$base" in
    cd | pushd) do_cd ;;
    git) guard_git ;;
    gh) guard_gh ;;
    rm) guard_rm ;;
  esac
  return 0
}

# process_segment <text>: tokenise, normalise, split on a lone &, check each command.
process_segment() {
  local toks t r skip=0 first=1 n idx=0
  toks=()
  CT=()
  read -r -a toks <<< "$1" || true
  n=${#toks[@]}
  while [ "$idx" -lt "$n" ]; do
    t=${toks[$idx]}
    idx=$((idx + 1))
    t=${t//\'/}
    t=${t//\"/}
    t=${t//\\/}
    if [ "$skip" -eq 1 ]; then
      skip=0
      continue
    fi
    if [ "$first" -eq 1 ]; then
      while :; do
        case "$t" in
          "("* | "{"*) t=${t#?} ;;
          *) break ;;
        esac
      done
    fi
    while :; do
      case "$t" in
        *")" | *"}") t=${t%?} ;;
        *) break ;;
      esac
    done
    if [ "$t" = "&" ]; then
      check_cmd
      CT=()
      first=1
      continue
    fi
    if [ -z "$t" ]; then continue; fi
    case "$t" in
      '&>'* | '>'* | '<'* | [0-9]'>'* | [0-9]'<'*)
        case "$t" in
          *'>' | *'<') skip=1 ;;
        esac
        continue
        ;;
    esac
    # A redirection glued to a word (main>/dev/null, main&>log): keep the word.
    case "$t" in
      *'>'* | *'<'*)
        r=${t%%[<>]*}
        case "$t" in
          *'>' | *'<') skip=1 ;;
        esac
        t=${r%&}
        case "$t" in
          *[!0-9]*) ;;
          *) continue ;;
        esac
        ;;
    esac
    # A & glued to a word (main&, sleep 1&git) ends the command there.
    while :; do
      case "$t" in
        *'&'*) ;;
        *) break ;;
      esac
      r=${t%%&*}
      t=${t#*&}
      if [ -n "$r" ]; then CT[${#CT[@]}]=$r; fi
      check_cmd
      CT=()
    done
    if [ -z "$t" ]; then
      first=1
      continue
    fi
    first=0
    CT[${#CT[@]}]=$t
  done
  check_cmd
  return 0
}

hook_init "$@"

cmd=$(hook_field .tool_input.command) || exit 0
if [ -z "$cmd" ]; then exit 0; fi
AGENT_TYPE=$(hook_field .agent_type) || AGENT_TYPE=""

ecwd=$(cd "$HOOK_CWD" 2> /dev/null && pwd -P) || ecwd=$HOOK_ROOT

cmd=${cmd//$'\\\n'/ }
cmd=${cmd//&&/$'\n'}
cmd=${cmd//||/$'\n'}
cmd=${cmd//|/$'\n'}
cmd=${cmd//;/$'\n'}

while IFS= read -r seg || [ -n "$seg" ]; do
  CURSEG=$seg
  process_segment "$seg"
done <<< "$cmd"

exit 0
