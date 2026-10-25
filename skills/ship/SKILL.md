---
name: ship
description: Ship one GitHub issue through the aew pipeline - spec analysis, brief, standards, QA plan and plan in parallel, the plan gate, development, review, QA with triage, docs and a pull request. Run it as /aew:ship <issue> [--auto] [--from <stage>].
disable-model-invocation: true
argument-hint: "<issue> [--auto] [--from <stage>]"
---

# aew ship

This is the main-thread orchestrator for one issue. It is the only part of aew that touches GitHub, and only through the plugin scripts. Agents are dispatched with explicit inputs, and only their return blocks are read.

## Plugin root

The plugin root is `${CLAUDE_PLUGIN_ROOT}`.

- The scripts live in `${CLAUDE_PLUGIN_ROOT}/scripts/`. Call each one by its absolute path, written out in the command, because the Bash tool has no `CLAUDE_PLUGIN_ROOT` variable. In this file and the references, a bare `state.sh …` (or `gh-issue.sh …`, `gh-labels.sh …`, `git-branch.sh …`, `gh-pr.sh …`, `gh-retro.sh …`) means that absolute path.
- Never write a `<placeholder>` inside a `${CLAUDE_PLUGIN_ROOT}/…` path.
- The references are read with Read and are not substituted: read every literal `${CLAUDE_PLUGIN_ROOT}` in them as the root above.
- A skill that reads this file with Read (`resume`, `prompt`) states the root itself, and the same rule applies to this file.

## Rules

