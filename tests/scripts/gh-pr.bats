#!/usr/bin/env bats
# Tests for scripts/gh-pr.sh (create, update, ready, comment). gh is the PATH shim.

load helpers/common

TEMPLATE="$REPO_ROOT/templates/artefacts/pr-body.md"

setup() {
  common_setup
  setup_project
  seed_run 12
  "$SCRIPTS/state.sh" set branch feat/12-add-widget
  gh_mock_respond pr-create - 0 <<< "https://github.com/acme/widgets/pull/7"
  PR="$SCRIPTS/gh-pr.sh"
}

# captured_body: the body file the last `pr create` received.
captured_body() { gh_captured_file 'pr create'; }

@test "create prints the PR number, passes head/base/title and fixes the closing line" {
  run --separate-stderr "$PR" create 12 "$TEMPLATE"
  assert_success
  assert_equal "$output" "7"
  assert_gh_called "--head feat/12-add-widget"
  assert_gh_called "--base main"
  assert_gh_called "--title Test run"
  local f
  f=$(captured_body)
  [ "$(grep -c '^Closes #12$' "$f")" -eq 1 ]
  refute_contains "$(cat "$f")" '#<issue>'
  grep -vF 'Closes #<issue>' "$TEMPLATE" > "$BATS_TEST_TMPDIR/expected"
  grep -v '^Closes #12$' "$f" > "$BATS_TEST_TMPDIR/actual"
  cmp "$BATS_TEST_TMPDIR/expected" "$BATS_TEST_TMPDIR/actual"
}

@test "create leaves the input file byte-identical" {
  cp "$TEMPLATE" "$BATS_TEST_TMPDIR/in.md"
  run --separate-stderr "$PR" create 12 "$BATS_TEST_TMPDIR/in.md"
  assert_success
  cmp "$TEMPLATE" "$BATS_TEST_TMPDIR/in.md"
}

@test "bulk run adds only the missing Closes lines, in state order" {
  seed_run m-3 --issues 4,5 --mode bulk
  "$SCRIPTS/state.sh" set branch feat/m-3
  printf '## Closes\n\nCloses #4\n' > "$BATS_TEST_TMPDIR/b.md"
  run --separate-stderr "$PR" create m-3 "$BATS_TEST_TMPDIR/b.md"
  assert_success
  local f
  f=$(captured_body)
  [ "$(grep -c '^Closes #4$' "$f")" -eq 1 ]
  [ "$(grep -c '^Closes #5$' "$f")" -eq 1 ]
  [ "$(grep -n '^Closes #4$' "$f" | cut -d: -f1)" -lt "$(grep -n '^Closes #5$' "$f" | cut -d: -f1)" ]
}

@test "other keywords and case count as coverage; Closes #123 does not cover #12" {
  seed_run m-3 --issues 4,5 --mode bulk
  "$SCRIPTS/state.sh" set branch feat/m-3
  printf 'fixes #4\nRESOLVED #5\n' > "$BATS_TEST_TMPDIR/k.md"
  run --separate-stderr "$PR" create m-3 "$BATS_TEST_TMPDIR/k.md"
  assert_success
  cmp "$BATS_TEST_TMPDIR/k.md" "$(captured_body)"
  printf 'Closes #123\n' > "$BATS_TEST_TMPDIR/p.md"
  run --separate-stderr "$PR" create 12 "$BATS_TEST_TMPDIR/p.md"
  assert_success
  [ "$(grep -c '^Closes #12$' "$(captured_body)")" -eq 1 ]
  grep -q '^Closes #123$' "$(captured_body)"
}

@test "normalising twice is stable" {
  run --separate-stderr "$PR" create 12 "$TEMPLATE"
  assert_success
  cp "$(captured_body)" "$BATS_TEST_TMPDIR/first.md"
  : > "$GH_MOCK_DIR/calls.log"
  rm -rf "$GH_MOCK_DIR/files" "$GH_MOCK_DIR/counters"
  run --separate-stderr "$PR" create 12 "$BATS_TEST_TMPDIR/first.md"
  assert_success
  cmp "$BATS_TEST_TMPDIR/first.md" "$(captured_body)"
}

