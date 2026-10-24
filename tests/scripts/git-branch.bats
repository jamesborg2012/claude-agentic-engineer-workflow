#!/usr/bin/env bats
# Tests for scripts/git-branch.sh: real throwaway repos, a local bare remote.

load helpers/common

setup() {
  common_setup
  setup_project
  GB="$SCRIPTS/git-branch.sh"
  REMOTE="$BATS_TEST_TMPDIR/remote.git"
}

# gb <args…>: run git-branch.sh with stdout and stderr kept apart.
gb() { run --separate-stderr "$GB" "$@"; }

use_config() {
  write_config "$1"
  git -C "$PROJECT" add -A
  git -C "$PROJECT" commit -qam cfg
}

add_remote() {
  git init -q --bare "$REMOTE"
  git remote add origin "$REMOTE"
}

head_branch() { git symbolic-ref --short HEAD; }

branch_count() { git for-each-ref refs/heads | grep -c '' || true; }

remote_ref_count() { git --git-dir="$REMOTE" for-each-ref | grep -c '' || true; }

@test "create: single-issue branch from the default pattern, based on main" {
  gb create 12 add-widget
  assert_success
  assert_equal "$output" "feat/12-add-widget"
  assert_equal "$(head_branch)" "feat/12-add-widget"
  assert_equal "$(git rev-parse HEAD)" "$(git rev-parse main)"
}

@test "create: milestone run id uses the milestone pattern" {
  gb create m-3 sprint-four
  assert_success
  assert_equal "$output" "feat/m3-sprint-four"
  assert_equal "$(head_branch)" "feat/m3-sprint-four"
}

@test "create: custom pattern from config" {
  use_config '{"project":"p","default_branch":"main","git":{"branch_pattern":"aew/{slug}-{issue}"}}'
  gb create 12 add-widget
  assert_success
  assert_equal "$output" "aew/add-widget-12"
}

@test "create: config without a git key falls back to the schema defaults" {
  use_config '{"project":"p","default_branch":"main"}'
  gb create 12 add-widget
  assert_success
  assert_equal "$output" "feat/12-add-widget"
}

@test "create: --base branches from another feature branch (stacked)" {
  git switch -q -c feat/3-base
  echo x > extra.txt
  git add extra.txt
  git commit -qm extra
  git switch -q main
  gb create 4 child --base feat/3-base
  assert_success
  assert_equal "$(git rev-parse HEAD)" "$(git rev-parse feat/3-base)"
}

@test "create: unresolvable --base is refused and no branch is created" {
  gb create 4 child --base nosuch
  assert_failure 1
  assert_equal "$output" ""
  assert_contains "$stderr" "error:"
  assert_equal "$(branch_count)" "1"
  assert_equal "$(head_branch)" "main"
}

@test "create: the default base follows default_branch" {
  use_config '{"project":"p","default_branch":"trunk"}'
  git switch -q -c trunk
  echo t > trunk.txt
  git add trunk.txt
  git commit -qm trunk
  git switch -q main
  gb create 5 from-trunk
  assert_success
  assert_equal "$(git rev-parse HEAD)" "$(git rev-parse trunk)"
}

@test "create: no upstream is set, even from a remote-tracking base" {
  add_remote
  git push -q origin main
  git fetch -q origin
  gb create 6 tracked --base origin/main
  assert_success
  run git rev-parse --abbrev-ref '@{u}'
  assert_failure
}

@test "create: modified tracked file is refused" {
  echo more >> .gitignore
  gb create 7 dirty
  assert_failure 1
  assert_equal "$output" ""
  assert_contains "$stderr" "error:"
  assert_equal "$(head_branch)" "main"
  assert_equal "$(branch_count)" "1"
}

@test "create: staged new file is refused" {
  echo s > staged.txt
  git add staged.txt
  gb create 7 dirty
  assert_failure 1
  assert_contains "$stderr" "error:"
  assert_equal "$(head_branch)" "main"
  assert_equal "$(branch_count)" "1"
}

@test "create: untracked file is refused" {
  echo u > untracked.txt
  gb create 7 dirty
  assert_failure 1
  assert_contains "$stderr" "error:"
  assert_equal "$(head_branch)" "main"
  assert_equal "$(branch_count)" "1"
}

