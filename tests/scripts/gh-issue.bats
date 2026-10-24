#!/usr/bin/env bats
# Tests for scripts/gh-issue.sh: fetch and comment. gh is always the shim.

load helpers/common

setup() {
  common_setup
  D="$BATS_TEST_TMPDIR/run"
  mkdir -p "$D"
  I="$FIXTURES/issue"
}

@test "fetch writes issue.json with every AC-5 key and the body byte for byte" {
  gh_mock_issue 12 --from "$I/view-12.json" --body-file "$I/body-12.md" --labels aew:analysing,bug
  run --separate-stderr "$SCRIPTS/gh-issue.sh" fetch 12 "$D"
  assert_success
  assert_json "$D/issue.json" 'has("number","title","body","state","url","author","comments","labels","milestone","assignees","blockedBy","blocking","parent","subIssues","closedByPullRequestsReferences","referenced_issues")'
  jq -j .body "$D/issue.json" | cmp - "$I/body-12.md"
  assert_json "$D/issue.json" '.referenced_issues == [3,4,5,7,20]'
  assert_json "$D/issue.json" '[.labels[].name] | sort == ["aew:analysing","bug"]'
}

@test "fetch makes exactly one gh call asking for the linked-issue fields" {
  gh_mock_issue 12 --from "$I/view-12.json" --body-file "$I/body-12.md"
  run --separate-stderr "$SCRIPTS/gh-issue.sh" fetch 12 "$D"
  assert_success
  assert_equal "$(gh_call_count)" 1
  assert_gh_called "issue view 12 --json"
  local f
  for f in blockedBy blocking parent subIssues closedByPullRequestsReferences; do assert_gh_called "$f"; done
}

@test "fetch renders 00-issue-original.md" {
  gh_mock_issue 12 --from "$I/view-12.json" --body-file "$I/body-12.md" --labels bug
  run --separate-stderr "$SCRIPTS/gh-issue.sh" fetch 12 "$D"
  assert_success
  local md="$D/00-issue-original.md"
  [ "$(head -n 1 "$md")" = "# #12 Add the widget exporter" ]
  grep -qF -- '- **Milestone:** v1.0 (#2)' "$md"
  grep -qF -- '- **Assignees:** @james' "$md"
  grep -qF -- '- **Author:** @octo' "$md"
  grep -qF -- '- **Labels:** bug' "$md"
  jq -e -Rs --rawfile b "$I/body-12.md" 'contains("## Body\n\n" + $b)' "$md" > /dev/null
  jq -e -Rs 'contains("## Comments (2)") and contains("### @octo") and contains("First line\r\nSee #20") and (index("### @octo") < index("### @james"))' "$md" > /dev/null
  grep -qF -- 'Blocked by: #3 Auth (OPEN)' "$md"
  grep -qF -- 'Parent: #1 Epic (OPEN)' "$md"
  grep -qF -- 'Sub-issues: #13' "$md"
  grep -qF -- 'Blocking: none' "$md"
  grep -qF -- 'Closed by pull requests: #6' "$md"
  grep -qF -- '#3, #4, #5, #7, #20' "$md"
}

@test "fetch of a minimal issue" {
  gh_mock_issue 5 --from "$I/view-minimal.json"
  run --separate-stderr "$SCRIPTS/gh-issue.sh" fetch 5 "$D"
  assert_success
  local md="$D/00-issue-original.md"
  grep -qF -- '## Comments (0)' "$md"
  grep -qF -- 'None.' "$md"
  grep -qF -- 'Milestone:** none' "$md"
  grep -qF -- 'Assignees:** none' "$md"
  grep -qF -- 'Labels:** none' "$md"
  grep -qF -- 'Parent: none' "$md"
  grep -qF -- 'Blocked by: none' "$md"
  grep -qF -- 'Blocking: none' "$md"
  grep -qF -- 'Sub-issues: none' "$md"
  grep -qF -- 'Closed by pull requests: none' "$md"
  assert_json "$D/issue.json" '.referenced_issues == []'
}

@test "fetch writes a body that already has aew markers verbatim, and a second fetch overwrites" {
  printf '<!-- aew:spec v2 -->\nSpec two\n<!-- /aew:spec -->\n' > "$BATS_TEST_TMPDIR/marked.md"
  gh_mock_issue 5 --from "$I/view-minimal.json" --body-file "$BATS_TEST_TMPDIR/marked.md"
  run --separate-stderr "$SCRIPTS/gh-issue.sh" fetch 5 "$D"
  assert_success
  jq -j .body "$D/issue.json" | cmp - "$BATS_TEST_TMPDIR/marked.md"
  jq -e -Rs --rawfile b "$BATS_TEST_TMPDIR/marked.md" 'contains("## Body\n\n" + $b)' "$D/00-issue-original.md" > /dev/null
  printf 'changed\n' > "$BATS_TEST_TMPDIR/changed.md"
  gh_mock_issue 5 --body-file "$BATS_TEST_TMPDIR/changed.md"
  run --separate-stderr "$SCRIPTS/gh-issue.sh" fetch 5 "$D"
  assert_success
  assert_json "$D/issue.json" '.body == "changed\n"'
  grep -qF -- 'changed' "$D/00-issue-original.md"
  if grep -qF -- 'Spec two' "$D/00-issue-original.md"; then return 1; fi
}

