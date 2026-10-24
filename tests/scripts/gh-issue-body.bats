#!/usr/bin/env bats
# Tests for the issue-body format (scripts/lib/issue-body.jq) through
# gh-issue.sh revise. gh is always the shim. The helpers below are written from
# the format contract in the plan, independent of issue-body.jq.

load helpers/common

setup() {
  common_setup
  I="$FIXTURES/issue"
  W="$BATS_TEST_TMPDIR/w"
  mkdir -p "$W"
}

# --- contract-side helpers (jq --rawfile + split, output with -j) -------------
# Not `jq -Rs`: jq 1.7.1 corrupts a multi-byte character that straddles one of
# its 4096-byte read chunks, which changes the codepoint count.

# prev_of <body-file> <K>: prints C_K = P[3:-2] | join("\n").
prev_of() {
  jq -n -j --rawfile b "$1" --argjson k "$2" '
    ($b | split("\n")) as $L
    | ([range(0; $L | length) | select($L[.] | test("^<!-- aew:spec-prev v\($k) -->\r?$"))][0]) as $o
    | ([range(0; $L | length) | select($L[.] | test("^<!-- /aew:spec-prev v\($k) -->\r?$"))][0]) as $c
    | $L[$o + 1 : $c] | .[3:-2] | join("\n")'
}

# spec_of <body-file>: prints the spec block content.
spec_of() {
  jq -n -j --rawfile b "$1" '
    ($b | split("\n")) as $L
    | ([range(0; $L | length) | select($L[.] | test("^<!-- aew:spec v[0-9]+ -->\r?$"))][0]) as $o
    | ([range(0; $L | length) | select($L[.] | test("^<!-- /aew:spec -->\r?$"))][0]) as $c
    | $L[$o + 1 : $c] | join("\n")'
}

# manual_of <body-file>: prints the manual-tests block content.
manual_of() {
  jq -n -j --rawfile b "$1" '
    ($b | split("\n")) as $L
    | ([range(0; $L | length) | select($L[.] | test("^<!-- aew:manual-tests -->\r?$"))][0]) as $o
    | ([range(0; $L | length) | select($L[.] | test("^<!-- /aew:manual-tests -->\r?$"))][0]) as $c
    | $L[$o + 1 : $c] | join("\n")'
}

# assert_no_line_lost <before> <after> [--except-manual]
# Every non-blank, non-marker line of <before> (one trailing \r stripped) must
# occur in <after> at least as many times.
assert_no_line_lost() {
  local out
  out=$(awk -v except_manual="${3:-}" '
    function norm(s) { sub(/\r$/, "", s); return s }
    function skip(s) { return s ~ /^[ \t]*$/ || s ~ /^<!-- \/?aew:[a-z-]+( v[0-9]+)? -->$/ }
    FILENAME == ARGV[1] {
      l = norm($0)
      if (except_manual == "--except-manual") {
        if (l == "<!-- aew:manual-tests -->") { inman = 1; next }
        if (l == "<!-- /aew:manual-tests -->") { inman = 0; next }
        if (inman) next
      }
      if (!skip(l)) { before[l]++; order[++n] = l }
      next
    }
    { l = norm($0); if (!skip(l)) after[l]++ }
    END {
      for (i = 1; i <= n; i++) {
        l = order[i]
        if (after[l] < before[l]) { print l; exit 1 }
      }
    }' "$1" "$2") || {
    printf 'line lost from the body: %s\n' "$out" >&2
    return 1
  }
}

crlf_nonl() { perl -pe 'chomp if eof' "$1" | perl -pe 's/\n/\r\n/'; }

revise() { run --separate-stderr "$SCRIPTS/gh-issue.sh" revise "$@"; }

edits() { gh_call_count 'issue edit'; }

# expect_refusal <body-file> <spec-file> <version> <message fragment>
expect_refusal() {
  local n
  n=$(edits)
  gh_mock_issue 7 --body-file "$1"
  cp "$1" "$W/before"
  revise 7 "$2" "$3"
  assert_failure 1
  assert_contains "$stderr" "error:"
  assert_contains "$stderr" "$4"
  assert_equal "$(edits)" "$n"
  gh_mock_body 7 | cmp - "$W/before"
}

