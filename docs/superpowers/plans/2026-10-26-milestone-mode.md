# Plan: milestone mode — `ship-milestone`, bulk and sequential runs (build prompt 06)  (EPIC · 5 phases)

- Spec: `docs/superpowers/specs/2026-10-26-milestone-mode.md` (senior APPROVED WITH NOTES · NOVEL · EPIC · hash `a1ec22d7…f4288e`)
- Issue: no issue (build prompt `docs/build-prompts/06-milestone-mode.md`; DESIGN.md wins on conflict)
- Phase plans below are copied verbatim from `docs/superpowers/plans/phases/2026-10-26-milestone-mode-phase-{A..E}.md`, each with its own senior approval trailer; this file is the authoritative copy. Precedence where texts disagree: **CTO conditions > Orchestrator reconciliations > Simplicity-challenge overrides > phase plan > spec.**
- Execution mode is fixed: subagent-driven only. Proceed to dw-human-review.

## Context manifest

**Reference files** (downstream agents read these first; full list and notes in the spec's §Context manifest):

- `docs/build-prompts/06-milestone-mode.md`: deliverables and acceptance criteria.
- `docs/DESIGN.md`: §7.1 run dir, §7.2 state, §8.7 doc-writer (bulk and stacked introductions), §9 orchestrator, §10 milestone mode, §11 hooks.
- `skills/ship/SKILL.md` and `references/{preflight,dispatch,gates,routing,pr,final-report}.md`: the reused procedure and every hook point.
- `skills/resume/SKILL.md`, `skills/status/SKILL.md`: the milestone stops to remove.
- `scripts/gh-milestone.sh`, `scripts/state.sh` (+ their bats): patterns for `select` and `index`. `scripts/git-branch.sh`, `scripts/gh-pr.sh`: stacking and PR base already supported.
- `agents/{brief-compiler,qa-engineer,doc-writer,spec-analyser}.md`: inputs that change (and the material/non-material rubric).
- `tests/scripts/skills.bats`, `tests/scripts/helpers/bin/gh`, `tests/agent-smoke/README.md` §9: static enforcement, mock routes, harness, launcher and ledger.
- `docs/superpowers/project-map.md`: bash 3.2 / zsh / jq gotchas.

**Platform facts (verified 2026-10-26 against code.claude.com/docs; detail in `phases/2026-10-26-milestone-mode-overrides.md`):** `disable-model-invocation: true` blocks Skill-tool invocation but allows `/aew:ship-milestone` (also in `-p`), so `resume` Reads skill files; `$ARGUMENTS` / `$N` / `$name`; `${CLAUDE_PLUGIN_ROOT}` substituted only in the loaded skill body, not in Read files nor the Bash env; AskUserQuestion main-thread only, removed under `--permission-prompts none`, 1–4 questions × 2–4 options; subagents concurrent (default cap 20), no ordering guarantee; SubagentStop carries `stop_hook_active`, `agent_type`.

## Assumptions the human should read first

The spec's "flag if wrong" defaults with the widest consequences, as amended by the cuts and reconciliations (full list: spec §Assumptions 1–19).

- **C1 (DESIGN deviation).** DESIGN §10's "5 ACs or fewer once analysed" is read as the script's quick AC-list count from the issue body, not a spec-analyser pass (the build prompt asks for "a quick read"). DESIGN §10's wording is updated and the change recorded as a deviation. **James confirms.**
- **A1/A2. Where the logic lives.** A new `gh-milestone.sh select` (reusing `issues`' `gh` call and `JQ_FILTER`) prints order, cycle, AC counts, `stack_on`, stack conflicts and the deterministic recommendation, tested in bats on the three prompt fixtures. "Same area" and "low risk" stay model judgement in `mode-selection.md` and can only turn bulk into sequential. Using `select` rather than the prompt's literal `gh-milestone.sh issues` is a recorded prompt-wording deviation.
- **A3/A11. Blocking and stacking.** A dependency blocks bulk unless it is a closed issue of this milestone. Stacking is decided without a `gh` call: a dependency shipped earlier in this run has an open PR (aew never merges), so its dependant stacks on its branch.
- **A12. Stack conflicts.** Two open dependencies that are not one chain stop a sequential run before any write, like a cycle (C2: the cycle/conflict "asks" in its stop message, not via AskUserQuestion).
- **A5. Reuse of `ship`.** `ship-milestone` follows ship's files directly; ship gains one-line hooks pointing at `bulk.md` / `sequential.md`; no shared reference file; `skills.bats` enforces no `## Stage:` sections in ship-milestone (AC-25).
- **A6/A7. No schema change.** Child-to-parent link is the history note `milestone m-<n>`; a bulk issue's spec version is the note `spec revision: #<k> v<N>`. `index.json` (`{run_id, order, children:[{issue, stack_on, status}]}`) is written only by the new `state.sh index init|set`, with no schema file. Bulk per-issue spec artefacts live in `issues/<k>/` (created by `state.sh init --mode bulk`).
- **A9 / C3. Bulk QA.** QA uses `m-<n>` as `<issue>`: evidence in `docs/qa/m-<n>/` (DESIGN §6 deviation); bulk commits end `(#a, #b, #c)`.
- **A15. Bulk manual tests** go to every issue in full (cases carry `#<k>-AC-<n>` ids).
- **A18 / R-E1. Simulated runs and budget.** Paid headless runs: M1 (bulk recommendation probe), M3 (chain → sequential, stacked order), B1 (`--bulk --auto`, one mocked PR closing three issues, at least one issue revised), Q1 (`--sequential --auto`, killed early in child 2), Q2 (`/aew:resume`, child 2 finishes as a stacked PR, child 3 forced to `blocked`). Planned caps ~$37 under a **$45 stop**. Only a probe re-run fits as a fallback; any larger fallback stops and asks James to raise the stop. **James confirms the $45 stop.**
- **Failed bulk run.** A failed or branchless bulk run is restarted with `remove .aew/runs/m-<mn>, then rerun /aew:ship-milestone <mn> --bulk` (resume treats a failed run as finished).

## Phase graph

- Phase A (depth: lean · risk: none): `gh-milestone.sh select`, `state.sh init` bulk subdirs, `state.sh index init|set`, fixtures, bats. depends_on: []
- Phase B (depth: lean · risk: none): `skills/ship-milestone/SKILL.md`, `references/mode-selection.md`, stub `bulk.md`/`sequential.md`, milestone and final reports, `skills.bats` registration, ship E3 line. depends_on: [] (written against A's `select` contract)
- Phase C (depth: full · risk: none): `references/bulk.md`, brief-compiler/qa-engineer/doc-writer bulk inputs, ship bulk hook lines (C5). depends_on: [A, B]
- Phase D (depth: full · risk: none): `references/sequential.md` (incl. `## Resume`), ship child hooks and preflight Check 5 exception (D2). depends_on: [A, B]; D2 depends_on [D1, C5]
- Phase E (depth: full · risk: spend of paid headless runs, real-GitHub isolation): `resume`, `status`, `skills.bats` no-copy check, DESIGN/run-protocol/github-ops/README docs, harness and paid runs M1, M3, B1, Q1, Q2 in README §10, CHANGELOG/CLAUDE.md/project map. depends_on: [C, D]

**Task-level waves** (paid runs strictly serial; every `skills.bats` and `tests/agent-smoke/README.md` edit serialised):

1. A1 ∥ A2 ∥ B1 ∥ B2
2. A3 ∥ B3
3. C1 ∥ C2 ∥ C3 ∥ C4 ∥ D1
4. C5
5. D2
6. E1 ∥ E4 ∥ E5 ∥ E6 ∥ E7
7. E2
8. E3
9. E8 (M1, M3)
10. E9 (B1)
11. E10 (Q1, Q2)
12. E11 (ledger and roll-up)
13. E12 (CHANGELOG, CLAUDE.md, project map)

Tasks: A 3 · B 3 · C 5 · D 2 · E 12 = 25.

## Simplicity-challenge

The CTO returned SIMPLER-PATH (small trims; core shape already close to minimal). Adopted (detail: `phases/2026-10-26-milestone-mode-overrides.md`):

1. **Simulated runs, partly adopted.** M2 dropped (the three fixture milestones are proven deterministically by `gh-milestone.bats`). M1 kept, declining that part of the cut: it is the only run where the model's "same area / low risk" judgement must leave a bulk recommendation standing, which no bats test can cover.
2. **No doc-writer stacked summary line.** The stacked introduction (`stacked_on`) and `gh-pr.sh create`'s base already cover "note it in the PR body"; Phase D makes no doc-writer change.
3. **Five phases, not six.** Old E (resume/status) folded into old F (docs and runs); B no longer waits for A (A∥B in wave 1); B registers `ship-milestone` in `skills.bats` so the suite stays green phase by phase.

Challenged and kept: `select` (milestone-level fields can't extend `issues`' array contract), `state.sh index` (state stays script-owned; `stack_on` must survive a resume), `issues/<k>/` subdirs (reuse spec-analyser and `gh-issue.sh fetch` unchanged), per-reference hook lines (drift guard under compaction), the Check 5 child exception, qa-engineer bulk `<issue>`, stack-conflict detection, Q1 kill + Q2 resume with child 3 forced `blocked`.

## Orchestrator reconciliations across phases (binding)

The five phases were planned in parallel; these cross-phase decisions were applied to the phase plans and diff-reviewed (`phases/2026-10-26-milestone-mode-reconciliations.md`).

- **R-B1 Failed bulk restart line.** Every phase prints exactly `remove .aew/runs/m-<mn>, then rerun /aew:ship-milestone <mn> --bulk`.
- **R-C1 Citations.** ship-milestone files cite `ship/SKILL.md` and `ship-milestone/SKILL.md` explicitly, never a bare `SKILL.md`; B3's resolver maps both, E3 adds `resume/SKILL.md`.
- **R-C2 `mode` in ship's Run variables** is C5's (H-2) alone.
- **R-C3 Serialised ship edits.** C5 is Phase C's only ship-edit task; D2 depends_on [D1, C5].
- **R-C4** qa-engineer puts the prefixed AC id on each `manual-tests.md` line.
- **R-D0 Headings.** `sequential.md` is `# Sequential mode` / `## Start` (same pair as `bulk.md`).
- **R-D1 Ownership.** D owns `sequential.md ## Resume` and the two-way preflight Check 5 exception; E1 only routes `resume` into `## Resume`.
- **R-D2** E records "AC-24 over AC-25" (preflight gains the Check 5 exception, not only bulk overrides) as a deviation.
- **R-D3** D uses B's names `<mn>`, `<mid>`, `<mrd>`.
- **R-D4 / R-B3** Stop and Finish cite only `## Milestone report` (which runs `## Final report`), after the parent status is set.
- **R-E1 Budget** as in the assumptions above.
- **R-E2 Revision path.** B1's issue 302 omits only a WCAG-implied accessibility clause (non-material per `agents/spec-analyser.md`, revised without a gate under `--auto`); B1's check needs at least one revised issue, else it is `open`, not passed.
- **R-E3** §10.7 records that Q runs on static-shop issues 311–313, not the chain fixture.
- **R-E4** M-8, B1-16 and Q2-14 each add a `system/init` row showing no user-connector tools (`mcp__notion`, `mcp__claude_ai_*`).

## CTO conditions (risk-gate, APPROVED WITH CONDITIONS, 2026-10-26): binding on the named tasks

- **CTO-1 (E3).** Free single-issue guard: every line that `git diff b7ffbe7 -- skills/ship` adds must name `bulk`, `sequential` or `milestone` (case-insensitive; this covers C5's H-1–H-13, D2's hooks and Check 5 line, and B3's E3 line). An unguarded added line is a defect, fixed before E8.
- **CTO-2 (E8–E10 fix loop).** After any fix commit, `tests/run-script-tests.sh` must pass and CTO-1 must be re-run before the next paid launch.
- **CTO-3 (E7).** The allowlist gains `Bash(grep -v '^$' *)` only, not `Bash(grep -v *)` (the only `grep -v` form in `skills/` and `agents/`); widen only after a recorded denial.
- **CTO-4 (E8).** No paid session starts until James has confirmed the $45 stop and C1 at human review. `$SMOKE/ledger-06/` must start empty.

**CTO notes (non-binding):** the prompt-05 rails (CTO-2 to CTO-5 of 2026-10-25) carry over through §9's `#### Launcher` reference copy; E7's free `diff` limits the copy's changes to ledger-06, the $45 stop, usage wording and the `<run-id>:<stage>` kill form, so P0 is not re-run. Blast radius is throwaway projects under `$SMOKE`; worst case is overspend, bounded by the launcher's spent-plus-cap refusal. Rollback: revert the commits.

## Commit model

Each task gets its own conventional commit on the feature branch (`feature/milestone-mode`), and the planning docs (spec, phase plans, overrides, reconciliations, this plan, project-map update) go in one commit at the start of implementation. Commit trailer: `Co-Authored-By: Claude <noreply@anthropic.com>` only (CLAUDE.md). As in prompts 02–05b, squash to one conventional commit when the PR is merged if a single commit is wanted.

---

# Phase A plan — Deterministic layer for milestones

- **Spec:** `docs/superpowers/specs/2026-10-26-milestone-mode.md` (hash `a1ec22d7…f4288e`)
- **Binding overrides:** `docs/superpowers/plans/phases/2026-10-26-milestone-mode-overrides.md`. For this phase: five-phase graph with A in wave 1 (`depends_on: []`); `select` reuses `issues`' `gh` call and `JQ_FILTER` and does not copy them (spec-review note). The CTO cuts touch no AC in 1–8.
- **Phase:** A of the EPIC. `depends_on: []`. Phase B (entry, mode selection) consumes C-1 and writes against it in parallel. Phase C (bulk) consumes C-2. Phase D (sequential) consumes C-1 (`order`, `stack_on`, `stack_conflicts`, `cycle`) and C-3. Phase E (resume, status, docs) reads C-3's file format and documents C-1 to C-3 in github-ops, run-protocol and DESIGN (C-4).
- **Depth:** lean
- **ACs covered:** AC-1, AC-2, AC-3, AC-4, AC-5, AC-6, AC-7, AC-8
- **Risk:** none. No schema change (Assumption 6), no new dependency, no new GitHub write: `select` is a read, and the only change to an existing call is one extra `--json` field.
- **Date:** 2026-10-26
- **Naming note:** "Assumption n" means the spec's assumption n. Task ids `A1`–`A3` are unrelated to those numbers or to the spec's AC numbers.

> **For agentic workers:** implement task by task, TDD. Every task records RED (the new bats tests failing against today's script) before the change and GREEN after. No paid run in this phase; everything is bats with the mocked `gh`.

**Goal:** give the milestone skills the deterministic facts they need: one `select` call that returns the open issues, their order, AC counts, stacking and a recommended mode; per-issue subdirs for a bulk run; and a script-owned `index.json` for a sequential run.

**Architecture:** one new subcommand in `scripts/gh-milestone.sh` that shares `issues`' validation, `gh` call and `JQ_FILTER` (composed inside one larger jq program), with three prompt fixtures; a few lines in `state.sh init`; one new `state.sh index` subcommand that mirrors `write_state` (validate, temp file, `mv`). New tests go in the existing `gh-milestone.bats` and `state.bats`. New files: the fixture JSON files only.

## Context manifest (only what this phase reads)

| File | Why |
|---|---|
| `scripts/gh-milestone.sh` (Usage header lines 1–16, `JQ_FILTER` lines 36–66, `cmd_issues` lines 68–83, dispatch `case` lines 85–94) | A1's edit target and pattern |
| `tests/scripts/gh-milestone.bats` (`setup`, "gh is called once with the documented arguments" line 97, "a gh failure…" line 117, "bad input is refused…" line 133, the inline `jq -n … \| gh_mock_respond issue-list -` pattern line 64) | A1's test pattern; the line-101 assertion changes |
| `tests/scripts/fixtures/milestone/{issues,expected}.json` | Raw `gh issue list` shape for the new fixtures; `expected.json` pins `issues`' output, unchanged |
| `scripts/state.sh` (Usage header lines 1–21, `write_state` lines 66–74, `cmd_init` lines 110–157, `cmd_set` validation-before-write, dispatch lines 267–283) | A2 and A3 edit targets and patterns |
| `tests/scripts/state.bats` (`st` snapshot helper, "init follows config base branch, --auto and milestone runs" line 45, "init refusals create nothing" line 58, "writes are atomic…" line 207, "AC-4: every snapshot validates…" line 263) | A2 and A3 test patterns; the snapshot test is AC-8's schema check |
| `scripts/lib/common.sh` (`is_run_id`, `run_dir [id]`, `die`, `warn`, `print_usage`) | Reused unchanged |
| `scripts/gh-issue.sh` Usage header (`fetch <n> <run-dir>` writes into the **existing** dir) | Why A2 exists; A2's integration assertion |
| `tests/scripts/helpers/common.bash` (`gh_mock_respond`, `gh_mock_issue`, `gh_call_count`, `assert_gh_called`, `setup_project`, `assert_json`) and `helpers/bin/gh` (route `issue-list`, call-specific `issue-list.<n>`) | Test helpers, unchanged |
| `docs/superpowers/project-map.md` Gotchas (bash 3.2, `set -e` in `$(…)`, empty arrays under `set -u`, bats `! cmd`) | Implementation traps |

## Interface contract (Phases B, C, D and E rely on this)

### C-1. `gh-milestone.sh select <milestone>` (A1; AC-1 to AC-5)

- **Call:** `gh-milestone.sh select <milestone>`. `<milestone>` is passed to `gh` verbatim, as for `issues`: a number or a title. The script does **not** strip `m-`; Phase B's argument parser turns `m-3` into `3` (Assumption 19).
- **Validation (before any `gh` call; exit 1, `error:` on stderr, empty stdout):** wrong argument count, empty milestone, milestone starting with `-`. Same rules and helper as `issues`.
- **`gh` call (one, shared with `issues`):** `gh issue list --milestone <m> --state all --limit 500 --json number,title,labels,state,body,blockedBy,url,milestone`. A `gh` failure exits 1 with gh's message on stderr and nothing on stdout. 500 results warns on stderr (as `issues`).
- **Stdout:** one JSON object, exit 0, also for a cycle or a stack conflict (they are data, not errors):

  | Key | Value |
  |---|---|
  | `milestone` | `{number, title}` from the first listed issue's `milestone`; `null` when the listing is empty |
  | `issues` | open issues, sorted by number, each `{number, title, labels, depends_on, ac_count, stack_on}`; `[]` when none is open, an empty listing included (confirms Phase B's B-1 assumption); `labels` and `depends_on` exactly as `issues` computes them (names; `JQ_FILTER`) |
  | `closed` | numbers of the closed issues, sorted |
  | `order` | Kahn's order of the open issues over open in-milestone edges, ties lowest number first; `null` on a cycle |
  | `cycle` | `null`, or the sorted numbers Kahn could not place (the cycle and anything downstream of it) |
  | `stack_conflicts` | `[]`, or `[{issue, deps}]` sorted by `issue`; `deps` = that issue's open in-milestone dependencies, sorted |
  | `recommend` | `"bulk"` or `"sequential"` |
  | `reasons` | `[]` exactly when `recommend` is `bulk`; otherwise strings, in the order below |

- **`ac_count` (AC-3):** body CRs removed; a null body counts as empty. The section opens at the **first** line that is an ATX heading (`#`–`######`, up to 3 spaces of indent) or a bold-only line (`**…**`, optional trailing `:`) whose text contains `acceptance criteria`, case-insensitive. It ends at the next line of either form. Count the lines in between that start, after 0–3 spaces, with `-`, `*`, `+`, `<digits>.` or `<digits>)` and a space, with or without `[ ]` / `[x]`. No section → `null`; a section with no items → `0`.
- **Blocking and stacking (AC-2, AC-4):** a dependency blocks when it is not a closed issue of this milestone (out-of-milestone ones block too; Assumption 3). Ordering and stacking use only open in-milestone dependencies. `stack_on` is `null` with none; otherwise the one latest in `order`, unless another open in-milestone dependency is not on that one's `stack_on` chain, in which case the issue goes into `stack_conflicts` and `stack_on` stays `null`. On a cycle every `stack_on` is `null` and `stack_conflicts` is `[]`.
- **`reasons`, exact strings and order:** first the count reason, either `no open issues` (0 open) or `<n> open issues (more than 5)`. Then, per open issue in number order, its AC reason, either `#<k>: no acceptance-criteria list found` (`null`) or `#<k> has <c> acceptance criteria` (`c > 5`), followed by its dependency reason `#<k> depends on #<a>, #<b>` (every blocking dependency, sorted). `recommend` is `bulk` iff `reasons` is empty.
- **Example** (chain fixture, compact): `{"milestone":{"number":4,"title":"Checkout flow"},"issues":[…],"closed":[],"order":[42,43,41],"cycle":null,"stack_conflicts":[],"recommend":"sequential","reasons":["#41 depends on #43","#43 depends on #42"]}` with `stack_on` 42 → `null`, 43 → `42`, 41 → `43`.
- **Unchanged:** `issues`' stdout, byte for byte (guarded by `expected.json`); only its `gh` call gains `milestone`.
- **Fixtures for Phase E's probes:** the three files in `tests/scripts/fixtures/milestone/` are raw `gh issue list` replies, so the smoke harness can serve them on the call-specific `issue-list.1` route (spec fact on mock collision, Risk 4). Phase B calls `select` once and keeps its output in context.

### C-2. `state.sh init … --mode bulk` subdirs (A2; AC-6)

- `state.sh init m-<n> --issues a,b,c --mode bulk [--title …] [--auto]` creates `.aew/runs/m-<n>/issues/<k>/` (empty) for each issue, before `state.json` is written, so `gh-issue.sh fetch <k> .aew/runs/m-<n>/issues/<k>` works with no `mkdir`. Every other mode creates no `issues/` dir. All validation and refusals are as today (nothing created on a refusal). No other `state.sh` behaviour changes.
- **Per-issue spec version (Phase C):** recorded with the existing `state.sh status running --note "spec revision: #<k> v<N>"`; the note is free text today, so no script change is needed. `spec_revision` stays 1 in bulk (Assumption 6).

### C-3. `state.sh index` (A3; AC-7)

```
state.sh index init <run-id> [--stack-on <k>:<dep>[,<k>:<dep>…]]
state.sh index set <run-id> <issue> <pending|running|done|blocked|failed>
```

- **Explicit run id, never `current`** (a deliberate, documented exception to "acts on `.aew/runs/current`"); neither subcommand reads or changes `current`.
- **File:** `.aew/runs/<run-id>/index.json`, owned by these two commands only:
  `{"run_id":"m-4","order":[42,43,41],"children":[{"issue":42,"stack_on":null,"status":"pending"},{"issue":43,"stack_on":42,"status":"pending"},{"issue":41,"stack_on":43,"status":"pending"}]}`
  `order` is the run's `state.json` `issues`; `children` follows `order`; `stack_on` is an issue number or `null`. No other keys. No schema file (Assumption 7).
- **`index init`:** needs the run's `state.json` with `mode` `sequential`. `--stack-on` is optional; when given its value is non-empty (`k:dep` pairs, comma-separated). Phase D omits the option when no child stacks, and builds the value from `select`'s non-null `stack_on`s.
- **`index set`:** changes one child's `status`; any status may follow any other (`failed` → `running` is how `ship --from` on a stopped child continues, AC-24). Setting the same value again is a no-op success.
- **Refusals (exit 1, `error:` on stderr, nothing written, an existing `index.json` byte-identical):** missing or invalid run id; no or unreadable `state.json`; mode other than `sequential`; `index init` when `index.json` already exists; a malformed or empty `--stack-on`, a repeated `<k>`, a `<k>` or `<dep>` not in the run, a `<dep>` not earlier in `order` than `<k>` (self included); an unknown option; `index set` with a missing or corrupt `index.json`, an issue not among `children`, or a status outside the five.
- **Stdout:** nothing on success. There is no `index get`: Phase D and E read `index.json` with Read (status runs no script).

### C-4. Not in this phase

github-ops rows (`select`, `state.sh index`), the run-protocol run-dir layout, DESIGN §7.1/§10 and the project map are Phase E's (AC-31), written from the `--help` text A1 and A3 add. No skill, agent or DESIGN file is touched here.

## Tasks

Waves: **1** = A1 ∥ A2 (no shared file). **2** = A3 (same files as A2). No cross-phase edges: nothing in this phase waits on B to E, and the C ↔ D ship-edit edge does not involve A.

---

### Task A1 — `gh-milestone.sh select` with the three prompt fixtures (AC-1 to AC-5, AC-8)

- **id:** A1
- **files:** `scripts/gh-milestone.sh`, `tests/scripts/gh-milestone.bats`, new `tests/scripts/fixtures/milestone/small-related.json`, `small-related.expected.json`, `five-one-large.json`, `chain.json`
- **depends_on:** []
- **pattern:** `cmd_issues` (validation, `gh` call, jq pass, truncation warning) and `JQ_FILTER`; the bats inline-listing pattern (`jq -n '[…]' | gh_mock_respond issue-list -`) and the whole-output pin against `expected.json`.
- **Reuse (spec-review note):** pull `cmd_issues`' argument checks and its `gh` call plus truncation warning into one shared helper that both subcommands call, adding `milestone` to `--json` there. `select`'s jq program starts from the raw list (`. as $raw`), runs `($JQ_FILTER) as $listed` (jq allows the `def`s inside the parentheses; checked with jq 1.7.1), then adds `ac_count` from `$raw`'s bodies and computes order, cycle, stacking and reasons per C-1, all in one jq pass. No copy of the filter or the call. No new library file.
- **Script edits:** `select)` arm (with `require_cmd gh jq`); Usage header (this is `--help`) gains the `select` line, the output keys, the AC-count rule, the blocking rule and the recommendation rule in a few lines each.
- **Fixtures** (raw `gh issue list` shape: `number, title, labels[{name}], state, body, blockedBy, url, milestone{number,title,description,dueOn}`, the extra milestone keys proving `{number,title}` is projected):
  - `small-related.json`: milestone 2 "Shop polish", open #21–#23, shared `shop` label, each with an AC section of ≤5 items, no dependencies. `small-related.expected.json` pins the whole `select` output (bulk, `reasons` `[]`).
  - `five-one-large.json`: milestone 3, open #31–#35, no dependencies, #33 has 8 ACs, the rest ≤5.
  - `chain.json`: milestone 4 "Checkout flow", listed as #43, #41, #42; #41 "Depends on #43" (body phrase), #43 blocked by #42 (native `blockedBy`), ACs ≤5. Order is `[42,43,41]`, so the test proves a real topological sort, not the number sort.
- **Tests (appended to `gh-milestone.bats`; each RED at first with `unknown subcommand: select`):**
  1. `select: three small related issues recommend bulk` — whole output equals `small-related.expected.json` (`jq -S`); top-level keys exactly C-1's eight; each issue's keys exactly the six.
  2. `select: five issues with one large recommend sequential with that reason` — `recommend` `sequential`, `reasons` `["#33 has 8 acceptance criteria"]`.
  3. `select: a chain listed out of order` — `order` `[42,43,41]`, `stack_on` per C-1's example, `reasons` the two dependency strings, `stack_conflicts` `[]`.
  4. `select: a cycle` — inline 1, 2→3, 3→2, 4→3 → `order` null, `cycle` `[2,3,4]`, every `stack_on` null, `stack_conflicts` `[]`.
  5. `select: stacking follows one chain or reports a conflict` — inline 1, 2, 3→{1,2} (conflict `{issue:3, deps:[1,2]}`, `stack_on` null) and 5→1, 6→{1,5} (`stack_on` 6 = 5, no conflict).
  6. `select: closed and outside-milestone dependencies` — a closed in-milestone dependency neither blocks nor stacks (in `closed`, bulk still possible); an out-of-milestone dependency blocks (`#k depends on #99`) but is not in `order` or `stack_on`.
  7. `select: acceptance-criteria counting` — table of bodies: `## Acceptance criteria`, `### Acceptance Criteria`, `**Acceptance criteria:**`; items `-`, `*`, `+`, `1.`, `2)`, `- [ ]`, `- [x]`; 3-space indent counted, 4-space and tab not; the section ends at the next heading and at the next bold-only line; only the first section counts; CRLF body; prose lines ignored; empty section `0`; no section and null body `null` with reason `#k: no acceptance-criteria list found`.
  8. `select: more than five open issues` — six small issues → `reasons` `["6 open issues (more than 5)"]`.
  9. `select: an all-closed and an empty milestone` — all closed: `issues` `[]`, `order` `[]`, `closed` sorted, `milestone` from the closed issues, `reasons` `["no open issues"]`; empty listing: `milestone` null, `issues`, `order` and `closed` `[]`, same reasons.
  10. `select: gh is called once with the documented arguments, and a title passes verbatim` — `gh_call_count` 1; the shared `--json …,url,milestone` line; `select "Sprint 4"`.
  11. `select: a gh failure prints nothing on stdout`; 12. `select: bad input is refused before any gh call` (no arg, `""`, `-x`, an extra arg; `gh_call_count` 0).
  - **Changed existing test:** "gh is called once with the documented arguments" (line 101) gains `,milestone`; at RED it still passes, after the shared-call change it must be updated in the same commit. "the whole output matches the expected fixture" must pass unchanged (`issues` stdout untouched).
- **RED:** `bats -f 'select' tests/scripts/gh-milestone.bats` → 12 tests, tests 1–11 fail on `unknown subcommand: select`; test 12 passes vacuously (every call already exits 1), record that.
- **GREEN:** `bats tests/scripts/gh-milestone.bats` all pass (the 18 existing plus 12); `scripts/gh-milestone.sh --help` shows the `select <milestone>` line; `tests/run-script-tests.sh` green and shellcheck-clean.
- **Commit:** `feat(scripts): add gh-milestone.sh select for milestone order and mode recommendation`
  trailer `Co-Authored-By: Claude <noreply@anthropic.com>`

---

### Task A2 — `state.sh init` creates bulk per-issue subdirs (AC-6, AC-8)

- **id:** A2
- **files:** `scripts/state.sh`, `tests/scripts/state.bats`
- **depends_on:** []
- **pattern:** `cmd_init`'s existing `mkdir -p "$dir"` after all validation; the `for a in ${issues//,/ }` loop already in `cmd_init`.
- **Script edits:** after `mkdir -p "$dir"` and before the temp `state.json`, when `mode` is `bulk`, `mkdir -p "$dir/issues/<k>"` for each issue (die on failure). The Usage header's `init` line gains "bulk also creates issues/<k>/ per issue".
- **Tests (in `state.bats`, using `st` so the bulk state is snapshotted for the schema test):**
  1. `init --mode bulk creates an issues/<k> dir per issue` — `st init m-3 --issues 4,5 --mode bulk --title "Sprint 3"`: `issues/4` and `issues/5` are empty dirs, nothing else under `issues/`; then `gh_mock_issue 4` and `"$SCRIPTS/gh-issue.sh" fetch 4 "$(rdir m-3)/issues/4"` succeeds and writes `issue.json` there.
  2. `init in other modes creates no issues dir` — `single`, `sequential` (`m-4`), `sequential-child` (`42`): no `issues/` in any.
  - The existing "init refusals create nothing" loop gains one bulk case (`m-9 --issues 4,4 --mode bulk`), so a refused bulk init creates no subdir.
- **RED:** `bats -f 'issues/|issues dir' tests/scripts/state.bats` → test 1 fails (`issues/4` missing); test 2 passes (record it: it guards "other modes unchanged").
- **GREEN:** `bats tests/scripts/state.bats` all pass, including "AC-4: every snapshot validates against state.schema.json"; `tests/run-script-tests.sh` green.
- **Commit:** `feat(scripts): create per-issue run subdirs in state.sh init for bulk runs`
  trailer `Co-Authored-By: Claude <noreply@anthropic.com>`

---

### Task A3 — `state.sh index init|set` (AC-7, AC-8)

- **id:** A3
- **files:** `scripts/state.sh`, `tests/scripts/state.bats`
- **depends_on:** [A2] (same two files; serialised so the worktrees do not conflict-merge)
- **pattern:** `write_state` (temp file in the run dir, `mv -f`, `TMP` cleared, the EXIT trap removes leftovers); `cmd_init`'s `--issues` regex and option loop; `cmd_set`'s "validate fully, then write" order; "invalid input leaves state.json byte-identical" and "writes are atomic and leave no temp files" tests.
- **Script edits:** `cmd_index` with `init` and `set` per C-3; `index` added to both dispatch `case`s; Usage header gains the two lines, the `index.json` format in one line, and "index acts on the run id given, not on .aew/runs/current"; the existing "All subcommands except init and `current set`" sentence gains `index` in its exception list. Suggested shape (implementer's call): validate `--stack-on` syntax in bash, then build or update the index in one jq program over `state.json` / `index.json` that `error`s on a semantic refusal, captured and turned into `die`, so a refusal never reaches the `mv`.
- **Tests (in `state.bats`):**
  1. `index init writes the order, stack_on and pending children` — `init m-4 --issues 42,43,41 --mode sequential`, then `current set` to another run, then `index init m-4 --stack-on 43:42,41:43`: `index.json` equals C-3's example (`jq -S`), keys exactly `run_id, order, children`; `current` unchanged; a second sequential run without `--stack-on` gets all `stack_on` null.
  2. `index set changes one child's status` — each of the five statuses on 43 in turn; 42 and 41 unchanged; repeat of the same value succeeds; `failed` → `running` succeeds; no `.index.json.*` temp file left.
  3. `index init refusals write nothing` — loop per C-3's list (no id, `m-x`, unknown run, `bulk`, `single`, `sequential-child` runs, existing `index.json`, `--stack-on ""`, no value, `43-42`, `43:42,43:42`, `99:42`, `43:99`, `42:43`, `42:42`, `--bogus`): each exit 1 with `error:`, `index.json` absent (or byte-identical for the "exists" case).
  4. `index set refusals leave index.json byte-identical` — status `skipped`, issue `99`, issue `x`, missing arguments, no `index.json`, a corrupt `index.json`.
  5. `--help documents index` — `state.sh --help` contains `index init <run-id>` and `index set <run-id>` and the explicit-run-id sentence.
- **RED:** `bats -f 'index' tests/scripts/state.bats` → tests 1, 2 and 5 fail (`unknown subcommand: index`; no `index` in `--help`); 3 and 4 pass vacuously at RED (record it; they keep guarding "nothing written").
- **GREEN:** `bats tests/scripts/state.bats` all pass (the snapshot schema test included); `tests/run-script-tests.sh` green and shellcheck-clean.
- **Commit:** `feat(scripts): add state.sh index to own a sequential run's index.json`
  trailer `Co-Authored-By: Claude <noreply@anthropic.com>`

## Phase verification (after A1–A3)

```sh
cd /Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
tests/run-script-tests.sh                              # all green, shellcheck clean (conventions.bats: bash 3.2, strict mode, --help)
scripts/gh-milestone.sh --help | grep -c 'select <milestone>'   # 1
scripts/state.sh --help | grep -c 'index '                      # >= 2
git diff --quiet main -- templates/state.schema.json && echo unchanged   # unchanged (AC-8, Assumption 6)
git status --porcelain     # only the A1–A3 files (plus the pre-existing spec, overrides and project-map changes)
```

## AC → task matrix

| AC | Task(s) | Evidence |
|---|---|---|
| AC-1 `select`: one `gh` call (`issues`' plus `milestone`), the eight keys; `issues` output unchanged; documented-arguments test updated | A1 | tests 1, 10; existing `expected.json` test; line-101 test |
| AC-2 blocking rule, Kahn order with lowest-first ties, out-of-milestone edges ignored for order, bulk criteria and reasons | A1 | tests 2, 3, 4, 6, 8, 9 |
| AC-3 AC-count heuristic, `null` without a section, CRLF and null bodies | A1 | test 7 |
| AC-4 `stack_on` and `stack_conflicts` | A1 | tests 3, 5 |
| AC-5 three prompt fixtures plus cycle, conflict, missing AC section, closed deps, all-closed, title, `gh` failure | A1 | tests 1–3 (fixtures), 4–12 |
| AC-6 bulk `issues/<k>/` subdirs; fetch works; other modes unchanged | A2 | A2 tests 1, 2, refusal case |
| AC-7 `state.sh index init|set`, explicit run id, atomic, every refusal, `--help` | A3 | A3 tests 1–5 |
| AC-8 bash 3.2, strict mode, shellcheck, `--help`, suite passes, schema unchanged, states validate | A1–A3 | `tests/run-script-tests.sh`; `state.bats` snapshot test; schema diff check |

## Decisions (flag if wrong)

1. **One task for all of `select`** (AC-1 to AC-5): one file and one jq program; splitting it would commit a half-built subcommand with no gain in parallelism.
2. **Reuse by composition:** `select`'s jq embeds `JQ_FILTER` and both subcommands share one validation-and-`gh` helper. `issues` keeps its jq and output.
3. **AC-section boundaries:** the "next heading" is the next ATX heading or bold-only line (the same forms that can open a section); only the **first** matching section counts, because an aew-managed body puts the current spec on top and older versions below; an empty section is `0`, not `null`; tab-indented items and fenced code get no special handling.
4. **Reason strings and order** as in C-1, with one dependency reason per issue that lists all its blocking dependencies.
5. **Zero open issues** → `sequential` with `no open issues` (bulk needs 1–5); Phase B stops on it anyway (AC-11). An empty listing gives `milestone: null`.
6. **On a cycle, no stacking is computed** (`stack_on` all null, `stack_conflicts` `[]`); a sequential run stops on the cycle first (AC-13).
7. **Cycle and conflict exit 0**: they are results for the skill to act on, not script errors.
8. **`index set` allows any transition**, and **`index init` refuses an existing `index.json`** (resume never re-initialises). **`--stack-on` must be non-empty** and is omitted when nothing stacks. **No `index get`.**
9. **Bulk subdirs are created before `state.json`**, so a run never exists without them.
10. **Fixture names** `small-related`, `five-one-large`, `chain`, and one whole-output pin (`small-related.expected.json`) as the bulk contract Phase B writes against.
11. **Docs deferred to Phase E** (C-4), so no two phases edit github-ops, run-protocol or DESIGN in parallel.

## Risks

- **Kahn's algorithm in jq** is easy to get subtly wrong (ties, downstream-of-cycle nodes). Mitigation: tests 3 and 4 use orders that differ from the number sort, and test 4 includes a node downstream of the cycle.
- **AC heuristic misses** an unusual AC format → `null` → sequential. That is the conservative direction (Assumption 4), and James confirms the mode.
- **The shared `gh` call** now asks for `milestone` from `issues` too. `gh` 2.103.2 lists `milestone` among `issue list --json` fields (checked 2026-10-26); the extra field is dropped by `JQ_FILTER`, and `expected.json` guards `issues`' output.
- **Mock collision** (spec Risk 4): `select` and `gh-retro.sh` share the `issue-list` route. Not a bats problem (one call per test); Phase E's harness serves the listing on `issue-list.1`.

## Approval (Phase A)

- Senior architect: APPROVED WITH NOTES on 2026-10-26T09:26:42Z (plan-review, lean phase)
- Plan format: LEAN
- Plan dependency graph: valid. Wave count: 2. Max wave width: 2 tasks parallel (A1 ∥ A2, then A3). No cross-phase edges.
- Cross-phase contract: C-1/C-2/C-3 match Phases B, C, D and E (field names, numeric `issue`/`stack_on`, statuses, `issues: []` on empty).
- Plan content hash (SHA-256, content above this trailer): cbfc95c1fa0e8e57c6c6d03266dcd744507b791846c1eae6bc609106ad23eb3a

---

# Phase B plan — ship-milestone entry, mode selection and the shared reports

- **Spec:** `docs/superpowers/specs/2026-10-26-milestone-mode.md` (senior APPROVED WITH NOTES · NOVEL · EPIC · hash `a1ec22d7…f4288e`).
- **Binding overrides:** `docs/superpowers/plans/phases/2026-10-26-milestone-mode-overrides.md` (overrides > spec-review notes > spec). For this phase: B is written against AC-1's `select` JSON contract and does not wait for Phase A; B also registers `ship-milestone` in `tests/scripts/skills.bats` (ENTRY list and citations) so the suite stays green phase by phase; the platform facts (V-1, V-4, path substitution) are verified and binding.
- **Phase:** B of the EPIC. `depends_on: []`. Wave 1 with Phase A. Phases C and D (wave 2) build on this phase's headings, run variables, stub references and resolver mapping; Phase E (wave 3) on its headings, verbatim strings and `skills.bats` layout.
- **Depth:** lean
- **ACs covered:** AC-9, AC-10, AC-11, AC-12, AC-13, AC-26, AC-27. Also, to keep the suite green: AC-25's E3 bullet (ship's E3 wording) and AC-30's registration part (ENTRY, citation resolver, tests 17 and 18). The rest of AC-25 is C's and D's; the rest of AC-30 (no-`## Stage:` check, resume and status citations) is E's.
- **Risk:** none. Markdown procedures plus one bats file; no script, schema, hook, agent, dependency or auth change. Nothing runs live in this phase (the M1 and M3 probes are Phase E's).
- **Date:** 2026-10-26
- **Naming note:** "AC-n" is the spec's AC n, "Assumption n" the spec's assumption n. Task ids `B1`–`B3` and decisions `BD-1`–`BD-15` are unrelated to those numbers and to the spec's simulated run "B1".

> **For agentic workers:** implement task by task. B1 and B2 are documentation tasks: RED is a check that fails before the change (the file is absent), GREEN is the same check passing. B3 is a test task: RED is the new test failing against the current tree. Copy every string marked **verbatim** in the interface contract exactly; write everything else in your own words, in British English, under ship's command rules (`skills/ship/SKILL.md` `## Rules`).

**Goal:** `/aew:ship-milestone <milestone> [--bulk|--sequential] [--auto]` parses its arguments, runs ship's preflight and `gh-milestone.sh select`, recommends and confirms a mode (or takes the flag), stops on a cycle or stack conflict in sequential mode, and hands over to `bulk.md` or `sequential.md` with nothing written. Both modes end through one shared milestone report (posted on every issue) and one final report.

**Architecture:** `skills/ship-milestone/SKILL.md` holds the procedure (entry, then the two shared exits). `references/mode-selection.md` holds the recommendation, the question and the cycle and stack-conflict stops. `references/bulk.md` and `references/sequential.md` are created here as heading-only stubs, so every citation and path resolves from this phase on; Phases C and D own their bodies. ship is reused by Read, never by the Skill tool. The only ship edit here is E3 (one line).

## Context manifest (only what this phase reads)

| File | Why |
|---|---|
| Overrides file, spec AC-9–13, 26, 27, Assumptions 2, 3, 4, 13, 14, 15, 19, Risk 4, V-1, V-4, the `## Approval` notes | The requirements and binding cuts |
| `skills/ship/SKILL.md` lines 1–36 (`## Plugin root`, `## Rules`), 38–49 (`## Run variables`), 91–114 (`## Step 1`, E1–E8), 116–120 (`## Step 2`), 234–255 (`## Gate pending`, `## Blocked path`, `## Final report`) | The patterns B1 mirrors; E3 is line 107 |
| `skills/ship/references/preflight.md` (Checks 1–6) | B1 runs Checks 1–4 and 6, then 5 with `<n>` = `<mid>`; no edit |
| `skills/ship/references/final-report.md` (`## Format`, `## Counting`, `## Blocked and failed runs`) | Pattern for B1's `## Final report`; `jq` by path, never `state.sh get`; `grep -c` exits 1 on 0 |
| `skills/ship/references/pr.md` `## Push and pull request` step 4, `## Manual tests`, `## Retro` | The PR-URL `jq` form, the manual-tests count, the retro lines B1 counts |
| `skills/prompt/SKILL.md` lines 1–40 | Pattern for a skill that Reads ship (`## Plugin root`, the citations rule, the bad-argument lines) |
| `templates/artefacts/manual-tests.md` | Case lines are `- [ ] **TC-<n> (AC-<n>):**`; in bulk the AC id is `#<k>-AC-<n>` (BD-11) |
| `scripts/gh-issue.sh --help` (`comment <n> <file>`) | The milestone-report post |
| `tests/scripts/fixtures/milestone/expected.json` | `labels` are plain strings (input to the judgement) |
| `tests/scripts/skills.bats` lines 1–10 (header, `ENTRY`), 209–287 (entry tests), 310–327 (ship bad-argument strings, E3 at 318), 450–474 (citation resolver), 476–496 (YAML list), 519–537 (tests 17 and 18) | B3's edit targets |

Gotchas that apply (`docs/superpowers/project-map.md`): `${CLAUDE_PLUGIN_ROOT}` is substituted only in the loaded `SKILL.md` body, never in a Read file nor in the Bash environment; Claude Code substitutes `$N` and `$ARGUMENTS[N]` in a loaded `SKILL.md`, so no shell or awk `$1` may appear in it; bats expands `$ARGUMENTS` in a test name to empty; a false `test` is silent, so every check prints its outcome; the Write tool refuses to overwrite a file not Read in the session; `claude plugin validate .` does not catch bad YAML (`skills.bats` does).

## Interface contract (what Phase B provides and consumes)

### B-1. Consumed from Phase A (spec contracts, not yet built)

- `gh-milestone.sh select <milestone>` (AC-1, AC-2): stdout one JSON object `{milestone: {number, title}, issues: [{number, title, labels, depends_on, ac_count, stack_on}], closed, order, cycle, stack_conflicts, recommend, reasons}`. A `gh` failure exits non-zero with nothing on stdout. A warning (the 500-result truncation) goes to stderr. **Assumed here, for A to confirm:** when no issue at all is listed, `issues` is `[]` (B stops on that before reading `milestone`, which may then be `null`).
- `state.sh init … --mode bulk` creates `<mrd>/issues/<k>/` (AC-6); bulk issues' `issue.json` lives there once Phase C fetches them.
- `index.json` format (AC-7): `{run_id, order, children: [{issue, stack_on, status}]}`, statuses `pending | running | done | blocked | failed`. B only reads it.
- B writes no state: it calls no `state.sh` write, `state.sh index`, `gh-labels.sh` or `git-branch.sh`.

### B-2. `skills/ship-milestone/SKILL.md` frontmatter (verbatim)

```yaml
---
name: ship-milestone
description: Ship a whole GitHub milestone with aew - in bulk (one combined pipeline and one PR closing every issue) or sequentially (one ship run per issue in dependency order, with stacked PRs). Run it as /aew:ship-milestone <milestone> [--bulk|--sequential] [--auto].
disable-model-invocation: true
argument-hint: "<milestone> [--bulk|--sequential] [--auto]"
---
```

No `allowed-tools`, no `` !`cmd` ``, no `$N` or `$ARGUMENTS[N]`, exactly one `$ARGUMENTS` (Step 1).

### B-3. `SKILL.md` headings, in this order (verbatim; each exactly once)

```
# aew ship-milestone
## Plugin root
## Rules
## Run variables
## References
## Step 1. Parse the arguments
## Step 2. Preflight
## Step 3. Select the issues
## Step 4. Choose the mode
## Step 5. Start the run
## Milestone report
## Final report
```

Phases C and D **do not edit** `skills/ship-milestone/SKILL.md` (B3's test pins these headings). A phase that finds it must change this file declares a cross-phase `depends_on` on the other phase's task that edits it.

### B-4. Run variables (`## Run variables`; C, D and E use these names)

- `<m>`: the milestone as parsed in Step 1 (a number, or a title with its surrounding quotes removed).
- `<mn>`: `milestone.number` from `select`. `<mid>`: `m-<mn>`. `<mrd>`: `.aew/runs/<mid>`.
- `<title>`: `milestone.title` from `select`.
- `mode` (`bulk` or `sequential`) and `auto` (true or false), from Step 1 and Step 4.
- The `select` output: printed once in Step 3 and used from the session from then on. `select` is called **once per session** (Risk 4); `bulk.md` `## Start` and `sequential.md` `## Start` take `issues`, `order` and `stack_on` from it.
- After the start, a parent field is read with `jq -r .<field> <mrd>/state.json`, never `state.sh get`, because `current` may name a child or be cleared.
- Inside each ship pipeline, `ship/SKILL.md` `## Run variables` apply; what `<id>` and `<n>` mean there is C's (bulk) and D's (child) to state.

### B-5. Citation names (`## Rules`; `skills.bats` resolves them, B3)

- In every ship-milestone file, a skill file is cited with its skill directory: `` `ship/SKILL.md` `` is ship's `skills/ship/SKILL.md`, and `` `ship-milestone/SKILL.md` `` is this skill's. A bare `` `SKILL.md` `` is never used in `skills/ship-milestone/**` (reconciliation R-C1; ship's own files keep their bare `SKILL.md` for ship's file).
- `` `preflight.md` ``, `` `dispatch.md` ``, `` `gates.md` ``, `` `routing.md` ``, `` `pr.md` ``, `` `final-report.md` `` are ship's references, cited bare.
- `` `mode-selection.md` ``, `` `bulk.md` ``, `` `sequential.md` `` are `skills/ship-milestone/references/` files, in any file (ship's hook lines in C and D cite them by these bare names).
- Form unchanged: `` `<file>.md` `## <heading>` ``.

### B-6. Reference files and their entry headings

- `references/mode-selection.md` (B2), headings verbatim and in order: `# Mode selection`, `## The script's recommendation`, `## Judgement`, `## Rationale`, `## Ask`, `## No answer`, `## Mode given`, `## Cycles and stack conflicts`.
- `references/bulk.md` (stub in B1; body Phase C): `# Bulk mode`, `## Start`. C adds any further headings.
- `references/sequential.md` (stub in B1; body Phase D): `# Sequential mode`, `## Start` (the same pair as `bulk.md`; Phase D uses these names). D adds every other heading, including `## Start a child`, `## After a child` and `## Resume` (AC-21, AC-28); the stub leaves them out so D1's RED (`grep -cx '## Start a child'` → 0) holds.
- Each stub section holds one line, the marker `<!-- TODO(milestone-mode) -->`, plus one stop sentence (`Not built yet: print "aew ship-milestone: <bulk|sequential> mode is not built yet." and stop.`). C and D replace every stub line in their file; Phase E's verification greps that `TODO(milestone-mode)` is gone.

### B-7. Hand-off into C and D (`## Step 5. Start the run`)

- On entry nothing has been written: no run dir, `current` untouched, no label, branch or `gh` write. The values in B-4 are known.
- `mode` `bulk` goes to `` `bulk.md` `## Start` ``; `sequential` goes to `` `sequential.md` `## Start` ``. From there, writes begin.
- Sequential's per-child `test -e .aew/runs/<k>` check (AC-20) is D's, at its `## Start`.

### B-8. The shared exits (C and D call these; E's resume reaches them through `sequential.md`)

- **Entry:** `` `ship-milestone/SKILL.md` `## Milestone report` ``, which ends by running `## Final report`. Precondition: the parent `<mrd>/state.json` status is final (`done`, `blocked` or `failed`) and, in sequential, the index child statuses are set (no `running`). `current` may hold anything. A pending gate is not an exit: it stops as ship's `## Gate pending` does, with no milestone report (BD-10).
- **Per-issue outcome** (computed once, used by both reports), over the parent's `.issues`:

  | Mode | Source | shipped | blocked or failed | not started |
  |---|---|---|---|---|
  | bulk | `<mrd>/state.json` (one for every issue); PR URL from `<mrd>/issues/<first issue>/issue.json` | status `done` | status `blocked` or `failed`: `.stage`, and the reason from the latest `history` note whose status is `blocked` or `failed` | never |
  | sequential | `<mrd>/index.json` child status, then `.aew/runs/<k>/state.json`; PR URL from `.aew/runs/<k>/issue.json` | `done` | `blocked` or `failed`, as for bulk but from the child's `state.json` | `pending` |

- **Milestone report** `<mrd>/milestone-report.md`, written with the Write tool (Read it first when it exists), lines verbatim in form:
  - `## aew milestone m-<mn> <title>: <done | stopped>` (`done` only when the parent status is `done`);
  - one line per issue: `- #<k>: shipped, PR <url>` · `- #<k>: blocked at <stage>: <reason>` · `- #<k>: failed at <stage>: <reason>` · `- #<k>: not started`;
  - `Manual tests outstanding: #<k>: <count>, …` over shipped issues, or `Manual tests outstanding: none`;
  - when stopped, the last line ``Resume with `/aew:resume m-<mn>`.``, except for a `failed` bulk parent, whose last line is ``Remove `.aew/runs/m-<mn>`, then rerun `/aew:ship-milestone <mn> --bulk`.`` (BD-12).
  - Posted with `gh-issue.sh comment <k> <mrd>/milestone-report.md` once for every `<k>` in the parent's `.issues`, in order. A failed post only warns: `Warning: milestone report comment on #<k> failed: <first stderr line>`.
- **Final report**, printed last, lines verbatim in form (AC-27):

  ```
  aew ship-milestone m-<mn> <title>: <done | stopped>
  Mode: <bulk | sequential>
  Shipped:
  #<k> → <PR url>
  Blocked:
  #<k> at <stage>: <reason>
  Not started: <#a, #b | none>
  Manual tests outstanding: <#k: <count>, … | none>
  Retro items filed: <count> (<created #a, commented #b>)
  Next: <next action>
  Warning: <text>
  ```

  `Shipped: none` and `Blocked: none` when empty; a failed issue reads `#<k> at <stage> (failed): <reason>`. `Next:` — done bulk: `review and merge the PR`; done sequential: `review and merge the PRs in order: #a, #b, #c` (the parent's `.issues`); a failed sequential child: `restart #<k> with /aew:ship <k> --from <stage>, then /aew:resume m-<mn>`; a `failed` bulk parent: `remove .aew/runs/m-<mn>, then rerun /aew:ship-milestone <mn> --bulk`; any other stop: `Resume with /aew:resume m-<mn>` (BD-12). Retro items: the `created #` and `commented #` lines `gh-retro.sh` printed this session (one call in bulk, one per child in sequential). Warnings: Step 2's (Check 4 ahead-only, Check 6), `select`'s stderr warning, `## Mode given` and bulk cycle or stack-conflict warnings, failed report comments, and any C or D pass on.
- Each sequential child's own ship final report is printed by ship when that child ends (D's hook); in bulk, whether ship's own final report also prints is C's call (AC-27 asks for the children's only).

### B-9. Verbatim strings (B3's test checks them; E's probes M1 and M3 read the rationale lines)

- Errors (Step 1), each followed by the usage line:
  - `aew ship-milestone: missing milestone.`
  - `aew ship-milestone: --bulk and --sequential cannot both be given.`
  - `aew ship-milestone: option "<token>" given more than once.`
  - `aew ship-milestone: unknown option "<token>".`
  - `Usage: /aew:ship-milestone <milestone> [--bulk|--sequential] [--auto]`
- Step 3 stops: `aew ship-milestone: milestone "<m>" has no open issues.` · `Run m-<mn> already exists: continue it with /aew:resume m-<mn>.` · `select` failure: `aew ship-milestone: could not list milestone "<m>": <first stderr line>`
- Rationale (mode-selection.md): first line `aew ship-milestone m-<mn> <title>: <count> open issue(s), recommended mode <bulk|sequential>.`; then one paragraph of reasons; then, when sequential is recommended, `Order: #a → #b → #c` (or `Order: none (dependency cycle)`) and `Stacked: #b on #a, …` (or `Stacked: none`); then `Closed and left out: #x, …` when `closed` is non-empty.
- Question: one AskUserQuestion, header `Mode`, options in order `<Bulk|Sequential> (recommended)`, the other mode, `Stop`.
- No answer: `Rerun with /aew:ship-milestone <mn> --<recommended> (or --<other>).` (with ` --auto` after the flag when given). `Stop` answer: `aew ship-milestone m-<mn>: stopped at the mode question; nothing was written.`
- Mode given: `Mode: <mode> (given)`; with `--bulk` against a sequential recommendation, one `Warning: <reason>; --bulk was given, so the run goes ahead in bulk.` per script reason.
- Sequential stops (AC-13): `aew ship-milestone m-<mn>: dependency cycle between #a, #b. Break one of these dependency links on GitHub, then rerun /aew:ship-milestone <mn> --sequential.` and, per conflict, `aew ship-milestone m-<mn>: #<k> depends on #a and #b, which are not one chain, so one branch cannot hold both. Add a dependency link between them (or remove one) on GitHub, then rerun /aew:ship-milestone <mn> --sequential.` Bulk warnings: `Warning: dependency cycle between #a, #b is ignored: bulk runs every issue on one branch.` and `Warning: #<k>'s stack conflict is ignored: bulk runs every issue on one branch.`
- ship E3 (B3): `- E3 `aew ship: "<token>" is a milestone; use /aew:ship-milestone <n>.`` where `<n>` is the token without `m-`.

### B-10. What Phase E relies on, and what B does not define

- `skills.bats` after B3: `ENTRY` holds `ship-milestone`; the citation test scans `skills/ship-milestone` and resolves B-5's names; tests 17 and 18 and the YAML test include `skills/ship-milestone/SKILL.md` and its references. E adds the no-`## Stage:` check (AC-25), resume and status citations, and the resume string at line 356.
- `resume` Reads `${CLAUDE_PLUGIN_ROOT}/skills/ship-milestone/SKILL.md` (`## Plugin root`, `## Rules`, `## Run variables`) and enters `` `sequential.md` `## Resume `` (D's body).
- Not defined here: the hook lines C and D add to ship's files, the bodies of `bulk.md` and `sequential.md`, and the README, resume and status "coming in a later release" lines (E).

## Tasks

Waves: **1** = B1 ∥ B2 (different files); **2** = B3. No cross-phase `depends_on`: B3's one-line ship edit precedes Phases C and D, which depend on this whole phase.

---

### Task B1 — `skills/ship-milestone/SKILL.md` and the two stub references

- **id:** B1
- **files:** `skills/ship-milestone/SKILL.md`, `skills/ship-milestone/references/bulk.md`, `skills/ship-milestone/references/sequential.md`
- **depends_on:** []
- **pattern:** `skills/ship/SKILL.md` (frontmatter, `## Plugin root`, `## Rules`, Step 1's numbered first-error-wins parse, `## Blocked path`'s Write-tool comment file) and `skills/prompt/SKILL.md` (`## Plugin root` for a skill that Reads ship; "`SKILL.md` `## Rules` (ship's) apply here, except …"); `final-report.md` for the report and its counting.
- **ACs:** AC-9, AC-10, AC-11, AC-26, AC-27 (AC-12 and AC-13 by citation into B2)
- **Content, by heading (B-3):**
  - Frontmatter per B-2. A two-sentence intro: the main-thread orchestrator for a milestone, reusing ship's procedure by Read.
  - `## Plugin root`: the root stated once; Read ship's `SKILL.md` and references and this skill's references with Read when a step says so; read every literal `${CLAUDE_PLUGIN_ROOT}` in a Read file as this root; never invoke `ship` with the Skill tool (it sets `disable-model-invocation: true`); a skill that Reads this file (`resume`) states the root itself.
  - `## Rules`: `ship/SKILL.md` `## Rules` apply. Additions: nothing is written before Step 5; `select` once per session; the files this skill writes are `milestone-report.md` only (plus what ship and the mode references write); no `## Stage:` sections, dispatch rows or gate steps here (stages are ship's); the citation names of B-5.
  - `## Run variables`: B-4.
  - `## References`: a table like ship's for `mode-selection.md` (Step 4), `bulk.md` (Step 5, bulk), `sequential.md` (Step 5, sequential), each by its absolute `${CLAUDE_PLUGIN_ROOT}/skills/ship-milestone/references/…` path; ship's `SKILL.md` and references by their absolute paths.
  - `## Step 1. Parse the arguments`: `The arguments are: $ARGUMENTS` (the only `$ARGUMENTS`). Split on whitespace; nothing runs or is written. First error wins, in order: no tokens (missing milestone); each token left to right, where `--bulk`, `--sequential`, `--auto` repeated is the repeat error and any other token starting with `--` is the unknown-option error; both `--bulk` and `--sequential` given; then join every non-`--` token with single spaces, remove one surrounding pair of matching `"` or `'`, and an empty result is the missing-milestone error. One remaining token matching `^[1-9][0-9]*$` is the number; `^m-[1-9][0-9]*$` is the number after `m-` (Assumption 19); anything else is a title. Error lines and usage per B-9. Result: `<m>`, `mode` (a flag, or none), `auto`.
  - `## Step 2. Preflight`: `preflight.md` `## Check 1. Config exists` to `preflight.md` `## Check 4. Default branch up to date`, then `preflight.md` `## Check 6. superpowers major version (warn only)`. Fresh form of Check 2. First failure stops with its message; warnings kept for the final report. Check 5 is in Step 3.
  - `## Step 3. Select the issues`, in order (BD-2, BD-3): (1) `gh-milestone.sh select <m>` (a title as a double-quoted literal, escaped per ship's rules); non-zero exit stops with the `select` failure line; a stderr warning is printed as `Warning:` and kept. (2) `issues` empty: the no-open-issues stop. (3) `test -e .aew/runs/m-<mn> && echo exists || echo absent`: `exists` is the run-exists stop. (4) `preflight.md` `## Check 5. No other active run` with `<n>` read as `<mid>`; its "this issue" branch cannot arise after (3).
  - `## Step 4. Choose the mode`: no flag: `mode-selection.md` `## The script's recommendation`, `## Judgement`, `## Rationale`, `## Ask` (unanswered goes to `## No answer`). Flag given: `mode-selection.md` `## Mode given`. Then, either way, `mode-selection.md` `## Cycles and stack conflicts`. Every stop here has written nothing.
  - `## Step 5. Start the run`: B-7.
  - `## Milestone report`: B-8 (entry precondition, the per-issue outcome table and its commands, the file and its lines, the posts). Commands, each pre-approvable and printing its outcome: `jq -r '.mode, .status, (.issues | map(tostring) | join(" "))' <mrd>/state.json`; sequential `jq -r '.children[] | "\(.issue) \(.status)"' <mrd>/index.json`; per state file `jq -r '.stage, .pr' <file>` and `jq -r '[.history[] | select(.status == "blocked" or .status == "failed")] | last | .note // "no reason recorded"' <file>`; the PR URL as in `pr.md` `## Push and pull request` step 4 against the issue.json named in B-8; manual tests: sequential `grep -c '^- \[ \]' .aew/runs/<k>/manual-tests.md`, bulk `grep -c '^- \[ \].*#<k>-AC-' <mrd>/manual-tests.md` (BD-11); `test -f <mrd>/milestone-report.md && echo exists || echo absent` before the Write. Then go to `## Final report`.
  - `## Final report`: B-8's format, `Next:` and warnings; counts from the outcomes above (never open an artefact); `grep -c` prints 0 and exits 1 on no match, and a missing file counts 0.
  - Stubs per B-6.
- **RED:** `test -e skills/ship-milestone/SKILL.md && echo exists || echo absent` → `absent` (checked 2026-10-26).
- **GREEN:**
  - `awk '/^```/{f=!f;next} !f && /^(# |## )/' skills/ship-milestone/SKILL.md` equals B-3 exactly.
  - `grep -o '\$ARGUMENTS' skills/ship-milestone/SKILL.md | wc -l` → 1; `grep -cE '\$[0-9]|\$ARGUMENTS\[' skills/ship-milestone/SKILL.md` → 0; `grep -cF '!`' skills/ship-milestone/SKILL.md` → 0.
  - `grep -cF` for each B-9 Step 1 and Step 3 string and each B-8 report line form → at least 1.
  - `grep -cF '`SKILL.md`' skills/ship-milestone/SKILL.md` → 0 (B-5: never a bare `SKILL.md`).
  - `grep -c 'TODO(milestone-mode)' skills/ship-milestone/references/bulk.md skills/ship-milestone/references/sequential.md` → 1 and 1.
  - `wc -l < skills/ship-milestone/SKILL.md` → under 500 (expected about 180).
  - `claude plugin validate .` → `✔ Validation passed` (existing warnings only); `bats tests/scripts/skills.bats` still passes (ship-milestone is not registered until B3).
- **Commit:** `feat(ship-milestone): add the entry skill with argument parsing, start order and milestone reports` with the trailer `Co-Authored-By: Claude <noreply@anthropic.com>`.

---

### Task B2 — `references/mode-selection.md`

- **id:** B2
- **files:** `skills/ship-milestone/references/mode-selection.md`
- **depends_on:** []
- **pattern:** ship's `gates.md` (asking through AskUserQuestion, and the unanswered case that `SKILL.md` `## Gate pending` prints and stops on); `preflight.md`'s header sentence for reading `${CLAUDE_PLUGIN_ROOT}` as the root stated in `ship-milestone/SKILL.md` `## Plugin root`.
- **ACs:** AC-12, AC-13
- **Content, by heading (B-6):**
  - `# Mode selection`: one line on when it is read, and that it writes nothing.
  - `## The script's recommendation`: start from `select`'s `recommend` and `reasons` (AC-2's criteria, computed by the script: count, AC counts, blocking dependencies); never recompute them.
  - `## Judgement`: only when `recommend` is `bulk`. "Same area" and "low risk", from issue titles and labels only. Each can only turn bulk into sequential, and only on a clear signal: labels or titles that name different parts of the product (for example two different `area:` labels), or a title or label that names a risky change (authentication, payments, security, data migration or schema, deleting data, infrastructure or deployment, a dependency upgrade). Missing labels or vague titles never change the recommendation (BD-7, the M1 case). Each change adds one reason, starting `judgement:`.
  - `## Rationale`: print the B-9 rationale block: the first line, one paragraph naming every reason (or why bulk fits), then the `Order:`, `Stacked:` and `Closed and left out:` lines. A cycle or stack conflict is named in the paragraph, with "sequential mode would stop here" (BD-9).
  - `## Ask`: one AskUserQuestion with one question (`How should aew run milestone m-<mn> <title>?`), header `Mode`, three options per B-9 with one-line descriptions (bulk: one branch, one pipeline, one PR closing every issue; sequential: one ship run per issue in order, stacked PRs where one builds on another). `Bulk…` and `Sequential…` set `mode`; `Stop` prints its line and stops. A free-text "Other" answer goes to `## No answer` (BD-5). `--auto` does not answer this question (BD-4). Do not try to call a tool you do not have.
  - `## No answer`: the tool is absent (headless), refused or empty: print the rerun line (B-9), then stop. Nothing has been written.
  - `## Mode given`: print `Mode: <mode> (given)`; with `--bulk` and `recommend` `sequential`, one warning per script reason (B-9). No judgement and no question (BD-8).
  - `## Cycles and stack conflicts`: sequential: a non-null `cycle` or a non-empty `stack_conflicts` prints every matching stop line (B-9), then stops, having written nothing (AC-13, conflict C2: it asks in its message, not through AskUserQuestion). Bulk: one warning each, kept for the final report, then continue.
- **RED:** `test -e skills/ship-milestone/references/mode-selection.md && echo exists || echo absent` → `absent`.
- **GREEN:** `awk '/^```/{f=!f;next} !f && /^(# |## )/'` on the file equals B-6's list; `grep -cF` → at least 1 for ` (recommended)`, `Rerun with /aew:ship-milestone`, `Mode: <mode> (given)`, `dependency cycle between`, `which are not one chain`, `Order: `, `Stacked: `, `judgement:`; `grep -cF '`SKILL.md`'` on the file → 0 (B-5); `claude plugin validate .` passes.
- **Commit:** `feat(ship-milestone): add mode selection with the recommendation question and cycle stops` with the trailer `Co-Authored-By: Claude <noreply@anthropic.com>`.

---

### Task B3 — register `ship-milestone` in `skills.bats` and point ship's E3 at it

- **id:** B3
- **files:** `tests/scripts/skills.bats`, `skills/ship/SKILL.md` (line 107 only)
- **depends_on:** [B1, B2]
- **pattern:** the existing entry-skill tests in `skills.bats`; `headings_equal` and `present` as used by the resume test (line 328 on); the citation resolver's `case` (lines 461–465).
- **ACs:** AC-9, AC-10, AC-25 (E3 bullet), AC-30 (registration part); static evidence for AC-11, AC-12, AC-26, AC-27
- **Edits to `skills.bats`:**
  1. Header comment: six entry skills. `ENTRY` gains `ship-milestone` (line 10), which brings it into the frontmatter, placeholder, path and `aew:<name>` tests.
  2. disable-model-invocation test (line 222): add `ship-milestone` to the list. Argument-hint test (line 241 loop): add `ship-milestone` with B-2's hint and exactly one `$ARGUMENTS`.
  3. `aew:<name>` test (line 276): drop the `ship-milestone` allowance from the test name and the condition (the skill now exists).
  4. ship bad-argument test (line 318): `/aew:ship-milestone (coming in a later release)` becomes `use /aew:ship-milestone <n>.`
  5. Citation test (line 450): name it "ship, ship-milestone, resume and prompt: …"; the `grep -oE` alternation gains `ship-milestone/SKILL`, `ship/SKILL`, `mode-selection`, `bulk`, `sequential`; the `case` maps `ship-milestone/SKILL.md` to `skills/ship-milestone/SKILL.md`, `ship/SKILL.md` to `skills/ship/SKILL.md` (the R-C1 citation form used in every ship-milestone file; E3 adds `resume/SKILL.md`) and the three names to `skills/ship-milestone/references/`; `find` adds `skills/ship-milestone`; require at least one citation in `skills/ship-milestone/SKILL.md` (as `ship_n` does for ship).
  6. YAML test (line 478), test 17 (line 521) and test 18 (line 531): add `ship-milestone` to the skill brace list and `skills/ship-milestone/references/*.md` to the files.
  7. One new test, `ship-milestone: headings, argument errors, mode question and report lines`: `headings_equal` on `SKILL.md` against B-3 and on `mode-selection.md` against B-6; `present` for every B-9 string except the E3 line, and for B-8's report line forms. (No `$ARGUMENTS` in the test name.)
- **Edit to `skills/ship/SKILL.md`:** E3 per B-9. Nothing else in ship changes in this phase.
- **RED:** make edit 4 and add test 7 first; `bats -f 'every bad-argument case' tests/scripts/skills.bats` fails with `missing: use /aew:ship-milestone <n>.`. Then edits 1–3, 5 and 6; negative control: rename `## Start` in the `bulk.md` stub, run `bats -f 'citation resolves' tests/scripts/skills.bats`, see it fail naming `bulk.md`, restore it. Record both outputs.
- **GREEN:** after the E3 edit, `bats tests/scripts/skills.bats` → every test passes (the existing 18 plus 1); `tests/run-script-tests.sh` → shellcheck clean and every bats file passes; `grep -c 'coming in a later release' skills/ship/SKILL.md` → 0; `git diff --stat` touches only the two files.
- **Commit:** `feat(ship): point milestone ids at /aew:ship-milestone and register it in the skill checks` with the trailer `Co-Authored-By: Claude <noreply@anthropic.com>`.

## Phase verification (after B1–B3)

```sh
cd /Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
tests/run-script-tests.sh                                   # all green, shellcheck clean
bats -f 'ship-milestone' tests/scripts/skills.bats          # the new test and the renamed citation test pass
claude plugin validate .                                    # ✔ Validation passed (existing warnings only)
wc -l skills/ship-milestone/SKILL.md                        # under 500
grep -c 'TODO(milestone-mode)' skills/ship-milestone/references/bulk.md skills/ship-milestone/references/sequential.md  # 1 and 1 (C and D remove them)
git status --porcelain                                      # only this phase's six files, plus the pre-existing spec, overrides and project-map changes
```

No paid run here: M1 and M3 (AC-32) run in Phase E against this phase's rationale lines.

## AC → task matrix

| AC | Task(s) | Evidence |
|---|---|---|
| AC-9 frontmatter, four files, under 500 lines, absolute citations, plugin root once, Read not Skill, no `$N` or `` !`cmd` ``, `$ARGUMENTS` whole | B1, B3 | B1 GREEN; B3's ENTRY, hint, placeholder, path and citation tests |
| AC-10 argument parsing, quote stripping, number forms, four errors before any write | B1, B3 | B-9 strings; B3 test 7 |
| AC-11 preflight 1–4 and 6, `select`, Check 5 with `m-<mn>`; no-open-issues and run-exists stops; nothing written before Step 5 | B1 | Step 2 and Step 3; B-9 stops |
| AC-12 recommendation from `recommend`/`reasons` plus judgement (bulk to sequential only), rationale, one question, no-answer rerun line, `Mode: <mode> (given)` and warnings | B2 (B1 Step 4) | B2 GREEN; B3 test 7 |
| AC-13 cycle or stack conflict stops sequential before any write; bulk warns | B2 | `## Cycles and stack conflicts`; B3 test 7 |
| AC-26 `milestone-report.md`, Write tool, posted on every run issue in both modes, per-issue lines, manual tests, resume line, failed post warns | B1 | `## Milestone report` per B-8 |
| AC-27 final report lines and order | B1 | `## Final report` per B-8; B3 test 7 |
| AC-25 E3 bullet | B3 | the bad-argument test |
| AC-30 registration (ENTRY, citation resolver, tests 17 and 18) | B3 | `skills.bats` green |
| AC-25 other bullets, AC-30 remainder, AC-32 | Phases C, D, E | not here |

## Decisions (flag if wrong)

- **BD-1 Stub references.** `bulk.md` and `sequential.md` are created here with their entry headings (B-6) and a marked stop line, so `SKILL.md`'s hand-off citations and paths resolve and `skills.bats` stays green; C and D own the bodies. The alternative, C and D each adding their hand-off line to `SKILL.md`, would make two wave-2 phases edit one file.
- **BD-2 Run-exists check before Check 5.** Step 3 runs `select`, the no-open-issues stop, the run-exists stop, then Check 5. AC-11's stated order of preflight, `select` and Check 5 holds. Checking the run dir first gives the right `/aew:resume m-<mn>` message and avoids editing `preflight.md` (Check 5's "this issue" message names `/aew:ship <n> --from`).
- **BD-3 The empty-milestone stop comes straight after `select`**, before any use of `milestone.number`, because `milestone` is taken from the issues and is assumed `null` when none is listed (B-1, for A to confirm).
- **BD-4 `--auto` does not answer the mode question.** It only skips plan gates (DESIGN §10); without a mode flag a headless `--auto` run stops with the rerun line.
- **BD-5 A free-text "Other" answer is treated as no answer** (rerun line, stop), rather than guessing a mode from text.
- **BD-6 The rerun line uses the milestone number** (no quoting problems with titles) and names both flags in one line.
- **BD-7 Judgement flips bulk only on a clear signal.** Missing labels or vague titles leave bulk standing, so M1 (three small related issues) stays bulk: the overrides keep M1 for exactly this.
- **BD-8 With a flag, no judgement runs.** Warnings cover the script's reasons only, and only for a forced `--bulk`.
- **BD-9 The cycle and stack-conflict check runs after the mode is fixed**, because bulk ignores both. The rationale says that sequential would stop, so James chooses knowingly.
- **BD-10 The milestone report runs only on a final parent status** (`done`, `blocked`, `failed`), not at a pending gate, which stops as ship's `## Gate pending` does. C and D place their calls to match.
- **BD-11 Bulk manual tests are counted per issue by the `#<k>-AC-` id on each case line**, while the whole file still goes to every issue (Assumption 15).
- **BD-12 `Next:` for a bulk `failed` run** (a plan-gate Stop) is `remove .aew/runs/m-<mn>, then rerun /aew:ship-milestone <mn> --bulk`, aligned with Phase C's CD-5 and Phase E's resume `failed` bulk line: resume treats a failed bulk run as finished, and the spec gives milestones no `--from`. (Review alignment, 2026-10-26.)
- **BD-13 Per-issue lines carry no issue title.** An issue that was never started has no `issue.json`, and after a resume the `select` output is no longer in the session.
- **BD-14 B registers more than the overrides name.** Besides ENTRY and the citation resolver, B3 adds ship-milestone to tests 17 and 18 and the YAML test, and makes the E3 edit with its test string, so this phase's own commands are checked and the suite is green at phase end.
- **BD-15 One new `skills.bats` test pins `SKILL.md`'s and `mode-selection.md`'s headings and B-9's strings.** It also enforces B-3's "C and D do not edit `SKILL.md` headings".

## Risks

- **Compaction between Step 3 and Step 5.** The `select` output lives only in the session. The span is short (no agent dispatch in between), and Step 5 hands over at once; C and D take what they need from it at their `## Start`.
- **Judgement drift.** The judgement is model work and could flip M1 to sequential. BD-7 states the clear-signal rule; Phase E's M1 probe is the live check.
- **Stub lines left behind.** The `TODO(milestone-mode)` marker makes leftovers greppable; Phase E's verification checks it is gone.
- **Index precondition.** If D ever reaches `## Milestone report` with a child still `running`, that issue has no row type. B-8 states the precondition; D's `## After a child` sets the index first.
- **Free-text titles in commands.** A title with `"`, `$` or a backtick must be escaped in `gh-milestone.sh select "<m>"` (ship's rule). Runs of spaces in a title collapse when tokens are joined, which may miss a milestone titled with double spaces: it then stops at the no-open-issues line, and the number form works.

## Approval (Phase B)

- Senior architect: APPROVED WITH NOTES on 2026-10-26T09:26:47Z (plan-review, lean phase)
- Plan format: LEAN
- Plan dependency graph: valid (B1, B2 → B3; no cycles, no dangling refs, no file overlap between B1 and B2). Wave count: 2. Max wave width: 2.
- Review alignment applied: `sequential.md` stub uses Phase D's `# Sequential mode` / `## Start` only; failed bulk `Next:` aligned with Phases C and E (BD-12); citation resolver also maps `ship/SKILL.md` (Phase C CD-12).
- Plan content hash (SHA-256, content above this section): a828ecdc1ab08cbb672e3dbfce519c38086220f46507d3a45facba5469422ab4 (re-approved after reconciliation diff-review 2026-10-26T09:40:16Z; was cfd441bc96bf…)

---

# Phase C plan — Bulk mode

- **Spec:** `docs/superpowers/specs/2026-10-26-milestone-mode.md` (senior APPROVED WITH NOTES · NOVEL · EPIC · hash `a1ec22d7…f4288e`).
- **Binding overrides:** `docs/superpowers/plans/phases/2026-10-26-milestone-mode-overrides.md`. Precedence: overrides > spec-review notes > spec. For this phase:
  - CTO cut 2: the only doc-writer change in the whole EPIC is this phase's bulk per-issue snapshot input. There is no stacked summary line.
  - Spec-review note: Phases C and D both add hook lines to `skills/ship/SKILL.md` and ship's references, so those edits are serialised. **All of this phase's ship edits are in one task, C5.** Phase D's ship-edit task declares `depends_on: [C5]`.
  - Spec-review note on AC-15: after one issue's spec gate is answered and re-analysed, the bulk stage moves on to the next issue still at `needs_input`, and goes to the brief only when every issue is `ok` (C1 `## Spec analysis` steps 1 to 6).
- **Phase:** C of the EPIC. `depends_on: [A, B]`. Wave 2, in parallel with D. Phase E (`depends_on: [C, D]`) consumes contracts C-1, C-3, C-4 and C-5.
- **Depth:** full
- **ACs covered:** AC-14, AC-15, AC-16, AC-17, AC-18, AC-19, and the bulk half of AC-25. The `skills.bats` check that enforces AC-25's first point is Phase E's; ship's E3 wording is Phase B's.
- **Risk:** none of the risky criteria: no schema change, no new dependency, no auth surface, no script change. The files are Markdown procedures and agent prompts. Nothing runs them live before Phase E's B1.
- **Date:** 2026-10-26
- **Naming note:** "AC-n" is the spec's AC n, "Assumption n" the spec's assumption n. Task ids are `C1`–`C5`. Dispatch rows `D1`–`D13` are ship's (`dispatch.md` `## Dispatch table`), unrelated to Phase D. Plan decisions are `CD-1`–`CD-12`. Contracts are `C-1`–`C-7`. In this plan and in `bulk.md`, `<id>` is the bulk run id `m-<number>`, `<number>` is the milestone number, and `<k>` is one issue of the run. The spec's `m-<n>` is the same thing as `<id>`. Phase B's `<mn>` (`ship-milestone/SKILL.md` `## Run variables`) is `<number>`, and `m-<mn>` is `<id>`; the two rerun lines (CD-4, CD-5) use B's names verbatim, so they match B's milestone report and E's resume line (reconciliation R-B1).

> **For agentic workers:** implement task by task. These are documentation and prompt tasks, so each task's RED is a check that fails before the change (the file is absent, or a grep count is 0) and its GREEN is the same check passing, plus the existing suite. Record both outputs in the task report. Text marked **verbatim** (headings, hook lines, note formats, commands, messages) is a contract: copy it exactly. Everything else is content to write in your own words, in British English, under ship's rules (DESIGN §3 H1–H8, M1, M2, no pipe in a condition, printed checks).

**Goal:** a bulk milestone run (`m-<number>`, mode `bulk`) that goes through ship's own stage sections once, with per-issue spec analysis in parallel, per-issue spec gates and revision records, one brief with prefixed AC ids, one standards pass, plan, build, review and QA, per-issue spec snapshots, and one PR that closes every issue, with every stage label, comment and flag applied to every issue.

**Architecture:** one new reference, `skills/ship-milestone/references/bulk.md`, holds every bulk divergence: an override table (`## Overrides`) and four procedure sections (`## Start`, `## Spec analysis`, `## Re-analysis`, `## Report`). ship's files gain only single-line hooks, each naming `bulk.md` (C5). Three agents gain bulk inputs: brief-compiler (`issues` field), qa-engineer (`<issue>` is the run id) and doc-writer (per-issue snapshots). No script, hook, template or schema changes.

**Tech stack:** Markdown skill and agent files; bash 3.2, jq 1.7.1 and grep for the inline commands; `bats`, `claude plugin validate .`.

## Context manifest (only what this phase reads)

| File | Why |
|---|---|
| `docs/superpowers/plans/phases/2026-10-26-milestone-mode-overrides.md` | Binding overrides (above) |
| `docs/superpowers/specs/2026-10-26-milestone-mode.md` | AC-14–19, AC-25, Assumptions 5, 6, 9, 15, 16, 17; C3 (evidence path) and C4 (run-dir layout); Risks 2, 4, 6, 7 |
| `skills/ship/SKILL.md` (255 lines) | Hook points: `## Rules` line 31 (one agent per call), `## Run variables` lines 40–49, `## Stage: spec_analysis` lines 147–154, `## Blocked path` lines 240–251, `## Final report` lines 253–255 |
| `skills/ship/references/dispatch.md` | `## How to dispatch` line 10 (the one-message exception), rows D1, D2, D3, D13, `## Required inputs per stage` rows `spec_analysis`, `brief`, `docs`, `## Return check`, `## Retries` |
| `skills/ship/references/gates.md` | `## Gate ids and pending state` (pending notes, the "never skip" paragraph at line 29), `## Gate: spec` step 4 (hands back to `SKILL.md` `## Stage: spec_analysis` step 4), step 4 of `plan-challenge`, `triage` and `spec-ambiguity`, `## Recording a spec revision` (render paths `.aew/runs/<id>/…`, step 5 `state.sh set spec_revision`), `## Re-asking a pending gate` |
| `skills/ship/references/pr.md` | `## Commit rules` (`(#<n>)` suffix), `## Docs and memory commits` step 1 message, `## Push and pull request` step 4 (`issue.json` URL), `## Manual tests`, `## Retro` step 1 (repo from `issue.json`), `## Finish` step 1 |
| `skills/ship/references/final-report.md` | `## Format` first line and `failed` `Next:`, `## Counting` AC grep (`^- \[x\] AC-`) |
| `agents/brief-compiler.md` | Inputs (single-issue required files, lines 26–29), numbering rule (line 45 already names `#<issue>-AC-<n>`), pipeline step 4 (`Source:` line), Return SUMMARY |
| `agents/qa-engineer.md` | Inputs line 36 (`issues[0]`), phase A H1 rule, phase B step 3 (spec file), steps 5, 13, 14 (evidence dir, `report.md`, commit), Outputs line 182 (report title) |
| `agents/doc-writer.md` | Files (run-root `spec-final.md` and `issue.json`), `## Spec snapshot`, Process step 4 (screenshot links), Outputs ("Exactly five files"), Return contract, Definition of done |
| `agents/developer.md` line 65, `agents/senior-engineer.md` line 70 | Already bulk-aware (WPs by `#<k>-AC-` prefix; prefixed coverage list). No change |
| `scripts/state.sh` (`cmd_init`, `cmd_transition`) | `init` takes `--title`; `status <s> --note` appends a history entry and keeps the stage, also when the status is unchanged (used for the per-issue revision note) |
| `scripts/gh-issue.sh`, `gh-labels.sh`, `git-branch.sh`, `gh-pr.sh` `--help` | `fetch <n> <run-dir>` needs an existing dir; `revise <n> <file> <version>`; `stage`/`flag` per issue; `create m-<n> <slug>` uses `milestone_branch_pattern`; `gh-pr.sh create <id>` closes every issue in `issues` and reads `base_branch` |
| `tests/scripts/skills.bats` | Tests that already cover ship's files and will cover `bulk.md` once Phase B adds `ship-milestone` to `ENTRY`: path existence (line 256), `aew:<name>` (276), the citation resolver (450; Phase B3 extends it to `bulk.md`, `ship/SKILL.md` and `ship-milestone/SKILL.md` and scans `skills/ship-milestone`, R-B2), tests 17 and 18 (519, 529; B3 adds `skills/ship-milestone/references/*.md`) and `preapprovable_offenders` (line 90) |
| `templates/artefacts/{brief,summary,pr-body,qa-report,qa-test-plan}.md` | H1 forms (`# Brief: #<issue> <title>` and so on) and the AC checklist line `- [x] AC-1: …` |

Gotchas that apply (from `docs/superpowers/project-map.md`): `${CLAUDE_PLUGIN_ROOT}` is substituted only in a loaded `SKILL.md`, so `bulk.md` (read with Read) states how to read it; `grep -c` exits 1 on a count of 0; the Write tool refuses to overwrite an unread file; a false `test` is silent, so every check prints its outcome; jq `--arg` goes after the filter with a plain-token value; agents with `memory: project` write `.claude/agent-memory/`, and parallel spec-analysers share one memory dir (Risk R-4).

## Plan-level decisions (refinements the spec leaves open; flag if wrong)

- **CD-1 ship's own final report is printed in bulk, then the milestone reports.** ship's `## Final report` prints its report (with the C-2 overrides: the run id in the first line, the prefixed AC count), then goes to `bulk.md` `## Report`, which runs Phase B's milestone report and final report (printed last, AC-27). This is why AC-25 gives `final-report.md` the `#<k>-AC-` count pattern, and it mirrors AC-27's rule that a sequential child's own ship report is printed too. It also keeps the AC and cycle counts, which AC-27's lines do not carry.
- **CD-2 one re-entrant spec-analysis loop, driven by files.** `bulk.md` `## Spec analysis` classifies each issue by the return block of its own `issues/<k>/01-spec-analysis.md` every time it is entered. A fresh start, a resume at `spec_analysis` (AC-15's last point) and the return from a per-issue gate all take the same path. No session memory decides which issue comes next.
- **CD-3 the per-issue spec version.** `<v_k>` is read from the history notes `spec revision: #<k> v<N>` with one `jq` command (C-2 row 7, dry-run below). With no note it is 1. `state.sh set spec_revision` is never called in bulk, so the run's `spec_revision` stays 1 (Assumption 6).
- **CD-4 a fetch failure or closed issue at bulk start** takes ship's three actions (`failed`, `current clear`, message, stop) and prints `Could not fetch issue #<k>: <reason>. Fix it, then remove .aew/runs/m-<mn>, then rerun /aew:ship-milestone <mn> --bulk.` This follows the `prompt` skill's precedent ("remove .aew/runs/<id>, then run /aew:prompt <n> again"), because a milestone has no `--from`. All fetches come before any label, so a stopped start leaves no label on any issue, and no milestone report is posted (nothing ran).
- **CD-5 the bulk `failed` `Next:` line** (only a plan-gate Stop reaches it) is `Next: remove .aew/runs/m-<mn>, then rerun /aew:ship-milestone <mn> --bulk` (R-B1: the same line as B's BD-12 and E's resume `failed` bulk line; ` --bulk` keeps the rerun from asking the mode question again).
- **CD-6 labels.** Every `gh-labels.sh stage` call runs once per issue in `issues`, in ascending order. There are two exceptions, which name one issue: the per-issue `spec` gate (`awaiting-input` on that issue) and its answer (`analysing` on that issue). The four run-wide gates (`plan-challenge`, `triage`, `spec-ambiguity`, `plan-approval`) set their label on every issue.
- **CD-7 answers from a later gate** (`bulk.md` `## Re-analysis`). A question that names `#<k>` of the run goes to issue k's D2, and a question naming several goes to each of them. A question naming none goes to every issue (AC-17). Question numbering continues per issue after `grep -c '^### Q[0-9]'` of that issue's `01-spec-analysis.md`.
- **CD-8 a `needs_input` during re-analysis** continues at `bulk.md` `## Spec analysis` step 1, whose exit is a plain `ship/SKILL.md` `## Stage: brief`. After a `spec-ambiguity` answer, that drops the non-material shortcut to `qa`, which is the safe direction (every stage from the brief re-runs).
- **CD-9 `dispatch.md` gets a hook too.** AC-25 lists `gates.md`, `preflight.md`, `pr.md` and `final-report.md` as hosts for bulk overrides. Rows D1, D2, D3 and D13 and three rows of `## Required inputs per stage` need bulk paths as well, and the spec's context manifest names them, so `dispatch.md` gains two hook lines (C5). **`preflight.md` gets no Phase C change:** Phase B owns Check 5 with the run id `m-<number>` (AC-11), and Phase D owns the child exception (AC-24).
- **CD-10 brief-compiler detects bulk by the `issues` field** (AC-16), and reads `<run_dir>/state.json` (`run_id` and `title` only) for the H1 `# Brief: m-<n> <milestone title>`. `mode: prompt` with `issues` returns `blocked`, because milestone runs have no prompt mode (spec scope, out).
- **CD-11 doc-writer reads a bulk issue's revision history from that issue's `issues/<k>/spec-revision-v<N>.md` files** (the highest N is the current version, 1 when there are none), not from the run's `spec_revision`, which stays 1 in bulk.
- **CD-12 citation form in `bulk.md`:** ship's skill file is always `ship/SKILL.md`, and ship-milestone's is always `ship-milestone/SKILL.md`. A bare `SKILL.md` is never used in `bulk.md` (or any ship-milestone file; R-C1, phase-B B-5); B3's resolver maps both explicit forms. ship's reference names (`dispatch.md`, `gates.md`, `routing.md`, `pr.md`, `final-report.md`, `preflight.md`) are cited bare: they are unique, as ship-milestone's own references are `mode-selection.md`, `bulk.md` and `sequential.md`. ship's existing files keep a bare `SKILL.md` for ship's own file and cite `bulk.md` bare (C-3).

## Interface contract

### C-1. What this phase consumes

**From Phase A** (deterministic layer):

- `state.sh init <id> --issues <a,b,c> --mode bulk --title "<t>" [--auto]` also creates `.aew/runs/<id>/issues/<k>/` for each issue (AC-6). `bulk.md` `## Start` step 1 relies on it, because `gh-issue.sh fetch` refuses a missing directory.
- `gh-milestone.sh select` JSON (AC-1). Phase C does **not** call it: Phase B calls it once and keeps the output in context (Risk 4). C uses only `milestone.number` (gives `<id>` = `m-<number>`), `milestone.title` and `issues[].number` (open issues, ascending), as handed over by B.
- C makes no use of `state.sh index` (sequential only, Phase D).

**From Phase B** (`skills/ship-milestone/SKILL.md`; the headings B must provide verbatim):

| What C needs | Expected text | Where C uses it |
|---|---|---|
| The plugin-root section (ship's rule, so `resume` can Read the file) | `## Plugin root` | `bulk.md` opening paragraph |
| The milestone report (AC-26) | `## Milestone report` | `bulk.md` `## Report` |
| The final report (AC-27) | `## Final report` | `bulk.md` `## Report` |
| The bulk hand-off, after mode selection and before any write (B has run preflight checks 1–4 and 6, `select`, Check 5 and the `.aew/runs/<id>` existence check, and printed the mode line and any forced-bulk warnings) | `` `bulk.md` `## Start` `` cited from `ship-milestone/SKILL.md`, with these values in context: `<number>`, the milestone title, the open issue numbers ascending, and `auto` | `bulk.md` `## Start` |
| `ship-milestone` registered in `tests/scripts/skills.bats` `ENTRY` (overrides, Phase B) | — | Makes the path, `aew:<name>` and frontmatter tests cover `bulk.md` as soon as C1 writes it |

If Phase B's plan names these headings differently, the consolidator changes `bulk.md` only: `## Report` and the opening paragraph are the only places C cites B. If Phase B creates a placeholder `bulk.md` so that its own citations resolve, C1 replaces the whole file (Read it first).

### C-2. `skills/ship-milestone/references/bulk.md` (C1): headings, in this order (verbatim; each exactly once)

```
# Bulk mode
## Overrides
## Start
## Spec analysis
## Re-analysis
## Report
```

- No line starts with `## Stage:`, `## Gate:` or `| D<digit>` (Phase E's AC-25 check: no stage sections, no gate steps, no dispatch-table rows). ship's sections are cited inline only.
- The `## Overrides` table header is verbatim `| Where | Single run | Bulk run |`, and its rows are numbered in the first cell (`1. …`) so that hooks and E's tests can name them. The rows, in order (content contract; wording free unless backticked):
  1. **Run variables `<n>`** (`ship/SKILL.md` `## Run variables`): the issue → each issue `<k>` of `issues`, ascending. Every `gh-labels.sh stage <n> …`, `gh-labels.sh flag <n> …`, `gh-issue.sh comment <n> …` and `gh-issue.sh manual-tests <n> …` call runs once per issue, except where a row below names one issue (rows 8 and 9).
  2. **Printed `#<n>`** (gate questions, the `plan-approval` question, `ship/SKILL.md` `## Gate pending`'s first line, the final report's first line) → the run id `<id>`, with no `#`. A per-issue spec-gate question is prefixed `#<k>: `.
  3. **D1 and D2** (`dispatch.md` `## Dispatch table`): `run_dir: .aew/runs/<id>/issues/<k>` and `spec_version: <v_k + 1>` (row 7). Required files: `issues/<k>/00-issue-original.md` and `issues/<k>/issue.json` (D2 adds `issues/<k>/01-spec-analysis.md`). `description` is `spec_analysis <id> #<k>`.
  4. **D3**: the fields are `run_dir: .aew/runs/<id>`, `mode: pipeline`, then `issues: <a,b,c>` (from `jq -r '.issues | map(tostring) | join(",")' .aew/runs/<id>/state.json`). Required files: `issues/<k>/spec-final.md` and `issues/<k>/issue.json` for every k.
  5. **D13**: required files `issues/<k>/spec-final.md` and `issues/<k>/issue.json` for every k, and `state.json`. Fields unchanged.
  6. **Required inputs per stage**: `spec_analysis` → per issue as row 3; `brief` → per issue as row 4; `docs` → per issue as row 5, plus the unchanged `08-qa-report-<fix_cycle+1>.md` rule. Other stages are unchanged (their files are at the run root).
  7. **`spec_revision`**: `state.sh get spec_revision` → `<v_k>`, from (verbatim) `jq -r '[.history[] | (.note // "") | select(startswith("spec revision: #" + $k + " v")) | ltrimstr("spec revision: #" + $k + " v") | tonumber] | max // 1' --arg k <k> .aew/runs/<id>/state.json`.
  8. **`gates.md` `## Gate: spec`**: `<rd>` is `.aew/runs/<id>/issues/<k>` and `<n>` is `k`. Step 1's note is (verbatim) `gate:spec issues/<k>/01-spec-analysis.md`, and its label goes on issue k only. Step 4's `gh-labels.sh stage <k> analysing` goes on k only, and D2 goes to k only. After the D2 return check (`dispatch.md` `## Return check`, retried once as `dispatch.md` `## Retries`), go to `bulk.md` `## Spec analysis` step 1, not `ship/SKILL.md` `## Stage: spec_analysis` step 4.
  9. **`gates.md` `## Recording a spec revision`**: for issue k, every `.aew/runs/<id>/` path in the section is `.aew/runs/<id>/issues/<k>/`, `<n>` is `k`, the version check compares `jq '.version' …` with `<v_k>` (row 7), and step 5 is (verbatim) `state.sh status running --note "spec revision: #<k> v<N>"`. The idempotency rule is unchanged: no post when the version is not greater than `<v_k>`.
  10. **The other four gates**: the pending status writes are unchanged, the label goes on every issue, and step 4 of `plan-challenge`, `triage` and `spec-ambiguity` is `bulk.md` `## Re-analysis`. `plan-approval` is unchanged apart from row 2.
  11. **`gates.md` `## Re-asking a pending gate`**: a note `gate:spec issues/<k>/01-spec-analysis.md` gives `<rd>` `.aew/runs/<id>/issues/<k>` and `<n>` `k` (Phase E's resume uses this).
  12. **`pr.md` `## Commit rules`**: the suffix `(#<n>)` → every issue, from `jq -r '.issues | map("#" + tostring) | join(", ")' .aew/runs/<id>/state.json`, for example `(#12, #13, #14)`. This also applies to the standards commit and the memory commit.
  13. **`pr.md` `## Docs and memory commits` step 1**: the message is `docs: add the issue specs<, and update CLAUDE.md> (#12, #13, #14)`. The paths rule is unchanged (every ARTEFACTS path outside `.aew/`: one `docs/specs/<k>-<slug>.md` per issue, and `CLAUDE.md`).
  14. **`issue.json`** in `pr.md` `## Push and pull request` step 4 (the PR URL) and `pr.md` `## Retro` step 1 (the repo) → `.aew/runs/<id>/issues/<first issue>/issue.json`. `gh-pr.sh create <id>` and `check-pr-intro.sh … --issues <count>` are unchanged.
  15. **`pr.md` `## Manual tests`**: the whole `manual-tests.md` goes to every issue (`gh-issue.sh manual-tests <k> …`), and every issue gets `gh-labels.sh flag <k> add manual-test-required` (Assumption 15).
  16. **`pr.md` `## Finish` step 1**: `ready-for-review` on every issue. The retro is filed once, as now.
  17. **`final-report.md`**: the first line is `aew ship <id> <title>: <done | blocked | failed>`; the AC counts are (verbatim) `grep -c '^- \[x\] #[0-9][0-9]*-AC-' .aew/runs/<id>/10-summary.md` and `grep -cE '^- \[[ x]\] #[0-9]+-AC-' .aew/runs/<id>/10-summary.md`; `failed` reads `Next: remove .aew/runs/m-<mn>, then rerun /aew:ship-milestone <mn> --bulk` (CD-5). After the report, go to `bulk.md` `## Report`.
  18. **`ship/SKILL.md` `## Blocked path`**: steps 2 (`gh-issue.sh comment <k> .aew/runs/blocked-<id>.md`) and 3 (`gh-labels.sh stage <k> blocked`) run once per issue. Step 4 runs once. A failed call for one issue never skips the others or step 4 (AC-19).
  19. **Agents, for reference** (no orchestrator action): the developer and senior-engineer are already bulk-aware; qa-engineer's `<issue>` is `<id>` (C3, evidence under `docs/qa/<id>/`, spec file `<ui.e2e_dir>/<id>-<slug>.spec.ts`); doc-writer writes one snapshot per issue (C4). The `SubagentStop` gates read `.aew/runs/current`, which is `<id>`.

### C-3. ship hook lines (C5; each verbatim, each one line)

Every hook line contains the phrase `bulk run` and names `bulk.md`. Phase D appends its `sequential-child` lines **after** these in the same sections. Phase E greps them.

| # | File and place | Hook line (verbatim) |
|---|---|---|
| H-1 | `skills/ship/SKILL.md` `## Rules`, **replaces** the line `` - One agent per Agent call, except the planning pair in `## Stage: plan`. `` | `` - One agent per Agent call, except the planning pair in `## Stage: plan` and, in a bulk run, the per-issue spec analyses of `bulk.md` `## Spec analysis` and `bulk.md` `## Re-analysis`. `` |
| H-2 | `skills/ship/SKILL.md` `## Run variables`, a new bullet after the `<default>` bullet | `` - `mode`: `state.sh get mode`. In a bulk run (`bulk`), Read `${CLAUDE_PLUGIN_ROOT}/skills/ship-milestone/references/bulk.md` and apply `bulk.md` `## Overrides` throughout this file and the references: `<id>` is the run id `m-<number>`, and `<n>` means each issue in `issues` in turn. `` |
| H-3 | `skills/ship/SKILL.md` `## Stage: spec_analysis`, a paragraph after step 6 | `` In a bulk run, step 1's label goes on every issue, and `bulk.md` `## Spec analysis` replaces steps 2 to 6. `` |
| H-4 | `skills/ship/SKILL.md` `## Blocked path`, a paragraph after the last one | `` In a bulk run, steps 2 and 3 run once per issue in `issues`, and a failure for one issue never skips the others (`bulk.md` `## Overrides`). `` |
| H-5 | `skills/ship/SKILL.md` `## Final report`, a paragraph after the existing one | `` In a bulk run, print this report with the `bulk.md` `## Overrides` changes, then go to `bulk.md` `## Report`. `` |
| H-6 | `skills/ship/references/dispatch.md` `## How to dispatch`, **replaces** the bullet starting `- Send one agent per Agent call.` | `` - Send one agent per Agent call. The exceptions are D6 and D7 (two Agent calls in one assistant message, with no other tool call in it) and, in a bulk run, the per-issue D1 or D2 calls of `bulk.md` `## Spec analysis` and `bulk.md` `## Re-analysis`. Concurrency is not guaranteed, and sequential execution is still correct. `` |
| H-7 | `skills/ship/references/dispatch.md` `## How to dispatch`, a new last bullet | `` - In a bulk run, `bulk.md` `## Overrides` changes rows D1, D2, D3 and D13 and the `spec_analysis`, `brief` and `docs` rows of `## Required inputs per stage`. `` |
| H-8 | `skills/ship/references/gates.md` `## Gate ids and pending state`, a paragraph after "The four `awaiting_input` gates never skip…" | `` In a bulk run (`bulk.md` `## Overrides`), the `spec` gate is per issue: `<rd>` is `.aew/runs/<id>/issues/<k>`, `<n>` is `k`, the note is `gate:spec issues/<k>/01-spec-analysis.md`, its label goes on that issue only, and its step 4 returns to `bulk.md` `## Spec analysis`. Every other gate's label goes on every issue, and step 4 of `plan-challenge`, `triage` and `spec-ambiguity` is `bulk.md` `## Re-analysis`. `` |
| H-9 | `skills/ship/references/gates.md` `## Recording a spec revision`, a paragraph after the refusal paragraph | `` In a bulk run, `bulk.md` `## Overrides` sets `<rd>` and `<n>` per issue, takes the version from that issue's `spec revision: #<k> v<N>` note instead of `spec_revision`, and replaces step 5 with that note. `` |
| H-10 | `skills/ship/references/gates.md` `## Re-asking a pending gate`, a new last bullet | `` - In a bulk run, a note `gate:spec issues/<k>/01-spec-analysis.md` gives `<rd>` `.aew/runs/<id>/issues/<k>` and `<n>` `k` (`bulk.md` `## Overrides`). `` |
| H-11 | `skills/ship/references/pr.md`, a paragraph after the opening paragraph | `` In a bulk run, `bulk.md` `## Overrides` changes the commit suffix, the docs commit message and the `issue.json` path (the PR URL and the retro repo), and makes the manual-tests, flag and `ready-for-review` calls once per issue. `` |
| H-12 | `skills/ship/references/final-report.md` `## Format`, a paragraph after the `Next:` list | `` In a bulk run, the first line names the run id (`aew ship <id> <title>: …`), and `failed` reads `Next: remove .aew/runs/m-<mn>, then rerun /aew:ship-milestone <mn> --bulk` (`bulk.md` `## Overrides`). `` |
| H-13 | `skills/ship/references/final-report.md` `## Counting`, a bullet after the ACs bullet | `` - In a bulk run the AC ids carry the issue prefix: `grep -c '^- \[x\] #[0-9][0-9]*-AC-' .aew/runs/<id>/10-summary.md`, and for the total `grep -cE '^- \[[ x]\] #[0-9]+-AC-' .aew/runs/<id>/10-summary.md`. `` |

In the table, the outer double backticks only delimit the cell; the hook line is the text inside them, starting at `-` or `In`. ship's `SKILL.md` grows by 7 lines (H-2 one bullet; H-3, H-4 and H-5 a blank line and a paragraph each; to about 262 plus Phase B's and D's), well under 500.

### C-4. Agent inputs (C2, C3, C4; the dispatch side is C-2 rows 4, 5, 19)

| Agent | New input | Behaviour |
|---|---|---|
| brief-compiler | dispatch field `issues: <a,b,c>` (bulk only) | required `<run_dir>/issues/<k>/spec-final.md` and `issue.json` per k; optional per-issue `01-spec-analysis.md` and `spec-changes.json`; `<run_dir>/state.json` `run_id` and `title`; one `02-brief.md` with H1 `# Brief: <run_id> <title>` (for example `# Brief: m-7 Sprint 3`), `Source:` one `issues/<k>/spec-final.md (v<n>)` entry per issue joined by `; `, ACs `#<k>-AC-<m>` numbered from 1 within each issue, issues in `issues` order; `mode: prompt` with `issues` → `blocked` |
| qa-engineer | none (reads `state.json` `mode` and `run_id` in phase B) | in a bulk run `<issue>` is `run_id`: spec file `<ui.e2e_dir>/<run_id>-<slug>.spec.ts`, evidence `<evidence.dir>/<run_id>/`, report title `# QA report <n>: <run_id> <title>`, test plan H1 copied from the brief (`# QA test plan: <run_id> <title>`), commit subject ends with every issue (`(#12, #13, #14)`), TC → AC tables carry the prefixed ids |
| doc-writer | none (reads `state.json` `mode`, `run_id`, `title`, `issues`) | in a bulk run reads `issues/<k>/spec-final.md`, `issue.json` and `spec-revision-v<N>.md` per k; one `docs/specs/<k>-<slug>.md` per issue (that issue's spec, revisions, the decisions bearing on it, its `#<k>-` ACs, its manual tests); `10-summary.md` H1 `# Summary: <run_id> <title>`; AC checklist keeps the prefixed ids (`- [x] #12-AC-1: …`, which H-13 counts); screenshot links use the first issue's `issue.json` for owner and repo and `<run_id>` as the evidence dir; outputs are four plus one snapshot per issue, all in ARTEFACTS |

### C-5. What Phases D and E get from this phase

- **Phase D (wave 2, parallel):** its ship-edit task (the one that edits `skills/ship/SKILL.md` and ship's references) declares `depends_on: [C5]`. C5 is the only Phase C task that touches `skills/ship/**`. D's I-D5/I-D6 edits share two sections with C but no line (`## Run variables` is C's alone: H-2 owns the `mode` bullet and D dropped its H1, R-C2): `## Blocked path` (D's H6 rewrites step 6; C's H-4 is a new last paragraph) and `## Final report` (D's H7 is a new last paragraph, after C's H-5). D's other ship edits (`## References` row, Step 3 paragraph, `## Stage: docs` step 3, `## Gate pending` paragraph, `preflight.md` Check 5) are in places C does not touch; D edits no `gates.md`, `dispatch.md`, `pr.md` or `final-report.md`. D makes no doc-writer change (CTO cut 2), so C4 is the only doc-writer edit and D does not need to wait for it.
- **Phase E (wave 3):**
  - resume (AC-28, bulk): reads ship's files as for `single`; at status `running` it enters `ship/SKILL.md` `## Stage: <stage>` step 1, where H-2 and H-3 send a bulk run into `bulk.md` (at `spec_analysis`, `bulk.md` `## Spec analysis` step 1 re-dispatches only the issues not yet `ok`); a pending gate goes through `gates.md` `## Re-asking a pending gate`, where H-10 gives the per-issue `<rd>` and `<n>`.
  - `skills.bats`: no resolver change for bulk (B3 already maps `bulk.md`, `ship/SKILL.md` and `ship-milestone/SKILL.md` and adds ship-milestone's files to tests 17 and 18; R-B2); the AC-25 check (no line in `skills/ship-milestone/**` matches `^## Stage:`, `^## Gate:` or `^\| D[0-9]+ \|`) holds for `bulk.md` by C-2.
  - B1 (AC-33) allow file: the commands of C-6.
  - Docs (AC-31): DESIGN §7.1 (`issues/<k>/` with `00-issue-original.md`, `issue.json`, `01-spec-analysis.md`, `spec-final.md`, `spec-changes.json`, `spec-revision-v<N>.md`), the C3 evidence deviation (`docs/qa/m-<n>/`), run-protocol and `CHANGELOG.md`. Phase C changes no doc outside the skill and agent files.

### C-6. Commands `bulk.md` adds (Phase E's B1 allowlist union; all pre-approvable, checked in C1 GREEN)

- `state.sh init <id> --issues <a,b,c> --mode bulk --title "<title>"` (plus `--auto`); `state.sh status failed --note "…"`, `state.sh current clear`, `state.sh set branch <name>`, `state.sh status running --note "spec revision: #<k> v<N>"`, `state.sh stage spec_analysis --note "answers: gate:<gate-id>"`.
- `gh-issue.sh fetch <k> .aew/runs/<id>/issues/<k>`; `gh-labels.sh stage <k> <label>`; `git-branch.sh create <id> <slug>`.
- `jq -r .state .aew/runs/<id>/issues/<k>/issue.json`; the slug `jq -r '.title | ascii_downcase | gsub("[^a-z0-9]+"; "-") | ltrimstr("-") | .[0:40] | rtrimstr("-") | if . == "" then "milestone-<number>" else . end' .aew/runs/<id>/state.json`; the C-2 row 7 version read; `jq -r '.issues | map(tostring) | join(",")' .aew/runs/<id>/state.json`; `jq -r '.issues | map("#" + tostring) | join(", ")' .aew/runs/<id>/state.json`; `jq -s '[.[].changes[] | select(.type == "material")] | length' <files>`.
- `test -f .aew/runs/<id>/issues/<k>/01-spec-analysis.md && echo yes || echo no`; `grep -v '^$' .aew/runs/<id>/issues/<k>/01-spec-analysis.md | tail -n 4`; `grep -c '^### Q[0-9]' .aew/runs/<id>/issues/<k>/01-spec-analysis.md`.

Dry-runs made while writing this plan (jq 1.7.1): the version read gives `3` for `#12` with notes `v2` and `v3`, `5` for `#1` (a `#12` note does not match `#1 v`), and `1` with no note; the slug filter on `Sprint 3: Basket & Checkout!` gives `sprint-3-basket-checkout`; the material count over two files with one material change each gives `2`; the suffix read gives `#12, #13, #14`; on a summary with `- [x] #12-AC-1`, `- [ ] #12-AC-2`, `- [x] #13-AC-1` and `- [x] AC-9`, the H-13 greps give `2` and `3`; the existing `preapprovable_offenders` function, extracted with `sed`, flags `jq -r .x $f` (H1) and passes ship's `SKILL.md` and `gates.md`.

### C-7. Run-dir layout a bulk run produces (for Phase E's DESIGN §7.1 update)

`.aew/runs/<id>/`: `state.json`, `log.md`, `issues/<k>/{00-issue-original.md, issue.json, 01-spec-analysis.md, spec-final.md, spec-changes.json, spec-revision-v<N>.md}` per issue, then the usual run-root artefacts from `02-brief.md` to `10-summary.md`, `pr-body.md`, `retro.md`, `manual-tests.md`. Beside it: `.aew/runs/blocked-<id>.md` (ship's flat blocked comment) and Phase B's `milestone-report.md` inside the run dir.

## Tasks

Waves: **1** = C1 ∥ C2 ∥ C3 ∥ C4 (four different files; they agree only through C-2 and C-4) · **2** = C5 (needs `bulk.md` to exist, because ship's path test checks the H-2 path, and cites its headings).

Commit trailer for every task, as the last line of the message: `Co-Authored-By: Claude <noreply@anthropic.com>` (CLAUDE.md; no model name, even if the session suggests another line).

Before C1 and C5 (in each worktree that runs them), extract the pre-approvable checker if `tests/tmp/pa.bash` is absent (scratch, gitignored):

```sh
cd /Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
sed -n '/^preapprovable_offenders() {/,/^}/p' tests/scripts/skills.bats > tests/tmp/pa.bash
wc -l < tests/tmp/pa.bash                                  # about 118
```

---

### Task C1 — `skills/ship-milestone/references/bulk.md`

- **id:** C1
- **files:** `skills/ship-milestone/references/bulk.md` (new, or replacing a Phase B placeholder after a Read)
- **depends_on:** [] within the phase (cross-phase: Phase B's `skills/ship-milestone/` directory and headings, C-1)
- **pattern:** the opening paragraph and numbered-step style of `skills/ship/references/gates.md`; the table style of `skills/ship/references/dispatch.md` `## Dispatch table`; ship's Step 3 (`skills/ship/SKILL.md` 3.1–3.8) for `## Start`. The override table has no analog (spec: NOVEL).
- **ACs:** AC-14, AC-15, AC-17 (labels, re-analysis), AC-18 and AC-19 (override rows), AC-25 (no stage sections, dispatch rows or gate steps)
- **Size:** about 110–170 lines.

**Step 1: RED.**

```sh
cd /Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
f=skills/ship-milestone/references/bulk.md
test -f "$f" && grep -cxF '## Overrides' "$f" || echo absent     # absent (or 0 over a placeholder)
```

**Step 2: write `bulk.md`** with the C-2 headings, in order. Content per section:

- `# Bulk mode`, then one opening paragraph:
  - Read by `ship-milestone` after mode selection, by `ship`'s hooks (each names this file) and by `resume`. A bulk run is one run `<id>` (`m-<number>`, mode `bulk`) that goes through ship's own stage sections once, on one branch, with one PR. This file holds only what differs.
  - Read every literal `${CLAUDE_PLUGIN_ROOT}` here as the plugin root stated in `ship-milestone/SKILL.md` `## Plugin root` (or in `resume`'s own statement of it), and a bare `state.sh …`, `gh-issue.sh …`, `gh-labels.sh …` or `git-branch.sh …` as that root's `scripts/` file by absolute path.
  - The CD-12 citation rule, in one sentence.
  - `<id>`, `<number>` and `<k>` as in this plan's naming note; `<rd_k>` is `.aew/runs/<id>/issues/<k>`.
- `## Overrides`: one sentence ("Apply each row wherever ship's files reach the place in the first column."), then the table with header `| Where | Single run | Bulk run |` and rows 1–19 of C-2, in order, numbered `1.` to `19.` in the first cell. Keep each cell short and free of literal `|` (write "or"). The verbatim pieces of C-2 (the version read, the gate note, the revision note, the suffix read, the AC greps, the `failed` `Next:` line) go into the cells exactly. Close with: "Everything else in ship's files applies unchanged: one standards pass, one plan (D6 ∥ D7), one plan gate unless `auto`, one develop, review and QA loop, one docs pass and one PR."
- `## Start` (AC-14), numbered steps **1–6 verbatim as numbers**:
  1. `state.sh init <id> --issues <a,b,c> --mode bulk --title "<milestone title>"`, adding `--auto` when given. `<a,b,c>` is the open issues from `select`, ascending. The title is a double-quoted literal with `"`, `$`, backtick and `\` escaped (ship's `## Rules`). This also creates `issues/<k>/` for each issue.
  2. For each k, ascending: `gh-issue.sh fetch <k> .aew/runs/<id>/issues/<k>`. On failure: `state.sh status failed --note "fetch failed: #<k>: <first stderr line>"`, then `state.sh current clear`, then print `Could not fetch issue #<k>: <reason>. Fix it, then remove .aew/runs/m-<mn>, then rerun /aew:ship-milestone <mn> --bulk.` and stop (CD-4).
  3. For each k: `jq -r .state .aew/runs/<id>/issues/<k>/issue.json`. `CLOSED` takes the same three actions as step 2, with the reason `issue #<k> is closed`.
  4. For each k: `gh-labels.sh stage <k> analysing`.
  5. The slug (C-6 command, verbatim, with `<number>` filled in), then `git-branch.sh create <id> <slug>` (it prints the branch name, from `git.milestone_branch_pattern`), then `state.sh set branch <name>`. A failure goes to `ship/SKILL.md` `## Blocked path` (`routing.md` `## Script failures`), with the bulk overrides.
  6. Go to `## Spec analysis` (`state.sh init` has already set the stage `spec_analysis`, and step 4 set the labels).
- `## Spec analysis` (AC-15; numbered steps **1–6**). Open with one sentence: this section is entered from `ship/SKILL.md` `## Stage: spec_analysis` (after its step 1), from `## Start`, from a per-issue spec gate (C-2 row 8) and from `## Re-analysis`, and it decides from each issue's file every time (CD-2).
  1. **Classify** each issue k, ascending: `test -f .aew/runs/<id>/issues/<k>/01-spec-analysis.md && echo yes || echo no`; on `yes`, `grep -v '^$' .aew/runs/<id>/issues/<k>/01-spec-analysis.md | tail -n 4` and read its first line. `STATUS: ok` is **done**, `STATUS: needs_input` is **waiting**, and anything else (`no`, `blocked`, `failed`, an invalid block) is **to run**.
  2. **Dispatch** every to-run issue: check its required files (C-2 row 3, `test -f … && echo yes || echo no`; a missing one goes to `ship/SKILL.md` `## Blocked path`), read its `<v_k>` (C-2 row 7), then send one D1 per issue, **all in one assistant message** with no other tool call in it (ship's `## Rules`, H-1). The prompt per issue (verbatim form):

     ```
     run_dir: .aew/runs/m-7/issues/12
     spec_version: 2
     ```

     Skip this step when no issue is to run.
  3. **Check each return** with `dispatch.md` `## Return check`. Retry a `failed` or invalid one once, on its own (`dispatch.md` `## Retries`); a second failure goes to `ship/SKILL.md` `## Blocked path`. A `blocked` goes to `routing.md` `## Agent status routing` (the blocked path). Each issue's return is checked and retried on its own: one issue's retry never re-sends another.
  4. **Record** each done issue's revision, ascending: `gates.md` `## Recording a spec revision` under C-2 row 9. It is idempotent, so issues recorded on an earlier pass are skipped by its version check.
  5. **Gate** the first waiting issue, ascending: `gates.md` `## Gate: spec` under C-2 row 8 (pending note `gate:spec issues/<k>/01-spec-analysis.md`, label on k only, questions prefixed `#<k>: `). Gates run one at a time: no second gate is set while one is open. Its step 4 dispatches D2 for k alone, checks that return, and comes back to step 1. With no answer, `ship/SKILL.md` `## Gate pending` stops the run (the other issues stay as their files say).
  6. **Exit** when step 1 finds every issue done (none to run, none waiting) and step 4 has run: go to `ship/SKILL.md` `## Stage: brief`, whose Entry sets `planning` on every issue (C-2 row 1).

  Then one closing line: "So after one issue's gate is answered and re-analysed, the stage moves on to the next issue still waiting, and reaches the brief only when every issue is `ok`." (the spec-review note, verbatim).
- `## Re-analysis` (AC-17; replaces step 4 of `gates.md` `## Gate: plan-challenge`, `gates.md` `## Gate: triage` and `gates.md` `## Gate: spec-ambiguity` in a bulk run; numbered steps **1–5**):
  1. **Group the answers** by issue (CD-7): a question naming `#<k>` of the run goes to k (to each k it names); a question naming none goes to every issue.
  2. `state.sh stage spec_analysis --note "answers: gate:<gate-id>"`, then `gh-labels.sh stage <k> analysing` for every issue.
  3. For each issue with answers: read `<v_k>` and `grep -c '^### Q[0-9]' .aew/runs/<id>/issues/<k>/01-spec-analysis.md` (`grep -c` prints `0` and exits 1 when there are none), then send one D2 per issue, all in one assistant message: `run_dir`, `spec_version: <v_k + 1>`, `answers:` and that issue's lines `Q<j>: <question> => <answer>`, with j continuing after the count.
  4. Check each return as in `## Spec analysis` step 3. Any `needs_input` goes to `## Spec analysis` step 1, whose exit is a plain `ship/SKILL.md` `## Stage: brief` (CD-8). Otherwise record each re-analysed issue's revision (`## Spec analysis` step 4).
  5. **Exit.** After `plan-challenge` or `triage`: `ship/SKILL.md` `## Stage: brief`. After `spec-ambiguity`: count `jq -s '[.[].changes[] | select(.type == "material")] | length' <files>`, where `<files>` are the re-analysed issues' `.aew/runs/<id>/issues/<k>/spec-changes.json` only (the others are from an earlier pass). Greater than 0: `ship/SKILL.md` `## Stage: brief`. 0: `ship/SKILL.md` `## Stage: brief` entered with the note `spec-ambiguity: non-material`, as in `gates.md` `## Gate: spec-ambiguity` step 4.
- `## Report` (AC-18, AC-19; reached from H-5 for every outcome): after ship's own report, follow `ship-milestone/SKILL.md` `## Milestone report`, then `ship-milestone/SKILL.md` `## Final report`, which is printed last. One line: `current` may already be cleared (`pr.md` `## Finish`, the plan-gate stop) or kept (the blocked path), so those sections read the run with `jq … .aew/runs/<id>/state.json`.

**Step 3: GREEN.**

```sh
f=skills/ship-milestone/references/bulk.md
for h in '# Bulk mode' '## Overrides' '## Start' '## Spec analysis' '## Re-analysis' '## Report'; do printf '%s=%s\n' "$h" "$(grep -cxF "$h" "$f")"; done   # each =1
grep -n '^#' "$f" | cut -d: -f2-                                  # the C-2 list, in that order
grep -cxF '| Where | Single run | Bulk run |' "$f"                  # 1
for r in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19; do printf '%s=%s\n' "$r" "$(grep -c "^| $r\. " "$f")"; done   # each =1
grep -cE '^## Stage:|^## Gate:|^\| D[0-9]+ \|' "$f"                # 0
for m in 'gate:spec issues/<k>/01-spec-analysis.md' 'state.sh status running --note "spec revision: #<k> v<N>"' 'select(startswith("spec revision: #" + $k + " v"))' "--arg k <k> .aew/runs/<id>/state.json" 'map("#" + tostring) | join(", ")' "grep -c '^- \[x\] #[0-9][0-9]*-AC-'" 'Next: remove .aew/runs/m-<mn>, then rerun /aew:ship-milestone <mn> --bulk' 'Could not fetch issue #<k>: <reason>. Fix it, then remove .aew/runs/m-<mn>, then rerun /aew:ship-milestone <mn> --bulk.' 'goes to the brief only when every issue is' 'all in one assistant message' 'ship-milestone/SKILL.md` `## Milestone report' 'ship-milestone/SKILL.md` `## Final report' 'ship-milestone/SKILL.md` `## Plugin root' 'spec-ambiguity: non-material'; do printf '%s=%s\n' "$m" "$(grep -cF -- "$m" "$f")"; done   # every count >= 1
grep -cF '`SKILL.md`' "$f"                                       # 0 (CD-12: never a bare SKILL.md)
grep -cE 'aew:(analysing|awaiting-input|planning|awaiting-approval|building|testing|documenting|ready-for-review|blocked|spec-revised|manual-test-required)' "$f"   # 0 (labels bare)
grep -nE '\$\{CLAUDE_PLUGIN_ROOT\}/[A-Za-z0-9._/-]*[<{]' "$f"       # no output
grep -ohE '\$\{CLAUDE_PLUGIN_ROOT\}/[A-Za-z0-9._/-]*' "$f" | sed 's/[.]*$//; s|^\${CLAUDE_PLUGIN_ROOT}/||' | while read -r p; do test -e "$p" || echo "MISSING $p"; done   # no output
grep -cE '\$[0-9]|\$ARGUMENTS|!`' "$f"                              # 0
bash -c '. tests/tmp/pa.bash; preapprovable_offenders "$PWD" "$1"' _ "$f" | grep -v '^no fenced sh block found$'   # no output
wc -l < "$f"                                                      # 110–170
bats tests/scripts/skills.bats                                    # passes (with B's ENTRY entry, bulk.md is now covered by the path and aew:<name> tests)
```

**Step 4: commit.**

```
feat(ship-milestone): add the bulk mode reference

bulk.md holds every way a bulk milestone run differs from a single run:
an override table that ship's hook lines point to (per-issue labels,
paths, revision notes and gates, the commit suffix, the PR URL and the
prefixed AC count), the run start, a re-entrant per-issue spec-analysis
loop with one gate at a time, re-analysis after a later gate, and the
hand-off to the milestone report. It has no stage sections of its own.

Co-Authored-By: Claude <noreply@anthropic.com>
```

---

### Task C2 — brief-compiler takes `issues` (bulk)

- **id:** C2
- **files:** `agents/brief-compiler.md`
- **depends_on:** []
- **pattern:** the existing optional-field style of `agents/brief-compiler.md` Inputs (`mode`, with its default), and Phase A's C-1 of 2026-10-25 (an optional field that changes nothing when absent).
- **ACs:** AC-16 (agent side)

**Step 1: RED.**

```sh
f=agents/brief-compiler.md
grep -c 'issues: 12,13,14' "$f"                     # 0
grep -cF 'issues/<k>/spec-final.md' "$f"            # 0
grep -cF '# Brief: <run_id> <title>' "$f"           # 0
```

**Step 2: edit**, keeping every existing sentence that still holds (without `issues`, behaviour is byte for byte today's):

- **Inputs → Dispatch fields:** add the bullet: "`issues` (bulk milestone runs only): the run's issue numbers, comma-separated, for example `issues: 12,13,14`. Its presence means a bulk run (see Bulk runs below). Without it, everything is single-issue as described."
- **Inputs:** add a `**Bulk runs** (`issues` given):` block after Optional files:
  - Required, for every k in `issues`: `<run_dir>/issues/<k>/spec-final.md` and `<run_dir>/issues/<k>/issue.json`. Any missing file is `blocked`, naming it. There is no `spec-final.md` or `issue.json` at the run root, so do not look for one.
  - Optional, per issue: `<run_dir>/issues/<k>/01-spec-analysis.md` and `<run_dir>/issues/<k>/spec-changes.json`, used as the optional files above are.
  - `<run_dir>/state.json`: read `run_id` and `title` only, for the H1. Never write it.
  - Pipeline mode only. `mode: prompt` with `issues` is `blocked` ("milestone runs have no prompt mode").
- **Writing acceptance criteria → Numbering:** extend the bulk sentence: the id is `#<issue>-AC-<n>`, numbered from 1 within each issue, with each issue's ACs together and the issues in the order of `issues`. Every issue has at least one AC.
- **Process → Pipeline mode step 4:** add: in a bulk run the H1 is `# Brief: <run_id> <title>` (for example `# Brief: m-7 Sprint 3`), and the `Source:` line has one `issues/<k>/spec-final.md (v<n>)` entry per issue, joined by `; `, with each `n` found by the existing rule from that issue's own files. Goal covers the milestone as a whole; Context gives a line or two per issue.
- **Process → step 5 self-check:** add: in a bulk run, the set of AC prefixes equals `issues`, and numbering is consecutive within each prefix.
- **Return contract → SUMMARY:** add: in a bulk run, the AC count per issue.
- **Definition of done:** extend the numbering item: "(per issue in a bulk run)".

**Step 3: GREEN.**

```sh
f=agents/brief-compiler.md
grep -c 'issues: 12,13,14' "$f"                     # >= 1
grep -cF 'issues/<k>/spec-final.md' "$f"            # >= 1
grep -cF 'issues/<k>/issue.json' "$f"               # >= 1
grep -cF '# Brief: <run_id> <title>' "$f"           # >= 1
grep -c 'milestone runs have no prompt mode' "$f"   # >= 1
grep -cF -- '- `<run_dir>/spec-final.md`: the settled spec text.' "$f"   # 1 (single-issue input kept)
bats -f 'frontmatter' tests/scripts/skills.bats     # passes
claude plugin validate .                            # passes, existing warnings only
```

**Step 4: commit.**

```
feat(agents): let brief-compiler compile one brief for a bulk milestone run

With the new issues field, brief-compiler reads each issue's spec-final.md
and issue.json from the run's issues/<k>/ subdirectories and writes one
02-brief.md, headed with the milestone run id and title, whose ACs are
numbered per issue (#12-AC-1). Without the field nothing changes.

Co-Authored-By: Claude <noreply@anthropic.com>
```

---

### Task C3 — qa-engineer uses the run id as `<issue>` in bulk

- **id:** C3
- **files:** `agents/qa-engineer.md`
- **depends_on:** []
- **pattern:** `agents/qa-engineer.md` Inputs line 36 (the `state.json` fields phase B reads) and Outputs line 182 (the report title rule). The evidence fixture already accepts `m-<n>-<slug>.spec.ts` (spec-review note: `startsWith(basename(dirname(dir)) + '-')`).
- **ACs:** AC-17 (QA `<issue>`, traceability, Assumption 9, conflict C3)

**Step 1: RED.**

```sh
f=agents/qa-engineer.md
grep -c 'bulk' "$f"                                 # 0
grep -cF '(#12, #13, #14)' "$f"                     # 0
```

**Step 2: edit:**

- **Inputs, line 36:** "Phase B reads `state.json` for these fallbacks, `issues`, `mode`, `run_id` and `base_branch` only." Then a new paragraph, the definition used throughout the prompt: "`<issue>` is `issues[0]`, except in a bulk milestone run (`mode` is `bulk`), where it is the run id (`run_id`, for example `m-7`), because one QA pass covers every issue. Then the spec file is `<ui.e2e_dir>/m-7-<slug>.spec.ts` (the slug from the brief's H1 title), the evidence goes under `<evidence.dir>/m-7/`, and the report title has no `#`."
- **Phase A:** where the H1 rule says phase A takes `#<issue> <title>` from the brief's H1, add: in a bulk run the brief's H1 is `# Brief: m-7 <title>`, so the test plan's H1 is `# QA test plan: m-7 <title>`. Phase A still never opens `state.json`.
- **Phase B step 11** (or the triage-table paragraph): one line: in a bulk run the AC column of the Results and triage tables carries the prefixed id (`#12-AC-1`), which gives traceability per issue, and so does each `manual-tests.md` line (`- [ ] **TC-3 (#12-AC-1):** …`), because Phase B's milestone report (BD-11) and doc-writer's per-issue snapshot (C4) select manual tests by that prefix.
- **Phase B step 14:** add: in a bulk run the subject ends with every issue in `issues`, for example `test(e2e): add basket and checkout tests (#12, #13, #14)`.
- **Outputs, line 182:** "The title of the report is `# QA report <n>: #<issue> <title>`, where `<issue>` is `issues[0]` from `state.json`; in a bulk run it is `# QA report <n>: <run_id> <title>`."

Every other `<issue>` (steps 3, 5, 13, the Outputs paths, the Guardrails) now follows the definition, so no other line changes.

**Step 3: GREEN.**

```sh
f=agents/qa-engineer.md
grep -cF '`mode`, `run_id` and `base_branch`' "$f"  # 1
grep -cF 'm-7-<slug>.spec.ts' "$f"                  # >= 1
grep -cF '<evidence.dir>/m-7/' "$f"                 # >= 1
grep -cF '(#12, #13, #14)' "$f"                     # >= 1
grep -cF '# QA report <n>: <run_id> <title>' "$f"   # 1
grep -cF '# QA test plan: m-7 <title>' "$f"         # 1
grep -cF 'TC-3 (#12-AC-1)' "$f"                     # >= 1 (manual-tests lines carry the prefix)
grep -cF 'Phase A never opens `state.json` or `issue.json`' "$f"   # 1 (the phase A rule is kept)
bats tests/scripts/hooks-gate-subagent.bats         # passes (the QA gate is untouched)
claude plugin validate .                            # passes
```

**Step 4: commit.**

```
feat(agents): name bulk QA evidence and specs after the milestone run id

In a bulk milestone run qa-engineer uses the run id (m-<n>) where it
used issues[0]: one spec file, docs/qa/m-<n>/ for the evidence, a report
titled with the run id, prefixed AC ids in the TC tables and a commit
that references every issue.

Co-Authored-By: Claude <noreply@anthropic.com>
```

---

### Task C4 — doc-writer writes per-issue snapshots in bulk

- **id:** C4
- **files:** `agents/doc-writer.md`
- **depends_on:** []
- **pattern:** `agents/doc-writer.md` `## Spec snapshot` (the five sections) and `## In plain English` Variants (the bulk variant already exists and is unchanged). CTO cut 2: no stacked summary line.
- **ACs:** AC-18 (doc-writer side), Assumption 17 as amended by cut 2

**Step 1: RED.**

```sh
f=agents/doc-writer.md
grep -cF 'issues/<k>/spec-final.md' "$f"            # 0
grep -cF 'docs/specs/<k>-<slug>.md' "$f"            # 0
```

**Step 2: edit:**

- **Inputs → Files:** after the first bullet, add a bulk bullet: "In a bulk milestone run (`state.json` `mode` is `bulk`), `spec-final.md`, `issue.json` and any `spec-revision-v<N>.md` are per issue, under `<run_dir>/issues/<k>/` for each k in `issues`. There are none at the run root. QA's evidence is under `docs/qa/<run_id>/` (one QA pass, named by the run id)." Add `mode`, `run_id` and `title` to the `state.json` fields read.
- **`## Spec snapshot`:** add a closing paragraph: in a bulk run write one snapshot per issue, `docs/specs/<k>-<slug>.md`, the slug from that issue's `issue.json` title, with the same five sections: `## Spec` from `issues/<k>/spec-final.md`; `## Revision history` from that issue's `spec-revision-v<N>.md` files (the current version is the highest N, or 1 when there are none; the run's `spec_revision` is not used in bulk, CD-11); `## Key decisions` from the shared plan, those that bear on the issue; `## Traceability` with the ACs prefixed `#<k>-` only; `## Outstanding manual tests` with the open items whose AC id has the `#<k>-` prefix, or "None.".
- **Process step 4:** add three points: in a bulk run the `10-summary.md` H1 is `# Summary: <run_id> <title>`; the AC checklist keeps the brief's prefixed ids (`- [x] #12-AC-1: …`), because the orchestrator counts them in that form; screenshot links take owner and repo from the first issue's `issues/<k>/issue.json`, and the evidence path uses `<run_id>` as `<issue>`.
- **`## Outputs`:** "Exactly five files" becomes "Exactly five files for a single issue. In a bulk run, the four run files (`CLAUDE.md`, `10-summary.md`, `pr-body.md`, `retro.md`) plus one `docs/specs/<k>-<slug>.md` per issue."
- **`## Return contract`:** the `ok` line: `ARTEFACTS` lists exactly those paths (five, or four plus one per issue).
- **`## Definition of done`:** the snapshot item: one snapshot per issue in a bulk run; the ARTEFACTS item: exactly the output paths.

**Step 3: GREEN.**

```sh
f=agents/doc-writer.md
grep -cF 'issues/<k>/spec-final.md' "$f"            # >= 1
grep -cF 'docs/specs/<k>-<slug>.md' "$f"            # >= 1
grep -cF '# Summary: <run_id> <title>' "$f"         # 1
grep -cF -- '- [x] #12-AC-1' "$f"                   # >= 1
grep -cF 'docs/qa/<run_id>/' "$f"                   # >= 1
grep -c 'stacked_on' "$f"                           # 2, as before (no stacked summary line, cut 2)
grep -cF 'Bulk: `issues` in `state.json` has more than one entry.' "$f"   # 1 (intro variant unchanged)
claude plugin validate .                            # passes
```

**Step 4: commit.**

```
feat(agents): write one spec snapshot per issue in a bulk run

In a bulk milestone run doc-writer reads each issue's spec, issue.json
and revisions from the run's issues/<k>/ subdirectories, writes one
docs/specs/<k>-<slug>.md per issue with that issue's ACs, keeps the
prefixed AC ids in the summary, and lists every output in ARTEFACTS.

Co-Authored-By: Claude <noreply@anthropic.com>
```

---

### Task C5 — ship's bulk hook lines

- **id:** C5 (**the Phase C ship-edit task; Phase D's ship-edit task declares `depends_on: [C5]`**)
- **files:** `skills/ship/SKILL.md`, `skills/ship/references/dispatch.md`, `skills/ship/references/gates.md`, `skills/ship/references/pr.md`, `skills/ship/references/final-report.md`
- **depends_on:** [C1] (the H-2 path must exist for `skills.bats`' path test, and the hooks cite `bulk.md`'s headings). Cross-phase: Phase B's ship E3 edit lands first (wave 1).
- **pattern:** ship's existing one-line cross-file rules, for example the prompt-mode rule in `gates.md` `## Gate ids and pending state` ("In prompt mode (`/aew:prompt`), skip every …") and the `stacked_on` note in `dispatch.md`.
- **ACs:** AC-25 (single-line hooks only; Rules, Run variables, `## Stage: spec_analysis`, Final report, Blocked path; the gates, pr and final-report overrides), AC-15 (Rules exception, per-issue gate), AC-19 (Blocked path)

**Step 1: RED.**

```sh
cd /Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
for f in skills/ship/SKILL.md skills/ship/references/dispatch.md skills/ship/references/gates.md skills/ship/references/pr.md skills/ship/references/final-report.md; do printf '%s=%s\n' "$f" "$(grep -c 'bulk\.md' "$f")"; done   # every count 0
wc -l < skills/ship/SKILL.md                                      # 255 (plus any Phase B change)
```

**Step 2: apply hooks H-1 to H-13 of C-3, verbatim, at the places given.** H-1 and H-6 replace an existing line; the rest add one line (a bullet or a paragraph). Change nothing else in these files. Read each file first (the Write and Edit tools need it), and match the existing line exactly for the two replacements.

**Step 3: GREEN.**

```sh
S=skills/ship/SKILL.md; R=skills/ship/references
grep -c 'bulk\.md' "$S"                                           # 5 (H-1 to H-5)
grep -c 'bulk\.md' "$R/dispatch.md"                               # 2 (H-6, H-7)
grep -c 'bulk\.md' "$R/gates.md"                                  # 3 (H-8 to H-10)
grep -c 'bulk\.md' "$R/pr.md"                                     # 1 (H-11)
grep -c 'bulk\.md' "$R/final-report.md"                           # 1 (H-12; H-13 names no file)
grep -c 'In a bulk run the AC ids carry the issue prefix' "$R/final-report.md"   # 1 (H-13)
grep -cF '${CLAUDE_PLUGIN_ROOT}/skills/ship-milestone/references/bulk.md' "$S"   # 1 (H-2)
grep -cF -- '- One agent per Agent call, except the planning pair in `## Stage: plan`.' "$S"   # 0 (H-1 replaced it)
grep -cF 'The single exception is D6 and D7' "$R/dispatch.md"     # 0 (H-6 replaced it)
grep -cF 'gate:spec issues/<k>/01-spec-analysis.md' "$R/gates.md" # 2 (H-8, H-10)
wc -l < "$S"                                                      # previous count + 7 (H-2 adds a bullet; H-3, H-4 and H-5 each add a blank line and a paragraph; H-1 replaces a line); well under 500
git diff --stat -- skills/ship                                    # only these five files; insertions only, plus the two replaced lines
bash -c '. tests/tmp/pa.bash; preapprovable_offenders "$PWD" "$@"' _ "$S" "$R"/*.md | grep -v '^no fenced sh block found$'   # no output
bats tests/scripts/skills.bats                                    # passes: paths (H-2 exists after C1), citations (B3's resolver checks `bulk.md` and `ship/SKILL.md` citations), tests 17 and 18
tests/run-script-tests.sh                                         # passes (no script touched)
claude plugin validate .                                          # passes
```

B3's resolver already checks `bulk.md` citations; this hand check is a quicker, more direct view of the same thing:

```sh
grep -ohE '`bulk\.md` `## [^`]+`' skills/ship/SKILL.md skills/ship/references/*.md | sort -u | sed 's/^`bulk\.md` `//; s/`$//' | while IFS= read -r h; do grep -qxF "$h" skills/ship-milestone/references/bulk.md && echo "ok $h" || echo "BROKEN $h"; done   # every line starts with ok
```

**Step 4: commit.**

```
feat(ship): add the bulk milestone hooks to ship and its references

One-line hooks send a bulk run to ship-milestone's bulk.md: the second
exception to one Agent call per message, the mode in Run variables, the
per-issue spec analysis, per-issue blocked comments and labels, the
milestone report after the final report, and the bulk overrides for
dispatch rows, the spec gate, revision records, commits, the PR URL and
the prefixed AC count. The single-issue path is unchanged.

Co-Authored-By: Claude <noreply@anthropic.com>
```

## Phase verification (after C1–C5)

```sh
cd /Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
tests/run-script-tests.sh                                         # all green, shellcheck clean (no script changed)
bats tests/scripts/skills.bats                                    # passes
claude plugin validate .                                          # passes, existing warnings only
bash -c '. tests/tmp/pa.bash; preapprovable_offenders "$PWD" "$@"' _ skills/ship-milestone/references/bulk.md skills/ship/SKILL.md skills/ship/references/*.md | grep -v '^no fenced sh block found$'   # no output
grep -rcE '^## Stage:|^## Gate:|^\| D[0-9]+ \|' skills/ship-milestone/references/bulk.md   # 0
wc -l < skills/ship/SKILL.md                                      # < 500
# Override table and hooks agree: every C-2 row a hook names exists.
for r in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19; do grep -c "^| $r\. " skills/ship-milestone/references/bulk.md; done | sort -u   # 1
# Dispatch fields agree with the agents.
grep -c 'issues: <a,b,c>' skills/ship-milestone/references/bulk.md   # >= 1 (C-2 row 4) and brief-compiler names the field (C2)
grep -c 'issues: 12,13,14' agents/brief-compiler.md                  # >= 1
git status --porcelain                                            # only the nine Phase C files (plus files of other phases and the pre-existing spec, overrides and project-map changes)
rm tests/tmp/pa.bash
```

No paid run in this phase. The live proof is Phase E's B1 (AC-33): one PR closing all three issues with an introduction that passes `check-pr-intro.sh --issues 3`, a revision record on each issue whose analysis changed it, `ready-for-review` and the milestone report on all three, and a valid `state.json` (`done`).

## AC → task matrix

| AC | Task(s) | Evidence |
|---|---|---|
| AC-14 run id `m-<n>`, `state.sh init … --mode bulk --title` (+ `--auto`), fetch into `issues/<k>/`, closed issue stops, `analysing` on every issue, one branch from `git-branch.sh create m-<n> <slug>` with ship's slug filter | C1 `## Start` (Phase A's init subdirs) | C1 GREEN greps; B1 in Phase E |
| AC-15 one D1 per issue in one message, per-issue `run_dir` and `spec_version`, own return check and retry; per-issue revision record with the `spec revision: #<k> v<N>` note and idempotency; per-issue spec gate (label on that issue, note `gate:spec issues/<k>/01-spec-analysis.md`), one at a time in issue order, then the next waiting issue, brief only when all `ok`; resume re-dispatches only non-`ok` issues | C1 `## Spec analysis`, rows 3, 7, 8, 9; C5 H-1, H-3, H-6, H-8, H-9, H-10 | C1 and C5 GREEN; dry-run of the version read (C-6) |
| AC-16 D3 once with `issues: <a,b,c>`, per-issue inputs, one brief, prefixed ids, H1 `# Brief: m-<n> <title>` | C2; C1 row 4; C5 H-7 | C2 GREEN |
| AC-17 ship's stages unchanged after the brief; every `gh-labels.sh stage` call per issue; prefixed ids in the QA TC → AC table; QA `<issue>` = `m-<n>` (`docs/qa/m-<n>/`); later-gate answers re-run D2 for the named issues (all when none), record each revision, then the brief | C1 rows 1, 10, `## Re-analysis`; C3; C5 H-2, H-8 | C1, C3 GREEN |
| AC-18 per-issue `docs/specs/<k>-<slug>.md`, bulk intro, `check-pr-intro.sh --issues <count>` as now, one `gh-pr.sh create m-<n>` closing all, manual tests and flag on every issue, `ready-for-review` on every issue, retro once | C4; C1 rows 12–17, `## Report`; C5 H-5, H-11, H-12, H-13 | C4, C5 GREEN; B1 in Phase E |
| AC-19 blocked comment and `blocked` label on every issue | C1 row 18; C5 H-4 | C5 GREEN |
| AC-25 (bulk half) no stage sections, dispatch rows or gate steps in `bulk.md`; ship gains single-line hooks only (Rules, Run variables, `## Stage: spec_analysis`, Final report, Blocked path); gates, pr and final-report gain only bulk path overrides | C1 (structure), C5 (hooks) | C1 `^## Stage:` grep = 0; C5 `git diff --stat`; Phase E's `skills.bats` check. The docs (`stacked_on`) and Gate pending hooks are Phase D's; E3 is Phase B's |

## Risks (this phase)

- **R-1 Heading mismatch with Phase B.** Phases B and C are planned in parallel, so B's `## Plugin root`, `## Milestone report` and `## Final report` (C-1) may come out named differently. Mitigation: `bulk.md` cites B in two places only (its opening paragraph and `## Report`), and the consolidator aligns them. B3's citation test then catches any leftover mismatch.
- **R-2 Override drift** (spec Risk 2). A step that misses a bulk override fails quietly, for example a label set on the first issue only. Mitigation: one numbered table, a hook line at each point of use that names `bulk.md`, and B1 checking labels, comments and flags on every issue.
- **R-3 Question text decides re-analysis scope** (CD-7). If the senior-engineer or QA does not name `#<k>` in a challenge, every issue is re-analysed. That costs one spec-analyser run per issue, but it is never wrong.
- **R-4 Parallel spec-analysers share one memory dir.** spec-analyser has `memory: project`, so in a bulk run up to five instances may write `.claude/agent-memory/aew-spec-analyser/` at once, and one write can overwrite another. The cost is a lost memory entry (cosmetic), not a broken run, and the memory commit is made once at docs time. Recorded for prompt 07; no change here.
- **R-5 Inherited resume gap** (spec Risk 6). A resume at `spec_analysis` after a per-issue gate was answered, but before that issue's D2 returned, re-dispatches D1 without the answers, so the gate is asked again. This is ship's existing behaviour, now per issue, and is not fixed here.
- **R-6 (closed by R-B2)** `bulk.md` is inside `skills.bats`' citation and pre-approvable checks from Phase B3 on. C1 and C5 GREEN also run the extracted `preapprovable_offenders` and a hand-written heading check.

## Approval (Phase C)

- Senior architect: APPROVED WITH NOTES on 2026-10-26T09:28:15Z (plan-review, full)
- Dependency graph: valid. Waves: 2 (C1 ∥ C2 ∥ C3 ∥ C4, then C5). Max wave width: 4. Cross-phase: Phase D's D2 must name C5 (it currently names C2).
- Notes for the consolidator: (1) resolved by R-C1/R-B2: CD-12's explicit form is the rule in every ship-milestone file, B-5 now says so, and B3's resolver maps `ship/SKILL.md`; C-1, C5's note, C-5's Phase E bullet and R-6 are corrected. (2) resolved by R-C2: C's H-2 owns `mode`; D dropped its H1.
- Plan content hash (SHA-256, before this section): 9476b12e2529e529d823b663fe4c6350b1c37e76d082b7aa073aa1d2017c648f (re-approved after reconciliation diff-review 2026-10-26T09:40:16Z; was 2604dc6dd72b…)

---

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

---

# Phase E plan — resume, status and static checks, then the docs and the simulated runs

- **Spec:** `docs/superpowers/specs/2026-10-26-milestone-mode.md` (senior APPROVED WITH NOTES · NOVEL · EPIC · hash `a1ec22d7…f4288e`).
- **Binding overrides:** `docs/superpowers/plans/phases/2026-10-26-milestone-mode-overrides.md` (they beat the spec-review notes, which beat the spec). For this phase: **cut 1** (M2 is dropped, so AC-32 is two probes, M1 and M3, and the budget is $37 against the $45 stop); **cut 2** (no doc-writer stacked summary line, so AC-34's stacked check is the introduction only, not a summary line naming the base branch); **cut 3** (old phases E and F merged into this one: resume and status come before the paid runs, which need them); the Q1 cap note (the kill stage is early in child 2, `brief`, and §9.1's "spend can pass the cap" rule holds).
- **Phase:** E of the EPIC. `depends_on: [C, D]` (wave 3). It consumes Phase A's script contracts, Phase B's skill names and its `skills.bats` registration, and the hook lines and reference sections of Phases C and D (see the interface contract). It provides `resume` and `status` for milestone runs, the no-pipeline-copy check, the closing docs and the live evidence.
- **Depth:** full
- **ACs covered:** AC-28, AC-29, AC-30, AC-25 (its last point, the `skills.bats` check), AC-31, AC-32 (M1 and M3, cut 1), AC-33, AC-34 (as amended by cut 2), AC-35.
- **Risk:** **paid headless sessions running the real orchestrator with Bash.** §9's rails 1 to 8 are binding for every paid session (E8–E10), and the launcher enforces them. No other risk line is crossed: no schema, auth, payments or dependency change, and the docs edits have no runtime effect.
- **Date:** 2026-10-26
- **Naming note:** task ids are `E1`–`E12`. Run names are the spec's (M1, M3, B1, Q1, Q2). Attempts are suffixed `.1`, `.2` (`B1.1`). "AC-n" and "Assumption n" are the spec's, "cut n" the CTO cut in the overrides, "X-n" this plan's interface items, and "PD-n" Phase B's decisions from prompt 05 (`docs/superpowers/plans/phases/2026-10-25-orchestrator-and-entry-skills-phase-B.md`).

> **For agentic workers:** implement task by task. E1–E3 are skill and test edits: RED is the updated bats test failing against today's files, GREEN is the same test passing. E4–E6 and E12 are documentation: RED is a grep count before the edit, GREEN the count after. E7 is free harness work. E8–E10 are paid sessions: start each one only through the launcher, and take every result from tool results, `system/init`, `calls.log` and artefacts, never from the model's prose. The strings, headings, commands and table formats marked **verbatim** are contracts. Everything else is content to write in your own words, in British English. **If a merged Phase A–D text differs from a string this plan consumes, the merged text wins: update the expected value here and in README §10 before the run that uses it, never after.**

**Goal:** `/aew:resume` and `/aew:status` handle bulk and sequential milestone runs; `skills.bats` proves that `ship-milestone` reuses ship rather than copying it; DESIGN, run-protocol, github-ops, the README, CHANGELOG, CLAUDE.md and the project map describe milestone mode; and five headless sessions (M1, M3, B1, Q1, Q2) prove the mode probes, a bulk run to one PR, and a sequential run killed in child 2, resumed, and stopped cleanly by a blocked child 3.

**Architecture:** two entry-skill edits (`skills/resume/SKILL.md`, `skills/status/SKILL.md`) that route on `mode` and hand a sequential run to Phase D's `sequential.md` `## Resume`; `tests/scripts/skills.bats` gains one test and updates three; five documentation files; and a new `## 10. Milestone mode (prompt 06)` in `tests/agent-smoke/README.md`, reusing §9's helpers, rails and launcher (copied with three harness-only changes). No script, hook, agent, template or schema changes. No new committed file.

**Tech stack:** Markdown skills; bats-core 1.14, bash 3.2, jq 1.7.1; `claude -p` 2.1.308 or later through `$SMOKE/ship-run.sh`.

## Context manifest (only what this phase reads)

| File | Why |
|---|---|
| `docs/superpowers/plans/phases/2026-10-26-milestone-mode-overrides.md` | Cuts 1–3, the serialised ship edits, the verified platform facts |
| `docs/superpowers/specs/2026-10-26-milestone-mode.md` | AC-25, AC-28–35, Assumptions 6, 8–14, 18, Risks 1–7, Conflicts C1–C4 |
| `skills/resume/SKILL.md` (68 lines; Step 2.3 at line 44, Step 3 at 46–51, Step 4 at 53–60, Step 5 at 62–68) | E1 edits it |
| `skills/status/SKILL.md` (94 lines; `## Show one run` at 43–79, `## Next action` at 81–94, the milestone line at 94) | E2 edits it |
| `tests/scripts/skills.bats` (537 lines; resume test 328–361, status test 363–399, citations 450–474, frontmatter YAML 476–496, test 17 at 519–527, test 18 at 529–537) | E1, E2 and E3 edit disjoint tests |
| `skills/ship/SKILL.md` (`## Run variables`, `## Step 3. Start the run` 3.7 slug filter at line 132, E3 at line 107) | Citations from resume; the slug filter for the forced block in Q2 |
| `skills/ship/references/gates.md` (`## Re-asking a pending gate`), `preflight.md` (`## Check 5. No other active run`) | What resume enters, and Phase D's Check 5 milestone exception (I-D6) that resume relies on without changing |
| `skills/ship-milestone/SKILL.md`, `references/{mode-selection,bulk,sequential}.md` (Phases B, C, D) | Headings and strings consumed (X-2–X-4); E3's check scans them |
| `scripts/gh-milestone.sh` (`--json number,title,labels,state,body,blockedBy,url` at line 76, plus `milestone` from Phase A), `scripts/state.sh --help` (`index`), `scripts/git-branch.sh` line 88 (`branch already exists: <b>`) | Expected values and the forced-block reason |
| `tests/scripts/helpers/bin/gh` (call-specific `<route>.<n>.out` first, then `<route>.out`) | Canned `issue-list.1`, `pr-create.1/.2` |
| `tests/agent-smoke/README.md` §9 (rails, 9.1 ledger rules, 9.2 helpers, `smoke_ship_allow`, launcher reference copy, 9.4 S1 checks, 9.6 kill-and-resume form), §9.10 (the latest record format and the open `grep -v` denial) | E7–E11 reuse and extend them |
| `tests/fixtures/apps/static-shop/` (`site/index.html` header, products and footer; `run/issue.json` as the issue template; `.aew/config.json`) | B1 and Q issues are written against it |
| `docs/DESIGN.md` §7.1 (lines 169–193), §9 line 521, §10 (lines 523–550) | E4 edits them |
| `skills/run-protocol/SKILL.md` `## Run directory` (12–41), `skills/github-ops/SKILL.md` (scripts table, Other calls, Conventions, Stdout contract) | E5 edits them |
| `README.md` `## Commands` (65–79), `### /aew:resume` (183–196), `### /aew:status` (198–210) | E6 edits them |
| `CHANGELOG.md` `## [Unreleased]`, `CLAUDE.md` `## Recent changes`, `docs/superpowers/project-map.md` | E12 appends |

Gotchas that apply (project map): `${CLAUDE_PLUGIN_ROOT}` is substituted only in the loaded skill body, so resume's new paths are absolute `${CLAUDE_PLUGIN_ROOT}/…`; headless pre-check rules (no `$VAR`, no `$(…)`, jq `--arg` after the filter, printed checks) bind every command in resume and status (tests 17 and 18); a bare `! cmd` in bats never fails a test (use the helpers); an awk extractor must track "inside block" so a heredoc `### ` line does not end it; the Bash guard blocks any command text containing `git push`, so launches go in script files; macOS `/var` is `/private/var`; `grep -c` exits 1 on a zero count; never run two QA sessions at once (port 4173).

## Phase entry checks (free; run before E1)

Every consumed contract must hold at the merged C+D state. A failure is a contract breach: stop and report it to the orchestrator. Do not patch another phase's files from here, except under E3's or the paid tasks' fix loop.

```sh
cd /Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
tests/run-script-tests.sh                                                        # green
for f in SKILL.md references/mode-selection.md references/bulk.md references/sequential.md; do test -f "skills/ship-milestone/$f" && echo "ok $f" || echo "MISSING $f"; done
for h in '## Start a child' '## After a child' '## Resume'; do printf '%s=%s\n' "$h" "$(grep -cxF "$h" skills/ship-milestone/references/sequential.md)"; done   # each =1
grep -c 'milestone m-' skills/ship-milestone/references/sequential.md            # >= 1 (the child note)
grep -c 'gate:spec issues/<k>/01-spec-analysis.md' skills/ship-milestone/references/bulk.md   # >= 1
grep -c 'use /aew:ship-milestone <n>' skills/ship/SKILL.md                      # >= 1 (E3 reworded)
grep -c 'later release' skills/ship/SKILL.md tests/scripts/skills.bats          # 0 and 1 (skills.bats keeps the resume string at line 356 until E1)
grep -c 'Milestone runs: also pass when one of' skills/ship/references/preflight.md   # 1 (Phase D I-D6, symmetric Check 5)
grep -c 'issues/<k>/01-spec-analysis.md' skills/ship/references/gates.md          # >= 1 (Phase C H-8/H-10, the per-issue gate in Re-asking)
grep -cE 'sequential' tests/scripts/skills.bats                                  # >= 1 (citation resolver maps sequential.md)
scripts/gh-milestone.sh --help | grep -c 'select'; scripts/state.sh --help | grep -c 'index'   # >= 1, >= 1
ls tests/scripts/fixtures/milestone/                                             # record the AC-5 fixture names (X-1.3)
```

## Interface contract

### Consumed

**X-1. From Phase A (deterministic layer).**

1. `gh-milestone.sh select <milestone>`: one `gh issue list` call, stdout one JSON object `{milestone: {number, title}, issues: [{number, title, labels, depends_on, ac_count, stack_on}], closed, order, cycle, stack_conflicts, recommend, reasons}` (AC-1). E7 runs it free against the canned listings to get every expected value.
2. `state.sh index` owns `.aew/runs/m-<n>/index.json`, format `{run_id, order, children: [{issue, stack_on, status}]}`, `status` one of `pending | running | done | blocked | failed` (AC-7). `status` (E2) reads `.children[] | .issue, .status`. `state.sh init <m-id> --mode bulk` creates `issues/<k>/` (AC-6).
3. The AC-5 fixtures under `tests/scripts/fixtures/milestone/`: each is a raw `gh issue list --json …` reply array (the `issues.json` form, with `milestone` on every issue), usable unchanged as `$GHM/responses/issue-list.1.out`. E8 uses `small-related.json` (three small related issues) for M1 and `chain.json` (dependency chain) for M3 (Phase A1's names; the entry checks confirm them). **Requirement on A:** the bulk fixture's titles and labels must read as one area and low risk (for example a shared area label and no risk-sounding title), because M1 is the run where the `mode-selection.md` judgement must leave bulk standing (cut 1's reason). E7 checks this by eye before any paid run.

**X-2. From Phase B (ship-milestone entry and reports).**

1. Files: `skills/ship-milestone/SKILL.md` (frontmatter `disable-model-invocation: true`, `argument-hint: "<milestone> [--bulk|--sequential] [--auto]"`) and `references/mode-selection.md`, `bulk.md`, `sequential.md`. Resume cites the first and last by their absolute `${CLAUDE_PLUGIN_ROOT}/…` paths.
2. `skills.bats` registration by B: `ENTRY` includes `ship-milestone`; the `disable-model-invocation` test and the argument-hint `case` cover it; the citation resolver maps `` `ship-milestone/SKILL.md` `` to `skills/ship-milestone/SKILL.md`, `` `ship/SKILL.md` `` to `skills/ship/SKILL.md`, and `` `mode-selection.md` ``, `` `bulk.md` ``, `` `sequential.md` `` to `skills/ship-milestone/references/`, and scans `skills/ship-milestone`. E1's resume citations rely on that mapping, and E extends the resolver only with the `` `resume/SKILL.md` `` mapping (E3, R-E5); every other resolver change is B3's (R-B2). Citation rule (R-C1): ship-milestone files cite `ship/SKILL.md` and `ship-milestone/SKILL.md` explicitly, never a bare `SKILL.md`. B3 (edits 1 and 6) also puts `ship-milestone` into the header comment, the frontmatter YAML test and tests 17 and 18; E3 only verifies those and raises their floors.
3. Printed strings the probes and runs check (AC-12, AC-27): `Mode: <mode> (given)`; the headless rerun hint `Rerun with /aew:ship-milestone <mn> --bulk` (or `--sequential`); the final report's first line `aew ship-milestone m-<mn> <title>: <done | stopped>` and its `Mode:`, `Shipped:`, `Blocked:`, `Not started:`, `Manual tests outstanding:`, `Retro items filed:`, `Next:` lines; `milestone-report.md` in `.aew/runs/m-<mn>/`, posted with `gh-issue.sh comment <k>` on every run issue (AC-26).
4. `select` runs once per session (Risk 4). E7 cans the listing on calls 1 and 2 anyway, and the checks record the count.

**X-3. From Phase C (bulk).**

1. Per-issue gate notes `gate:spec issues/<k>/01-spec-analysis.md` (AC-15). Phase C's H-10 puts the mapping (`<rd>` = `.aew/runs/m-<mn>/issues/<k>`, `<n>` = `k`) in `gates.md` `## Re-asking a pending gate`; resume (E1) only points to it.
2. ship's `## Stage: spec_analysis` bulk hook re-dispatches only the issues whose `01-spec-analysis.md` is not yet `ok`, so resume at `spec_analysis` adds nothing for bulk.
3. Brief H1 `# Brief: m-<mn> <milestone title>`, D3 with `issues: <a,b,c>`, prefixed ids `#<k>-AC-<n>`, QA evidence `docs/qa/m-<mn>/` and spec `<e2e_dir>/m-<mn>-<slug>.spec.ts`, per-issue `docs/specs/<k>-<slug>.md`, commits ending `(#a, #b, #c)` (AC-16–18, Assumption 9). B1 checks them.
4. The failed bulk rerun line (R-B1, verbatim, shared by C's CD-4/CD-5/H-12, B's BD-12 and E1/E2): `remove .aew/runs/m-<mn>, then rerun /aew:ship-milestone <mn> --bulk`. `<mn>` is the milestone number (Phase B's `<mn>`; in resume and status, the run id without `m-`).
5. bulk per-issue revisions: the history note `spec revision: #<k> v<N>` (C1 `## Spec analysis` step 4), plus ship's `## Recording a spec revision` comment, body marker and `aew:spec-revised` flag on that issue.

**X-4. From Phase D (sequential).**

1. `sequential.md` headings `## Start a child`, `## After a child`, `## Resume` (verbatim). `## Resume` (AC-28) takes the first child not `done` in the index, then keys on that child's own `state.json` (PD-D2): none → start it; `running`, `blocked` or a pending gate → run resume's `## Step 4. Checks` and `## Step 5. Continue` with that child's id; `failed` → print `/aew:ship <k> --from <stage>` and stop; `done` → `## After a child`; all `done` → finish. It never calls resume's Steps 1–3.
2. The child note `milestone m-<n>` straight after the child's `state.sh init` (AC-21), and the parent note `child #<k> <status>: <reason>` on a stop (AC-23).
3. `preflight.md` Check 5 passes when one of `current` and the run is `m-<n>` and the other is its child, in either direction (I-D6, PD-D3; AC-24 and AC-28). Resume adds no Check 5 rule of its own.
4. ship's child hand-backs (final report, blocked path, plan-gate stop, Step 3.3/3.4) go to `## After a child`, so a child continued by resume rejoins the sequence.

### Provided

**X-5. To Phase D (and any later reader).** `skills/resume/SKILL.md` keeps its headings verbatim (`## Step 4. Checks` and `## Step 5. Continue` are D's citation targets), and both steps act on whatever run id they are given, so `## Resume` can run them for a child. Resume redirects a `sequential-child` id to its parent in Step 2, which `## Resume` never re-enters, so there is no loop.

**X-6. Resume's routing (E1).** `single` and `bulk` continue in ship's sections; `sequential-child` → parent from the note → as `sequential`; `sequential` → Read `ship-milestone/SKILL.md` and `sequential.md`, enter `sequential.md` `## Resume`. A sequential parent skips the branch check. Check 5 needs nothing from resume: Phase D's symmetric milestone line covers `current` = a child while the parent resumes.

**X-7. The no-pipeline-copy rule (E3, AC-25).** No file under `skills/ship-milestone/` may contain a line matching `^## Stage: `, `^## Gate: `, `^\| D[0-9]+ \|`, `^\| Row \| Agent and mode \|` or `^[0-9]+\. (Set pending|Apply the answer):` (ship's stage headings, gate headings, dispatch rows and header, and gate step labels).

**X-8. Harness extensions (E7, README §10).** The launcher's `<kill-stage>` also takes `<run-id>:<stage>` (the poller then reads `.aew/runs/<run-id>/state.json` rather than `current`'s); `smoke_ship_allow` gains the `gh-milestone.sh` rules and `Bash(grep -v *)`; new helpers `smoke_ms_bodies`, `smoke_ms_issue`, `smoke_ms_listing`, `smoke_ms_expected`, `smoke_ms_rev`, `smoke_ms_stages`, `smoke_fanout`, `smoke_agent_prompts`. Prompt 07 can reuse them.

## Tasks

Waves: **1** = E1 ∥ E4 ∥ E5 ∥ E6 ∥ E7 · **2** = E2 · **3** = E3 · **4** = E8 · **5** = E9 · **6** = E10 · **7** = E11 · **8** = E12.

E1, E2 and E3 all edit `tests/scripts/skills.bats` (disjoint tests, but the resume and status tests are one line apart), so they are chained E1 → E2 → E3 rather than merged from parallel worktrees; each is small. E8–E11 all edit README §10, in their own subsections, one after another. E9 and E10 never overlap (port 4173). E8 runs first because it is a $2 check of the shared entry path (preflight, `select`, Check 5) before the larger sessions.

Commit trailer for every commit in this phase (CLAUDE.md overrides the session's attribution): `Co-Authored-By: Claude <noreply@anthropic.com>`.

---

### Task E1 — `resume` continues bulk and sequential runs (AC-28, AC-30)

- **id:** E1
- **files:** `skills/resume/SKILL.md`, `tests/scripts/skills.bats` (the "resume: re-asks a pending gate…" test only, lines 328–361)
- **depends_on:** [] (phase-level: C, D)
- **pattern:** resume's own prompt-mode handling (a check in Step 2, then a hand-over in Step 5 to another skill's section by citation); the `prompt` marker `jq` precedent for the `milestone m-` note.
- **ACs:** AC-28; AC-30 (resume's citations and contract strings)

**Step 1: RED.** In the resume test, replace the present-list line `aew resume: run <id> is a <mode> run; milestone runs are resumed by /aew:ship-milestone (coming in a later release).` with these lines (verbatim), and add the two checks after the `gates.md` heading check:

```
${CLAUDE_PLUGIN_ROOT}/skills/ship-milestone/SKILL.md
${CLAUDE_PLUGIN_ROOT}/skills/ship-milestone/references/sequential.md
`sequential.md` `## Resume`
sequential-child
startswith("milestone m-")
Run <id> is part of milestone run <parent>: continuing the milestone.
issues/<k>/
remove .aew/runs/m-<mn>, then rerun /aew:ship-milestone <mn> --bulk
```

```bash
  bad="$bad$(absent_fixed "$f" 'coming in a later release')"
  [ "$(grep -cxF '## Resume' "$REPO_ROOT/skills/ship-milestone/references/sequential.md" || true)" -eq 1 ] || bad="${bad}sequential.md lacks '## Resume'"$'\n'
```

```sh
bats -f 'resume: re-asks' tests/scripts/skills.bats      # 1 test, fails: the eight strings missing, "must not contain: coming in a later release"
```

**Step 2: edit `skills/resume/SKILL.md`** (exact text where shown; keep every heading as it is, X-5):

- Frontmatter `description` (one line, no unquoted `: `): `Continue an interrupted aew run from its state.json - re-asks a pending gate, or re-enters the ship procedure at the recorded stage after checking the branch and working tree. A bulk milestone run continues like one issue, a sequential one at its first unfinished child. Run it as /aew:resume [<run-id>].`
- Intro paragraph: add one sentence, "Milestone runs (`m-<n>`) are resumed as well: a bulk run as one pipeline, a sequential run at its first unfinished child."
- `## Plugin root`, first bullet: add "For a sequential milestone run, also read `${CLAUDE_PLUGIN_ROOT}/skills/ship-milestone/SKILL.md` and `${CLAUDE_PLUGIN_ROOT}/skills/ship-milestone/references/sequential.md`." Third bullet: "Never invoke `ship`, `ship-milestone` or `prompt` with the Skill tool: all three set `disable-model-invocation: true`, which blocks it." Fourth bullet: add "`` `ship-milestone/SKILL.md` `` is `skills/ship-milestone/SKILL.md`, and `` `sequential.md` `` is under `skills/ship-milestone/references/`."
- `## Step 2. Read the state`, item 3 replaced by:

~~~markdown
3. The mode decides how the run continues. Nothing is written here.
   - `single`: as below.
   - `bulk`: as below, like `single`. Ship's sections carry the bulk hooks into `bulk.md`, and `<n>` means each issue in `issues` (`SKILL.md` `## Run variables`).
   - `sequential-child`: find the milestone run it belongs to:
     `jq -r '[.history[] | select((.note // "") | startswith("milestone m-"))] | first | .note // "" | ltrimstr("milestone ")' .aew/runs/<id>/state.json`
     Empty output stops with `aew resume: run <id> has no "milestone m-<n>" note.` Otherwise print `Run <id> is part of milestone run <parent>: continuing the milestone.`, take `<parent>` as `<id>` from here on, and run Step 1's `state.json` test and items 1 and 3 of this step again for it. A parent that is not a `sequential` run stops with `aew resume: <parent> is not a sequential milestone run.`
   - `sequential`: a milestone run whose children are runs of their own. Step 3 applies as written, Step 4 skips item 4, and Step 5 hands over at item 2.
~~~

- `## Step 3. Finished runs`: `done` bullet adds "For a `sequential` run, print `See /aew:status <id> for each child and its PR.` instead of the PR line." `failed` bullet adds "For a `bulk` run, print instead `Run <id> failed at <stage> and is finished: remove .aew/runs/m-<mn>, then rerun /aew:ship-milestone <mn> --bulk.` (`<mn>` is the id without `m-`)." (X-3.4)
- `## Step 4. Checks`: item 1 is unchanged (Check 5's milestone exception is Phase D's, I-D6; resume adds no Check 5 text). Item 4 adds, before the existing sentence: "A `sequential` run skips this item: its `branch` is null, and `sequential.md` `## Resume` checks each child's branch. For a `bulk` run, a null `branch` stops with `Run <id> has no branch: remove .aew/runs/m-<mn>, then rerun /aew:ship-milestone <mn> --bulk.`"
- `## Step 5. Continue`: after item 1, a new item 2 (the later items renumber):

~~~markdown
2. Mode `sequential`: Read `${CLAUDE_PLUGIN_ROOT}/skills/ship-milestone/SKILL.md` and `${CLAUDE_PLUGIN_ROOT}/skills/ship-milestone/references/sequential.md`, then follow `sequential.md` `## Resume`. It acts on the first child whose index status is not `done`, and for a child that has started it runs this file's `## Step 4. Checks` and `## Step 5. Continue` with that child's id. The items below then apply to the child, never to the parent.
~~~

  The gate item (now 3) adds: "In a `bulk` run, a note `gate:spec issues/<k>/01-spec-analysis.md` is issue `k`'s gate; `gates.md` `## Re-asking a pending gate` sets its `<rd>` and `<n>`." The last item adds "and never re-runs a finished child".
- Size: about 85 lines. Exactly one `$ARGUMENTS`, no `$N`.

**Step 3: GREEN.**

```sh
bats -f 'resume: re-asks' tests/scripts/skills.bats       # ok
bats tests/scripts/skills.bats                             # all pass (citations resolve, tests 17 and 18 clean for resume)
grep -c 'later release' skills/resume/SKILL.md             # 0
claude plugin validate .                                   # passes (existing warnings only)
git diff --stat                                            # skills/resume/SKILL.md, tests/scripts/skills.bats
```

**Step 4: commit.**

```
feat(resume): continue bulk and sequential milestone runs

A bulk run continues in ship's sections like a single run, with per-issue
gates taken from the note path. A sequential run, or any of its children,
hands over to ship-milestone's sequential.md "## Resume", which acts on the
first unfinished child. The "coming in a later release" stop goes.

Co-Authored-By: Claude <noreply@anthropic.com>
```

---

### Task E2 — `status` shows milestone runs (AC-29, AC-30)

- **id:** E2
- **files:** `skills/status/SKILL.md`, `tests/scripts/skills.bats` (the "status: reads only…" test only, lines 363–399)
- **depends_on:** [E1] (shared `skills.bats`)
- **pattern:** status's own list read (one `jq` over literal paths, `input_filename` for the id, `2>/dev/null` fallback) and its prompt-marker check.
- **ACs:** AC-29; AC-30 (status's contract strings)

**Step 1: RED.** Add to the status test's `present` list (verbatim):

```
.aew/runs/<id>/index.json
| Child | Index | Status | Stage | PR |
startswith("milestone m-")
Part of milestone run m-<n>.
/aew:resume m-<n>
```

and to its `absent_fixed` list: `gh-milestone.sh` and `coming in a later release`.

```sh
bats -f 'status: reads only' tests/scripts/skills.bats    # fails: five strings missing, "must not contain: coming in a later release"
```

**Step 2: edit `skills/status/SKILL.md`.** Headings unchanged. `## List every run` unchanged (AC-29: mode-agnostic; child runs `.aew/runs/<k>` list as ordinary runs). In `## Show one run`, replace step 6 with:

~~~markdown
6. Milestone runs, by the `mode` line of step 2:
   - `sequential`: the children. First the index, in order:

     ```sh
     jq -r '.children[] | [.issue, .status] | map(tostring) | @tsv' .aew/runs/<id>/index.json
     ```

     Then one read of every child's `state.json`, each written as its literal path in index order. A child that has not started has no `state.json` and gives no line:

     ```sh
     jq -r 'input_filename as $f | ($f | split("/") | .[-2]) as $k | [$k, .status, .stage, (.pr // "-" | tostring)] | @tsv' .aew/runs/<k1>/state.json .aew/runs/<k2>/state.json 2>/dev/null
     ```

     Print `| Child | Index | Status | Stage | PR |`, one row per index child, with `-` where its `state.json` gave no line. A missing or unreadable `index.json`: say so, naming `.aew/runs/<id>/index.json`.
   - `sequential-child`: the milestone it belongs to:

     ```sh
     jq -r '[.history[] | select((.note // "") | startswith("milestone m-"))] | first | .note // "" | ltrimstr("milestone ")' .aew/runs/<id>/state.json
     ```

     Print `Part of milestone run m-<n>.`, with `m-<n>` from that output (nothing when it is empty).
   - `bulk`: nothing more. One run covers every issue in `issues`, and a pending gate's note names the issue's file (`issues/<k>/01-spec-analysis.md`).
7. Go to `## Next action`.
~~~

In `## Next action`, replace the last line ("A run whose `mode` is not `single` …") with:

~~~markdown
Milestone runs use the rows above with their own id (`/aew:resume m-<n>`), and these as well:

| Run | Next action |
|---|---|
| Sequential, `running` or `blocked` | Look at the first child in the table that is not `done`. A `failed` child: `/aew:ship <k> --from <stage>`, then `/aew:resume m-<n>`. A `blocked` child: fix the reason (`/aew:status <k>`), then `/aew:resume m-<n>`. Otherwise: `/aew:resume m-<n>`. |
| Sequential, `done` | Nothing to do: each child has its own PR (the table above). Merge stacked PRs in order. |
| Sequential child | Part of milestone run m-<n>: `/aew:resume m-<n>` (or `/aew:resume <k>`) continues the milestone. A `failed` child is restarted with `/aew:ship <k> --from <stage>` first. |
| Bulk, `failed` | Finished: remove .aew/runs/m-<mn>, then rerun /aew:ship-milestone <mn> --bulk (`<mn>` is the id without `m-`). |
~~~

The six `` | `<status>` | `` rows stay exactly one each (the new rows start with a word, not a backticked status). No script, git or gh name is added.

**Step 3: GREEN.**

```sh
bats -f 'status: reads only' tests/scripts/skills.bats    # ok
bats tests/scripts/skills.bats                             # all pass (test 17: the new jq forms are pre-approvable)
printf '{"run_id":"m-3","order":[311,312,313],"children":[{"issue":311,"stack_on":null,"status":"done"},{"issue":312,"stack_on":311,"status":"running"},{"issue":313,"stack_on":312,"status":"pending"}]}\n' > tests/tmp/index-probe.json
jq -r '.children[] | [.issue, .status] | map(tostring) | @tsv' tests/tmp/index-probe.json   # 311 done / 312 running / 313 pending
rm tests/tmp/index-probe.json
git diff --stat                                            # skills/status/SKILL.md, tests/scripts/skills.bats
```

**Step 4: commit.**

```
feat(status): show a sequential run's children and a child's milestone

Show one run prints the index as a table with each child's status, stage
and PR, marks a child with its milestone run, and the next-action section
gains the milestone rows. Still read-only, with no script.

Co-Authored-By: Claude <noreply@anthropic.com>
```

---

### Task E3 — `skills.bats`: no pipeline copy in `ship-milestone`, and its files in the shared checks (AC-25, AC-30)

- **id:** E3
- **files:** `tests/scripts/skills.bats` (floors in the frontmatter YAML test 476–496 and test 17 at 519–527, one `resume/SKILL.md` line in the citation resolver, one appended test); `skills/ship-milestone/**` **only** to fix an offender these checks find (fix loop)
- **depends_on:** [E2] (shared `skills.bats`)
- **pattern:** the "ship: no mktemp anywhere under skills/ship" test (a scan of one skill directory) and the `absent_regex` / `report_offenders` helpers.
- **ACs:** AC-25 (last point), AC-30

**Step 1: RED.**

1. Phase B3 (edit 6) already added `ship-milestone` and `skills/ship-milestone/references/*.md` to the frontmatter YAML test and tests 17 and 18: verify the loops, then raise the floors only, the YAML test to `[ "$n" -ge 13 ]` and test 17 to `[ "${#files[@]}" -ge 15 ]`. If B's loops are missing, that is a contract breach: report it, do not add them here.
2. Append the new test (verbatim):

```bash
@test "ship-milestone: no stage sections, dispatch rows or gate steps (it reuses ship)" {
  local d="$REPO_ROOT/skills/ship-milestone" f bad="" n=0
  [ -d "$d" ] || { echo "skills/ship-milestone is missing" >&2; return 1; }
  while IFS= read -r f; do
    n=$((n + 1))
    bad="$bad$(absent_regex "$f" '^## Stage: 
^## Gate: 
^\| D[0-9]+ \|
^\| Row \| Agent and mode \|
^[0-9]+\. (Set pending|Apply the answer):')"
  done < <(find "$d" -type f -name '*.md')
  [ "$n" -eq 4 ] || bad="${bad}want 4 files under skills/ship-milestone, found $n"$'\n'
  report_offenders "pipeline copy in ship-milestone (AC-25)" "$bad"
}
```

3. Prove it bites (mutation RED), then undo:

```sh
printf '\n## Stage: brief\n| D3 | x |\n' >> skills/ship-milestone/references/bulk.md
bats -f 'no stage sections' tests/scripts/skills.bats     # fails: bulk.md must not match ^## Stage: and ^\| D[0-9]+ \|
git restore skills/ship-milestone/references/bulk.md
```

4. Header comment: Phase B3 (edit 1) owns it; only verify it says six entry skills.
5. Citation resolver (R-E5): add `resume/SKILL` to the test's `grep -oE` alternation and `resume/SKILL.md) p=skills/resume/SKILL.md ;;` to its `case`, so Phase D's `` `resume/SKILL.md` `## Step 4. Checks` `` and `` `resume/SKILL.md` `## Step 5. Continue` `` citations in `sequential.md` are checked. This is E's only resolver change; B3 already maps `ship/SKILL.md`, `ship-milestone/SKILL.md` and the three reference names (R-B2). Mutation RED, then undo:

```sh
sed -i '' 's/`resume\/SKILL.md` `## Step 4. Checks`/`resume\/SKILL.md` `## Step 9. Checks`/' skills/ship-milestone/references/sequential.md
bats -f 'citation resolves' tests/scripts/skills.bats     # fails: sequential.md unresolved resume/SKILL.md ## Step 9. Checks
git restore skills/ship-milestone/references/sequential.md
```

**Step 2: GREEN.**

```sh
bats tests/scripts/skills.bats      # all pass; the new test is ok; test 17 and test 18 now cover ship-milestone's four files
tests/run-script-tests.sh           # shellcheck clean, every bats file passes
```

If test 17 or 18 names an offender in `skills/ship-milestone/**` (a command that is not pre-approvable headless, or a silent check), fix the command there in the form the other skills use (for example `test -e x && echo exists || echo absent`), in this task, and say so in the commit body.

**Step 3: commit.**

```
test(skills): check ship-milestone reuses ship and holds the headless rules

A new test refuses stage sections, gate sections, dispatch rows and gate
steps anywhere under skills/ship-milestone (AC-25). The frontmatter check
and the pre-approvable and printed-check tests now cover its four files.
The citation resolver also maps resume/SKILL.md, so sequential.md's
citations into resume's Steps 4 and 5 are checked.

Co-Authored-By: Claude <noreply@anthropic.com>
```

---

### Task E4 — DESIGN §7.1, §9 and §10 (AC-31)

- **id:** E4
- **files:** `docs/DESIGN.md`
- **depends_on:** []
- **pattern:** §7.1's table and its "Flat files" paragraph; §9's prompt-mode bullet; the prompt-05 "deviations" commit (`docs(design): record the prompt-05 platform facts, deviations and gate rules`) for how a deviation is worded.
- **ACs:** AC-31 (DESIGN part)

**Step 1: RED.**

```sh
for p in 'index.json' 'milestone-report.md' 'skills/ship-milestone/' 'issues/<k>/' 'Recorded deviations (prompt 06)'; do printf '%s=%s\n' "$p" "$(grep -cF -- "$p" docs/DESIGN.md)"; done   # all 0 (checked 2026-10-26)
grep -c 'runs only until milestone mode' docs/DESIGN.md                                  # 1
```

**Step 2: edits.**

- §7.1: three rows after `prompt.md`: `issues/<k>/` (bulk only: per issue `issue.json`, `00-issue-original.md`, `01-spec-analysis.md`, `spec-final.md`, `spec-changes.json`, `spec-revision-v<N>.md`; writers as for the root files); `index.json` (sequential only: order, each child's `stack_on` and milestone status; written only by `state.sh index`); `milestone-report.md` (milestone runs: the orchestrator, with Write). One sentence after the table: a sequential run's children are ordinary runs `.aew/runs/<k>/` beside `m-<n>`, linked by the index and the child's history note `milestone m-<n>`; a bulk issue's spec version is the history note `spec revision: #<k> v<N>` (Assumption 6, no schema change).
- §9 line 521: replace "`resume` continues `single` runs only until milestone mode (§10, prompt 06); `status` shows every mode." with: "`resume` continues every mode: a bulk run like a single one, and a sequential run (or any of its children) at its first unfinished child, through `skills/ship-milestone/references/sequential.md`. `status` shows every mode, and a sequential run's children."
- §10: under the syntax line, "Procedure detail: `skills/ship-milestone/` (`SKILL.md`, `references/mode-selection.md`, `bulk.md`, `sequential.md`); the deterministic part is `gh-milestone.sh select` and `state.sh index`." The small-issue bullet becomes "each issue small (5 ACs or fewer by a quick count of the issue's acceptance-criteria list)". After the dependency bullet, the rules in one bullet each: a dependency blocks bulk unless it is a closed issue of this milestone (Assumption 3); order is Kahn's over open in-milestone edges, lowest number first; a stacked child branches from the latest of its dependencies in `order`, and two open dependencies that are not one chain stop a sequential run before anything is written (Assumption 12); stacking is decided without a `gh` call (Assumption 11); aew never merges or retargets a stacked PR, so merge them in order (Risk 3). Then a `**Recorded deviations (prompt 06).**` list: **C1** the AC count is the script's quick count, not a spec analysis (the wording above replaces "once analysed"; James confirms at plan approval); **C2** a cycle or stack conflict stops before any write and asks in its message, not through AskUserQuestion; **C3** bulk QA evidence goes to `docs/qa/m-<n>/` (not §6's `docs/qa/<issue>/`); the prompt's `gh-milestone.sh issues` fetch is the new `select` subcommand of the same script, which reuses its `gh` call; **C4** the run dir gains `issues/<k>/` and `index.json` (§7.1), with no renamed artefact; cut 2: the stacked PR carries the stacked introduction only, with no extra summary line; **AC-24 over AC-25** (R-D2): AC-25 lets `preflight.md` gain only the bulk path overrides, but `preflight.md` `## Check 5. No other active run` also gains the two-way milestone exception that AC-24 requires (Phase D I-D6, PD-D3), as one continuation line.

**Step 3: GREEN.**

```sh
for p in 'index.json' 'milestone-report.md' 'skills/ship-milestone/' 'issues/<k>/' 'Recorded deviations (prompt 06)' 'quick count' 'AC-24 over AC-25'; do printf '%s=%s\n' "$p" "$(grep -cF -- "$p" docs/DESIGN.md)"; done   # >= 1 each
grep -n 'once analysed' docs/DESIGN.md                                                   # one line only: the C1 deviation quoting the old wording
grep -c 'runs only until milestone mode' docs/DESIGN.md                                  # 0
git diff --stat                                                                          # docs/DESIGN.md only
```

**Step 4: commit.** `docs(design): record milestone mode's run layout, resume and deviations` (body: the §7.1 rows, the §9 resume line, the §10 rules and deviations C1–C4 and AC-24 over AC-25; trailer).

---

### Task E5 — run-protocol and github-ops (AC-31)

- **id:** E5
- **files:** `skills/run-protocol/SKILL.md`, `skills/github-ops/SKILL.md`
- **depends_on:** []
- **pattern:** the existing table rows and the "Other calls", Exceptions and Stdout contract lines (the prompt-05 A3 edit of `gh-pr.sh open` is the model).
- **ACs:** AC-31 (run-protocol and github-ops)

**Step 1: RED.**

```sh
for p in 'index.json' 'issues/<k>/' 'milestone-report.md' 'docs/qa/m-'; do printf 'rp %s=%s\n' "$p" "$(grep -cF -- "$p" skills/run-protocol/SKILL.md)"; done   # all 0
for p in 'gh-milestone.sh select' 'state.sh index'; do printf 'gho %s=%s\n' "$p" "$(grep -cF -- "$p" skills/github-ops/SKILL.md)"; done   # 0 and 0 (if Phase A already added them, record it and only check them below)
```

**Step 2: edits.**

- run-protocol `## Run directory`: the same three rows as E4's §7.1 (`issues/<k>/…`, `index.json`, `milestone-report.md`), the children sentence, and in "Committed outputs" add `docs/qa/m-<n>/` for a bulk run.
- github-ops: the `gh-milestone.sh` row "Use it to" becomes "list a milestone's issues with parsed dependencies, or `select`: order, cycle, AC count, stacking and the mode recommendation", example unchanged; "Other calls" adds `gh-milestone.sh select 3`, `state.sh index init m-3 --stack-on 312:311,313:312`, `state.sh index set m-3 312 done`; Exceptions adds `gh-milestone.sh select <milestone>` and "`state.sh index` takes an explicit `m-<n>` id, not `current`"; Stdout contract: the `gh-milestone.sh` row reads "`issues`: a JSON array of `{number, title, labels, state, depends_on}`; `select`: one JSON object `{milestone, issues, closed, order, cycle, stack_conflicts, recommend, reasons}`", and the `state.sh` row adds `index`'s output exactly as `scripts/state.sh --help` states it.

**Step 3: GREEN.**

```sh
for p in 'index.json' 'issues/<k>/' 'milestone-report.md' 'docs/qa/m-'; do printf 'rp %s=%s\n' "$p" "$(grep -cF -- "$p" skills/run-protocol/SKILL.md)"; done   # >= 1 each
for p in 'gh-milestone.sh select' 'state.sh index'; do printf 'gho %s=%s\n' "$p" "$(grep -cF -- "$p" skills/github-ops/SKILL.md)"; done   # >= 2 each
claude plugin validate .                                                                  # passes
```

**Step 4: commit.** `docs(skills): document milestone run files, select and state.sh index` (trailer).

---

### Task E6 — README commands (AC-31)

- **id:** E6
- **files:** `README.md`
- **depends_on:** []
- **pattern:** the `### /aew:ship` subsection (syntax, examples, one paragraph of behaviour).
- **ACs:** AC-31 (README commands section)

**Step 1: RED.** `grep -c 'later release' README.md` → `1`; `grep -c '### /aew:ship-milestone' README.md` → `0`.

**Step 2: edits.** Commands table: a row `` | [`/aew:ship-milestone <milestone>`](#aewship-milestone) | Deliver a whole milestone, in one PR or one PR per issue | `` after the ship row; remove the "coming in a later release" paragraph (lines 78–79). A new `### /aew:ship-milestone` after `### /aew:ship`: syntax `/aew:ship-milestone <milestone> [--bulk|--sequential] [--auto]`; examples `/aew:ship-milestone 3`, `/aew:ship-milestone "Sprint 3" --sequential --auto`; one paragraph each on mode selection (the recommendation and one confirmation, or the flag), bulk (one branch, one PR closing every issue), sequential (one ship run per issue in dependency order, stacked PRs on the dependency's branch, to be merged in order; a blocked or failed child stops the sequence) and the milestone report comment on every issue. `### /aew:resume`: add "A milestone run (`/aew:resume m-3`) continues too: bulk like one issue, sequential at its first unfinished child; a child's id continues its milestone." `### /aew:status`: add "For a sequential milestone run it lists each child with its status, stage and PR."

**Step 3: GREEN.** `grep -c 'later release' README.md` → `0`; `grep -c '### /aew:ship-milestone' README.md` → `1`; `grep -c '(#aewship-milestone)' README.md` → `1`.

**Step 4: commit.** `docs(readme): document /aew:ship-milestone and milestone resume and status` (trailer).

---

### Task E7 — Harness: README §10 skeleton, ledger, launcher copy, allowlist, helpers and free dry-runs (AC-32–35 form)

- **id:** E7
- **files:** `tests/agent-smoke/README.md` (§9.2 `smoke_ship_allow`: two lines; new `## 10. Milestone mode (prompt 06)` with 10.1, 10.2 and the headings of 10.3–10.7). Outside the repo, never committed: `$SMOKE/ship-run.sh` (the launcher copy), `$SMOKE/ledger-06/`.
- **depends_on:** []
- **pattern:** §9 intro and rails, §9.1 ledger rules, §9.2 helpers and their `awk` loader, §9.10's rebuilt-launcher note (a copy with a recorded `diff`).
- **ACs:** AC-35 (form), and the setup that AC-32–34 depend on
- **Spend cap:** $0 (no Claude session)

**Step 1: RED.** `grep -c '^## 10\. ' tests/agent-smoke/README.md` → `0`; `grep -c 'gh-milestone' tests/agent-smoke/README.md` → `0`.

**Step 2: write §10.** Headings (verbatim, in this order):

```
## 10. Milestone mode (prompt 06)
### 10.1 Spend ledger (prompt 06, stop at $45)
### 10.2 Harness
#### Helpers (section 10)
#### Free checks (section 10)
### 10.3 M1 and M3: mode probes
### 10.4 B1: `/aew:ship-milestone 2 --bulk --auto` to one mocked PR
### 10.5 Q1 and Q2: sequential, killed in child 2, resumed, child 3 blocked
### 10.6 Acceptance criteria (build prompt 06)
### 10.7 Notes (prompt 06)
```

- **Intro:** §9's rails 1 to 8 apply unchanged to every session. Rail 9 (re-run P0 when the launcher's environment lines change) does not trigger: the copy below changes no environment line (§9.10 precedent). Transcripts, streams and `$SMOKE` are never committed. Each run records in its own subsection.
- **10.1:** caps M1 1, M3 1, B1 15, Q1 8, Q2 12: $37 against a **stop of $45** (kept; R-E1, James confirms at plan approval). The $8 margin fits only a probe re-run (M1.2 or M3.2, $1 each). Any larger fallback (a B1 raise or re-run, a Q1 raise, a Q2 re-run) stops the run sequence and asks James to raise the stop; it never starts within $45. §9.1's rules otherwise (reserve before start, refuse over the stop, one raise to 2x only if accepted, a killed or crashed session counts its cap, spend can pass the cap). Ledger `$SMOKE/ledger-06/`. The table (columns as §9.1) is filled by E11 only.
- **10.2, launcher:** `$SMOKE/ship-run.sh` is §9.2's reference copy (extracted with `awk '/^#### Launcher$/…'`) with these harness-only changes, recorded as the `diff`: `L="$HERE/ledger-06"`; the stop `60` → `45` in the `awk` test and its message; the usage comment's "prompt-05" → "prompt-06" and its "one $60 budget" → "$45"; and the `<run-id>:<stage>` kill form (X-8):

```bash
# after the argument line
KRUN=""; case $KSTAGE in *:*) KRUN=${KSTAGE%%:*}; KSTAGE=${KSTAGE#*:} ;; esac   # <run-id>:<stage> keys the kill on that run's state.json
# in the poller, replacing the current-run read
    id=${KRUN:-$(cat .aew/runs/current 2> /dev/null || true)}
```

- **10.2, allowlist:** edit §9.2's `smoke_ship_allow` (the README is the harness source): add `gh-milestone` to the `for s in state gh-issue …` list, and `"Bash(grep -v *)"` to group 1a with the comment "prompt 06: ship's return check `grep -v '^$' <file> | tail -n 4` since 6a66e42 (9.10 notes)". Every run in §10 uses `smoke_ship_allow ship`.
- **10.2, `#### Helpers (section 10)`:** one `sh` block, loaded like §9's (`eval "$(awk '/^#### Helpers \(section 10\)$/{f=1;next} f&&!b&&/^#+ /{exit} f&&/^```sh$/{b=1;next} f&&b&&/^```$/{b=0;next} f&&b' "$REPO/tests/agent-smoke/README.md")"`, after §9's loader):

```sh
# smoke_ms_bodies: the six issue bodies, written to $W/bodies/<n>.md (B1: 301-303, milestone 2; Q: 311-313, milestone 3)
# 302's AC 2 deliberately lacks the WCAG 2.2 AA clause the others carry: a non-material gap (rubric: "an accessibility requirement implied by WCAG 2.2 AA") that spec-analyser applies without a gate under --auto (R-E2). The viewport sentence stays, so no layout change can trip the tie-break into material.
smoke_ms_bodies() {
  mkdir -p "$W/bodies" || return 1
  cat > "$W/bodies/301.md" <<'EOF'
### Summary

The footer shows the shop's contact email, so shoppers know how to reach the shop.

### Acceptance criteria

1. The footer contains a link whose text is "hello@static-shop.test" and whose `href` is "mailto:hello@static-shop.test".
2. At desktop (1440×900) and mobile (390×844), the footer is visible without horizontal scrolling, and the page has no serious or critical accessibility violations against WCAG 2.2 AA.

### Out of scope

- a contact form.
EOF
  cat > "$W/bodies/302.md" <<'EOF'
### Summary

The footer carries the shop's copyright line.

### Acceptance criteria

1. The footer contains the fixed text "© 2026 Static Shop" (not computed from today's date).
2. At desktop (1440×900) and mobile (390×844), the footer is visible without horizontal scrolling.
EOF
  cat > "$W/bodies/303.md" <<'EOF'
### Summary

The footer shows the shop's opening hours instead of the fixture note.

### Acceptance criteria

1. The footer text "Static Shop, a test fixture." is replaced by "Open Monday to Friday, 9am to 5pm.".
2. At desktop (1440×900) and mobile (390×844), the footer is visible without horizontal scrolling, and the page has no serious or critical accessibility violations against WCAG 2.2 AA.
EOF
  cat > "$W/bodies/311.md" <<'EOF'
### Summary

Each product shows whether it is in stock.

### Acceptance criteria

1. Directly under its price, each of the three products ("Tea towel", "Mug" and "Notebook") shows the text "In stock".
2. At desktop (1440×900) and mobile (390×844), all three products and their stock text are visible without horizontal scrolling, and the page has no serious or critical accessibility violations against WCAG 2.2 AA.

### Out of scope

- changing any product's stock.
EOF
  cat > "$W/bodies/312.md" <<'EOF'
Depends on #311.

### Summary

The Notebook is out of stock.

### Acceptance criteria

1. The Notebook's stock text reads "Out of stock"; "Tea towel" and "Mug" still read "In stock".
2. The Notebook's "Add to basket" button has the `disabled` attribute, so it cannot be activated by mouse or keyboard; the other two buttons still work.
3. The page has no serious or critical accessibility violations against WCAG 2.2 AA.
EOF
  cat > "$W/bodies/313.md" <<'EOF'
Depends on #312.

### Summary

Shoppers can hide products that are out of stock.

### Acceptance criteria

1. Above the product list there is a checkbox labelled "Hide out-of-stock products", unchecked on load.
2. Checking it hides the Notebook; unchecking it shows the Notebook again.
EOF
}

# smoke_ms_issue <n> <title> <label> <milestone-number> <milestone-title>: $W/issues/<n>.json from #201's issue.json, seeded in the mock
smoke_ms_issue() {
  mkdir -p "$W/issues" &&
    jq --argjson n "$1" --arg t "$2" --arg l "$3" --argjson mn "$4" --arg mt "$5" --rawfile b "$W/bodies/$1.md" \
      '.number = $n | .title = $t | .body = $b | .url = "https://github.com/acme/static-shop/issues/\($n)"
       | .labels = [{name: $l}] | .milestone = {number: $mn, title: $mt}' "$SHOP_RUN/issue.json" > "$W/issues/$1.json" &&
    smoke_ship_issue "$1" "$W/issues/$1.json"
}

# smoke_ms_listing <n>...: the gh issue list reply (gh-milestone.sh's --json fields plus milestone), in the order given
smoke_ms_listing() {
  local n f=()
  for n in "$@"; do f+=("$W/issues/$n.json"); done
  jq -s '[.[] | {number, title, labels, state, body, blockedBy: [], url, milestone}]' "${f[@]}"
}

# smoke_ms_expected <listing-file> <milestone>: select's JSON from a throwaway mock, no session (the expected values)
smoke_ms_expected() {
  local d="$W/free-select"
  rm -rf "$d" && mkdir -p "$d/responses" && cp "$1" "$d/responses/issue-list.out" &&
    (cd "$P" && GH_MOCK_DIR="$d" PATH="$SHIM:$PATH" "$REPO/scripts/gh-milestone.sh" select "$2")
}

# smoke_ms_rev <dir-with-spec-changes.json> <k>: k, its recorded changes, then its revision comments, body markers and flag
smoke_ms_rev() {
  printf '%s changes=%s comment=%s marker=%s flag=%s\n' "$2" \
    "$(jq '.changes | length' "$1/spec-changes.json" 2> /dev/null || echo '?')" \
    "$(grep -cE "^issue comment $2 .*spec-revision-v[0-9]+\.md" "$GHM/calls.log" || true)" \
    "$(grep -c '^<!-- aew:spec v' "$GHM/issues/$2/body" || true)" \
    "$(grep -cx 'aew:spec-revised' "$GHM/issues/$2/labels" || true)"
}

# smoke_ms_stages <k>: the stage labels added to issue k, in order (no-op stage calls add none)
smoke_ms_stages() { awk -v k="$1" '$1 == "issue" && $2 == "edit" && $3 == k { for (i = 4; i < NF; i++)
  if ($i == "--add-label" && $(i + 1) !~ /spec-revised|manual-test-required/) printf "%s ", $(i + 1) } END { print "" }' "$GHM/calls.log"; }

# smoke_fanout <O> <subagent_type>: per main-thread message with that agent, how many calls it holds (AC-15: one line, 3)
smoke_fanout() { jq -rR --arg a "$2" 'fromjson? | select(.type == "assistant" and .parent_tool_use_id == null) | .message as $m
  | $m.content[]? | select(.type == "tool_use" and .name == "Agent" and .input.subagent_type == $a) | [$m.id, .id] | @tsv' "$1/stream.jsonl" \
  | sort -u | cut -f1 | uniq -c | awk '{print $1}'; }

# smoke_agent_prompts <O>: every Agent call on any thread: type TAB the first 160 characters of its prompt
smoke_agent_prompts() { jq -rR 'fromjson? | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use" and .name == "Agent")
  | [.input.subagent_type, (.input.prompt // "" | gsub("\n"; " ") | .[0:160])] | @tsv' "$1/stream.jsonl"; }
```

- **10.2, `#### Free checks (section 10)`** (record each output under it):

```sh
/bin/bash -n "$SMOKE/ship-run.sh" && npx --yes shellcheck "$SMOKE/ship-run.sh"           # no output
diff <(awk '/^#### Launcher$/{f=1} f&&/^```bash$/{b=1;next} b&&/^```$/{exit} b' "$REPO/tests/agent-smoke/README.md") "$SMOKE/ship-run.sh"   # only the X-8 lines, ledger-06, 45 and the usage word
# §9.2's harness checks: claude --version, the real-gh canary, the keychain check (unchanged)
smoke_ship_project dry shop && smoke_ms_bodies &&
  smoke_ms_issue 301 "Footer contact email" footer 2 "Shop footer" && smoke_ms_issue 302 "Footer copyright line" footer 2 "Shop footer" &&
  smoke_ms_issue 303 "Footer opening hours" footer 2 "Shop footer" && smoke_ms_issue 311 "Stock labels" stock 3 "Product stock" &&
  smoke_ms_issue 312 "Notebook out of stock" stock 3 "Product stock" && smoke_ms_issue 313 "Stock filter toggle" stock 3 "Product stock"
smoke_ms_listing 301 302 303 > "$W/b1-listing.json"; smoke_ms_listing 313 311 312 > "$W/q-listing.json"
smoke_ms_expected "$W/b1-listing.json" 2 | jq -c '{recommend, reasons, order, ac: [.issues[].ac_count]}'   # bulk, [], [301,302,303], [2,2,2]
smoke_ms_expected "$W/q-listing.json" 3 | jq -c '{recommend, order, stack: [.issues[] | [.number, .stack_on]], stack_conflicts}'   # sequential, [311,312,313], [[311,null],[312,311],[313,312]], []
for n in 311 312 313; do jq -r '.title | ascii_downcase | gsub("[^a-z0-9]+"; "-") | ltrimstr("-") | .[0:40] | rtrimstr("-")' "$W/issues/$n.json"; done   # ship 3.7's filter: stock-labels, notebook-out-of-stock, stock-filter-toggle
for f in small-related.json chain.json; do jq -c '[.[] | {number, title, labels: [.labels[].name], milestone}]' "$REPO/tests/scripts/fixtures/milestone/$f"; done   # X-1.3: record; the bulk titles read as one area, low risk
grep -ohE '`[a-z][a-z0-9.-]*( [^`]*)?`' "$REPO"/skills/ship-milestone/SKILL.md "$REPO"/skills/ship-milestone/references/*.md | awk '{print $1}' | tr -d '`' | sort -u   # each leading word is covered by smoke_ship_allow ship (record any gap and add its rule to 9.2 before E8)
rm -rf "$SMOKE/ship-dry"
```

`small-related.json` (milestone 2 "Shop polish", shared `shop` label) and `chain.json` (milestone 4) are Phase A1's names; if the entry checks recorded different merged names, use those in the README text itself.

**Step 3: GREEN.** `grep -c '^## 10\. ' tests/agent-smoke/README.md` → `1`; the ten headings above each occur once; the §10 loader defines `smoke_ms_bodies` (`command -v smoke_ms_bodies`); every free check prints its expected output; `git -C "$REPO" status --porcelain` shows only the README.

**Step 4: commit.** `test(agent-smoke): add the prompt-06 milestone harness and its free checks` (body: the launcher copy's changes, the two allowlist lines, the helpers; trailer).

---

### Task E8 — M1 and M3: mode probes (AC-32, cut 1)

- **id:** E8
- **files:** `tests/agent-smoke/README.md` (§10.3 only); fix files only under the fix loop (below).
- **depends_on:** [E1, E2, E3, E7]
- **pattern:** §9.3's P1 (a cheap probe that must stop before any write; evidence from tool results and `calls.log`).
- **ACs:** AC-32
- **Spend cap:** M1 $1, M3 $1.

**Run.** One project for both probes. Nothing is written, so only the mock's call log and counters are moved aside between them.

```sh
smoke_ship_project ms shop && P_REAL=$(cd "$P" && pwd -P) && smoke_ship_allow ship > "$W/allow-ship.txt"
FX="$REPO/tests/scripts/fixtures/milestone"
cp "$FX/small-related.json" "$GHM/responses/issue-list.1.out"; M=$(jq -r '.[0].milestone.number' "$FX/small-related.json")
smoke_ms_expected "$FX/small-related.json" "$M" > "$W/out/m1-expected.json"
"$SMOKE/ship-run.sh" "$REPO" "$W" M1.1 1 "$W/allow-ship.txt" "/aew:ship-milestone $M"
O="$W/out/M1.1"
```

Checks (M1; M3 identical with the chain fixture, attempt `M3.1`, `--sequential` in M-1, and M-3):

```sh
smoke_res "$O"                                                                          # M-1 one rationale paragraph, then "Rerun with /aew:ship-milestone <M> --bulk"; no "Mode: … (given)" line
smoke_init_evt "$O" '.tools | index("AskUserQuestion")'                                 # M-2 null (absent headless)
jq -r '.recommend, (.reasons | join("; "))' "$W/out/m1-expected.json"                    # M-3 the printed recommendation (and reasons) match; M3: the printed order equals .order and the stacked order equals each .stack_on
test -e "$P/.aew/runs" && ls -A "$P/.aew/runs" || echo absent                           # M-4 absent or empty: no run dir, no current
smoke_norm "$GHM/calls.log"                                                             # M-5 exactly: auth-status, issue-list (one select call; no edit, comment, label or pr route)
git -C "$P" status --porcelain; git -C "$P" branch --format='%(refname:short)'          # M-6 empty; main only
smoke_main "$O" | awk -F'\t' '$1 == "Agent" || $1 == "Write" || $1 == "Edit"'           # M-7 none
smoke_denials "$O"; ls -A "$W/ghcfg"                                                    # M-8 []; empty; launcher exit 0 and "audit clean"
smoke_init_evt "$O" '[.tools[] | select(startswith("mcp__notion") or startswith("mcp__claude_ai_"))]'   # M-8 [] (system/init lists no mcp__notion or mcp__claude_ai_* tool; R-E4)
# M1 only: M-9 the rationale names "same area" and "low risk" as met, from titles and labels only (quote it)
mv "$GHM/calls.log" "$O/calls.log"; rm -f "$GHM/counters/"*                             # before M3
```

For M3: `cp "$FX/chain.json" "$GHM/responses/issue-list.1.out"`, recompute `M` and `m3-expected.json`, then launch `M3.1`.

**Fix loop (E8–E10).** A failing check caused by a skill, script or agent defect is fixed in the file that owns it (any phase's), in its own commit (`fix(<scope>): …` with the trailer), and the run is repeated as the next attempt if the launcher accepts it. A harness fault is fixed in §10 or §9.2 and recorded. A refused session leaves its checks `open` and the task reports `DONE_WITH_CONCERNS`. If M1's judgement turns bulk into sequential, that is a finding, not a harness fault: record the rationale and stop for a decision (the fixture's titles, or the judgement text in `mode-selection.md`).

**Record:** one table `| run | check | result | notes |` in §10.3 (S1's form), one row per check per probe.

**Commit:** `test(agent-smoke): record the milestone mode probes M1 and M3` (trailer).

---

### Task E9 — B1: bulk to one mocked PR (AC-33)

- **id:** E9
- **files:** `tests/agent-smoke/README.md` (§10.4 only); fix files only under the fix loop.
- **depends_on:** [E8]
- **pattern:** §9.4 S1 (run block, then numbered checks, then the table).
- **ACs:** AC-33 (and live evidence for AC-14–19, AC-26, AC-27)
- **Spend cap:** $15. Port 4173 must be free.

```sh
lsof -nP -iTCP:4173 -sTCP:LISTEN                                                        # must print nothing
smoke_ship_project b1 shop && smoke_ms_bodies &&
  smoke_ms_issue 301 "Footer contact email" footer 2 "Shop footer" && smoke_ms_issue 302 "Footer copyright line" footer 2 "Shop footer" &&
  smoke_ms_issue 303 "Footer opening hours" footer 2 "Shop footer"
smoke_ms_listing 301 302 303 > "$GHM/responses/issue-list.1.out"; cp "$GHM/responses/issue-list.1.out" "$GHM/responses/issue-list.2.out"
P_REAL=$(cd "$P" && pwd -P); smoke_ship_allow ship > "$W/allow-ship.txt"
"$SMOKE/ship-run.sh" "$REPO" "$W" B1.1 15 "$W/allow-ship.txt" "/aew:ship-milestone 2 --bulk --auto"   # run_in_background
RUN="$P/.aew/runs/m-2"; O="$W/out/B1.1"; BR=$(jq -r .branch "$RUN/state.json")
```

```sh
jq -rR 'fromjson? | select(.type == "result") | .subtype' "$O/stream.jsonl"; jq -r '.mode, .stage, .status, (.issues | map(tostring) | join(","))' "$RUN/state.json"   #  1 success; bulk, pr, done, 301,302,303
smoke_state_valid "$RUN/state.json"; test -s "$P/.aew/runs/current" && echo set || echo cleared   #  2 valid; cleared
echo "$BR"; git -C "$W/origin.git" rev-parse "refs/heads/$BR"; git -C "$P" rev-parse "$BR"   #  3 feat/m2-shop-footer; equal
for k in 301 302 303; do ls "$RUN/issues/$k"; done                                       #  4 each: 00-issue-original.md, issue.json, 01-spec-analysis.md, spec-final.md, spec-changes.json
smoke_fanout "$O" aew:spec-analyser                                                      #  5 one line: 3 (AC-15, one message)
for k in 301 302 303; do smoke_ms_rev "$RUN/issues/$k" "$k"; done                        #  6 per issue: changes=0 -> comment=0 marker=0 flag=0; changes>0 -> all >= 1 (AC-33)
jq -r '[.history[].note // empty | select(startswith("spec revision: #"))] | join("; ")' "$RUN/state.json"   #  6 at least one `spec revision: #<k> v<N>` note (302 expected), each matching an issue with changes>0; no revised issue -> check 6 is `open`, not pass (R-E2)
head -n 1 "$RUN/02-brief.md"; grep -cE '#30[123]-AC-[0-9]+' "$RUN/02-brief.md"; smoke_agent_prompts "$O" | grep -c '^aew:brief-compiler.*issues: *301,302,303'   #  7 "# Brief: m-2 Shop footer"; >= 6; 1
grep -c '^pr create' "$GHM/calls.log"                                                    #  8 1
n=$(grep -n '^pr create' "$GHM/calls.log" | cut -d: -f1); B=$(ls "$GHM/files/$(printf %03d "$n")-"*)
for k in 301 302 303; do grep -c "Closes #$k" "$B"; done; "$REPO/scripts/check-pr-intro.sh" "$B" --issues 3; echo "exit $?"   #  9 1, 1, 1; exit 0
for k in 301 302 303; do smoke_ms_stages "$k"; grep '^aew:' "$GHM/issues/$k/labels"; done   # 10 each: aew:analysing … aew:ready-for-review; final labels ready-for-review (+ spec-revised where 6 says so)
grep -cE '^issue comment (301|302|303) .*milestone-report\.md' "$GHM/calls.log"; test -f "$RUN/milestone-report.md" && echo exists || echo absent   # 11 3; exists
grep -c '^issue list --repo acme/aew-retro' "$GHM/calls.log"; grep -cE '^issue list .*--milestone' "$GHM/calls.log"   # 12 1 (retro filed once); select calls: 1 (record 2 as Risk 4)
git -C "$P" ls-tree -r --name-only "$BR" -- docs/specs docs/qa/m-2 tests/e2e | sed -n '1,40p'   # 13 three docs/specs/30<k>-<slug>.md; docs/qa/m-2/…; tests/e2e/m-2-<slug>.spec.ts
git -C "$P" log --format=%s main.."$BR"                                                  # 14 orchestrator and QA commits end (#301, #302, #303); record the developer's
smoke_res "$O"                                                                           # 15 "Mode: bulk (given)", then "aew ship-milestone m-2 Shop footer: done", Mode:, Shipped: #301/#302/#303 → …/pull/7, Blocked: none, Not started: none, Manual tests outstanding:, Retro items filed:, Next:
smoke_denials "$O"; ls -A "$W/ghcfg"; git -C "$P" status --porcelain; git -C "$REPO" status --porcelain   # 16 []; empty; empty; this README plus intended fixes; launcher exit 0, audit clean
smoke_init_evt "$O" '[.tools[] | select(startswith("mcp__notion") or startswith("mcp__claude_ai_"))]'   # 16 [] (system/init lists no mcp__notion or mcp__claude_ai_* tool; R-E4)
```

Fallbacks: a stop at a spec gate under `--auto` (Risk 7; material changes always gate, even with `--auto`) is recorded with the questions. If 302's gap is the one gated, the analyser judged it material: record that as a finding. A re-run (`B1.2`, after tightening the body in `smoke_ms_bodies`, mock-only like §9.5's AC-4 change) or a raise to 30 does not fit the $45 stop: stop the run sequence and ask James to raise the stop first (R-E1).

**Record:** §10.4 table, one row per check, plus a verbatim copy of the PR introduction (it must read as the bulk variant).

**Commit:** `test(agent-smoke): record B1, a bulk milestone run to one PR` (trailer).

---

### Task E10 — Q1 and Q2: sequential, killed in child 2, resumed, child 3 blocked (AC-34, AC-28 live)

- **id:** E10
- **files:** `tests/agent-smoke/README.md` (§10.5 only); fix files only under the fix loop.
- **depends_on:** [E9] (port 4173 and budget order)
- **pattern:** §9.6 run F1 and R2 (kill by the poller, snapshot hashes, resume checks).
- **ACs:** AC-34 (cut 2: the stacked introduction, no summary line), AC-28 (live)
- **Spend cap:** Q1 $8 (killed, so charged in full), Q2 $12.

**Q1.**

```sh
lsof -nP -iTCP:4173 -sTCP:LISTEN                                                        # nothing
smoke_ship_project q shop && smoke_ms_bodies &&
  smoke_ms_issue 311 "Stock labels" stock 3 "Product stock" && smoke_ms_issue 312 "Notebook out of stock" stock 3 "Product stock" &&
  smoke_ms_issue 313 "Stock filter toggle" stock 3 "Product stock"
smoke_ms_listing 313 311 312 > "$GHM/responses/issue-list.1.out"; cp "$GHM/responses/issue-list.1.out" "$GHM/responses/issue-list.2.out"
printf 'https://github.com/acme/static-shop/pull/7\n' > "$GHM/responses/pr-create.1.out"; printf 'https://github.com/acme/static-shop/pull/8\n' > "$GHM/responses/pr-create.2.out"
P_REAL=$(cd "$P" && pwd -P); smoke_ship_allow ship > "$W/allow-ship.txt"
"$SMOKE/ship-run.sh" "$REPO" "$W" Q1.1 8 "$W/allow-ship.txt" "/aew:ship-milestone 3 --sequential --auto" 312:brief   # run_in_background
O="$W/out/Q1.1"; R="$P/.aew/runs"
```

```sh
cat "$O/killed-at"; jq -r '.stage, .status, .mode' "$R/312/state.json"                  # Q1-1 a timestamp; brief, running, sequential-child
jq -r '.status, .pr, .base_branch, .mode' "$R/311/state.json"; smoke_state_valid "$R/311/state.json"   # Q1-2 done, 7, main, sequential-child; valid
grep -c '^pr create --head feat/311-stock-labels --base main' "$GHM/calls.log"           # Q1-3 1
jq -r '[.children[] | "\(.issue):\(.status):\(.stack_on // "-")"] | join(" ")' "$R/m-3/index.json"   # Q1-4 311:done:- 312:running:311 313:pending:312
jq -r '.base_branch, .branch' "$R/312/state.json"; jq -r '[.history[].note // empty] | map(select(startswith("milestone m-"))) | .[0]' "$R/312/state.json"   # Q1-5 feat/311-stock-labels, feat/312-notebook-out-of-stock; milestone m-3
git -C "$P" merge-base --is-ancestor feat/311-stock-labels feat/312-notebook-out-of-stock && echo stacked || echo not-stacked   # Q1-5 stacked
test -e "$R/313" && echo exists || echo absent; git -C "$P" branch --list 'feat/313*'; cat "$GHM/issues/313/labels"   # Q1-6 absent; nothing; empty
jq -r '.mode, .status, .branch' "$R/m-3/state.json"; cat "$R/current"                    # Q1-7 sequential, running, null; 312
smoke_denials "$O"; ls -A "$W/ghcfg"; git -C "$REPO" status --porcelain                  # Q1-8 nothing (killed, no result); empty; this README; launcher exit 0, audit clean
```

**Between Q1 and Q2 (harness actions, in a script file):** hash what must not change, force child 3's block, snapshot.

```sh
(cd "$R" && find 311 -type f && find 312 -type f ! -name state.json ! -name log.md) | sort > "$W/out/q1-files.txt"
(cd "$R" && xargs shasum < "$W/out/q1-files.txt") > "$W/out/q1-artefacts.sha"
wc -l < "$R/312/log.md" > "$W/out/q1-312.lines"
git -C "$P" branch feat/313-stock-filter-toggle main                                     # child 3's branch exists, so git-branch.sh create refuses it
rm -rf "$SMOKE/snap-q1" && cp -Rp "$W" "$SMOKE/snap-q1"                                  # restore with cp -Rp for a Q2.2
```

**Q2.**

```sh
"$SMOKE/ship-run.sh" "$REPO" "$W" Q2.1 12 "$W/allow-ship.txt" "/aew:resume m-3"          # run_in_background
O="$W/out/Q2.1"; L0=$(cat "$W/out/q1-312.lines")
```

```sh
jq -rR 'fromjson? | select(.type == "result") | .subtype' "$O/stream.jsonl"               # Q2-1 success
smoke_main "$O" | awk -F'\t' '$1 == "Read" && $2 ~ /skills\/(ship-milestone\/(SKILL|references\/sequential)|ship\/SKILL)\.md$/'; smoke_main "$O" | awk -F'\t' '$1 == "Skill"'   # Q2-2 the three Reads; no Skill call
tail -n +$((L0 + 1)) "$R/312/log.md"                                                     # Q2-3 first line "brief running — resume"; no spec_analysis line
(cd "$R" && shasum -c "$W/out/q1-artefacts.sha") | grep -vc ': OK$'                      # Q2-4 0 (child 1 and child 2's earlier files untouched)
grep -c '^issue view 311 --json number,title,body' "$GHM/calls.log"; grep -c '^issue view 312 --json number,title,body' "$GHM/calls.log"   # Q2-4 1; 1
grep -c '^pr create --head feat/312-notebook-out-of-stock --base feat/311-stock-labels' "$GHM/calls.log"; jq -r '.status, .pr, .base_branch' "$R/312/state.json"   # Q2-5 1; done, 8, feat/311-stock-labels
n=$(grep -n '^pr create --head feat/312' "$GHM/calls.log" | cut -d: -f1); B=$(ls "$GHM/files/$(printf %03d "$n")-"*)
awk '/^## In plain English$/{f=1;next} f&&/^## /{exit} f' "$B" | grep -ciE '#311|after'; "$REPO/scripts/check-pr-intro.sh" "$B" --issues 1; echo "exit $?"   # Q2-6 >= 1 (names #311 and says merge after it: quote it); exit 0
jq -r '.status, (.history | last | .note)' "$R/313/state.json"; grep '^aew:' "$GHM/issues/313/labels"   # Q2-7 blocked, a note naming "branch already exists: feat/313-stock-filter-toggle"; aew:blocked
smoke_agent_prompts "$O" | grep -c 'runs/313'                                            # Q2-8 0 (child 3 has no agent dispatch)
jq -r '[.children[].status] | join(", ")' "$R/m-3/index.json"                            # Q2-9 done, done, blocked
jq -r '.status, (.history | last | .note)' "$R/m-3/state.json"; cat "$R/current"         # Q2-10 blocked, "child #313 blocked: …"; m-3
grep -cE '^issue comment (311|312|313) .*milestone-report\.md' "$GHM/calls.log"; cat "$R/m-3/milestone-report.md"   # Q2-11 3; #311 and #312 shipped with PR links, #313 blocked with the reason, "Resume with /aew:resume m-3"
smoke_res "$O"                                                                           # Q2-12 #312's own ship report, then "aew ship-milestone m-3 Product stock: stopped", Mode: sequential, Shipped: #311 → …/pull/7 and #312 → …/pull/8, Blocked: #313 at …, Not started: none, Next:
for f in m-3 311 312 313; do smoke_state_valid "$R/$f/state.json"; done; for k in 311 312 313; do smoke_ms_stages "$k"; done   # Q2-13 four valid; 311 and 312 end aew:ready-for-review, 313 aew:analysing aew:blocked
smoke_denials "$O"; ls -A "$W/ghcfg"; git -C "$P" status --porcelain; git -C "$REPO" status --porcelain   # Q2-14 []; empty; empty or agent memory only; this README plus intended fixes; audit clean
smoke_init_evt "$O" '[.tools[] | select(startswith("mcp__notion") or startswith("mcp__claude_ai_"))]'   # Q2-14 [] (system/init lists no mcp__notion or mcp__claude_ai_* tool; R-E4)
```

Fallbacks: Q1 hitting its cap before child 2 reaches `brief` is a run failure; a raise to 16 does not fit the $45 stop, so stop and ask James to raise the stop first (R-E1). A Q2 failure that needs a re-run (restore `$SMOKE/snap-q1` with `cp -Rp`, then `Q2.2`) likewise waits for James to raise the stop.

**Record:** §10.5 tables (Q1 and Q2), plus #312's stacked introduction verbatim.

**Commit:** `test(agent-smoke): record Q1 and Q2, a sequential milestone killed, resumed and stopped` (trailer).

---

### Task E11 — §10 ledger, AC roll-up and notes (AC-35)

- **id:** E11
- **files:** `tests/agent-smoke/README.md` (§10.1 table, §10.6, §10.7)
- **depends_on:** [E8, E9, E10]
- **pattern:** §9.1's ledger table and roll-up; §9.10's "Acceptance criteria (build prompt 05b)" table and notes.

**Step 1: RED.** §10.1's table has no rows; §10.6 is empty.

**Step 2: write.** §10.1: one row per session from `$SMOKE/ledger-06/*.tsv` in start-time order, with the running total and the total against $45 (killed sessions at their cap). §10.6: `| build-prompt AC | evidence |`, one row per build-prompt 06 AC (mode recommendation on three fixtures: `gh-milestone.bats` plus M1 and M3; simulated bulk run: B1 checks 6, 8, 9; simulated sequential run: Q1-3, Q1-5, Q2-5, Q2-9, Q2-10; resume in the second child: Q2-2 to Q2-4; results recorded: this section), and the spec's AC-32–34 mapped to their checks. §10.7: the AC-34 deviation (R-E3): Q1 and Q2 run static-shop issues 311–313 written by `smoke_ms_bodies`, not the chain fixture AC-34 names, because a full sequential run needs issues whose ACs the static-shop app can be built and QA'd against (as #201's are); the chain fixture's order and stacking stay covered by `gh-milestone.bats` and the M3 probe; harness notes (the launcher diff, the allowlist lines, call counts for `select` and the retro list, any mock artefact), findings and open items for prompt 07 (Risk 3 stacked PRs after merges; Risk 5 the SessionStart hint naming `spec_analysis` for a sequential parent; Risk 6; anything not exercised live, such as a per-issue bulk gate answer, a `failed` child and `/aew:ship <k> --from` on a stopped child).

**Step 3: GREEN.** Every §10.3–10.5 check has a result (`pass`, `fail`, or `open` with the reason); the ledger total equals the sum of the tsv files; `git -C "$REPO" status --porcelain` shows only the README.

**Step 4: commit.** `test(agent-smoke): roll up the prompt-06 ledger and results` (trailer).

---

### Task E12 — CHANGELOG, CLAUDE.md recent changes and the project map (AC-31)

- **id:** E12
- **files:** `CHANGELOG.md`, `CLAUDE.md`, `docs/superpowers/project-map.md`
- **depends_on:** [E4, E5, E6, E11]
- **pattern:** the prompt-05 closing commit (`docs: record the prompt-05 changelog, project knowledge and recent changes`).

**Step 1: RED.** `grep -c 'ship-milestone' CHANGELOG.md CLAUDE.md` → record (0 unless an earlier phase added lines); `grep -c '2026-10-26 milestone mode built' docs/superpowers/project-map.md` → `0`.

**Step 2: write.** CHANGELOG `## [Unreleased]`: under Added, `/aew:ship-milestone` (bulk and sequential, mode recommendation, milestone report), `gh-milestone.sh select`, `state.sh index` and bulk `issues/<k>/` subdirs, the `skills.bats` no-pipeline-copy check; under Changed, resume and status handle milestone runs, ship's milestone message, the brief-compiler, qa-engineer and doc-writer inputs, DESIGN §10's recorded deviations. Fold in, without duplicating, any line an earlier phase added. CLAUDE.md `## Recent changes`: one line in the existing form, `- 2026-10-26 · <branch> · Milestone mode (build prompt 06): … · [spec](docs/superpowers/specs/2026-10-26-milestone-mode.md) · [plan](<the consolidated plan path>)`, with the branch from `git branch --show-current`. Project map: append "2026-10-26 milestone mode built (prompt 06)" to Per-feature learnings (what was reused, the run evidence and spend); add a Key-contracts bullet for ship-milestone's entry points (the four files, `## Resume`, the child note, the per-issue gate and revision notes, `index.json`); refresh the dispatch-fields gotcha (brief-compiler `issues`, qa-engineer bulk `<issue>`, doc-writer per-issue snapshots); append gotchas learnt in E8–E10 and mark the 9.10 `grep -v` open item resolved.

**Step 3: GREEN.** `grep -c 'ship-milestone' CHANGELOG.md` ≥ 1; `grep -c 'build prompt 06' CLAUDE.md` = 1; `grep -c '2026-10-26 milestone mode built' docs/superpowers/project-map.md` = 1; `tests/run-script-tests.sh` passes; `claude plugin validate .` passes.

**Step 4: commit.** `docs: record the prompt-06 changelog, project knowledge and recent changes` (trailer).

## Phase verification (after E1–E12)

```sh
cd /Users/jamesborg/Documents/Development/claude-agentic-engineer-workflow
tests/run-script-tests.sh                                                  # all green, shellcheck clean
bats tests/scripts/skills.bats                                             # all pass, including the new ship-milestone test
claude plugin validate .                                                   # passes (existing warnings only)
grep -rc 'later release' skills/resume skills/status README.md docs/DESIGN.md | grep -v ':0$'   # no output
wc -l < skills/resume/SKILL.md; wc -l < skills/status/SKILL.md             # < 500 each (about 85 and 125)
grep -c '^## 10\. ' tests/agent-smoke/README.md                            # 1
git status --porcelain                                                     # clean after the last commit; no transcript or $SMOKE file anywhere in the repo
```

## AC → task matrix

| AC | Task(s) | Evidence |
|---|---|---|
| AC-25 last point: a `skills.bats` check enforces no `## Stage:` sections, dispatch rows or gate steps in ship-milestone | E3 | the new test; its mutation RED |
| AC-28 resume: no "later release" stop; bulk like single with per-issue gates; sequential or child id → `sequential.md` `## Resume`; parent skips the branch check; never re-runs a finished child | E1 (static), E10 (Q2-2 to Q2-4, Q2-9) | resume test; Q2 |
| AC-29 status: list unchanged; index table; `Part of milestone run m-<n>`; milestone next-action rows; read-only, no script | E2 | status test (incl. no script names), the index probe |
| AC-30 `skills.bats`: ship-milestone in entry skills, citations, tests 17 and 18; all resolve; suite passes | B (ENTRY, hint, citations), E1, E3 | `bats tests/scripts/skills.bats` green |
| AC-31 DESIGN §7.1/§9/§10 with deviations; run-protocol; github-ops; README; CHANGELOG; CLAUDE.md; project map | E4, E5, E6, E12 | the GREEN greps |
| AC-32 mode probes (M1, M3 after cut 1): recommendation printed, stop without AskUserQuestion, no run dir, no `gh` write | E7, E8 | M-1 to M-9 |
| AC-33 B1: one PR closing all three, intro passes `--issues 3`; revisions only where changed; ready-for-review on all; milestone report on each; `state.json` done | E7, E9 | B1 checks 1–16 |
| AC-34 Q1 ships child 1 (base `main`), killed in child 2 on child 2's own state; Q2 continues child 2 from its stage, base = child 1's branch, stacked intro; child 3 forced blocked; index `done, done, blocked`; parent blocked; report on all three; no child-3 dispatch | E7, E10 | Q1-1 to Q1-8, Q2-1 to Q2-14 |
| AC-35 results in §10 in §9's form: rails, launcher, ledger with a stop, check tables, roll-up; no transcripts | E7, E11 | §10 |

## Decisions (flag if wrong)

1. **A child's id resumes its milestone.** `/aew:resume <k>` on a `sequential-child` run redirects to the parent and enters `## Resume` (AC-28's "a `sequential-child` id … enters `sequential.md` `## Resume`"), so a finished child is never re-run and the sequence always continues.
2. **A failed or branchless bulk run restarts from scratch.** ship refuses `m-<n>` and ship-milestone stops on an existing run dir, so resume and status print R-B1's line `remove .aew/runs/m-<mn>, then rerun /aew:ship-milestone <mn> --bulk` (X-3.4). The spec is silent here.
3. **Bulk per-issue gates are mapped in `gates.md`** (Phase C H-10, `## Re-asking a pending gate`); resume's line is a pointer to it, so the mapping is written once.
4. **status uses a second next-action table** for milestone rows, so the existing one-row-per-status contract (`skills.bats`) holds, and shows no `stack_on` column (AC-29 names the columns).
5. **The no-pipeline-copy check** keys on ship's own formats (X-7) and requires exactly four files under `skills/ship-milestone/`, which also catches a fifth file that copies ship.
6. **M1 and M3 use Phase A's AC-5 fixtures unchanged**, as AC-32 says, with the requirement in X-1.3 on the bulk fixture's titles. B1 and Q use six static-shop issues written by `smoke_ms_bodies` in README §10, with `run/issue.json` as the template, rather than new committed fixture files. For Q this is a recorded AC-34 deviation (§10.7, R-E3).
7. **Launcher copy:** `ledger-06`, the $45 stop, and the `<run-id>:<stage>` kill form. P0 is not re-run, because no environment line changes (§9.10 precedent). The kill has no `<kill-agent>`, because child 1 has already dispatched every agent.
8. **The allowlist fix goes into §9.2's helper** (`gh-milestone.sh` and `Bash(grep -v *)`), which closes the §9.10 open item rather than working round it per run. `grep -v *` is harness-only and broad, like the other harness lines.
9. **Canned replies:** the listing on `issue-list.1` and `.2` (Risk 4), with the call count recorded; `pr-create.1` → `/pull/7` and `.2` → `/pull/8`, so Q's two children get distinct PRs.
10. **Child 3 is blocked by a local branch created after Q1** (Assumption 18), named with ship's 3.7 slug filter, so the block lands in `git-branch.sh create` before any agent runs.
11. **Budget $37 against a $45 stop, kept** (cut 1; R-E1, **James confirms at plan approval**). Only a probe re-run fits the $8 margin; any larger fallback (B1 raise or re-run, Q1 raise, Q2 re-run) stops the sequence and asks James to raise the stop. Run order M1, M3 → B1 → Q1 → Q2, serial for port 4173 and so the cheap probes check the entry path first.
12. **Closing bookkeeping last:** E12 owns CHANGELOG, CLAUDE.md and the project map for the whole feature, so that no two phases edit them at once.

## Risks

- **Contract drift from A–D.** This plan consumes strings and names from four parallel plans. The phase entry checks catch a missing file or heading before any work, and the rule "the merged text wins; update the expected value before the run" covers wording.
- **A spec gate under `--auto` in B1 or Q** (spec Risk 7). The bodies are short and give exact strings, viewports and the axe standard, as #201's do. A gate is recorded; tightening the body (mock-only) and repeating the run needs James to raise the stop first (R-E1).
- **Q1's cap.** $8 must cover child 1 in full and child 2's spec analysis (S1 cost $4.42 for one issue). Spend can pass the cap, and a killed session is charged its cap, so the ledger records $8 whatever the real spend.
- **Context growth in Q2** (spec Risk 1). Q2 drives child 2 from `brief` to its PR and then starts child 3 in one session. The design re-reads state and references at each step. A lost step shows up as a failing Q2 check, not as a silent pass.
- **Port 4173.** B1 and Q both start the app for QA, so they never overlap (E10 depends on E9).
- **Spend.** A defect found late (Q2) leaves no budget for a re-run under the $45 stop: the sequence stops and asks James to raise it (R-E1). Without a raise, the fix loop records it as `DONE_WITH_CONCERNS`, and the fix stays covered by `skills.bats` and the bats suite.

## Approval (Phase E)

- Senior architect: APPROVED WITH NOTES on 2026-10-26T09:40:16Z (plan-diff-review of the reconciliation revision)
- Resolved: MAJOR-1 by R-E1 ($45 stop kept, only a probe re-run fits, larger fallbacks stop and ask James; **James confirms at plan approval**); MAJOR-2 by R-E2 (302 seeded with a non-material gap; no revised issue makes check 6 `open`); R-E3 (§10.7 AC-34 deviation), R-E4 (`system/init` rows at M-8, B1-16, Q2-14), R-E5 (`resume/SKILL.md` resolver mapping, E3 only); R-B1 rerun line with ` --bulk`; R-D1/R-D2 (Check 5 owned by D, AC-24 over AC-25 deviation).
- Mechanical fix applied at review: R-E2 narrowed so 302 drops only AC 2's WCAG 2.2 AA clause (keeps the viewport sentence). The accessibility gap matches the rubric's non-material bullet exactly; a missing mobile-layout AC could be read as a user-visible change, which the tie-break makes material and gates even under `--auto`. B1 `ac_count` back to `[2,2,2]`, brief AC floor back to `>= 6`.
- Plan content hash (SHA-256, before this section): 29b64d513ba97eccbc3c4d6dda0555d2a8dca6e83c1325c210b2c2f90b6e2cfc

---

## Approval

- Senior architect: APPROVED per phase — A APPROVED WITH NOTES (2026-10-26T09:26Z); B, C, D APPROVED (re-approved after reconciliation diff-review 2026-10-26T09:40:16Z); E APPROVED WITH NOTES (2026-10-26T09:40:16Z)
- Plan format: FULL (EPIC plan-of-phases; A and B lean, C, D and E full)
- Phase graph: A ∥ B → C ∥ D (D2 after C5) → E; 25 tasks, 13 waves
- Simplicity-challenge: SIMPLER-PATH, 2 cuts adopted, 1 partly adopted (M1 kept)
- CTO: APPROVED WITH CONDITIONS on 2026-10-26, mode: risk-gate (Phase E) + routine-signoff (A–D)
- Conditions: CTO-1 to CTO-4 above
- Plan content hash (SHA-256): 38fda72cabdda26e6dcf58138ad85a79bb739d681691c9303e8fea7a85f873ba (the document above this section)
- Recorded: 2026-10-26T09:44:22Z
- Human (developer): APPROVED on 2026-10-26T09:47:30Z (confirmed C1 and the $45 stop for paid runs, CTO-4)
- Plan content hash at approval: cbef5b24a434cad7f6a159eaa02496d9f52f40176881cd66ca295c9c2e33949c