@test "fetch refuses a missing run dir without calling gh" {
  run --separate-stderr "$SCRIPTS/gh-issue.sh" fetch 12 "$BATS_TEST_TMPDIR/nope"
  assert_failure 1
  assert_contains "$stderr" "error:"
  assert_contains "$stderr" "run dir not found"
  assert_equal "$(gh_call_count)" 0
  [ ! -e "$BATS_TEST_TMPDIR/nope" ]
}

@test "fetch refuses an invalid issue number or a missing argument without calling gh" {
  run --separate-stderr "$SCRIPTS/gh-issue.sh" fetch abc "$D"
  assert_failure 1
  assert_contains "$stderr" "invalid issue number: abc"
  run --separate-stderr "$SCRIPTS/gh-issue.sh" fetch 0 "$D"
  assert_failure 1
  assert_contains "$stderr" "invalid issue number: 0"
  run --separate-stderr "$SCRIPTS/gh-issue.sh" fetch 12
  assert_failure 1
  assert_contains "$stderr" "error:"
  run --separate-stderr "$SCRIPTS/gh-issue.sh" fetch
  assert_failure 1
  assert_contains "$stderr" "error:"
  assert_equal "$(gh_call_count)" 0
  [ -z "$(ls -A "$D")" ]
}

@test "fetch of an unseeded issue writes nothing" {
  run --separate-stderr "$SCRIPTS/gh-issue.sh" fetch 404 "$D"
  assert_failure 1
  assert_contains "$stderr" "error:"
  assert_contains "$stderr" "gh issue view #404 failed"
  [ -z "$(ls -A "$D")" ]
}

@test "fetch propagates a gh failure and writes nothing" {
  printf 'HTTP 502 bad gateway\n' | gh_mock_respond issue-view - 1
  run --separate-stderr "$SCRIPTS/gh-issue.sh" fetch 12 "$D"
  assert_failure 1
  assert_contains "$stderr" "error:"
  assert_contains "$stderr" "502"
  [ -z "$(ls -A "$D")" ]
}

@test "comment posts the file and passes gh's stdout through" {
  printf 'https://github.com/acme/widgets/issues/12#issuecomment-1\n' | gh_mock_respond issue-comment -
  printf 'Spec revised: v2\n\n- one\n' > "$BATS_TEST_TMPDIR/c.md"
  run --separate-stderr "$SCRIPTS/gh-issue.sh" comment 12 "$BATS_TEST_TMPDIR/c.md"
  assert_success
  assert_equal "$output" "https://github.com/acme/widgets/issues/12#issuecomment-1"
  assert_gh_called "issue comment 12 --body-file"
  cmp "$(gh_captured_file 'issue comment 12')" "$BATS_TEST_TMPDIR/c.md"
}

@test "comment refusals make no gh call" {
  : > "$BATS_TEST_TMPDIR/empty.md"
  run --separate-stderr "$SCRIPTS/gh-issue.sh" comment 12 "$BATS_TEST_TMPDIR/empty.md"
  assert_failure 1
  assert_contains "$stderr" "error:"
  run --separate-stderr "$SCRIPTS/gh-issue.sh" comment 12 "$BATS_TEST_TMPDIR/missing.md"
  assert_failure 1
  assert_contains "$stderr" "error:"
  printf 'x\n' > "$BATS_TEST_TMPDIR/c.md"
  run --separate-stderr "$SCRIPTS/gh-issue.sh" comment x "$BATS_TEST_TMPDIR/c.md"
  assert_failure 1
  assert_contains "$stderr" "invalid issue number: x"
  run --separate-stderr "$SCRIPTS/gh-issue.sh" comment 12
  assert_failure 1
  assert_contains "$stderr" "error:"
  assert_equal "$(gh_call_count)" 0
}

@test "comment fails when gh fails" {
  printf 'boom\n' | gh_mock_respond issue-comment - 1
  printf 'x\n' > "$BATS_TEST_TMPDIR/c.md"
  run --separate-stderr "$SCRIPTS/gh-issue.sh" comment 12 "$BATS_TEST_TMPDIR/c.md"
  assert_failure 1
  assert_contains "$stderr" "gh issue comment #12 failed"
}

@test "dispatch: unknown subcommand fails, --help lists fetch and comment" {
  run --separate-stderr "$SCRIPTS/gh-issue.sh" nosuch
  assert_failure 1
  assert_contains "$stderr" "error:"
  run --separate-stderr "$SCRIPTS/gh-issue.sh" --help
  assert_success
  assert_contains "$output" "fetch <n> <run-dir>"
  assert_contains "$output" "comment <n> <file>"
}
