# Sequential mode

This file is read by ship-milestone in sequential mode, by ship through its milestone-child hooks, and by `resume`. It runs ship's own single-issue procedure once per open issue, in dependency order, and stacks each child on its dependency. The plugin root is `${CLAUDE_PLUGIN_ROOT}`: read every literal `${CLAUDE_PLUGIN_ROOT}` here as the plugin root stated in the skill that sent you here (`ship/SKILL.md`, `ship-milestone/SKILL.md` or `resume/SKILL.md`). A bare `state.sh …`, `git-branch.sh …` and the other scripts means that absolute path in `scripts/`, written out in the command.

Variables:

- `<mid>` is the parent run id and `<mrd>` its directory `.aew/runs/<mid>` (`<mn>` is the milestone number, as in `ship-milestone/SKILL.md` `## Run variables`). In `## Start` they come from `select`. In `## Resume` `<mid>` is the run id that resume gives. In ship's hooks it is the child's parent from `## Parent and dependency of a child` step 1.
- `<k>` is a child's issue number. It is also its run id and, inside ship's sections, its `<id>` and `<n>`.
- `<dep>` is a child's dependency issue.

Rules:

- A child is a ship run. This file never restates a stage, a dispatch or a gate: it enters ship's sections by citation.
- `index.json` is written only by `state.sh index`, and `state.json` only by `state.sh`.
- Re-read `index.json` and the child's `state.json` at every step. Never rely on session memory: this is a long session.
- The loop is driven by the model, one command per call. Never write a shell loop.
- Commands follow `ship/SKILL.md` `## Rules`.

## Start

Entered from `ship-milestone/SKILL.md` with `<mn>`, the milestone title, `auto`, `order` and each issue's `stack_on` from `select`. Nothing has been written yet.

1. For each issue `<k>` in `order`, in order, one command each: `test -e .aew/runs/<k> && echo exists || echo absent`. At the first `exists`, stop with this message, having written nothing: `aew ship-milestone: run <k> already exists, so #<k> cannot start as part of <mid>. Check it with /aew:status <k>, finish or remove it, then rerun.`
2. `state.sh init <mid> --issues <order, comma-separated, in order> --mode sequential --title "<milestone title>"`, adding `--auto` when given. Escape the title as in ship's Rules. This sets `current` to `<mid>`. The parent's `branch` stays null for the whole run.
3. `state.sh index init <mid> --stack-on <k>:<dep>,<k>:<dep>`. Give one `<k>:<dep>` pair for each open issue whose `stack_on` is not null, in `order`. Leave out `--stack-on` when there are none. On a non-zero exit: run `state.sh status failed --note "index init failed: <first stderr line>"`, then `state.sh current clear`, then print `aew ship-milestone: could not write the index for <mid>: <reason>. Remove <mrd>, then rerun.` and stop.
4. Go to `## Next child`.

## Next child

1. `jq -r '[.children[] | select(.status != "done")] | if length == 0 then "none" else (first | "\(.issue) \(.status)") end' <mrd>/index.json`. It prints `none`, or `<k> <status>`.
2. `none`: go to `## Finish the sequence`. `<k> pending`: go to `## Start a child`. Any other status can only follow a resume: go to `## Resume` step 2.

## Start a child

`current` is `<mid>`.

1. `state.sh index set <mid> <k> running`.
2. Read the parent's `auto` with `jq -r .auto <mrd>/state.json`. Read the dependency with `## Parent and dependency of a child` step 2. For a stacked child (`<dep>` not `none`), read the dependency's branch with `jq -r .branch .aew/runs/<dep>/state.json`.
3. If `${CLAUDE_PLUGIN_ROOT}/skills/ship/SKILL.md` has not been read in this session, Read it. Skip ship's Step 1 and Step 2, because the parent ran them. Then follow `ship/SKILL.md` `## Step 3. Start the run` from 3.1, with `<n>` = `<k>`. Make exactly these three substitutions:
   - **3.2:** `state.sh init <k> --issues <k> --mode sequential-child`, adding `--auto` when the parent's `auto` is `true`. Then, straight after it and before the fetch: `state.sh stage spec_analysis --note "milestone <mid>"`. This note is the link to the parent.
   - **3.7, stacked child only:** `git-branch.sh create <k> <slug> --base <dependency branch>` (the slug as in 3.7), then `state.sh set branch <name>`, then `state.sh set base_branch <dependency branch>`. A child with no dependency runs 3.7 unchanged, so it starts from the default branch.
   - **The rest, unchanged:** 3.1 and 3.3 to 3.6 run as ship writes them. So does 3.8, which goes into `ship/SKILL.md` `## Stage: spec_analysis` step 2, and every stage section after it.
