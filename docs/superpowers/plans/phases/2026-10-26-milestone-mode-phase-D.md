# Phase D plan — Sequential mode

- **Spec:** `docs/superpowers/specs/2026-10-26-milestone-mode.md` (senior APPROVED WITH NOTES · NOVEL · EPIC · hash `a1ec22d7…f4288e`).
- **Binding overrides:** `docs/superpowers/plans/phases/2026-10-26-milestone-mode-overrides.md`. These beat the spec-review notes, which beat the spec. Three of them bind this phase. **Cut 2**: AC-22 loses the doc-writer's "stacked summary line naming the base branch", so this phase makes no doc-writer change. **Phases**: D is `depends_on: [A, B]`, in wave 2 beside C. **Serialised ship edits**: this phase's ship-edit task has a cross-phase `depends_on` on Phase C's ship-edit task.
- **Phase:** D of the EPIC. `depends_on: [A, B]`. It consumes Phase A's `state.sh init` (mode `sequential`) and `state.sh index`, and Phase B's `skills/ship-milestone/SKILL.md` (the hand-off into sequential mode, the milestone report and the final report). It provides the `sequential.md` sections, the ship hook lines and the preflight Check 5 exception that Phase E's resume, status and `skills.bats` tasks and its Q1/Q2 runs rely on.
- **Depth:** full
- **ACs covered:** AC-20, AC-21, AC-22 (as amended by cut 2), AC-23, AC-24, and the sequential half of AC-25. It also writes the `sequential.md` `## Resume` section that AC-28 names. That AC is owned and verified by Phase E (see PD-D1).
- **Risk:** none of the risky criteria. The phase changes Markdown procedures only: no script, schema, hook, agent, dependency or auth change. Nothing runs live before Phase E's Q1/Q2.
- **Date:** 2026-10-26
- **Naming note:** "AC-n" means the spec's ACs, "Assumption n" the spec's assumptions, and "cut n" the override file's CTO cuts. The task ids are `D1` and `D2`, the interface items are `I-D1` to `I-D9`, and the plan decisions are `PD-D1` to `PD-D12`. Ship's dispatch rows keep their own names (D1 to D13, in `dispatch.md`). They are unrelated to the task ids. Wherever this plan could mean either, it writes "row D13" or "task D1".

> **For agentic workers:** implement task by task. Both tasks are documentation tasks. RED is a check that fails before the change (a grep count of 0, or a missing heading). GREEN is the same check passing, plus `jq` dry-runs of every command the new text tells the model to run, against scratch fixtures under the gitignored `tests/tmp/`. Record both outputs in the task report. The headings, notes, messages, commands and hook lines marked **verbatim** are contracts: copy them exactly. Everything else is content to write in your own words, in British English, under the rules in ship's `SKILL.md` `## Rules` (pre-approvable commands, printed checks, no `$VAR`, no `$(…)`).

**Goal:** a sequential milestone run. It runs ship's own single-issue procedure once per open issue, in dependency order, and stacks each child's branch and PR on its dependency's branch. It stops cleanly when a child ends `blocked` or `failed`, and it can be resumed. Nothing in ship's pipeline is copied.

