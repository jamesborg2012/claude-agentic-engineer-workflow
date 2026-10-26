#!/usr/bin/env bats
# Tests for scripts/check-pr-intro.sh. Pure text checks: no gh, no run state.

load helpers/common

FX="$FIXTURES/pr-intro"

setup() {
  common_setup
  CHECK="$SCRIPTS/check-pr-intro.sh"
}

@test "a valid single-issue introduction passes with no output" {
  run --separate-stderr "$CHECK" "$FX/valid.md"
  assert_success
  assert_equal "$output" ""
}

@test "a valid bulk introduction passes with --issues 3" {
  run --separate-stderr "$CHECK" "$FX/valid-bulk.md" --issues 3
  assert_success
}

@test "the same bulk body fails as a single issue (too long) and passes with --issues 3" {
  run --separate-stderr "$CHECK" "$FX/valid-bulk.md"
  assert_failure 1
  assert_contains "$output" "FAIL: introduction is "
  assert_contains "$output" "words, maximum is 250"
  run --separate-stderr "$CHECK" "$FX/valid-bulk.md" --issues 3
  assert_success
}

@test "--issues accepts the option before the file" {
  run --separate-stderr "$CHECK" --issues 3 "$FX/valid-bulk.md"
  assert_success
}

@test "bulk maximum is 80 x n + 80 words" {
  run --separate-stderr "$CHECK" "$FX/too-long.md" --issues 3
  assert_failure 1
  assert_contains "$output" "words, maximum is 320"
}

@test "a body with no introduction section fails" {
  run --separate-stderr "$CHECK" "$FX/no-section.md"
  assert_failure 1
  assert_equal "$output" "FAIL: no '## In plain English' section found"
}

@test "an introduction that is not the first ## section fails, and stops the other checks" {
  run --separate-stderr "$CHECK" "$FX/not-first.md"
  assert_failure 1
  assert_equal "$output" "FAIL: '## In plain English' must be the first ## section (found '## Summary' first)"
}

@test "too long fails with the word count" {
  run --separate-stderr "$CHECK" "$FX/too-long.md"
  assert_failure 1
  assert_equal "$output" "FAIL: introduction is 348 words, maximum is 250"
}

@test "too short fails with the word count" {
  run --separate-stderr "$CHECK" "$FX/too-short.md"
  assert_failure 1
  assert_equal "$output" "FAIL: introduction is 25 words, minimum is 100"
}

@test "backticks fail" {
  run --separate-stderr "$CHECK" "$FX/backticks.md"
  assert_failure 1
  assert_equal "$output" "FAIL: introduction contains a backtick"
}

@test "a file path fails and is quoted" {
  run --separate-stderr "$CHECK" "$FX/path.md"
  assert_failure 1
  assert_equal "$output" "FAIL: introduction contains a file path: src/basket.js"
}

@test "an AC identifier fails and is quoted" {
  run --separate-stderr "$CHECK" "$FX/ac-id.md"
  assert_failure 1
  assert_equal "$output" "FAIL: introduction contains an AC/TC/WP identifier: AC-3"
}

@test "a table fails" {
  run --separate-stderr "$CHECK" "$FX/table.md"
  assert_failure 1
  assert_equal "$output" "FAIL: introduction contains a table"
}

@test "a heading inside the introduction fails" {
  run --separate-stderr "$CHECK" "$FX/heading.md"
  assert_failure 1
  assert_equal "$output" "FAIL: introduction contains a heading: ### Outstanding"
}

@test "a line starting with an issue reference (#12) is not a heading" {
  local f="$BATS_TEST_TMPDIR/h.md"
  sed 's/^Shoppers can now/#12 was the request. Shoppers can now/' "$FX/valid.md" > "$f"
  run --separate-stderr "$CHECK" "$f"
  assert_success
}

@test "several violations are each reported on their own FAIL line" {
  local f="$BATS_TEST_TMPDIR/many.md"
  { cat "$FX/valid.md"; } | sed 's/^Shoppers can now/Shoppers (AC-1, `x`) can now/' > "$f"
  run --separate-stderr "$CHECK" "$f"
  assert_failure 1
  [ "$(printf '%s\n' "$output" | grep -c '^FAIL: ')" -eq 2 ]
}

@test "backticks, paths and AC ids in the technical sections are not checked" {
  grep -q '`' "$FX/valid.md"
  grep -q 'src/basket.js' "$FX/valid.md"
  grep -q 'AC-1' "$FX/valid.md"
  run --separate-stderr "$CHECK" "$FX/valid.md"
  assert_success
}

@test "a leftover template comment is ignored, not counted as words or paths" {
  local f="$BATS_TEST_TMPDIR/c.md"
  {
    printf '<!--\nremoved by the doc-writer. See templates/artefacts/pr-body.md `x` AC-1\n-->\n'
    printf '## In plain English\n\n<!-- one-line comment with src/a.js -->\n'
    sed '1,2d' "$FX/valid.md"
  } > "$f"
  run --separate-stderr "$CHECK" "$f"
  assert_success
}

@test "an inline comment is stripped from within a line" {
  local f="$BATS_TEST_TMPDIR/i.md"
  sed 's/^Shoppers can now/<!-- `x` --> Shoppers can now/' "$FX/valid.md" > "$f"
  run --separate-stderr "$CHECK" "$f"
  assert_success
}

@test "the unfilled template fails as too short (comments stripped, no intro text)" {
  run --separate-stderr "$CHECK" "$REPO_ROOT/templates/artefacts/pr-body.md"
  assert_failure 1
  assert_equal "$output" "FAIL: introduction is 0 words, minimum is 100"
}

@test "a second ## In plain English section is judged on the first" {
  local f="$BATS_TEST_TMPDIR/two.md"
  { cat "$FX/valid.md"; printf '\n## In plain English\n\nSee `src/x.js` AC-9.\n'; } > "$f"
  run --separate-stderr "$CHECK" "$f"
  assert_success
}

@test "text before the section (a title line) is allowed" {
  local f="$BATS_TEST_TMPDIR/t.md"
  { printf '# Add a basket\n\n'; cat "$FX/valid.md"; } > "$f"
  run --separate-stderr "$CHECK" "$f"
  assert_success
}

@test "ordinary prose with slashes is not flagged as a path" {
  local f="$BATS_TEST_TMPDIR/p.md"
  { sed '$d' "$FX/valid.md" | sed 's/^It was built as/Pass\/fail, and\/or 24\/7 and 1\/2 were all fine. It was built as/' | sed 's/All 14 checks pass on desktop/All 14 checks pass\/fail. 14 checks pass on desktop/'; } > "$f"
  grep -q '24/7' "$f"
  run --separate-stderr "$CHECK" "$f"
  assert_success
}

@test "--help exits 0 with Usage on stdout" {
  run --separate-stderr "$CHECK" --help
  assert_success
  assert_contains "$output" "Usage: check-pr-intro.sh"
}

@test "no argument exits 1 with an error (convention: usage errors share the suite-wide status)" {
  run --separate-stderr "$CHECK"
  assert_failure 1
  assert_contains "$stderr" "error:"
}

@test "a missing file exits 2 with the message on stderr" {
  run --separate-stderr "$CHECK" "$BATS_TEST_TMPDIR/nope.md"
  assert_failure 2
  assert_equal "$output" ""
  assert_contains "$stderr" "no such file"
}

@test "an invalid --issues value exits 2" {
  run --separate-stderr "$CHECK" "$FX/valid.md" --issues zero
  assert_failure 2
  run --separate-stderr "$CHECK" "$FX/valid.md" --issues 0
  assert_failure 2
}
