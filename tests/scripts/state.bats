#!/usr/bin/env bats
# Tests for scripts/state.sh. Every successful state-changing call snapshots
# state.json so the last test can validate all of them against the schema.

load helpers/common

setup() {
  common_setup
  setup_project
  SNAPN=0
  mkdir -p "$BATS_FILE_TMPDIR/snapshots"
}

# st <args…>: run state.sh, then snapshot state.json (if any).
st() {
  run --separate-stderr "$SCRIPTS/state.sh" "$@"
  if [ -f "$PROJECT/.aew/runs/current" ]; then
    local cur d
    cur=$(head -n 1 "$PROJECT/.aew/runs/current")
    d="$PROJECT/.aew/runs/$cur"
    if [ -f "$d/state.json" ]; then
      SNAPN=$((SNAPN + 1))
      cp "$d/state.json" "$BATS_FILE_TMPDIR/snapshots/${BATS_TEST_NUMBER}-${SNAPN}.json"
    fi
  fi
}

rdir() { printf '%s\n' "$PROJECT/.aew/runs/$1"; }

@test "init writes state.json, log.md and current" {
  st init 12 --issues 12 --mode single --title "Add widget"
  assert_success
  local d
  d=$(rdir 12)
  assert_json "$d/state.json" '.run_id == "12" and .issues == [12] and .title == "Add widget" and .mode == "single" and .auto == false'
  assert_json "$d/state.json" '.stage == "spec_analysis" and .status == "running" and .branch == null and .pr == null'
  assert_json "$d/state.json" '.base_branch == "main" and .spec_revision == 1 and .fix_cycle == 0 and .review_cycle == 0'
  assert_json "$d/state.json" '.started_at == .updated_at'
  assert_json "$d/state.json" '(.history | length) == 1 and (.history[0] | has("note") | not) and .history[0].stage == "spec_analysis"'
  assert_equal "$(wc -l < "$d/log.md" | tr -d ' ')" 1
  grep -Eq '^- [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z spec_analysis running$' "$d/log.md"
  assert_equal "$(cat "$PROJECT/.aew/runs/current")" 12
}

@test "init follows config base branch, --auto and milestone runs" {
  write_config '{"default_branch":"trunk"}'
  st init 12 --issues 12 --mode single
  assert_success
  assert_json "$(rdir 12)/state.json" '.base_branch == "trunk" and .title == ""'
  st init 13 --issues 13 --mode single --auto
  assert_success
  assert_json "$(rdir 13)/state.json" '.auto == true'
  st init m-3 --issues 4,5 --mode bulk
  assert_success
  assert_json "$(rdir m-3)/state.json" '.run_id == "m-3" and .issues == [4,5] and .mode == "bulk"'
}

@test "init --mode bulk creates an issues/<k> dir per issue" {
  st init m-3 --issues 4,5 --mode bulk --title "Sprint 3"
  assert_success
  [ -d "$(rdir m-3)/issues/4" ]
  [ -d "$(rdir m-3)/issues/5" ]
  [ -z "$(ls -A "$(rdir m-3)/issues/4")" ]
  [ -z "$(ls -A "$(rdir m-3)/issues/5")" ]
  [ "$(ls "$(rdir m-3)/issues" | wc -l | tr -d ' ')" = 2 ]
  gh_mock_issue 4
  run "$SCRIPTS/gh-issue.sh" fetch 4 "$(rdir m-3)/issues/4"
  assert_success
  [ -f "$(rdir m-3)/issues/4/issue.json" ]
}

@test "init in other modes creates no issues dir" {
  st init 41 --issues 41 --mode single
  assert_success
  st init m-4 --issues 4,5 --mode sequential
  assert_success
  st init 42 --issues 42 --mode sequential-child
  assert_success
  [ ! -e "$(rdir 41)/issues" ]
  [ ! -e "$(rdir m-4)/issues" ]
  [ ! -e "$(rdir 42)/issues" ]
}

