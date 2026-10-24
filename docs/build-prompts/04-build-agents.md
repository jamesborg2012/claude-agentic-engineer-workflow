# Prompt 04 — Build-side agents: developer, QA, documentation

## Ground rules
- Read `docs/DESIGN.md` in full before doing anything. It is the approved design and the source of truth. If anything in this prompt conflicts with it, DESIGN.md wins; note the conflict in your summary.
- Verify every Claude Code feature you rely on against the current official docs at code.claude.com/docs. That includes:
  - plugin `.mcp.json` format and the resulting MCP tool names;
  - how a subagent spawns a subagent;
  - how worktree isolation is requested for a spawned agent, and how its branch is merged back;
  - agent frontmatter fields.

  Use the claude-code-guide agent; don't rely on memory. If the docs contradict DESIGN.md, follow the docs, update DESIGN.md in the same commit, and call it out.
- Work autonomously. Stop and ask me only when:
  - a decision isn't covered by DESIGN.md and is expensive to reverse;
  - the docs contradict the design in a way that changes behaviour;
  - you'd need to act outside this repo in a way this prompt doesn't ask for.
- Simplicity first: no abstractions, options or files the design doesn't call for.
- British English in all prose.
- Use superpowers' verification-before-completion before claiming you're done.
- Finish with:
  1. the checks you ran and their results;
  2. the files created or changed;
  3. any deviations from DESIGN.md, and why;
  4. anything I need to decide.

  Then commit with a conventional commit message.

## Goal
Build the agents that write, test and document the code (developer, qa-engineer, doc-writer), their supporting skills (ui-qa, claude-md-curation), and the Playwright integration.

## Deliverables
1. **Playwright integration.**
   - First check whether `claude-plugins-official` now ships an official Playwright plugin or skill. If it does and it covers DESIGN §8.6, use it as a pinned dependency instead, and update DESIGN §4.
   - Otherwise, add the Playwright MCP server (`@playwright/mcp`, pinned to a specific current version) to the plugin's `.mcp.json`.
   - Verify the resulting tool names and list exactly those in qa-engineer's `tools`.
2. **`skills/ui-qa/`:** an internal skill, not a slash command. It covers:
   - `@playwright/test` conventions:
     - specs go in `ui.e2e_dir`;
     - role- and label-based locators first;
     - no fixed waits;
     - page objects only when more than three tests share a page;
     - test titles start with the TC id.
   - Starting the app from config and waiting on `ready_check`, with a timeout and a clear failure message.
   - Viewports from config.
   - Screenshots named `<TC>-<viewport>.jpg`, JPEG at quality 80, full-page where useful.
   - An `@axe-core/playwright` scan of every changed page, tagged to `ui.axe_standard`. Serious or critical violations fail; moderate ones are reported.
   - Exploratory checks via MCP: what to look for (layout breaks, focus order, keyboard traps, console errors).
   - Evidence rules: final passing cycle only, overwrite earlier cycles, committed in the PR branch.
   - The manual-test handoff format.
   - Setting up Playwright in a project that doesn't have it: a Node package at the repo root for JS projects, or `tests/e2e/package.json` for PHP and .NET projects.
3. **`skills/claude-md-curation/`:** an internal skill.
   - The rules from DESIGN §8.7, with examples of good and bad CLAUDE.md entries.
   - A prune procedure, the size cap, and a never-include list: secrets, run logs, anything already in the standards docs, anything obvious from the code, and anything time-bound.
4. **Agents** (`agents/*.md`). Each is a complete system prompt with the same structure as in prompt 03: role, inputs, process, outputs, return contract, guardrails, autonomy rules and definition of done. None of them may call `gh`.
   - **`developer`:**
     - Implements DESIGN §8.5 in full: sequential mode, package mode for sub-developers, and fix mode.
     - **Fan-out rules:**
       - only for work packages marked `parallelisable` that own disjoint files;
       - at most `max_parallel_developers`;
       - each in an isolated worktree;
       - merged back one at a time;
       - the full set of checks rerun after merging.
     - One commit per work package using conventional commits (`feat(scope): … (#n)`).
     - Uses the frontend-design skill on UI work packages.
     - Never diverges silently from the plan. If a plan step is wrong, it returns `STATUS: blocked` with the reason.
     - `tools` includes `Agent`.
   - **`qa-engineer`:**
     - **Phase A** must not read the implementation. Its instructions limit it to the brief, the standards and the existing test conventions, and it must state in its report which files it read.
     - **Phase B:** implements the acceptance tests, runs everything, captures evidence, runs the axe scans and the exploratory checks.
     - **Triage classification:** give precise criteria and two examples for each of `impl_bug`, `plan_divergence`, `spec_ambiguity` and `test_bug`.
     - Enforce the UI-done rule.
     - Writes `manual-tests.md` for the orchestrator to post.
   - **`doc-writer`:**
     - Implements DESIGN §8.7.
     - Writes `docs/specs/<issue>-<slug>.md` and updates CLAUDE.md via the curation skill.
     - Also writes `10-summary.md`, `pr-body.md` (screenshot links in `blob/<branch>/…?raw=true` form) and `retro.md`.
     - Retro items describe the plugin's behaviour, not the project's.
5. **Fixture `tests/fixtures/apps/static-shop/`:** a tiny static site served with `npx serve`, with a fixture run dir containing a brief, plan, QA test plan and dev report. The site deliberately has:
   - one functional bug (e.g. the basket count doesn't update);
   - one serious accessibility violation (e.g. an icon button with no accessible name);
   - one non-automatable requirement in the brief (e.g. a confirmation email is sent).

   Also add a fixture plan with two parallelisable work packages on disjoint files, for the fan-out test.

## Acceptance criteria
- **qa-engineer phase B** run headlessly on the static-shop fixture:
  - flags the functional bug as `impl_bug`;
  - fails the accessibility violation as serious;
  - classifies the email check as manual and writes `manual-tests.md`;
  - writes the report and screenshots to the right paths with the right names;
  - returns `STATUS: failed` with the triage table.
- **developer fix mode** fixes both automatable failures. A QA re-run passes, and the earlier screenshots are overwritten.
- **Fan-out:** the two-package fixture plan produces two sub-developers in worktrees and a clean merge with all checks green. Keep this test small.
- **doc-writer** on the fixture run:
  - produces a CLAUDE.md change within the cap that doesn't duplicate the standards;
  - produces a spec snapshot with AC→test traceability;
  - writes a `retro.md` containing at least one observation about the plugin.
- The `SubagentStop` gates from prompt 02 fire correctly for developer and qa-engineer. A run without a report is blocked; a run with one passes.
- Append the results to `tests/agent-smoke/README.md`. If an agent fails a check, improve its prompt and re-run it. Don't weaken the check.
