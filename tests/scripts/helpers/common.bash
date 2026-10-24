# Shared bats helpers. Each bats file starts with `load helpers/common` and
# calls common_setup first in setup().
#
# bats injects status, output, stderr and BATS_* variables, so shellcheck
# cannot see them being assigned.
# shellcheck disable=SC2154
# FIXTURES is used by the bats files that load this helper.
# shellcheck disable=SC2034

bats_require_minimum_version 1.5.0

REPO_ROOT=$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)
SCRIPTS="$REPO_ROOT/scripts"
FIXTURES="$REPO_ROOT/tests/scripts/fixtures"
# Put the gh shim first so no test can reach the real gh.
PATH="$REPO_ROOT/tests/scripts/helpers/bin:$PATH"

common_setup() {
  unset CLAUDE_PLUGIN_ROOT CLAUDE_PROJECT_DIR
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
  export GIT_AUTHOR_NAME="Test" GIT_AUTHOR_EMAIL="test@example.com"
  export GIT_COMMITTER_NAME="Test" GIT_COMMITTER_EMAIL="test@example.com"
  export GH_MOCK_DIR="$BATS_TEST_TMPDIR/gh"
  mkdir -p "$GH_MOCK_DIR"
  cd "$BATS_TEST_TMPDIR" || return 1
}

setup_project() {
  local with_config=1
  if [ "${1:-}" = "--no-config" ]; then with_config=0; fi
  rm -rf "$BATS_TEST_TMPDIR/project"
  mkdir -p "$BATS_TEST_TMPDIR/project" || return 1
  cd "$BATS_TEST_TMPDIR/project" || return 1
  PROJECT=$(pwd -P) || return 1
  export PROJECT
  git init -q -b main . || return 1
  printf '.aew/runs/\n' > .gitignore
  if [ "$with_config" -eq 1 ]; then
    mkdir -p .aew
    cp "$REPO_ROOT/templates/config.example.json" .aew/config.json
  fi
  git add -A && git commit -q -m "initial" || return 1
}

write_config() {
  mkdir -p "$PROJECT/.aew"
  printf '%s' "$1" > "$PROJECT/.aew/config.json"
}

run_lib() {
  local lib=$1
  shift
  # shellcheck disable=SC2016  # the single quotes are intentional: expand in the child
  run --separate-stderr bash -c '. "$1"; shift; "$@"' "$lib" "$SCRIPTS/lib/$lib" "$@"
}

run_hook() {
  local hook=$1 payload=$2
  if [ "${payload#@}" != "$payload" ]; then
    run --separate-stderr "$SCRIPTS/hooks/$hook" < "${payload#@}"
  else
    run --separate-stderr "$SCRIPTS/hooks/$hook" <<<"$payload"
  fi
}

elapsed_ms() {
  # The command's stdin, stdout and stderr are discarded; only the integer is printed.
  ELAPSED_OUT="$BATS_TEST_TMPDIR/.elapsed" perl -MTime::HiRes=time -e '
    my $t = time;
    open(my $o, ">", $ENV{ELAPSED_OUT}) or die;
    open(STDIN, "<", "/dev/null");
    open(STDOUT, ">", "/dev/null");
    open(STDERR, ">", "/dev/null");
    system { $ARGV[0] } @ARGV;
    printf $o "%d\n", (time - $t) * 1000;
  ' "$@" < /dev/null > /dev/null 2>&1
  cat "$BATS_TEST_TMPDIR/.elapsed"
}

assert_success() {
  if [ "$status" -ne 0 ]; then
    printf 'expected success, got status %s\noutput: %s\nstderr: %s\n' "$status" "$output" "${stderr:-}" >&2
    return 1
  fi
}

assert_failure() {
  if [ "$status" -eq 0 ] || { [ -n "${1:-}" ] && [ "$status" -ne "$1" ]; }; then
    printf 'expected failure%s, got status %s\noutput: %s\nstderr: %s\n' "${1:+ $1}" "$status" "$output" "${stderr:-}" >&2
    return 1
  fi
}

assert_equal() {
  if [ "$1" != "$2" ]; then
    printf 'expected: %s\nactual:   %s\n' "$2" "$1" >&2
    return 1
  fi
}

assert_contains() {
  case "$1" in
    *"$2"*) ;;
    *) printf 'expected to contain: %s\nin: %s\n' "$2" "$1" >&2; return 1 ;;
  esac
}

