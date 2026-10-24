#!/usr/bin/env bats
# Tests for scripts/lib/hooks.sh (the shared hook preamble).
# STUB_TAIL holds code that the stub evaluates, so the single quotes are intentional.
# shellcheck disable=SC2016,SC2089,SC2090

load helpers/common

setup() {
  common_setup
  HOOKS_FIX="$FIXTURES/hooks"
}

# make_stub: write $BATS_TEST_TMPDIR/stub.sh; $STUB_TAIL (if set) runs last.
make_stub() {
  cat > "$BATS_TEST_TMPDIR/stub.sh" <<STUB
#!/usr/bin/env bash
# Usage: stub.sh < payload.json
#
# Test stub for hook_init.
. "$SCRIPTS/lib/common.sh"
. "$SCRIPTS/lib/hooks.sh"
hook_init "\$@"
printf 'cwd=%s root=%s pwd=%s\n' "\$HOOK_CWD" "\$HOOK_ROOT" "\$PWD"
${STUB_TAIL:-}
STUB
  chmod +x "$BATS_TEST_TMPDIR/stub.sh"
}

# run_stub <payload> [arg…]
run_stub() {
  local payload=$1
  shift
  make_stub
  run --separate-stderr "$BATS_TEST_TMPDIR/stub.sh" "$@" <<<"$payload"
}

# payload_for <fixture> <cwd>
payload_for() {
  jq -c --arg cwd "$2" '.cwd = $cwd' "$HOOKS_FIX/$1"
}

@test "hooks.sh --help prints usage; running it otherwise is refused" {
  run --separate-stderr bash "$SCRIPTS/lib/hooks.sh" --help
  assert_success
  assert_contains "$output" "Usage:"
  run --separate-stderr bash "$SCRIPTS/lib/hooks.sh" foo
  assert_failure 1
  assert_contains "$stderr" "is a library"
}

@test "fixtures are valid JSON with the documented fields" {
  assert_json "$HOOKS_FIX/pretooluse-bash.json" '.tool_name == "Bash" and (.tool_input.command | type == "string") and .tool_use_id'
  assert_json "$HOOKS_FIX/pretooluse-edit.json" '.tool_name == "Edit" and (.tool_input.file_path | startswith("/")) and .old_string == null and .tool_input.old_string and .tool_input.new_string'
  assert_json "$HOOKS_FIX/subagentstop.json" '.stop_hook_active == false and .agent_type == "aew:developer" and .agent_id and .agent_transcript_path and .last_assistant_message'
  assert_json "$HOOKS_FIX/sessionstart.json" '.source == "startup" and .hook_event_name == "SessionStart"'
}

@test "--help works outside a git repo with stdin at /dev/null" {
  make_stub
  run --separate-stderr "$BATS_TEST_TMPDIR/stub.sh" --help < /dev/null
  assert_success
  assert_contains "$output" "Usage:"
}

@test "an unexpected argument exits 1, before the fail-open trap" {
  make_stub
  run --separate-stderr "$BATS_TEST_TMPDIR/stub.sh" --bogus < /dev/null
  assert_failure 1
  assert_equal "$output" ""
  assert_contains "$stderr" "error:"
}

@test "happy path in an aew project" {
  setup_project
  mkdir -p sub
  run_stub "$(payload_for pretooluse-bash.json "$PROJECT/sub")"
  assert_success
  assert_equal "$output" "cwd=$PROJECT/sub root=$PROJECT pwd=$PROJECT"
}

@test "CLAUDE_PROJECT_DIR beats the payload cwd" {
  setup_project
  local other="$BATS_TEST_TMPDIR/not-git"
  mkdir -p "$other"
  CLAUDE_PROJECT_DIR=$PROJECT run_stub "$(payload_for pretooluse-bash.json "$other")"
  assert_success
  assert_contains "$output" "root=$PROJECT"
}

@test "no CLAUDE_PROJECT_DIR and no cwd key falls back to PWD" {
  setup_project
  run_stub "$(jq -c 'del(.cwd)' "$HOOKS_FIX/pretooluse-bash.json")"
  assert_success
  assert_contains "$output" "root=$PROJECT"
  # $PWD may be the unresolved path (/var vs /private/var on macOS).
  assert_contains "$output" "/project root=$PROJECT pwd="
}

