# Milestone mode — binding overrides for the phase plans

- **Spec:** `docs/superpowers/specs/2026-10-26-milestone-mode.md` (senior APPROVED WITH NOTES · NOVEL · EPIC · hash `a1ec22d7…f4288e`). Read its `## Approval` section (spec-review notes, `<spec-summary>`, `<epic-decomposition>`) first.
- **Precedence:** these overrides > spec-review notes > spec.

## CTO simplicity-challenge (SIMPLER-PATH) — adopted

1. **Simulated runs, partly adopted.** Drop **M2** (five issues including a large one, sequential): the three fixture milestones are covered deterministically by AC-5's bats tests in `gh-milestone.bats`, and the sequential no-flag path is also exercised by M3. **Keep M1** (three small related issues, bulk) and **M3** (dependency chain, sequential with stacked order). Reason for keeping M1, declining that part of the cut: "same area" and "low risk" are model judgements made in `mode-selection.md`, and they can only turn bulk into sequential. M1 is the only run in which that judgement must leave a bulk recommendation standing; no bats test can cover it. AC-32 becomes two headless probes (M1, M3). Lower the budget in Assumption 18 by one probe's cap.
2. **No doc-writer stacked summary line (adopted).** AC-22 and Assumption 17 lose the extra "stacked summary line naming the base branch". `agents/doc-writer.md` already handles the stacked introduction through `stacked_on`, and `gh-pr.sh create` already sets the base from `base_branch`. Phase D makes no doc-writer change. The only doc-writer change is Phase C's bulk per-issue snapshot input.
3. **Phases (adopted).** Five phases, not six:
   - **A** deterministic layer (spec ACs 1–8, lean), `depends_on: []`.
   - **B** ship-milestone entry, mode selection, shared milestone and final reports (ACs 9–13, 26, 27, lean), `depends_on: []`. B is written against AC-1's `select` JSON contract, so it does not wait for A. B also registers `ship-milestone` in `tests/scripts/skills.bats` (ENTRY list and citations) so the suite stays green phase by phase.
   - **C** bulk (ACs 14–19, 25, full), `depends_on: [A, B]`.
   - **D** sequential (ACs 20–25, full), `depends_on: [A, B]`.
   - **E** resume, status, the `skills.bats` no-`## Stage:` check and resume/status citations, then docs and the simulated runs (old E and F merged: ACs 28–35, full), `depends_on: [C, D]`. Its resume/status tasks come before the paid runs, which need them.
   - Waves: 1 = [A, B], 2 = [C, D], 3 = [E].

## Spec-review notes carried forward (binding)

- C and D both add hook lines to `skills/ship/SKILL.md` and ship's references. **Serialise those edits.** Phase D's task that edits ship files declares a cross-phase `depends_on` on Phase C's ship-edit task (written as `depends_on: [C<n>]`). Keep the ship edits in each phase in as few tasks as possible so the cross-phase edge is one edge.
- AC-15: after one issue's spec gate is answered and re-analysed, the bulk stage moves on to the next issue still at `needs_input`, and goes to the brief only when every issue is `ok`.
- `select` reuses `issues`' `gh` call and `JQ_FILTER`; it does not copy them.
- The C1 DESIGN §10 wording change is recorded as a deviation (AC-31), not a silent reword.
- Q1's cap must cover child 1 in full plus part of child 2: set the kill stage early in child 2 (for example `brief`), and keep §9.1's "spend can pass the cap" rule.

## Platform facts (verified 2026-10-26 against code.claude.com/docs)

- `disable-model-invocation: true` stops Claude invoking the skill (Skill-tool calls blocked); `/aew:ship-milestone` works, also in `-p`. `resume` reads skill files with Read.
- Arguments: `$ARGUMENTS` (whole string), `$ARGUMENTS[N]` / `$N` (0-based, shell-style quoting), `$name` via `arguments:`. `argument-hint` exists.
- `${CLAUDE_PLUGIN_ROOT}` / `${CLAUDE_SKILL_DIR}` are substituted only in the loaded skill's Markdown body, not in files read with Read, and are not in the Bash tool's environment.
- AskUserQuestion: main thread only; removed under `--permission-prompts none`; 1–4 questions and 2–4 options per call, "Other" added automatically.
- Subagents run concurrently; default cap 20 (`CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`); no ordering guarantee.
- SubagentStop payload has `stop_hook_active`, `agent_type`, `last_assistant_message`.
