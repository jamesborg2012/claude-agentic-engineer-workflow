# Brainstorm — Build-side agents: developer, QA, documentation (build prompt 04)

- **Issue:** no issue — build prompt 04 (`docs/build-prompts/04-build-agents.md`; DESIGN.md wins on conflict)
- **Date:** 2026-10-24

## Problem

The plugin can now analyse a spec, compile a brief, set standards and plan, but nothing writes, tests or documents the code. The build half of the pipeline (`develop → review → qa → docs`) needs three agents: a developer that implements work packages (sequentially, or fanned out to sub-developers in isolated worktrees) and fixes failures; a QA engineer that writes a test plan blind to the implementation, then executes it with Playwright, axe-core and exploratory MCP checks and classifies every failure for routing; and a doc-writer that leaves the project better (spec snapshot, curated CLAUDE.md) and produces the PR body, summary and plugin retro. They need two supporting skills (`ui-qa`, `claude-md-curation`), a pinned Playwright MCP server, and fixtures that prove the whole fail → fix → pass → document loop, plus the fan-out, in headless smoke runs.

## Acceptance criteria

Every acceptance criterion from the prompt is kept and marked **[P]**. The rest turn the prompt's deliverables and the DESIGN.md requirements into testable criteria.

**Playwright integration**

1. **AC-1** `.mcp.json` at the plugin root declares one server, `playwright`, in the `mcpServers` wrapper form: `npx --yes @playwright/mcp@0.0.83 --headless --isolated` (an exact version, never `@latest` or a range). `claude plugin validate .` passes. DESIGN §4's Playwright row records that `claude-plugins-official` now ships a `playwright` plugin, why it is not used (it is only an unpinned `@playwright/mcp@latest` `.mcp.json` with no skill, so it does not cover §8.6 and breaks §4's pinning rule), and that aew bundles its own pinned server (Assumption 1).
2. **AC-2** The tool names are verified, not assumed. A headless session with `--plugin-dir` records the `system/init` event's `tools` array; every `mcp__plugin_aew_playwright__*` name in it is recorded in `tests/agent-smoke/README.md`, and the naming fact goes in DESIGN §3. Every Playwright entry in qa-engineer's `tools` is an exact name from that list, with no wildcard (Assumption 2).

**`skills/ui-qa/`**

3. **AC-3** `skills/ui-qa/SKILL.md` has the frontmatter `name: ui-qa`, a `description` and `user-invocable: false` (no `disable-model-invocation`, so it can be preloaded). It covers, each in its own section:
   - `@playwright/test` conventions: specs in `ui.e2e_dir`; role- and label-based locators first (`getByRole`, `getByLabel`, then `getByText`, test ids last, CSS/XPath never unless unavoidable and commented); no fixed waits (`waitForTimeout` banned; web-first assertions and auto-waiting only); page objects only when more than three tests share a page; every test title starts with its TC id (`TC-3: …`);
   - starting the app from `app.start_command` and waiting on `app.ready_check` (URL or command) with a timeout and a clear failure message (Assumption 7);
   - viewports from `ui.viewports`, one Playwright project per viewport, named after it;
   - screenshots named `<TC>-<viewport>.jpg`, JPEG at `evidence.quality` (80), full-page where the state spans the page (Assumption 6);
   - an `@axe-core/playwright` scan of every changed page, tagged to `ui.axe_standard`; serious or critical violations fail, moderate ones are reported (AC-4);
   - exploratory checks through the Playwright MCP: layout breaks at each viewport, focus order, keyboard traps, console errors, and how findings are recorded;
   - evidence rules (AC-5);
   - the manual-test handoff format (`templates/artefacts/manual-tests.md`);
   - setting up Playwright in a project that has none: a Node package at the repo root for JS projects, or `tests/e2e/package.json` (with its own `playwright.config`) for PHP and .NET projects; exact-pinned `@playwright/test@1.64.1` and `@axe-core/playwright@4.14.0`; `npx playwright install chromium`; `test-results/` and `playwright-report/` gitignored (Assumption 4).
4. **AC-4** The axe section defines how `ui.axe_standard` maps to tags: a WCAG level value expands to the cumulative axe tags up to and including it (`wcag22aa` → `wcag2a, wcag2aa, wcag21a, wcag21aa, wcag22aa`); any other value is passed through as a single tag. A spec fails on any violation with impact `serious` or `critical`, and writes all results (including `moderate` and `minor`) where QA can report them (Assumption 5).
5. **AC-5** The evidence rules state: paths `docs/qa/<issue>/report.md` and `docs/qa/<issue>/screenshots/<TC>-<viewport>.jpg` (root from `evidence.dir`); specs write screenshots only when `AEW_EVIDENCE_DIR` is set, so the regression suite run by anyone else never churns evidence; each cycle overwrites same-named files and deletes screenshots it did not produce; `report.md` is written only for a passing cycle, so only the final passing cycle is kept; evidence is committed on the feature branch (Assumption 6).

**`skills/claude-md-curation/`**

6. **AC-6** `skills/claude-md-curation/SKILL.md` has the frontmatter `name: claude-md-curation`, a `description` and `user-invocable: false`. It holds the DESIGN §8.7 rules (only durable, non-obvious, project-specific learnings; edit and prune before appending; stay within `claude_md.max_lines`; link to `docs/` for detail; never duplicate the standards docs), at least three good and three bad example entries with the reason for each, a step-by-step prune procedure, the size cap (read from config with the schema default 300), and the never-include list: secrets, run logs, anything already in the standards docs, anything obvious from the code, and anything time-bound.

**Agents (`agents/*.md`)**

7. **AC-7** Each agent is a complete system prompt with the prompt-03 structure: Role, Inputs (dispatch fields and files), Process, Outputs (each from its template at `${CLAUDE_PLUGIN_ROOT}/templates/artefacts/…`), Return contract, Guardrails, Autonomy, (Memory where enabled) and Definition of done. Frontmatter follows DESIGN §5.3:

   | Agent | model | effort | memory | skills | tools |
   |---|---|---|---|---|---|
   | developer | sonnet | medium | — | aew:run-protocol, superpowers:test-driven-development, superpowers:verification-before-completion, superpowers:systematic-debugging | Read, Write, Edit, Bash, Agent, Skill, mcp__plugin_context7_context7__* |
   | qa-engineer | sonnet | medium | project | aew:run-protocol, aew:ui-qa, superpowers:verification-before-completion | Read, Write, Edit, Bash, the exact Playwright MCP names (AC-2) |
   | doc-writer | sonnet | medium | project | aew:run-protocol, aew:claude-md-curation | Read, Write, Edit, Glob, Grep |

   No agent sets `isolation` (Assumption 10). Each `description` says it is dispatched by the aew orchestrator only. `claude plugin validate .` passes.
