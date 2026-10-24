#!/usr/bin/env bats
# Glob-driven convention checks over scripts/*.sh, scripts/lib/*.sh and
# scripts/hooks/*.sh. New scripts are picked up automatically; never edit this
# file to add one. Each test collects every offender and fails once, naming them.

load helpers/common

setup() {
  common_setup
}

# script_files <executables|libs|subcommand|all>: absolute paths, one per line.
script_files() {
  local kind=$1 f
  shopt -s nullglob
  case "$kind" in
    executables) for f in "$SCRIPTS"/*.sh "$SCRIPTS"/hooks/*.sh; do printf '%s\n' "$f"; done ;;
    libs) for f in "$SCRIPTS"/lib/*.sh; do printf '%s\n' "$f"; done ;;
    # A script whose Usage line names only optional arguments ("name [x]") may
    # succeed with none, so only scripts naming a required argument are kept.
    subcommand)
      for f in "$SCRIPTS"/*.sh; do
        case "$(sed -n '2s/^# Usage: [^ ]* *//p' "$f")" in
          '['*) ;;
          *) printf '%s\n' "$f" ;;
        esac
      done
      ;;
    all) for f in "$SCRIPTS"/*.sh "$SCRIPTS"/hooks/*.sh "$SCRIPTS"/lib/*.sh; do printf '%s\n' "$f"; done ;;
  esac
  shopt -u nullglob
  return 0
}

# Run a file as a non-git, config-free, stdin-less child. Sets status/output/stderr.
run_script() {
  local f=$1
  shift
  cd "$BATS_TEST_TMPDIR" || return 1
  case "$f" in
    "$SCRIPTS"/lib/*) run --separate-stderr env -u CLAUDE_PLUGIN_ROOT -u CLAUDE_PROJECT_DIR bash "$f" "$@" < /dev/null ;;
    *) run --separate-stderr env -u CLAUDE_PLUGIN_ROOT -u CLAUDE_PROJECT_DIR "$f" "$@" < /dev/null ;;
  esac
}

# Fail, listing the offenders, if any; also fail if the set was empty.
finish_check() {
  local what=$1 count=$2 offenders=$3
  if [ "$count" -eq 0 ]; then
    printf 'no files found for: %s\n' "$what" >&2
    return 1
  fi
  if [ -n "$offenders" ]; then
    printf 'convention violations (%s):\n%s' "$what" "$offenders" >&2
    return 1
  fi
}

@test "executables are +x with env-bash shebang and strict mode; libs have shebang and lib_main" {
  local f bad="" n=0 first last
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    n=$((n + 1))
    if [ ! -x "$f" ]; then bad="$bad  $f: not executable"$'\n'; fi
    first=$(head -n 1 "$f")
    if [ "$first" != "#!/usr/bin/env bash" ]; then bad="$bad  $f: bad shebang"$'\n'; fi
    if ! grep -qE 'lib/common\.sh|set -euo pipefail' "$f"; then
      bad="$bad  $f: does not source lib/common.sh or set -euo pipefail"$'\n'
    fi
  done < <(script_files executables)
  # No non-empty guard: scripts/*.sh and scripts/hooks/*.sh are empty until later phases.
  if [ -n "$bad" ]; then
    printf 'convention violations (executables):\n%s' "$bad" >&2
    return 1
  fi

  bad="" n=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    n=$((n + 1))
    first=$(head -n 1 "$f")
    if [ "$first" != "#!/usr/bin/env bash" ]; then bad="$bad  $f: bad shebang"$'\n'; fi
    last=$(tail -n 1 "$f")
    case "$last" in
      *lib_main*) ;;
      *) bad="$bad  $f: last line is not the lib_main line"$'\n' ;;
    esac
    if ! sed -n '2p' "$f" | grep -q '^# Usage:'; then bad="$bad  $f: line 2 is not '# Usage:'"$'\n'; fi
  done < <(script_files libs)
  finish_check "libs" "$n" "$bad"
}

@test "every file's line 2 starts a Usage: header block" {
  local f bad="" n=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    n=$((n + 1))
    if ! sed -n '2p' "$f" | grep -q '^# Usage:'; then bad="$bad  $f"$'\n'; fi
  done < <(script_files all)
  finish_check "usage header" "$n" "$bad"
}

@test "--help and -h exit 0 with Usage: on stdout, from a non-git directory" {
  local f opt bad="" n=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    n=$((n + 1))
    for opt in --help -h; do
      run_script "$f" "$opt"
      case "$output" in
        *Usage:*) ;;
        *) bad="$bad  $f $opt: stdout lacks Usage:"$'\n' ;;
      esac
      if [ "$status" -ne 0 ]; then bad="$bad  $f $opt: exit $status"$'\n'; fi
    done
  done < <(script_files all)
  finish_check "--help" "$n" "$bad"
}

@test "an unrecognised option exits 1 with empty stdout and error: on stderr" {
  local f bad="" n=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    n=$((n + 1))
    run_script "$f" --definitely-not-an-option
    if [ "$status" -ne 1 ]; then bad="$bad  $f: exit $status (want 1)"$'\n'; fi
    if [ -n "$output" ]; then bad="$bad  $f: stdout not empty"$'\n'; fi
    case "$stderr" in
      *error:*) ;;
      *) bad="$bad  $f: stderr lacks error:"$'\n' ;;
    esac
  done < <(script_files all)
  finish_check "bad option" "$n" "$bad"
}

@test "scripts whose Usage names a required argument exit 1 with no arguments, with error: on stderr" {
  local f bad=""
  # Vacuous until a subcommand script exists, so there is no non-empty guard.
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    run_script "$f"
    if [ "$status" -ne 1 ]; then bad="$bad  $f: exit $status (want 1)"$'\n'; fi
    case "$stderr" in
      *error:*) ;;
      *) bad="$bad  $f: stderr lacks error:"$'\n' ;;
    esac
  done < <(script_files subcommand)
  if [ -n "$bad" ]; then
    printf 'no-argument violations:\n%s' "$bad" >&2
    return 1
  fi
}

@test "no bash 4+ or GNU/BSD-divergent constructs in scripts, runner or helpers" {
  local patterns=(
    '(declare|local|typeset)[[:space:]]+-[a-zA-Z]*A'
    '(^|[^[:alnum:]_])(mapfile|readarray|coproc)([^[:alnum:]_]|$)'
    '\$\{[A-Za-z_][A-Za-z0-9_]*(,|\^)'
    '\$\{[A-Za-z_][A-Za-z0-9_]*@[QEPAaKk]\}'
    '(declare|local|typeset)[[:space:]]+-[a-zA-Z]*n'
    '\|&'
    '&>>'
    'wait[[:space:]]+-n'
    'globstar'
    'EPOCHREALTIME|EPOCHSECONDS|SRANDOM'
    '\$\{[A-Za-z_][A-Za-z0-9_]*\[-[0-9]+\]\}'
    'sed[[:space:]]+-[a-zA-Z]*i'
    'date[[:space:]]+-d'
    'stat[[:space:]]+-[cf]'
    'readlink[[:space:]]+-f'
    'grep[[:space:]]+-[a-zA-Z]*P'
  )
  local files=() f p hits bad="" n=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    files+=("$f")
  done < <(script_files all)
  files+=("$REPO_ROOT/tests/run-script-tests.sh")
  shopt -s nullglob
  for f in "$REPO_ROOT"/tests/scripts/helpers/*.bash "$REPO_ROOT"/tests/scripts/helpers/bin/*; do
    files+=("$f")
  done
  shopt -u nullglob
  for f in "${files[@]}"; do
    [ -f "$f" ] || continue
    n=$((n + 1))
    for p in "${patterns[@]}"; do
      hits=$(grep -n '' "$f" | sed 's/^\([0-9]*\):/\1: /' | grep -vE '^[0-9]+:[[:space:]]*#' | grep -E "^[0-9]+:.*($p)" || true)
      if [ -n "$hits" ]; then
        bad="$bad  $f: pattern '$p':"$'\n'"$hits"$'\n'
      fi
    done
  done
  finish_check "bash 3.2 lint" "$n" "$bad"
}