# --- scenarios ----------------------------------------------------------------

@test "1. v1 to v2 matches the golden body and records v1 verbatim" {
  gh_mock_issue 7 --body-file "$I/body-v1.md"
  revise 7 "$I/spec-v2.md" 2
  assert_success
  gh_mock_body 7 > "$W/after"
  cmp "$W/after" "$I/expected-v2.md"
  assert_equal "$(head -n 1 "$W/after")" "<!-- aew:spec v2 -->"
  spec_of "$W/after" | cmp - "$I/spec-v2.md"
  prev_of "$W/after" 1 | cmp - "$I/body-v1.md"
  assert_equal "$(edits)" 1
  assert_gh_called "issue edit 7 --body-file"
  cmp "$(gh_captured_file 'issue edit 7')" "$W/after"
  grep -qxF '<summary>Spec v1 (original)</summary>' "$W/after"
  assert_no_line_lost "$I/body-v1.md" "$W/after"
  [ -z "$output" ]
}

@test "2. revise twice with the same input is idempotent (AC-6)" {
  gh_mock_issue 7 --body-file "$I/body-v1.md"
  revise 7 "$I/spec-v2.md" 2
  assert_success
  gh_mock_body 7 > "$W/after1"
  revise 7 "$I/spec-v2.md" 2
  assert_success
  gh_gh=$(edits)
  assert_equal "$gh_gh" 1
  gh_mock_body 7 | cmp - "$W/after1"
  assert_contains "$stderr" "unchanged"
}

v3_check() {
  local v1=$1
  gh_mock_issue 7 --body-file "$v1"
  revise 7 "$I/spec-v2.md" 2
  assert_success
  revise 7 "$I/spec-v3.md" 3
  assert_success
  gh_mock_body 7 > "$W/after"
  spec_of "$W/after" | cmp - "$I/spec-v3.md"
  local l2 l1
  l2=$(grep -n '^<!-- aew:spec-prev v2 -->' "$W/after" | cut -d: -f1)
  l1=$(grep -n '^<!-- aew:spec-prev v1 -->' "$W/after" | cut -d: -f1)
  [ "$l2" -lt "$l1" ]
  prev_of "$W/after" 2 | cmp - "$I/spec-v2.md"
  prev_of "$W/after" 1 | cmp - "$v1"
  assert_no_line_lost "$I/body-v1.md" "$W/after"
  cp "$W/after" "$W/after3"
  local n=$(edits)
  revise 7 "$I/spec-v3.md" 3
  assert_success
  gh_mock_body 7 | cmp - "$W/after3"
  assert_equal "$(edits)" "$n"
}

@test "3. v3 keeps v1 byte for byte (CRLF, no final newline)" {
  crlf_nonl "$I/body-v1.md" > "$W/body-v1.crlf"
  v3_check "$W/body-v1.crlf"
  # the author's pieces are inside the v1 block
  prev_of "$W/after" 1 | grep -qF '<details><summary>Logs</summary>'
  prev_of "$W/after" 1 | grep -qF '<!-- author note -->'
  prev_of "$W/after" 1 | grep -qF 'café'
  prev_of "$W/after" 1 | grep -qF -- '--> still inside the fence'
}

@test "3b. v3 keeps v1 byte for byte (LF fixture)" {
  v3_check "$I/body-v1.md"
}

@test "4a. versions below 2 and non-numbers are refused before any gh call" {
  local v
  for v in 1 0 abc 02 -1 ""; do
    revise 7 "$I/spec-v2.md" "$v"
    assert_failure 1
    assert_contains "$stderr" "error:"
  done
  assert_equal "$(gh_call_count)" 0
}

@test "4b. a gap, a regression and a conflicting same-version spec are refused" {
  expect_refusal "$I/body-v1.md" "$I/spec-v3.md" 3 "gap"
  cp "$I/expected-v2.md" "$W/v2"
  gh_mock_issue 7 --body-file "$W/v2"
  revise 7 "$I/spec-v3.md" 3
  assert_success
  gh_mock_body 7 > "$W/v3"
  expect_refusal "$W/v3" "$I/spec-v2.md" 2 "regress"
  expect_refusal "$I/expected-v2.md" "$I/spec-v3.md" 2 "already recorded with different content; use version 3"
}