8. **AC-8** No agent can or may call `gh`. developer and qa-engineer keep Bash, so the ban is in their guardrails and enforced by the existing `guard-bash.sh` `aew:*` rule; doc-writer has no Bash at all. Each prompt states the run-protocol rule: no `gh`, no push, no merge into the base branch, no PR. Each Bash agent's Guardrails lists the exact command families it may run (this list becomes the smoke `ALLOW` line and, in prompt 05, the input to `init`'s permission proposal).
9. **AC-9** **developer** implements DESIGN §8.5 in full:
   - **Modes** by the dispatch `mode`: `full` (the plan's WPs in dependency order, sequentially, fanning out where allowed), `package` (one WP in a given worktree, as a sub-developer) and `fix` (Assumption 9).
   - **Fan-out rules:** only for WPs marked `parallelisable: yes` whose `depends_on` are all done and whose file lists are pairwise disjoint (the developer checks this itself; any overlap means sequential); at most `limits.max_parallel_developers` at once, dispatched in one message; each sub-developer in its own git worktree created from the feature-branch HEAD; integrated one at a time in WP-number order; worktrees and WP branches removed; then the full set of checks rerun on the feature branch (Assumptions 10–12).
   - A sub-developer (package mode) never spawns agents, touches only its WP's files (it checks `git diff --name-only` before committing), makes exactly one commit on its WP branch and writes `06-dev-report-WP<n>.md` in the main run dir.
   - Before finishing each WP it runs lint, format, typecheck and unit tests from `config.commands` (a missing command is recorded as "not configured"), using TDD for unit tests.
   - One commit per WP, conventional: `feat(<scope>): <summary> (#<issue>)` (or the fitting type); fix-mode commits are `fix(<scope>): … (#<issue>)`.
   - On a UI work package (any [UI] AC, or files that render UI) it invokes `frontend-design:frontend-design` with the Skill tool before implementing.
   - It never diverges silently: if a plan step is impossible or clearly wrong it stops that WP and returns `STATUS: blocked` with the reason (and in full mode, integrates only the WPs that finished).
   - **Fix mode** reads the artefacts named in `fix_from` (a triage, a QA report's failing tests or review findings), fixes them, reruns those tests (starting the app per `aew:ui-qa` when they are e2e, invoked with the Skill tool) and the full unit suite, and overwrites `06-dev-report.md` with `Mode: fix (cycle <n>)` (Assumptions 15, 16).
   - `tools` includes `Agent`. Doc comments on public functions; comments explain why.
10. **AC-10** **qa-engineer phase A** reads only: `02-brief.md`, `03-standards.md`, the `docs/standards/` docs it names, `.aew/config.json`, and the existing test conventions (test config files, test-related manifest fields, existing test files). It must not read source files outside the test directories, `05-plan.md`, `06-dev-report*.md`, or any branch diff or log. It writes `04-qa-test-plan.md` from its template: every AC mapped to at least one TC, a level per TC, test data, UI tests and viewports, accessibility checks, manual-only cases each with a reason, and a new `## Files read` section listing every file it opened (Assumption 18).
11. **AC-11** **qa-engineer phase B** (dispatch `phase: B`, `n`): implements the automated acceptance tests per `ui-qa` (UI tests as `@playwright/test` specs in `ui.e2e_dir`); sets Playwright up first if the project has none; starts the app and waits for `ready_check`; runs everything (unit, e2e, axe) with `AEW_EVIDENCE_DIR` set; captures screenshots per TC per viewport; runs the axe scan of every changed page; runs the exploratory MCP checks; writes `08-qa-report-<n>.md` from its template (results table TC → AC → pass/fail, commands and output excerpts, screenshot index, accessibility table, failures with a triage class and a triage table); writes `manual-tests.md` when there are manual cases; copies the report to `docs/qa/<issue>/report.md` only on a passing cycle; commits its specs, setup and evidence (Assumption 14); and stops the app if it started it. STATUS: `ok` when everything passes and the UI rule is met; `failed` when the report is complete but any test or serious/critical axe check fails; `blocked` when it could not execute (app never ready, setup failed) (Assumption 13).
12. **AC-12** The qa-engineer prompt gives precise criteria and two concrete examples for each triage class, and a fixed order of elimination (`test_bug` → `spec_ambiguity` → `plan_divergence` → `impl_bug`):
    - `impl_bug`: the test faithfully encodes the brief and plan, and the code does not do what the plan says;
    - `plan_divergence`: the code follows the plan (or diverged from it), and the plan, as written or as implemented, cannot satisfy the AC, so a plan decision is needed;
    - `spec_ambiguity`: the brief admits two reasonable readings, the test and the implementation chose different ones, and only James can decide;
    - `test_bug`: the test is wrong (expectation not in the brief, bad locator, timing, missing test data or environment), and the product behaves as the brief says.
13. **AC-13** The UI-done rule is enforced: when the brief has `UI changes: yes`, phase B cannot return `ok` while any automatable UI TC fails, is skipped or is unimplemented, or any expected screenshot is missing. QA may not move an automatable case into `manual-tests.md`; only cases phase A classed manual-only, with a reason, go there.
14. **AC-14** **doc-writer** implements DESIGN §8.7:
    - `docs/specs/<issue>-<slug>.md` with the sections defined in its prompt (final spec, revision history, key decisions from the plan's alternatives, AC → TC → test location → result traceability covering every AC, outstanding manual tests) (Assumption 22);
    - CLAUDE.md updated via `claude-md-curation`, within `claude_md.max_lines`, with every removed entry listed in `10-summary.md`;
    - `10-summary.md` and `pr-body.md` from their templates: summary, AC checklist, test results, screenshot links in `https://github.com/<owner>/<repo>/blob/<branch>/…?raw=true` form (owner and repo from `issue.json` `url`, branch from `state.json`), manual tests, and `Closes #n` for every issue in the run; the template comment removed from `pr-body.md`;
    - `retro.md` from its template, whose items describe the plugin's behaviour (an agent, skill, hook, script or stage), never the project's;
    - it does not commit (no Bash); the orchestrator commits the docs in prompt 05 (Assumption 14).

**Templates and protocol**

15. **AC-15** Small changes to prompt-01/02 artefacts, each keeping the existing headings and order:
    - `templates/artefacts/qa-test-plan.md` gains `## Files read` before the return block;
    - `templates/artefacts/qa-report.md` gains a triage table (`| TC | AC | Triage class | Summary |`) at the top of `## Failures`;
    - `skills/run-protocol/SKILL.md` (return contract) and `references/state-machine.md` (failure paths) say that qa-engineer phase B's `failed` means "QA failures, report complete" and is routed by triage class, not retried as an agent failure (Assumption 13);
    - `templates/config.schema.json` `ui.axe_standard` description says it is expanded to cumulative tags (Assumption 5).
    The full script suite (`tests/run-script-tests.sh`) still passes.

**Fixtures**

16. **AC-16** `tests/fixtures/apps/static-shop/` is a tiny static site served with `npx serve` (`serve@14.2.6`, exact-pinned devDependency, with `@playwright/test@1.64.1` and `@axe-core/playwright@4.14.0`), plus `.aew/config.json` (valid against the schema), a `.gitignore`, one passing unit test run by `node --test`, a small `docs/standards/` (README and one doc) and a `CLAUDE.md` close to its cap. The site deliberately has exactly these defects:
    - a functional bug: clicking "Add to basket" does not update the basket count;
    - a serious accessibility violation: an icon-only basket button with no accessible name (axe `button-name`);
    - a non-automatable requirement in the brief: a confirmation email is sent when an order is placed.
17. **AC-17** `tests/fixtures/apps/static-shop/run/` is a fixture run dir for issue #201: `00-issue-original.md`, `issue.json` (with a GitHub `url`), `spec-final.md`, `02-brief.md` (UI changes: yes; tagged ACs covering the basket count, the accessible basket button with WCAG 2.2 AA, both viewports, and the confirmation email), `03-standards.md`, `04-qa-test-plan.md` (the email case manual-only, with a reason), `05-plan.md` and `06-dev-report.md` (`STATUS: ok`, as if the bugged code were the implementation). Each follows its template's headings and order, and the ones that require it end with a valid return block.
18. **AC-18** `tests/fixtures/apps/static-shop/run-fanout/` holds a fixture `02-brief.md` (issue #202, two small non-UI ACs) and `05-plan.md` with exactly two work packages, both `parallelisable: yes`, `depends_on: []`, on disjoint files (each one new module under `site/` plus its unit test).

**Headless smoke runs**

19. **AC-19 [P]** qa-engineer phase B, run headlessly on the static-shop fixture (cycle 1):
    - flags the basket-count bug as `impl_bug`;
    - fails the accessibility violation in the serious-or-critical band;
    - classifies the email check as manual and writes `manual-tests.md` in the template's format;
    - writes `.aew/runs/<id>/08-qa-report-1.md` and `docs/qa/201/screenshots/<TC>-<viewport>.jpg` for every UI TC at both viewports (real JPEGs, by magic bytes), with specs in `tests/e2e/` whose titles start with their TC id, and no `docs/qa/201/report.md` yet;
    - returns `STATUS: failed` with the triage table in its final message and in the report.
20. **AC-20 [P]** developer fix mode (`fix_from: 08-qa-report-1.md`) fixes both automatable failures with `fix(…): … (#201)` commits and a `Mode: fix (cycle 1)` dev report. A QA re-run (cycle 2) returns `STATUS: ok`, writes `08-qa-report-2.md` and `docs/qa/201/report.md`, and the cycle-1 screenshots are overwritten: the same file names, all newer than the cycle-1 run, the basket-count ones with different checksums, and no stale files.
21. **AC-21 [P]** Fan-out: the two-package fixture plan, in developer `full` mode, produces two sub-developers in two worktrees (two package-mode Agent dispatches in one message, two `06-dev-report-WP<n>.md` with `Mode: package`), and a clean integration: `main..HEAD` holds exactly two `feat(…): … (#202)` commits, each touching only its WP's files; `git worktree list` shows only the main worktree; no WP branches remain; and the post-integration checks are green (in `06-dev-report.md`, and when the harness reruns `node --test`). Kept small: two trivial modules.
22. **AC-22 [P]** doc-writer on the fixture run (after cycle 2):
    - produces a CLAUDE.md change within the fixture's cap that doesn't duplicate the standards: `wc -l` ≤ `claude_md.max_lines`, the file changed, the planted line that duplicates a standards rule is gone and no added line restates a standards rule, and the planted time-bound line is pruned;
    - produces `docs/specs/201-<slug>.md` with AC → test traceability covering every brief AC;
    - writes a `retro.md` containing at least one observation about the plugin;
    - and `pr-body.md` with `blob/<branch>/…?raw=true` screenshot links and `Closes #201`.
23. **AC-23 [P]** The `SubagentStop` gates from prompt 02 fire correctly for developer and qa-engineer: a run without a report is blocked (one deliberately report-less dispatch per agent shows a `block` decision naming the missing artefact), and a run with one passes (the stops in AC-19–22 that follow a valid report are allowed). Whether nested sub-developers fire `SubagentStop`, and with which `agent_type`, is recorded from the AC-21 run (Assumption 29).
24. **AC-24** qa-engineer phase A, run headlessly on the static-shop fixture with the implementation and `05-plan.md` present as traps, writes a valid `04-qa-test-plan.md`, and neither its tool calls (from the stream) nor its `## Files read` section touch `site/` or `05-plan.md`, and the section matches the files it actually read.
25. **AC-25** Every run: every artefact follows its template (same headings, same order), every final message ends with a valid return block (`valid_return_block` from `gate-subagent.sh`), the debug log shows every `skills:` entry preloaded with no skip warning (including `aew:ui-qa`, `aew:claude-md-curation` and the three superpowers skills), `git -C "$REPO" status --porcelain` shows only intentional files, and the cost goes in the spend ledger.
26. **AC-26 [P]** The results are appended to `tests/agent-smoke/README.md` (setup, invocation, check commands and a check | result | notes table, no transcripts). When an agent fails a check, its prompt is improved and the check re-run; the check is never weakened.

**Closing**

27. **AC-27** DESIGN.md is updated in the same commit with the facts and decisions below (§3, §4, §7.3, §8.5, §8.6, §8.7). `CHANGELOG.md` and `docs/superpowers/project-map.md` are updated. The final report lists the checks run, the files changed, the deviations from DESIGN and any decisions needed. Everything lands as conventional commits.

## Scope

- **In:**
  - `.mcp.json` (pinned Playwright MCP);
  - `skills/ui-qa/SKILL.md`, `skills/claude-md-curation/SKILL.md`;
  - `agents/developer.md`, `agents/qa-engineer.md`, `agents/doc-writer.md`;
  - the template, run-protocol and schema-description changes in AC-15;
  - `tests/fixtures/apps/static-shop/` (app, config, standards, CLAUDE.md, `run/`, `run-fanout/`);
  - the smoke runs and their `tests/agent-smoke/README.md` section;
  - DESIGN.md, CHANGELOG, project-map updates;
  - a `gate-subagent.sh` change only if the smoke runs show it mis-blocking (Assumption 29).
- **Out:**
  - the orchestrator (`ship`), `init` (including running the Playwright setup in a real project and the permission proposal), `resume`, `status`, `prompt`, dispatch wording, and committing the doc-writer's and standards-setter's docs (prompt 05);
  - milestone mode (prompt 06) and the sandbox end-to-end run (prompt 07);
  - smoke runs of senior-engineer review and triage modes (prompt 07 covers them end to end);
  - a guard rule denying `git push` from agents (instruction-only for now; see Risks);
  - smoke-testing the PHP/.NET Playwright setup path, and `frontend-design` invocation (no UI WP in the fan-out fixture; recorded as untested);
  - a smoke runner script, CI, README.md updates;
  - any new artefact names or templates beyond AC-15 (the spec snapshot's sections live in the doc-writer prompt).

## Context manifest

**Reference files** (downstream agents read these first):

- `docs/build-prompts/04-build-agents.md`: the task, deliverables and [P] ACs.
- `docs/DESIGN.md`: §3 (platform facts to extend), §4 (Playwright row), §5.2–5.3 (skill and agent tables), §6/§6.1 (`docs/qa/`, `docs/specs/`, e2e dir; `ui.*`, `limits.max_parallel_developers`, `evidence.*`, `claude_md.max_lines`), §7.1/§7.3/§7.5 (writers, stages, return contract), §8.5–8.7 (the three agents), §11 (gates).
- `docs/superpowers/specs/2026-10-24-standards-and-planning-agents.md` and `docs/superpowers/plans/2026-10-24-standards-and-planning-agents.md`: the analog spec and plan (structure, assumptions style, smoke approach, EPIC phasing).
- `agents/senior-engineer.md`: the agent prompt structure to mirror (Role, Inputs → Dispatch fields / Files per mode / Templates, Process per mode, Outputs, Return contract, Guardrails, Autonomy, Memory, Definition of done per mode), the "plugin paths are already absolute" paragraph, and the `mcp__plugin_context7_context7__*` tools entry.
- `skills/run-protocol/SKILL.md` and `references/state-machine.md`: frontmatter pattern, file naming (`08-qa-report-<fix_cycle + 1>.md`, `06-dev-report-WP<n>.md`), the return-contract bullets and the failure-path row to amend (Assumption 13).
- `skills/run-protocol/references/artefacts.md`: readers and templates for `06-dev-report*`, `08-qa-report-<n>`, `manual-tests.md`, `10-summary.md`, `pr-body.md`, `retro.md`, `docs/qa/<issue>/`.
- `templates/artefacts/dev-report.md` (`Mode: package / fix (cycle <n>) / full`, `## Commands run` table the gate reads), `qa-test-plan.md`, `qa-report.md`, `manual-tests.md`, `summary.md`, `pr-body.md`, `retro.md`, `plan.md` (`parallelisable: yes / no`, `depends_on`, owned files).
- `scripts/hooks/gate-subagent.sh`: developer gate = newest `06-dev-report*.md`, not older than `state.json`, valid return block, filled `## Commands run` when `ok`; qa gate = `04-qa-test-plan.md` at stage `plan|qa_test_plan`, `08-qa-report-<fix_cycle+1>.md` at stage `qa`; `valid_return_block` is the smoke check.
- `scripts/lib/hooks.sh`, `scripts/lib/common.sh`: hooks resolve `HOOK_ROOT` to the main worktree via `git rev-parse --git-common-dir`, so the run dir resolves correctly from a linked worktree.
- `scripts/hooks/guard-bash.sh`: the `aew:*` `gh` deny; recursive `rm` outside the project is denied (so worktrees are removed with `git worktree remove`, never `rm -rf`); `git reset --hard` on the default branch is denied.
- `templates/config.schema.json` / `config.example.json`: `ui.*`, `app.*`, `limits.max_parallel_developers`, `evidence.*`, `claude_md.max_lines` with their defaults (leaf and object-level).
- `tests/agent-smoke/README.md`: the harness to extend (`$SMOKE` outside the repo, `smoke_project`/`smoke_use`/`smoke_dispatch`, `--add-dir "$REPO"`, `enabledPlugins` disabling only `dev-workflow` and `figma`, `--include-hook-events`, `final.txt` extraction, spend ledger, after-run `git status` check).
- `docs/superpowers/project-map.md`: gotchas (bash 3.2, zsh one-liners, `CLAUDE_PLUGIN_ROOT` not in Bash env, skills preload verification, `/var` symlink).

**Key facts learned from the codebase:**

- There is no `.mcp.json` yet; `plugin.json` needs no change (the file is auto-discovered at the plugin root).
- The developer gate already fits package mode: each sub-developer writes its own `06-dev-report-WP<n>.md` into the main run dir (absolute `run_dir`), which becomes the newest report when it stops. It cannot tell sub-developers apart, so a report-less sub-developer could pass on a sibling's report (a false allow, caught by the parent, which checks every WP report), and a sibling's malformed report could cost one corrective turn (never a lasting block, because of `stop_hook_active`).
- The gate's freshness rule needs `state.json` written before each developer dispatch; the harness does this with `state.sh stage` / `bump fix_cycle`, as the orchestrator will.
- `state-machine.md` currently retries any agent that returns `failed`, which would retry a QA run whose tests failed. The prompt's AC requires QA to return `failed` in that case, so the protocol needs a one-row exception (it already has a "developer excepted" note for `blocked`).
- `qa-test-plan.md` has no place to list files read, and `qa-report.md` has per-failure entries but no triage table.
- `ui.axe_standard` defaults to `wcag22aa`, but in axe-core that tag marks only the rules new in WCAG 2.2 AA. Scanning with that tag alone would miss `button-name` (WCAG 2 A), the fixture's planted violation. Hence Assumption 5.
- The plan template's WP block has owned files, `depends_on: []` and `parallelisable: yes / no`, so the developer's eligibility check reads them directly.
- The frontend-design skill's qualified name is `frontend-design:frontend-design` (installed plugin cache).
- `.aew/runs/` is gitignored in target projects (the smoke harness ignores `.aew/`), so worktrees under the run dir never show in `git status`.

## Claude Code and package facts (verified 2026-10-24 by the dispatching session against code.claude.com/docs and npm; cited here, not re-verified)

| # | Fact | DESIGN action |
|---|---|---|
| F1 | Plugin `.mcp.json` accepts a bare server map or the `mcpServers` wrapper; `${CLAUDE_PLUGIN_ROOT}` is substituted in `command`/`args`/`env`. Tools are `mcp__plugin_<plugin>_<server>__<tool>`: `mcp__plugin_aew_playwright__<tool>` for an aew-bundled `playwright` server, `mcp__plugin_playwright_playwright__<tool>` for the official plugin. | §3: confirm; add the resolved Playwright names after AC-2 |
| F2 | Agent `tools` accepts full MCP tool names. A server wildcard `mcp__<server>__*` is documented; a plugin-prefixed wildcard follows the pattern but is not shown. An omitted `tools` inherits everything, MCP included. | §3: note; basis for listing exact Playwright names (Assumption 2) |
| F3 | Subagents can spawn subagents up to 3 layers below the main thread (`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`). `Agent` must be in `tools` to spawn. `Agent(type)` restriction lists are ignored in a subagent definition. | §3 Nesting: add the `Agent` and `Agent(type)` points |
| F4 | Worktree isolation (`isolation: worktree` frontmatter, or `isolation: "worktree"` on the Agent call) branches from the repo's **default branch**, not the caller's HEAD, unless the user sets `worktree.baseRef: "head"` (a plugin can't rely on it). Path and branch naming are undocumented; the worktree is auto-cleaned only if unchanged; Claude Code does not merge changes back. | §3: add; §8.5: fan-out uses `git worktree add` from HEAD (Assumption 10) |
| F5 | The plugin-agent frontmatter list in §3 is current (`isolation` only `worktree`; `hooks`, `mcpServers`, `permissionMode`, `initialPrompt` ignored). | none |
| F6 | `SubagentStop` payload: `stop_hook_active`, `agent_id`, `agent_type`, `agent_transcript_path`, `last_assistant_message`. Whether a subagent-spawned subagent fires it with its own `agent_type` is undocumented. | §3: record the AC-23 observation |
| F7 | `claude-plugins-official` ships `playwright` (external_plugins/playwright, by Microsoft): only a `.mcp.json` running `npx @playwright/mcp@latest`, no skill. | §4: record the decision (Assumption 1) |
| F8 | npm current: `@playwright/mcp` 0.0.83 (2026-09-28), `@playwright/test` 1.64.1, `@axe-core/playwright` 4.14.0, `serve` 14.2.6. | §4: pinned versions |

F4 is the only fact that changes how a design requirement can be met: "each in an isolated worktree" cannot use the built-in isolation, because the sub-developer would start from `main` without the feature branch's earlier WPs.

## Assumptions

**Playwright and the ui-qa skill**

1. **Assumed:** aew bundles its own pinned server, `.mcp.json` → `{"mcpServers":{"playwright":{"command":"npx","args":["--yes","@playwright/mcp@0.0.83","--headless","--isolated"]}}}`, and does not depend on the official `playwright` plugin. Reason: the official plugin is only an unpinned `@latest` MCP config with no skill, so it covers neither DESIGN §4's pinning rule nor §8.6 (the skill is `ui-qa`). `--headless` because QA runs unattended; `--isolated` so no browser profile or login state leaks between runs. If James also has the official plugin enabled, both servers run under different names; harmless. **Flag if wrong** (especially headless: a headed browser would let James watch exploratory checks, at the cost of windows popping up).
2. **Assumed:** qa-engineer's `tools` lists exact Playwright tool names rather than a wildcard (F2: a plugin-prefixed wildcard is unverified), limited to what the exploratory checklist uses: navigate, snapshot, click, type, press key, select option, hover, resize, console messages, wait for and close, plus any equivalent the init list shows under a different name. The final set is taken from the AC-2 init list. **Flag if wrong** (the alternative is every tool the server exposes).
3. **Assumed:** the MCP server's default browser is used. If the smoke run shows it unavailable on a clean machine, the plan adds `--browser chromium` to the args and the matching install step to `ui-qa`'s prerequisites, and records it in DESIGN §4.
4. **Assumed:** Playwright test packages live in the target project (exact-pinned `@playwright/test@1.64.1`, `@axe-core/playwright@4.14.0`), not in the plugin. The static-shop fixture pre-declares them and the harness installs them (`npm install`, `npx playwright install chromium`) before the runs, so the paid runs don't spend budget on downloads. The fixture has no `playwright.config`, so QA exercises the config-creation part of setup; the from-scratch package install and the PHP/.NET `tests/e2e/package.json` path are documented but not smoke-tested. **Flag if wrong.**
5. **Assumed (fixes a latent config bug):** `ui.axe_standard` names a conformance target, and `ui-qa` expands a WCAG level to the cumulative axe tags (`wcag2a` → `[wcag2a]`; `wcag2aa` → `[wcag2a, wcag2aa]`; `wcag21a` → `[wcag2a, wcag21a]`; `wcag21aa` → `[wcag2a, wcag2aa, wcag21a, wcag21aa]`; `wcag22aa` → those plus `wcag22aa`). Any other value is used verbatim as one tag. Without this, the default `wcag22aa` scans only the 2.2 additions and misses most violations, including the fixture's `button-name`. Only the schema's description changes, not its shape or default. **Flag if wrong.**
6. **Assumed:** each UI TC captures one screenshot per viewport, at the state its assertion checks, named `<TC>-<viewport>.jpg` (`type: 'jpeg'`, `quality` from `evidence.quality`, `fullPage: true` unless the state is a viewport-only overlay). Specs write screenshots only when `AEW_EVIDENCE_DIR` is set (QA sets it to `<evidence.dir>/<issue>/screenshots`), so developers, James and later regression runs never modify committed evidence. Each QA cycle deletes screenshots in that directory it did not produce. `docs/qa/<issue>/report.md` is written only on a passing cycle. **Flag if wrong.**
7. **Assumed:** QA starts the app itself (no `webServer` block in `playwright.config`, because `ready_check` may be a command, and the MCP checks need the app up too): if `app.base_url` already answers it reuses that instance and leaves it running; otherwise it starts `app.start_command` in the background, waits up to 120 s (a URL `ready_check` via `curl` with retries, so no `sleep` calls; a command `ready_check` polled until it exits 0), and on timeout returns `STATUS: blocked` with the URL or command, the time waited and the tail of the start output. It stops only an instance it started, by the port in `base_url`. `env_type` other than `native`/`local`/`none` (wp-env, ddev, docker) is assumed to be started by `start_command` too. **Flag if wrong.**
8. **Assumed:** `playwright.config` defines one project per `ui.viewports` entry (named after it, with its width and height) and `baseURL` from `app.base_url`; screenshot names take the viewport from the project name.

**Agents**

9. **Assumed (cross-prompt contract for prompt 05):** dispatch fields, each falling back to `.aew/runs/current` for the run dir:
   - developer: `run_dir`; `mode: full | package | fix` (`full` is the template's name for DESIGN's sequential mode, with fan-out inside it); fix adds `n` (the failing cycle) and `fix_from` (comma-separated run-dir artefacts: a `09-triage-<n>.md`, an `08-qa-report-<n>.md` or a `07-review-<n>.md`, which is how review `changes_required` comes back); package adds `wp` (`WP-<n>`), `worktree` (absolute path) and `branch`;
   - qa-engineer: `run_dir`; `phase: A | B`; B adds `n` (`fix_cycle + 1`) and optionally `triage` (a `09-triage-<n>.md` ruling a test wrong);
   - doc-writer: `run_dir`.
   Recorded in the project map. **Flag if wrong.**
10. **Assumed (the high-leverage fan-out decision):** the developer creates the worktrees itself and dispatches sub-developers **without** `isolation`: `git worktree add -b aew/<run-id>/wp-<n> <run_dir>/worktrees/WP-<n> HEAD`, then one `aew:developer` Agent call per WP in a single message (`mode: package`, `wp`, `worktree`, `branch`, `run_dir`). Sub-developers prefix every Bash command with `cd <worktree> &&`, edit by absolute path inside the worktree, and run `commands.install` there first only if a check needs dependencies that are missing. Reasons: built-in isolation branches from the default branch (F4), so sub-developers would miss earlier WPs; its naming and merge-back are undocumented; `git worktree add` from HEAD is deterministic, testable and needs no user setting. Worktrees sit in the gitignored run dir, inside the project, so headless and interactive permission rules for writes inside the working directory apply. No agent sets `isolation: worktree` (on the developer it would move the whole build onto a branch of `main`). DESIGN §8.5 gets one sentence describing this. **Flag if wrong.**
11. **Assumed:** integration is `git cherry-pick <wp-commit>` onto the feature branch in WP-number order, then `git worktree remove` and `git branch -D` for each WP, and only then the full checks (lint, format, typecheck, unit tests), because a worktree nested in the project would otherwise be picked up by test runners scanning from the root. This reads DESIGN's "merges their branches into the feature branch one at a time" as integrating them one at a time; cherry-pick keeps exactly one commit per WP and a linear history (`git merge` would add merge commits or fast-forward unpredictably). A conflict (which disjoint files make unexpected) aborts the pick and returns `STATUS: blocked` naming the overlapping files. **Flag if wrong.**
12. **Assumed:** fan-out runs in waves: among unfinished WPs whose `depends_on` are all integrated, those marked `parallelisable: yes` with pairwise-disjoint file lists form a wave if there are at least two; the wave is dispatched in batches of at most `limits.max_parallel_developers` (schema default 4); everything else runs sequentially in the main checkout. A blocked sub-developer's WP is left unintegrated; the others are integrated and the developer returns `blocked` with the reason.
13. **Assumed (resolves a prompt-versus-protocol gap):** qa-engineer phase B returns `ok` (all pass, UI rule met), `failed` (the report is complete, and tests or serious/critical axe checks failed) or `blocked` (could not execute). The prompt's AC requires `failed` for test failures, but the state machine retries every `failed` and blocks after two. So run-protocol's return contract and the state machine's failure paths get one exception, mirroring the existing "developer excepted" note: a qa-engineer phase B `failed` with a valid report is routed by triage class under `max_fix_cycles`, not retried. DESIGN §7.3 gets the same sentence. The discriminator is mechanical, so prompt 05 can implement it without opening the report body: the `failed` counts as "QA failures, report complete" only when `08-qa-report-<n>.md` exists, ends with a valid return block whose STATUS is `failed`, and its `## Failures` triage table has at least one row; anything else (no report, invalid block, empty triage table) is an ordinary agent `failed` (retry once, then `blocked`). Phase A returns `ok` or `blocked`. **Flag if wrong** (it is a behaviour clarification prompt 05 must implement).
14. **Assumed:** commit ownership is: the developer commits per WP and per fix; QA commits its specs, Playwright setup and evidence at the end of every phase-B cycle (`test(e2e): … (#<issue>)`), because the developer's fix mode needs QA's failing tests in a clean tree; the doc-writer does not commit (it has no Bash, keeping its permission surface minimal) and the orchestrator commits its docs in prompt 05, as it does the standards docs (prompt 03 Assumption 10). Squash merges keep only the final evidence on `main`. DESIGN §8.6/§8.7 get one line each. **Flag if wrong.**
15. **Assumed:** in fix mode with failing e2e tests, the developer starts the app by invoking `aew:ui-qa` with the Skill tool (not preloading it, so DESIGN §5.3's preload list stays unchanged), runs only the failing specs without `AEW_EVIDENCE_DIR`, then runs the full unit suite. It never edits QA's specs; a test it believes is wrong is a `blocked` return for senior-engineer triage.
16. **Assumed:** fix mode overwrites `06-dev-report.md` (`Mode: fix (cycle <n>)`) rather than inventing a cycle-suffixed name ("don't invent new ones"); earlier reports are in git-ignored history only. In `full` mode the developer writes one `06-dev-report.md` after all WPs and the post-integration checks, listing every WP with its commit.
17. **Assumed:** tools and Bash scope: developer `Read, Write, Edit, Bash, Agent, Skill, mcp__plugin_context7_context7__*` (Skill for frontend-design and ui-qa; context7 per DESIGN §4); qa-engineer `Read, Write, Edit, Bash` plus the Playwright names (no context7, as DESIGN §4 doesn't list QA); doc-writer `Read, Write, Edit, Glob, Grep` (no Bash, so it searches with Glob/Grep per DESIGN §3). Their Guardrails list the Bash families: developer `git` (status, diff, log, show, add, commit, worktree, cherry-pick, branch, rev-parse), the `config.commands`, `node`/`npm`/`npx` as those commands need; qa-engineer the `config.commands`, the app start and ready check (`curl`), `npx playwright …`, `lsof`/`kill` for the port it started, `file`, and `git` (status, diff, log, add, commit). Skills are fully qualified in `skills:` and verified in the debug log. **Flag if wrong.**
18. **Assumed:** phase A's read limit is instruction-only (no tool can restrict paths, and a hook for it is a new abstraction DESIGN doesn't call for), backed by the `## Files read` section and the AC-24 stream check. "Existing test conventions" means test config files (`playwright.config.*`, `vitest.config.*`, `phpunit.xml`…), the test-related fields of manifests (scripts, devDependencies), and existing files inside test directories; following an import from a test into source is forbidden. **Flag if wrong.**
19. **Assumed:** the triage table appears both in the report's `## Failures` and in the final message above the return block. An axe serious/critical violation on a page covered by a brief [A11Y] AC is an `impl_bug` unless the AC is ambiguous about it; an exploratory finding becomes a failure only if it breaks an AC or is a WCAG A/AA failure (a keyboard trap or broken focus order), otherwise it is reported as an observation.
20. **Assumed:** the order of elimination is `test_bug` first (rule out the test), then `spec_ambiguity`, then `plan_divergence`, then `impl_bug`. Example pairs in the prompt (two each): impl_bug (the basket count isn't updated; a required field accepts empty input though the plan names the validation); plan_divergence (the plan validates only server-side but the AC needs an inline message; the plan's nav has no mobile variant but an AC requires it at 390 px); spec_ambiguity ("prices include tax" with no region; "recent orders" with no time window); test_bug (a locator matching two elements; a test expecting seed data the brief never mentioned).
21. **Assumed:** the UI-done rule counts skipped, `fixme` and unimplemented automatable UI TCs, and missing expected screenshots, as failures; a phase-B test plan change (a TC added because the implementation revealed a case) is allowed, but moving a TC from automated to manual is not.
22. **Assumed:** the spec snapshot has no template; its sections are defined in the doc-writer prompt, in order: Spec (from `spec-final.md`), Revision history (`state.json` `spec_revision` and any `spec-revision-v<N>.md`, or "No revisions"), Key decisions (from the plan's alternatives), Traceability (`| AC | TC | Test | Result |`, every brief AC, manual ones pointing to `manual-tests.md`), Outstanding manual tests. The slug is the lower-case kebab-case issue title (run-protocol). CLAUDE.md is curated as a whole file (DESIGN §8.7 says edit and prune existing entries), and every removal is listed in `10-summary.md`'s Summary so the PR reviewer sees it. **Flag if wrong** (the safer-but-weaker alternative is to curate only an aew-managed section).
23. **Assumed:** memory instructions are bounded: qa-engineer records app-start quirks, flaky areas and test-data needs in this project; doc-writer records curation decisions (what was pruned and why) so it doesn't re-add pruned entries. Neither records secrets, run-specific detail or anything in the standards docs. The developer has no memory (DESIGN §5.3).
24. **Assumed:** `claude-md-curation`'s entry format is one bullet per learning under a small set of headings (Commands, Gotchas, Architecture decisions, Conventions), each line a fact plus where to read more; the prune procedure is: read the whole file → drop never-include items → merge duplicates → rewrite stale entries against the code → only then append → recount against the cap, dropping the least durable entries if still over.
25. **Assumed:** each new skill is a single `SKILL.md`, with no `references/`, unless it passes about 300 lines.

**Fixtures and smoke runs**

26. **Assumed:** the fixture layout is `tests/fixtures/apps/static-shop/{package.json (type module, scripts, exact-pinned devDependencies), .gitignore, .aew/config.json, site/{index.html, app.js, basket.js, styles.css}, tests/unit/basket.test.js, docs/standards/{README.md, web.md}, CLAUDE.md, run/…, run-fanout/…}`. `basket.js` is correct and unit-tested; the bug is in `app.js`'s DOM wiring. The config uses `start_command: npx serve -l 4173 site`, `ready_check`/`base_url` `http://localhost:4173`, `test_unit: node --test`, `test_e2e: npx playwright test`, default `ui`, and `claude_md.max_lines: 40` with a fixture `CLAUDE.md` of about 35 lines, including one line that restates a `web.md` rule and one time-bound line, so the cap and the never-include list actually bite. Lint, format and typecheck are omitted from `commands`. The fixture `.gitignore` lists `node_modules/`, `.aew/runs/`, `test-results/` and `playwright-report/`, and never `.aew/` as a whole: a nested `.gitignore` also applies inside the plugin repo, so ignoring `.aew/` would stop the fixture's `.aew/config.json` being committed (and DESIGN §6 commits `config.json` in real projects). The harness keeps the fixture's `.gitignore` instead of overwriting it with `.aew/` as prompt 03's `smoke_project` does. `run/` and `run-fanout/` are removed from the temp project after copying. **Flag if wrong.**
27. **Assumed:** the smoke runs mirror prompt 03's harness (thin `-p` main thread dispatching the subagent, `$SMOKE` outside the repo, `--add-dir "$REPO"`, `--include-hook-events`, `--debug-file`, `acceptEdits` plus each agent's `ALLOW` line from its Guardrails, including the Playwright MCP names for QA). The harness commits the fixture on `main`, creates `feat/201-add-to-basket` (or `feat/202-…`), sets `branch` via `state.sh set`, and drives state with `state.sh stage` / `bump fix_cycle` before each dispatch. Runs: 941 phase A; 951 one pipeline run (QA cycle 1 → `bump fix_cycle` → developer fix → QA cycle 2 → doc-writer); 961 fan-out; 971/972 the report-less gate checks (developer, qa-engineer). Caps: $5 per run, $8 for QA phase B, $10 for fan-out, $2 for the gate checks; one 2x raise per run as before; stop at **$60** total for this prompt. **Flag if wrong.**
28. **Assumed:** beyond the prompt's checks, the smoke runs add phase A's read-limit check (AC-24), the CLAUDE.md planted-line checks (AC-22), preload verification and the MCP tool names (AC-2, AC-25), because each pins a rule that would otherwise fail silently. They are new checks, not weaker ones.
29. **Assumed:** `gate-subagent.sh` needs no change: package mode always writes its own WP report, and the AC-23 runs confirm the live behaviour. If the fan-out run shows a nested sub-developer mis-blocked, the fix is to gate on the report named in the payload's `last_assistant_message` ARTEFACTS line, with bats rows, recorded as a deviation. **Flag if wrong.**
30. **Assumed:** as in prompts 02 and 03, the prompt asks for one conventional commit but dw-implement commits per task; squashing is raised at human review, not done autonomously.

## DESIGN.md changes this work requires (same commit)

1. **§3:** extend Nesting with F3 (`Agent` in `tools`; `Agent(type)` ignored in subagent definitions); add F4 (worktree isolation branches from the default branch, naming and merge-back undocumented, so aew doesn't use it); confirm F1 with the resolved `mcp__plugin_aew_playwright__*` names (AC-2); note F2 (exact MCP names in `tools`; the plugin-prefixed wildcard is unverified); record F6 and the observed nested-`SubagentStop` behaviour (AC-23).
2. **§4:** the Playwright row: the official plugin exists but is unpinned and has no skill, so aew bundles `@playwright/mcp@0.0.83` in `.mcp.json`; `@playwright/test` and `@axe-core/playwright` are exact-pinned in the target project by `ui-qa` setup.
3. **§7.3** (and run-protocol): the qa-engineer phase B `failed` exception (Assumption 13).
4. **§8.5:** one sentence on fan-out mechanics (Assumptions 10–11).
5. **§8.6:** QA commits its specs and evidence each cycle; `axe_standard` expands to cumulative tags (Assumptions 5, 14).
6. **§8.7:** the doc-writer doesn't commit; the orchestrator commits its docs (Assumption 14).
7. **§11, only if Assumption 29's fallback triggers:** the developer gate reads the report named in the `ARTEFACTS` line of `last_assistant_message`; recorded as a deviation.

## DESIGN.md and prompt conflicts found

1. **QA `STATUS: failed` (prompt vs protocol).** The prompt requires `failed` for test failures; the prompt-02 state machine retries every `failed`. Resolved by Assumption 13 (a documented exception). Behaviour change for prompt 05, so flagged.
2. **"Isolated worktree" (DESIGN vs platform).** DESIGN and the prompt ask for isolated worktrees; the built-in isolation starts from the default branch (F4). Resolved by Assumption 10 (git worktrees from HEAD), which meets the requirement without the built-in feature.
3. **"Merges their branches" (DESIGN wording vs one commit per WP).** Resolved by Assumption 11 (cherry-pick), flagged.
4. **`axe_standard` (config default vs axe-core tags).** Not a DESIGN conflict, but the default would under-scan. Resolved by Assumption 5.

No conflict changes the three agents' models, effort, memory or preloaded skills from DESIGN §5.3.

## Risks

- **Fan-out is the least-proven path** (high). Nested spawning, worktrees inside the project, cherry-pick integration and the nested `SubagentStop` behaviour are all new. Mitigations: deterministic git commands, a deliberately tiny fixture, structural checks (commit count, files per commit, `git worktree list`, WP reports), and Assumption 29's fallback.
- **Worktrees nested in the project.** Test runners, linters or file watchers scanning from the root can pick up worktree copies. Mitigation: remove worktrees before the post-integration checks; `.aew/runs/` is gitignored. Residual: a `dev` server watching the whole tree during fan-out (not a v1 case).
- **Playwright MCP runs in every session** where aew is enabled (plugin servers start with the plugin): a first-run `npx` download and a Node process per session, and browser availability on a clean machine (Assumption 3). Mitigation: pinned version, `--headless --isolated`, smoke verification of the browser.
- **Headless cost and non-determinism** (high). Playwright runs, MCP exploration and two QA cycles are slower and costlier than prompt 03's runs. Mitigations: per-run caps, the $60 stop, pre-installed dependencies, structural checks, fix-the-prompt-never-the-check.
- **Screenshot overwrite proof** depends on file mtimes (whole seconds on macOS) and checksums; JPEG output of an unchanged state can be byte-identical, so the checksum check is only applied to screenshots whose state the fix changed.
- **Agents pushing.** developer and QA are the first agents that commit; the guard blocks pushes to the default branch and force pushes, but not a plain push of the feature branch. Instruction-only for now; a candidate retro item if it is ever seen.
- **Whole-file CLAUDE.md curation** may prune lines James wrote. Mitigation: every removal listed in `10-summary.md` and the PR; flagged (Assumption 22).
- **Unverified preload of three superpowers skills plus two new aew skills** — silent skip. Mitigation: AC-25's debug-log check.
- **Untested paths:** `frontend-design` invocation, the from-scratch and PHP/.NET Playwright setup, senior-engineer triage/review in the loop. They are recorded as untested in the README; prompt 07 covers the end-to-end loop.
- **Cross-prompt contracts.** The dispatch fields (Assumption 9), QA's `failed` semantics (13), commit ownership (14) and the Bash allowlists (17) become inputs to prompt 05. Mitigation: recorded in each agent's Inputs/Guardrails and the project map.
- **Touching prompt-01/02 files.** The template, run-protocol and schema-description edits reopen reviewed files. Mitigation: additive edits only, headings and order preserved, the full script suite re-run.
- **Scale.** About 30 small files (three long agent prompts, two skills, ~20 fixture files) and six smoke scenarios. A phased plan is expected.

## Open questions for human

(none: every decision was made from DESIGN.md, the verified facts and the repo. The high-leverage defaults are flagged above, especially Assumptions 1, 5, 6, 10, 11, 13, 14, 22 and 27)

## Spec-review notes

Applied by the senior architect during spec review (mechanical, no design change):

1. **MAJOR, applied (Assumption 26).** The fixture `.gitignore` must ignore `.aew/runs/`, not `.aew/`. A nested `.gitignore` also applies inside the plugin repo, so `.aew/` would have silently kept `tests/fixtures/apps/static-shop/.aew/config.json` out of git, and DESIGN §6 commits `config.json` in real projects. The harness keeps the fixture's `.gitignore` rather than writing `.aew/` over it.
2. **MAJOR, applied (Assumption 13).** The QA `failed` exception now names its discriminator (report exists, valid return block with `STATUS: failed`, a triage table of at least one row). Without it, prompt 05 cannot tell "tests failed" from "agent failed" without guessing. Checked against DESIGN §7.3: step 7 already routes QA failures through triage, and only the closing "an agent returning `failed` twice" rule collides with the prompt's required `STATUS: failed`. A one-sentence exception is the smallest correct resolution (returning `ok` with failures would break the prompt's [P] AC and the meaning of `ok`).
3. **MINOR, applied.** The DESIGN change list now includes the F2 note for §3 and a conditional §11 entry for Assumption 29's fallback.

Notes for the plan (not applied; the plan should handle them):

- **Browser channel (Assumption 3).** `@playwright/mcp` defaults to the Chrome channel, not the Playwright-bundled Chromium. If the smoke run needs `--browser chromium`, that browser build is tied to the MCP's own bundled Playwright version, not to `@playwright/test@1.64.1`, so the install step must use the MCP package's own install route. Record whichever is used in DESIGN §4.
- **Worktree removal (Assumption 11).** `git worktree remove` refuses a worktree with untracked, non-ignored files. The developer may use `--force` only after confirming that the WP's commit has been cherry-picked; otherwise it returns `blocked`.
- **Compound Bash in worktrees (Assumption 10).** `cd <worktree> && …` has to be matched by the smoke `ALLOW` line. Run 961 should confirm this; `git -C <worktree>` for git commands is the fallback if it is not matched.
- **Fixture CLAUDE.md in the plugin repo.** `tests/fixtures/apps/static-shop/CLAUDE.md` loads as nested memory whenever a session on this repo reads fixture files. This is harmless, but keep it obviously fixture-only (its first line says so).
- **Cost stop (Assumption 27).** If the $60 stop is reached before every check passes, stop and record the unpassed checks as open in the README and the final report. Never weaken a check to fit the budget.
- **Scope.** The extra smoke checks (AC-24, the planted lines in AC-22, the preload and MCP-name checks) are justified: each one pins a rule that would otherwise fail silently. Nothing else goes beyond the prompt or DESIGN.

## Approval

- Senior architect: APPROVED WITH NOTES on 2026-10-24T19:26:11Z
- Complexity: NOVEL
- Scale: EPIC
- Reason: there is no in-repo analog for nested fan-out (manual worktrees, cherry-pick integration, nested `SubagentStop`), for a bundled MCP server or for Playwright/axe execution. The work adds a new runtime dependency (the pinned `@playwright/mcp`), amends the run-protocol state machine (a cross-prompt contract) and runs to roughly 30 files and well over 8 tasks across five shippable slices.
- Spec content hash (SHA-256): 3507d61441accd0ef18ffe1df69034c6371b60ccc6e2f6805ae993488126c9c7 (of this doc up to and including "Spec-review notes", before this trailer)

<spec-summary>
- Topic: build-agents
- Issue: no issue (build prompt `docs/build-prompts/04-build-agents.md`; DESIGN.md wins on conflict)
- Problem: nothing in the plugin writes, tests or documents code yet. The build half (`develop → review → qa → docs`) needs the developer (sequential, fan-out and fix modes), the qa-engineer (blind phase A, Playwright/axe/MCP phase B with triage) and the doc-writer, plus the ui-qa and claude-md-curation skills, a pinned Playwright MCP and fixtures that prove the fail → fix → pass → document loop and the fan-out headlessly.
- ACs (testable): AC-1–2 pinned `.mcp.json` and verified exact tool names; AC-3–5 ui-qa (conventions, app start, viewports, JPEG evidence, cumulative axe tags, AEW_EVIDENCE_DIR rules); AC-6 claude-md-curation; AC-7–8 agent frontmatter per DESIGN §5.3 and the no-`gh` rule; AC-9 developer (modes, fan-out, commits, frontend-design, blocked); AC-10–13 qa-engineer (phase A read limit plus `## Files read`, phase B, triage classes in a fixed order, UI-done rule); AC-14 doc-writer; AC-15 template/protocol/schema-description edits; AC-16–18 static-shop fixture, `run/` (#201), `run-fanout/` (#202); AC-19–26 headless smoke runs (QA cycle 1, fix plus cycle 2, fan-out, doc-writer, gates, phase-A blindness, per-run hygiene, README); AC-27 DESIGN/CHANGELOG/project map.
- Scope in: .mcp.json; skills/ui-qa, skills/claude-md-curation; agents/developer.md, qa-engineer.md, doc-writer.md; qa-test-plan/qa-report templates, run-protocol SKILL.md and state-machine.md, the config.schema axe_standard description; tests/fixtures/apps/static-shop (app, config, standards, CLAUDE.md, run/, run-fanout/); smoke runs plus the README section; DESIGN §3/§4/§7.3/§8.5–8.7, CHANGELOG, project map; a gate-subagent.sh change only if A29's fallback triggers.
- Scope out: ship/init/resume/status/prompt, dispatch wording, orchestrator commits of docs (prompt 05); milestone mode (06); sandbox e2e (07); smoke runs of senior review/triage modes; a git-push guard rule; the PHP/.NET Playwright path and frontend-design smoke; a runner script, CI and README.md.
- Context manifest (key references):
  - docs/DESIGN.md §3, §4, §5.3, §6.1, §7.3, §8.5–8.7, §11: source of truth
  - agents/senior-engineer.md: the prompt structure and the context7 tools entry to mirror
  - skills/run-protocol/SKILL.md + references/state-machine.md: return contract and failure-path row to amend (A13)
  - templates/artefacts/{dev-report,qa-test-plan,qa-report,manual-tests,summary,pr-body,retro,plan}.md: agent outputs
  - scripts/hooks/gate-subagent.sh: dev gate = newest 06-dev-report*; qa gate = 08-qa-report-<fix_cycle+1>; valid_return_block
  - scripts/hooks/guard-bash.sh / guard-edit.sh: aew agents denied `gh`; no `rm -rf` outside the project; `.git/` writes denied
  - tests/agent-smoke/README.md: the harness to extend (smoke_project/smoke_dispatch, spend ledger)
- Assumptions (high-stakes only, marked "flag if wrong"):
  - A1: bundle own `@playwright/mcp@0.0.83 --headless --isolated` (the official plugin is unpinned @latest with no skill)
  - A5: `ui.axe_standard` expands to cumulative WCAG tags (`wcag22aa` alone misses `button-name`)
  - A6: screenshots only when AEW_EVIDENCE_DIR is set; overwrite and prune each cycle; report.md only on a passing cycle
  - A10/A11: the developer runs `git worktree add -b aew/<run>/wp-<n> <run_dir>/worktrees/WP-<n> HEAD`; no `isolation`; cherry-pick in WP order; remove the worktrees, then the full checks
  - A13: QA phase B `failed` with a complete report (valid block plus a non-empty triage table) is routed by triage class, not retried (DESIGN §7.3 and run-protocol exception)
  - A14: developer and QA commit; the doc-writer has no Bash, so the orchestrator commits its docs (prompt 05)
  - A22: whole-file CLAUDE.md curation, with every removal listed in 10-summary.md
  - A27: harness as in prompt 03; runs 941/951/961/971/972; $60 total stop
  - A29: gate-subagent.sh unchanged unless the fan-out run shows a mis-block
- Complexity: NOVEL
- Scale: EPIC
- Spec content hash: 3507d61441accd0ef18ffe1df69034c6371b60ccc6e2f6805ae993488126c9c7
</spec-summary>

<epic-decomposition>
- phase: A
  title: Playwright integration and the ui-qa skill
  scope: pinned .mcp.json, headless init run to record the exact mcp__plugin_aew_playwright__* names, skills/ui-qa/SKILL.md (conventions, app start, viewports, evidence, cumulative axe tags, MCP exploratory checks, manual handoff, setup), config.schema axe_standard description, DESIGN §3 names / §4 Playwright row
  acs: [1, 2, 3, 4, 5, 15]
  depends_on: []
  depth: full
  risk: new runtime dependency (bundled @playwright/mcp server starts in every aew session)
- phase: B
  title: static-shop fixture and fixture run dirs
  scope: static site with the three planted defects, package.json pins, .gitignore (.aew/runs/ only), .aew/config.json, unit test, docs/standards, near-cap CLAUDE.md with planted lines, run/ (#201) and run-fanout/ (#202) artefacts per template
  acs: [16, 17, 18]
  depends_on: []
  depth: lean
  risk: none
- phase: C
  title: qa-engineer agent, QA template and protocol changes, and QA smoke runs
  scope: agents/qa-engineer.md (phase A blind read, phase B, triage criteria and examples, UI-done rule, commits), qa-test-plan `## Files read`, qa-report triage table, run-protocol/state-machine QA-failed exception plus DESIGN §7.3/§8.6, smoke 941 (phase A blindness) and 951 QA cycle 1
  acs: [7, 8, 10, 11, 12, 13, 15, 19, 24]
  depends_on: [A, B]
  depth: full
  risk: run-protocol state-machine contract change (consumed by prompt 05)
- phase: D
  title: developer agent and the fan-out smoke run
  scope: agents/developer.md (full/package/fix modes, wave eligibility, manual worktrees from HEAD, cherry-pick integration, post-integration checks, frontend-design, blocked), DESIGN §3 F3/F4 and §8.5 sentence, smoke 961 fan-out with nested SubagentStop observation
  acs: [7, 8, 9, 21, 23]
  depends_on: [B]
  depth: full
  risk: none
- phase: E
  title: doc-writer, claude-md-curation, loop closure and closing docs
  scope: skills/claude-md-curation, agents/doc-writer.md, DESIGN §8.7; the 951 continuation (developer fix → QA cycle 2 → doc-writer), the 971/972 report-less gate runs, per-run hygiene checks, the README results, CHANGELOG, project map, final report
  acs: [6, 7, 14, 20, 22, 23, 25, 26, 27]
  depends_on: [C, D]
  depth: lean
  risk: none
</epic-decomposition>
