#!/usr/bin/env bats
# Tests for scripts/hooks/gate-subagent.sh (the SubagentStop gate).

load helpers/common

setup() {
  common_setup
  HOOKS_FIX="$FIXTURES/hooks"
  setup_project
  seed_run 12
  RD="$PROJECT/.aew/runs/12"
}

# payload [agent_type] [cwd] [stop_hook_active]
payload() {
  jq -c --arg a "${1:-aew:developer}" --arg c "${2:-$PROJECT}" --argjson s "${3:-false}" \
    '.agent_type = $a | .cwd = $c | .stop_hook_active = $s' "$HOOKS_FIX/subagentstop.json"
}

gate() { run_hook gate-subagent.sh "$(payload "$@")"; }

assert_allow() {
  assert_success
  assert_equal "$output" ""
}

assert_block() {
  assert_success
  assert_json <(printf '%s' "$output") '.decision == "block"'
  if [ -n "${1:-}" ]; then assert_contains "$output" "$1"; fi
}

dev_stage() { "$SCRIPTS/state.sh" stage develop; }

@test "developer: no report blocks" {
  dev_stage
  gate
  assert_block "06-dev-report"
  assert_json <(printf '%s' "$output") '.reason | startswith("aew gate:")'
  assert_contains "$output" ".aew/runs/12/"
  assert_contains "$output" "templates/artefacts/dev-report.md"
}

@test "developer: a valid report allows" {
  dev_stage
  cp "$HOOKS_FIX/dev-report-ok.md" "$RD/06-dev-report.md"
  gate
  assert_allow
}

@test "developer: the real template blocks (placeholder STATUS)" {
  dev_stage
  cp "$REPO_ROOT/templates/artefacts/dev-report.md" "$RD/06-dev-report.md"
  gate
  assert_block "STATUS"
}

@test "developer: STATUS ok needs a filled Commands run row" {
  dev_stage
  cp "$HOOKS_FIX/dev-report-no-commands.md" "$RD/06-dev-report.md"
  gate
  assert_block "Commands run"
  # a placeholder-only row does not count
  sed 's/^| Command | Result |$/| Command | Result |\n|---|---|\n| <lint command> | pass |/' \
    "$HOOKS_FIX/dev-report-no-commands.md" > "$RD/06-dev-report.md"
  gate
  assert_block "Commands run"
}

@test "developer: STATUS blocked needs no commands" {
  dev_stage
  cp "$HOOKS_FIX/dev-report-blocked.md" "$RD/06-dev-report.md"
  gate
  assert_allow
}

@test "developer: a report older than the state is stale" {
  dev_stage
  cp "$HOOKS_FIX/dev-report-ok.md" "$RD/06-dev-report.md"
  touch -t 202001010000 "$RD/06-dev-report.md"
  gate
  assert_block "earlier cycle"
  touch "$RD/06-dev-report.md"
  gate
  assert_allow
}

@test "developer: the newest report wins" {
  dev_stage
  cp "$HOOKS_FIX/dev-report-no-commands.md" "$RD/06-dev-report.md"
  touch -t 202001010000 "$RD/06-dev-report.md"
  cp "$HOOKS_FIX/dev-report-ok.md" "$RD/06-dev-report-WP2.md"
  gate
  assert_allow
  rm "$RD/06-dev-report-WP2.md" "$RD/06-dev-report.md"
  cp "$HOOKS_FIX/dev-report-ok.md" "$RD/06-dev-report.md"
  touch -t 202001010000 "$RD/06-dev-report.md"
  cp "$HOOKS_FIX/dev-report-no-commands.md" "$RD/06-dev-report-WP2.md"
  gate
  assert_block "Commands run"
}

@test "developer: return block variants" {
  dev_stage
  local f="$RD/06-dev-report.md" ok="$HOOKS_FIX/dev-report-ok.md"
  sed 's/$/\r/' "$ok" > "$f"
  gate
  assert_allow
  { cat "$ok"; printf '\n\n\n'; } > "$f"
  gate
  assert_allow
  { cat "$ok"; printf '\nMore text after the block.\n'; } > "$f"
  gate
  assert_block
  sed 's/^STATUS: ok/STATUS: done/' "$ok" > "$f"
  gate
  assert_block "STATUS must be one of"
  sed 's/^ARTEFACTS:.*/ARTEFACTS:/' "$ok" > "$f"
  gate
  assert_block
  { grep -v '^\(STATUS\|ARTEFACTS\|SUMMARY\|NEXT\):' "$ok"; grep '^ARTEFACTS:' "$ok"; grep '^STATUS:' "$ok"; grep '^SUMMARY:' "$ok"; grep '^NEXT:' "$ok"; } > "$f"
  gate
  assert_block
}

