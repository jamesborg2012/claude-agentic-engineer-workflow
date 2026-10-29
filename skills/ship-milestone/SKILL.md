---
name: ship-milestone
description: Ship a whole GitHub milestone with aew - in bulk (one combined pipeline and one PR closing every issue) or sequentially (one ship run per issue in dependency order, with stacked PRs). Run it as /aew:ship-milestone <milestone> [--bulk|--sequential] [--auto].
disable-model-invocation: true
argument-hint: "<milestone> [--bulk|--sequential] [--auto]"
---

# aew ship-milestone

This is the main-thread orchestrator for a milestone (DESIGN §10). It reuses ship's procedure by reading ship's files, never by invoking the skill, and it is the only part of aew that touches GitHub for a milestone, through the plugin scripts alone.

## Plugin root

The plugin root is `${CLAUDE_PLUGIN_ROOT}`.

- Read `${CLAUDE_PLUGIN_ROOT}/skills/ship/SKILL.md` and the references it names under `${CLAUDE_PLUGIN_ROOT}/skills/ship/references/`, and this skill's references under `${CLAUDE_PLUGIN_ROOT}/skills/ship-milestone/references/`, with Read, when a step says so.
- In those files, read every literal `${CLAUDE_PLUGIN_ROOT}` as this root. A bare `state.sh …`, `gh-milestone.sh …`, `gh-issue.sh …` and the other scripts means that absolute path in `scripts/`, written out in the command.
- Never invoke `ship` with the Skill tool: it sets `disable-model-invocation: true`, which blocks it. Read its files instead.
- A skill that reads this file with Read (`resume`) states the root itself, and the same rule applies to this file.

## Rules

- `ship/SKILL.md` `## Rules` apply here. Additions:
- Nothing is written before Step 5: no run directory, no `current`, no label, no branch and no `gh` write.
- `gh-milestone.sh select` runs once per session.
- The only file this skill writes is `milestone-report.md`, besides what ship and the mode references write.
- This file has no `## Stage:` sections, dispatch rows or gate steps: the stages are ship's.
- Citation names. `ship/SKILL.md` and `ship-milestone/SKILL.md` are the two skill files, named with their skill directory; the file name alone is never used here. `preflight.md`, `dispatch.md`, `gates.md`, `routing.md`, `pr.md` and `final-report.md` are ship's references. `mode-selection.md`, `bulk.md` and `sequential.md` are this skill's references. The form is `` `<file>.md` `## <heading>` ``.

## Run variables

- `<m>`: the milestone as parsed in Step 1 (a number, or a title with its surrounding quotes removed).
- `<mn>`: `milestone.number` from `select`. `<mid>`: `m-<mn>`. `<mrd>`: `.aew/runs/<mid>`.
- `<title>`: `milestone.title` from `select`.
- `mode` (`bulk` or `sequential`) and `auto` (true or false), from Step 1 and Step 4.
- The `select` output: printed once in Step 3 and used from the session after that. `bulk.md` `## Start` and `sequential.md` `## Start` take `issues`, `order` and `stack_on` from it.
- After the start, read a parent field with `jq -r .<field> <mrd>/state.json`, never `state.sh get`, because `current` may name a child or be cleared.
- Inside each ship pipeline, `ship/SKILL.md` `## Run variables` apply.

## References

Read each reference at the step that names it.

| File | Covers | Read at |
|---|---|---|
| `${CLAUDE_PLUGIN_ROOT}/skills/ship-milestone/references/mode-selection.md` | the recommendation, the mode question, the cycle and stack-conflict stops | Step 4 |
| `${CLAUDE_PLUGIN_ROOT}/skills/ship-milestone/references/bulk.md` | the bulk run | Step 5, bulk |
| `${CLAUDE_PLUGIN_ROOT}/skills/ship-milestone/references/sequential.md` | the sequential run | Step 5, sequential |
| `${CLAUDE_PLUGIN_ROOT}/skills/ship/SKILL.md` | ship's rules, run variables and stages | every step |
| `${CLAUDE_PLUGIN_ROOT}/skills/ship/references/preflight.md` | the preflight checks | Step 2, Step 3 |
| `${CLAUDE_PLUGIN_ROOT}/skills/ship/references/final-report.md` | counting rules for the reports | Final report |

