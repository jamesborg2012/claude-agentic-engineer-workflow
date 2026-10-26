#!/usr/bin/env bats
# Tests for scripts/gh-retro.sh (AC-15).

load helpers/common

RETRO_REPO="jamesborg2012/claude-agentic-engineer-workflow"

setup() {
  common_setup
  setup_project
  gh_mock_respond issue-list "$FIXTURES/retro/open-issues.json"
  printf 'https://github.com/%s/issues/50\n' "$RETRO_REPO" | gh_mock_respond issue-create - 0 1
  printf 'https://github.com/%s/issues/51\n' "$RETRO_REPO" | gh_mock_respond issue-create - 0 2
}

file_retro() { run --separate-stderr "$SCRIPTS/gh-retro.sh" file "${1:-$FIXTURES/retro/retro.md}" acme/widgets 12; }

# Run with an inline retro.md and a single open issue #41.
match_title() {
  printf '### %s\n\nbody text\n' "$1" > "$BATS_TEST_TMPDIR/one.md"
  run --separate-stderr "$SCRIPTS/gh-retro.sh" file "$BATS_TEST_TMPDIR/one.md" acme/widgets 12
}

@test "1. comments on a match, creates new items, and comments on a same-file duplicate" {
  file_retro
  assert_success
  assert_equal "$output" "$(printf 'commented #41\ncreated #50\ncommented #50')"
  assert_equal "$(gh_call_count 'issue create')" 1
  refute_gh_called "short title"
  refute_gh_called "not an item"
}

@test "2. the comment body opens with the provenance line then the item body" {
  file_retro
  assert_success
  local f
  f=$(gh_captured_file 'issue comment 41')
  [ -n "$f" ]
  assert_equal "$(sed -n 1p "$f")" "Seen again in acme/widgets run 12"
  assert_equal "$(sed -n 2p "$f")" ""
  assert_equal "$(sed -n '3,$p' "$f")" "$(printf 'The dev gate accepted a report from an earlier cycle.\nCheck the report timestamp against the review.')"
}

@test "3. the create call carries title and label; the body has the item and provenance" {
  file_retro
  assert_success
  assert_gh_called "--title Flaky QA screenshot"
  assert_gh_called "--label retro"
  local f body
  f=$(gh_captured_file 'issue create')
  body=$(cat "$f")
  assert_contains "$body" "QA captured the screenshot before the page settled."
  assert_contains "$body" "Wait for network idle first."
  assert_contains "$body" "### not an item"
  assert_contains "$body" "Filed by aew from acme/widgets run 12."
}

@test "4. every gh call targets the retro repo; label create has no --force and comes first" {
  file_retro
  assert_success
  local line n=0
  while IFS= read -r line; do
    n=$((n + 1))
    assert_contains "$line" "--repo $RETRO_REPO"
  done < <(gh_calls)
  [ "$n" -ge 4 ]
  assert_equal "$(gh_calls | sed -n 1p | cut -d' ' -f1-3)" "label create retro"
  local lc
  lc=$(gh_calls | sed -n 1p)
  assert_contains "$lc" "--color"
  assert_contains "$lc" "--description"
  refute_contains "$lc" "--force"
  assert_contains "$(gh_calls | sed -n 2p)" "issue list"
  assert_contains "$(gh_calls | sed -n 2p)" "--label retro --state open"
}

@test "4a. a label that already exists is not a warning" {
  gh_mock_respond label-create - 1 <<<'label with name "retro" already exists'
  file_retro
  assert_success
  assert_equal "$output" "$(printf 'commented #41\ncreated #50\ncommented #50')"
  refute_contains "$stderr" "warning:"
  assert_gh_called "issue create"
}

@test "4a. a 403 on label create only warns" {
  gh_mock_respond label-create - 1 <<<'HTTP 403: Resource not accessible'
  file_retro
  assert_success
  assert_equal "$output" "$(printf 'commented #41\ncreated #50\ncommented #50')"
  assert_contains "$stderr" "warning:"
  assert_contains "$stderr" "HTTP 403"
}

