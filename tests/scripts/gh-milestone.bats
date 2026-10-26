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
  assert_gh_called 'issue list --milestone 3 --state all --limit 500 --json number,title,labels,state,body,blockedBy,url,milestone'
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

# --- select ---------------------------------------------------------------

# mk '<jq array expr>': serve a listing built with i(n; state; body; deps) or
# j(n; state; deps) (a default acceptance-criteria body), milestone 1.
mk() {
  jq -n 'def i($n; $s; $b; $d): {number: $n, title: "T\($n)", labels: [], state: $s, body: $b, blockedBy: ($d | map({number: .})), url: "https://github.com/o/r/issues/\($n)", milestone: {number: 1, title: "M"}};
         def j($n; $s; $d): i($n; $s; "## Acceptance criteria\n- a\n"; $d);
         '"$1" | gh_mock_respond issue-list -
}

sel() { run --separate-stderr "$SCRIPTS/gh-milestone.sh" select "${1:-1}"; }

# stack_of <n>: the stack_on of one issue from the last run.
stack_of() { printf '%s' "$output" | jq -c --argjson n "$1" '.issues[] | select(.number == $n) | .stack_on'; }

@test "select: three small related issues recommend bulk" {
  gh_mock_respond issue-list "$FIXTURES/milestone/small-related.json"
  sel 2
  assert_success
  assert_equal "$(printf '%s' "$output" | jq -S .)" "$(jq -S . "$FIXTURES/milestone/small-related.expected.json")"
  printf '%s' "$output" | jq -e '(keys | sort) == ["closed","cycle","issues","milestone","order","reasons","recommend","stack_conflicts"]' > /dev/null
  printf '%s' "$output" | jq -e 'all(.issues[]; (keys | sort) == ["ac_count","depends_on","labels","number","stack_on","title"])' > /dev/null
}

@test "select: five issues with one large recommend sequential with that reason" {
  gh_mock_respond issue-list "$FIXTURES/milestone/five-one-large.json"
  sel 3
  assert_success
  assert_equal "$(printf '%s' "$output" | jq -c '[.recommend, .reasons]')" '["sequential",["#33 has 8 acceptance criteria"]]'
}

@test "select: a chain listed out of order" {
  gh_mock_respond issue-list "$FIXTURES/milestone/chain.json"
  sel 4
  assert_success
  assert_equal "$(printf '%s' "$output" | jq -c '.order')" '[42,43,41]'
  assert_equal "$(stack_of 42)" 'null'
  assert_equal "$(stack_of 43)" '42'
  assert_equal "$(stack_of 41)" '43'
  assert_equal "$(printf '%s' "$output" | jq -c '[.recommend, .reasons, .stack_conflicts, .milestone, .cycle]')" \
    '["sequential",["#41 depends on #43","#43 depends on #42"],[],{"number":4,"title":"Checkout flow"},null]'
  assert_equal "$(printf '%s' "$output" | jq -c '[.issues[].number]')" '[41,42,43]'
}

@test "select: a cycle" {
  mk '[j(1; "OPEN"; []), j(2; "OPEN"; [3]), j(3; "OPEN"; [2]), j(4; "OPEN"; [3])]'
  sel
  assert_success
  assert_equal "$(printf '%s' "$output" | jq -c '[.order, .cycle, .stack_conflicts, ([.issues[].stack_on] | unique), .recommend]')" \
    '[null,[2,3,4],[],[null],"sequential"]'
}

@test "select: stacking follows one chain or reports a conflict" {
  mk '[j(1; "OPEN"; []), j(2; "OPEN"; []), j(3; "OPEN"; [1,2]), j(5; "OPEN"; [1]), j(6; "OPEN"; [1,5])]'
  sel
  assert_success
  assert_equal "$(printf '%s' "$output" | jq -c '.stack_conflicts')" '[{"issue":3,"deps":[1,2]}]'
  assert_equal "$(stack_of 3)" 'null'
  assert_equal "$(stack_of 5)" '1'
  assert_equal "$(stack_of 6)" '5'
}

@test "select: closed and outside-milestone dependencies" {
  mk '[j(1; "CLOSED"; []), j(2; "OPEN"; [1]), j(3; "OPEN"; [99])]'
  sel
  assert_success
  assert_equal "$(printf '%s' "$output" | jq -c '[.closed, .order, .reasons, .recommend, .stack_conflicts]')" \
    '[[1],[2,3],["#3 depends on #99"],"sequential",[]]'
  assert_equal "$(stack_of 2)" 'null'
  assert_equal "$(stack_of 3)" 'null'
  mk '[j(1; "CLOSED"; []), j(2; "OPEN"; [1])]'
  sel
  assert_equal "$(printf '%s' "$output" | jq -c '[.recommend, .reasons]')" '["bulk",[]]'
}