@test "4c. a missing, empty or marker-bearing spec file is refused" {
  gh_mock_issue 7 --body-file "$I/body-v1.md"
  revise 7 "$W/nope.md" 2
  assert_failure 1
  : > "$W/empty.md"
  revise 7 "$W/empty.md" 2
  assert_failure 1
  printf '# s\n<!-- aew:spec-prev v1 -->\nx\n' > "$W/m1.md"
  expect_refusal "$I/body-v1.md" "$W/m1.md" 2 "marker"
  printf 'text\n<!-- /aew:spec -->' > "$W/m2.md"
  expect_refusal "$I/body-v1.md" "$W/m2.md" 2 "marker"
  printf 'text\r\n<!-- /aew:spec -->\r\n' > "$W/m3.md"
  expect_refusal "$I/body-v1.md" "$W/m3.md" 2 "marker"
  printf '<!-- aew:foo -->' > "$W/m4.md"
  expect_refusal "$I/body-v1.md" "$W/m4.md" 2 "marker"
}

@test "4d. a stray marker in the author's body is refused" {
  expect_refusal "$I/body-v1-stray-marker.md" "$I/spec-v2.md" 2 "malformed aew blocks"
}

@test "4e. malformed managed bodies are refused, never repaired" {
  local v2="$I/expected-v2.md" b
  b="$W/m-noclose"; grep -v '^<!-- /aew:spec -->$' "$v2" > "$b"
  expect_refusal "$b" "$I/spec-v3.md" 3 "malformed aew blocks"
  b="$W/m-twospec"; { cat "$v2"; printf '\n<!-- aew:spec v2 -->\nx\n<!-- /aew:spec -->\n'; } > "$b"
  expect_refusal "$b" "$I/spec-v3.md" 3 "malformed aew blocks"
  b="$W/m-relabel"; sed 's/aew:spec-prev v1/aew:spec-prev v3/' "$v2" > "$b"
  expect_refusal "$b" "$I/spec-v3.md" 3 "malformed aew blocks"
  b="$W/m-closek"; sed 's#^<!-- /aew:spec-prev v1 -->#<!-- /aew:spec-prev v2 -->#' "$v2" > "$b"
  expect_refusal "$b" "$I/spec-v3.md" 3 "malformed aew blocks"
  b="$W/m-nodetails"; sed "$(grep -n '^</details>$' "$v2" | tail -n 1 | cut -d: -f1)d" "$v2" > "$b"
  expect_refusal "$b" "$I/spec-v3.md" 3 "malformed aew blocks"
  b="$W/m-five"
  printf '<!-- aew:spec v2 -->\nS\n<!-- /aew:spec -->\n\n<!-- aew:spec-prev v1 -->\n<details>\n<summary>Spec v1 (original)</summary>\n\nx\n</details>\n<!-- /aew:spec-prev v1 -->\n' > "$b"
  expect_refusal "$b" "$I/spec-v3.md" 3 "malformed aew blocks"
  b="$W/m-nested"; awk '{ print } $0 == "<details>" && !d { print "<!-- aew:spec v2 -->"; d = 1 }' "$v2" > "$b"
  expect_refusal "$b" "$I/spec-v3.md" 3 "malformed aew blocks"
  b="$W/m-unknown"; awk '$0 == "<!-- aew:spec-prev v1 -->" { print "<!-- aew:foo -->" } { print }' "$v2" > "$b"
  expect_refusal "$b" "$I/spec-v3.md" 3 "malformed aew blocks"
  b="$W/m-v0"; sed 's/aew:spec v2/aew:spec v0/' "$v2" > "$b"
  expect_refusal "$b" "$I/spec-v3.md" 3 "malformed aew blocks"
  b="$W/m-v01"; sed 's/aew:spec v2/aew:spec v02/' "$v2" > "$b"
  expect_refusal "$b" "$I/spec-v3.md" 3 "malformed aew blocks"
  b="$W/m-twomanual"; { cat "$I/body-v1-manual.md"; printf '<!-- aew:manual-tests -->\nx\n<!-- /aew:manual-tests -->\n'; } > "$b"
  expect_refusal "$b" "$I/spec-v2.md" 2 "malformed aew blocks"
  b="$W/m-prevnospec"; sed '/^<!-- aew:spec v2 -->$/,/^<!-- \/aew:spec -->$/d' "$v2" > "$b"
  expect_refusal "$b" "$I/spec-v2.md" 2 "malformed aew blocks"
}

