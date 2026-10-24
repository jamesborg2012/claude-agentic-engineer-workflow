#!/usr/bin/env bats
# Tests for the stateful gh PATH shim and the bats helpers (tests/scripts/helpers).

load helpers/common

setup() {
  common_setup
}

@test "gh on PATH is the shim" {
  run command -v gh
  assert_equal "$output" "$REPO_ROOT/tests/scripts/helpers/bin/gh"
}

@test "shim exits 99 without GH_MOCK_DIR" {
  unset GH_MOCK_DIR
  run --separate-stderr gh issue view 1
  assert_failure 99
  assert_contains "$stderr$output" "GH_MOCK_DIR not set"
}

@test "calls are logged one line each, newlines escaped" {
  run gh issue comment 5 --body "a
b"
  run gh label create x --force
  assert_equal "$(gh_call_count)" "2"
  assert_equal "$(gh_calls | sed -n 1p)" 'issue comment 5 --body a\nb'
  assert_gh_called "label create x --force"
  refute_gh_called "pr create"
  assert_equal "$(gh_call_count 'label create')" "1"
}

@test "issue view returns exact CRLF body, labels and only requested keys" {
  printf 'line1\r\nline2\r\n\r\ntail' > "$BATS_TEST_TMPDIR/in.md"
  gh_mock_issue 5 --body-file "$BATS_TEST_TMPDIR/in.md" --labels aew:building,bug
  gh issue view 5 --json body,labels > "$BATS_TEST_TMPDIR/out.json"
  jq -j .body "$BATS_TEST_TMPDIR/out.json" > "$BATS_TEST_TMPDIR/body.out"
  cmp "$BATS_TEST_TMPDIR/in.md" "$BATS_TEST_TMPDIR/body.out"
  run jq -c 'keys' "$BATS_TEST_TMPDIR/out.json"
  assert_equal "$output" '["body","labels"]'
  run jq -c '.labels' "$BATS_TEST_TMPDIR/out.json"
  assert_equal "$output" '[{"name":"aew:building"},{"name":"bug"}]'
}

@test "--jq and -q are applied" {
  gh_mock_issue 5 --body x --labels a,b
  run gh issue view 5 --json labels --jq '.labels[].name'
  assert_equal "$output" "$(printf 'a\nb')"
  run gh issue view 5 --json labels -q '.labels[0].name'
  assert_equal "$output" "a"
}

@test "issue edit replaces body byte-exact, captures the file, reads stdin" {
  gh_mock_issue 5 --body old
  printf 'new\r\nbody' > "$BATS_TEST_TMPDIR/f.md"
  gh issue edit 5 --body-file "$BATS_TEST_TMPDIR/f.md"
  gh_mock_body 5 > "$BATS_TEST_TMPDIR/got"
  cmp "$BATS_TEST_TMPDIR/f.md" "$BATS_TEST_TMPDIR/got"
  cmp "$BATS_TEST_TMPDIR/f.md" "$(gh_captured_file 'issue edit 5')"
  printf 'from stdin' | gh issue edit 5 --body-file -
  assert_equal "$(gh_mock_body 5)" "from stdin"
}

@test "issue edit labels: add, remove, sorted unique" {
  gh_mock_issue 5 --body x --labels aew:building,bug
  gh issue edit 5 --add-label a,b --remove-label aew:building --add-label a
  assert_equal "$(gh_mock_labels 5)" "$(printf 'a\nb\nbug')"
  gh issue edit 5 --remove-label nothere
  assert_equal "$(gh_mock_labels 5)" "$(printf 'a\nb\nbug')"
}

@test "unseeded issue view and edit fail with a GraphQL-style message" {
  run --separate-stderr gh issue view 404 --json body
  assert_failure 1
  assert_contains "$stderr" "Could not resolve to an issue or pull request with the number of 404"
  run --separate-stderr gh issue edit 404 --add-label x
  assert_failure 1
}

@test "canned responses: plain, call-specific, non-zero to stderr" {
  gh_mock_respond pr-create - <<<"https://github.com/acme/widgets/pull/9"
  run gh pr create
  assert_equal "$output" "https://github.com/acme/widgets/pull/9"
  gh_mock_respond issue-create - 0 2 <<<"second"
  gh_mock_respond issue-create - <<<"plain"
  run gh issue create
  assert_equal "$output" "plain"
  run gh issue create
  assert_equal "$output" "second"
  run gh issue create
  assert_equal "$output" "plain"
  gh_mock_respond pr-ready - 3 <<<"boom"
  run --separate-stderr gh pr ready 1
  assert_failure 3
  assert_equal "$output" ""
  assert_contains "$stderr" "boom"
}

@test "unknown route succeeds silently; api routes; -F is not a file; -R ignored" {
  run gh label create x --force
  assert_success
  assert_equal "$output" ""
  assert_gh_called "label create x --force"
  gh_mock_respond api-repos_o_r_issues_5 - <<<"canned"
  run gh api repos/o/r/issues/5
  assert_equal "$output" "canned"
  run gh api graphql -F n=5
  assert_success
  assert_equal "$(ls "$GH_MOCK_DIR/files" 2>/dev/null | wc -l | tr -d ' ')" "0"
  gh_mock_issue 5 --body hi
  run gh issue view 5 -R acme/widgets --json body --jq .body
  assert_equal "$output" "hi"
}

@test "setup_project gives a clean repo on main with config" {
  setup_project
  assert_equal "$PROJECT" "$(pwd -P)"
  assert_equal "$(git status --porcelain)" ""
  assert_equal "$(git rev-parse --abbrev-ref HEAD)" "main"
  [ -f .aew/config.json ]
  setup_project --no-config
  [ ! -f .aew/config.json ]
}

@test "elapsed_ms prints a small integer" {
  run elapsed_ms true
  [[ "$output" =~ ^[0-9]+$ ]]
  [ "$output" -lt 1000 ]
}

@test "run-script-tests.sh --help prints usage" {
  run "$REPO_ROOT/tests/run-script-tests.sh" --help
  assert_success
  assert_contains "$output" "Usage:"
}
