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