@test "4f. a failing gh issue edit exits 1" {
  gh_mock_issue 7 --body-file "$I/body-v1.md"
  gh_mock_respond issue-edit - 1 <<< "GraphQL: edit failed"
  revise 7 "$I/spec-v2.md" 2
  assert_failure 1
  assert_contains "$stderr" "error:"
}

@test "5. the 65,536 limit counts codepoints and never truncates" {
  gh_mock_issue 8 --body-file "$I/body-v1.md"
  printf 'x' > "$W/one.md"
  revise 8 "$W/one.md" 2
  assert_success
  local b0 pad
  gh_mock_body 8 > "$W/b8"
  b0=$(jq -n --rawfile b "$W/b8" '$b | length')
  pad=$((65536 - b0 + 1))
  perl -CS -e 'print "\x{e9}" x $ARGV[0]' "$pad" > "$W/fit.md"
  gh_mock_issue 9 --body-file "$I/body-v1.md"
  revise 9 "$W/fit.md" 2
  assert_success
  gh_mock_body 9 > "$W/b9"
  assert_equal "$(jq -n --rawfile b "$W/b9" '$b | length')" 65536
  [ "$(gh_mock_body 9 | wc -c | tr -d ' ')" -gt 65536 ]
  perl -CS -e 'print "\x{e9}" x $ARGV[0]' "$((pad + 1))" > "$W/over.md"
  gh_mock_issue 10 --body-file "$I/body-v1.md"
  local before
  before=$(edits)
  revise 10 "$W/over.md" 2
  assert_failure 1
  assert_contains "$stderr" "GitHub limit 65536"
  assert_equal "$(edits)" "$before"
  gh_mock_body 10 | cmp - "$I/body-v1.md"
}

@test "6. an existing manual-tests block is preserved between spec and v1" {
  gh_mock_issue 7 --body-file "$I/body-v1-manual.md"
  revise 7 "$I/spec-v2.md" 2
  assert_success
  gh_mock_body 7 > "$W/after"
  manual_of "$W/after" | cmp - "$I/manual-tests.md"
  prev_of "$W/after" 1 | cmp - "$I/body-v1.md"
  local s m p
  s=$(grep -n '^<!-- aew:spec v2 -->' "$W/after" | cut -d: -f1)
  m=$(grep -n '^<!-- aew:manual-tests -->' "$W/after" | cut -d: -f1)
  p=$(grep -n '^<!-- aew:spec-prev v1 -->' "$W/after" | cut -d: -f1)
  [ "$s" -lt "$m" ]
  [ "$m" -lt "$p" ]
  assert_no_line_lost "$I/body-v1-manual.md" "$W/after"
  revise 7 "$I/spec-v3.md" 3
  assert_success
  gh_mock_body 7 > "$W/after3"
  manual_of "$W/after3" | cmp - "$I/manual-tests.md"
  prev_of "$W/after3" 1 | cmp - "$I/body-v1.md"
  assert_no_line_lost "$I/body-v1-manual.md" "$W/after3"
}

@test "6b. author text after the manual block joins the v1 content" {
  { cat "$I/body-v1-manual.md"; printf '\nAuthor PS\n'; } > "$W/ps"
  gh_mock_issue 7 --body-file "$W/ps"
  revise 7 "$I/spec-v2.md" 2
  assert_success
  gh_mock_body 7 > "$W/after"
  { cat "$I/body-v1.md"; printf '\n\nAuthor PS'; } > "$W/want"
  prev_of "$W/after" 1 | cmp - "$W/want"
  manual_of "$W/after" | cmp - "$I/manual-tests.md"
  assert_no_line_lost "$W/ps" "$W/after"
  local n
  n=$(edits)
  revise 7 "$I/spec-v2.md" 2
  assert_success
  assert_equal "$(edits)" "$n"
  gh_mock_body 7 | cmp - "$W/after"
}