@test "init refusals create nothing" {
  st init 12 --issues 12 --mode single
  assert_success
  local before after
  before=$(find "$PROJECT/.aew/runs" | sort | tr '\n' ' ')
  local args
  for args in "12 --issues 12 --mode single" "0 --issues 1 --mode single" "abc --issues 1 --mode single" \
    "../x --issues 1 --mode single" "20 --issues  --mode single" "20 --issues 1,,2 --mode single" \
    "20 --issues 1,1 --mode single" "20 --issues x --mode single" "20 --issues 1" \
    "20 --issues 1 --mode solo" "20 --issues 1 --mode single --bogus" \
    "m-9 --issues 4,4 --mode bulk"; do
    # shellcheck disable=SC2086  # word splitting of the case string is intended
    run --separate-stderr "$SCRIPTS/state.sh" init $args
    assert_failure 1
    assert_contains "$stderr" "error:"
    after=$(find "$PROJECT/.aew/runs" | sort | tr '\n' ' ')
    assert_equal "$after" "$before"
  done
}

@test "init refusal on a fresh project creates no .aew/runs" {
  run --separate-stderr "$SCRIPTS/state.sh" init 20 --issues 1 --mode solo
  assert_failure 1
  [ ! -e "$PROJECT/.aew/runs" ]
}

@test "get prints whole state or one field" {
  seed_run 12
  st get
  assert_success
  printf '%s' "$output" | jq -e '.run_id == "12"' > /dev/null
  st get stage
  assert_equal "$output" spec_analysis
  st get pr
  assert_equal "$output" null
  st get issues
  assert_equal "$output" "[12]"
  st get nosuch
  assert_failure 1
}

@test "get failure modes: no current run, missing state.json, corrupt state.json" {
  run --separate-stderr "$SCRIPTS/state.sh" get
  assert_failure 1
  assert_contains "$stderr" "no current run"
  mkdir -p "$PROJECT/.aew/runs/5"
  printf '5\n' > "$PROJECT/.aew/runs/current"
  run --separate-stderr "$SCRIPTS/state.sh" get
  assert_failure 1
  assert_contains "$stderr" "no state.json"
  printf '{nope' > "$PROJECT/.aew/runs/5/state.json"
  run --separate-stderr "$SCRIPTS/state.sh" get stage
  assert_failure 1
  assert_contains "$stderr" "not valid JSON"
}

@test "stage and status record history and log lines" {
  seed_run 12
  local d
  d=$(rdir 12)
  st stage brief --note "spec confirmed"
  assert_success
  assert_json "$d/state.json" '.stage == "brief" and .status == "running" and (.history | length) == 2 and .history[1].note == "spec confirmed"'
  assert_equal "$(wc -l < "$d/log.md" | tr -d ' ')" 2
  tail -n 1 "$d/log.md" | grep -Eq ' brief running — spec confirmed$'
  st status awaiting_input --note "1 material change"
  assert_success
  assert_json "$d/state.json" '.stage == "brief" and .status == "awaiting_input" and (.history | length) == 3'
  st status blocked
  assert_json "$d/state.json" '(.history[3] | has("note") | not)'
  st stage develop
  assert_json "$d/state.json" '.stage == "develop" and .status == "running"'
  assert_equal "$(wc -l < "$d/log.md" | tr -d ' ')" 5
}

@test "updated_at changes on every write, started_at never" {
  seed_run 12
  local d tmp
  d=$(rdir 12)
  local cmd
  for cmd in "stage brief" "status blocked" "bump fix_cycle" "set title X"; do
    tmp="$BATS_TEST_TMPDIR/t.json"
    jq '.updated_at = "2000-01-01T00:00:00Z"' "$d/state.json" > "$tmp" && cp "$tmp" "$d/state.json"
    local started
    started=$(jq -r .started_at "$d/state.json")
    # shellcheck disable=SC2086
    st $cmd
    assert_success
    assert_json "$d/state.json" '.updated_at != "2000-01-01T00:00:00Z"'
    assert_equal "$(jq -r .started_at "$d/state.json")" "$started"
  done
}

@test "bump increments, prints, and logs nothing" {
  seed_run 12
  local d
  d=$(rdir 12)
  st bump fix_cycle
  assert_success
  assert_equal "$output" 1
  st bump fix_cycle
  assert_equal "$output" 2
  st bump review_cycle
  assert_equal "$output" 1
  assert_json "$d/state.json" '.fix_cycle == 2 and .review_cycle == 1 and (.history | length) == 1'
  assert_equal "$(wc -l < "$d/log.md" | tr -d ' ')" 1
}