- Run every command from the project root and never `cd`.
- Write each command so it can be pre-approved before it runs: one command (or the pipeline given) per call, no `$VAR`, `$?` or `$(…)`, no backticks, no `VAR=x cmd` prefix, no brace expansion and no heredoc. A value one command prints and the next one needs is read first, then written into the next command as a literal. Free text in a double-quoted argument (a title, a `--note`, a commit message) has `"`, `$`, backtick and `\` escaped with a backslash. `jq` puts every `--arg name value` after the filter, with a plain-token value (a number or a run id), and reads several files with `-s`, never `--slurpfile`.
- Never run `gh` except `gh auth status` in preflight.
- Never run git's push, merge, rebase, reset or force forms. Push only with `git-branch.sh push`.
- Stage explicit paths only (`git add -- <paths>`), never `-A` or `.`.
- Never edit an artefact, `state.json` or `log.md`: scripts own state. The only files ship writes are `spec-revision-v<N>.md` (the `jq` render), `.aew/runs/blocked-<id>.md` (the blocked comment, written with the Write tool) and the commits in `pr.md`.
- Read only what `## What the orchestrator reads` lists.
- Every developer dispatch comes straight after a `state.sh` write in the same step (the developer gate's freshness check).
- One agent per Agent call, except the planning pair in `## Stage: plan`.
- An invalid return counts as `failed`. A failed dispatch is retried once in this session, then the blocked path.
- Script failures follow `routing.md` `## Script failures`.
- Write labels bare: `gh-labels.sh stage <n> blocked`, "the `blocked` label".
- A gate's answer comes only from AskUserQuestion on the main thread. Never take it from an agent, and never invent one.
- Citation form (used here and in every reference): a section of another file is cited as `` `<file>.md` `## <heading>` ``, with the file name in backticks, one space, then the exact heading in backticks.

## Run variables

Read each value fresh before each use.

- `<id>` and `<n>`: the run id and the issue number (the same number in single mode).
- `<rd>`: `.aew/runs/<id>`.
- `auto`, `review_cycle`, `fix_cycle`, `spec_revision`, `branch`, `base_branch`, `pr`, `stage`, `status`: `state.sh get <field>`.
- Limits: `jq -r '.limits.max_review_cycles // 2' .aew/config.json` and `jq -r '.limits.max_fix_cycles // 3' .aew/config.json`.
- Plan gate: `jq -r 'if .gates.plan_approval == false then "off" else "on" end' .aew/config.json`. Do not use `// true`, which turns an explicit `false` into `true`.
- `<default>`: `jq -r '.default_branch // "main"' .aew/config.json`.

`resume` takes all of these from `state.json`. After `state.sh current clear` (run-start failures, the plan-gate stop, `pr.md` `## Finish`), `state.sh get` fails, so any later read uses `jq -r .<field> .aew/runs/<id>/state.json`.

## What the orchestrator reads

| Read | When | How |
|---|---|---|
| The Agent return block | every dispatch | the last four non-blank lines of the result |
| ARTEFACTS paths and required inputs | before and after each dispatch | `test -f <path> && echo yes \|\| echo no` (`no` is missing); develop mode: `test <rd>/07-review-<review_cycle>.md -nt <rd>/05-plan.md && echo newer \|\| echo older` |
| Each named developer report | after a developer dispatch | `awk 'NF' <file> \| tail -n 4` |
| `05-plan.md` | the plan gate | Read in full (the only full read) |
| `## Questions` of `01-spec-analysis.md` | gate `spec` | bounded section read (`gates.md`) |
| `## Challenges to the spec` of `05-plan.md` | gate `plan-challenge` | bounded section read |
| `## Root cause` and `## Where the divergence started` of `09-triage-<k>.md` | gate `triage` | bounded section read |
| The triage table of `08-qa-report-<k>.md`, and of `<k-1>` | the QA loop (repeat check) | bounded section read (`routing.md`) |
| The `### TC-<n>:` entries classed `spec_ambiguity` | gate `spec-ambiguity` | bounded section read |
| `state.json` | any decision | `state.sh get <field>`, or `jq` for `history` notes |
| `.aew/config.json` fields | limits, gates, `default_branch` | `jq` |
| `spec-changes.json` | recording a spec revision | `jq` counts, and a render to a file only |
| `issue.json` | run start, `--from spec_analysis` | `jq` for `title`, `state` and `url` |
| The return block of an `08-qa-report-<k>.md` | the complete-failure test (`routing.md`), the `docs` required inputs (`dispatch.md`) | `awk 'NF' <file> \| tail -n 4` |
| `01-spec-analysis.md` question count | numbering extra questions in gates `plan-challenge` and `spec-ambiguity` | `grep -c '^### Q[0-9]'` |
| `.aew/runs/current` | preflight Check 5 | `cat` |
| `.status` of another run's `state.json` | preflight Check 5 | `jq -r .status` |
| `10-summary.md` and `manual-tests.md` | the pull request and the final report | `grep -c` |

Nothing else. Never open other artefacts, and never read source code. A bounded section read is not a full read.

## References

Read each reference at the step that names it.

| File | Covers | Read at |
|---|---|---|
| `${CLAUDE_PLUGIN_ROOT}/skills/ship/references/preflight.md` | the six preflight checks and the restart checks | Step 2, Step 4 |
| `${CLAUDE_PLUGIN_ROOT}/skills/ship/references/dispatch.md` | how to dispatch, the dispatch table (rows D1 to D13), required inputs, the return check, retries | every stage |
| `${CLAUDE_PLUGIN_ROOT}/skills/ship/references/gates.md` | gate ids and pending state, asking, each gate, recording a spec revision, re-asking | spec_analysis, plan, qa |
| `${CLAUDE_PLUGIN_ROOT}/skills/ship/references/routing.md` | the stage table, status routing, review loop, developer blocked, QA loop, cycle limits, script failures | every stage |
| `${CLAUDE_PLUGIN_ROOT}/skills/ship/references/pr.md` | commit rules, the standards, docs and memory commits, push and pull request, manual tests, retro, finish | standards, docs, pr |
| `${CLAUDE_PLUGIN_ROOT}/skills/ship/references/final-report.md` | the report format, counting, blocked and failed runs | Final report |

For the stage diagram, see `${CLAUDE_PLUGIN_ROOT}/skills/run-protocol/references/state-machine.md`. For script output contracts, see `${CLAUDE_PLUGIN_ROOT}/skills/github-ops/SKILL.md`.

## Step 1. Parse the arguments

The arguments are: `$ARGUMENTS`

Split them on whitespace. Nothing in this step runs a command or writes anything. The first error wins: print its line, then `Usage: /aew:ship <issue> [--auto] [--from <stage>]`, then stop.

In order:

1. No tokens: E1.
2. The first token. `^m-[0-9]+$`: E3. `^[1-9][0-9]*$`: that is the issue. Starts with `--`: E1. Anything else: E2.
3. Each later token, left to right. `--auto`: a second one is E5. `--from`: a second one is E5; no next token, or a next token starting with `-`, is E7; a next token that is not one of the ten stages is E8; otherwise that token is the stage. Any other token starting with `-`: E4. Anything else: E6.

Error lines (fill in the `<…>`):

- E1 `aew ship: missing issue number.`
- E2 `aew ship: the issue must be a positive integer, got "<token>".`
- E3 `aew ship: "<token>" is a milestone; milestone runs use /aew:ship-milestone (coming in a later release).`
- E4 `aew ship: unknown option "<token>".`
- E5 `aew ship: option "<token>" given more than once.`
- E6 `aew ship: unexpected argument "<token>".`
- E7 `aew ship: --from needs a stage.`
- E8 `aew ship: unknown stage "<token>". Stages: spec_analysis, brief, standards, qa_test_plan, plan, develop, review, qa, docs, pr.`

The result is `<n>`, `auto` (true or false) and `from` (a stage, or none).

## Step 2. Preflight

Run the six checks in order, from `preflight.md` `## Check 1. Config exists` to `preflight.md` `## Check 6. superpowers major version (warn only)`. The first failing check stops the run with its message, having written nothing. Check 6 only warns. Preflight checks the default branch and never fast-forwards it. With `--from`, Check 2 uses the restart form and Check 5 treats this issue's run as being resumed.

Then: `from` set, go to Step 4. Otherwise go to Step 3.

## Step 3. Start the run

State is initialised before the fetch (a recorded deviation from DESIGN's order), because `gh-issue.sh fetch` writes into an existing run dir.

- 3.1 `test -e .aew/runs/<n> && echo exists || echo absent`. If it prints `exists`, stop with `Run <n> already exists: continue it with /aew:resume <n>, or restart a stage with /aew:ship <n> --from <stage>.`
- 3.2 `state.sh init <n> --issues <n> --mode single`, adding `--auto` when given.
- 3.3 `gh-issue.sh fetch <n> .aew/runs/<n>`. On failure: `state.sh status failed --note "fetch failed: <first stderr line>"`, then `state.sh current clear`, then print `Could not fetch issue #<n>: <reason>. Fix it, then restart with /aew:ship <n> --from spec_analysis.` and stop.
- 3.4 `jq -r .state .aew/runs/<n>/issue.json`. If it prints `CLOSED`, take the same three actions as in 3.3, with the reason `issue #<n> is closed`.
- 3.5 Read the title on its own: `jq -r .title .aew/runs/<n>/issue.json`. Then `state.sh set title "<that title>"`, with the printed text written into the command as a double-quoted literal (see `## Rules`, free text in a command). Never nest the first command inside the second.
- 3.6 `gh-labels.sh stage <n> analysing`.
- 3.7 The slug: `jq -r '.title | ascii_downcase | gsub("[^a-z0-9]+"; "-") | ltrimstr("-") | .[0:40] | rtrimstr("-") | if . == "" then "issue-<n>" else . end' .aew/runs/<n>/issue.json`. Then `git-branch.sh create <n> <slug>` (it prints the branch name), then `state.sh set branch <name>`.
- 3.8 Go to `## Stage: spec_analysis` step 2 (Step 3 has done its Entry).

## Step 4. Restart at a stage (--from)

1. Run `preflight.md` `## Restart checks (--from)`. A missing run dir with `from` = `spec_analysis` goes to Step 3. Every other failure stops there.
2. `state.sh current set <n>`.
3. Add `state.sh set auto true` when `--auto` was given. Without `--auto`, the run keeps its recorded value.
4. If the current branch (`git branch --show-current`) is not `state.branch`: `git switch <branch>`.
5. For `spec_analysis`: `gh-issue.sh fetch` as in 3.3 and the closed check as in 3.4 (`current` was just set, so clear it again on failure), then `state.sh set title` as in 3.5, and the slug and branch of 3.7 only when `state.branch` is null.
6. `qa_test_plan` and `plan` both go to `## Stage: plan`.
7. Enter `## Stage: <from>` at step 1 with the note `--from`.

Earlier stages are not redone, counters are kept, and a `done` run's PR is updated rather than re-created (`state.pr`).

## Stage: spec_analysis

1. Entry: `state.sh stage spec_analysis` (note `--from` or `resume` when sent that way), then `gh-labels.sh stage <n> analysing`.
2. Check required files: `dispatch.md` `## Required inputs per stage`. A missing file goes to `## Blocked path`, naming it.
3. Dispatch row D1 (`dispatch.md` `## Dispatch table`) with `spec_version: <spec_revision+1>`.
4. Return check: `dispatch.md` `## Return check`.
5. Exit: `ok` runs `gates.md` `## Recording a spec revision`, then `## Stage: brief`. `needs_input` runs `gates.md` `## Gate: spec`.
6. Failure: `routing.md` `## Agent status routing` and `dispatch.md` `## Retries`.

## Stage: brief

1. Entry: `state.sh stage brief` (with the reason as a note when sent by a gate), then `gh-labels.sh stage <n> planning`.
2. Check required files: `dispatch.md` `## Required inputs per stage`.
3. Dispatch row D3.
4. Return check: `dispatch.md` `## Return check`.
5. Exit: `ok` goes to `## Stage: standards`, except after a non-material `spec-ambiguity` answer, which goes to `## Stage: qa`. Decide this from `history`, not from session memory, so a resumed brief takes the same exit. Run this command:

   `jq -r '.history | (map(.note == "spec-ambiguity: non-material") | indices(true) | last) as $i | if $i == null then "no" elif (.[$i+1:] | any(.stage != "brief")) then "no" else "yes" end' .aew/runs/<id>/state.json`

   `yes` goes to `## Stage: qa`. `no` goes to `## Stage: standards`.
6. Failure: `routing.md` `## Agent status routing`.

## Stage: standards

1. Entry: `state.sh stage standards`, then `gh-labels.sh stage <n> planning`.
2. Check required files: `dispatch.md` `## Required inputs per stage`.
3. Dispatch row D5.
4. Return check: `dispatch.md` `## Return check`.
5. Exit: `ok` runs `pr.md` `## Standards commit`, then `## Stage: plan`.
6. Failure: `routing.md` `## Agent status routing`.

## Stage: qa_test_plan

`qa_test_plan` and `plan` are one step. Go to `## Stage: plan`.

## Stage: plan

1. Entry: `state.sh stage plan` (note `--from`, `resume`, or the reason that sent you here), then `gh-labels.sh stage <n> planning`.
2. Check required files: `dispatch.md` `## Required inputs per stage`.
3. Dispatch rows D6 and D7. Send them as two Agent calls in ONE assistant message, with no other tool call in it, and do not wait for one before sending the other. When this stage was entered with `notes` (a plan-gate change request, or a developer `blocked`), dispatch only D7 with `notes:`, because QA phase A is not re-run. `notes` is one line and the last field of the D7 prompt; join several notes with ` / `.
4. Return check: check both returns (`dispatch.md` `## Return check`). If one failed, retry only that one, on its own.
5. Exit: plan `needs_input` runs `gates.md` `## Gate: plan-challenge`. Both `ok`: go to `gates.md` `## Gate: plan-approval` when `auto` is false and the plan gate is `on`, otherwise to `## Stage: develop`.
6. Failure: `routing.md` `## Agent status routing`.

## Stage: develop

1. Entry: `state.sh stage develop` (note `--from`, `resume`, or the reason that sent you here), then `gh-labels.sh stage <n> building`. This write is the one the developer gate needs: dispatch straight after it.
2. Choose the mode. Fix mode needs `review_cycle` k of at least 1 and `test .aew/runs/<id>/07-review-<k>.md -nt .aew/runs/<id>/05-plan.md && echo newer || echo older` to print `newer`: dispatch row D10 with `fix_from: 07-review-<k>.md` and `n: <k>`. Otherwise dispatch row D8 (`mode: full`). Check required files first (`dispatch.md` `## Required inputs per stage`).
3. Dispatch the row chosen.
4. Return check: `dispatch.md` `## Return check`, which includes every `06-dev-report*.md` the developer names.
5. Exit: `ok` goes to `## Stage: review`. `blocked` goes to `routing.md` `## Developer blocked`.
6. Failure: `routing.md` `## Agent status routing`.

## Stage: review

1. Entry: `state.sh stage review`, then `gh-labels.sh stage <n> building`.
2. Check required files: `dispatch.md` `## Required inputs per stage`.
3. Dispatch row D9 with `n: <review_cycle+1>` and `base: <base_branch>`.
4. Return check: `dispatch.md` `## Return check`. The verdict is the first word of SUMMARY.
5. Exit: `approve` goes to `## Stage: qa`. `changes_required` goes to `routing.md` `## Review loop`. Any other word is an invalid return.
6. Failure: `routing.md` `## Cycle limits` and `routing.md` `## Agent status routing`.

## Stage: qa

1. Entry: `state.sh stage qa` (note `--from`, `resume`, or the reason that sent you here), then `gh-labels.sh stage <n> testing`.
2. Check required files: `dispatch.md` `## Required inputs per stage`.
3. Dispatch row D12 with `n: <fix_cycle+1>`, adding `triage:` only when sent by the QA loop.
4. Return check: `dispatch.md` `## Return check`.
5. Exit: `ok` goes to `## Stage: docs`.
6. Failure: `failed` goes to `routing.md` `## QA loop`, where the complete-failure test decides between routing and retrying.

## Stage: docs

1. Entry: `state.sh stage docs`, then `gh-labels.sh stage <n> documenting`.
2. Check required files: `dispatch.md` `## Required inputs per stage`.
3. Dispatch row D13.
4. Return check: `dispatch.md` `## Return check`.
5. Exit: `ok` runs `pr.md` `## Docs and memory commits`, then `## Stage: pr`.
6. Failure: `routing.md` `## Agent status routing`.

## Stage: pr

1. Entry: `state.sh stage pr` only. The `ready-for-review` label is set once the PR exists.
2. Run `pr.md` `## Push and pull request`, `pr.md` `## Manual tests`, `pr.md` `## Retro` and `pr.md` `## Finish`, in that order.
3. Go to `## Final report`.
4. Failure: `routing.md` `## Script failures`. Check `state.pr` before creating a PR (`pr.md`).

## Gate pending

Reached when a gate's Ask step gets no answer: AskUserQuestion is not among your tools (as in every headless run started with `--permission-prompts none`), the question is refused, or the answer is empty. Do not try to call a tool you do not have. State and label are already set by the gate.

Print `aew ship #<n>: waiting at the <gate-id> gate.`, then the questions with their recommended answers (or the plan summary and the `05-plan.md` path), then the line `Answer with /aew:resume <id>`. Stop: nothing after the gate runs.

## Blocked path

In this order:

1. Write the comment with the Write tool to `.aew/runs/blocked-<id>.md`. Do not use a temp file or a heredoc. If the file is left from an earlier block, Read it first, because the Write tool refuses to overwrite a file it has not read. The body: the heading `## aew run <id> blocked`, then bullets for the stage, the reason (the agent SUMMARY or the script error), the cycles (`review <review_cycle>/<max_review_cycles>, fix <fix_cycle>/<max_fix_cycles>`) and the artefact names from `ls .aew/runs/<id>` ("in the run dir, not on GitHub"), then the line ``Resume with `/aew:resume <id>`.``
2. `gh-issue.sh comment <n> .aew/runs/blocked-<id>.md`.
3. `gh-labels.sh stage <n> blocked`.
4. `state.sh status blocked --note "<reason, one line>"`.
5. Keep `current` as it is.
6. Go to `## Final report`, then stop.

A failed `gh` script call in step 2 or 3 never skips step 4. The final report names the call that failed.

## Final report

Follow `final-report.md` `## Format`, `final-report.md` `## Counting` and `final-report.md` `## Blocked and failed runs` for every outcome: `done`, `blocked` and `failed`.
