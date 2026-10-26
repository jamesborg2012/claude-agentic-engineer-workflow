---
name: resume
description: Continue an interrupted aew run from its state.json - re-asks a pending gate, or re-enters the ship procedure at the recorded stage after checking the branch and working tree. A bulk milestone run continues like one issue, a sequential one at its first unfinished child. Run it as /aew:resume [<run-id>].
disable-model-invocation: true
argument-hint: "[<run-id>]"
---

# aew resume

Continues the run named by the argument (default: the current run) from its `state.json`. It never re-runs a stage before the recorded one and never copies ship's procedure: it reads it and enters it at the right place. Milestone runs (`m-<n>`) are resumed as well: a bulk run as one pipeline, a sequential run at its first unfinished child.

## Plugin root

The plugin root is `${CLAUDE_PLUGIN_ROOT}`.

- Read `${CLAUDE_PLUGIN_ROOT}/skills/ship/SKILL.md` and the references it names with the Read tool. For a prompt-mode run, also read `${CLAUDE_PLUGIN_ROOT}/skills/prompt/SKILL.md`. For a sequential milestone run, also read `${CLAUDE_PLUGIN_ROOT}/skills/ship-milestone/SKILL.md` and `${CLAUDE_PLUGIN_ROOT}/skills/ship-milestone/references/sequential.md`.
- They are not substituted: read every literal `${CLAUDE_PLUGIN_ROOT}` in them as the root above. Call each script by its absolute path under `${CLAUDE_PLUGIN_ROOT}/scripts/`, written out in the command, because the Bash tool has no `CLAUDE_PLUGIN_ROOT` variable. A bare `state.sh …` below means that absolute path.
- Never invoke `ship`, `ship-milestone` or `prompt` with the Skill tool: all three set `disable-model-invocation: true`, which blocks it.
- Citation form: `` `<file>.md` `## <heading>` ``. `` `SKILL.md` `` is ship's `skills/ship/SKILL.md`, `` `preflight.md` `` and `` `gates.md` `` are under `skills/ship/references/`, `` `prompt/SKILL.md` `` is `skills/prompt/SKILL.md`, `` `ship-milestone/SKILL.md` `` is `skills/ship-milestone/SKILL.md`, and `` `sequential.md` `` is under `skills/ship-milestone/references/`.

## Rules

- Ship's `SKILL.md` `## Rules` apply to everything resume does once it continues a run.
- Before Step 5, resume writes nothing: no state, label, branch or file.
- The issue, `auto`, counters, branch and base branch come from `state.json` (`SKILL.md` `## Run variables`), never from this session.

## Step 1. Pick the run

The argument is: `$ARGUMENTS`.

Split it on whitespace. Print each error below followed by `Usage: /aew:resume [<run-id>]`, then stop.

- No token: run `cat .aew/runs/current`. A missing or empty file stops with `aew resume: no current run. Name one: /aew:resume <run-id> (/aew:status lists the runs).` Otherwise the content is the id.
- One token matching `^([1-9][0-9]*|m-[1-9][0-9]*)$`: it is the id. Any other single token stops with `aew resume: "<token>" is not a run id (an issue number, or m-<number> for a milestone run).`
- More than one token: stop with `aew resume: unexpected argument "<token>".` (the second token).

Then `test -f .aew/runs/<id>/state.json && echo yes || echo no`. If it prints `no`, stop with `aew resume: no run <id> (.aew/runs/<id>/state.json is missing).`

## Step 2. Read the state

1. `jq -r '[.status, .stage, .mode, (.issues | map(tostring) | join(",")), (.branch // "-"), (.pr // "-" | tostring)] | @tsv' .aew/runs/<id>/state.json` gives status, stage, mode, issues, branch and PR.
2. Prompt-mode test (the marker is present and `branch` is null):
   `jq -r 'if ([.history[] | select(.note == "prompt")] | length) > 0 and .branch == null then "prompt" else "ship" end' .aew/runs/<id>/state.json`
3. The mode decides how the run continues. Nothing is written here.
   - `single`: as below.
   - `bulk`: as below, like `single`. Ship's sections carry the bulk hooks into `bulk.md`, and `<n>` means each issue in `issues` (`SKILL.md` `## Run variables`).
   - `sequential-child`: find the milestone run it belongs to:
     `jq -r '[.history[] | select((.note // "") | startswith("milestone m-"))] | first | .note // "" | ltrimstr("milestone ")' .aew/runs/<id>/state.json`
     Empty output stops with `aew resume: run <id> has no "milestone m-<n>" note.` Otherwise print `Run <id> is part of milestone run <parent>: continuing the milestone.`, take `<parent>` as `<id>` from here on, and run Step 1's `state.json` test and items 1 and 3 of this step again for it. A parent that is not a `sequential` run stops with `aew resume: <parent> is not a sequential milestone run.`
   - `sequential`: a milestone run whose children are runs of their own. Step 3 applies as written, Step 4 skips item 4, and Step 5 hands over at item 2.

