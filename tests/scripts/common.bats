#!/usr/bin/env bats

load helpers/common

setup() {
  common_setup
  LIB="$SCRIPTS/lib/common.sh"
}

@test "sourcing has no side effects and enables strict mode" {
  run --separate-stderr bash -c '. "$1"; echo ok' x "$LIB"
  assert_success
  assert_equal "$output" "ok"
  assert_equal "$stderr" ""
  run --separate-stderr bash -c '. "$1"; . "$1"; set -o | grep -E "^(errexit|nounset|pipefail)[[:space:]]+on" | wc -l | tr -d " "' x "$LIB"
  assert_success
  assert_equal "$output" "3"
}

@test "info, warn and die write to stderr with prefixes" {
  run_lib common.sh info hello
  assert_success
  assert_equal "$output" ""
  assert_equal "$stderr" "common.sh: hello"
  run_lib common.sh warn careful
  assert_success
  assert_equal "$output" ""
  assert_equal "$stderr" "common.sh: warning: careful"
  run_lib common.sh die boom
  assert_failure 1
  assert_equal "$output" ""
  assert_equal "$stderr" "common.sh: error: boom"
}

@test "die lets an EXIT trap replace the status (fail-open contract)" {
  run --separate-stderr bash -c '. "$1"; trap "exit 0" EXIT; die boom' x "$LIB"
  assert_success
  assert_contains "$stderr" "error: boom"
}

@test "require_cmd passes for present commands and names the first missing one" {
  run_lib common.sh require_cmd jq git
  assert_success
  run_lib common.sh require_cmd jq no-such-cmd-xyz
  assert_failure 1
  assert_contains "$stderr" "required command not found: no-such-cmd-xyz"
}

@test "plugin_root falls back to the repo and honours CLAUDE_PLUGIN_ROOT" {
  run_lib common.sh plugin_root
  assert_success
  assert_equal "$output" "$REPO_ROOT"
  CLAUDE_PLUGIN_ROOT=/x run_lib common.sh plugin_root
  assert_equal "$output" "/x"
  CLAUDE_PLUGIN_ROOT=/x/ run_lib common.sh plugin_root
  assert_equal "$output" "/x"
}

@test "plugin_root stays correct after the caller cds (relative source path)" {
  cd "$REPO_ROOT"
  run --separate-stderr bash -c '. scripts/lib/common.sh; cd /; plugin_root'
  assert_success
  assert_equal "$output" "$REPO_ROOT"
}

@test "repo_root returns the main worktree root from root, subdir and linked worktree" {
  setup_project
  run_lib common.sh repo_root
  assert_success
  assert_equal "$output" "$PROJECT"
  mkdir -p sub/dir
  cd sub/dir
  run_lib common.sh repo_root
  assert_equal "$output" "$PROJECT"
  cd "$PROJECT"
  git worktree add -q "$BATS_TEST_TMPDIR/wt" -b feat/x
  cd "$BATS_TEST_TMPDIR/wt"
  run_lib common.sh repo_root
  assert_success
  assert_equal "$output" "$PROJECT"
}

@test "repo_root accepts a directory argument and dies outside a repo" {
  setup_project
  cd "$BATS_TEST_TMPDIR"
  run_lib common.sh repo_root "$PROJECT"
  assert_success
  assert_equal "$output" "$PROJECT"
  mkdir -p "$BATS_TEST_TMPDIR/plain"
  cd "$BATS_TEST_TMPDIR/plain"
  run_lib common.sh repo_root
  assert_failure 1
  assert_equal "$output" ""
  assert_contains "$stderr" "not inside a git repository"
}

@test "config_get returns configured values" {
  setup_project
  write_config '{"default_branch":"trunk"}'
  run_lib common.sh config_get default_branch
  assert_success
  assert_equal "$output" "trunk"
}

@test "config_get serves leaf and whole-object defaults" {
  setup_project
  write_config '{"default_branch":"trunk"}'
  run_lib common.sh config_get git.branch_pattern
  assert_success
  assert_equal "$output" "feat/{issue}-{slug}"
  run_lib common.sh config_get git
  assert_success
  assert_equal "$output" '{"branch_pattern":"feat/{issue}-{slug}","milestone_branch_pattern":"feat/m{milestone}-{slug}","commit_convention":"conventional","commit_trailer":"Co-Authored-By: Claude <noreply@anthropic.com>"}'
}

@test "config_get falls back to an object-level default when the leaf has none" {
  setup_project
  write_config '{}'
  mkdir -p "$BATS_TEST_TMPDIR/plug/templates"
  jq 'del(.properties.limits.properties.max_fix_cycles.default)' "$REPO_ROOT/templates/config.schema.json" > "$BATS_TEST_TMPDIR/plug/templates/config.schema.json"
  CLAUDE_PLUGIN_ROOT="$BATS_TEST_TMPDIR/plug" run_lib common.sh config_get limits.max_fix_cycles
  assert_success
  assert_equal "$output" "3"
}