@test "developer: a linked worktree cwd uses the main project's run" {
  dev_stage
  git worktree add -q "$BATS_TEST_TMPDIR/wt" -b sub
  gate aew:developer "$BATS_TEST_TMPDIR/wt"
  assert_block "06-dev-report"
  cp "$HOOKS_FIX/dev-report-ok.md" "$RD/06-dev-report.md"
  gate aew:developer "$BATS_TEST_TMPDIR/wt"
  assert_allow
}

@test "qa: stage plan and qa_test_plan gate 04-qa-test-plan.md" {
  local s
  for s in plan qa_test_plan; do
    "$SCRIPTS/state.sh" stage "$s"
    rm -f "$RD/04-qa-test-plan.md"
    gate aew:qa-engineer
    assert_block "04-qa-test-plan.md"
    cp "$HOOKS_FIX/qa-test-plan-ok.md" "$RD/04-qa-test-plan.md"
    gate aew:qa-engineer
    assert_allow
    cp "$REPO_ROOT/templates/artefacts/qa-test-plan.md" "$RD/04-qa-test-plan.md"
    gate aew:qa-engineer
    assert_block "STATUS"
  done
}

@test "qa: stage qa gates 08-qa-report-<fix_cycle+1>.md" {
  "$SCRIPTS/state.sh" stage qa
  cp "$HOOKS_FIX/qa-report-ok.md" "$RD/08-qa-report-1.md"
  gate aew:qa-engineer
  assert_allow
  "$SCRIPTS/state.sh" bump fix_cycle
  gate aew:qa-engineer
  assert_block "08-qa-report-2.md"
  cp "$REPO_ROOT/templates/artefacts/qa-report.md" "$RD/08-qa-report-2.md"
  gate aew:qa-engineer
  assert_block "STATUS"
}

@test "qa: any other stage allows with a warning naming the stage" {
  dev_stage
  gate aew:qa-engineer
  assert_allow
  assert_contains "$stderr" "develop"
}

@test "other agent types are ignored silently" {
  dev_stage
  local a
  for a in general-purpose developer other:developer; do
    gate "$a"
    assert_allow
    assert_equal "$stderr" ""
  done
}

@test "stop_hook_active allows with a warning" {
  dev_stage
  gate aew:developer "$PROJECT" true
  assert_allow
  assert_contains "$stderr" "stop_hook_active"
}

@test "fail-open: no current run, missing state, corrupt state" {
  rm "$PROJECT/.aew/runs/current"
  gate
  assert_allow
  assert_contains "$stderr" "no current aew run"
  printf '12\n' > "$PROJECT/.aew/runs/current"
  mv "$RD/state.json" "$RD/state.json.bak"
  gate
  assert_allow
  assert_contains "$stderr" "state file missing"
  echo x > "$RD/state.json"
  gate
  assert_allow
  assert_contains "$stderr" "unreadable state file"
  printf '{}\n' > "$RD/state.json"
  gate
  assert_allow
  assert_contains "$stderr" "not gating"
}

@test "never exits 2 and --help works" {
  run --separate-stderr "$SCRIPTS/hooks/gate-subagent.sh" --help
  assert_success
  assert_contains "$output" "Usage:"
}

@test "timing: the ok paths are under 1000 ms" {
  dev_stage
  cp "$HOOKS_FIX/dev-report-ok.md" "$RD/06-dev-report.md"
  payload > "$BATS_TEST_TMPDIR/p.json"
  local ms
  ms=$(elapsed_ms bash -c "'$SCRIPTS/hooks/gate-subagent.sh' < '$BATS_TEST_TMPDIR/p.json'")
  [ "$ms" -lt 1000 ]
  "$SCRIPTS/state.sh" stage qa_test_plan
  cp "$HOOKS_FIX/qa-test-plan-ok.md" "$RD/04-qa-test-plan.md"
  payload aew:qa-engineer > "$BATS_TEST_TMPDIR/p.json"
  ms=$(elapsed_ms bash -c "'$SCRIPTS/hooks/gate-subagent.sh' < '$BATS_TEST_TMPDIR/p.json'")
  [ "$ms" -lt 1000 ]
}
