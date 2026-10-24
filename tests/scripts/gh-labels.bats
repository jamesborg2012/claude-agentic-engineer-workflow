#!/usr/bin/env bats
# Tests for scripts/gh-labels.sh (ensure, stage, flag) against the gh shim.

load helpers/common

STAGES="analysing awaiting-input planning awaiting-approval building testing documenting ready-for-review blocked"

setup() {
  common_setup
}

edit_count() { gh_call_count "issue edit"; }

@test "ensure creates all 11 labels in table order with --force" {
  run --separate-stderr "$SCRIPTS/gh-labels.sh" ensure
  assert_success
  assert_equal "$(gh_call_count "label create")" 11
  assert_gh_called "label create aew:analysing --color 1D76DB --description aew: spec analysis is running --force"
  assert_gh_called "label create aew:manual-test-required --color D93F0B"
  local first last
  first=$(gh_calls | sed -n 1p)
  last=$(gh_calls | sed -n 11p)
  assert_contains "$first" "label create aew:analysing "
  assert_contains "$last" "label create aew:manual-test-required "
  local l
  for l in $STAGES spec-revised manual-test-required; do
    assert_equal "$(gh_call_count "label create aew:$l ")" 1
  done
}

@test "ensure creates exactly the DESIGN 7.4 label set, each call well formed" {
  run --separate-stderr "$SCRIPTS/gh-labels.sh" ensure
  assert_success
  local design created bad
  design=$(awk '/^### 7\.4 Labels/ { f = 1; next } f && /^###/ { exit } f' "$REPO_ROOT/docs/DESIGN.md" |
    grep -oE 'aew:[a-z-]+' | sort -u)
  [ -n "$design" ]
  created=$(gh_calls | awk '$1 == "label" && $2 == "create" { print $3 }' | sort)
  assert_equal "$created" "$design"
  bad=$(gh_calls | grep -vE '^label create aew:[a-z-]+ --color [0-9A-Fa-f]{6} --description .+ --force$' || true)
  assert_equal "$bad" ""
}

@test "ensure fails fast on a gh error and rejects extra arguments" {
  gh_mock_respond label-create - 1 3 <<< "boom"
  run --separate-stderr "$SCRIPTS/gh-labels.sh" ensure
  assert_failure 1
  assert_contains "$stderr" "error:"
  assert_contains "$stderr" "aew:planning"
  assert_equal "$(gh_call_count "label create")" 3
  : > "$GH_MOCK_DIR/calls.log"
  run --separate-stderr "$SCRIPTS/gh-labels.sh" ensure extra
  assert_failure 1
  assert_contains "$stderr" "error:"
  assert_equal "$(gh_call_count)" 0
}

@test "stage replaces other stage labels in one edit and keeps the rest" {
  gh_mock_issue 12 --labels aew:analysing,aew:planning,aew:spec-revised,enhancement
  run --separate-stderr "$SCRIPTS/gh-labels.sh" stage 12 building
  assert_success
  assert_equal "$(gh_mock_labels 12)" "$(printf 'aew:building\naew:spec-revised\nenhancement')"
  assert_equal "$(edit_count)" 1
  assert_gh_called "issue edit 12 --add-label aew:building --remove-label aew:analysing,aew:planning"
}

@test "stage accepts the aew: prefix" {
  gh_mock_issue 12 --labels aew:planning,bug
  run --separate-stderr "$SCRIPTS/gh-labels.sh" stage 12 aew:building
  assert_success
  assert_equal "$(gh_mock_labels 12)" "$(printf 'aew:building\nbug')"
}

@test "stage is idempotent when already set" {
  gh_mock_issue 12 --labels aew:building,bug
  run --separate-stderr "$SCRIPTS/gh-labels.sh" stage 12 building
  assert_success
  assert_equal "$(edit_count)" 0
  assert_equal "$(gh_mock_labels 12)" "$(printf 'aew:building\nbug')"
}

@test "stage removes only when the target is present beside another stage label" {
  gh_mock_issue 12 --labels aew:building,aew:testing
  run --separate-stderr "$SCRIPTS/gh-labels.sh" stage 12 building
  assert_success
  assert_equal "$(edit_count)" 1
  refute_gh_called "--add-label"
  assert_equal "$(gh_mock_labels 12)" "aew:building"
}

