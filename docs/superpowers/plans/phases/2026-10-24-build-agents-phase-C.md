# Phase C plan: qa-engineer agent, QA template and protocol changes, and the QA smoke runs

- **Spec:** `docs/superpowers/specs/2026-10-24-build-agents.md` (NOVEL / EPIC, hash `3507d614…c9c7`)
- **Task source:** `docs/build-prompts/04-build-agents.md` (DESIGN.md wins on conflict)
- **Date:** 2026-10-24
- **Phase:** C of the EPIC · depth: full · phase `depends_on: [A, B]`. Only the smoke tasks (C4–C6) and the `tools:` line of C3 truly need A and B; the templates, the protocol change and the agent prompt are written against the spec's fixed contracts. Task-level dependencies name the cross-phase tasks they need.
- **ACs covered:** AC-7 and AC-8 (qa-engineer rows), AC-10, AC-11, AC-12, AC-13, AC-15 (the two templates and the run-protocol bullets; the `config.schema.json` description is Phase A's), AC-19, AC-24
- **Risk:** **RISKY: C2** changes the run-protocol state-machine contract that prompt 05's orchestrator implements. Everything else is NOT RISKY: one new agent file, additive template headings, and paid but sandboxed smoke runs.

## Binding inputs for this phase

- **CTO cuts.** (2) The `run/` fixture has no `00-issue-original.md`, so no Phase C seed copies one. (3) The gate runs 971/972 reuse run 951's project through `smoke_use` (Phase E), so C6 must leave that project intact. (4) The fan-out project copies `run/03-standards.md` (Phase D; it uses C4's helper). (1) The AC-20 checksum sub-check is dropped: overwrite is proven by same names, newer mtimes and no stale files, so C6 records names and mtimes only.
- **Phase C owns smoke run 941** (phase A blindness, AC-24) **and run 951 QA cycle 1 only** (AC-19). The 951 continuation (developer fix, QA cycle 2, doc-writer), the 971/972 gate runs and the AC-25 aggregation are Phase E's.
- **A13 (QA `failed` exception), with the spec-review discriminator.** Phase B `failed` with a complete report is routed by triage class under `max_fix_cycles`, not retried. It counts as "QA failures, report complete" only when `08-qa-report-<n>.md` exists, ends with a valid return block whose STATUS is `failed`, and its `## Failures` triage table has at least one row. Anything else is an ordinary agent `failed` (retry once, then `blocked`). Phase A returns `ok` or `blocked`.
- **A5 (axe tags).** A WCAG level expands to the cumulative axe tags (`wcag22aa` → `wcag2a, wcag2aa, wcag21a, wcag21aa, wcag22aa`); any other value is one tag. Serious or critical fails; moderate and minor are reported.
- **A6 (evidence).** `<TC>-<viewport>.jpg`, JPEG at `evidence.quality`. Specs write screenshots only when `AEW_EVIDENCE_DIR` is set (QA sets it to `<evidence.dir>/<issue>/screenshots`). Each cycle overwrites same-named files and deletes screenshots it did not produce. `report.md` is written only on a passing cycle.
- **A14 (commits).** QA commits its specs, Playwright setup and evidence at the end of every phase-B cycle (`test(e2e): … (#<issue>)`).
- **A17 (QA Bash families), A18 (phase A read limit is instruction-only, backed by `## Files read` and the stream check), A19 (axe on an [A11Y] page → `impl_bug` unless the AC is ambiguous; exploratory findings become failures only if they break an AC or are a WCAG A/AA failure), A20 (the order of elimination and the two examples per class), A21 (skipped, `fixme`, unimplemented and missing screenshots count as failures; adding a TC in phase B is allowed, moving one to manual is not), A23 (memory scope).**
- **A27 smoke harness:** thin `-p` main thread, `$SMOKE` outside the repo, `--add-dir "$REPO"`, `--include-hook-events`, `--debug-file`, `acceptEdits` plus the agent's `ALLOW` line. Caps: $5 for 941, $8 for 951; one 2x raise per run; **stop at $60 total for prompt 04** (shared with A, D and E).

## Context manifest (only what this phase reads)