@test "7. content outside aew blocks is kept once, after the last prev block" {
  { printf 'Author note above\n'; cat "$I/expected-v2.md"; printf '\nAuthor follow-up\n'; } > "$W/o"
  gh_mock_issue 7 --body-file "$W/o"
  revise 7 "$I/spec-v3.md" 3
  assert_success
  gh_mock_body 7 > "$W/after"
  [ "$(grep -cx 'Author note above' "$W/after")" -eq 1 ]
  [ "$(grep -cx 'Author follow-up' "$W/after")" -eq 1 ]
  local last a f
  last=$(grep -n '^<!-- /aew:spec-prev v1 -->' "$W/after" | cut -d: -f1)
  a=$(grep -nx 'Author note above' "$W/after" | cut -d: -f1)
  f=$(grep -nx 'Author follow-up' "$W/after" | cut -d: -f1)
  [ "$a" -gt "$last" ]
  [ "$f" -gt "$a" ]
  prev_of "$W/after" 1 | cmp - "$I/body-v1.md"
  assert_no_line_lost "$W/o" "$W/after"
  local n
  n=$(edits)
  revise 7 "$I/spec-v3.md" 3
  assert_success
  assert_equal "$(edits)" "$n"
  gh_mock_body 7 | cmp - "$W/after"
}

@test "8. a CRLF re-saved body is tolerated" {
  perl -pe 's/\n/\r\n/' "$I/expected-v2.md" > "$W/crlf"
  gh_mock_issue 7 --body-file "$W/crlf"
  revise 7 "$I/spec-v3.md" 3
  assert_success
  gh_mock_body 7 > "$W/after"
  assert_no_line_lost "$I/body-v1.md" "$W/after"
  # the stored v2 content is the CRLF form of spec-v2.md plus the \r of the
  # block's final (empty) line
  { perl -pe 's/\n/\r\n/' "$I/spec-v2.md"; printf '\r'; } > "$W/want2"
  prev_of "$W/after" 2 | cmp - "$W/want2"
  spec_of "$W/after" | cmp - "$I/spec-v3.md"
}

@test "8b. B-2: same version on a CRLF body is a no-op for the content, never a refusal" {
  perl -pe 's/\n/\r\n/' "$I/expected-v2.md" > "$W/crlf"
  gh_mock_issue 7 --body-file "$W/crlf"
  revise 7 "$I/spec-v2.md" 2
  assert_success
  gh_mock_body 7 > "$W/after"
  spec_of "$W/after" | cmp - <(spec_of "$W/crlf")
  prev_of "$W/after" 1 | cmp - <(prev_of "$W/crlf" 1)
  assert_no_line_lost "$I/body-v1.md" "$W/after"
}

@test "8c. B-3: a spec file that is not valid UTF-8 is refused" {
  printf 'a\377b\n' > "$W/bad.md"
  gh_mock_issue 7 --body-file "$I/body-v1.md"
  revise 7 "$W/bad.md" 2
  assert_failure 1
  assert_contains "$stderr" "not valid UTF-8"
  assert_equal "$(edits)" 0
  gh_mock_body 7 | cmp - "$I/body-v1.md"
}

@test "9. an empty v1 body records an empty v1 and is then stable" {
  gh_mock_issue 7 --body ""
  revise 7 "$I/spec-v2.md" 2
  assert_success
  gh_mock_body 7 > "$W/after"
  [ "$(prev_of "$W/after" 1 | wc -c | tr -d ' ')" -eq 0 ]
  spec_of "$W/after" | cmp - "$I/spec-v2.md"
  revise 7 "$I/spec-v2.md" 2
  assert_success
  assert_equal "$(edits)" 1
  gh_mock_body 7 | cmp - "$W/after"
}

@test "10. dispatch: missing arguments fail and --help lists revise" {
  run --separate-stderr "$SCRIPTS/gh-issue.sh" revise
  assert_failure 1
  run --separate-stderr "$SCRIPTS/gh-issue.sh" revise 7 "$I/spec-v2.md"
  assert_failure 1
  run --separate-stderr "$SCRIPTS/gh-issue.sh" --help
  assert_success
  assert_contains "$output" "revise <n> <spec-file> <version>"
}

# --- review regressions -------------------------------------------------------

