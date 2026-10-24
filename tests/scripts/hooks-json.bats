#!/usr/bin/env bats
# Tests for hooks/hooks.json (the wiring) and the cross-hook fail-open matrix.

load helpers/common

HOOKS_JSON="$BATS_TEST_DIRNAME/../../hooks/hooks.json"

setup() {
  common_setup
  HOOKS_FIX="$FIXTURES/hooks"
  PREFIX='"${CLAUDE_PLUGIN_ROOT}/scripts/hooks/'
}

# matcher_of <event> <script>: the matcher of the entry running <script> ("-" when none).
matcher_of() {
  jq -r --arg e "$1" --arg s "$2" \
    '.hooks[$e][] | select(.hooks[0].command | endswith("/" + $s + "\"")) | .matcher // "-"' "$HOOKS_JSON"
}

# payload_for <hook> [dangerous] [cwd]: the event fixture, cwd overridden,
# optionally with the input that the hook exists to stop.
payload_for() {
  local hook=$1 danger=${2:-} cwd=${3:-/tmp}
  case "$hook" in
    guard-bash.sh)
      jq -c --arg cwd "$cwd" --arg d "$danger" \
        '.cwd = $cwd | if $d != "" then .tool_input.command = "git push -f origin main" else . end' "$HOOKS_FIX/pretooluse-bash.json" ;;
    guard-edit.sh)
      jq -c --arg cwd "$cwd" --arg d "$danger" \
        '.cwd = $cwd | if $d != "" then .tool_input.file_path = ($cwd + "/.env") else . end' "$HOOKS_FIX/pretooluse-edit.json" ;;
    gate-subagent.sh)
      jq -c --arg cwd "$cwd" '.cwd = $cwd' "$HOOKS_FIX/subagentstop.json" ;;
    session-start.sh)
      jq -c --arg cwd "$cwd" '.cwd = $cwd' "$HOOKS_FIX/sessionstart.json" ;;
    *) echo "payload_for: no fixture for $hook" >&2; return 1 ;;
  esac
}

all_hooks() {
  local f n=0
  for f in "$SCRIPTS"/hooks/*.sh; do
    [ -e "$f" ] || continue
    printf '%s\n' "${f##*/}"
    n=$((n + 1))
  done
  [ "$n" -gt 0 ]
}

@test "hooks.json is valid with exactly the three events and well-formed hooks" {
  jq -e . "$HOOKS_JSON" > /dev/null
  assert_equal "$(jq -r '.hooks | keys | join(",")' "$HOOKS_JSON")" "PreToolUse,SessionStart,SubagentStop"
  assert_json "$HOOKS_JSON" '[.hooks[][].hooks[]] | length > 0 and all(.type == "command" and (.timeout | type == "number" and . == floor and . >= 1 and . <= 10))'
  assert_json "$HOOKS_JSON" '[.hooks[][].hooks[].command] | all(startswith("\"${CLAUDE_PLUGIN_ROOT}/scripts/hooks/"))'
}

