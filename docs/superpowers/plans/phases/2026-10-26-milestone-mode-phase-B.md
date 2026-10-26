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
