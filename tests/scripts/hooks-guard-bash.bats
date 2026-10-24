#!/usr/bin/env bats
# Tests for scripts/hooks/guard-bash.sh (the PreToolUse Bash guard).
# The command column of the case table is data, so the single quotes are intentional.
# shellcheck disable=SC2016

load helpers/common

setup() {
  common_setup
  HOOKS_FIX="$FIXTURES/hooks"
  TABLE="$HOOKS_FIX/bash-cases.tsv"
}

# setup_guard_project: a project with the directories the table's rm rows use and a feat/x branch.
setup_guard_project() {
  setup_project
  mkdir -p sub tests/tmp node_modules dist
  git branch feat/x
}

# bash_payload <command> <cwd>
bash_payload() {
  jq -c --arg c "$1" --arg d "$2" '.tool_input.command = $c | .cwd = $d' "$HOOKS_FIX/pretooluse-bash.json"
}

# is_deny: success if $output is a well-formed PreToolUse deny.
is_deny() {
  printf '%s' "$output" | jq -e '.hookSpecificOutput.permissionDecision == "deny"
    and .hookSpecificOutput.hookEventName == "PreToolUse"
    and (.hookSpecificOutput.permissionDecisionReason | length > 0)' > /dev/null 2>&1
}

@test "the case table agrees with the guard, row by row" {
  setup_guard_project
  local expect branch cwd command want got bad="" n=0 cur=main dir
  while IFS=$'\t' read -r expect branch cwd command; do
    case "$expect" in '' | '#'*) continue ;; esac
    n=$((n + 1))
    want=$branch
    if [ "$branch" = "feat" ]; then want=feat/x; fi
    if [ "$cur" != "$want" ]; then
      git switch -q "$want"
      cur=$want
    fi
    command=${command//@PROJECT@/$PROJECT}
    command=$(printf '%b' "$command")
    dir=$PROJECT
    if [ "$cwd" != "." ]; then dir=$PROJECT/$cwd; fi
    run_hook guard-bash.sh "$(bash_payload "$command" "$dir")"
    got=allow
    if [ "$status" -ne 0 ]; then
      got="exit-$status"
    elif is_deny; then
      got=block
    elif [ -n "$output" ]; then
      got="odd-output"
    fi
    if [ "$got" != "$expect" ]; then
      bad="$bad  expect=$expect branch=$branch cwd=$cwd command=[$command] got=$got"$'\n'
    fi
  done < "$TABLE"
  if [ -n "$bad" ]; then
    printf 'mismatches (%s rows checked):\n%s' "$n" "$bad" >&2
    return 1
  fi
}

@test "the case table keeps every prompt-listed and CTO-mandated row" {
  local n pins=0 expect branch command
  n=$(grep -vc '^#' "$TABLE")
  [ "$n" -ge 87 ]
  while IFS=$'\t' read -r expect branch command; do
    if ! E="$expect" B="$branch" C="$command" awk -F'\t' '$1 == ENVIRON["E"] && $2 == ENVIRON["B"] && $4 == ENVIRON["C"] { f = 1 } END { exit !f }' "$TABLE"; then
      printf 'missing table row: %s %s %s\n' "$expect" "$branch" "$command" >&2
      return 1
    fi
    pins=$((pins + 1))
  done <<'PINS'
block	feat	git push origin main
block	main	git push
block	feat	git push -f
block	feat	git push --force-with-lease
block	feat	gh pr merge 3
block	feat	gh repo delete
block	main	git reset --hard
block	feat	rm -rf /
block	feat	rm -rf ~
block	feat	rm -rf ..
block	feat	git clean -fdx
allow	feat	git push origin feat/x
allow	feat	rm -rf node_modules
allow	feat	rm -rf tests/tmp
allow	feat	npm test
allow	feat	git reset --hard
allow	feat	gh issue view 3
block	feat	rm -rf .git
block	feat	rm -rf sub/.git
allow	feat	rm -f .git/index.lock
allow	feat	rm -rf .github/old
allow	feat	git checkout main && git checkout -b feat/y && git push -u origin HEAD
PINS
  [ "$pins" -eq 22 ]
}

@test "the deny reason names the rule" {
  setup_guard_project
  git switch -q feat/x
  run_hook guard-bash.sh "$(bash_payload 'git push -f' "$PROJECT")"
  assert_success
  assert_contains "$output" "force push"
  run_hook guard-bash.sh "$(bash_payload 'git push origin main' "$PROJECT")"
  assert_contains "$output" "default branch"
  run_hook guard-bash.sh "$(bash_payload 'rm -rf /' "$PROJECT")"
  assert_contains "$output" "rm"
  run_hook guard-bash.sh "$(bash_payload 'rm -rf .git' "$PROJECT")"
  assert_contains "$output" "rm of git internals"
}

@test "a custom default branch is honoured" {
  setup_guard_project
  write_config '{"default_branch":"trunk"}'
  git switch -q -c trunk
  run_hook guard-bash.sh "$(bash_payload 'git push origin trunk' "$PROJECT")"
  assert_success
  is_deny
  run_hook guard-bash.sh "$(bash_payload 'git push origin main' "$PROJECT")"
  assert_success
  assert_equal "$output" ""
}

@test "a linked worktree is its own repo root for rm and push" {
  setup_guard_project
  git worktree add -q ../wt feat/x
  local wt
  wt=$(cd "$PROJECT/../wt" && pwd -P)
  mkdir -p "$wt/node_modules"
  run_hook guard-bash.sh "$(bash_payload 'rm -rf node_modules' "$wt")"
  assert_success
  assert_equal "$output" ""
  run_hook guard-bash.sh "$(bash_payload 'rm -rf ../project' "$wt")"
  assert_success
  is_deny
  run_hook guard-bash.sh "$(bash_payload 'git push' "$wt")"
  assert_success
  assert_equal "$output" ""
}

@test "the worst-case command is answered in under a second" {
  setup_guard_project
  git switch -q feat/x
  local f="$BATS_TEST_TMPDIR/worst.json" ms
  [ -x "$SCRIPTS/hooks/guard-bash.sh" ]
  bash_payload 'cd sub && git push origin HEAD && git reset --hard && rm -rf ../tests/tmp' "$PROJECT" > "$f"
  ms=$(elapsed_ms bash -c '"$0" < "$1"' "$SCRIPTS/hooks/guard-bash.sh" "$f")
  printf 'elapsed: %s ms\n' "$ms" >&3
  [ "$ms" -lt 1000 ]
}