@test "R1. B-2 on a CRLF body is a fixed point, and a later LF revise round-trips" {
  perl -pe 's/\n/\r\n/' "$I/expected-v2.md" > "$W/crlf"
  gh_mock_issue 7 --body-file "$W/crlf"
  revise 7 "$I/spec-v2.md" 2
  assert_success
  gh_mock_body 7 > "$W/b2"
  local n
  n=$(edits)
  revise 7 "$I/spec-v2.md" 2
  assert_success
  assert_equal "$(edits)" "$n"
  gh_mock_body 7 | cmp - "$W/b2"
  revise 7 "$I/spec-v3.md" 3
  assert_success
  gh_mock_body 7 > "$W/b3"
  spec_of "$W/b3" | cmp - "$I/spec-v3.md"
  prev_of "$W/b3" 2 | cmp - <(spec_of "$W/crlf")
  prev_of "$W/b3" 1 | cmp - <(prev_of "$W/crlf" 1)
  assert_no_line_lost "$W/crlf" "$W/b3"
  n=$(edits)
  revise 7 "$I/spec-v3.md" 3
  assert_success
  assert_equal "$(edits)" "$n"
  printf '# v4\n' > "$W/s4.md"
  revise 7 "$W/s4.md" 4
  assert_success
  gh_mock_body 7 > "$W/b4"
  prev_of "$W/b4" 3 | cmp - "$I/spec-v3.md"
  prev_of "$W/b4" 2 | cmp - <(spec_of "$W/crlf")
  prev_of "$W/b4" 1 | cmp - <(prev_of "$W/crlf" 1)
  assert_no_line_lost "$W/b3" "$W/b4"
}

@test "R2. multi-byte characters across 4096-byte read chunks survive byte for byte" {
  local pre
  for pre in 1 2 4094; do
    perl -CS -e 'print "a" x $ARGV[0]; print "\x{e9}\x{1F600}\x{20AC}\n" x 1500' "$pre" > "$W/mb.md"
    gh_mock_issue 7 --body-file "$W/mb.md"
    revise 7 "$W/mb.md" 2
    assert_success
    gh_mock_body 7 > "$W/after"
    prev_of "$W/after" 1 | cmp - "$W/mb.md"
    spec_of "$W/after" | cmp - "$W/mb.md"
  done
}

@test "R3. a spec file without a final newline is stored exactly and is idempotent" {
  printf '# no newline at end' > "$W/nonl.md"
  gh_mock_issue 7 --body-file "$I/body-v1.md"
  revise 7 "$W/nonl.md" 2
  assert_success
  gh_mock_body 7 > "$W/after"
  spec_of "$W/after" | cmp - "$W/nonl.md"
  revise 7 "$W/nonl.md" 2
  assert_success
  assert_equal "$(edits)" 1
  printf '# no newline at end\n' > "$W/nl.md"
  expect_refusal "$W/after" "$W/nl.md" 2 "already recorded with different content"
}

@test "R4. more malformed shapes are refused: duplicate prev, missing prev, stray close, unclosed tail block" {
  local v2="$I/expected-v2.md" b
  b="$W/r-dupprev"; { cat "$v2"; printf '\n<!-- aew:spec-prev v1 -->\n<details>\n<summary>Spec v1 (original)</summary>\n\nx\n\n</details>\n<!-- /aew:spec-prev v1 -->\n'; } > "$b"
  expect_refusal "$b" "$I/spec-v3.md" 3 "malformed aew blocks"
  b="$W/r-missingprev"; sed -e 's/aew:spec v2/aew:spec v3/' -e 's/aew:spec-prev v1/aew:spec-prev v2/' "$v2" > "$b"
  expect_refusal "$b" "$I/spec-v3.md" 3 "malformed aew blocks"
  # a huge version must be refused at once, not build range(1; N)
  b="$W/r-hugev"; sed 's/aew:spec v2/aew:spec v99999999999999999999/' "$v2" > "$b"
  expect_refusal "$b" "$I/spec-v3.md" 3 "malformed aew blocks"
  b="$W/r-strayclose"; awk '$0 == "<!-- aew:spec-prev v1 -->" { print "<!-- /aew:spec-prev v1 -->" } { print }' "$v2" > "$b"
  expect_refusal "$b" "$I/spec-v3.md" 3 "malformed aew blocks"
  b="$W/r-unclosed"; { cat "$v2"; printf '\n<!-- aew:manual-tests -->\n- [ ] x\n'; } > "$b"
  expect_refusal "$b" "$I/spec-v3.md" 3 "malformed aew blocks"
  b="$W/r-unclosed-v1"; { cat "$I/body-v1.md"; printf '<!-- aew:manual-tests -->\n- [ ] x'; } > "$b"
  expect_refusal "$b" "$I/spec-v2.md" 2 "malformed aew blocks"
}