## Step 3. Finished runs

Nothing is written here.

- `done`: print `Run <id> is done: nothing to resume.`, then `PR #<pr> on <branch>.` for a ship run, or `The prompt is at .aew/runs/<id>/prompt.md.` for a prompt-mode run. For a `sequential` run, print `See /aew:status <id> for each child and its PR.` instead of the PR line. Stop.
- `failed`: print the last note (`jq -r '.history | last | .note // ""' .aew/runs/<id>/state.json`), then `Run <id> failed at <stage> and is finished: restart it with /aew:ship <n> --from <stage>.` For a prompt-mode run print instead `Run <id> failed at <stage>: remove .aew/runs/<id>, then run /aew:prompt <n> again.` For a `bulk` run, print instead `Run <id> failed at <stage> and is finished: remove .aew/runs/m-<mn>, then rerun /aew:ship-milestone <mn> --bulk.` (`<mn>` is the id without `m-`). Stop.

## Step 4. Checks

Read-only. Skips checks 4 and 6 of `preflight.md`: the default branch no longer matters mid-run.

1. Run `preflight.md` `## Check 1. Config exists`, `preflight.md` `## Check 3. gh is authenticated` and `preflight.md` `## Check 5. No other active run`. Another active run stops with that check's message; this run passes.
2. A prompt-mode run skips items 3 and 4: it commits nothing and has no branch.
3. Run `preflight.md` `## Check 2. Clean working tree` in its restart form: `git status --porcelain --untracked-files=all`, ignoring lines whose path starts with `.claude/agent-memory/`. Anything else stops with that check's message and paths. Nothing is stashed, reset or discarded.
4. A `sequential` run skips this item: its `branch` is null, and `sequential.md` `## Resume` checks each child's branch. For a `bulk` run, a null `branch` stops with `Run <id> has no branch: remove .aew/runs/m-<mn>, then rerun /aew:ship-milestone <mn> --bulk.` Otherwise, if `branch` is null, stop with `Run <id> has no branch: restart it with /aew:ship <n> --from spec_analysis.` Otherwise compare it with `git branch --show-current`. If they differ, `git switch <branch>` (the tree is clean, so this is safe). A failed switch stops with git's first error line.

## Step 5. Continue

1. `state.sh current set <id>`, because every `state.sh` write acts on the current run.
2. Mode `sequential`: Read `${CLAUDE_PLUGIN_ROOT}/skills/ship-milestone/SKILL.md` and `${CLAUDE_PLUGIN_ROOT}/skills/ship-milestone/references/sequential.md`, then follow `sequential.md` `## Resume`. It acts on the first child whose index status is not `done`, and for a child that has started it runs this file's `## Step 4. Checks` and `## Step 5. Continue` with that child's id. The items below then apply to the child, never to the parent.
3. Status `awaiting_input` or `awaiting_plan_approval`: Read `gates.md` and follow `gates.md` `## Re-asking a pending gate`. It finds the gate from the `gate:` note and enters that gate at step 2, so only what the gate reads is re-read, and state and label are not re-written. The gate's apply step then continues into ship's sections as written. If there is no answer again, follow `SKILL.md` `## Gate pending` (the run stays pending). `gates.md` `## Re-asking a pending gate` itself hands a prompt-mode run back to the `prompt` skill, so resume adds nothing for it here. In a `bulk` run, a note `gate:spec issues/<k>/01-spec-analysis.md` is issue `k`'s gate; `gates.md` `## Re-asking a pending gate` sets its `<rd>` and `<n>`.
4. Status `running` or `blocked`, and the Step 2 test printed `ship`: Read `SKILL.md` and its references. Skip `SKILL.md` Steps 1–4 (argument parsing, preflight, run start and restart, done above or not needed). Enter ship's stage section `## Stage: <stage>` for the recorded stage at step 1, with the note `resume`. A recorded `qa_test_plan` enters `## Stage: plan`. The stage entry re-writes status `running` and moves the label off `blocked`.
5. Status `running` or `blocked`, and the test printed `prompt`: Read `prompt/SKILL.md`. Stage `spec_analysis` enters `prompt/SKILL.md` `## Step 4. Analyse the spec`, and `brief` enters `prompt/SKILL.md` `## Step 5. Compile the prompt`, each at step 1 with the note `resume`.
6. Resume never runs `state.sh init`, never fetches the issue, never creates a branch, never runs a stage before the recorded one, and never re-runs a finished child.