@test "--base, base_branch fallback and --draft" {
  run --separate-stderr "$PR" create 12 "$TEMPLATE" --base develop
  assert_success
  assert_gh_called "--base develop"
  refute_gh_called "--draft"
  : > "$GH_MOCK_DIR/calls.log"
  "$SCRIPTS/state.sh" set base_branch trunk
  run --separate-stderr "$PR" create 12 "$TEMPLATE" --draft
  assert_success
  assert_gh_called "--base trunk"
  assert_gh_called "--draft"
}

@test "CRLF body: detection works and appended lines use CRLF" {
  printf '## Closes\r\n\r\nCloses #<issue>\r\n' > "$BATS_TEST_TMPDIR/c.md"
  run --separate-stderr "$PR" create 12 "$BATS_TEST_TMPDIR/c.md"
  assert_success
  local f
  f=$(captured_body)
  [ "$(tail -c 12 "$f" | od -c | grep -c '\\r  \\n')" -ge 1 ]
  [ "$(grep -c 'Closes #12' "$f")" -eq 1 ]
  # no bare-LF line: every line ends in CR
  [ "$(grep -c -v $'\r$' "$f")" -eq 0 ]
  # already covered CRLF body is left alone
  printf 'Closes #12\r\n' > "$BATS_TEST_TMPDIR/c2.md"
  run --separate-stderr "$PR" create 12 "$BATS_TEST_TMPDIR/c2.md"
  assert_success
  cmp "$BATS_TEST_TMPDIR/c2.md" "$(captured_body)"
  # LF body: appended lines end in LF only
  printf 'Hello\n' > "$BATS_TEST_TMPDIR/l.md"
  run --separate-stderr "$PR" create 12 "$BATS_TEST_TMPDIR/l.md"
  assert_success
  [ "$(grep -c $'\r' "$(captured_body)")" -eq 0 ]
}

@test "gh failure: non-zero, empty stdout, gh message on stderr" {
  gh_mock_respond pr-create - 1 <<< "a pull request for branch feat/12-add-widget already exists"
  run --separate-stderr "$PR" create 12 "$TEMPLATE"
  assert_failure
  assert_equal "$output" ""
  assert_contains "$stderr" "already exists"
}

@test "output without a /pull/<n> URL is an error" {
  gh_mock_respond pr-create - 0 <<< "created something"
  run --separate-stderr "$PR" create 12 "$TEMPLATE"
  assert_failure 1
  assert_equal "$output" ""
  assert_contains "$stderr" "error:"
}

@test "create refusals make no gh call" {
  : > "$BATS_TEST_TMPDIR/empty.md"
  run --separate-stderr "$PR" create abc "$TEMPLATE"
  assert_failure 1; assert_contains "$stderr" "error:"
  run --separate-stderr "$PR" create 99 "$TEMPLATE"
  assert_failure 1; assert_contains "$stderr" "error:"
  run --separate-stderr "$PR" create 12 "$BATS_TEST_TMPDIR/missing.md"
  assert_failure 1; assert_contains "$stderr" "error:"
  run --separate-stderr "$PR" create 12 "$BATS_TEST_TMPDIR/empty.md"
  assert_failure 1; assert_contains "$stderr" "error:"
  run --separate-stderr "$PR" create 12 "$TEMPLATE" --base
  assert_failure 1; assert_contains "$stderr" "error:"
  run --separate-stderr "$PR" create 12 "$TEMPLATE" --bogus
  assert_failure 1; assert_contains "$stderr" "error:"
  run --separate-stderr "$PR" create 12
  assert_failure 1; assert_contains "$stderr" "error:"
  run --separate-stderr "$PR" create
  assert_failure 1; assert_contains "$stderr" "error:"
  [ "$(gh_call_count)" -eq 0 ]
}