@test "create: untracked file is refused even with status.showUntrackedFiles=no" {
  git config status.showUntrackedFiles no
  echo u > untracked.txt
  gb create 7 dirty
  assert_failure 1
  assert_contains "$stderr" "error:"
  assert_equal "$(head_branch)" "main"
  assert_equal "$(branch_count)" "1"
}

@test "create: a file under the gitignored .aew/runs/ does not block" {
  mkdir -p .aew/runs/1
  echo log > .aew/runs/1/log.md
  gb create 7 clean
  assert_success
  assert_equal "$output" "feat/7-clean"
}

@test "create: an existing branch is refused" {
  gb create 12 add-widget
  assert_success
  git switch -q main
  gb create 12 add-widget
  assert_failure 1
  assert_contains "$stderr" "error:"
  assert_equal "$(head_branch)" "main"
}

@test "create: bad slugs are refused, not transformed" {
  local s
  for s in Add-Widget add_widget -x x- a--b ""; do
    gb create 12 "$s"
    assert_failure 1
    assert_equal "$output" ""
    assert_contains "$stderr" "error:"
  done
  assert_equal "$(branch_count)" "1"
}

@test "create: bad run ids are refused" {
  local id
  for id in 0 abc; do
    gb create "$id" ok
    assert_failure 1
    assert_contains "$stderr" "error:"
  done
  assert_equal "$(branch_count)" "1"
}

@test "create: unknown placeholder in the pattern is named" {
  use_config '{"project":"p","default_branch":"main","git":{"branch_pattern":"feat/{ticket}-{slug}"}}'
  gb create 12 add-widget
  assert_failure 1
  assert_contains "$stderr" "error:"
  assert_contains "$stderr" "{ticket}"
  assert_equal "$(branch_count)" "1"
}

@test "create: {issue} in a milestone pattern is refused" {
  use_config '{"project":"p","default_branch":"main","git":{"milestone_branch_pattern":"feat/{issue}-{slug}"}}'
  gb create m-3 sprint
  assert_failure 1
  assert_contains "$stderr" "{issue}"
}

@test "create: a pattern giving an invalid ref is refused" {
  use_config '{"project":"p","default_branch":"main","git":{"branch_pattern":"feat/{slug}..x"}}'
  gb create 12 add-widget
  assert_failure 1
  assert_contains "$stderr" "error:"
  assert_equal "$(branch_count)" "1"
}

@test "create: unknown option and missing positionals are refused" {
  gb create 12 add-widget --bogus
  assert_failure 1
  assert_equal "$output" ""
  assert_contains "$stderr" "error:"
  gb create 12
  assert_failure 1
  gb create
  assert_failure 1
  gb create 12 add-widget --base
  assert_failure 1
  assert_equal "$(branch_count)" "1"
}

@test "push: pushes the current branch with upstream and prints its name" {
  add_remote
  gb create 12 add-widget
  assert_success
  gb push
  assert_success
  assert_equal "$output" "feat/12-add-widget"
  assert_equal "$(git --git-dir="$REMOTE" rev-parse refs/heads/feat/12-add-widget)" "$(git rev-parse HEAD)"
  assert_equal "$(git rev-parse --abbrev-ref '@{u}')" "origin/feat/12-add-widget"
}

@test "push: refuses the default branch and pushes nothing" {
  add_remote
  gb push
  assert_failure 1
  assert_equal "$output" ""
  assert_contains "$stderr" "main"
  assert_equal "$(remote_ref_count)" "0"
}

@test "push: refuses a configured default_branch other than main" {
  add_remote
  git switch -q -c trunk
  use_config '{"project":"p","default_branch":"trunk"}'
  gb push
  assert_failure 1
  assert_contains "$stderr" "trunk"
  assert_equal "$(remote_ref_count)" "0"
}

@test "push: refuses a detached HEAD" {
  add_remote
  git switch -q --detach
  gb push
  assert_failure 1
  assert_contains "$stderr" "detached"
}

@test "push: extra arguments are refused" {
  add_remote
  gb create 12 add-widget
  gb push extra
  assert_failure 1
  assert_equal "$output" ""
  assert_contains "$stderr" "error:"
}

@test "push: no origin remote fails with git's error and no stdout" {
  gb create 12 add-widget
  assert_success
  gb push
  assert_failure
  assert_equal "$output" ""
  [ -n "$stderr" ]
}