**Architecture:** one new reference, `skills/ship-milestone/references/sequential.md`. It holds the sequence loop: start, next child, start a child (ship's `## Step 3. Start the run` with three substitutions), the parent and dependency lookups, after a child, stop, finish, and resume. The loop is model-driven, never a shell loop. Its only memory is `index.json` (owned by `state.sh index`) and the history notes, re-read at every step. ship gains six single-line hooks in `SKILL.md` and one exception in `preflight.md` Check 5. They send a `sequential-child` run back to `sequential.md` where ship would otherwise stop. No other file changes. `gh-pr.sh create` already uses `base_branch` as the PR base, row D9 already diffs against it, and the doc-writer already writes the stacked introduction from `stacked_on`.

**Tech stack:** Markdown skill files. bash 3.2, jq 1.7.1 and the plugin scripts for the inline commands. bats for the existing suite. `claude plugin validate .`.

## Context manifest (only what this phase reads)

| File | Why |
|---|---|
| `docs/superpowers/plans/phases/2026-10-26-milestone-mode-overrides.md` | Cut 2 (no doc-writer change), the phase graph, the serialised ship edits |
| `docs/superpowers/specs/2026-10-26-milestone-mode.md` | AC-20 to AC-25, AC-28 (the `## Resume` text), Assumptions 6, 8, 10, 11, 12 and 13, Risks 1, 3 and 5, and the `## Approval` notes (state.sh init never checks `current`; `git-branch.sh create --base` resolves a local branch; `gh-pr.sh create` and row D9 read `base_branch`) |
| `skills/ship/SKILL.md` (255 lines at `b7ffbe7`) | The hook points: `## Run variables` line 44, `## References` table lines 80–87, `## Step 3. Start the run` lines 122–133 (3.2 init, 3.3/3.4 stop, 3.7 branch), `## Stage: docs` step 3 line 222, `## Gate pending` lines 234–238, `## Blocked path` step 6 line 249, `## Final report` line 255 |
| `skills/ship/references/preflight.md` | `## Check 5. No other active run` (lines 54–60): the AC-24 exception |
| `skills/ship/references/gates.md` `## Gate: plan-approval` | The Stop answer goes to `SKILL.md` `## Final report` with outcome `failed`, so the Final report hook covers it and `gates.md` needs no edit |
| `skills/ship/references/pr.md` `## Finish` | `current clear` happens before the child's final report, so `## After a child` sets `current` again |
| `skills/ship/references/routing.md` `## Script failures` | `git-branch.sh create` failing at 3.7 goes to the blocked path. Q1/Q2 rely on this to force child 3 `blocked` |
| `skills/ship/references/dispatch.md` field notes | `stacked_on` (row D13) and `base` (row D9) are already documented. No edit |
| `skills/resume/SKILL.md` `## Step 4. Checks`, `## Step 5. Continue` | `sequential.md` `## Resume` runs these with the child's id |
| `agents/doc-writer.md` lines 27 and 84 | The stacked introduction already exists (cut 2) |
| `scripts/state.sh --help`, `scripts/git-branch.sh --help`, `scripts/gh-pr.sh` `run_state` | `init` sets `current`, `base_branch` = default and `branch` null. `set base_branch` exists. `create <k> <slug> --base <b>` stacks. `create <id>` takes the base from `base_branch` |
| `tests/scripts/skills.bats` | Test 256 (every `${CLAUDE_PLUGIN_ROOT}/…` path exists), the citation resolver (line 450; it maps only ship's own file names today), tests 17 and 18 (`preapprovable_offenders`, which scan ship's `SKILL.md` and references) |
| `tests/scripts/gh-pr.bats` "`--base, base_branch fallback and --draft`", `tests/scripts/git-branch.bats` "`create: --base branches from another feature branch (stacked)`" | The existing proof of AC-22's script side |
| `docs/superpowers/plans/phases/2026-10-25-orchestrator-and-entry-skills-phase-B.md` | Format analog |

Gotchas that apply (`docs/superpowers/project-map.md`):

- `${CLAUDE_PLUGIN_ROOT}` is substituted only in a loaded `SKILL.md` body. `sequential.md` is always read with Read, so it restates the root rule.
- A false `test` is silent to the model, so every check prints its outcome (test 18).
- No `$VAR` outside single quotes, no `$(…)`, and `jq --arg` comes after the filter with a plain-token value (test 17).
- The Write tool refuses to overwrite a file it has not read. Task D1 may find a placeholder `sequential.md` left by Phase B (PD-D10).
- zsh breaks `echo =====` and has no `declare -F`, so run the multi-line checks below with `bash`.
- bats `! cmd` that is not the last line never fails.

## Interface contract

### I-D1. `skills/ship-milestone/references/sequential.md` headings, in this order (verbatim; each occurs exactly once; provided by task D1)

```
# Sequential mode
## Start
## Next child
## Start a child
## Parent and dependency of a child
## After a child
## Stop the sequence
## Finish the sequence
## Resume
```

- `## Start` is the **only** entry from Phase B (I-D2). `## After a child` and `## Parent and dependency of a child` are the only targets of ship's hooks (I-D5). `## Resume` is the only entry from Phase E's `resume` (I-D7).
- The file has no line matching `^## Stage:` or `^## Gate:`, and no dispatch-table row (`^\| D[0-9]+ \|`). It has no gate steps of its own (AC-25). Phase E's `skills.bats` no-copy check can grep for exactly these.
- Its first paragraph restates the plugin-root rule. Read every literal `${CLAUDE_PLUGIN_ROOT}` in the file as the plugin root stated in the skill that sent you here (`ship/SKILL.md`, `ship-milestone/SKILL.md` or `resume/SKILL.md`).

### I-D2. Consumed from Phase B: the hand-off into `## Start`

Phase B's `skills/ship-milestone/SKILL.md` goes to `` `sequential.md` `## Start` `` once the mode is `sequential`, with **nothing written yet**, after it has done all of this:

- parsed the arguments (AC-10);
- run preflight checks 1–4 and 6, `gh-milestone.sh select`, and Check 5 with the run id `<mid>` (AC-11);
- stopped on no open issues, or on an existing `<mrd>` (AC-11);
- stopped on a non-null `cycle` or a non-empty `stack_conflicts` (AC-13).

It hands over these values, held in context (Risk 4: `select` runs once):

- `<mn>` (`milestone.number`), with `<mid>` = `m-<mn>` and `<mrd>` = `.aew/runs/<mid>` (phase-B B-4 `## Run variables`; R-D3);
- the milestone title, from `milestone.title`;
- `auto`, true when `--auto` was given;
- the `select` output's `order` and each open issue's `stack_on`.

`sequential.md` never calls `select` again. After `## Start`, every value comes from `<mrd>/state.json` and `index.json`.

### I-D3. Consumed from Phase A (as AC-6 and AC-7 specify)

- `state.sh init <mid> --issues <a,b,c> --mode sequential --title "<t>" [--auto]` creates the parent with `branch` null and stage `spec_analysis`, and sets `current` to `<mid>` (no subdirs: those are bulk only).
- `state.sh index init <mid> [--stack-on <k>:<dep>,…]` and `state.sh index set <mid> <issue> <pending|running|done|blocked|failed>`. Both take an explicit run id, so they work whatever `current` holds.
- `<mrd>/index.json` is `{run_id, order, children: [{issue, stack_on, status}]}`:
  - `issue` is a JSON number, and `stack_on` is a JSON number or `null`;
  - `children` is in `order` order.

  The commands in I-D6 were dry-run against exactly this shape. If Phase A writes numbers as strings, task D1 changes `($k | tonumber)` to `$k` and records it.

### I-D4. Consumed from Phase B: the shared reports (AC-26, AC-27)

`sequential.md` cites these two sections. It does not restate them.

- `` `ship-milestone/SKILL.md` `## Milestone report` ``. It writes `<mrd>/milestone-report.md`, posts it on every issue of the run, and **ends by running `## Final report` itself** (phase-B B-8), so `sequential.md` never cites `## Final report` directly. The outcome (`done` or `stopped`) is derived by B from the parent's status, which must be final (`done` or `blocked`) with no index entry `running` before the call.
- `` `ship-milestone/SKILL.md` `## Final report` ``, reached only through the milestone report. It is printed last.

Both read the parent with `jq` (not `state.sh get`), because `current` may hold anything (B-8); `## Finish the sequence` clears it before the milestone report. They take each child's line from `index.json` and that child's `state.json`. **If Phase B names these headings differently**, task D1 uses B's names (B is committed before D starts) and records the change in its report.

### I-D5. Ship hook lines (provided by task D2; Phase E's checks and the consolidator rely on them)

All of these are in `skills/ship/SKILL.md` and are **verbatim**. Each one is a single line, and each is either a new line or a single-line change to an existing step:

| Id | Where | Change |
|---|---|---|
| H1 | — | **Dropped at plan review.** Phase C's C5 hook H-2 already adds a `mode` bullet to `## Run variables` (`state.sh get mode`); a second `mode` entry would duplicate it. The hooks below rely on C's bullet. |
| H2 | `## References` table, a new last row | the row in the block below the table |
| H3 | `## Step 3. Start the run`, a new paragraph after the 3.8 bullet | ``Milestone child: in a `sequential-child` run, a stop at 3.3 or 3.4 prints its message, then goes to `sequential.md` `## After a child` instead of stopping.`` |
| H4 | `## Stage: docs` step 3 | `3. Dispatch row D13.` becomes ``3. Dispatch row D13. A `sequential-child` run adds `stacked_on: <dep>` when `sequential.md` `## Parent and dependency of a child` gives a dependency.`` |
| H5 | `## Gate pending`, a new last paragraph | ``Milestone child: a `sequential-child` run stops here too, and its milestone index entry stays `running`. After the `Answer with` line, also print `Or continue the whole milestone with /aew:resume m-<p>`, where `m-<p>` is its parent from `sequential.md` `## Parent and dependency of a child`.`` |
| H6 | `## Blocked path` step 6 | ``6. Go to `## Final report`, then stop.`` becomes ``6. Go to `## Final report`, then stop (a `sequential-child` run is handed back there instead of stopping).`` |
| H7 | `## Final report`, a new last paragraph | ``Milestone child: when `mode` is `sequential-child` (read it with `jq -r .mode .aew/runs/<id>/state.json`, because `current` may be cleared), print the report, then go to `sequential.md` `## After a child` instead of stopping. This covers `done`, the blocked path and the plan-gate stop.`` |

H2, the new `## References` row (verbatim):

```
| `${CLAUDE_PLUGIN_ROOT}/skills/ship-milestone/references/sequential.md` | a milestone child (`mode` `sequential-child`): its parent and dependency, and the hand-back when it ends | Step 3, docs, Gate pending, Blocked path, Final report |
```

The plan-gate Stop (`gates.md`) and every blocked route (`routing.md`) already end in `SKILL.md` `## Final report`, so H6 and H7 cover them with no edit to `gates.md` or `routing.md`. No ship heading is added, removed or renamed.

### I-D6. Preflight Check 5 milestone exception (provided by task D2; Phase E's resume relies on it)

In `skills/ship/references/preflight.md` `## Check 5. No other active run`, step 3 gains one indented continuation line (**verbatim**):

```
   Milestone runs: also pass when one of `<cur>` and this run is a milestone run `m-<p>` and the other is its child. Check it with `jq -r '[.history[] | select(.note == "milestone " + $m)] | length' --arg m <mid> .aew/runs/<other>/state.json`, where `<mid>` is whichever of the two ids is `m-<p>` and `<other>` is the other one: `1` or more passes; `0`, or no output (no such `state.json`), does not.
```

- **AC-24:** `/aew:ship <k> --from <stage>` on a stopped child passes while `current` is `m-<n>`. Here `<mid>` is `m-<n>` and `<other>` is `<k>`.
- **AC-28** (Phase E): `/aew:resume m-<n>` passes while a child's gate holds `current` = `<k>`. Here `<mid>` is `m-<n>` (this run) and `<other>` is `<k>` (`<cur>`). `/aew:resume <k>` passes either way: `<cur>` is the child itself, or its parent.

The command was dry-run: it prints `1` for a child's own parent, `0` for another milestone, and nothing (jq exit 2) for a missing `state.json`.

### I-D7. `## Resume` (provided by task D1; Phase E's `resume` enters it)

E's `resume` enters `` `sequential.md` `## Resume` `` in two cases, after its own Step 1 (arguments) and Step 2 (state read):

- for a run whose `mode` is `sequential`, with `<id>` = `<mid>`;
- for a `sequential-child` id, with `<mid>` taken from the child's `milestone <mid>` note (the `## Parent and dependency of a child` step 1 command).

For the parent it skips the branch check (`branch` is null). It may run its `## Step 4. Checks` items 1–3 for the parent first; they are read-only. The section then works only from `index.json` and the child's `state.json`:

- every child is `done`: it finishes the run;
- the first child that is not `done` has no `state.json`: it starts that child;
- that child's status is `failed`: it prints `/aew:ship <k> --from <stage>` and stops;
- that child's status is `done`: it goes to `## After a child`;
- that child's status is `running`, `blocked`, `awaiting_input` or `awaiting_plan_approval`: it runs `` `resume/SKILL.md` `## Step 4. Checks` `` and `` `resume/SKILL.md` `## Step 5. Continue` `` with `<id>` = `<k>`.

**E must keep those two resume headings verbatim.** It never re-runs a finished child.

### I-D8. History notes and index transitions (provided to Phase E's status table and Q1/Q2 checks)

**History notes** (verbatim; `<k>` and `<status>` filled in):

| Note | Run | Written by |
|---|---|---|
| `milestone <mid>` | child, straight after its `state.sh init` | `## Start a child` |
| `child #<k> done` | parent, `status running` | `## After a child` |
| `child #<k> <status>: <reason>` | parent, `status blocked` | `## Stop the sequence` (AC-23) |
| `resume` | parent, `status running` | `## Resume` |
| `sequence done` | parent, `status done` | `## Finish the sequence` |

**Index transitions:**

- `pending` → `running`. `## Start a child` writes this **before** the child's `state.sh init`, and `## Resume` writes it again before continuing a child.
- `running` → `done`, `blocked` or `failed`. `## After a child` copies this from the child's own final `status`.
- A child waiting at a gate stays `running`.

**The parent run:**

- its stage stays `spec_analysis` (Assumption 10);
- its status is `running` while the sequence is live, `blocked` after a stop and `done` at the end. It is never `failed` (Assumption 13), except for the index-init failure in `## Start`;
- `current` is `<mid>` between children and after a stop, `<k>` while child `<k>` runs, and cleared after `## Finish the sequence`.

### I-D9. Citation convention in ship-milestone files, and the resolver mapping (R-C1, R-B2, R-E5)

- Inside `skills/ship-milestone/**` a skill file is always cited with its directory, never as a bare `` `SKILL.md` ``:
  - `` `ship/SKILL.md` `` means ship's `skills/ship/SKILL.md`;
  - `` `ship-milestone/SKILL.md` `` means `skills/ship-milestone/SKILL.md`;
  - `` `resume/SKILL.md` `` means `skills/resume/SKILL.md`;
  - `` `sequential.md` `` (and C's `bulk.md`, B's `mode-selection.md`) means `skills/ship-milestone/references/<file>`;
  - ship's other references keep their bare names (`preflight.md`, `gates.md`, …).
- ship's own files (the I-D5 hook lines, `preflight.md`) keep their bare `SKILL.md` for ship's own file and cite `sequential.md` bare.
- Resolver: Phase B3 maps `ship/SKILL.md`, `ship-milestone/SKILL.md` and the three reference names and scans `skills/ship-milestone`; Phase E3 adds `resume/SKILL.md`. Until E3, the `resume/SKILL.md` citations are checked by hand (Phase verification step 3).

**Not changed by this phase:** `agents/*` (cut 2), `gates.md`, `pr.md`, `final-report.md`, `dispatch.md`, `routing.md`, every script, hook and template, `state.schema.json`, and `tests/scripts/*.bats` (`skills.bats` belongs to B and E).

## Tasks

Waves (within the phase):

- **1**: D1.
- **2**: D2. It waits for D1, because test 256 needs the `sequential.md` path in H2 to exist and its citations need the I-D1 headings. It also waits for Phase C's ship-edit task (the serialised ship edits).

Commit trailer for every task, and the only one (CLAUDE.md overrides the session's model-name line): `Co-Authored-By: Claude <noreply@anthropic.com>`.

---

### Task D1 — `skills/ship-milestone/references/sequential.md`, the sequence

- **id:** D1
- **files:** `skills/ship-milestone/references/sequential.md`. This is a new file, or it replaces a placeholder that Phase B left so that its path checks stay green (PD-D10).
- **depends_on:** [] within the phase. Cross-phase: Phase B is complete (the phase-level edge). This task reads B's committed `skills/ship-milestone/SKILL.md`.
- **pattern:**
  - the section, step, command and message style of `skills/ship/references/preflight.md` and `gates.md`;
  - the `prompt` marker precedent (`state.sh stage spec_analysis --note "prompt"` straight after init) for the child note;
  - `resume`'s "Read ship's files and enter at a named section" for reusing ship's Step 3 and stage sections.

  The sequence itself has no analog in the repo (spec: NOVEL).
- **ACs:** AC-20, AC-21 (the sequence side), AC-22 (the base and `stacked_on` source), AC-23, AC-25 (no copied pipeline in ship-milestone), and the `## Resume` text for AC-28 (PD-D1)
- **Size:** about 110–170 lines. Keep it under 200.

**Step 0: align with Phase B** (read-only; record the outputs).

```sh
cd /Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
grep -n '^## ' skills/ship-milestone/SKILL.md
grep -o '`sequential.md` `## [^`]*`' skills/ship-milestone/SKILL.md | sort -u     # expect: `sequential.md` `## Start`
grep -cx '## Milestone report' skills/ship-milestone/SKILL.md                      # expect 1
grep -cx '## Final report' skills/ship-milestone/SKILL.md                          # expect 1
test -f skills/ship-milestone/references/sequential.md && echo exists || echo absent
```

If B cites a different entry heading, or names its report sections differently, use B's names here and in I-D1/I-D4, and say so in the task report. If the file `exists` (B's placeholder), Read it before writing.

**Step 1: RED.**

```sh
grep -cx '## Start a child' skills/ship-milestone/references/sequential.md 2>/dev/null || echo 0    # 0
grep -cx '## After a child' skills/ship-milestone/references/sequential.md 2>/dev/null || echo 0    # 0
```

**Step 2: write the file** with the I-D1 headings, in order. Number the steps in each section. Content per section:

- `# Sequential mode`. Write one paragraph covering these points:
  - Who reads this file: ship-milestone in sequential mode; ship, through its milestone-child hooks; and `resume`.
  - The plugin-root rule (I-D1).
  - The variables:
    - `<mid>` is the parent run id and `<mrd>` its directory `.aew/runs/<mid>` (B's `## Run variables` names; `<mn>` is the milestone number). In `## Start` they come from `select`; in `## Resume` `<mid>` is the run id resume gives; in ship's hooks it is the child's parent from `## Parent and dependency of a child` step 1;
    - `<k>` is a child's issue number, which is also its run id and, inside ship's sections, its `<id>` and `<n>`;
    - `<dep>` is a child's dependency issue.
  - The rules:
    - A child **is** a ship run. This file never restates a stage, a dispatch or a gate: it enters ship's sections by citation.
    - `index.json` is written only by `state.sh index`, and `state.json` only by `state.sh`.
    - Re-read `index.json` and the child's `state.json` at every step. Never rely on session memory: this is a long session (Risk 1).
    - The loop is driven by the model, one command per call. Never write a shell loop.
    - Commands follow `` `ship/SKILL.md` `## Rules` ``.
- `## Start` (AC-20). Entered from `ship-milestone/SKILL.md` with the I-D2 values and nothing written.
  1. For each issue `<k>` in `order`, in order, one command each: `test -e .aew/runs/<k> && echo exists || echo absent`. At the first `exists`, stop with this message (**verbatim**), having written nothing: `aew ship-milestone: run <k> already exists, so #<k> cannot start as part of <mid>. Check it with /aew:status <k>, finish or remove it, then rerun.`
  2. `state.sh init <mid> --issues <order, comma-separated, in order> --mode sequential --title "<milestone title>"`, adding `--auto` when given. The title is escaped as in ship's Rules. This sets `current` to `<mid>`. The parent's `branch` stays null for the whole run.
  3. `state.sh index init <mid> --stack-on <k>:<dep>,<k>:<dep>`. Give one `<k>:<dep>` pair for each open issue whose `stack_on` is not null, in `order`. Leave out `--stack-on` when there are none.
     - On a non-zero exit: run `state.sh status failed --note "index init failed: <first stderr line>"`, then `state.sh current clear`, then print `aew ship-milestone: could not write the index for <mid>: <reason>. Remove <mrd>, then rerun.` and stop.
  4. Go to `## Next child`.
- `## Next child`.
  1. `jq -r '[.children[] | select(.status != "done")] | if length == 0 then "none" else (first | "\(.issue) \(.status)") end' <mrd>/index.json` (**verbatim**). It prints `none`, or `<k> <status>`.
  2. `none`: go to `## Finish the sequence`. `<k> pending`: go to `## Start a child`. Any other status can only follow a resume: go to `## Resume` step 2.
- `## Start a child` (AC-21; the three substitutions are the contract). `current` is `<mid>`.
  1. `state.sh index set <mid> <k> running`.
  2. Read the parent's `auto` with `jq -r .auto <mrd>/state.json`. Read the dependency with `## Parent and dependency of a child` step 2. For a stacked child (`<dep>` not `none`), read the dependency's branch with `jq -r .branch .aew/runs/<dep>/state.json`.
  3. If ship's `${CLAUDE_PLUGIN_ROOT}/skills/ship/SKILL.md` has not been read in this session, Read it. Skip ship's Step 1 and Step 2, because the parent ran them. Then follow `` `ship/SKILL.md` `## Step 3. Start the run` `` from 3.1, with `<n>` = `<k>`. Make exactly these three substitutions:
     - **3.2:** `state.sh init <k> --issues <k> --mode sequential-child`, adding `--auto` when the parent's `auto` is `true`. Then, straight after it and before the fetch: `state.sh stage spec_analysis --note "milestone <mid>"` (**verbatim** note; the parent link, Assumption 6).
     - **3.7, stacked child only:** `git-branch.sh create <k> <slug> --base <dependency branch>` (the slug as in 3.7), then `state.sh set branch <name>`, then `state.sh set base_branch <dependency branch>`. A child with no dependency runs 3.7 unchanged, so it starts from the default branch.
     - **The rest, unchanged:** 3.1 and 3.3–3.6 run as ship writes them. So does 3.8, which goes into `` `ship/SKILL.md` `## Stage: spec_analysis` `` step 2, and every stage section after it.
  4. The child is now an ordinary ship run:
     - its PR base and its review base follow from `base_branch` (`gh-pr.sh create` and row D9);
     - its plan gate applies unless `auto`;
     - ship's milestone-child hooks bring it back to `## After a child` when it ends, or stop the session at an unanswered gate.

     Write nothing else here.
- `## Parent and dependency of a child` (AC-22; used by `## Start a child` and by ship's H4 and H5).
  1. Parent: `jq -r '[.history[] | select((.note // "") | test("^milestone m-[1-9][0-9]*$"))] | if length == 0 then "none" else (first | .note | ltrimstr("milestone ")) end' .aew/runs/<k>/state.json` (**verbatim**). It prints `<mid>`, or `none` for a run that is not a milestone child. In that case, a hook that gets `none` does what ship says, as for a single run.
  2. Dependency: `jq -r '.children[] | select(.issue == ($k | tonumber)) | .stack_on // "none"' --arg k <k> <mrd>/index.json` (**verbatim**). It prints `<dep>` or `none`.
  3. The three uses:
     - the `--base` and `base_branch` of `## Start a child`;
     - `stacked_on: <dep>` on row D13 (ship's docs hook), from which the doc-writer writes the stacked introduction (this PR builds on the PR for issue #`<dep>` and must be merged after it), with `check-pr-intro.sh` run as ship runs it;
     - the parent id in ship's `## Gate pending` line.
  4. One sentence: stacking is decided without a `gh` call (Assumption 11). A dependency that was closed at selection is not in `stack_on`.
- `## After a child` (AC-21, AC-23). Reached from ship's `## Final report` (`done`, the blocked path, the plan-gate stop) and from ship's Step 3.3/3.4 stop. `<k>` is the child that just ended.
  1. The parent `<mid>`, from `## Parent and dependency of a child` step 1.
  2. `jq -r .status .aew/runs/<k>/state.json`. It is expected to be `done`, `blocked` or `failed`. Any other status means the child is still in progress: print `Child #<k> is <status>: continue it with /aew:resume <k>.` and stop, having written nothing.
  3. `state.sh index set <mid> <k> <status>`.
  4. `state.sh current set <mid>`.
  5. `done`: `state.sh status running --note "child #<k> done"`, then go to `## Next child`. `blocked` or `failed`: go to `## Stop the sequence`.
- `## Stop the sequence` (AC-23). `current` is `<mid>`.
  1. The reason: `jq -r '.history | last | .note // "no reason recorded"' .aew/runs/<k>/state.json`.
  2. `state.sh status blocked --note "child #<k> <status>: <reason>"` (**verbatim** format; the reason on one line, escaped as in ship's Rules).
  3. `` `ship-milestone/SKILL.md` `## Milestone report` `` (outcome `stopped`; it ends with ship-milestone's final report, I-D4).
  4. Stop.
     - `current` stays `<mid>`, and the parent is `blocked`, never `failed` (Assumption 13).
     - Later children get no state, branch or label.
     - The final report's `Next:` line comes from B's section: `/aew:resume <mid>` for a blocked child, or `/aew:ship <k> --from <stage>` for a failed child.
- `## Finish the sequence`.
  1. `state.sh status done --note "sequence done"`.
  2. `state.sh current clear`.
  3. `` `ship-milestone/SKILL.md` `## Milestone report` `` (outcome `done`; it ends with ship-milestone's final report, I-D4). After the clear, reads use `jq -r .<field> <mrd>/state.json`.
- `## Resume` (the I-D7 text; AC-28's sequential bullets). Entered from `resume` with `<mid>`. Decide first, then write.
  1. Run `## Next child` step 1. `none`: `state.sh current set <mid>`, then go to `## Finish the sequence`.
  2. `<k>`: `test -f .aew/runs/<k>/state.json && echo yes || echo no`. `no` (a pending child, or one marked `running` before its init): `state.sh current set <mid>`, then `state.sh status running --note "resume"`, then go to `## Start a child`.
  3. Otherwise `jq -r '[.status, .stage] | @tsv' .aew/runs/<k>/state.json`:
     - `failed`: print `Child #<k> failed at <stage>: restart it with /aew:ship <k> --from <stage>. It hands back to milestone run <mid> when it finishes.` (**verbatim**), then stop, having written nothing.
     - `done`: go to `## After a child` (the index fell behind the child).
     - `running`, `blocked`, `awaiting_input` or `awaiting_plan_approval`:
       1. follow `` `resume/SKILL.md` `## Step 4. Checks` `` with `<id>` = `<k>` (read-only: Check 5, the tree check and the branch check). A failing check stops there, having written nothing to the parent;
       2. `state.sh current set <mid>`;
       3. `state.sh status running --note "resume"`;
       4. `state.sh index set <mid> <k> running`;
       5. follow `` `resume/SKILL.md` `## Step 5. Continue` `` with `<id>` = `<k>`. It does `current set <k>`, then the gate re-ask or the stage entry.

       From there, ship's hooks hand the child back to `## After a child`.
  4. One closing line: resume never re-runs a `done` child, and the parent itself has no branch to check.

**Step 3: GREEN** (run with `bash`).

```sh
cd /Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
f=skills/ship-milestone/references/sequential.md
awk '/^```/{b=!b;next} !b && /^(# |## )/' "$f"        # exactly the I-D1 list, in order
grep -cE '^## (Stage|Gate):' "$f"                       # 0
grep -cE '^\| D[0-9]+ \|' "$f"                          # 0
grep -c '\$ARGUMENTS' "$f"                              # 0
grep -c 'TODO(milestone-mode)' "$f"                     # 0 (B1's stub markers are gone; phase-B B-6)
wc -l < "$f"                                            # 110–199
for s in '--mode sequential-child' '--note "milestone <mid>"' '--base <dependency branch>' 'state.sh set base_branch <dependency branch>' 'state.sh index init <mid>' 'state.sh index set <mid> <k> running' '--mode sequential --title' 'test -e .aew/runs/<k> && echo exists || echo absent' 'child #<k> <status>: <reason>' 'child #<k> done' 'sequence done' 'stacked_on: <dep>' '`ship/SKILL.md` `## Step 3. Start the run`' '`resume/SKILL.md` `## Step 4. Checks`' '`resume/SKILL.md` `## Step 5. Continue`' '`ship-milestone/SKILL.md` `## Milestone report`' 'already exists, so #<k> cannot start as part of <mid>' 'It hands back to milestone run <mid> when it finishes.'; do printf '%s=%s\n' "$s" "$(grep -cF -- "$s" "$f")"; done
# every count >= 1
grep -cF '`SKILL.md`' "$f"                                 # 0 (I-D9, R-C1: never a bare SKILL.md)
grep -nE '\$\{CLAUDE_PLUGIN_ROOT\}/[A-Za-z0-9._/-]*[<{]' "$f"                         # no output
grep -ohE '\$\{CLAUDE_PLUGIN_ROOT\}/[A-Za-z0-9._/-]+' "$f" | sed 's/[.,]*$//' | sort -u | while read -r p; do q=${p#'${CLAUDE_PLUGIN_ROOT}/'}; [ -e "$q" ] || echo "MISSING $q"; done   # no output
# Pre-approvable and printed-check rules (tests 17/18 do not scan this file until Phase E):
mkdir -p tests/tmp && awk '/^preapprovable_offenders\(\) \{/,/^}/' tests/scripts/skills.bats > tests/tmp/pa.sh
bash -c '. tests/tmp/pa.sh; preapprovable_offenders "$PWD" skills/ship-milestone/references/sequential.md' | grep -vx 'no fenced sh block found'   # no output
```

Dry-run every `jq` command against scratch fixtures shaped as in I-D3 (copy each command out of the file as written, with the placeholders filled in):

```sh
d=tests/tmp/dseq/.aew/runs; rm -rf tests/tmp/dseq; mkdir -p "$d/m-3" "$d/12" "$d/13"
printf '%s\n' '{"run_id":"m-3","order":[12,13,14],"children":[{"issue":12,"stack_on":null,"status":"done"},{"issue":13,"stack_on":12,"status":"running"},{"issue":14,"stack_on":13,"status":"pending"}]}' > "$d/m-3/index.json"
printf '%s\n' '{"run_id":"m-3","auto":true,"branch":null,"history":[]}' > "$d/m-3/state.json"
printf '%s\n' '{"run_id":"12","mode":"sequential-child","status":"done","stage":"pr","branch":"feat/12-a","history":[{"note":"milestone m-3"}]}' > "$d/12/state.json"
printf '%s\n' '{"run_id":"13","mode":"sequential-child","status":"blocked","stage":"spec_analysis","branch":"feat/13-b","history":[{"stage":"spec_analysis"},{"note":"milestone m-3"},{"note":"git-branch.sh create failed: branch exists"}]}' > "$d/13/state.json"
cd tests/tmp/dseq
# Next child                         -> 13 running
# Parent of 13                       -> m-3
# Dependency of 13 / of 12           -> 12 / none
# Dependency branch of 12            -> feat/12-a
# Parent auto                        -> true
# Stop reason of 13                  -> git-branch.sh create failed: branch exists
# Resume status/stage of 13          -> blocked<TAB>spec_analysis
# With every child "done" in index.json, Next child -> none
cd /Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow && rm -rf tests/tmp/dseq tests/tmp/pa.sh
```

**Step 4: commit.**

```
feat(ship-milestone): add the sequential mode reference

skills/ship-milestone/references/sequential.md runs a milestone one
issue at a time in dependency order: it checks no child run exists,
initialises the parent and its index, then starts each child through
ship's own run start with three substitutions (sequential-child mode,
the milestone note, a stacked base branch) and ship's stage sections
unchanged. After each child it records the index, continues on done,
and stops the sequence cleanly on blocked or failed, with the
milestone and final reports. A Resume section continues from the
index for /aew:resume.

Co-Authored-By: Claude <noreply@anthropic.com>
```

---

### Task D2 — ship hooks and the Check 5 exception

- **id:** D2
- **files:** `skills/ship/SKILL.md`, `skills/ship/references/preflight.md`
- **depends_on:** [D1, C5]
  - **C5** is Phase C's only task that edits `skills/ship/**` (phase-C C-5: the bulk hook lines H-1 to H-13 and path overrides).
  - If Phase C numbers that task differently, the consolidator rewrites this edge to its id. It must stay one edge (overrides: serialise the ship edits).
- **pattern:** ship's own one-line routing sentences (`## Stage: brief` step 5, `## Step 2. Preflight`) and the Check 5 step layout in `preflight.md`.
- **ACs:** AC-21 (the hand-back points: Step 3.3/3.4, Final report, Blocked path, the plan-gate stop through Final report, Gate pending), AC-22 (`stacked_on` on row D13), AC-24, AC-25 (the sequential hook lines: docs, Final report, Blocked path, Gate pending; single lines only)

**Step 0: rebase on C's text.** Phase C5 adds lines in `## Run variables` (H-2, the `mode` bullet), `## Blocked path` (H-4) and `## Final report` (H-5); D's H5–H7 paragraphs go **after** C's in the same sections (phase-C C-5). Apply each edit to the text as it stands after C5, so that the I-D5 and I-D6 wording lands unchanged. If C changed the exact old string of H4 or H6, change only the token named in I-D5. Record the before and after lines in the task report.

```sh
cd /Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
grep -n '^## ' skills/ship/SKILL.md > tests/tmp/ship-headings-before.txt
wc -l < skills/ship/SKILL.md
```

**Step 1: RED.**

```sh
grep -c 'sequential-child' skills/ship/SKILL.md                                          # 0
grep -cF 'select(.note == "milestone " + $m)' skills/ship/references/preflight.md        # 0
```

**Step 2: edit.** Make H2 to H7 exactly as in I-D5 (H1 is dropped) and the Check 5 line exactly as in I-D6. Use Edit with exact old strings. Each of H3, H5 and H7 is a new paragraph with a blank line before it. The Check 5 line goes straight after step 3, indented three spaces, so steps 4 and 5 keep their numbers. Nothing else changes.

**Step 3: GREEN** (run with `bash`).

```sh
f=skills/ship/SKILL.md
grep -c 'sequential-child' "$f"                                                            # 6 (H2-H7)
grep -cF '`sequential.md` `## After a child`' "$f"                                         # 2 (H3, H7)
grep -cF '`sequential.md` `## Parent and dependency of a child`' "$f"                      # 2 (H4, H5)
grep -cF '${CLAUDE_PLUGIN_ROOT}/skills/ship-milestone/references/sequential.md' "$f"       # 1 (H2)
grep -cF 'stacked_on: <dep>' "$f"                                                          # 1
grep -cF 'Or continue the whole milestone with /aew:resume m-<p>' "$f"                     # 1
grep -n '^## ' "$f" | diff tests/tmp/ship-headings-before.txt - && echo same || echo changed   # same (numbers may shift; headings identical)
git diff -U0 -- "$f" | grep -E '^-[^-]'                                                    # exactly the two old lines of H4 and H6
git diff -U0 -- "$f" | grep -cE '^\+[^+]'                                                  # 6 (one per hook, H2-H7)
wc -l < "$f"                                                                               # < 500
p=skills/ship/references/preflight.md
grep -cF 'select(.note == "milestone " + $m)' "$p"                                         # 1
grep -c '^## ' "$p"                                                                        # unchanged (7 at b7ffbe7, plus any C added)
git diff -U0 -- "$p" | grep -cE '^\+[^+]'                                                  # 1
bats tests/scripts/skills.bats                                                             # passes: test 256 (the H2 path exists), 17 and 18 (the hook commands and the Check 5 jq are pre-approvable)
tests/run-script-tests.sh                                                                  # passes
claude plugin validate .                                                                   # passes as before
```

Dry-run the Check 5 command (I-D6) against the D1 scratch fixture (re-create it as in D1 step 3):

- with `--arg m m-3` on `13/state.json` it prints `1`;
- with `--arg m m-4` it prints `0`;
- on a missing `99/state.json` it prints nothing and exits 2.

Then delete `tests/tmp/dseq` and `tests/tmp/ship-headings-before.txt`.

**Step 4: commit.**

```
feat(ship): hand sequential milestone children back to the sequence

A sequential-child run follows ship unchanged, except where ship would
stop: the run-start fetch and closed stops, the blocked path and the
final report now go to sequential.md "After a child", a pending gate
also names the milestone resume, and the docs stage passes stacked_on
for a stacked child. Preflight Check 5 lets a milestone run and its own
child pass each other, so /aew:ship <k> --from works on a stopped child
and resume reaches a child waiting at a gate.

Co-Authored-By: Claude <noreply@anthropic.com>
```

## Phase verification (after D1 and D2)

Run with `bash` from the repo root.

```sh
cd /Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
# 1. Suite and manifests.
tests/run-script-tests.sh                                       # all green, shellcheck clean (no script changed)
claude plugin validate .                                        # passes (existing warnings only)
# 2. AC-22's script side is already proven (no change in this phase):
bats -f 'base_branch fallback' tests/scripts/gh-pr.bats         # 1 test, ok
bats -f 'stacked' tests/scripts/git-branch.bats                 # 1 test, ok
# 3. Every citation into or out of sequential.md resolves (I-D9 mapping).
grep -ohE '`(ship-milestone/SKILL|ship/SKILL|resume/SKILL|SKILL|sequential|preflight|dispatch|gates|routing|pr|final-report)\.md` `## [^`]+`' skills/ship-milestone/references/sequential.md skills/ship/SKILL.md skills/ship/references/preflight.md | sort -u | sed 's/^`//; s/`$//; s/` `/|/' |
  while IFS='|' read -r file h; do
    case "$file" in
      SKILL.md|ship/SKILL.md) p=skills/ship/SKILL.md ;;
      ship-milestone/SKILL.md) p=skills/ship-milestone/SKILL.md ;;
      resume/SKILL.md) p=skills/resume/SKILL.md ;;
      sequential.md) p=skills/ship-milestone/references/sequential.md ;;
      *) p=skills/ship/references/$file ;;
    esac
    grep -qxF -- "$h" "$p" 2>/dev/null || echo "BROKEN $file -> $h"
  done                                                          # no output
# 4. Self-citations inside sequential.md resolve.
sed -E 's/`[A-Za-z/-]+\.md` `## [^`]+`//g' skills/ship-milestone/references/sequential.md | grep -oE '`## [^`]+`' | tr -d '`' | sort -u |
  while IFS= read -r h; do grep -qxF -- "$h" skills/ship-milestone/references/sequential.md || echo "BROKEN self -> $h"; done   # no output
# 5. Only the four files of this phase changed (plus the pre-existing spec, plan and project-map changes).
git status --porcelain
```

There is no paid run in this phase. The behavioural proof is Phase E's Q1/Q2 (AC-34): child 1 ships with PR base `main`, child 2 is resumed from its own recorded stage and its PR is based on child 1's branch with the stacked introduction, and child 3 is forced `blocked` at `git-branch.sh create`. The index then reads `done, done, blocked`, the parent `state.json` is `blocked`, and child 3 gets no dispatch. Phase E's M3 probe proves the hand-off up to the recommendation only.

## AC → task matrix

| AC | Task(s) | Evidence |
|---|---|---|
| AC-20: the order is `select`'s `order`; parent `state.sh init … --mode sequential --title` (+ `--auto`), then `index init --stack-on`; every child dir is `absent` before any write; `current` is `<mid>` between children | D1 (`## Start`, `## After a child` step 4) | D1 GREEN greps; I-D8 |
| AC-21: each child runs ship's Step 3 with three substitutions, then ship's stages unchanged | D1 (`## Start a child`) | D1 GREEN greps (`--mode sequential-child`, the `milestone <mid>` note, `--base`, `set base_branch`, the Step 3 citation) |
| AC-21: the index goes `running` at the start, then the child's final status | D1 (`## Start a child` step 1, `## After a child` step 3) | D1 jq dry-runs; I-D8 |
| AC-21: the Final report, blocked path and plan-gate stop hand back; so do the Step 3.3/3.4 stops (index `failed`) | D2 (H3, H6, H7) + D1 (`## After a child`) | D2 GREEN counts; I-D5 |
| AC-21: an unanswered gate stops the session, the index stays `running`, `current` stays `<k>`, and both resumes continue it | D2 (H5, the I-D6 Check 5 exception) + D1 (`## Resume`) | D2 GREEN and the Check 5 dry-run. The live proof is Phase E's |
| AC-21: the plan gate applies per child unless `--auto` | D1 (the child's `--auto` comes from the parent's `auto`) | D1 GREEN |
| AC-22: the stacked PR targets the dependency's branch and D9 diffs against it | D1 (`set base_branch`) + existing `gh-pr.sh`/row D9 behaviour | `gh-pr.bats` "`base_branch fallback`", `git-branch.bats` "stacked"; Phase E's Q2 |
| AC-22: row D13 gets `stacked_on`, the doc-writer writes the stacked introduction, and `check-pr-intro.sh` passes | D2 (H4) + D1 (`## Parent and dependency of a child`); doc-writer unchanged | D2 GREEN; Q2 (Phase E) |
| AC-22: the "summary line naming the base branch" | dropped by cut 2 | not built |
| AC-23: a `blocked` or `failed` child stops the sequence: the index records it, `current set <mid>`, `status blocked --note "child #<k> <status>: <reason>"`, the milestone report, then the final report; later children get nothing | D1 (`## After a child`, `## Stop the sequence`) | D1 GREEN greps and the stop-reason dry-run; Q2 (Phase E) |
| AC-24: Check 5 passes for a milestone's own child, and `/aew:ship <k> --from` hands back when it finishes | D2 (I-D6 + H7) | D2 Check 5 dry-run; `skills.bats` 17/18 |
| AC-25: no `## Stage:`, dispatch rows or gate steps in ship-milestone (the sequential file) | D1 | D1 GREEN (0, 0) |
| AC-25: ship gains only single-line hooks (docs, Final report, Blocked path, Gate pending for a sequential child) | D2 | `git diff -U0` counts (6 added, 2 changed) |
| AC-25: E3 wording, the bulk hooks, and the `skills.bats` check | Phases B, C and E | not here |
| AC-28: the `sequential.md` `## Resume` text | D1 | I-D7. Phase E owns the AC and wires `resume` to it |

## Decisions (flag if wrong)

- **PD-D1 `## Resume` is written here, not in Phase E.**
  - The spec's decomposition lists "resume" in D's `sequential.md` scope.
  - The overrides say C and D provide the sections that E relies on.
  - E edits `skills/resume/SKILL.md` to enter it (I-D7) and verifies AC-28.
- **PD-D2 Resume keys on the child's own `state.json` status, not the index.** The index holds the milestone-level status. The live status belongs to the child (Assumption 8), and the two can differ:
  - A child restarted with `/aew:ship <k> --from` and now waiting at a gate shows `failed` in the index but `awaiting_input` in its own state. It is continued, not refused.
  - A child whose index entry fell behind its `done` state goes to `## After a child`.
  - The spec's "a `failed` child prints `--from` and stops" holds whenever the child itself is `failed`.
- **PD-D3 Check 5 is symmetric.** It passes when either side is the milestone and the other is its child, not only when `current` is `<mid>` (AC-24's case). `/aew:resume <mid>` must pass while a child's gate holds `current` (AC-21, AC-28). Doing both in D's single `preflight.md` edit spares Phase E a second, conflicting edit to the same file.
- **PD-D4 The index entry goes `running` before the child's `state.sh init`.** A session killed between the two leaves `running` with no child `state.json`, which `## Resume` treats as not started. The reverse order would leave a child `state.json` beside a `pending` entry. That is harmless too, but it is harder to describe.
- **PD-D5 The hooks read `mode` from C5's `## Run variables` bullet (H-2; D's own H1 was dropped as a duplicate at plan review), and one `## References` row (H2) names `sequential.md`.**
  - The hooks test `mode` instead of each carrying its own `jq`. H7 adds the `jq` form because `current` is already cleared at the final report.
  - H2 gives ship its one absolute path to the file. That satisfies test 256 and the plugin-root rule when ship-milestone or `resume` Reads ship's `SKILL.md`.
  - H2 is not in AC-25's hook list, but it is one line of the same kind.
- **PD-D6 `stacked_on` comes from the index (`stack_on`), not from comparing `base_branch` with the default branch.** The doc-writer needs the dependency's **issue number**, which only the index holds.
- **PD-D7 The parent flips back to `running` on every `child #<k> done`.** So a sequence stopped at child `k` and continued by `/aew:ship <k> --from` reads `running` again, then `done` at the end. On an already-running parent it only adds a history line.
- **PD-D8 Gate pending in a child writes nothing to the parent.** The parent stays `running` and `current` stays `<k>` (AC-21). H5 adds only the extra `resume m-<p>` line.
- **PD-D9 `current` handling at the end.** On a stop, `current` stays `<mid>`, so the SessionStart hint and `/aew:status` name the milestone. On finish, it is cleared after the milestone report and before the final report, as ship's `## Finish` clears it before its own report.
- **PD-D10 A placeholder from Phase B is replaced, not merged.**
  - Phase B registers `ship-milestone` in `skills.bats`, so test 256 fails on any `${CLAUDE_PLUGIN_ROOT}/…` path that does not exist. If B therefore committed a stub `sequential.md`, task D1 Reads it and replaces it whole.
  - B's entry citation, and its report headings, win over the names in I-D1 and I-D4 (D1 step 0).
- **PD-D11 No new bats test in this phase.**
  - The deterministic parts of AC-22 are already pinned by `gh-pr.bats` and `git-branch.bats`.
  - The static checks on ship-milestone files (the no-copy check, the citation resolver, and tests 17/18 over `skills/ship-milestone/**`) are B's and E's `skills.bats` work.
  - This phase runs the same checks by hand: the extracted `preapprovable_offenders` and the citation loops.
- **PD-D12 An index-init failure marks the parent `failed` and asks for the run dir to be removed.** It cannot happen with Phase A's validated inputs from `select`. It is the only `failed` parent, and it is the cheapest honest stop: a rerun is refused while `<mrd>` exists (AC-11).

## Risks

- **Naming drift across the parallel plans.**
  - B's entry heading and report headings (I-D2, I-D4), C's task id for the serialised edge (C5, confirmed), and E's resolver mapping (I-D9) are assumed here.
  - Mitigations: D1 step 0 reads B's committed file and adopts its names; D2's edge is one line for the consolidator to rewrite; I-D9 states the mapping E must add.
- **Context growth over several pipelines in one session** (spec Risk 1). Mitigations:
  - every `sequential.md` step re-reads `index.json` and the child's `state.json`;
  - ship's sections are entered by citation, never from memory;
  - a killed session resumes from the index (Q1/Q2 prove it).
- **Leftover dirty paths between children.** Paths that ship's docs stage only warns about would make the next child's `git-branch.sh create` refuse. That goes to the child's blocked path, which stops the sequence cleanly and resumably, naming the paths. It is not auto-cleaned (ship never commits stray paths).
- **Stacked PRs after a merge** (spec Risk 3). If James merges child 1 before child 2's PR, child 2's base branch may be deleted. Resume does not re-base. This is documented, not automated.
- **The SessionStart hint for a stopped sequence says stage `spec_analysis`** (spec Risk 5, Assumption 10). This is cosmetic, and a hook change is out of scope.
- **A child dir left without `state.json`** (a crash inside `state.sh init`) would make ship's 3.1 stop the whole session with "Run <k> already exists". `state.sh init` writes the dir and `state.json` in one call, so this is not expected. It is recorded for prompt 07.

## Approval (Phase D)

- Senior architect: APPROVED WITH NOTES on 2026-10-26T09:29:12Z (plan-review, full rigour)
- Plan format: FULL · Complexity: NOVEL (phase of EPIC) · Risk lines crossed: none
- Spec: `docs/superpowers/specs/2026-10-26-milestone-mode.md` `<spec-summary>` (hash `a1ec22d7…f4288e`); overrides applied (cut 2: no doc-writer change)
- Plan dependency graph: valid. D1 → D2; cross-phase D2 ← C5 (the single serialised ship-edit edge). Wave count: 2. Max wave width: 1.
- Mechanical fixes applied at review: `sequential.md` title and entry heading aligned to phase-B B-6 (`# Sequential mode`, `## Start`); D2 edge C2 → C5; H1 dropped (duplicates C5 H-2's `mode` bullet), GREEN counts updated (6 added, 2 changed); Stop and Finish cite only `## Milestone report`, which runs `## Final report` itself (B-8), and Finish clears `current` first; `## Resume` runs resume Step 4 checks before any parent write; TODO-marker grep added to D1 GREEN.
- Ownership ruling: Phase D owns `sequential.md` `## Resume` and the symmetric preflight Check 5 exception (I-D6). Phase E owns only the routing into `## Resume` from `skills/resume/SKILL.md` and must not restate the Check 5 pass rule.
- Plan content hash (SHA-256, before this section): d8277ba37d57df2d0cc2ceb636920b4b8860f02722880d47272b331652b8fa66 (re-approved after reconciliation diff-review 2026-10-26T09:40:16Z; was 33391cc6c70c…)
