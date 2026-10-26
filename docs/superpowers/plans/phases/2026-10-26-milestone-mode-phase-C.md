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
