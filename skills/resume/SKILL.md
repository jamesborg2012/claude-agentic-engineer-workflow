---
name: resume
description: Continue an interrupted aew run from its state.json - re-asks a pending gate, or re-enters the ship procedure at the recorded stage after checking the branch and working tree. Run it as /aew:resume [<run-id>].
disable-model-invocation: true
argument-hint: "[<run-id>]"
---

# aew resume

Continues the run named by the argument (default: the current run) from its `state.json`. It never re-runs a stage before the recorded one and never copies ship's procedure: it reads it and enters it at the right place.

## Plugin root

The plugin root is `${CLAUDE_PLUGIN_ROOT}`.

- Read `${CLAUDE_PLUGIN_ROOT}/skills/ship/SKILL.md` and the references it names with the Read tool. For a prompt-mode run, also read `${CLAUDE_PLUGIN_ROOT}/skills/prompt/SKILL.md`.
- They are not substituted: read every literal `${CLAUDE_PLUGIN_ROOT}` in them as the root above. Call each script by its absolute path under `${CLAUDE_PLUGIN_ROOT}/scripts/`, written out in the command, because the Bash tool has no `CLAUDE_PLUGIN_ROOT` variable. A bare `state.sh …` below means that absolute path.
- Never invoke `ship` or `prompt` with the Skill tool: both set `disable-model-invocation: true`, which blocks it.
- Citation form: `` `<file>.md` `## <heading>` ``. `` `SKILL.md` `` is ship's `skills/ship/SKILL.md`, `` `preflight.md` `` and `` `gates.md` `` are under `skills/ship/references/`, and `` `prompt/SKILL.md` `` is `skills/prompt/SKILL.md`.

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

Then `test -f .aew/runs/<id>/state.json`. If it is missing, stop with `aew resume: no run <id> (.aew/runs/<id>/state.json is missing).`

## Step 2. Read the state

1. `jq -r '[.status, .stage, .mode, (.issues | map(tostring) | join(",")), (.branch // "-"), (.pr // "-" | tostring)] | @tsv' .aew/runs/<id>/state.json` gives status, stage, mode, issues, branch and PR.
2. Prompt-mode test (the marker is present and `branch` is null):
   `jq -r 'if ([.history[] | select(.note == "prompt")] | length) > 0 and .branch == null then "prompt" else "ship" end' .aew/runs/<id>/state.json`
3. A `mode` other than `single` stops with `aew resume: run <id> is a <mode> run; milestone runs are resumed by /aew:ship-milestone (coming in a later release).`

## Step 3. Finished runs

Nothing is written here.

- `done`: print `Run <id> is done: nothing to resume.`, then `PR #<pr> on <branch>.` for a ship run, or `The prompt is at .aew/runs/<id>/prompt.md.` for a prompt-mode run. Stop.
- `failed`: print the last note (`jq -r '.history | last | .note // ""' .aew/runs/<id>/state.json`), then `Run <id> failed at <stage> and is finished: restart it with /aew:ship <n> --from <stage>.` For a prompt-mode run print instead `Run <id> failed at <stage>: remove .aew/runs/<id>, then run /aew:prompt <n> again.` Stop.

## Step 4. Checks

Read-only. Skips checks 4 and 6 of `preflight.md`: the default branch no longer matters mid-run.

1. Run `preflight.md` `## Check 1. Config exists`, `preflight.md` `## Check 3. gh is authenticated` and `preflight.md` `## Check 5. No other active run`. Another active run stops with that check's message; this run passes.
2. A prompt-mode run skips items 3 and 4: it commits nothing and has no branch.
3. Run `preflight.md` `## Check 2. Clean working tree` in its restart form: `git status --porcelain --untracked-files=all`, ignoring lines whose path starts with `.claude/agent-memory/`. Anything else stops with that check's message and paths. Nothing is stashed, reset or discarded.
4. If `branch` is null, stop with `Run <id> has no branch: restart it with /aew:ship <n> --from spec_analysis.` Otherwise compare it with `git branch --show-current`. If they differ, `git switch <branch>` (the tree is clean, so this is safe). A failed switch stops with git's first error line.

## Step 5. Continue

1. `state.sh current set <id>`, because every `state.sh` write acts on the current run.
2. Status `awaiting_input` or `awaiting_plan_approval`: Read `gates.md` and follow `gates.md` `## Re-asking a pending gate`. It finds the gate from the `gate:` note and enters that gate at step 2, so only what the gate reads is re-read, and state and label are not re-written. The gate's apply step then continues into ship's sections as written. If there is no answer again, follow `SKILL.md` `## Gate pending` (the run stays pending). `gates.md` `## Re-asking a pending gate` itself hands a prompt-mode run back to the `prompt` skill, so resume adds nothing for it here.
3. Status `running` or `blocked`, and the Step 2 test printed `ship`: Read `SKILL.md` and its references. Skip `SKILL.md` Steps 1–4 (argument parsing, preflight, run start and restart, done above or not needed). Enter ship's stage section `## Stage: <stage>` for the recorded stage at step 1, with the note `resume`. A recorded `qa_test_plan` enters `## Stage: plan`. The stage entry re-writes status `running` and moves the label off `blocked`.
4. Status `running` or `blocked`, and the test printed `prompt`: Read `prompt/SKILL.md`. Stage `spec_analysis` enters `prompt/SKILL.md` `## Step 4. Analyse the spec`, and `brief` enters `prompt/SKILL.md` `## Step 5. Compile the prompt`, each at step 1 with the note `resume`.
5. Resume never runs `state.sh init`, never fetches the issue, never creates a branch, and never runs a stage before the recorded one.