@test "select: acceptance-criteria counting" {
  jq -n '[["## Acceptance criteria\n- a\n- b", 2],
          ["### Acceptance Criteria\n* a", 1],
          ["**Acceptance criteria:**\n+ a\n1. b\n2) c", 3],
          ["**Acceptance criteria**:\n- a", 1],
          ["## Acceptance criteria\n- [ ] a\n- [x] b", 2],
          ["## Acceptance criteria\n   - a\n    - b", 1],
          ["## Acceptance criteria\n\t- a\n- b", 1],
          ["## Acceptance criteria\n- a\n## Notes\n- b", 1],
          ["## Acceptance criteria\n- a\n**Notes**\n- b", 1],
          ["## Acceptance criteria\n- a\n## Acceptance criteria\n- b\n- c", 1],
          ["## Acceptance criteria\r\n- a\r\n- b\r\n", 2],
          ["## Acceptance criteria\nprose\n- a\nmore prose", 1],
          ["## Acceptance criteria\n\n## Next", 0],
          ["just text", null],
          [null, null]]' > "$BATS_TEST_TMPDIR/cases.json"
  jq '[to_entries[] | {number: (.key + 1), title: "t", labels: [], state: "OPEN", body: .value[0], blockedBy: [], milestone: {number: 1, title: "M"}}]' \
    "$BATS_TEST_TMPDIR/cases.json" | gh_mock_respond issue-list -
  sel
  assert_success
  assert_equal "$(printf '%s' "$output" | jq -c '[.issues[].ac_count]')" "$(jq -c '[.[][1]]' "$BATS_TEST_TMPDIR/cases.json")"
  assert_equal "$(printf '%s' "$output" | jq -c '.reasons | map(select(test("^#(14|15):")))')" \
    '["#14: no acceptance-criteria list found","#15: no acceptance-criteria list found"]'
}

@test "select: more than five open issues" {
  mk '[range(1; 7) as $n | j($n; "OPEN"; [])]'
  sel
  assert_success
  assert_equal "$(printf '%s' "$output" | jq -c '[.recommend, .reasons]')" '["sequential",["6 open issues (more than 5)"]]'
}

@test "select: an all-closed and an empty milestone" {
  mk '[j(2; "CLOSED"; []), j(1; "CLOSED"; [])]'
  sel
  assert_success
  assert_equal "$(printf '%s' "$output" | jq -c '[.milestone, .issues, .order, .closed, .reasons, .recommend]')" \
    '[{"number":1,"title":"M"},[],[],[1,2],["no open issues"],"sequential"]'
  printf '[]' | gh_mock_respond issue-list -
  sel
  assert_success
  assert_equal "$(printf '%s' "$output" | jq -c '[.milestone, .issues, .order, .closed, .reasons]')" \
    '[null,[],[],[],["no open issues"]]'
}

@test "select: gh is called once with the documented arguments, and a title passes verbatim" {
  sel 3
  assert_success
  assert_equal "$(gh_call_count)" 1
  assert_gh_called 'issue list --milestone 3 --state all --limit 500 --json number,title,labels,state,body,blockedBy,url,milestone'
  run --separate-stderr "$SCRIPTS/gh-milestone.sh" select "Sprint 4"
  assert_success
  assert_gh_called 'issue list --milestone Sprint 4 --state all'
}

@test "select: a gh failure prints nothing on stdout" {
  printf 'could not find milestone' | gh_mock_respond issue-list - 1
  sel 3
  assert_failure
  assert_equal "$output" ''
  assert_contains "$stderr" 'could not find milestone'
}

@test "select: bad input is refused before any gh call" {
  run --separate-stderr "$SCRIPTS/gh-milestone.sh" select
  assert_failure 1
  run --separate-stderr "$SCRIPTS/gh-milestone.sh" select ""
  assert_failure 1
  run --separate-stderr "$SCRIPTS/gh-milestone.sh" select -x
  assert_failure 1
  run --separate-stderr "$SCRIPTS/gh-milestone.sh" select 3 extra
  assert_failure 1
  assert_equal "$output" ''
  assert_contains "$stderr" 'error:'
  assert_equal "$(gh_call_count)" 0
}
