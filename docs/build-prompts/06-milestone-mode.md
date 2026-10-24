# Prompt 06 — Milestone mode

## Ground rules
- Read `docs/DESIGN.md` in full before doing anything. It is the approved design and the source of truth. If anything in this prompt conflicts with it, DESIGN.md wins; note the conflict in your summary.
- Verify every Claude Code feature you rely on against the current official docs at code.claude.com/docs. Use the claude-code-guide agent; don't rely on memory. If the docs contradict DESIGN.md, follow the docs, update DESIGN.md in the same commit, and call it out.
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
Add `ship-milestone` (DESIGN §10). It runs a whole milestone either in **bulk** (one combined pipeline and one PR for small, cheap milestones) or **sequentially** (the full single-issue pipeline per issue, in dependency order). It reuses the `ship` procedure rather than duplicating it.

## Deliverables
1. **`skills/ship-milestone/`** (`disable-model-invocation: true`). `SKILL.md` holds the procedure; the detail goes in:
   - `references/mode-selection.md`
   - `references/bulk.md`
   - `references/sequential.md`
2. **Arguments:** a milestone number or title (required), `--bulk` or `--sequential`, and `--auto`.
3. **Mode selection** when no mode flag is given:
   - fetch the issues (`gh-milestone.sh issues`);
   - apply the DESIGN §10 criteria. The AC count comes from a quick read of each issue, not a full spec analysis.
   - recommend a mode with a one-paragraph rationale, and confirm via AskUserQuestion.
4. **Bulk mode:**
   - run id `m-<milestone>`;
   - spec analysis per issue in parallel. Each issue gets its own gate (if material) and its own revision record.
   - one combined brief, with AC ids prefixed by issue (`#12-AC-1`);
   - one standards pass, one plan, one branch (`milestone_branch_pattern`), and one development, review and QA cycle;
   - QA traceability per issue;
   - one PR that closes every issue;
   - stage labels updated on every issue.
5. **Sequential mode:**
   - Order the issues topologically by `depends_on`. A dependency cycle stops the run and asks me.
   - Run the `ship` procedure for each issue as a `sequential-child` run.
   - If an issue depends on an issue whose PR is still open, branch from that issue's branch (a stacked PR), set the PR base accordingly, and note it in the PR body.
   - The plan gate applies per issue unless `--auto`.
   - On `blocked`, stop the sequence and write a milestone report.
   - Keep an index at `.aew/runs/m-<milestone>/index.json` with each child's status, so `resume` and `status` work at milestone level.
6. **Shared logic.** Factor the parts of `ship` that both modes need into shared references, or have `ship-milestone` follow `ship`'s references directly. No copy-paste of the pipeline. Update `resume` and `status` to understand milestone runs, and extend the state schema if needed.
7. **Milestone summary:** a comment on each issue in the milestone with the run outcome and links, plus a final report to me covering issues shipped, PRs, blocked items and manual tests outstanding.

## Acceptance criteria
- **Mode recommendation**, tested on three fixture milestones (mocked `gh`):
  - three small, related issues → bulk;
  - five issues, including a large one → sequential;
  - three issues in a dependency chain → sequential, in the correct stacked order.
- **Simulated bulk run** (mocked `gh`): completes, creates one PR with closing keywords for all three issues, and records a revision on each issue that needed one.
- **Simulated sequential run:** respects the dependency order, creates stacked branches with the correct PR bases, and stops cleanly when one child is forced to `blocked`.
- **Resume:** works for a milestone run interrupted in its second child.
- Record the results in `tests/agent-smoke/README.md`.