# --- manual-tests (B3) ----------------------------------------------------------

mt() { run --separate-stderr "$SCRIPTS/gh-issue.sh" manual-tests "$@"; }

@test "M1. an unmanaged body gets the golden manual block and keeps the author's bytes as a prefix" {
  gh_mock_issue 7 --body-file "$I/body-v1.md"
  mt 7 "$I/manual-tests.md"
  assert_success
  gh_mock_body 7 > "$W/after"
  cmp "$W/after" "$I/body-v1-manual.md"
  head -c "$(wc -c < "$I/body-v1.md" | tr -d ' ')" "$W/after" | cmp - "$I/body-v1.md"
  manual_of "$W/after" | cmp - "$I/manual-tests.md"
  assert_no_line_lost "$I/body-v1.md" "$W/after"
  assert_equal "$(edits)" 1
  [ -z "$output" ]
}

@test "M2. running it again is idempotent: same body, no second edit" {
  gh_mock_issue 7 --body-file "$I/body-v1.md"
  mt 7 "$I/manual-tests.md"
  assert_success
  gh_mock_body 7 > "$W/after1"
  mt 7 "$I/manual-tests.md"
  assert_success
  assert_contains "$stderr" "unchanged"
  gh_mock_body 7 | cmp - "$W/after1"
  assert_equal "$(edits)" 1
}

@test "M3. a different file replaces the block, leaving one block and the author's prefix" {
  gh_mock_issue 7 --body-file "$I/body-v1.md"
  mt 7 "$I/manual-tests.md"
  assert_success
  mt 7 "$I/manual-tests-2.md"
  assert_success
  gh_mock_body 7 > "$W/after"
  assert_equal "$(grep -c '^<!-- aew:manual-tests -->' "$W/after")" 1
  manual_of "$W/after" | cmp - "$I/manual-tests-2.md"
  head -c "$(wc -c < "$I/body-v1.md" | tr -d ' ')" "$W/after" | cmp - "$I/body-v1.md"
  ! grep -qF 'Export an empty list' "$W/after"
  assert_no_line_lost "$I/body-v1.md" "$W/after"
  assert_no_line_lost "$I/body-v1-manual.md" "$W/after" --except-manual
}

@test "M4. a managed body: block between spec and history, spec and history byte-identical, O kept" {
  gh_mock_issue 7 --body-file "$I/expected-v2.md"
  revise 7 "$I/spec-v3.md" 3
  assert_success
  gh_mock_body 7 > "$W/b3"
  printf '\nAuthor paragraph O\n' >> "$W/b3"
  gh_mock_issue 7 --body-file "$W/b3"
  mt 7 "$I/manual-tests.md"
  assert_success
  gh_mock_body 7 > "$W/m1"
  local s m p
  s=$(grep -n '^<!-- aew:spec v3 -->' "$W/m1" | cut -d: -f1)
  m=$(grep -n '^<!-- aew:manual-tests -->' "$W/m1" | cut -d: -f1)
  p=$(grep -n '^<!-- aew:spec-prev v2 -->' "$W/m1" | cut -d: -f1)
  [ "$s" -lt "$m" ]
  [ "$m" -lt "$p" ]
  spec_of "$W/m1" | cmp - <(spec_of "$W/b3")
  prev_of "$W/m1" 2 | cmp - <(prev_of "$W/b3" 2)
  prev_of "$W/m1" 1 | cmp - <(prev_of "$W/b3" 1)
  manual_of "$W/m1" | cmp - "$I/manual-tests.md"
  grep -qxF 'Author paragraph O' "$W/m1"
  assert_no_line_lost "$W/b3" "$W/m1"
  mt 7 "$I/manual-tests-2.md"
  assert_success
  gh_mock_body 7 > "$W/m2"
  manual_of "$W/m2" | cmp - "$I/manual-tests-2.md"
  spec_of "$W/m2" | cmp - <(spec_of "$W/b3")
  prev_of "$W/m2" 2 | cmp - <(prev_of "$W/b3" 2)
  prev_of "$W/m2" 1 | cmp - <(prev_of "$W/b3" 1)
  grep -qxF 'Author paragraph O' "$W/m2"
  assert_no_line_lost "$W/m1" "$W/m2" --except-manual
  assert_equal "$(grep -c '^<!-- aew:manual-tests -->' "$W/m2")" 1
}