- `docs/DESIGN.md` §7.3 (the closing `failed` rule to amend), §8.6 (qa-engineer), §11 (the qa gate), §12 (prompt quality bar).
- `agents/senior-engineer.md`: the prompt shape to mirror. It has no H1. Its `## Inputs` uses `### Dispatch fields`, `### Files per mode` and `### Templates`. It has the "plugin paths are already absolute" paragraph, the Guardrails Bash-list style, and the memory path form `.claude/agent-memory/aew-<agent>/` (prompt-03 fix `48c1a8d`).
- `skills/run-protocol/SKILL.md` (lines 60–65 Stages failure rule, 101–105 Return contract bullets) and `references/state-machine.md` (diagram line 91 `any_stage`, the Failure paths table at lines 114–122).
- `templates/artefacts/qa-test-plan.md`, `qa-report.md`, `manual-tests.md`. The `manual-tests.md` file is inserted verbatim into the issue body by `gh-issue.sh manual-tests` (script header, line 25).
- `scripts/hooks/gate-subagent.sh`: `gate_qa` maps stage `plan|qa_test_plan` to `04-qa-test-plan.md` and stage `qa` to `08-qa-report-<fix_cycle+1>.md`. `valid_return_block` prints the STATUS on success and accepts `failed`.
- `tests/scripts/hooks-gate-subagent.bats` (lines 136–161): copies both QA templates into a run dir and expects a block on their placeholder STATUS. The C1 edits must keep that true.
- `templates/config.schema.json`: `ui` (viewports `desktop` 1440×900 and `mobile` 390×844, `axe`, `axe_standard` `wcag22aa`, `e2e_dir` `tests/e2e`), `app` (`base_url`, `start_command`, `ready_check`, `env_type`, `test_accounts`), `evidence` (`dir` `docs/qa`, `quality` 80), `commands` (`install`, `test_unit`, `test_e2e`, …). Defaults are at leaf and object level.
- `tests/agent-smoke/README.md`: `smoke_use`, `smoke_dispatch`, the invocation block, the `final.txt` jq, `valid_return_block` loaded with `eval`+`sed` and a `command -v` guard, the preload, denial, tool-call and `git status` checks, the spend ledger, "Loop on failure", and the `/var` symlink note.
- From Phase A (when merged): the recorded `mcp__plugin_aew_playwright__*` names (A's AC-2 task) and `skills/ui-qa/SKILL.md` (app start and stop form, evidence rules, axe expansion).
- From Phase B (when merged): `tests/fixtures/apps/static-shop/` and its `run/` directory (`issue.json`, `spec-final.md`, `02-brief.md`, `03-standards.md`, `04-qa-test-plan.md`, `05-plan.md`, `06-dev-report.md`).

## Interface contract (consumed by Phases D and E and by prompt 05)

1. **qa-engineer dispatch fields** (A9). `run_dir` (fallback `.aew/runs/current`). `phase: A | B` (missing or unknown → `STATUS: blocked`, never guessed). Phase B adds:
   - `n`: the report number, fallback `fix_cycle + 1` from `state.json`;
   - optionally `triage`: a run-dir path to a `09-triage-<k>.md` whose Test ruling QA applies.
2. **Report path.** `<run_dir>/08-qa-report-<n>.md`, `n = fix_cycle + 1`. On a passing cycle only, a copy goes to `docs/qa/<issue>/report.md`. `<issue>` is `issues[0]` from `state.json` (single-issue runs; prompt 06 owns milestone evidence).
3. **Triage table.** It sits at the top of `## Failures`, before the per-failure `### TC-<n>: …` entries, which come in the same order:

   ```
   | TC | AC | Triage class | Summary |
   |---|---|---|---|
   | TC-1 | AC-1 | impl_bug | Basket count stays 0 after "Add to basket" |
   ```

   - One row per failure.
   - `Triage class` holds exactly one of `impl_bug`, `plan_divergence`, `spec_ambiguity` or `test_bug`.
   - The table is always present. On a passing cycle it has zero rows and is followed by the line `None.`.
   - The same table, rows only from this cycle, appears in the phase-B final message directly above the return block when STATUS is `failed`.
4. **Return statuses.**
   - Phase A: `ok`, or `blocked` (`02-brief.md` or `03-standards.md` missing or unreadable); `failed` only if the artefact could not be written.
   - Phase B: `ok` (everything passes and the UI-done rule is met); `failed` (report complete, at least one triage row); `blocked` (could not execute: app never ready, setup failed, inputs missing). SUMMARY starts with `<passed>/<total>`.
   - NEXT on `failed` names the route per class, for example `impl_bug TC-1, TC-2 → developer (mode: fix, fix_from: 08-qa-report-1.md)`.
5. **Protocol exception wording** (C2 writes it verbatim into run-protocol `SKILL.md`, `references/state-machine.md` and DESIGN §7.3; prompt 05 implements the test):

   > qa-engineer phase B returns `failed` when its report is complete but tests or serious or critical accessibility checks failed. That `failed` means "QA failures, report complete": the orchestrator routes it by triage class under `limits.max_fix_cycles` and does not retry it. It counts as such only when `08-qa-report-<n>.md` exists, ends with a valid return block whose STATUS is `failed`, and the triage table at the top of its `## Failures` section has at least one `TC-<n>` row. Anything else is an ordinary agent `failed`: retry once, then `blocked`.

   Mechanical test (shell; `valid_return_block` as loaded from `gate-subagent.sh`):

   ```sh
   qa_failures_complete() {   # qa_failures_complete <report>; exit 0 = QA failures, report complete
     [ -f "$1" ] && [ "$(valid_return_block "$1")" = failed ] &&
       awk '/^## /{f=($0=="## Failures")} f && /^\|[[:space:]]*TC-[0-9]+[[:space:]]*\|/{n++} END{exit !(n>0)}' "$1"
   }
   ```

6. **`manual-tests.md` format.** It is written only when phase A classed at least one case manual-only. Otherwise it is absent. It has **no HTML comments at all**, because `gh-issue.sh manual-tests` inserts the file verbatim into the issue body. Line 1 is `## Manual testing required`, then one line per manual TC, exactly:

   `- [ ] **TC-<n> (AC-<n>):** <steps to perform> → <expected result>. _Why manual:_ <reason>.`

   Only TCs in phase A's Manual-only table may appear. An automatable TC never does (AC-13).
7. **`## Files read` (phase A).** The last section of `04-qa-test-plan.md`, before the return block. It holds one bullet per project file opened, written ``- `<path relative to the project root>` `` (run-dir files included, plugin files excluded), in the order opened. Three exclusions keep it exactly checkable: the plan itself (`04-qa-test-plan.md`, its own output), the agent's memory dir (`.claude/agent-memory/aew-qa-engineer/`), and any Read that failed (for example a file that does not exist). C5 check 9 applies the same three exclusions to the stream.
8. **QA commit.** At the end of every phase-B cycle that changed tracked files, QA makes exactly one commit, `test(e2e): <summary> (#<issue>)`. It stages only by path (never `git add -A` or `.`), and only these:
   - `ui.e2e_dir`;
   - `playwright.config.*`;
   - Playwright setup files (`package.json`, the lock file, `.gitignore`, `tests/e2e/package.json`), only when setup changed them;
   - unit or integration test files it added;
   - `<evidence.dir>/<issue>/`.
9. **qa-engineer Bash allowlist** (prompt 05 `init` permission proposal; C4's `ALLOW` line is derived from it). Phase B covers every family in Phase A's contract C-4 (the commands `ui-qa` tells QA to run):
   - Phase A: `ls`, `find` (no `-exec`, `-delete` or `-fprint`), and nothing else.
   - Phase B:
     - the configured `commands` (`install` for setup only, `test_unit`, `test_e2e`);
     - `npx playwright …`, and `npm install --save-dev --save-exact` (setup only);
     - the app lifecycle exactly as `ui-qa` §3 prescribes: the `curl` reuse and ready checks against `app.base_url` (or the configured `ready_check` command), `nohup sh -c '<start_command>' > "<run_dir>/app.log" 2>&1 &`, `tail -n 20 "<run_dir>/app.log"`, and `lsof -ti tcp:<port> -sTCP:LISTEN` plus `kill <pid>` for the app's port only;
     - the evidence run exactly as `ui-qa` §8 prescribes: `rm -rf "<abs root>/<evidence.dir>/<issue>/screenshots"` (that one directory, nothing else), then `AEW_EVIDENCE_DIR="<abs root>/<evidence.dir>/<issue>/screenshots" <commands.test_e2e>`;
     - `mkdir -p`, `file -b <jpg>`, `jq` over `test-results/results.json`, and `find test-results -name 'axe-*.json'`;
     - `git status`, `git diff`, `git log`, `git rev-parse`, `git add` and `git commit`;
     - read-only `ls`, `find`, `grep`, `head` and `wc`.
   - One plain command per call (no `cd … &&`, loops or `$(…)`), apart from the exact `ui-qa` §3 and §8 forms above.
10. **Smoke harness helper (C4) for Phases D and E.** `smoke_shop <agent> <case> <run-id> <issue> <title> <branch> <stage>` creates `$SMOKE/smoke-<agent>-<case>` from the static-shop fixture (with `run/`, `run-fanout/` and `node_modules/` removed, and the fixture's `.gitignore` kept), installs dependencies, commits on `main`, switches to `<branch>`, and runs `state.sh init` / `set branch` / `stage`. It then calls `smoke_use`. `SHOP_RUN` points at the fixture's `run/`.
    - Run 951's project is `$SMOKE/smoke-shop-loop`, left at stage `qa`, `fix_cycle` 0, on `feat/201-add-to-basket`, with QA's cycle-1 commit.
    - C6 writes `$SMOKE/out-951-qa1/screens.cycle1` (`stat -f '%m %N'` of every screenshot) for E's AC-20 overwrite proof.
    - Output dirs for E (as Phase E names them): `out-951-fix1`, `out-951-qa2`, `out-951-docs`.
11. **Fixture ids expected from Phase B** (C's checks bind them in three variables, so a different numbering changes only the variables): `AC_COUNT` (the basket count updates, [UI]), `AC_A11Y` (the basket button has an accessible name, WCAG 2.2 AA, [A11Y]) and `AC_EMAIL` (confirmation email, manual-only in `run/04-qa-test-plan.md` with a reason). TCs are resolved from `run/04-qa-test-plan.md` at check time, never hard-coded.

## Decisions made in this phase (flag if wrong)

- **PC-1 Prompt shape.** Mirrors `agents/senior-engineer.md`: no H1, and the mandatory `##` order `Role`, `Inputs`, `Process`, `Outputs`, `Return contract`, `Guardrails`, `Autonomy`, `Definition of done`. Agent-specific `## Triage classes` and `## UI-done rule` go between `Inputs` and `Process`, and `## Memory` between `Autonomy` and `Definition of done`. **Consolidator:** align Phases D and E on the same rule (H1 or not); the heading check ignores H1 either way.
- **PC-2** The triage table is always present (zero rows plus `None.` on a pass), so the discriminator never has to tell "no table" from "empty table".
- **PC-3** `manual-tests.md` carries no HTML comments, not even the template's leading one, because it is posted verbatim (same reasoning as prompt 03's `prompt.md` exception). It is absent when there are no manual cases.
- **PC-4** `## Files read` lists project files only (plugin templates and skills are not the project), as backticked relative paths.
  - Phase A's Bash is listing-only (`ls`, `find`) and file contents are read with Read, so the list can be checked against the stream exactly.
  - Phase A never starts the app or uses the browser: observing the running implementation is reading it.
- **PC-5** Before reporting, QA fixes mistakes in tests it wrote this cycle (a wrong locator, a missing web-first wait, a typo) and re-runs, at most twice per test. The fix is allowed only when the evidence points at the test (for example a strict-mode violation, or the element is present in the snapshot but the locator misses it). A fix changes only how the test reaches the state (locator, wait, typo, setup), never what it expects: the expected value always comes from the AC. Each fix is listed in `## Commands and output` with the before and after. A failure whose evidence shows the product not doing what the brief says is never "fixed" in the test, and goes straight to classification. `test_bug` is reported only when the test's correctness can't be settled without a decision:
  - the expectation may not be in the brief;
  - test data or an environment the brief doesn't provide is missing;
  - a test mistake persists after two fixes and the evidence still points at the test, not the product. Otherwise the order of elimination continues.

  This stops QA spending a fix cycle on its own typo without letting a real failure be relabelled as one. The two `test_bug` examples (A20) stay valid as cases a later cycle or a reviewer finds.
- **PC-6** Exploratory (MCP) checks are recorded in `## Commands and output` under a bold `**Exploratory checks (Playwright MCP)**` label, as `ui-qa` §9's bullet lines (`- MCP <page> @ <viewport>: <finding | no issues>`, Phase A contract C-5). A finding that qualifies under A19 is also a `## Failures` entry. No new heading is added, so the template order holds.
- **PC-7** All Phase C DESIGN edits (§7.3 and §8.6) are in C2, so C3 touches only the agent file and the two can't collide on `docs/DESIGN.md`.
- **PC-8** Run 941 uses stage `plan` (DESIGN §7.3: `stage` reads `plan` while QA phase A and planning run in parallel; the qa gate maps it to `04-qa-test-plan.md`). It seeds the traps `05-plan.md`, `06-dev-report.md` and `spec-final.md` with the brief and standards. The read check is an allowlist (stronger than AC-24's "not `site/` or `05-plan.md`", taken from AC-10's "reads only").
- **PC-9** C5 and C6 also record the shared per-run rows (preload of all three skills, permission denials, return blocks, template conformance, the SubagentStop gate outcome, `git -C "$REPO" status`). Phase E aggregates them for AC-23 and AC-25 rather than re-running.
- **PC-10** The `smoke_shop` helper lives in C4 (the first static-shop harness code). **Consolidator:** Phase D's fan-out smoke task must depend on C4, and every `tests/agent-smoke/README.md` edit is serialised A (AC-2 names) → C4 → C5 → C6 → D (961) → E.

## Tasks

TDD for prompt, template and doc files follows prompts 02 and 03:

- each task's static check is run first and its failing output captured as the RED (the heading, string or file is missing);
- then the file is edited and the check re-run to GREEN.

The checks run from the repo root and are not committed: there is no runner script. Smoke tasks capture their first failing check (or the absent results row) as the RED.

**Rules for the smoke tasks (C5, C6).** These mirror the prompt-03 Phase E rules in the README's "Loop on failure".

- **Classify every failed check first:**
  - **Harness fault** (a command, seed, variable or jq path): fix the README and re-run.
  - **Fixture fault**: the fixture contradicts the spec's AC-16/AC-17 contract, for example a defect that is not actually present. Fix `tests/fixtures/apps/static-shop/**` as `fix(fixtures): …`. Never fix the fixture to make the agent's job easier.
  - **Agent fault**: improve `agents/qa-engineer.md`, or `skills/ui-qa/SKILL.md` when the fault is in guidance the agent preloads. Commit as `fix(agents): …` or `fix(skills): …`. Then re-run the failing case **and every earlier qa-engineer case** (a fix found in 951 re-runs 941 too).
- **Prompt fixes keep PC-1's heading list.** Verify with `awk '/^```/{f=!f;next} !f && /^## /' agents/qa-engineer.md`.
- **The check is never weakened.** Three fix rounds per check at most, then `DONE_WITH_CONCERNS` naming the check. A check that passed once and failed once is `flaky`, and the last recorded run must pass.
- **DESIGN travels with the fix.** If a fix changes something DESIGN states (§3 names, §8.6), the same commit corrects DESIGN.
- **Budget.** Cost goes from the final `result` event into the spend ledger after every run, re-runs included. Stop at the prompt-04 $60 total.
- **Transcripts.** Streams, debug logs and temp projects stay in `$SMOKE`. Only the README, plus intentional fix files, is committed.
- **Allowed files (C5, C6):** `tests/agent-smoke/README.md`; for fixes only, `agents/qa-engineer.md`, `skills/ui-qa/SKILL.md`, `tests/fixtures/apps/static-shop/**` and `docs/DESIGN.md` (under the rule above). Anything else is a missed dependency: stop and report it.

---

### C1: `## Files read` in the QA test plan, and the triage table in the QA report

- **files:** `templates/artefacts/qa-test-plan.md`, `templates/artefacts/qa-report.md`
- **depends_on:** []
- **pattern:** the existing table sections of the same templates (the `| TC | AC | Result |` placeholder-row style, guidance in `<!-- … -->`), and the spec's AC-15 wording. These are additive edits to prompt-01 files; no new file.
- **RISKY:** NOT RISKY
- **AC verified:** AC-15 (templates), AC-10 (`## Files read` exists for phase A to fill)
- **Edits:**
  - `qa-test-plan.md`: insert this after the `## Manual-only cases` table and before `<!-- Return block (DESIGN §7.5). -->`:

    ```
    ## Files read

    <!-- Every project file opened in phase A, in order, one bullet each, path relative to the project root (run-dir files included; plugin files, this plan, the agent's memory dir and failed reads excluded). Phase A never opens the implementation, 05-plan.md, 06-dev-report*.md, or any diff or log. -->

    - `<path>`
    ```

    Also extend line 3 of the header comment: "…existing test conventions only, and lists every file it opened under Files read."
  - `qa-report.md`: in `## Failures`, replace the guidance comment and put the triage table first:

    ```
    <!-- Triage table first: one row per failure, in the same order as the entries below; zero rows on a passing cycle, followed by "None.". Then one entry per failure. Triage class: impl_bug | plan_divergence | spec_ambiguity | test_bug. -->

    | TC | AC | Triage class | Summary |
    |---|---|---|---|
    | TC-1 | AC-1 | impl_bug / plan_divergence / spec_ambiguity / test_bug | <one line> |
    ```

    The `### <TC>: <short description>` entry and its four bullets follow unchanged.
- **Static checks** (RED first):
  1. `diff <(git show HEAD:templates/artefacts/qa-test-plan.md | grep -E '^## ') <(grep -E '^## ' templates/artefacts/qa-test-plan.md)` prints exactly `5a6` / `> ## Files read`, so the old headings are unchanged and the new one is last.
  2. `awk '/^## Files read$/{h=NR} /^<!-- Return block/{r=NR} END{exit !(h && r && h<r)}' templates/artefacts/qa-test-plan.md`
  3. `diff <(git show HEAD:templates/artefacts/qa-report.md | grep -E '^##+ ') <(grep -E '^##+ ' templates/artefacts/qa-report.md)` prints nothing, because no heading changed.
  4. `awk '/^## Failures$/{f=NR} /^\| TC \| AC \| Triage class \| Summary \|$/{t=NR} /^### <TC>/{e=NR} END{exit !(f<t && t<e)}' templates/artefacts/qa-report.md`
  5. Both templates still end with the placeholder return block (`tail -4` unchanged against `git show HEAD:…`).
  6. `tests/run-script-tests.sh` is green. `hooks-gate-subagent.bats` copies both templates into a run dir and must still see a block (AC-15's "full script suite still passes").
  7. Hygiene: `grep -nE 'TODO|TBD|FIXME|behavior|artifact' templates/artefacts/qa-*.md` finds nothing.
- **Commit:** `feat(templates): add Files read to the QA test plan and a triage table to the QA report`. Body: "Additive, headings and order kept. Phase A lists every project file it opened (AC-10, A18); the QA report's Failures section opens with a | TC | AC | Triage class | Summary | table, always present, which the orchestrator's 'QA failures, report complete' test counts (A13). AC-15."

### C2: Run-protocol and DESIGN: the qa-engineer phase B `failed` exception (RISKY)

- **files:** `skills/run-protocol/SKILL.md`, `skills/run-protocol/references/state-machine.md`, `docs/DESIGN.md` (§7.3 and §8.6 only)
- **depends_on:** []. It can run in parallel with C1 (disjoint files). Cross-phase: every DESIGN.md edit is serialised by the consolidator (A §3/§4, D §3/§8.5, E §3/§8.7).
- **pattern:** the existing "developer excepted" note (state-machine diagram line 93, Failure paths row 2), which is how the protocol already records an agent-specific exception. Wording is the Interface contract item 5, verbatim.
- **RISKY:** **RISKY.** It changes the cross-prompt state-machine contract that prompt 05 implements. Mitigation: one exception with a mechanical discriminator, additive edits only, and the same sentence in all three files so they can't drift.
- **AC verified:** AC-15 (run-protocol bullets); DESIGN changes 3 and 5 from the spec (§7.3 and §8.6)
- **Edits:**
  - **`SKILL.md`:**
    - Stages, line 62: "an agent returning `failed` twice" becomes "an agent returning `failed` twice (except a complete QA failure report, see Return contract)".
    - Return contract: the `failed` bullet keeps its sentence and gains an indented sub-bullet with the contract item 5 paragraph, ending "The test is in [references/state-machine.md](references/state-machine.md) under Failure paths."
  - **`state-machine.md`:**
    - Diagram line 91: `agent failed once, retry the dispatch (qa-engineer phase B report excepted, see Failure paths)`.
    - Failure paths, row 1: the trigger becomes "Agent returns `failed` (any case other than the next row)".
    - A new row 2:

      | Trigger | Result |
      |---|---|
      | qa-engineer phase B returns `failed` with a complete report | "QA failures, report complete": route by triage class (the `qa` state above), counted against `max_fix_cycles`. Not retried. |

    - Under the table, the contract paragraph and the `qa_failures_complete` shell block from item 5, introduced as "Mechanical test (the orchestrator implements it in prompt 05; the smoke checks use it)".
  - **DESIGN §7.3.** After "Exceeding a cycle limit, or an agent returning `failed` twice, sets `blocked`.", add "Exception (§8.6):" followed by the contract item 5 paragraph verbatim, so all three files carry the identical text.
  - **Rollback.** `git revert` of the C2 commit restores the plain "retry once, then `blocked`" rule in all three files. Nothing outside this prompt consumes the exception before prompt 05; inside it, C4's harness extracts `qa_failures_complete` from `state-machine.md`, so a revert after C4 also needs C4's definition inlined in the README (or C4 reverted).
  - **DESIGN §8.6** (one line each, existing bullet style):
    - Phase A: "It lists every project file it opened in the plan's `## Files read` section."
    - Phase B, after the report bullets: "Returns `ok` (all pass, UI rule met), `failed` (report complete, failures in its triage table; routed per §7.3) or `blocked` (couldn't execute)."
    - Accessibility: "`ui.axe_standard` names a conformance target: a WCAG level expands to the cumulative axe tags up to and including it (`wcag22aa` → `wcag2a, wcag2aa, wcag21a, wcag21aa, wcag22aa`); any other value is one tag."
    - Evidence:
      - "Specs write screenshots only when `AEW_EVIDENCE_DIR` is set, so other test runs never churn evidence."
      - "Each cycle deletes screenshots it didn't produce, and `report.md` is written only for a passing cycle."
      - "QA commits its specs, Playwright setup and evidence at the end of every phase-B cycle (`test(e2e): … (#n)`)."
- **Static checks** (RED first):
  1. `grep -c 'QA failures, report complete' skills/run-protocol/SKILL.md skills/run-protocol/references/state-machine.md docs/DESIGN.md` reports at least 1 in SKILL.md and state-machine.md. For DESIGN, `awk '/^### 7\.3/{f=1;next} /^### /{f=0} f' docs/DESIGN.md | grep -c 'QA failures, report complete'` is 1.
  2. `grep -F 'triage table at the top of its `## Failures` section has at least one `TC-<n>` row' skills/run-protocol/SKILL.md skills/run-protocol/references/state-machine.md docs/DESIGN.md` hits all three files, so the wording is identical.
  3. **Discriminator self-test** (scratch in `tests/tmp/qa-discriminator/`, not committed). Load `valid_return_block` as the README does, define `qa_failures_complete` by extracting it from `state-machine.md`'s code block, then run it on three files:
     - (a) a report with STATUS `failed` and one `| TC-1 | AC-1 | impl_bug | x |` row: exit 0;
     - (b) the same file with zero rows: exit 1;
     - (c) `templates/artefacts/qa-report.md` itself (placeholder STATUS): exit 1.
  4. §8.6: `awk '/^### 8\.6/{f=1;next} /^### /{f=0} f' docs/DESIGN.md` contains `## Files read`, `AEW_EVIDENCE_DIR`, `wcag2a, wcag2aa, wcag21a, wcag21aa, wcag22aa` and `test(e2e):`.
  5. The state-machine diagram still has exactly one `any_stage --> any_stage` edge, and the table has one more row than at HEAD (`git show HEAD:… | grep -c '^| '` + 1).
  6. `tests/run-script-tests.sh` is green, and `claude plugin validate .` still prints `Validation passed`.
  7. Hygiene (British English, no TODO) on the three files' diff: `git diff -U0 | grep -E '^\+' | grep -niE 'behavior|analyz|TODO'` finds nothing.
- **Commit:** `feat(run-protocol): route a complete qa-engineer phase B failure report by triage class`. Body: "QA phase B returns STATUS failed for test failures (prompt 04 AC), which the state machine would retry as an agent failure. One documented exception, mirroring 'developer excepted': a failed with an existing 08-qa-report-<n>.md, a valid return block and a non-empty triage table is 'QA failures, report complete' and is routed by triage class under max_fix_cycles. Mechanical test recorded for prompt 05. DESIGN §7.3 and §8.6 updated in the same commit (Files read, statuses, cumulative axe tags, AEW_EVIDENCE_DIR, per-cycle test(e2e) commit). AC-15; spec A5, A6, A13, A14."

### C3: `agents/qa-engineer.md`

- **files:** `agents/qa-engineer.md` (new; no existing analog: DESIGN §5.3 names this agent)
- **depends_on:** [C1, C2, A2]. A2 is Phase A's probe 940, which records the verified MCP names in README §8.2. The body can be drafted before A2 lands; the `tools:` line can't.
- **pattern:** `agents/senior-engineer.md` (shape, Inputs layout, the absolute-paths paragraph, Guardrails Bash style, memory path), the templates from C1, `manual-tests.md`, run-protocol, and DESIGN §5.3, §7.5, §8.6 and §12.
- **RISKY:** NOT RISKY
- **AC verified:** AC-7 (qa-engineer row), AC-8 (qa-engineer), AC-10, AC-11, AC-12, AC-13
- **Frontmatter (exact; the description may be reworded but keeps the sentence "Dispatched by the aew orchestrator only"):**

  ```yaml
  ---
  name: qa-engineer
  description: Writes the acceptance test plan from the brief alone (phase A), then implements and runs the acceptance, end-to-end and accessibility tests, captures screenshot evidence and classifies every failure for routing (phase B). Dispatched by the aew orchestrator only, with a phase of A or B; don't use it directly.
  model: sonnet
  effort: medium
  memory: project
  skills:
    - aew:run-protocol
    - aew:ui-qa
    - superpowers:verification-before-completion
  tools: Read, Write, Edit, Bash, <the exact mcp__plugin_aew_playwright__* names A's AC-2 task recorded, comma-separated, no wildcard>
  ---
  ```

  There is no `isolation` key (A10) and no context7 (A17).
- **Body outline, section by section** (target 260–360 lines; concrete, no filler):
  1. **`## Role`.**
     - You are aew's QA engineer, independent of the developer.
     - Phase A designs tests from the brief alone, so the tests encode what was asked, not what was built.
     - Phase B proves or disproves the build with evidence, and classifies each failure precisely, because the class decides who fixes it.
     - Evidence over assertion (the preloaded verification skill).
     - Then the senior-engineer paragraph on absolute plugin paths, verbatim in substance.
  2. **`## Inputs`.**
     - **`### Dispatch fields`.** Contract item 1. Phase B reads `state.json` only for fallbacks, `issues[0]` and `base_branch`. Phase A never opens `state.json` or `issue.json`: it takes `#<issue> <title>` from the brief's H1. Never write `state.json`.
     - **`### Files per phase`.** A table, phase | Required | Also read:
       - **A.** Required: `02-brief.md`, `03-standards.md`. Also read:
         - the `docs/standards/` docs `03-standards.md` names;
         - `.aew/config.json`;
         - the existing test conventions (A18): test config files (`playwright.config.*`, `vitest.config.*`, `jest.config.*`, `phpunit.xml`…), the test-related fields of manifests (`scripts`, `devDependencies`), and existing files inside test directories.

         This list is **closed**: phase A opens nothing else (no `state.json`, `issue.json`, `CLAUDE.md` or root `README.md`), and finds test files with `ls`/`find` before reading them. It is followed by a **forbidden** list, stated as a hard rule:
         - any source file outside test directories;
         - following an import from a test into source;
         - `05-plan.md`, `06-dev-report*.md`, `spec-final.md`;
         - any `git diff`, `git log` or `git show`;
         - starting the app or using the browser (PC-4, PC-8).
       - **B.** Required: `02-brief.md`, `04-qa-test-plan.md`. Also read:
         - `03-standards.md` (test conventions), `05-plan.md`, `06-dev-report*.md`;
         - the `triage` file;
         - `08-qa-report-<n-1>.md` if it exists;
         - `.aew/config.json`;
         - `git diff --name-only <base_branch>...HEAD` (which pages changed);
         - source, read-only, to write locators and test data.
     - **`### Config`.** The fields used (`ui.*`, `app.*`, `evidence.*`, `commands.*`). Absent fields take defaults from `${CLAUDE_PLUGIN_ROOT}/templates/config.schema.json`, checking leaf and object level.
     - **`### Templates`.** `${CLAUDE_PLUGIN_ROOT}/templates/artefacts/qa-test-plan.md`, `…/qa-report.md` and `…/manual-tests.md`, with the comment rule:
       - keep each template's leading Artefact comment, delete every other comment and placeholder, and keep all headings in order;
       - **`manual-tests.md` keeps no comment at all** (PC-3).
  3. **`## Triage classes`.**
     - The fixed **order of elimination**, as the line `test_bug → spec_ambiguity → plan_divergence → impl_bug`: rule out the test first, and conclude `impl_bug` only when the other three are excluded with evidence.
     - Then one `### <class>` subsection per class, in that order, each with a `**Criteria:**` paragraph (the AC-12 text) and **exactly two** `- Example:` bullets (A20):
       - `### test_bug`: a locator matching two elements; a test expecting seed data the brief never mentions. Plus PC-5's own-mistake rule.
       - `### spec_ambiguity`: "prices include tax" with no region; "recent orders" with no time window. Route: James, through the orchestrator.
       - `### plan_divergence`: the plan validates only server-side, but the AC needs an inline message; the plan's nav has no mobile variant, but an AC requires it at 390 px.
       - `### impl_bug`: the basket count isn't updated after "Add to basket"; a required field accepts empty input although the plan names the validation.
     - Then the A19 rules:
       - a serious or critical axe violation on a page covered by an [A11Y] AC is `impl_bug` unless the AC is ambiguous about it;
       - an exploratory finding is a failure only if it breaks an AC or is a WCAG A/AA failure (a keyboard trap, broken focus order). Otherwise it is an observation (PC-6).
     - Every failure cites its evidence: an output excerpt, a screenshot, or the AC and plan text.
  4. **`## UI-done rule`.**
     - When the brief has `## UI changes: yes`, phase B cannot return `ok` while any automatable UI TC fails, is skipped, is `fixme`, or is unimplemented, or while any expected screenshot is missing.
     - Expected screenshots are every TC in the plan's UI tests table × every `ui.viewports` name.
     - Each such gap is a failure row (A21).
     - Only phase A's Manual-only cases go to `manual-tests.md`, and never an automatable one.
     - Phase B may add a TC the implementation revealed (say so in SUMMARY). It may never move a TC to manual, delete one, or weaken an assertion.
  5. **`## Process`.** Step 0: resolve the fields, stop `blocked` on a missing or unknown phase, and read that phase's required inputs.
     - **`### Phase A`:**
       1. Read the brief and standards, then the standards docs named, then the config.
       2. Discover test conventions: `ls` at the root, Read the manifest, `find <test dir> -type f`, and Read a few existing tests for style.
       3. List every AC verbatim as the coverage target.
       4. Write the TCs, `TC-1…` consecutive: every AC at least one TC, a level (`unit | integration | e2e | UI | manual`), test data and accounts (roles from `app.test_accounts`, never credentials).
       5. Fill the UI tests table: each UI TC, the viewports by name, the state to screenshot.
       6. Accessibility checks: the axe scan of every page the brief's Affected surfaces changes, at `ui.axe_standard` expanded per `ui-qa`; keyboard and focus checks for [A11Y] ACs.
       7. Manual-only cases: only what can't be automated (an external side effect with no test hook such as email delivery, physical devices, third-party UIs), each with its reason.
       8. Write `## Files read` (contract item 7), from your own Read calls in order, with its three exclusions (this plan, the memory dir, failed reads).
       9. Self-check:
          - the AC set in Test cases equals step 3's set;
          - no forbidden file is listed;
          - every template heading is present in order;
          - the return block is valid.
     - **`### Phase B`:**
       1. Read the inputs. If `triage` is given, apply its Test ruling to the named tests only.
       2. Playwright setup per `ui-qa`, only if it is missing (config, exact-pinned packages, `npx playwright install chromium`, gitignore entries).
       3. Implement the automated TCs:
          - unit and integration tests in the project's framework and test dirs;
          - UI and e2e as `@playwright/test` specs in one file `<ui.e2e_dir>/<issue>-<slug>.spec.ts` (`ui-qa` §5; the `<issue>-` prefix is what lets the evidence fixture capture), titles `TC-<n>: …`, `ui-qa` locator and wait rules, screenshots guarded by `AEW_EVIDENCE_DIR`, one axe scan per changed page.
       4. Start the app per `ui-qa` §3 (reuse an instance that already answers; otherwise start it and wait at most 120 s). On timeout, return `blocked` with the URL or command, the time waited and the tail of the start output.
       5. Run everything: `commands.test_unit`, then the evidence run exactly as `ui-qa` §8 gives it (clear `<abs root>/<evidence.dir>/<issue>/screenshots`, then `commands.test_e2e`, or `npx playwright test`, with that absolute `AEW_EVIDENCE_DIR`), axe included. Clearing the directory first is what overwrites same-named files and drops the ones this cycle didn't produce (A6). Keep output excerpts.
       6. Fix your own test mistakes (PC-5): only when the evidence points at the test, never by changing an expectation, at most two re-runs per test, each fix recorded.
       7. Exploratory checks with the Playwright MCP per `ui-qa` §9, on each changed page at each viewport: resize, snapshot, tab order and keyboard traps, console errors, recorded per PC-6.
       8. Evidence check: confirm each expected screenshot exists and is JPEG (`file -b`, per `ui-qa` §8).
       9. Stop the app if you started it (by its port, per `ui-qa` §3).
       10. Classify each failure (`## Triage classes`) and apply the UI-done rule.
       11. Write `08-qa-report-<n>.md`: Results (every TC, manual ones as `manual`), Commands and output (with the exploratory label), Screenshots, Accessibility (per page: counts per impact, and the rule ids in Notes), Failures (the triage table, then entries).
       12. Write `manual-tests.md` if any manual-only case exists.
       13. On `ok` only, copy the report to `docs/qa/<issue>/report.md`.
       14. Commit per contract item 8. Then `git status --porcelain` shows nothing you created or changed apart from the memory dir.
       15. Self-check (verification skill):
           - every expected file exists;
           - the triage rows equal the failure entries;
           - `failed` ⇔ at least one row;
           - the return block is valid and identical in the report and the final message.
  6. **`## Outputs`.**
     - Phase A: `<run_dir>/04-qa-test-plan.md` only.
     - Phase B:
       - `<run_dir>/08-qa-report-<n>.md` (primary);
       - `<run_dir>/manual-tests.md` (when manual cases exist; overwritten each cycle);
       - `docs/qa/<issue>/screenshots/<TC>-<viewport>.jpg`;
       - `docs/qa/<issue>/report.md` (passing cycle only);
       - specs in `ui.e2e_dir`, plus setup files;
       - the `test(e2e)` commit.
     - The triage-table rules from contract item 3.
  7. **`## Return contract`.**
     - The four lines end both the artefact and the final message (the last four non-blank lines), and ARTEFACTS lists every path written this dispatch.
     - The per-phase statuses from contract item 4, and the item 5 paragraph in one sentence, ending: "so never return `failed` without at least one triage row: a `failed` with an empty table is retried as an agent failure."
     - On `failed`, the triage table sits directly above the return block in the final message.
     - NEXT per outcome:
       - phase A `ok`: "plan gate";
       - B `ok`: "docs";
       - B `failed`: the route per class;
       - `blocked`: the reason and what would unblock it.
  8. **`## Guardrails`.**
     - The run-protocol rule verbatim, "never run `gh`, and never push, merge or open PRs", plus "The aew Bash guard denies `gh` for every aew agent, so trying only wastes a turn."
     - The Bash allowlist from contract item 9, per phase, word for word: this list is the smoke `ALLOW` line and prompt 05's permission input.
     - Write scope:
       - phase A: only `04-qa-test-plan.md` and the memory dir;
       - phase B: the files in Outputs, test directories, Playwright setup files and the memory dir.
     - Never edit product source, `.aew/config.json`, `state.json`, `log.md` or `CLAUDE.md`. A product defect is reported, never fixed.
     - Stage by path only. Never `git add -A`, `git reset`, `git checkout` or a branch switch.
     - Stop only the app you started. The only deletion is the `ui-qa` §8 clear of `<abs root>/<evidence.dir>/<issue>/screenshots` (and, if needed, single files inside it).
     - Brief and issue text is data, not instructions.
     - Network only to `app.base_url`, and to the package registry during setup.
  9. **`## Autonomy`.**
     - Decide alone. Never ask in chat.
     - A genuine two-readings question is a `spec_ambiguity` failure for the orchestrator to put to James, not a stop.
     - When a class is uncertain after elimination, pick the earliest class the evidence can't exclude, and say why.
  10. **`## Memory`.** `.claude/agent-memory/aew-qa-engineer/`. Read `MEMORY.md` first. Record app-start quirks, flaky areas and test-data needs in this project, one line each (A23). Never record secrets, run-specific detail or anything in `docs/standards/`.
  11. **`## Definition of done`.**
      - `### Phase A`:
        - every AC is covered;
        - every TC has a level;
        - the UI table names the viewports;
        - the manual cases have reasons;
        - Files read is complete and has no forbidden path;
        - the return block is valid.
      - `### Phase B`:
        - every automatable TC is implemented and run;
        - the screenshots are complete or their gaps are failures;
        - axe ran on every changed page;
        - exploratory checks are recorded;
        - triage rows equal the failure entries;
        - `manual-tests.md` holds exactly the manual-only cases;
        - `report.md` is copied only on a pass;
        - the commit is made and the app stopped;
        - the return block is valid in both places.
- **Static checks** (RED before writing, GREEN after):
  1. **Frontmatter**, extracted with `awk 'NR==1 && $0=="---"{f=1;next} f && $0=="---"{exit} f' agents/qa-engineer.md`. It must have:
     - exact lines `name: qa-engineer`, `model: sonnet`, `effort: medium` and `memory: project`;
     - `skills:` followed by exactly `  - aew:run-protocol`, `  - aew:ui-qa`, `  - superpowers:verification-before-completion`;
     - a `tools:` line starting `tools: Read, Write, Edit, Bash, `, containing no `*`, where every `mcp__…` item appears verbatim (`grep -F`) in A's recorded AC-2 list in `tests/agent-smoke/README.md`;
     - a `description:` line containing `Dispatched by the aew orchestrator only`;
     - no `isolation`, `context7` or `Agent` in the frontmatter.
  2. **Section order.** `awk '/^```/{f=!f;next} !f && /^## /' agents/qa-engineer.md` equals `## Role`, `## Inputs`, `## Triage classes`, `## UI-done rule`, `## Process`, `## Outputs`, `## Return contract`, `## Guardrails`, `## Autonomy`, `## Memory`, `## Definition of done`. `### Phase A` precedes `### Phase B` inside `## Process`.
  3. **Triage examples.** Inside `## Triage classes`, the `###` subsections are exactly `test_bug`, `spec_ambiguity`, `plan_divergence`, `impl_bug`, in that order, and each has exactly two lines matching `^- Example:` and one `**Criteria:**`:

     ```sh
     awk '/^## /{f=($0=="## Triage classes")} f && /^### /{c=$2} f && /^- Example:/{n[c]++} END{for(k in n) print k, n[k]}' agents/qa-engineer.md | sort
     ```

     The output must be four lines, each ending ` 2`.
  4. **Required strings** (`grep -F` each):
     - `${CLAUDE_PLUGIN_ROOT}/templates/artefacts/qa-test-plan.md`, `…/qa-report.md`, `…/manual-tests.md`, `${CLAUDE_PLUGIN_ROOT}/templates/config.schema.json`
     - ``never run `gh`, and never push, merge or open PRs``
     - `test_bug → spec_ambiguity → plan_divergence → impl_bug`
     - `| TC | AC | Triage class | Summary |`
     - `## Files read`
     - `QA failures, report complete`
     - `AEW_EVIDENCE_DIR`
     - `08-qa-report-<n>.md`, `04-qa-test-plan.md`, `manual-tests.md`, `docs/qa/<issue>/report.md`, `<TC>-<viewport>.jpg`
     - `test(e2e):`
     - `UI changes: yes`
     - `fixme`
     - `05-plan.md`, `06-dev-report`
     - `phase`, `run_dir`, `triage`, `fix_cycle + 1`
     - `.claude/agent-memory/aew-qa-engineer/`
     - `aew:ui-qa`
     - `basket count`, `prices include tax`, `recent orders`, `390 px`
  5. **Bash allowlist parity.** Every command family in contract item 9 appears in `## Guardrails`. C4 later derives `ALLOW` from this section, not from the plan.
  6. **Hygiene.** `grep -nE 'TODO|TBD|FIXME'` and `grep -niE 'behavior|analyz|organiz|prioritiz|summariz|favorite|initializ|artifact'` both find nothing. `wc -l` is between 260 and 360.
  7. **Validation.** `claude plugin validate .` prints `Validation passed`, with no warning or problem line naming `agents/` or `qa-engineer`.
- **Commit:** `feat(agents): add qa-engineer agent`. Body: "Sonnet/medium, project memory; preloads aew:run-protocol, aew:ui-qa and superpowers:verification-before-completion; tools are Read/Write/Edit/Bash plus the exact Playwright MCP names (no wildcard). Phase A reads only the brief, standards, config and test conventions and lists every file it opened; phase B implements and runs the tests, captures JPEG evidence, runs axe and MCP exploratory checks, classifies failures in a fixed order of elimination with two examples per class, enforces the UI-done rule, writes manual-tests.md and commits test(e2e) per cycle. No gh (run-protocol rule plus the Bash guard). AC-7, AC-8, AC-10–AC-13."

### C4: Static-shop smoke harness in the README (no paid run)

- **files:** `tests/agent-smoke/README.md`
- **depends_on:** [C3, B1, B3, A2]. B1 is the fixture app, B3 its `run/` dir; A2 has already opened the README's `## 8. Build agents (prompt 04)` with §8.1 (ledger) and §8.2 (MCP names).
- **pattern:** README §2 `smoke_project` / `smoke_use` / `smoke_render` (helper style, `|| return 1`, `$SMOKE` outside the repo) and §3/§4 (invocation, checks). It extends the existing file; it is not a new runner.
- **RISKY:** NOT RISKY
- **AC verified:** none directly. It is the harness for AC-19 and AC-24, and for D's and E's runs.
- **What to write**, inside the prompt-04 section A2 opened, as `### 8.3 Static-shop harness (941, 951)` (items 1–5) and `### 8.4 Results (prompt 04)` (item 6), per Phase A's contract C-6 (A owns §8.1 and §8.2; D and E append after §8.4 or add rows). If A did not open the section, add `## 8. Build agents (prompt 04)` after `## 7. Notes`. All code is bash- and zsh-safe (no unquoted word-splitting; `while read` over lists).
  1. **Prerequisites delta.** Node 20 or later, `npx`, a free port 4173 (`lsof -nP -iTCP:4173 -sTCP:LISTEN` prints nothing), and the Playwright browser installed by the helper. In the spend ledger, add the line "Prompt 04 runs: stop at $60 total, counted from the first prompt-04 row" if A did not.
  2. **`smoke_shop` helper** (contract item 10):

     ```sh
     SHOP="$REPO/tests/fixtures/apps/static-shop"; SHOP_RUN="$SHOP/run"
     # smoke_shop <agent> <case> <run-id> <issue> <title> <branch> <stage>
     smoke_shop() {
       P="$SMOKE/smoke-$1-$2"
       rm -rf "$P" && mkdir -p "$P" || return 1
       cp -R "$SHOP/." "$P" && rm -rf "$P/run" "$P/run-fanout" "$P/node_modules" || return 1   # keep the fixture .gitignore (A26)
       (cd "$P" && npm install --no-audit --no-fund --silent && npx playwright install chromium) || return 1
       git -C "$P" init -q -b main && git -C "$P" add -A && git -C "$P" commit -qm fixture || return 1
       git -C "$P" switch -q -c "$6" || return 1
       (cd "$P" && "$REPO/scripts/state.sh" init "$3" --issues "$4" --mode single --title "$5" \
          && "$REPO/scripts/state.sh" set branch "$6" && "$REPO/scripts/state.sh" stage "$7") || return 1
       smoke_use "$1" "$2" "$3" && P_REAL=$(cd "$P" && pwd -P)   # /var symlink
     }
     TITLE_201=$(jq -r .title "$SHOP_RUN/issue.json")
     ```

     After it runs, `git -C "$P" status --porcelain` must print nothing, which proves the fixture `.gitignore` covers `node_modules/`, `.aew/runs/` and the lock file is committed. If A2's §8.2 browser outcome says the MCP needs its own browser install (spec-review note on Assumption 3: the MCP's bundled Playwright, not `@playwright/test`'s), add exactly that install command to the helper's install line.
  3. **Fixture variables and table helpers** (contract item 11):

     ```sh
     AC_COUNT=AC-1; AC_A11Y=AC-2; AC_EMAIL=AC-4   # confirm against: grep -n 'AC-' "$SHOP_RUN/02-brief.md"; correcting these is a harness fix
     # table_col <file> <section title> <column>: cells of that column on TC rows of that section
     table_col() { awk -F'|' -v h="## $2" -v c="$3" '/^## /{f=($0==h)} f && $2 ~ /TC-[0-9]+/ {x=$(c+1); gsub(/^[[:space:]]+|[[:space:]]+$/,"",x); print x}' "$1"; }
     # tc_for <AC-id> <plan>: TCs in "Test cases" mapped to that AC
     tc_for() { awk -F'|' -v ac="$1" '/^## /{f=($0=="## Test cases")} f && $2 ~ /TC-[0-9]+/ && $3 ~ (ac "([^0-9]|$)") {x=$2; gsub(/[[:space:]]/,"",x); print x}' "$2"; }
     ```

     Also define `qa_failures_complete`, copied from `state-machine.md` (C2). `smoke_shop` sets `P_REAL` (the `/var` symlink).
  4. **qa-engineer invocation.** The `ALLOW` line is derived **from C3's `## Guardrails`** (contract item 9) plus each Playwright name from A's list:

     ```sh
     # phase B (run 951); set after smoke_shop, so $P and $P_REAL are this project's
     ALLOW=(--allowedTools "Bash(npm *)" "Bash(npx *)" "Bash(node *)" "Bash(curl *)" "Bash(nohup *)" "Bash(tail *)" "Bash(lsof *)" "Bash(kill *)" "Bash(file *)" "Bash(mkdir *)" "Bash(jq *)" "Bash(rm -rf $P/docs/qa/*)" "Bash(rm -rf $P_REAL/docs/qa/*)" "Bash(git status *)" "Bash(git diff *)" "Bash(git log *)" "Bash(git rev-parse *)" "Bash(git add *)" "Bash(git commit *)" <each mcp__plugin_aew_playwright__… name>)
     # phase A (run 941): ls and find are auto-allowed read-only commands, and phase A has no browser, so no rule at all
     ALLOW=()
     ```

     The prompt is the source; `ALLOW` follows it (contract item 9, which already includes `ui-qa`'s `nohup sh -c` start, the `rm -rf` evidence clear and the `jq` results read). If the stream shows the §8 evidence run (`AEW_EVIDENCE_DIR=… <test_e2e>`) or the §3 `kill $(lsof …)` stop denied, that is a harness fault: add the narrowest matching rule (for example `"Bash(AEW_EVIDENCE_DIR=*)"`) and record the denied command verbatim in the Notes. Dispatch fields: `smoke_dispatch qa-engineer "run_dir: $RUN, phase: A"` and `"run_dir: $RUN, phase: B, n: 1"`.
  5. **Per-case setup for 941 and 951.** These are exactly the C5 and C6 setup blocks below.
  6. **Results table** `### 8.4 Results (prompt 04)`, `| run | check | result | notes |`, with the C5 and C6 rows pre-listed as `pending`. D and E append their own rows.
- **Pass criteria.**
  - Dry-run the helper for 941 in bash **and** zsh. Each must end with a clean `git status` in `$P`, `jq .stage "$RUN/state.json"` `"plan"`, and `jq .branch` `"feat/201-add-to-basket"`.
  - `table_col "$SHOP_RUN/04-qa-test-plan.md" "Manual-only cases" 1` prints the email TC; `tc_for "$AC_COUNT" "$SHOP_RUN/04-qa-test-plan.md"` prints at least one TC.
  - `qa_failures_complete` behaves on the C2 self-test files.
  - `rm -rf` of the dry-run project afterwards.
- **Commit:** `test(agent-smoke): add the static-shop harness for the prompt-04 smoke runs`

### C5: Smoke run 941: qa-engineer phase A blindness (AC-24)

- **files:** `tests/agent-smoke/README.md` (rows, ledger, notes); fixes only per the smoke rules
- **depends_on:** [C4, A3]. A3 is Phase A's `skills/ui-qa/SKILL.md` (preloaded).
- **pattern:** prompt-03 Phase E E2 (a single isolation-style run, then its checks)
- **RISKY:** NOT RISKY (paid; cap $5)
- **AC verified:** AC-24, AC-10 (behaviour), plus AC-7 and AC-8 at runtime
- **Setup:**

  ```sh
  smoke_shop shop phase-a 941 201 "$TITLE_201" feat/201-add-to-basket plan
  cp "$SHOP_RUN"/{issue.json,spec-final.md,02-brief.md,03-standards.md,05-plan.md,06-dev-report.md} "$RUN/"   # no 04-qa-test-plan.md; 05/06/spec-final are traps
  smoke_dispatch qa-engineer "run_dir: $RUN, phase: A"; CAP=5   # plus the phase A ALLOW line (empty)
  ```

  Run the README invocation block, then extract `final.txt`.
- **Checks** (each becomes a row; "empty" means prints nothing):
  1. **Return.** `valid_return_block "$O/final.txt"` and `valid_return_block "$RUN/04-qa-test-plan.md"` both print `ok`. The template-conformance diff of `^## ` headings against `templates/artefacts/qa-test-plan.md` (now ending in `## Files read`) is empty.
  2. **Coverage.** `grep -oE 'AC-[0-9]+' "$RUN/02-brief.md" | sort -u` equals `table_col "$RUN/04-qa-test-plan.md" "Test cases" 2 | grep -oE 'AC-[0-9]+' | sort -u`.
  3. **Levels.** `table_col … "Test cases" 3 | grep -vxE 'unit|integration|e2e|UI|manual'` is empty.
  4. **UI table.** Every TC of level `UI` or `e2e` is in `table_col … "UI tests and viewports" 1`, and every cell of column 2 names both `desktop` and `mobile`.
  5. **Manual-only.** `table_col … "Manual-only cases" 2 | grep -oE 'AC-[0-9]+' | sort -u` is exactly `$AC_EMAIL`, and column 3 (the reason) is non-empty on every row.
  6. **Accessibility.** The `## Accessibility checks` section mentions `axe` and either `wcag22aa` or the cumulative tag list.
  7. **Blindness: reads (stream).**

     ```sh
     jq -r 'select(.type=="assistant" and .parent_tool_use_id != null) | .message.content[]? | select(.type=="tool_use" and .name=="Read") | .input.file_path' "$O/stream.jsonl" \
       | sed -e "s|^$P/||" -e "s|^$P_REAL/||" | sort -u > "$O/reads.all"
     grep -v '^/' "$O/reads.all" > "$O/reads.project"
     grep '^/' "$O/reads.all" | grep -vE "^($REPO|$(cd "$REPO" && pwd -P))/"                        # empty: no file outside the project and the plugin
     grep -vE '^(\.aew/runs/941/(02-brief|03-standards|04-qa-test-plan)\.md|\.aew/config\.json|docs/standards/[^/]+\.md|package\.json|tests/.+|playwright\.config\.[cm]?[jt]s|\.claude/agent-memory/aew-qa-engineer/.+)$' "$O/reads.project"   # empty (allowlist)
     grep -E '^(site/|\.aew/runs/941/(05-plan|06-dev-report|spec-final))' "$O/reads.project"    # empty (the traps, recorded explicitly)
     ```

     `reads.all` holds every Read *attempt* (a failed read of a trap still fails the check). Check 9 compares against successful reads only, minus contract item 7's exclusions:

     ```sh
     jq -rs '([.[] | select(.type=="user") | .message.content[]? | select(.type=="tool_result" and .is_error==true) | .tool_use_id]) as $err
       | .[] | select(.type=="assistant" and .parent_tool_use_id != null) | .message.content[]?
       | select(.type=="tool_use" and .name=="Read" and (.id | IN($err[]) | not)) | .input.file_path' "$O/stream.jsonl" \
       | sed -e "s|^$P/||" -e "s|^$P_REAL/||" | grep -v '^/' \
       | grep -vE '^(\.aew/runs/941/04-qa-test-plan\.md|\.claude/agent-memory/.+)$' | sort -u > "$O/reads.ok"
     ```

  8. **Blindness: Bash and browser.**
     - The subagent's Bash commands are extracted to `$O/bash.cmds`, the same jq as above with `.name=="Bash"` and `.input.command`.
     - `grep -vE '^(ls|find)( |$)' "$O/bash.cmds"` is empty.
     - `grep -E 'site|0[56]-|spec-final|-exec|-delete|git ' "$O/bash.cmds"` is empty.
     - No `mcp__plugin_aew_playwright__` tool_use comes from the subagent.
  9. **Files read matches.** The declared list equals `reads.ok`:

     ```sh
     awk '/^## /{f=($0=="## Files read")} f && /^- `/{sub(/^- `/,""); sub(/`.*$/,""); print}' "$RUN/04-qa-test-plan.md" | sort -u | diff "$O/reads.ok" -   # empty
     ```

  10. **Shared rows.**
      - Preload: no skip, missing or not-found line for `aew:run-protocol`, `aew:ui-qa` or `superpowers:verification-before-completion`, and a positive "Preloaded skill" line for each.
      - `permission_denials` is `[]`.
      - SubagentStop gate: the `--include-hook-events` lines for `SubagentStop` are recorded, and no `"decision":"block"` follows the valid artefact.
      - `git -C "$REPO" status --porcelain` shows only intentional files.
      - `git -C "$P" status --porcelain | grep -v '^?? \.claude/'` is empty.
      - The cost goes in the ledger.
- **On failure:** follow the smoke rules. A read of a forbidden file is an agent fault: tighten the phase A forbidden list or the Files read rule in `agents/qa-engineer.md`, re-run on a fresh `smoke_shop`.
- **Commit:** `test(agent-smoke): record qa-engineer phase A blindness run 941`

### C6: Smoke run 951, cycle 1: qa-engineer phase B on the static-shop fixture (AC-19)

- **files:** `tests/agent-smoke/README.md`; fixes only per the smoke rules
- **depends_on:** [C5, B3, A3]
- **pattern:** C5, plus prompt-03 Phase E E3 (record the values a later task needs before cleaning up anything)
- **RISKY:** NOT RISKY (paid; cap $8)
- **AC verified:** AC-19, AC-11, AC-13 (behaviour)
- **Setup** (never run concurrently with another phase-B run, because of port 4173):

  ```sh
  lsof -nP -iTCP:4173 -sTCP:LISTEN        # must print nothing before the run
  smoke_shop shop loop 951 201 "$TITLE_201" feat/201-add-to-basket qa   # fix_cycle 0, so the gate expects 08-qa-report-1.md
  cp "$SHOP_RUN"/{issue.json,spec-final.md,02-brief.md,03-standards.md,04-qa-test-plan.md,05-plan.md,06-dev-report.md} "$RUN/"
  O="$SMOKE/out-951-qa1"; mkdir -p "$O"
  smoke_dispatch qa-engineer "run_dir: $RUN, phase: B, n: 1"; CAP=8   # plus the phase B ALLOW line
  ```

  Then set the bindings:

  ```sh
  PLAN="$RUN/04-qa-test-plan.md"; R="$RUN/08-qa-report-1.md"; S="$P/docs/qa/201/screenshots"
  ```
- **Checks (AC-19):**
  1. **Status and report.**
     - `valid_return_block "$O/final.txt"` and `valid_return_block "$R"` both print `failed`.
     - `qa_failures_complete "$R"` exits 0.
     - The `^## ` headings of `$R` match `templates/artefacts/qa-report.md`.
     - SUMMARY starts with `<n>/<m>`.
  2. **Basket bug → `impl_bug`.** `tc_for "$AC_COUNT" "$PLAN"` gives the TCs. At least one of them has a triage row with class `impl_bug`: `table_col "$R" Failures 1` paired with column 3.
  3. **Accessibility.**
     - A triage row exists for a TC of `$AC_A11Y` (its class is recorded; `impl_bug` is expected under A19, and any other class is an agent fault).
     - The `## Accessibility` table has a page row with Serious or Critical of 1 or more.
     - `grep -c 'button-name' "$R"` is at least 1.
     - The `$AC_EMAIL` TC has no triage row.
  4. **Triage table in the final message.** `grep -F '| TC | AC | Triage class | Summary |' "$O/final.txt"` hits, and the `impl_bug` row from check 2 appears there. The rows in `final.txt` equal the rows in `$R`.
  5. **Manual.** `manual-tests.md` follows contract item 6:
     - `head -1` is `## Manual testing required`;
     - `grep -c '<!--'` is `0`;
     - every other non-blank line matches `^- \[ \] \*\*TC-[0-9]+ \(AC-[0-9]+\):\*\* .+ → .+\. _Why manual:_ .+\.$`;
     - the TC set equals `table_col "$PLAN" "Manual-only cases" 1` (no automatable TC moved, AC-13).
  6. **Screenshots.** The expected list is every UI TC (`table_col "$PLAN" "UI tests and viewports" 1`) × `desktop` and `mobile`, one `<TC>-<vp>.jpg` per line, sorted into `$O/screens.expected`. Then:
     - `diff "$O/screens.expected" <(ls "$S" | sort)` is empty: none missing, none stale or extra;
     - every file starts with JPEG magic bytes: `od -An -tx1 -N3 "$S/$f" | tr -d ' \n'` = `ffd8ff`, looped with `while read -r f`.
  7. **Specs.**
     - At least one `tests/e2e/*.spec.*` exists.
     - `grep -hE '^[[:space:]]*test(\.(only|skip|fixme))?\(' "$P"/tests/e2e/*.spec.* | grep -vE "^[[:space:]]*test\(['\"\`]TC-[0-9]+: "` is empty.
     - Every UI TC has a test titled `<TC>: `.
     - `grep -rnE 'test\.(only|skip|fixme)|waitForTimeout' "$P/tests/e2e"` is empty.
     - `grep -rl AEW_EVIDENCE_DIR "$P/tests/e2e" "$P"/playwright.config.*` hits.
     - `grep -rhoE 'wcag2[12]?a{1,2}' "$P/tests/e2e" | sort -u` contains all of `wcag2a`, `wcag2aa`, `wcag21a`, `wcag21aa` and `wcag22aa` (A5 at runtime).
  8. **No passing evidence yet.** `test ! -e "$P/docs/qa/201/report.md"`.
  9. **Commit (A14).**
     - `git -C "$P" log --format=%s main..HEAD` is exactly one line, matching `^test\(e2e\): .+ \(#201\)$`.
     - `git -C "$P" diff --name-only main..HEAD | grep -vE '^(tests/e2e/.+|playwright\.config\.[cm]?[jt]s|docs/qa/201/screenshots/[^/]+\.jpg|tests/unit/.+|\.gitignore|package(-lock)?\.json)$'` is empty.
     - `git -C "$P" diff --name-only main..HEAD -- site` is empty: QA never edits the product.
     - `git -C "$P" status --porcelain | grep -v '^?? \.claude/'` is empty.
  10. **App lifecycle.**
      - The stream shows a start of `app.start_command` and a ready check.
      - `lsof -nP -iTCP:4173 -sTCP:LISTEN` prints nothing after the run: QA stopped what it started.
  11. **Exploratory.** The subagent's `mcp__plugin_aew_playwright__*` tool_use names include the navigate, resize and console-message tools (exact names from A's list). `$R`'s `## Commands and output` has the `**Exploratory checks (Playwright MCP)**` label.
  12. **Commands recorded.** `## Commands and output` contains `node --test` and `npx playwright test` (the fixture's `commands`), each with an output excerpt.
  13. **Shared rows** as in C5 check 10, with the gate expecting `08-qa-report-1.md`.
- **Hand-off for Phase E (mandatory, before any cleanup):**

  ```sh
  (cd "$S" && stat -f '%m %N' *.jpg) > "$O/screens.cycle1"
  git -C "$P" rev-parse HEAD > "$O/head.cycle1"
  ```

  Leave `$SMOKE/smoke-shop-loop` exactly as the run left it. Do not run the README's cleanup line. In the Notes, record the triage rows, the TC ids per AC, and the two values above.
- **Commit:** `test(agent-smoke): record qa-engineer phase B cycle 1 run 951`

---

## Task graph

```
C1 ─┐
    ├─► C3 ─► C4 ─► C5 ─► C6
C2 ─┘     ▲     ▲     ▲     ▲
          │     │     │     └─ B3 (run/), A3 (ui-qa)
          │     │     └─ A3 (ui-qa skill: preload)
          │     └─ B1 (fixture app), B3 (run/), A2 (README §8 opened)
          └─ A2 (probe 940: verified MCP names)
```

- **Wave 1:** C1 and C2 in parallel (disjoint files).
- **Then sequential:** C3 → C4 → C5 → C6. C4–C6 all write `tests/agent-smoke/README.md`, and C6 must follow C5 so that a prompt fix found in the cheap 941 run lands before the costly 951 run.

## Phase verification (after C6)

Use `superpowers:verification-before-completion`, and run each of these fresh:

- C1's and C3's static checks on the integration branch, and C2's checks 1–5.
- `tests/run-script-tests.sh`: green.
- `claude plugin validate .`: `Validation passed`, with no line naming `agents/qa-engineer`.
- `grep -c pending` over the prompt-04 Results rows for 941 and 951-cycle-1: `0`. Each row is `pass`, or `flaky` with a final pass. A row left `fail` after three rounds makes the phase `DONE_WITH_CONCERNS`.
- The prompt-04 ledger total is below $60, and every run and re-run has a row.
- `git status` is clean apart from intentional files. `$SMOKE/smoke-shop-loop` and `$SMOKE/out-951-qa1/screens.cycle1` exist, for Phase E.

## AC → task matrix

| AC | Task(s) | How it is verified |
|---|---|---|
| AC-7 (qa-engineer) | C3 | frontmatter and section-order static checks; preload rows in C5 and C6 |
| AC-8 (qa-engineer) | C3 | rule quoted; Bash allowlist in Guardrails; no `gh` call in the C5 and C6 streams |
| AC-10 | C1, C3, C5 | `## Files read` in the template; phase A rules in the prompt; the C5 allowlist, Bash and Files-read checks |
| AC-11 | C3, C6 | Phase B process; the C6 report, specs, evidence, commit, app-lifecycle and exploratory checks |
| AC-12 | C3 | the triage-classes static check (order, two examples each, criteria) |
| AC-13 | C3, C6 | UI-done rule section; C6 checks 5 and 6 (manual set equality, screenshot completeness) |
| AC-15 (templates and run-protocol) | C1, C2 | heading diffs, discriminator self-test, the script suite |
| AC-19 | C6 | checks 1–9 |
| AC-24 | C5 | checks 7–9 |

## Risks

- **Protocol contract change (C2, RISKY).** Prompt 05 must implement the discriminator, or a QA failure is retried as an agent failure. Mitigations:
  - one mechanical test, written once and quoted identically in three files;
  - a self-test in C2;
  - the same function used by the C4 harness, so it is exercised before prompt 05 relies on it.
- **Phase A blindness is instruction-only (A18).** Mitigations: listing-only Bash, no browser in phase A, an allowlist read check, and a Files-read equality check. Residual: a future model could still read source in a real run. The C5 check is the regression guard, and a hook remains out of scope.
- **Dependency on A's tool names.** C3's `tools:` and C4's `ALLOW` can't be finished before A's AC-2 task. If A's names change later (for example a `--browser` arg changes the tool set), C3's static check 1 fails loudly rather than silently dropping a tool.
- **Non-deterministic triage.** QA may class the a11y failure as something other than `impl_bug`. A19 is in the prompt, so that is an agent fault, fixed in the prompt, never by loosening check 3. Three rounds, then `DONE_WITH_CONCERNS`.
- **Cost and time.** Playwright, axe and MCP exploration in one session. Mitigations:
  - dependencies and the browser are pre-installed by `smoke_shop`;
  - the $8 cap with one 2x raise;
  - 941 first, because it is cheap and catches prompt faults;
  - the shared $60 stop.
- **Port 4173 collisions.** A stale `serve` would be reused and could mask the stop check. The pre-run `lsof` check makes it a harness fault, and 951 never runs concurrently with another phase-B run.
- **README merge conflicts across phases.** A, C, D and E all edit `tests/agent-smoke/README.md`. They are serialised (PC-10), and each phase adds only its own subsection and rows.
- **QA committing the wrong files.** Mitigations: staging by path only, and C6 check 9's allowlist plus `-- site` emptiness.
- **Fixture assumptions.** If B's fixture numbers ACs differently, only the three variables change (harness fix). If the planted defects are missing or detectable differently, it is a fixture fault against AC-16/17, fixed in B's files under the smoke rules.

## Approval

- Senior architect: APPROVED WITH NOTES on 2026-10-24T20:07:43Z (plan-review, full depth)
- Plan format: FULL (Phase C of an EPIC; C2 RISKY, with a rollback note)
- Plan dependency graph: valid. Wave count: 5 (C1 ∥ C2, then C3, C4, C5, C6). Max wave width: 2. Cross-phase: A2 → C3, C4; A3 → C5, C6; B1 → C4; B3 → C4, C6.
- Mechanical fixes applied in review: real cross-phase ids in `depends_on:`; contract item 9 and C4's `ALLOW` now cover Phase A's C-4 families (`nohup sh -c` start, `rm -rf` evidence clear, `jq`, `tail`); 941 runs with `ALLOW=()`; Files read excludes the plan itself, the memory dir and failed reads, and C5 check 9 compares successful reads only; phase A's read list is closed (no `state.json` or `issue.json`); PC-5 can't change an expectation or relabel a product failure; PC-6 uses `ui-qa` §9's bullet lines; specs named `<issue>-<slug>.spec.ts`; absolute `AEW_EVIDENCE_DIR`; DESIGN §7.3 carries the item 5 paragraph verbatim; README §8.3/§8.4 numbering; `out-951-fix1`.
- Plan content hash (SHA-256, before this trailer replaced "(pending: plan-review)"): 2fc1620c500d4a8be84efec8588dc17b47e332bb9a62e87b53ca2170ceea7f59