@test "a linked worktree resolves to the main worktree root" {
  setup_project
  git worktree add -q "$BATS_TEST_TMPDIR/wt" -b feat/x
  local wt
  wt=$(cd "$BATS_TEST_TMPDIR/wt" && pwd -P)
  run_stub "$(payload_for pretooluse-bash.json "$wt")"
  assert_success
  assert_contains "$output" "root=$PROJECT"
  assert_contains "$output" "cwd=$wt "
}

@test "a non-git cwd is inert and silent" {
  local d="$BATS_TEST_TMPDIR/plain"
  mkdir -p "$d"
  run_stub "$(payload_for pretooluse-bash.json "$d")"
  assert_success
  assert_equal "$output" ""
  assert_equal "$stderr" ""
}

@test "a git repo without .aew is inert and silent" {
  setup_project --no-config
  rm -rf .aew
  run_stub "$(payload_for pretooluse-bash.json "$PROJECT")"
  assert_success
  assert_equal "$output" ""
  assert_equal "$stderr" ""
}

@test ".aew without config.json warns and is inert" {
  setup_project --no-config
  mkdir -p .aew
  run_stub "$(payload_for pretooluse-bash.json "$PROJECT")"
  assert_success
  assert_equal "$output" ""
  assert_contains "$stderr" "stub.sh: warning:"
  assert_contains "$stderr" "config.json is missing"
}

@test "missing jq disables the hook with a warning" {
  mkdir -p "$BATS_TEST_TMPDIR/nojq"
  ln -s "$(command -v bash)" "$BATS_TEST_TMPDIR/nojq/bash"
  ln -s "$(command -v dirname)" "$BATS_TEST_TMPDIR/nojq/dirname"
  make_stub
  run --separate-stderr /usr/bin/env PATH="$BATS_TEST_TMPDIR/nojq" "$BATS_TEST_TMPDIR/stub.sh" <<<'{}'
  assert_success
  assert_equal "$output" ""
  assert_contains "$stderr" "jq not found"
}

@test "an unreadable payload fails open" {
  setup_project
  local p
  for p in '' 'not json' '[]' 'null' '   ' '"str"' '{"cwd":"/x"} {"cwd":"/y"}'; do
    run_stub "$p"
    assert_success
    refute_contains "$output" "cwd="
    assert_contains "$stderr" "unreadable hook payload"
  done
}

@test "stop_hook_active true allows the stop; false or absent proceeds" {
  setup_project
  run_stub "$(payload_for subagentstop.json "$PROJECT" | jq -c '.stop_hook_active = true')"
  assert_success
  refute_contains "$output" "cwd="
  assert_contains "$stderr" "stop_hook_active"
  run_stub "$(payload_for subagentstop.json "$PROJECT")"
  assert_success
  assert_contains "$output" "cwd="
  run_stub "$(payload_for subagentstop.json "$PROJECT" | jq -c 'del(.stop_hook_active)')"
  assert_success
  assert_contains "$output" "cwd="
}

@test "failures after init exit 0 and say they fail open" {
  setup_project
  local t
  for t in 'false' 'die boom' 'x=$(exit 3)'; do
    STUB_TAIL=$t run_stub "$(payload_for pretooluse-bash.json "$PROJECT")"
    assert_success
    assert_contains "$stderr" "failing open"
    if [ "$t" = "die boom" ]; then assert_contains "$stderr" "error: boom"; fi
  done
}

@test "an explicit exit 2 or an unbound variable after init still exits 0" {
  setup_project
  local t
  for t in 'exit 2' 'echo "$no_such_var"'; do
    STUB_TAIL=$t run_stub "$(payload_for pretooluse-bash.json "$PROJECT")"
    assert_success
  done
}

@test "hook_field returns strings, and empty for missing or null" {
  setup_project
  STUB_TAIL='printf "[%s][%s][%s]\n" "$(hook_field .tool_input.command)" "$(hook_field .tool_input.nope)" "$(hook_field .nothing)"'
  export STUB_TAIL
  run_stub "$(payload_for pretooluse-bash.json "$PROJECT" | jq -c '.nothing = null')"
  assert_success
  assert_contains "$output" "[ls -la][][]"
}