## Step 1. Parse the arguments

The arguments are: `$ARGUMENTS`

Split them on whitespace. Nothing in this step runs a command or writes anything. The first error wins: print its line, then `Usage: /aew:ship-milestone <milestone> [--bulk|--sequential] [--auto]`, then stop.

In order:

1. No tokens: `aew ship-milestone: missing milestone.`
2. Each token, left to right. `--bulk`, `--sequential` or `--auto` seen a second time: `aew ship-milestone: option "<token>" given more than once.` Any other token starting with `--`: `aew ship-milestone: unknown option "<token>".`
3. Both `--bulk` and `--sequential` given: `aew ship-milestone: --bulk and --sequential cannot both be given.`
4. Join every token that does not start with `--` with single spaces, and remove one surrounding pair of matching `"` or `'`. An empty result: `aew ship-milestone: missing milestone.`

The remaining text is the milestone. One token matching `^[1-9][0-9]*$` is the number. One token matching `^m-[1-9][0-9]*$` is the number after `m-`. Anything else is a title.

The result is `<m>`, `mode` (a flag, or none) and `auto` (true or false).

## Step 2. Preflight

Run `preflight.md` `## Check 1. Config exists` to `preflight.md` `## Check 4. Default branch up to date`, then `preflight.md` `## Check 6. superpowers major version (warn only)`. Check 2 uses its fresh form. The first failing check stops with its message, having written nothing; the warnings are kept for the final report. Check 5 runs in Step 3.

## Step 3. Select the issues

In order:

1. `gh-milestone.sh select <m>`, with a title written as a double-quoted literal, its `"`, `$`, backtick and `\` escaped with a backslash. A non-zero exit stops with `aew ship-milestone: could not list milestone "<m>": <first stderr line>`. A warning on stderr is printed as `Warning: <text>` and kept for the final report.
2. `issues` empty: stop with `aew ship-milestone: milestone "<m>" has no open issues.` Do this before reading `milestone`, which may be null.
3. `test -e .aew/runs/m-<mn> && echo exists || echo absent`. On `exists`, stop with `Run m-<mn> already exists: continue it with /aew:resume m-<mn>.`
4. `preflight.md` `## Check 5. No other active run`, reading `<n>` as `<mid>`. Its "this issue" branch cannot arise after the previous check.

## Step 4. Choose the mode

No flag given: `mode-selection.md` `## The script's recommendation`, `mode-selection.md` `## Judgement`, `mode-selection.md` `## Rationale` and `mode-selection.md` `## Ask`. An unanswered question goes to `mode-selection.md` `## No answer`.

A flag given: `mode-selection.md` `## Mode given`.

Then, either way, `mode-selection.md` `## Cycles and stack conflicts`. Every stop in this step has written nothing.

## Step 5. Start the run

Nothing has been written yet, and the values in `## Run variables` are known. `mode` `bulk` goes to `bulk.md` `## Start`; `mode` `sequential` goes to `sequential.md` `## Start`. Writes begin there.

## Milestone report

Reached from `bulk.md` and `sequential.md`, and from `sequential.md` `## Resume`, when the parent run has ended. The parent `<mrd>/state.json` status must be final (`done`, `blocked` or `failed`) and, in sequential mode, no child in `<mrd>/index.json` is `running`. `current` may hold anything. A pending gate is not an exit: it stops as `ship/SKILL.md` `## Gate pending` does, with no report.

Compute each issue's outcome once, for both reports. Every command below prints its outcome and is written so it can be pre-approved.

- Parent: `jq -r '.mode, .status, (.issues | map(tostring) | join(" "))' <mrd>/state.json`.
- Sequential only: `jq -r '.children[] | "\(.issue) \(.status)"' <mrd>/index.json`.
- Per state file `<file>`: `jq -r '.stage, .pr' <file>` and `jq -r '[.history[] | select(.status == "blocked" or .status == "failed")] | last | .note // "no reason recorded"' <file>`.

