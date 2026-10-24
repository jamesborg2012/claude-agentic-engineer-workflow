#!/usr/bin/env bats
# Tests for scripts/hooks/session-start.sh (the active-run hint).

load helpers/common

setup() {
  common_setup
  setup_project
  HOOKS_FIX="$FIXTURES/hooks"
  PAYLOAD=$(jq -c --arg cwd "$PROJECT" '.cwd = $cwd' "$HOOKS_FIX/sessionstart.json")
}

ctx() { jq -r '.hookSpecificOutput.additionalContext' <<<"$output"; }

@test "an active run produces the hint" {
  seed_run 12
  "$SCRIPTS/state.sh" stage develop
  run_hook session-start.sh "$PAYLOAD"
  assert_success
  assert_equal "$(jq -r '.hookSpecificOutput.hookEventName' <<<"$output")" "SessionStart"
  assert_equal "$(ctx)" "Active aew run 12 at stage develop (running). Use /aew:resume."
}

@test "blocked and failed runs are still shown" {
  seed_run 12
  "$SCRIPTS/state.sh" status blocked
  run_hook session-start.sh "$PAYLOAD"
  assert_success
  assert_contains "$(ctx)" "(blocked)"
  "$SCRIPTS/state.sh" status failed
  run_hook session-start.sh "$PAYLOAD"
  assert_success
  assert_contains "$(ctx)" "(failed)"
}

@test "a done run is silent" {
  seed_run 12
  "$SCRIPTS/state.sh" status done
  run_hook session-start.sh "$PAYLOAD"
  assert_success
  assert_equal "$output" ""
}

@test "no current run is silent on stdout and stderr" {
  run_hook session-start.sh "$PAYLOAD"
  assert_success
  assert_equal "$output" ""
  assert_equal "$stderr" ""
}

@test "a current run with no state.json warns and prints nothing" {
  mkdir -p .aew/runs
  printf '7\n' > .aew/runs/current
  run_hook session-start.sh "$PAYLOAD"
  assert_success
  assert_equal "$output" ""
  assert_contains "$stderr" "warning"
}

@test "it works for every source value" {
  seed_run 12
  local s
  for s in startup resume clear compact fork; do
    run_hook session-start.sh "$(jq -c --arg s "$s" '.source = $s' <<<"$PAYLOAD")"
    assert_success
    assert_contains "$(ctx)" "Active aew run 12"
  done
}

@test "a milestone run id is shown as is" {
  seed_run m-3
  run_hook session-start.sh "$PAYLOAD"
  assert_success
  assert_contains "$(ctx)" "Active aew run m-3 at stage"
}

@test "it runs in under a second" {
  seed_run 12
  local ms
  ms=$(elapsed_ms "$SCRIPTS/hooks/session-start.sh" <<<"$PAYLOAD")
  [ "$ms" -lt 1000 ]
}