@test "set coerces by schema type" {
  seed_run 12
  local d
  d=$(rdir 12)
  st set branch feat/12-x
  assert_json "$d/state.json" '.branch == "feat/12-x"'
  st set branch null
  assert_json "$d/state.json" '.branch == null'
  st set pr 7
  assert_json "$d/state.json" '.pr == 7'
  st set pr null
  assert_json "$d/state.json" '.pr == null'
  st set spec_revision 2
  assert_json "$d/state.json" '.spec_revision == 2'
  st set auto true
  assert_json "$d/state.json" '.auto == true'
  st set title "New title"
  assert_json "$d/state.json" '.title == "New title"'
  st set base_branch develop
  assert_json "$d/state.json" '.base_branch == "develop"'
  st set title null
  assert_failure 1
}

@test "invalid input leaves state.json byte-identical" {
  seed_run 12
  local d c nlog
  d=$(rdir 12)
  for c in "stage nosuch" "status nosuch" "bump nosuch" "bump issues" "set pr 0" "set pr abc" \
    "set spec_revision 0" "set auto yes" "set stage develop" "set history x" "set run_id 5" \
    "set nosuch 1" "stage" "set pr"; do
    cp "$d/state.json" "$BATS_TEST_TMPDIR/before"
    nlog=$(wc -l < "$d/log.md")
    # shellcheck disable=SC2086
    run --separate-stderr "$SCRIPTS/state.sh" $c
    assert_failure 1
    assert_contains "$stderr" "error:"
    cmp "$BATS_TEST_TMPDIR/before" "$d/state.json"
    assert_equal "$(wc -l < "$d/log.md")" "$nlog"
  done
}

@test "writes are atomic and leave no temp files" {
  seed_run 12
  local d i1 i2
  d=$(rdir 12)
  i1=$(ls -i "$d/state.json" | cut -d' ' -f1)
  st stage brief
  i2=$(ls -i "$d/state.json" | cut -d' ' -f1)
  [ "$i1" != "$i2" ]
  run --separate-stderr "$SCRIPTS/state.sh" stage nosuch
  [ -z "$(find "$PROJECT/.aew/runs" -name '.state.json.*' -o -name '.current.*')" ]
}

@test "current reads, sets and clears" {
  seed_run 12
  seed_run m-3
  printf '12\n' > "$PROJECT/.aew/runs/current"
  st current
  assert_equal "$output" 12
  st current set 99
  assert_failure 1
  st current set m-3
  assert_success
  st current
  assert_equal "$output" m-3
  st current clear
  assert_success
  [ ! -e "$PROJECT/.aew/runs/current" ]
  st current clear
  assert_success
  run --separate-stderr "$SCRIPTS/state.sh" current
  assert_failure 1
  assert_contains "$stderr" "no current run"
}

@test "works from a linked worktree" {
  seed_run 12
  git worktree add -q "$BATS_TEST_TMPDIR/wt" -b wt-branch
  cd "$BATS_TEST_TMPDIR/wt"
  run --separate-stderr "$SCRIPTS/state.sh" get stage
  assert_success
  assert_equal "$output" spec_analysis
}

@test "index init writes the order, stack_on and pending children" {
  st init m-4 --issues 42,43,41 --mode sequential
  st init 7 --issues 7 --mode single
  st index init m-4 --stack-on 43:42,41:43
  assert_success
  assert_equal "$output" ""
  local f
  f=$(rdir m-4)/index.json
  run jq -S -c . "$f"
  assert_equal "$output" "$(printf '%s' '{"run_id":"m-4","order":[42,43,41],"children":[{"issue":42,"stack_on":null,"status":"pending"},{"issue":43,"stack_on":42,"status":"pending"},{"issue":41,"stack_on":43,"status":"pending"}]}' | jq -S -c .)"
  assert_json "$f" '(keys | sort) == ["children","order","run_id"]'
  assert_equal "$(head -n 1 "$PROJECT/.aew/runs/current")" 7
  st init m-5 --issues 5,6 --mode sequential
  st index init m-5
  assert_success
  assert_json "$(rdir m-5)/index.json" '[.children[].stack_on] == [null,null] and ([.children[].status] | unique) == ["pending"]'
}

