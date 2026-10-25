---
name: status
description: Read-only view of aew runs in this project - with no argument lists every run (id, status, stage, updated, current, title); with a run id shows its state, the last 10 log lines, the review and fix cycles used, and the next action. Run it as /aew:status [<run-id>].
argument-hint: "[<run-id>]"
---

# aew status

A read-only view of the aew runs in this project: every run at a glance, or one run in detail.

## Rules

- Read-only. Write no file and run no plugin script, no git command and no gh command. Read `state.json` with `jq`, because the state script's `get` reads only the current run.
- Paths are relative to the project root. Never open other artefacts, and never read source code.
- A run id is an issue number or `m-<number>` for a milestone run. Only directories under `.aew/runs/` whose names match a run id are runs: `current` and init's flat `init-*` scratch files are not.

## Step 1. Parse the argument

The argument is: `$ARGUMENTS`.

- No token: go to `## List every run`.
- One token matching `^([1-9][0-9]*|m-[1-9][0-9]*)$`: go to `## Show one run` with that id.
- One token that does not match: print `aew status: "<token>" is not a run id (an issue number, or m-<number> for a milestone run).`, then `Usage: /aew:status [<run-id>]`, and stop.
- More than one token: print `aew status: unexpected argument "<token>".` (the second token), then `Usage: /aew:status [<run-id>]`, and stop.

## List every run

1. Run `cat .aew/runs/current`. Missing or empty means there is no current run; `<cur>` is then `-`.
2. Run this one read (`<cur>` is step 1's id, written bare after `--arg cur`, or `-` when there is no current run). The glob matches only directories that hold a `state.json`, and `test()` keeps only run-id names. `--arg` goes after the filter, never before it:

   ```sh
   jq -r 'input_filename as $f | ($f | split("/") | .[-2]) as $id | select($id | test("^([1-9][0-9]*|m-[1-9][0-9]*)$")) | [$id, .status, .stage, .updated_at, (if $id == $cur then "current" else "-" end), (.title // "-")] | @tsv' --arg cur <cur> .aew/runs/*/state.json
   ```

3. Print a table with the columns `| Run | Status | Stage | Updated | Current | Title |`, one row per line of output.
4. No output, `no matches found` (zsh) or `Could not open file` (bash) with no `.aew/runs/*/state.json` at all: print `No aew runs in this project.`
5. A `jq: parse error` is not that case. jq reads the files as one stream, so the error names no file and can hide every run after the bad one. Run `ls .aew/runs/*/state.json`, keep the paths whose directory name matches a run id, and run the same read once per kept name, with that run's literal path in place of the glob (no shell variables, no loop). Report each `corrupt` line as a corrupt `state.json`, naming it, above the table of the other runs:

   ```sh
   jq -r 'input_filename as $f | ($f | split("/") | .[-2]) as $id | select($id | test("^([1-9][0-9]*|m-[1-9][0-9]*)$")) | [$id, .status, .stage, .updated_at, (if $id == $cur then "current" else "-" end), (.title // "-")] | @tsv' --arg cur <cur> .aew/runs/<run-id>/state.json 2>/dev/null || printf 'corrupt\t%s\n' .aew/runs/<run-id>/state.json
   ```

## Show one run

1. Run `test -f .aew/runs/<id>/state.json`. Missing: print `aew status: no run <id>.` and stop.
2. State fields:

   ```sh
   jq -r 'del(.history) | to_entries[] | "\(.key): \(.value | if type == "array" then map(tostring) | join(",") else tostring end)"' .aew/runs/<id>/state.json
   ```

   A `jq` parse error means a corrupt `state.json`: say so, naming `.aew/runs/<id>/state.json`, and stop.
3. Last 10 log lines: `tail -n 10 .aew/runs/<id>/log.md`.
4. Cycles used against their limits:

   ```sh
   jq -r '"\(.limits.max_review_cycles // 2) \(.limits.max_fix_cycles // 3)"' .aew/config.json
   ```

   Print `review <review_cycle>/<max_review_cycles>, fix <fix_cycle>/<max_fix_cycles>`. With no `.aew/config.json`, use the schema defaults 2 and 3 and say so.
5. For `awaiting_input` and `awaiting_plan_approval`, name the pending gate:

   ```sh
   jq -r '[.history[] | select((.note // "") | startswith("gate:"))] | last | .note' .aew/runs/<id>/state.json
   ```

   The note reads `gate:<gate-id> <source file>`. `null` means `plan-approval` for `awaiting_plan_approval` and `spec` for `awaiting_input`. For `blocked` and `failed`, give the reason:

   ```sh
   jq -r '.history | last | .note // ""' .aew/runs/<id>/state.json
   ```

   Mark a prompt-mode run with this check (`prompt` means prompt mode):

   ```sh
   jq -r 'if ([.history[] | select(.note == "prompt")] | length) > 0 and .branch == null then "prompt" else "ship" end' .aew/runs/<id>/state.json
   ```

6. Go to `## Next action`.

## Next action

Pick the row for the run's status and fill in `<id>`, `<gate>`, `<pr>`, `<n>` (the issue) and `<stage>` from the state.

| Status | Next action |
|---|---|
| `running` | If no session is driving it (interrupted), `/aew:resume <id>`; otherwise wait. |
| `awaiting_input` | Answer the `<gate>` gate with `/aew:resume <id>`. |
| `awaiting_plan_approval` | Approve, change or stop the plan with `/aew:resume <id>` (the plan is `.aew/runs/<id>/05-plan.md`). |
| `blocked` | Fix the reason shown, then `/aew:resume <id>`. |
| `done` | Nothing to do: PR #<pr>. A prompt-mode run has `.aew/runs/<id>/prompt.md` instead. |
| `failed` | Finished. Restart it with `/aew:ship <n> --from <stage>`. A prompt-mode run has no PR: remove `.aew/runs/<n>`, then run `/aew:prompt <n>` again. |

A run whose `mode` is not `single` is handled by `/aew:ship-milestone` (coming in a later release).
