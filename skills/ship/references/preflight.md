# Preflight

Run the checks in order; the first failure stops with its message. Preflight writes nothing: no state, label, branch, commit or `gh` write. (`git fetch` only updates remote-tracking refs.) Read every `${CLAUDE_PLUGIN_ROOT}` in this file as the plugin root stated in `SKILL.md` `## Plugin root`. `<n>` is the issue number and `<default>` is the default branch (`SKILL.md` `## Run variables`).

## Check 1. Config exists

Command: `test -f .aew/config.json && echo yes || echo no`.

Pass: it prints `yes`. On `no` stop with:

`No .aew/config.json in this project: run /aew:init first.`

## Check 2. Clean working tree

Both forms use `git status --porcelain --untracked-files=all`. The flag matters: without it a wholly untracked directory collapses to one line (`?? .claude/`) and a path filter never matches. It also agrees with the dirty set that `git-branch.sh create` counts.

**Fresh run.** The command must print nothing. Otherwise stop with:

`The working tree has uncommitted changes; commit or stash them, then retry:`

followed by the dirty paths, one per line.

- If every dirty path is under `.claude/agent-memory/` (memory left by an earlier run that never reached its docs commit), add this line after the paths:

  `These are aew agent memory files from an earlier run: commit them (git add -- .claude/agent-memory && git commit -m "chore(aew): update agent memory" -m "Co-Authored-By: Claude <noreply@anthropic.com>"), then retry.`

  Commit rather than stash: stashing would hide the memory from the agents.
- If a dirty path is under `.aew/runs/`, add: `.aew/runs/ should be gitignored: run /aew:init.`

**Restart form** (`--from`, and `resume`). Run the same command and ignore every line whose path starts with `.claude/agent-memory/` (memory written earlier in this run and committed at the docs stage). The remaining lines must be empty. Otherwise stop with the same message and paths, listing only the remaining ones.

## Check 3. gh is authenticated

Command: `gh auth status`. It is read-only and is the only direct `gh` call in aew (a recorded deviation; no script wraps it). It is also the canary for the offline simulation: a real `gh` must fail here, before any write.

Pass: exit 0. On a non-zero exit stop with:

`gh is not authenticated: run gh auth login, then retry.`

followed by gh's own output, quoted as it printed it (newer `gh` can exit non-zero when any configured host is unhealthy, and that output says which).

## Check 4. Default branch up to date

Preflight checks the branch and never fast-forwards it.

1. `<default>` comes from config: `jq -r '.default_branch // "main"' .aew/config.json`.
2. `git fetch origin <default>`. On failure stop with `Could not fetch origin/<default>: <stderr>.`
3. Ahead: `git rev-list --count origin/<default>..<default>`. Behind: `git rev-list --count <default>..origin/<default>`. If the first fails because `<default>` is unknown, stop with `The default branch <default> does not exist locally: run git switch <default>, then retry.`
4. Compare the two counts (`<ahead>` and `<behind>`):
   - `behind` above 0 (only behind, or diverged): stop with `<default> is behind origin/<default> by <behind> commit(s), and ahead by <ahead>: run git switch <default> && git pull --ff-only (or reconcile the divergence), then retry.` Leave out ", and ahead by <ahead>" when `ahead` is 0.
   - `behind` 0 and `ahead` above 0: warn `<default> has <ahead> unpushed commit(s); the PR will include them.` and continue.
   - Both 0: pass.

## Check 5. No other active run

1. `cat .aew/runs/current`. A missing or empty file passes.
2. Otherwise `jq -r .status .aew/runs/<cur>/state.json`, where `<cur>` is the id in `current`. If that `state.json` is missing, pass with a warning (`aew: run <cur> has no state.json; ignoring it.`).
3. Pass when the status is `done` or `failed`, or when `<cur>` is this issue and the call is `--from` or `resume`.
4. `<cur>` is another run and its status is active (`running`, `blocked`, `awaiting_input`, `awaiting_plan_approval`): stop with `Run <cur> is active (<status>): finish it with /aew:resume <cur>, or check it with /aew:status <cur>.`
5. `<cur>` is this issue, without `--from`: stop with `Run <n> is active (<status>): continue it with /aew:resume <n>, or restart a stage with /aew:ship <n> --from <stage>.`

## Check 6. superpowers major version (warn only)

superpowers cannot be range-pinned (DESIGN §4), so this is the early warning. It never stops the run.

Built against superpowers major: 7

Command:

`claude plugin list --json | jq -r '.[] | select(.id == "superpowers@claude-plugins-official") | .version'`

Outcomes:

- Empty output or a non-zero exit: warn `Could not check the installed superpowers version.`
- The value matches `^[0-9]+\.` and its major is not 7: warn `superpowers <value> is installed; aew is built against 7.x. Check the superpowers release notes before relying on this run.`
- The value is not semver (for example a 12-character commit SHA): warn `The installed superpowers version "<value>" is not a release number, so it could not be compared with 7.x.`
- A 7.x value: no output.

## Restart checks (--from)

Read-only. The writes (`current set`, `set auto`, `git switch`) are in `SKILL.md` `## Step 4. Restart at a stage (--from)`.

1. `test -f .aew/runs/<n>/state.json && echo yes || echo no`. If it prints `no` and the stage is `spec_analysis`, go back to `SKILL.md` `## Step 3. Start the run` (a fresh start). For any other stage stop with `No run <n> to restart: start it with /aew:ship <n>.`
2. `jq -r .branch .aew/runs/<n>/state.json`. If it is `null` and the stage is not `spec_analysis`, stop with `Run <n> has no branch yet: restart it with /aew:ship <n> --from spec_analysis.`
3. The stage's required inputs (`dispatch.md` `## Required inputs per stage`), each with `test -f .aew/runs/<n>/<file> && echo yes || echo no`. If any prints `no`, stop with `Cannot restart run <n> at <stage>: missing <files>.`