@test "M5. end to end on a CRLF v1 without a final newline: v1 survives both revisions" {
  crlf_nonl "$I/body-v1.md" > "$W/crlf"
  gh_mock_issue 7 --body-file "$W/crlf"
  mt 7 "$I/manual-tests.md"
  assert_success
  gh_mock_body 7 > "$W/a0"
  head -c "$(wc -c < "$W/crlf" | tr -d ' ')" "$W/a0" | cmp - "$W/crlf"
  assert_no_line_lost "$W/crlf" "$W/a0"
  revise 7 "$I/spec-v2.md" 2
  assert_success
  revise 7 "$I/spec-v3.md" 3
  assert_success
  gh_mock_body 7 > "$W/a3"
  prev_of "$W/a3" 1 | cmp - "$W/crlf"
  manual_of "$W/a3" | cmp - "$I/manual-tests.md"
  assert_no_line_lost "$W/crlf" "$W/a3"
}

@test "M6. refusals leave the body alone and make no edit" {
  gh_mock_issue 7 --body-file "$I/body-v1.md"
  local n
  n=$(edits)
  : > "$W/empty.md"
  printf 'x\n<!-- /aew:manual-tests -->\n' > "$W/marker.md"
  printf 'a\377b\n' > "$W/bad.md"
  mt 7 "$W/empty.md"
  assert_failure 1
  mt 7 "$W/missing.md"
  assert_failure 1
  mt 7 "$W/marker.md"
  assert_failure 1
  assert_contains "$stderr" "marker"
  mt 7 "$W/bad.md"
  assert_failure 1
  assert_contains "$stderr" "not valid UTF-8"
  mt 0 "$I/manual-tests.md"
  assert_failure 1
  assert_contains "$stderr" "invalid issue number"
  mt abc "$I/manual-tests.md"
  assert_failure 1
  mt 7
  assert_failure 1
  assert_equal "$(edits)" "$n"
  gh_mock_body 7 | cmp - "$I/body-v1.md"
  # malformed body: two manual blocks
  { cat "$I/body-v1-manual.md"; printf '<!-- aew:manual-tests -->\nx\n<!-- /aew:manual-tests -->\n'; } > "$W/two"
  gh_mock_issue 8 --body-file "$W/two"
  mt 8 "$I/manual-tests.md"
  assert_failure 1
  assert_contains "$stderr" "malformed aew blocks"
  gh_mock_body 8 | cmp - "$W/two"
  # a body pushed over the limit
  perl -CS -e 'print "\x{e9}" x 65530' > "$W/big"
  gh_mock_issue 9 --body-file "$W/big"
  mt 9 "$I/manual-tests.md"
  assert_failure 1
  assert_contains "$stderr" "GitHub limit 65536"
  gh_mock_body 9 | cmp - "$W/big"
  assert_equal "$(edits)" "$n"
}

@test "M7. labels are untouched" {
  gh_mock_issue 7 --body-file "$I/body-v1.md" --labels "aew:building,bug"
  local before
  before=$(gh_mock_labels 7)
  mt 7 "$I/manual-tests.md"
  assert_success
  assert_equal "$(gh_mock_labels 7)" "$before"
  ! gh_calls | grep -q -e '--add-label'
  ! gh_calls | grep -q -e '--remove-label'
}

@test "M8. dispatch: --help lists manual-tests" {
  run --separate-stderr "$SCRIPTS/gh-issue.sh" --help
  assert_success
  assert_contains "$output" "manual-tests <n> <file>"
}
