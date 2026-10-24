load helpers/common

setup() {
  common_setup
  setup_project
  gh_mock_respond issue-list "$FIXTURES/milestone/issues.json"
}

# deps <number>: the depends_on of one issue from the last run, compact.
deps() { printf '%s' "$output" | jq -c --argjson n "$1" '.[] | select(.number == $n) | .depends_on'; }

@test "blocked by a single issue" {
  run --separate-stderr "$SCRIPTS/gh-milestone.sh" issues 3
  assert_success
  assert_equal "$(deps 101)" '[3]'
}

@test "list forms are case-insensitive, with an optional colon" {
  run --separate-stderr "$SCRIPTS/gh-milestone.sh" issues 3
  assert_success
  assert_equal "$(deps 102)" '[3,4,5]'
  assert_equal "$(deps 103)" '[6,7]'
}

@test "task list items count only when the issue is the first token" {
  run --separate-stderr "$SCRIPTS/gh-milestone.sh" issues 3
  assert_success
  assert_equal "$(deps 104)" '[8,9,10]'
}

@test "native blockedBy as an array and as a connection" {
  run --separate-stderr "$SCRIPTS/gh-milestone.sh" issues 3
  assert_success
  assert_equal "$(deps 105)" '[13]'
  assert_equal "$(deps 106)" '[14]'
}

@test "sources are merged, de-duplicated and sorted" {
  run --separate-stderr "$SCRIPTS/gh-milestone.sh" issues 3
  assert_success
  assert_equal "$(deps 107)" '[3,5]'
}

@test "a self-reference is dropped" {
  run --separate-stderr "$SCRIPTS/gh-milestone.sh" issues 3
  assert_success
  assert_equal "$(deps 20)" '[2]'
}

@test "CRLF bodies parse and a null body gives an empty list" {
  run --separate-stderr "$SCRIPTS/gh-milestone.sh" issues 3
  assert_success
  assert_equal "$(deps 108)" '[4]'
  assert_equal "$(deps 109)" '[]'
}

@test "repo-qualified references and issue URLs are not counted" {
  run --separate-stderr "$SCRIPTS/gh-milestone.sh" issues 3
  assert_success
  assert_equal "$(deps 110)" '[]'
}

@test "native blockedBy entries from another repository are dropped" {
  jq -n '[{number: 1, title: "x", labels: [], state: "OPEN", body: "", blockedBy: {nodes: [{number: 7, repository: {nameWithOwner: "acme/widgets"}}, {number: 8, repository: {nameWithOwner: "acme/other"}}]}}]' \
    | gh_mock_respond issue-list -
  GH_REPO=acme/widgets run --separate-stderr "$SCRIPTS/gh-milestone.sh" issues 3
  assert_success
  assert_equal "$(deps 1)" '[7]'
}

@test "the listed repository comes from each issue's url, without GH_REPO" {
  jq -n '[{number: 1, title: "x", labels: [], state: "OPEN", body: "", url: "https://github.com/acme/widgets/issues/1",
           blockedBy: {nodes: [{number: 7, repository: {nameWithOwner: "acme/widgets"}}, {number: 8, repository: {nameWithOwner: "acme/other"}}]}}]' \
    | gh_mock_respond issue-list -
  run --separate-stderr "$SCRIPTS/gh-milestone.sh" issues 3
  assert_success
  assert_equal "$(deps 1)" '[7]'
}

@test "a host-qualified GH_REPO still filters cross-repository blockers" {
  jq -n '[{number: 1, title: "x", labels: [], state: "OPEN", body: "",
           blockedBy: {nodes: [{number: 7, repository: {nameWithOwner: "acme/widgets"}}, {number: 8, repository: {nameWithOwner: "acme/other"}}]}}]' \
    | gh_mock_respond issue-list -
  GH_REPO=github.com/acme/widgets run --separate-stderr "$SCRIPTS/gh-milestone.sh" issues 3
  assert_success
  assert_equal "$(deps 1)" '[7]'
}

@test "the whole output matches the expected fixture" {
  run --separate-stderr "$SCRIPTS/gh-milestone.sh" issues 3
  assert_success
  assert_equal "$(printf '%s' "$output" | jq -S .)" "$(jq -S . "$FIXTURES/milestone/expected.json")"
  printf '%s' "$output" | jq -e 'all(.[]; (keys | sort) == ["depends_on","labels","number","state","title"])' > /dev/null
  printf '%s' "$output" | jq -e '[.[].number] == ([.[].number] | sort)' > /dev/null
}

@test "gh is called once with the documented arguments" {
  run --separate-stderr "$SCRIPTS/gh-milestone.sh" issues 3
  assert_success
  assert_equal "$(gh_call_count)" 1
  assert_gh_called 'issue list --milestone 3 --state all --limit 500 --json number,title,labels,state,body,blockedBy,url'
}

@test "a milestone title is passed verbatim" {
  run --separate-stderr "$SCRIPTS/gh-milestone.sh" issues "Sprint 4"
  assert_success
  assert_gh_called 'issue list --milestone Sprint 4 --state all'
}

@test "an empty milestone prints an empty list" {
  printf '[]' | gh_mock_respond issue-list -
  run --separate-stderr "$SCRIPTS/gh-milestone.sh" issues 3
  assert_success
  assert_equal "$output" '[]'
}

@test "a gh failure passes its message through with nothing on stdout" {
  printf 'could not find milestone' | gh_mock_respond issue-list - 1
  run --separate-stderr "$SCRIPTS/gh-milestone.sh" issues 3
  assert_failure
  assert_equal "$output" ''
  assert_contains "$stderr" 'could not find milestone'
}

@test "exactly 500 issues warns about truncation but still succeeds" {
  jq -n '[range(1; 501) | {number: ., title: "t", labels: [], state: "OPEN", body: "", blockedBy: []}]' | gh_mock_respond issue-list -
  run --separate-stderr "$SCRIPTS/gh-milestone.sh" issues 3
  assert_success
  assert_contains "$stderr" 'warning:'
  assert_equal "$(printf '%s' "$output" | jq 'length')" 500
}

@test "bad input is refused before any gh call" {
  run --separate-stderr "$SCRIPTS/gh-milestone.sh" issues
  assert_failure 1
  run --separate-stderr "$SCRIPTS/gh-milestone.sh" issues ""
  assert_failure 1
  run --separate-stderr "$SCRIPTS/gh-milestone.sh" issues 3 extra
  assert_failure 1
  run --separate-stderr "$SCRIPTS/gh-milestone.sh" bogus 3
  assert_failure 1
  run --separate-stderr "$SCRIPTS/gh-milestone.sh" --bogus
  assert_failure 1
  assert_equal "$output" ''
  assert_contains "$stderr" 'error:'
  assert_equal "$(gh_call_count)" 0
}