@test "create refuses a null branch and an empty title" {
  seed_run 13
  run --separate-stderr "$PR" create 13 "$TEMPLATE"
  assert_failure 1; assert_contains "$stderr" "error:"
  "$SCRIPTS/state.sh" set branch feat/13
  "$SCRIPTS/state.sh" set title ""
  run --separate-stderr "$PR" create 13 "$TEMPLATE"
  assert_failure 1; assert_contains "$stderr" "error:"
  [ "$(gh_call_count)" -eq 0 ]
}

@test "update --run applies the closing-line fix and leaves the input alone" {
  cp "$TEMPLATE" "$BATS_TEST_TMPDIR/in.md"
  run --separate-stderr "$PR" update 7 "$BATS_TEST_TMPDIR/in.md" --run 12
  assert_success
  assert_equal "$output" ""
  local f
  f=$(gh_captured_file 'pr edit 7')
  [ "$(grep -c '^Closes #12$' "$f")" -eq 1 ]
  refute_contains "$(cat "$f")" '#<issue>'
  grep -vF 'Closes #<issue>' "$TEMPLATE" > "$BATS_TEST_TMPDIR/expected"
  grep -v '^Closes #12$' "$f" > "$BATS_TEST_TMPDIR/actual"
  cmp "$BATS_TEST_TMPDIR/expected" "$BATS_TEST_TMPDIR/actual"
  cmp "$TEMPLATE" "$BATS_TEST_TMPDIR/in.md"
}

@test "update --run refusals make no gh call" {
  run --separate-stderr "$PR" update 7 "$TEMPLATE" --run abc
  assert_failure 1; assert_contains "$stderr" "error:"
  run --separate-stderr "$PR" update 7 "$TEMPLATE" --run
  assert_failure 1; assert_contains "$stderr" "error:"
  run --separate-stderr "$PR" update 7 "$TEMPLATE" --run 99
  assert_failure 1; assert_contains "$stderr" "error:"
  run --separate-stderr "$PR" update 7 "$TEMPLATE" --bogus
  assert_failure 1; assert_contains "$stderr" "error:"
  [ "$(gh_call_count)" -eq 0 ]
}

@test "update, ready and comment wrap gh and print nothing" {
  printf 'body text\n' > "$BATS_TEST_TMPDIR/f.md"
  run --separate-stderr "$PR" update 7 "$BATS_TEST_TMPDIR/f.md"
  assert_success; assert_equal "$output" ""
  assert_gh_called "pr edit 7 --body-file"
  cmp "$BATS_TEST_TMPDIR/f.md" "$(gh_captured_file 'pr edit 7')"
  run --separate-stderr "$PR" ready 7
  assert_success; assert_equal "$output" ""
  assert_gh_called "pr ready 7"
  run --separate-stderr "$PR" comment 7 "$BATS_TEST_TMPDIR/f.md"
  assert_success; assert_equal "$output" ""
  assert_gh_called "pr comment 7 --body-file"
  cmp "$BATS_TEST_TMPDIR/f.md" "$(gh_captured_file 'pr comment 7')"
}

@test "update, ready and comment refuse bad input without calling gh" {
  printf 'x\n' > "$BATS_TEST_TMPDIR/f.md"
  run --separate-stderr "$PR" update abc "$BATS_TEST_TMPDIR/f.md"
  assert_failure 1; assert_contains "$stderr" "error:"
  run --separate-stderr "$PR" ready 0
  assert_failure 1; assert_contains "$stderr" "error:"
  run --separate-stderr "$PR" comment 7 "$BATS_TEST_TMPDIR/missing.md"
  assert_failure 1; assert_contains "$stderr" "error:"
  [ "$(gh_call_count)" -eq 0 ]
}