| Mode | Source | shipped | blocked or failed | not started |
|---|---|---|---|---|
| bulk | `<mrd>/state.json`, one status for every issue; the PR from `<mrd>/issues/<first issue>/issue.json` | status `done` | status `blocked` or `failed`: the `.stage`, and the reason from the latest blocked or failed history note | never |
| sequential | `<mrd>/index.json` child status, then `.aew/runs/<k>/state.json`; the PR from `.aew/runs/<k>/issue.json` | `done` | `blocked` or `failed`, as for bulk but from the child's `state.json` | `pending` |

The PR URL is built as in `pr.md` `## Push and pull request` step 4, from the `.pr` of the state file and the `issue.json` named in the table.

Manual tests outstanding, per shipped issue `<k>`: sequential `grep -c '^- \[ \]' .aew/runs/<k>/manual-tests.md`; bulk `grep -c '^- \[ \].*#<k>-AC-' <mrd>/manual-tests.md`, because the bulk file is shared and each case line carries its issue's prefixed AC id. `grep -c` prints 0 and exits 1 on no match, and a missing file counts 0.

Write `<mrd>/milestone-report.md` with the Write tool. First `test -f <mrd>/milestone-report.md && echo exists || echo absent`; when it exists, Read it before the Write, because the Write tool refuses to overwrite a file it has not read. The lines:

- `## aew milestone m-<mn> <title>: <done | stopped>`, with `done` only when the parent status is `done`.
- One line per issue, in the parent's order, with no issue title: `- #<k>: shipped, PR <url>` · `- #<k>: blocked at <stage>: <reason>` · `- #<k>: failed at <stage>: <reason>` · `- #<k>: not started`.
- `Manual tests outstanding: #<k>: <count>, …` over the shipped issues, or `Manual tests outstanding: none`.
- When stopped, the last line ``Resume with `/aew:resume m-<mn>`.``, except for a `failed` bulk parent, whose last line is ``Remove `.aew/runs/m-<mn>`, then rerun `/aew:ship-milestone <mn> --bulk`.``

Then post it: `gh-issue.sh comment <k> <mrd>/milestone-report.md` once for every `<k>` in the parent's `.issues`, in order. A failed post only warns, and the next one still runs: `Warning: milestone report comment on #<k> failed: <first stderr line>`.

Then go to `## Final report`.

## Final report

Printed last, for every outcome, from the outcomes computed above. Never open an artefact; the counting rules are `final-report.md` `## Counting`.

```
aew ship-milestone m-<mn> <title>: <done | stopped>
Mode: <bulk | sequential>
Shipped:
#<k> → <PR url>
Blocked:
#<k> at <stage>: <reason>
Not started: <#a, #b | none>
Manual tests outstanding: <#k: <count>, … | none>
Retro items filed: <count> in <retro.repo> (<created #a, commented #b>)
Next: <next action>
Warning: <text>
```

- `Shipped: none` and `Blocked: none` when empty. A failed issue reads `#<k> at <stage> (failed): <reason>`.
- `Next:` by outcome. Done, bulk: `review and merge the PR`. Done, sequential: `review and merge the PRs in order: #a, #b, #c` (the parent's `.issues`). A failed sequential child: `restart #<k> with /aew:ship <k> --from <stage>, then /aew:resume m-<mn>`. A `failed` bulk parent: `remove .aew/runs/m-<mn>, then rerun /aew:ship-milestone <mn> --bulk`. Any other stop: `Resume with /aew:resume m-<mn>`.
- Retro items: the `created #` and `commented #` lines `gh-retro.sh` printed this session (one call in bulk, one per child in sequential), in `retro.repo` as in `ship/references/final-report.md` `## Counting`.
- `Warning:` lines, one each: Step 2's (Check 4 ahead-only, Check 6), the `select` stderr warning, the `mode-selection.md` `## Mode given` and bulk cycle or stack-conflict warnings, failed report comments, and any the mode reference passes on.
- Each sequential child's own ship final report is printed by ship when that child ends.