@test "every command resolves to an executable and every hook script is wired exactly once" {
  local cmd path
  while IFS= read -r cmd; do
    path=${cmd//\$\{CLAUDE_PLUGIN_ROOT\}/$REPO_ROOT}
    path=${path//\"/}
    [ -x "$path" ] || { echo "not executable: $path" >&2; return 1; }
  done < <(jq -r '.hooks[][].hooks[].command' "$HOOKS_JSON")
  local h
  while IFS= read -r h; do
    assert_equal "$(jq -r '.hooks[][].hooks[].command' "$HOOKS_JSON" | grep -cF -- "/scripts/hooks/$h\"")" "1"
  done < <(all_hooks)
  assert_equal "$(jq -r '[.hooks[][].hooks[]] | length' "$HOOKS_JSON")" "$(all_hooks | grep -c '')"
}

@test "Bash and Edit|Write are exact-match matchers; SessionStart has none" {
  assert_equal "$(matcher_of PreToolUse guard-bash.sh)" "Bash"
  assert_equal "$(matcher_of PreToolUse guard-edit.sh)" "Edit|Write"
  local m
  for m in Bash "Edit|Write"; do
    printf '%s\n' "$m" | grep -Eq '^[A-Za-z0-9_|, -]+$'
  done
  assert_equal "$(matcher_of SessionStart session-start.sh)" "-"
}

@test "the SubagentStop matcher is anchored and rejects look-alikes" {
  local m cand
  m=$(matcher_of SubagentStop gate-subagent.sh)
  assert_equal "$m" '^aew:(developer|qa-engineer)$'
  for cand in aew:developer aew:qa-engineer; do
    printf '%s\n' "$cand" | grep -Eq -- "$m"
  done
  for cand in developer qa-engineer aew:developer-x aew:qa-engineer-x xaew:developer xaew:qa-engineer other:qa-engineer aew:architect; do
    if printf '%s\n' "$cand" | grep -Eq -- "$m"; then
      echo "matched look-alike: $cand" >&2
      return 1
    fi
  done
}

@test "fail-open: jq missing" {
  setup_project
  mkdir -p "$BATS_TEST_TMPDIR/nojq"
  ln -s "$(command -v bash)" "$BATS_TEST_TMPDIR/nojq/bash"
  ln -s "$(command -v dirname)" "$BATS_TEST_TMPDIR/nojq/dirname"
  local h
  while IFS= read -r h; do
    run --separate-stderr /usr/bin/env PATH="$BATS_TEST_TMPDIR/nojq" "$SCRIPTS/hooks/$h" <<<"$(payload_for "$h" danger "$PROJECT")"
    [ "$status" -eq 0 ] || { echo "$h: status $status" >&2; return 1; }
    [ -z "$output" ] || { echo "$h: stdout [$output]" >&2; return 1; }
  done < <(all_hooks)
}

@test "fail-open: not a git repo is silent" {
  mkdir -p "$BATS_TEST_TMPDIR/plain"
  local h
  while IFS= read -r h; do
    cd "$BATS_TEST_TMPDIR/plain"
    run_hook "$h" "$(payload_for "$h" danger "$BATS_TEST_TMPDIR/plain")"
    [ "$status" -eq 0 ] || { echo "$h: status $status" >&2; return 1; }
    [ -z "$output" ] && [ -z "$stderr" ] || { echo "$h: not silent [$output] [$stderr]" >&2; return 1; }
  done < <(all_hooks)
}

@test "fail-open: a git repo without .aew is inert even for dangerous input" {
  setup_project --no-config
  rm -rf "$PROJECT/.aew"
  local h
  while IFS= read -r h; do
    run_hook "$h" "$(payload_for "$h" danger "$PROJECT")"
    [ "$status" -eq 0 ] || { echo "$h: status $status" >&2; return 1; }
    [ -z "$output" ] && [ -z "$stderr" ] || { echo "$h: not silent [$output] [$stderr]" >&2; return 1; }
  done < <(all_hooks)
}

@test "fail-open: .aew without config warns and allows" {
  setup_project --no-config
  mkdir -p "$PROJECT/.aew"
  local h
  while IFS= read -r h; do
    run_hook "$h" "$(payload_for "$h" danger "$PROJECT")"
    [ "$status" -eq 0 ] || { echo "$h: status $status" >&2; return 1; }
    [ -z "$output" ] || { echo "$h: stdout [$output]" >&2; return 1; }
    [ -n "$stderr" ] || { echo "$h: no warning" >&2; return 1; }
  done < <(all_hooks)
}

@test "fail-open: empty or invalid payload warns and allows" {
  setup_project
  local h p
  while IFS= read -r h; do
    for p in '' 'not json' '[]' 'null' '   ' '{"cwd":"/x"} {"cwd":"/y"}'; do
      run_hook "$h" "$p"
      [ "$status" -eq 0 ] || { echo "$h [$p]: status $status" >&2; return 1; }
      [ -z "$output" ] || { echo "$h [$p]: stdout [$output]" >&2; return 1; }
      [ -n "$stderr" ] || { echo "$h [$p]: no warning" >&2; return 1; }
    done
  done < <(all_hooks)
}

@test "fail-open: missing run state allows" {
  setup_project
  local h
  while IFS= read -r h; do
    run_hook "$h" "$(payload_for "$h" "" "$PROJECT")"
    [ "$status" -eq 0 ] || { echo "$h: status $status" >&2; return 1; }
    [ -z "$output" ] || { echo "$h: stdout [$output]" >&2; return 1; }
  done < <(all_hooks)
}

@test "fail-open: stop_hook_active true allows" {
  setup_project
  seed_run 12
  local h
  while IFS= read -r h; do
    run_hook "$h" "$(payload_for "$h" danger "$PROJECT" | jq -c '.stop_hook_active = true')"
    [ "$status" -eq 0 ] || { echo "$h: status $status" >&2; return 1; }
    [ -z "$output" ] || { echo "$h: stdout [$output]" >&2; return 1; }
  done < <(all_hooks)
}

@test "fail-open: an unbound variable, a failing command or an explicit error after init exits 0, never 2" {
  setup_project
  local body
  for body in 'echo "$undefined_var"' 'false' 'exit 2' 'exit 3' 'return 2 2>/dev/null; exit 2'; do
    printf '#!/usr/bin/env bash\nset -euo pipefail\n. "%s/scripts/lib/hooks.sh"\nhook_init "$@"\n%s\n' "$REPO_ROOT" "$body" > "$BATS_TEST_TMPDIR/stub.sh"
    chmod +x "$BATS_TEST_TMPDIR/stub.sh"
    run --separate-stderr "$BATS_TEST_TMPDIR/stub.sh" <<<"$(payload_for guard-bash.sh "" "$PROJECT")"
    [ "$status" -eq 0 ] || { echo "[$body]: status $status" >&2; return 1; }
    [ -z "$output" ] || { echo "[$body]: stdout [$output]" >&2; return 1; }
  done
}

@test "wired guards still deny the dangerous input inside an aew project (not vacuous)" {
  setup_project
  local h
  for h in guard-bash.sh guard-edit.sh; do
    run_hook "$h" "$(payload_for "$h" danger "$PROJECT")"
    [ "$status" -eq 0 ]
    assert_equal "$(jq -r '.hookSpecificOutput.permissionDecision' <<<"$output")" "deny"
  done
}

@test "guard-edit denies path tricks to .env" {
  setup_project
  local p
  for p in "$PROJECT/./.env" "$PROJECT//.env" "$PROJECT/x/../.env" "./.env"; do
    run_hook guard-edit.sh "$(payload_for guard-edit.sh "" "$PROJECT" | jq -c --arg p "$p" '.tool_input.file_path = $p')"
    [ "$status" -eq 0 ]
    [ "$(jq -r '.hookSpecificOutput.permissionDecision // empty' <<<"$output")" = deny ] || { echo "not denied: $p [$output]" >&2; return 1; }
  done
}

@test "hooks stay within the time budget" {
  setup_project
  local h ms
  while IFS= read -r h; do
    payload_for "$h" "" "$PROJECT" > "$BATS_TEST_TMPDIR/payload.json"
    ms=$(elapsed_ms bash -c '"$0" < "$1"' "$SCRIPTS/hooks/$h" "$BATS_TEST_TMPDIR/payload.json")
    [ "$ms" -lt 1000 ] || { echo "$h took ${ms}ms" >&2; return 1; }
    run_hook "$h" "@$BATS_TEST_TMPDIR/payload.json"
    [ "$status" -eq 0 ] || { echo "$h: status $status" >&2; return 1; }
  done < <(all_hooks)
}

@test "claude plugin validate passes with no hooks warnings" {
  command -v claude > /dev/null 2>&1 || skip "claude is not on PATH"
  run --separate-stderr claude plugin validate "$REPO_ROOT"
  assert_success
  if printf '%s\n%s\n' "$output" "$stderr" | grep -q 'hooks:'; then
    printf '%s\n%s\n' "$output" "$stderr" >&2
    return 1
  fi
}
