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
  [[ "$reason" == *"ask James"* ]]
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