@test "5. normalisation ignores case, punctuation and spacing but requires equality" {
  match_title "DEV GATE STALE REPORT PASSES"
  assert_success
  assert_equal "$output" "commented #41"
  rm -rf "$GH_MOCK_DIR"; mkdir -p "$GH_MOCK_DIR"
  gh_mock_respond issue-list "$FIXTURES/retro/open-issues.json"
  match_title "  dev   gate: stale-report passes. "
  assert_success
  assert_equal "$output" "commented #41"
  rm -rf "$GH_MOCK_DIR"; mkdir -p "$GH_MOCK_DIR"
  gh_mock_respond issue-list "$FIXTURES/retro/open-issues.json"
  printf 'https://github.com/%s/issues/60\n' "$RETRO_REPO" | gh_mock_respond issue-create - 0
  match_title "dev gate stale report"
  assert_success
  assert_equal "$output" "created #60"
}

@test "6. the lowest issue number wins when several normalise equal" {
  printf '[{"number":45,"title":"Same thing"},{"number":43,"title":"same, thing!"}]' > "$BATS_TEST_TMPDIR/two.json"
  gh_mock_respond issue-list "$BATS_TEST_TMPDIR/two.json"
  match_title "SAME THING"
  assert_success
  assert_equal "$output" "commented #43"
}

@test "7. a custom label is used in the label, list and create calls" {
  write_config '{"retro":{"repo":"o/r","label":"aew-retro"}}'
  file_retro
  assert_success
  assert_gh_called "label create aew-retro --repo o/r"
  assert_gh_called "--label aew-retro --state open"
  assert_gh_called "--title Flaky QA screenshot --label aew-retro"
}

@test "7. label defaults to retro when only repo is configured" {
  write_config '{"retro":{"repo":"o/r"}}'
  file_retro
  assert_success
  assert_gh_called "label create retro --repo o/r"
}

@test "8. a missing retro.repo dies before any gh call" {
  write_config '{}'
  file_retro
  assert_failure 1
  assert_contains "$stderr" "no value or default for 'retro.repo'"
  assert_equal "$(gh_call_count)" 0
}

@test "9. only placeholders: exit 0, nothing on stdout, no gh calls" {
  printf '# Retro\n\n## Agent mistakes\n\n### <short title>\n\n<text>\n\n### \n' > "$BATS_TEST_TMPDIR/ph.md"
  file_retro "$BATS_TEST_TMPDIR/ph.md"
  assert_success
  assert_equal "$output" ""
  assert_equal "$(gh_call_count)" 0
  file_retro "$REPO_ROOT/templates/artefacts/retro.md"
  assert_success
  assert_equal "$output" ""
  assert_equal "$(gh_call_count)" 0
}

@test "10. CRLF input gives the same results and no carriage returns" {
  sed 's/$/\r/' "$FIXTURES/retro/retro.md" > "$BATS_TEST_TMPDIR/crlf.md"
  file_retro "$BATS_TEST_TMPDIR/crlf.md"
  assert_success
  assert_equal "$output" "$(printf 'commented #41\ncreated #50\ncommented #50')"
  assert_contains "$(gh_calls)" "--title Flaky QA screenshot"
  local f
  for f in "$GH_MOCK_DIR"/files/*; do
    if grep -q "$(printf '\r')" "$f"; then return 1; fi
  done
  [ "$(gh_calls | grep -c "$(printf '\r')" || true)" = 0 ]
}

@test "11. a failing create exits non-zero after earlier lines were printed" {
  gh_mock_respond issue-create - 1 1 <<<'boom'
  file_retro
  assert_failure
  assert_contains "$output" "commented #41"
  refute_contains "$output" "created"
}

@test "12. bad input exits 1 with no gh call" {
  file_retro "$BATS_TEST_TMPDIR/missing.md"
  assert_failure 1
  run --separate-stderr "$SCRIPTS/gh-retro.sh" file "$FIXTURES/retro/retro.md" widgets 12
  assert_failure 1
  run --separate-stderr "$SCRIPTS/gh-retro.sh" file "$FIXTURES/retro/retro.md" acme/widgets abc
  assert_failure 1
  run --separate-stderr "$SCRIPTS/gh-retro.sh" file
  assert_failure 1
  run --separate-stderr "$SCRIPTS/gh-retro.sh" file "$FIXTURES/retro/retro.md" acme/widgets
  assert_failure 1
  run --separate-stderr "$SCRIPTS/gh-retro.sh" bogus
  assert_failure 1
  run --separate-stderr "$SCRIPTS/gh-retro.sh" --bogus
  assert_failure 1
  assert_equal "$output" ""
  assert_equal "$(gh_call_count)" 0
}