refute_contains() {
  case "$1" in
    *"$2"*) printf 'expected NOT to contain: %s\nin: %s\n' "$2" "$1" >&2; return 1 ;;
  esac
}

assert_json() {
  if ! jq -e "$2" "$1" > /dev/null; then
    printf 'jq assertion failed: %s\nfile: %s\n' "$2" "$1" >&2
    return 1
  fi
}

validate_json_schema() {
  local schema=$1 args=() f
  shift
  for f in "$@"; do args+=(-d "$f"); done
  local out
  if ! out=$(cd "$REPO_ROOT" && npx --yes -p ajv-cli@5 -p ajv-formats@3 ajv validate --spec=draft2020 -c ajv-formats -s "$schema" "${args[@]}" 2>&1); then
    printf '%s\n' "$out" >&2
    return 1
  fi
}

# gh_mock_issue <n> [--from <json-file>] [--body-file <f>] [--body <s>] [--labels a,b,…]
gh_mock_issue() {
  local n=$1 from="" body_file="" body="" have_body=0 labels=""
  shift
  while [ $# -gt 0 ]; do
    case "$1" in
      --from) from=$2; shift 2 ;;
      --body-file) body_file=$2; have_body=1; shift 2 ;;
      --body) body=$2; have_body=2; shift 2 ;;
      --labels) labels=$2; shift 2 ;;
      *) echo "gh_mock_issue: unknown option $1" >&2; return 1 ;;
    esac
  done
  local d="$GH_MOCK_DIR/issues/$n"
  mkdir -p "$d" || return 1
  if [ -n "$from" ]; then
    jq 'del(.body, .labels)' "$from" > "$d/base.json" || return 1
    if [ "$have_body" -eq 0 ]; then jq -j '.body // ""' "$from" > "$d/body" || return 1; fi
    if [ -z "$labels" ]; then labels=$(jq -r '[.labels[]?.name] | join(",")' "$from") || return 1; fi
  else
    jq -n --argjson n "$n" '{number: $n, title: ("Issue " + ($n | tostring)), state: "OPEN", url: ("https://github.com/acme/widgets/issues/" + ($n | tostring))}' > "$d/base.json" || return 1
  fi
  case "$have_body" in
    1) cp "$body_file" "$d/body" ;;
    2) printf '%s' "$body" > "$d/body" ;;
    0) if [ ! -f "$d/body" ]; then : > "$d/body"; fi ;;
  esac
  if [ -n "$labels" ]; then
    printf '%s' "$labels" | tr ',' '\n' | grep -v '^$' | sort -u > "$d/labels" || true
  else
    : > "$d/labels"
  fi
}

gh_mock_body() { cat "$GH_MOCK_DIR/issues/$1/body"; }

gh_mock_labels() { cat "$GH_MOCK_DIR/issues/$1/labels"; }

# gh_mock_respond <route> <stdout-file|-> [exit-code] [call-number]
gh_mock_respond() {
  local route=$1 src=$2 code=${3:-0} k=${4:-}
  local base="$GH_MOCK_DIR/responses/$route${k:+.$k}"
  mkdir -p "$GH_MOCK_DIR/responses" || return 1
  if [ "$src" = "-" ]; then cat > "$base.out"; else cp "$src" "$base.out"; fi
  printf '%s' "$code" > "$base.code"
}

gh_calls() { cat "$GH_MOCK_DIR/calls.log" 2> /dev/null || true; }

assert_gh_called() {
  if ! gh_calls | grep -qF -- "$1"; then
    printf 'expected a gh call containing: %s\ncalls:\n%s\n' "$1" "$(gh_calls)" >&2
    return 1
  fi
}

refute_gh_called() {
  if gh_calls | grep -qF -- "$1"; then
    printf 'expected NO gh call containing: %s\ncalls:\n%s\n' "$1" "$(gh_calls)" >&2
    return 1
  fi
}

gh_call_count() {
  if [ -n "${1:-}" ]; then
    gh_calls | grep -cF -- "$1" || true
  else
    gh_calls | grep -c '' || true
  fi
}

gh_captured_file() {
  local idx nnn
  idx=$(gh_calls | grep -nF -- "$1" | tail -n 1 | cut -d: -f1) || return 1
  [ -n "$idx" ] || return 1
  nnn=$(printf '%03d' "$idx") || return 1
  find "$GH_MOCK_DIR/files" -name "$nnn-*" 2> /dev/null | head -n 1
}