@test "index set changes one child's status" {
  st init m-4 --issues 42,43,41 --mode sequential
  st index init m-4
  local s f
  f=$(rdir m-4)/index.json
  for s in running done blocked failed pending; do
    st index set m-4 43 "$s"
    assert_success
    assert_json "$f" "(.children[] | select(.issue == 43) | .status) == \"$s\" and ([.children[] | select(.issue != 43) | .status] == [\"pending\",\"pending\"])"
  done
  st index set m-4 43 pending
  assert_success
  st index set m-4 43 failed
  st index set m-4 43 running
  assert_success
  [ -z "$(find "$(rdir m-4)" -name '.index.json.*')" ]
}

@test "index init refusals write nothing" {
  st init m-4 --issues 42,43,41 --mode sequential
  st init m-6 --issues 4,5 --mode bulk
  st init 9 --issues 9 --mode single
  st init m-8 --issues 8 --mode sequential-child
  local d args
  d=$(rdir m-4)
  for args in "" "m-x" "m-77" "m-6" "9" "m-8" \
    "m-4 --stack-on" "m-4 --stack-on 43-42" "m-4 --stack-on 43:42,43:42" \
    "m-4 --stack-on 99:42" "m-4 --stack-on 43:99" "m-4 --stack-on 42:43" \
    "m-4 --stack-on 42:42" "m-4 --bogus"; do
    # shellcheck disable=SC2086
    st index init $args
    assert_failure 1
    assert_contains "$stderr" "error:"
    [ ! -e "$d/index.json" ]
  done
  st index init m-4 --stack-on ""
  assert_failure 1
  [ ! -e "$d/index.json" ]
  st index init m-4
  assert_success
  cp "$d/index.json" "$BATS_TEST_TMPDIR/before.json"
  st index init m-4
  assert_failure 1
  assert_contains "$stderr" "error:"
  cmp "$d/index.json" "$BATS_TEST_TMPDIR/before.json"
}

@test "index set refusals leave index.json byte-identical" {
  st init m-4 --issues 42,43,41 --mode sequential
  local f args
  f=$(rdir m-4)/index.json
  st index set m-4 43 running
  assert_failure 1
  assert_contains "$stderr" "error:"
  [ ! -e "$f" ]
  st index init m-4
  cp "$f" "$BATS_TEST_TMPDIR/before.json"
  for args in "m-4 43 skipped" "m-4 99 done" "m-4 x done" "m-4 43" "m-4" "" "m-x 43 done"; do
    # shellcheck disable=SC2086
    st index set $args
    assert_failure 1
    assert_contains "$stderr" "error:"
    cmp "$f" "$BATS_TEST_TMPDIR/before.json"
  done
  printf 'not json' > "$f"
  cp "$f" "$BATS_TEST_TMPDIR/before.json"
  st index set m-4 43 done
  assert_failure 1
  assert_contains "$stderr" "error:"
  cmp "$f" "$BATS_TEST_TMPDIR/before.json"
}

@test "--help documents index" {
  run "$SCRIPTS/state.sh" --help
  assert_success
  assert_contains "$output" "index init <run-id>"
  assert_contains "$output" "index set <run-id>"
  assert_contains "$output" "not on .aew/runs/current"
}

@test "seed_run creates a readable current run" {
  seed_run 12
  run --separate-stderr "$SCRIPTS/state.sh" get run_id
  assert_equal "$output" 12
}

@test "validator self-test: a bad timestamp is rejected" {
  seed_run 12
  jq '.started_at = "nope"' "$(rdir 12)/state.json" > "$BATS_TEST_TMPDIR/bad.json"
  run validate_json_schema "$REPO_ROOT/templates/state.schema.json" "$BATS_TEST_TMPDIR/bad.json"
  [ "$status" -ne 0 ]
}

@test "AC-4: every snapshot validates against state.schema.json" {
  local files=("$BATS_FILE_TMPDIR"/snapshots/*.json)
  [ "${#files[@]}" -ge 25 ]
  validate_json_schema "$REPO_ROOT/templates/state.schema.json" "${files[@]}"
}