4. The child is now an ordinary ship run. Its PR base and its review base follow from `base_branch` (`gh-pr.sh create` and dispatch row D9). Its plan gate applies unless `auto`. Ship's milestone-child hooks bring it back to `## After a child` when it ends, or stop the session at an unanswered gate. Write nothing else here.

## Parent and dependency of a child

Used by `## Start a child` and by ship's docs and Gate pending hooks.

1. Parent: `jq -r '[.history[] | select((.note // "") | test("^milestone m-[1-9][0-9]*$"))] | if length == 0 then "none" else (first | .note | ltrimstr("milestone ")) end' .aew/runs/<k>/state.json`. It prints `<mid>`, or `none` for a run that is not a milestone child. A hook that gets `none` does what ship says, as for a single run.
2. Dependency: `jq -r '.children[] | select(.issue == ($k | tonumber)) | .stack_on // "none"' --arg k <k> <mrd>/index.json`. It prints `<dep>` or `none`.
3. The three uses:
   - the `--base` and `base_branch` of `## Start a child`;
   - `stacked_on: <dep>` on dispatch row D13 (ship's docs hook), from which the doc-writer writes the stacked introduction (this PR builds on the PR for issue #`<dep>` and must be merged after it), with `check-pr-intro.sh` run as ship runs it;
   - the parent id in ship's `## Gate pending` line.
4. Stacking is decided without a `gh` call. A dependency that was closed at selection is not in `stack_on`.

## After a child

Reached from ship's `## Final report` (`done`, the blocked path, the plan-gate stop) and from ship's Step 3.3 and 3.4 stops. `<k>` is the child that just ended.

1. The parent `<mid>`, from `## Parent and dependency of a child` step 1.
2. `jq -r .status .aew/runs/<k>/state.json`. It is expected to be `done`, `blocked` or `failed`. Any other status means the child is still in progress: print `Child #<k> is <status>: continue it with /aew:resume <k>.` and stop, having written nothing.
3. `state.sh index set <mid> <k> <status>`.
4. `state.sh current set <mid>`.
5. `done`: `state.sh status running --note "child #<k> done"`, then go to `## Next child`. `blocked` or `failed`: go to `## Stop the sequence`.

## Stop the sequence

`current` is `<mid>`.

1. The reason: `jq -r '.history | last | .note // "no reason recorded"' .aew/runs/<k>/state.json`.
2. `state.sh status blocked --note "child #<k> <status>: <reason>"`. Keep the reason on one line, escaped as in ship's Rules.
3. `ship-milestone/SKILL.md` `## Milestone report` (outcome `stopped`; it ends with ship-milestone's final report).
4. Stop. `current` stays `<mid>`, and the parent is `blocked`, never `failed`. Later children get no state, branch or label. The final report's `Next:` line comes from that section: `/aew:resume <mid>` for a blocked child, or `/aew:ship <k> --from <stage>` for a failed child.

## Finish the sequence

1. `state.sh status done --note "sequence done"`.
2. `state.sh current clear`.
3. `ship-milestone/SKILL.md` `## Milestone report` (outcome `done`; it ends with ship-milestone's final report). After the clear, read the parent with `jq -r .<field> <mrd>/state.json`.

## Resume

Entered from `resume` with `<mid>`. Decide first, then write.

1. Run `## Next child` step 1. `none`: `state.sh current set <mid>`, then go to `## Finish the sequence`.
2. `<k>`: `test -f .aew/runs/<k>/state.json && echo yes || echo no`. `no` (a pending child, or one marked `running` before its init): `state.sh current set <mid>`, then `state.sh status running --note "resume"`, then go to `## Start a child`.
3. Otherwise `jq -r '[.status, .stage] | @tsv' .aew/runs/<k>/state.json`:
   - `failed`: print `Child #<k> failed at <stage>: restart it with /aew:ship <k> --from <stage>. It hands back to milestone run <mid> when it finishes.` then stop, having written nothing.
   - `done`: go to `## After a child` (the index fell behind the child).
   - `running`, `blocked`, `awaiting_input` or `awaiting_plan_approval`:
     1. follow `resume/SKILL.md` `## Step 4. Checks` with `<id>` = `<k>` (read-only: Check 5, the tree check and the branch check). A failing check stops there, having written nothing to the parent;
     2. `state.sh current set <mid>`;
     3. `state.sh status running --note "resume"`;
     4. `state.sh index set <mid> <k> running`;
     5. follow `resume/SKILL.md` `## Step 5. Continue` with `<id>` = `<k>`. It does `current set <k>`, then the gate re-ask or the stage entry.

     From there, ship's hooks hand the child back to `## After a child`.
4. Resume never re-runs a `done` child, and the parent itself has no branch to check.
