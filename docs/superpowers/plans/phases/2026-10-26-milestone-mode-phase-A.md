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
