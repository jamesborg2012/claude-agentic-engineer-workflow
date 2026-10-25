# Prompt 05b — Plain-English introduction on every PR

## Ground rules
- Read `docs/DESIGN.md` in full before doing anything. It is the approved design and the source of truth. If anything in this prompt conflicts with it, DESIGN.md wins; note the conflict in your summary.
- Verify every Claude Code feature you rely on against the current official docs at code.claude.com/docs. Use the claude-code-guide agent; don't rely on memory.
- Work autonomously. Stop and ask me only when:
  - a decision isn't covered by DESIGN.md or this prompt and is expensive to reverse;
  - the docs contradict the design in a way that changes behaviour.
- Simplicity first: no abstractions, options or files this change doesn't need.
- British English in all prose.
- Use superpowers' verification-before-completion before claiming you're done.
- Finish with:
  1. the checks you ran and their results;
  2. the files created or changed;
  3. any deviations, and why;
  4. anything I need to decide.

  Then commit with a conventional commit message, and add a CHANGELOG entry.

## Goal
Every PR the plugin opens must start with a short plain-English introduction, so I can understand what happened in the run before reading the technical detail.

## Decisions already made (don't re-ask)
- **Every completed run ends in a PR.** This is already true. Make it an explicit rule in DESIGN §9: single-issue runs, bulk milestone runs and each sequential-milestone child all end in a PR, and so does `init`.
- **Blocked runs do not open a PR.** They keep today's behaviour: a report comment on the issue, the blocked label, and a stop.
- **A resumed or re-run run updates the existing PR** (already in `skills/ship/references/pr.md`), and the introduction is rewritten to match the final state, not appended to.
- **The reader is me, reviewing quickly.** I know the project, so don't explain it to me. The point is to lead with what happened and why, in plain words, before the detail.
- **GitHub issues are out of scope** for this change. The plugin doesn't create project issues, and the issue body and comment formats stay as they are.

## The introduction: specification
- **Position:** the very first section of the PR body, headed `## In plain English`, before `## Summary`. Everything technical stays below it, unchanged.
- **Length:** 100–250 words for a single issue. For a bulk milestone PR, one opening paragraph plus at most about 80 words per issue.
- **Content,** in this order. Omit a point only when it genuinely doesn't apply.
  1. What was asked for and why it matters, in one or two sentences. Name the issue as "issue #12" in words.
  2. What changed, from the point of view of someone using the product: what they'll see or be able to do now.
  3. How it was done, in a sentence or two. If the plan rejected an obvious alternative, say which and why.
  4. What changed along the way: spec clarifications I confirmed, anything the run decided on my behalf, and deviations from the original issue.
  5. What needs my attention: manual tests outstanding, risks, known limitations, anything left out. If nothing, say so in one line.
  6. How confident the run is: one line, e.g. "All 14 checks pass on desktop and mobile, with no accessibility issues found."
- **Style:**
  - plain words and short sentences;
  - no file paths, function or variable names, code, backticks, or AC/TC/WP identifiers;
  - no Markdown tables or headings inside the section (short paragraphs, at most one short list);
  - name technical terms only when unavoidable, and explain them in passing;
  - don't restate what the technical sections already list in full;
  - use real, specific facts from the run (no generic filler like "this PR improves the codebase").
- **Variants:**
  - **Stacked PR (sequential milestone):** say plainly that it builds on the PR for issue #n and must be merged after it.
  - **Bulk milestone PR:** an opening paragraph on the milestone as a whole, then one short paragraph per issue.
  - **`init` PR:** what was set up for the project and why, what I should check (detected commands, permissions), and what happens next.

## Deliverables
1. **DESIGN.md:**
   - In §8.7, add the introduction to the `pr-body.md` contents, with this specification condensed.
   - In §9, add the explicit "every completed run ends in a PR; blocked runs don't; re-runs update and rewrite" rule.
   - Check §10 mentions the bulk and stacked variants.
2. **`templates/artefacts/pr-body.md`:** add `## In plain English` as the first section, with a comment describing the specification. The comment is stripped before posting, as today.
3. **`agents/doc-writer.md`:** add the introduction as a required output, with the content order, style rules and variants above. Give one good and one bad example, both short. The doc-writer writes the introduction last, after the technical sections, so it summarises what is actually there. Add it to the agent's done criteria.
4. **A deterministic check (`scripts/check-pr-intro.sh <pr-body.md>`), run by the orchestrator before `gh-pr.sh create` or `update`.** It fails if:
   - the first `##` heading isn't `## In plain English`;
   - the section is outside the word limits;
   - it contains backticks, a path-like token (`/` plus an extension, or `src/`, `docs/` and similar), `AC-`, `TC-` or `WP-` identifiers, a table, or a heading.

   On failure, send it back to the doc-writer once with the check's output. If it still fails, open the PR anyway and note the failure in the final report and the retro: the intro must never block a PR. Make it shellcheck-clean, with `--help` and tests (passing and failing fixture bodies).
5. **Orchestrator:**
   - Wire the check into `skills/ship/references/pr.md` (`## Push and pull request`).
   - Make sure `init` produces a PR body with the `init` variant of the introduction.
6. **Tests:** update the agent-smoke fixtures. Re-run the doc-writer on its existing fixture run and confirm the new section passes the check. Record the results in `tests/agent-smoke/README.md`.

## Acceptance criteria
- The doc-writer fixture run produces a `pr-body.md` whose first section is `## In plain English`, passes `check-pr-intro.sh`, and mentions the outstanding manual test and the test outcome in plain words.
- `check-pr-intro.sh` tests cover: a valid intro; a missing section; too long; backticks; a path; an `AC-3` identifier; a table. All pass.
- A simulated `ship --auto` run (mocked `gh`, as in prompt 05) posts a PR body that starts with the introduction. A simulated resume rewrites the introduction rather than adding a second one.
- No change to blocked-run behaviour, and no change to issue bodies or comments.