@test "stage adds only when there is no stage label" {
  gh_mock_issue 12 --labels bug
  run --separate-stderr "$SCRIPTS/gh-labels.sh" stage 12 planning
  assert_success
  refute_gh_called "--remove-label"
  assert_gh_called "issue edit 12 --add-label aew:planning"
}

@test "stage accepts every one of the 9 stage names" {
  local s n=20
  for s in $STAGES; do
    n=$((n + 1))
    gh_mock_issue "$n" --labels aew:blocked,bug
    run --separate-stderr "$SCRIPTS/gh-labels.sh" stage "$n" "$s"
    assert_success
    assert_equal "$(gh_mock_labels "$n" | grep -c '^aew:')" 1
    gh_mock_labels "$n" | grep -qx "aew:$s"
  done
}

@test "flag add and remove leave the stage label alone" {
  gh_mock_issue 12 --labels aew:building
  run --separate-stderr "$SCRIPTS/gh-labels.sh" flag 12 add spec-revised
  assert_success
  assert_equal "$(gh_mock_labels 12)" "$(printf 'aew:building\naew:spec-revised')"
  run --separate-stderr "$SCRIPTS/gh-labels.sh" flag 12 add aew:manual-test-required
  assert_success
  gh_mock_labels 12 | grep -qx "aew:manual-test-required"
  run --separate-stderr "$SCRIPTS/gh-labels.sh" flag 12 remove spec-revised
  assert_success
  assert_equal "$(gh_mock_labels 12)" "$(printf 'aew:building\naew:manual-test-required')"
}

@test "flag is a no-op (exit 0, no edit) when nothing would change" {
  gh_mock_issue 12 --labels aew:building,aew:spec-revised
  run --separate-stderr "$SCRIPTS/gh-labels.sh" flag 12 add spec-revised
  assert_success
  run --separate-stderr "$SCRIPTS/gh-labels.sh" flag 12 remove manual-test-required
  assert_success
  assert_equal "$(edit_count)" 0
}

@test "flag rejections make no gh call" {
  gh_mock_issue 12 --labels aew:building
  : > "$GH_MOCK_DIR/calls.log"
  local args
  for args in "12 add blocked" "12 add aew:building" "12 add bug" "12 toggle spec-revised" "12 add" "12" "x add spec-revised"; do
    # shellcheck disable=SC2086
    run --separate-stderr "$SCRIPTS/gh-labels.sh" flag $args
    assert_failure 1
    assert_contains "$stderr" "error:"
  done
  run --separate-stderr "$SCRIPTS/gh-labels.sh" flag 12 add ""
  assert_failure 1
  assert_contains "$stderr" "error:"
  assert_equal "$(gh_call_count)" 0
}

@test "stage rejections make no gh call" {
  gh_mock_issue 12 --labels aew:building
  : > "$GH_MOCK_DIR/calls.log"
  local args
  for args in "12 nosuch" "12 spec-revised" "x building" "0 building" "012 building" "12"; do
    # shellcheck disable=SC2086
    run --separate-stderr "$SCRIPTS/gh-labels.sh" stage $args
    assert_failure 1
    assert_contains "$stderr" "error:"
  done
  assert_equal "$(gh_call_count)" 0
}

@test "gh errors propagate" {
  run --separate-stderr "$SCRIPTS/gh-labels.sh" stage 404 building
  assert_failure 1
  assert_contains "$stderr" "error:"
  assert_equal "$(edit_count)" 0
  gh_mock_issue 12 --labels aew:planning
  gh_mock_respond issue-edit - 1 <<< "nope"
  run --separate-stderr "$SCRIPTS/gh-labels.sh" stage 12 building
  assert_failure 1
  assert_contains "$stderr" "error:"
}

@test "unknown subcommand fails and --help lists the subcommands" {
  run --separate-stderr "$SCRIPTS/gh-labels.sh" nosuch
  assert_failure 1
  assert_contains "$stderr" "error:"
  run --separate-stderr "$SCRIPTS/gh-labels.sh" --help
  assert_success
  assert_contains "$output" "ensure"
  assert_contains "$output" "stage"
  assert_contains "$output" "flag"
}
