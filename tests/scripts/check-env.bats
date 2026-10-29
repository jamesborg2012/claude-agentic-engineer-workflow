#!/usr/bin/env bats
# Tests for scripts/check-env.sh. Tools are stubs on a restricted PATH, so no
# test depends on what the machine has installed.

load helpers/common

setup() {
  common_setup
  CHECK="$SCRIPTS/check-env.sh"
  setup_project
  BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$BIN"
  local t
  for t in jq git; do ln -s "$(command -v "$t")" "$BIN/$t"; done
  PLAN="$BATS_TEST_TMPDIR/05-plan.md"
}

# stub <name> <version-line> [<exit status of any other call>]
stub() {
  printf '#!/bin/sh\nif [ "$1" = --version ]; then echo "%s"; exit 0; fi\nexit %s\n' "$2" "${3:-0}" > "$BIN/$1"
  chmod +x "$BIN/$1"
}

# plan <environment lines> [<risk lines>]: writes a plan with those sections.
plan() {
  printf '# Plan: #1 Test\n\n## Environment\n\n<!-- one per line -->\n%s\n\n## Risks\n\n%s\n\n## AC→WP traceability\n' "$1" "${2:-None identified.}" > "$PLAN"
}

check() {
  PATH="$BIN:/usr/bin:/bin" run --separate-stderr "$CHECK" "$PLAN"
}

@test "every requirement met: exit 0 and no output" {
  stub node v24.11.1
  stub pnpm 10.2.0
  stub docker "Docker version 27.3.1, build ce12230"
  plan $'- tool: node 24\n- tool: pnpm\n- service: docker'
  check
  assert_success
  assert_equal "$output" ""
}

@test "a tool missing from PATH fails" {
  plan '- tool: pnpm'
  check
  assert_failure 1
  assert_equal "$output" "FAIL: tool pnpm is not on PATH"
}

@test "a wrong major version fails and names both versions" {
  stub node v26.0.0
  plan '- tool: node 24'
  check
  assert_failure 1
  assert_equal "$output" "FAIL: tool node is version 26, the plan needs 24"
}

@test "docker: a daemon that does not answer fails, an answering one passes" {
  stub docker "Docker version 27.3.1" 1
  plan '- service: docker'
  check
  assert_failure 1
  assert_contains "$output" "FAIL: service docker is not answering"
  stub docker "Docker version 27.3.1" 0
  check
  assert_success
}

@test "docker: not installed fails" {
  plan '- service: docker'
  check
  assert_failure 1
  assert_equal "$output" "FAIL: service docker: docker is not on PATH"
}

@test "an owner hand-off fails until the file exists or is allow-listed" {
  jq '.guard.allow_paths = []' "$REPO_ROOT/templates/config.example.json" > "$PROJECT/.aew/config.json"
  plan 'None.' $'- Owner hand-off: `.env.test`: add it to guard.allow_paths in .aew/config.json if it is committed and holds no secrets, or create it by hand before develop.\n- Owner hand-off: .npmrc: create it by hand.'
  check
  assert_failure 1
  assert_contains "$output" "FAIL: owner hand-off .env.test does not exist and aew may not write it"
  assert_contains "$output" "FAIL: owner hand-off .npmrc does not exist and aew may not write it"
  touch "$PROJECT/.npmrc"
  jq '.guard.allow_paths = [".env.test"]' "$REPO_ROOT/templates/config.example.json" > "$PROJECT/.aew/config.json"
  check
  assert_success
}

@test "a line the grammar does not know fails, and a bad tool name is never run" {
  printf '#!/bin/sh\ntouch "%s/ran"\n' "$BATS_TEST_TMPDIR" > "$BIN/evil"
  chmod +x "$BIN/evil"
  plan $'- tool: ../bin/evil\n- tool: evil; true\n- needs a database\n- service: postgres'
  check
  assert_failure 1
  assert_contains "$output" "FAIL: unreadable environment line: - tool: ../bin/evil"
  assert_contains "$output" "FAIL: unreadable environment line: - needs a database"
  assert_contains "$output" "FAIL: unreadable environment line: - service: postgres"
  [ ! -e "$BATS_TEST_TMPDIR/ran" ]
}

@test "None., comments, blank lines and a plan with no Environment section pass" {
  plan 'None.'
  check
  assert_success
  printf '# Plan: #1 Test\n\n## Risks\n\nNone identified.\n' > "$PLAN"
  check
  assert_success
}

@test "an unreadable plan exits 2; no argument exits 1" {
  PLAN="$BATS_TEST_TMPDIR/missing.md"
  check
  assert_failure 2
  run --separate-stderr "$CHECK"
  assert_failure 1
}
