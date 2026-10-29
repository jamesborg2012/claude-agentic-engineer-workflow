#!/usr/bin/env bats
# Tests for scripts/hooks/guard-edit.sh (PreToolUse Edit/Write guard).

load helpers/common

setup() {
  common_setup
  HOOKS_FIX="$FIXTURES/hooks"
  setup_project
}

# edit_payload <tool> <absolute-path>
edit_payload() {
  jq -c --arg t "$1" --arg p "$2" --arg cwd "$PROJECT" \
    '.tool_name = $t | .tool_input.file_path = $p | .cwd = $cwd' "$HOOKS_FIX/pretooluse-edit.json"
}

@test "table: every row is blocked or allowed as expected, for Edit and Write" {
  local tool expect rel payload bad="" n=0 blocked=0 allowed=0
  for tool in Edit Write; do
    while IFS=$'\t' read -r expect rel; do
      [ -n "$expect" ] || continue
      n=$((n + 1))
      payload=$(edit_payload "$tool" "$PROJECT/$rel")
      run_hook guard-edit.sh "$payload"
      if [ "$status" -ne 0 ]; then
        bad="$bad  $tool $rel: exit $status"$'\n'
        continue
      fi
      if [ "$expect" = block ]; then
        if [ "$(jq -r '.hookSpecificOutput.permissionDecision // empty' <<<"$output")" != deny ]; then
          bad="$bad  $tool $rel: expected deny, got [$output]"$'\n'
        fi
        [ "$tool" = Edit ] && blocked=$((blocked + 1))
      else
        if [ -n "$output" ]; then bad="$bad  $tool $rel: expected allow, got [$output]"$'\n'; fi
        [ "$tool" = Edit ] && allowed=$((allowed + 1))
      fi
    done < "$HOOKS_FIX/edit-cases.tsv"
  done
  if [ -n "$bad" ]; then printf 'mismatches:\n%s' "$bad" >&2; return 1; fi
  [ "$n" -eq 50 ]
  [ "$blocked" -eq 15 ]
  [ "$allowed" -eq 10 ]
  # AC-18's named paths are present in the table.
  local p
  for p in $'block\t.env' $'block\t.env.local' $'block\t.git/config' $'allow\t.env.example'; do
    grep -qxF "$p" "$HOOKS_FIX/edit-cases.tsv"
  done
}

@test "deny JSON has the PreToolUse shape and the reason names the path" {
  run_hook guard-edit.sh "$(edit_payload Edit "$PROJECT/.env")"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.hookSpecificOutput.hookEventName' <<<"$output")" = PreToolUse ]
  [ "$(jq -r '.hookSpecificOutput.permissionDecision' <<<"$output")" = deny ]
  local reason
  reason=$(jq -r '.hookSpecificOutput.permissionDecisionReason' <<<"$output")
  [[ "$reason" == "aew guard: blocked a write to "* ]]
  [[ "$reason" == *"$PROJECT/.env"* ]]
  [[ "$reason" == *"guard.allow_paths"* ]]
  [[ "$reason" != *James* ]]
}

# allow <paths-json>: sets guard.allow_paths in the project's config.
allow() {
  jq --argjson a "$1" '.guard.allow_paths = $a' "$REPO_ROOT/templates/config.example.json" > "$PROJECT/.aew/config.json"
}

# decision <tool> <absolute-path>: prints deny, or allow when the hook is silent.
decision() {
  run_hook guard-edit.sh "$(edit_payload "$1" "$2")"
  [ "$status" -eq 0 ] || return 1
  if [ -z "$output" ]; then echo allow; else jq -r '.hookSpecificOutput.permissionDecision' <<<"$output"; fi
}

@test "guard.allow_paths: a listed path is allowed for Edit and Write, including in a new directory" {
  allow '[".env.test", ".npmrc", "config/certs/test.pem"]'
  local tool p
  for tool in Edit Write; do
    for p in .env.test .npmrc config/certs/test.pem; do
      [ "$(decision "$tool" "$PROJECT/$p")" = allow ] || { echo "$tool $p not allowed" >&2; return 1; }
    done
  done
}

@test "guard.allow_paths: matching is exact, project-relative and case-sensitive" {
  allow '[".env.test", "apps/web/.npmrc"]'
  [ "$(decision Write "$PROJECT/sub/.env.test")" = deny ]
  [ "$(decision Write "$PROJECT/.npmrc")" = deny ]
  [ "$(decision Write "$PROJECT/.ENV.TEST")" = deny ]
  [ "$(decision Write "$PROJECT/.env.local")" = deny ]
  [ "$(decision Write "$PROJECT/apps/web/.npmrc")" = allow ]
}

@test "guard.allow_paths: a listed path is allowed inside a linked worktree of the run" {
  allow '[".env.test"]'
  local wt="$PROJECT/.aew/runs/1/worktrees/WP-3"
  git worktree add -q -b aew/1/wp-3 "$wt" HEAD
  [ "$(decision Write "$wt/.env.test")" = allow ]
  [ "$(decision Write "$wt/.env")" = deny ]
}

@test "guard.allow_paths: a logical path through a symlinked parent still matches" {
  allow '[".env.test"]'
  ln -s "$PROJECT" "$BATS_TEST_TMPDIR/link"
  [ "$(decision Write "$BATS_TEST_TMPDIR/link/.env.test")" = allow ]
}

@test "guard.allow_paths: git internals are never allowed, and their reason has no allowlist hint" {
  allow '[".git/config", ".git/hooks/pre-commit"]'
  run_hook guard-edit.sh "$(edit_payload Edit "$PROJECT/.git/config")"
  [ "$(jq -r '.hookSpecificOutput.permissionDecision' <<<"$output")" = deny ]
  [[ "$(jq -r '.hookSpecificOutput.permissionDecisionReason' <<<"$output")" != *"allow_paths"* ]]
  [ "$(decision Write "$PROJECT/.git/hooks/pre-commit")" = deny ]
}

@test "guard.allow_paths: an unreadable config keeps the deny" {
  write_config '{ not json'
  [ "$(decision Write "$PROJECT/.env.test")" = deny ]
}

@test "a missing tool_input.file_path is allowed" {
  local payload
  payload=$(jq -c --arg cwd "$PROJECT" 'del(.tool_input.file_path) | .cwd = $cwd' "$HOOKS_FIX/pretooluse-edit.json")
  run_hook guard-edit.sh "$payload"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a relative path is resolved against the payload cwd" {
  run_hook guard-edit.sh "$(edit_payload Write ".git/config")"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.hookSpecificOutput.permissionDecision' <<<"$output")" = deny ]
}

@test "outside an aew project the guard is silent" {
  rm -rf .aew
  run_hook guard-edit.sh "$(edit_payload Edit "$PROJECT/.env")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a blocked path answers in under 1000 ms" {
  local f="$BATS_TEST_TMPDIR/payload.json" ms
  edit_payload Edit "$PROJECT/.git/config" > "$f"
  ms=$(elapsed_ms bash -c '"$0" < "$1"' "$SCRIPTS/hooks/guard-edit.sh" "$f")
  [ "$ms" -lt 1000 ]
  # elapsed_ms ignores the exit status, so prove the timed run really denies.
  run_hook guard-edit.sh "@$f"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.hookSpecificOutput.permissionDecision' <<<"$output")" = deny ]
}
