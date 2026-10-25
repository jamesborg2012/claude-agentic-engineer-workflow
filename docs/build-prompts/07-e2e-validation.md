# Prompt 07 — End-to-end validation on real GitHub and 0.1.0 release

## Ground rules
- Read `docs/DESIGN.md` in full before doing anything. It is the approved design and the source of truth. If anything in this prompt conflicts with it, DESIGN.md wins; note the conflict in your summary.
- Verify every Claude Code feature you rely on against the current official docs at code.claude.com/docs, including plugin install from a local marketplace and the tag format that dependency resolution expects. Use the claude-code-guide agent; don't rely on memory.
- Work autonomously. Stop and ask me only when:
  - a decision isn't covered by DESIGN.md and is expensive to reverse;
  - something would cost money;
  - you'd need to delete anything on GitHub. Never delete the sandbox repo.
- British English in all prose.
- Use superpowers' verification-before-completion before claiming you're done.
- Commit each fix separately with a conventional commit message.

## Goal
Prove the plugin works on real GitHub with real runs, fix whatever breaks, and release 0.1.0.

## Steps
1. **Install for real.**
   - Add the local marketplace and install the plugin at user scope.
   - Confirm the dependencies were installed (superpowers, context7, frontend-design), that the plugin's skills and agents are listed, and that the Playwright MCP server connects.
   - Record the exact commands in the README.
2. **Create the sandbox.**
   - Create a private repo `aew-sandbox` under my account with `gh repo create --private`.
   - Give it a small Next.js + Tailwind app: one page with a form, one API route that the form posts to, a lint script and a unit test setup. No Playwright yet.
   - Push it to main.
3. **Run init in the sandbox.** Check its PR, then ask me to merge it. Don't try `gh pr merge`; the guard blocks it by design.
4. **Create issues and milestones with `gh`, then run each scenario.** After each one, ask me to merge its PR before the next scenario, unless the scenarios are independent.

   | # | Scenario | Expect |
   |---|---|---|
   | S1 | Non-UI issue: server-side validation for the API route | `ship`, gates on. Plan gate shown, ACs traced to tests, PR opened. |
   | S2 | UI issue with an accessibility requirement: inline error messages, announced to screen readers | `ship --auto`. Playwright specs committed, screenshots for both viewports in `docs/qa/`, axe results in the report. |
   | S3 | Issue with a deliberate material ambiguity | Spec gate fires even with `--auto`. After I answer, revision v2 appears on the issue with the original collapsed. |
   | S4 | Issue that includes one non-automatable check, e.g. "an email is sent to the admin" | Manual-testing section added to the issue, label set, listed in the PR. |
   | S5 | Milestone of three small, related issues | `ship-milestone` recommends bulk. One PR closes all three. |
   | S6 | Milestone of three issues in a dependency chain | `ship-milestone --sequential`. Correct order and stacked PRs. |
   | S7 | Interrupt an S1-style run during `develop` (Ctrl-C) | `status` shows it, the SessionStart hook mentions it, and `resume` continues from `develop`. |
   | S8 | `prompt` on a fresh issue | Paste `prompt.md` into a new session **without** the plugin (`claude --bare` or a plugin-less profile). It should be self-sufficient enough to plan and complete at least the first work package. |
   | S9 (optional) | Only if Docker is available: a minimal WooCommerce extension in a second sandbox, using wp-env | Stack detection gives wordpress + woocommerce. Standards docs are generated. A small issue ships. |

   For every PR in S1–S6 (and the init PR), also check that it opens with the `## In plain English` introduction, that I could understand the run from it alone, and that it matches what actually happened. A generic or inaccurate introduction counts as a failure, even if `check-pr-intro.sh` passes.
5. **Record results.** After each scenario, add to `tests/e2e-validation.md`:
   - pass/fail for each expectation;
   - review and fix cycles used;
   - rough duration;
   - problems found.

   Fix plugin problems as you go and re-run the failed scenarios. Improve agent prompts rather than weakening expectations.
6. **Triage the retro issues** the runs filed in the plugin repo. Fix the small ones now; leave the rest open with a note.
7. **Release:**
   - finalise the README: purpose, install, prerequisites, commands, config reference, labels, the files the plugin creates in a project, troubleshooting, uninstall;
   - add a 0.1.0 entry to CHANGELOG;
   - bump the version if anything changed;
   - tag using the format the plugin dependency docs expect, e.g. `aew--v0.1.0`.

## Acceptance criteria
- S1–S8 pass. S9 passes or is documented as skipped, with the reason.
- No guard-hook false positives remain unresolved.
- `tests/e2e-validation.md` is complete. The README is accurate against what actually happened in these runs.
- The final summary to me lists: what was fixed during validation, known limitations, and the open retro items.