@test "config_get preserves false and prints non-strings as compact JSON" {
  setup_project
  write_config '{"gates":{"plan_approval":false}}'
  run_lib common.sh config_get gates.plan_approval
  assert_success
  assert_equal "$output" "false"
  write_config '{}'
  run_lib common.sh config_get limits
  assert_success
  assert_equal "$output" '{"max_fix_cycles":3,"max_review_cycles":2,"max_parallel_developers":4}'
  run_lib common.sh config_get limits.max_review_cycles
  assert_equal "$output" "2"
}

@test "config_get serves defaults when the config file is missing" {
  setup_project --no-config
  run_lib common.sh config_get default_branch
  assert_success
  assert_equal "$output" "main"
}

@test "config_get fails clearly for no default, invalid JSON, bad path and missing schema" {
  setup_project
  write_config '{}'
  run_lib common.sh config_get retro.repo
  assert_failure 1
  assert_equal "$output" ""
  assert_contains "$stderr" "no value or default for 'retro.repo'"
  write_config '{not json'
  run_lib common.sh config_get default_branch
  assert_failure 1
  assert_contains "$stderr" "invalid JSON"
  write_config '{}'
  run_lib common.sh config_get a..b
  assert_failure 1
  CLAUDE_PLUGIN_ROOT="$BATS_TEST_TMPDIR/nowhere" run_lib common.sh config_get default_branch
  assert_failure 1
  assert_contains "$stderr" "schema not found"
}

@test "is_run_id accepts schema-valid ids only" {
  run_lib common.sh is_run_id 12
  assert_success
  run_lib common.sh is_run_id m-3
  assert_success
  local bad
  for bad in 0 012 m-0 ../x 12/.. ""; do
    run_lib common.sh is_run_id "$bad"
    assert_failure 1
  done
}

@test "run_dir resolves explicit ids and rejects invalid ones" {
  setup_project
  run_lib common.sh run_dir 12
  assert_success
  assert_equal "$output" "$PROJECT/.aew/runs/12"
  run_lib common.sh run_dir ../etc
  assert_failure 1
  assert_contains "$stderr" "invalid run id: ../etc"
}

@test "run_dir reads the current run, tolerating CRLF, and dies when unset" {
  setup_project
  run_lib common.sh run_dir
  assert_failure 1
  assert_contains "$stderr" "no current run"
  mkdir -p .aew/runs
  printf '7\r\n' > .aew/runs/current
  run_lib common.sh run_dir
  assert_success
  assert_equal "$output" "$PROJECT/.aew/runs/7"
  printf '' > .aew/runs/current
  run_lib common.sh run_dir
  assert_failure 1
  assert_contains "$stderr" "no current run"
}

@test "run_dir resolves the main worktree's current run from a linked worktree" {
  setup_project
  mkdir -p .aew/runs
  printf '9\n' > .aew/runs/current
  git worktree add -q "$BATS_TEST_TMPDIR/wt" -b feat/y
  cd "$BATS_TEST_TMPDIR/wt"
  run_lib common.sh run_dir
  assert_success
  assert_equal "$output" "$PROJECT/.aew/runs/9"
}

@test "value functions print nothing outside a git repo (errexit-in-substitution guard)" {
  mkdir -p "$BATS_TEST_TMPDIR/plain"
  cd "$BATS_TEST_TMPDIR/plain"
  run_lib common.sh run_dir 12
  assert_failure 1
  assert_equal "$output" ""
  run_lib common.sh config_get default_branch
  assert_failure 1
  assert_equal "$output" ""
  run --separate-stderr bash -c '. "$1"; x=$(run_dir 12) || exit 1; echo "$x"' x "$LIB"
  assert_failure 1
  assert_equal "$output" ""
}

@test "print_usage prints the header block without comment prefixes" {
  printf '#!/usr/bin/env bash\n# Usage: foo <x>\n#\n#   more text\n\nset -e\n# not part of it\n' > "$BATS_TEST_TMPDIR/f.sh"
  run_lib common.sh print_usage "$BATS_TEST_TMPDIR/f.sh"
  assert_success
  assert_equal "$output" "$(printf 'Usage: foo <x>\n\n  more text')"
}

@test "common.sh run directly: --help prints usage, anything else is refused" {
  run --separate-stderr bash "$LIB" --help
  assert_success
  assert_contains "$output" "Usage:"
  run --separate-stderr bash "$LIB" foo
  assert_failure 1
  assert_contains "$stderr" "is a library"
}
