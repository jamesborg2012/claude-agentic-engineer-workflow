# Light plan - plain-English introduction on every PR

- **Issue:** no issue (source: `docs/build-prompts/05b-plain-english-pr-intro.md`)
- **Date:** 2026-10-26
- **Lane:** light

## Problem

PR bodies lead with technical detail, so James cannot see what a run did and why without reading it all. Every PR the plugin opens (ship single, bulk, sequential child, and `init`) must start with a short, checked, plain-English `## In plain English` section, rewritten (not appended) when a run is resumed or re-run.

## Acceptance criteria

Mapped to the build prompt's four criteria.

1. (P-AC1) The doc-writer fixture run (static-shop, run 951) produces a `pr-body.md` whose first `##` section is `## In plain English`, passes `check-pr-intro.sh`, and mentions the outstanding manual test and the test outcome in plain words.
2. (P-AC2) `check-pr-intro.sh` bats tests cover: a valid intro; a missing section; too long; backticks; a path; an `AC-3` identifier; a table. All pass. (Added by this plan: too short, a heading inside, bulk limits, comment stripping, `--help`, bad usage.)
3. (P-AC3) A simulated `ship --auto` run (mocked `gh`, as prompt 05's section 9) posts a PR body that starts with the introduction. A simulated resume rewrites the introduction instead of adding a second one.
4. (P-AC4) No change to blocked-run behaviour, issue bodies or comments. Verified by diff: no edit to the blocked path in `skills/ship/SKILL.md`, `gh-issue.sh` or the issue templates.
5. (Deliverables 1, 5) DESIGN.md states the rule in 8.7 and 9 and names the variants (10); `init` produces the init variant.

## Scope

- **In:** DESIGN.md 8.7 / 9 / 10; `templates/artefacts/pr-body.md`; `agents/doc-writer.md`; new `scripts/check-pr-intro.sh` and its bats file and fixtures; the check wired into `skills/ship/references/pr.md` (+ final report and retro notes); `skills/init/SKILL.md` intro variant; pre-approval of the new script wherever the other `scripts/*.sh` are listed; smoke-test docs and the paid re-runs; CHANGELOG and CLAUDE.md "Recent changes".
- **Out:** GitHub issue bodies and comments; blocked-run behaviour; any change to `gh-pr.sh` (it passes the body verbatim apart from the closing line); a new retro mechanism; agents other than doc-writer; any new skill, option or directory beyond `tests/scripts/fixtures/pr-intro/`.

## Assumptions

- **Assumed:** DESIGN.md has no conflict with the build prompt. 8.7 and 9 only need additions; 10 already says bulk is "one PR that closes all the issues" and sequential PRs are stacked and "noted in the PR", so the 10 edit is one clause naming the introduction's variants, not a rule change. Flagged here because the prompt says to check it. **Flag if wrong.**
- **Assumed:** the check is run by the orchestrator, not by the doc-writer (it has no Bash), exactly as prompt deliverable 4 says. The retry is one re-dispatch of `aew:doc-writer` with the check output appended to the dispatch fields.
- **Assumed:** bulk vs single is told to the script by a flag, `--issues <n>` (default 1). The orchestrator passes `jq '.issues | length' state.json`. Single (n=1): 100-250 words. Bulk (n>1): minimum 100, maximum 80 x n + 80 (an opening paragraph of about 80 words plus 80 per issue). Simple, no mode names, and sequential children are n=1 as each has one issue.
- **Assumed:** section extraction is from the first `## In plain English` line to the next line starting `## ` (or end of file). The section text is everything between, excluding the heading line.
- **Assumed:** HTML comments (`<!-- ... -->`, single or multi-line) are stripped from the whole body before any check, because the doc-writer must already remove them and the template comment would otherwise count as words or trip the path regex. A leftover comment is therefore not a failure of this check (the doc-writer's own done criteria cover it).
- **Assumed:** word count is `wc -w` semantics (whitespace separated tokens) of the extracted section after comment stripping. List bullet markers (`-`) count as tokens; accepted, the margin of 100-250 absorbs it.
- **Assumed:** exit codes: 0 pass; 1 check failed (one `FAIL: <reason>` line per violation on stdout, so the whole output can be pasted to the doc-writer); 2 invalid usage or unreadable file (message on stderr). Mirrors `common.sh` helpers where they fit; if `die` exits 1, the script uses an explicit `exit 2` for usage errors only.
- **Assumed:** path-like regex (ERE, case-sensitive, applied to the section): a token with a slash and an extension, `[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]*\.[A-Za-z0-9]{1,5}`; or a known top-level directory prefix, `(^|[^A-Za-z0-9])(src|docs|app|lib|tests?|scripts|templates|skills|agents|hooks|node_modules|\.aew|\.claude)/`. "and/or" and "24/7" do not match. URLs match (a URL has no place in the intro). Other checks: any backtick; `(AC|TC|WP)-[0-9]` (also catches `#12-AC-1`); a table (a line starting `|`, or a separator row of dashes and pipes); a heading (a line starting `#` inside the section, other than the section heading itself).
- **Assumed:** a missing `## In plain English` as the FIRST `##` heading is one failure and stops the other checks (nothing to measure). Content under a leading `# Title` or a blank line is allowed before it; only a different `##` heading first fails.
- **Assumed:** the check also runs for `init`'s PR body (`.aew/runs/init-pr-body.md`), with the init skill rewriting the intro once on failure and then opening the PR anyway. The prompt's deliverable 4 names only the orchestrator; applying it to init follows from "every PR". **Flag if wrong.**
- **Assumed:** the retro note is made by the orchestrator appending one `###` item (about the doc-writer prompt failing the intro check, with the check output) to `.aew/runs/<id>/retro.md` before the existing `## Retro` step files it. `retro.md` is doc-writer-owned but the orchestrator only appends here; no state.sh involvement. **Flag if wrong.**
- **Assumed:** a re-run or resume needs no new mechanism: the doc-writer re-runs from the `docs` stage and rewrites `pr-body.md` from its template (which has the one intro section), then `gh-pr.sh update` replaces the whole body. Test 3 proves one section only.
- **Assumed:** pre-approval. `skills.bats` requires every skill command to be pre-approvable, and init's settings templates list each `scripts/*.sh`. The new script is added next to `gh-retro.sh` / `detect-stack.sh` in those lists, and in the smoke `smoke_ship_allow` helper, not as a new pattern.

## Context manifest

**Pattern / reuse candidates** (read these first):
- `scripts/gh-pr.sh` - header comment style (`# Usage:` on line 2, `--help` via `print_usage`), `require_cmd`, `die`, sourcing `scripts/lib/common.sh`. Mirror the header and the arg handling.
- `tests/scripts/gh-pr.bats` + `tests/scripts/helpers/common.bash` - bats layout (`load helpers/common`, `common_setup`, `assert_success`, `run --separate-stderr`).
- `tests/scripts/conventions.bats` - globs `scripts/*.sh`; the new script is picked up automatically (strict mode, shebang, `--help`, a "Usage:" line, no-arg behaviour). Do not edit this file. Note its `subcommand` rule: line 2 must read `# Usage: check-pr-intro.sh <pr-body.md> [--issues <n>]` so the script counts as one with a required argument.
- `templates/artefacts/pr-body.md` - add the section first; the existing comment-block style.
- `agents/doc-writer.md` - Process step 4 (pr-body), Definition of done, the `blob/...` screenshot bullet style.
- `skills/ship/references/pr.md` - `## Push and pull request` (steps 1-4), `## Retro`; `skills/ship/references/final-report.md` (Warnings line list); `skills/ship/references/dispatch.md` row D13 (doc-writer dispatch fields).
- `skills/init/SKILL.md` section 12 (`init-pr-body.md`, line ~478) and the settings templates (~line 322-340).
- `tests/agent-smoke/README.md` - "951: doc-writer (E4)" (fixture run, `smoke_use shop loop 951`, D1-D10 rows, `snap-951-docs`, spend ledger) and sections 9.2 (helpers, `smoke_ship_allow`), 9.4 (S1), 9.6 (F1/R2 resume).
- `docs/DESIGN.md` 7.1, 8.7, 9, 10.

## Tasks

- id: 1
  title: DESIGN.md - state the rule and the introduction
  files: [docs/DESIGN.md]
  pattern: existing bullet style in 8.7 (`10-summary.md and pr-body.md` bullets), 9 (Final report, Recorded deviations), 10 (Bulk / Sequential bullets)
  depends_on: []
  test: none (prose); reread against the build prompt spec for word limits, order and variants
  ac: 5
  notes: 8.7 adds an "In plain English" bullet (first section, 100-250 words / bulk opening paragraph plus ~80 per issue, six content points in order, plain-style rules, three variants, written last by the doc-writer, checked by `check-pr-intro.sh`). 9 adds the "every completed run ends in a PR (single, bulk, each sequential child, init); blocked runs open none; re-runs and resumes update the PR and rewrite the introduction" rule, the check step (one doc-writer retry, never blocks the PR, noted in final report and retro), and the script in the Steps list before "create the PR". 10 gets one clause per variant. Add `check-pr-intro.sh` to any DESIGN scripts list if one exists (grep first). Record in 9's "Recorded deviations" only if a real conflict turns up.

- id: 2
  title: pr-body template - add the first section
  files: [templates/artefacts/pr-body.md]
  pattern: the template's own `## Summary` ... `## Closes` structure and comment style
  depends_on: [1]
  test: covered by task 3 (the template, with its comment stripped, must fail the check as a missing/empty intro only through placeholder text, and `gh-pr.bats` still passes untouched since it diffs against the template)
  ac: 1, 5
  notes: insert `## In plain English` before `## Summary`, with an HTML comment holding the condensed spec (order of six points, limits, banned content, variants). The comment is stripped before posting, as today.

- id: 3
  title: check-pr-intro.sh, fixtures and bats tests (TDD)
  files: [scripts/check-pr-intro.sh, tests/scripts/check-pr-intro.bats, tests/scripts/fixtures/pr-intro/valid.md, tests/scripts/fixtures/pr-intro/valid-bulk.md, tests/scripts/fixtures/pr-intro/no-section.md, tests/scripts/fixtures/pr-intro/not-first.md, tests/scripts/fixtures/pr-intro/too-long.md, tests/scripts/fixtures/pr-intro/too-short.md, tests/scripts/fixtures/pr-intro/backticks.md, tests/scripts/fixtures/pr-intro/path.md, tests/scripts/fixtures/pr-intro/ac-id.md, tests/scripts/fixtures/pr-intro/table.md, tests/scripts/fixtures/pr-intro/heading.md]
  pattern: `scripts/gh-pr.sh` (header, --help, die) and `tests/scripts/gh-pr.bats` (setup, assertions); fixtures dir mirrors `tests/scripts/fixtures/issue/`
  depends_on: [2]
  test: one bats test per fixture (exit and the `FAIL:` line text), plus valid bulk with `--issues 3`, the same long-ish body failing single but passing bulk, a leftover template comment ignored, a body with a second `## In plain English` is judged on the first, `--help` exits 0, no argument and a missing file exit 2. Write each test first and capture the RED (script absent, then each rule absent) before implementing.
  ac: 2
  notes: no `gh`, no run state, no network; needs only bash, awk, grep (declare with `require_cmd`). Strip comments with awk across lines, extract the section, then run the checks as settled in Assumptions. Keep the fixtures realistic (the valid one is a real static-shop run introduction, 100-250 words). bash 3.2, `set -euo pipefail`, shellcheck-clean (`tests/run-script-tests.sh`).

- id: 4
  title: doc-writer - the introduction as a required output
  files: [agents/doc-writer.md]
  pattern: the existing Process step list, "Spec snapshot" section style (numbered ordered contents), Definition of done bullets
  depends_on: [2]
  test: exercised by task 7 (headless re-run); `claude plugin validate .` passes
  ac: 1, 5
  notes: add an "In plain English" section to the doc: content order (six points), style rules, the three variants, how to tell them apart (issues count in `state.json`, `base_branch` not the default branch for stacked, init is not dispatched to this agent), one short good and one short bad example (bad one trips the path/backtick/AC rules), write it LAST after the technical sections, one section only on re-run (the agent starts from the template, so it rewrites). Add `--issues` limits to the instructions (single 100-250; bulk per above). Add to Process step 4 and the Definition of done. Add a "retry" input: when the dispatch includes `intro_check_output`, fix only the introduction in `pr-body.md` and return. Keep the exact outputs list (still five files).

- id: 5
  title: orchestrator - wire the check into pr.md, final report and retro
  files: [skills/ship/references/pr.md, skills/ship/references/dispatch.md, skills/ship/references/final-report.md, skills/ship/SKILL.md]
  pattern: pr.md numbered steps and its `## Retro` "never blocks a run" wording; dispatch.md D13 row; final-report.md Warnings list
  depends_on: [3, 4]
  test: `tests/scripts/skills.bats` (every skill command is pre-approvable) stays green with the new script added to the approved lists (see task 6); manual read against the simulated runs in task 8
  ac: 3, 4
  notes: in `## Push and pull request`, new step between "push" and "create/update": run `check-pr-intro.sh .aew/runs/<id>/pr-body.md --issues <n>` (n from `jq '.issues | length'` on state.json). Exit 0: continue. Exit 1: re-dispatch D13 once with `intro_check_output` set to the stdout, re-run the check; if it still exits 1, record the failure and continue to create/update anyway. Exit 2 or a script error: treat as a failed check, continue (never blocks the PR). On a persistent failure: add a `Warning: PR introduction failed the check: <first FAIL line>` to the final report (final-report.md Warnings list) and append a `###` item to `retro.md` before the `## Retro` step. The retry and fallback sit before step 1's `create`/`update` call, so a resume's update path is covered identically. Add the dispatch field to D13 and `check-pr-intro.sh` to SKILL.md's script list only if the file lists scripts (grep first). No change to the blocked path, to `routing.md` or to `gates.md`. The retry re-dispatches D13 from the `pr` stage without rewinding the stage (no `state.sh stage docs`): the doc-writer has no gate hook and only edits `pr-body.md`; state this explicitly in pr.md so the orchestrator does not rewind. Task 3 should add a bats case that the path regex passes ordinary prose ("and/or", "24/7", "1/2", "pass/fail. 14 checks").

- id: 6
  title: init - intro variant, and pre-approve the new script
  files: [skills/init/SKILL.md, tests/scripts/skills.bats, tests/agent-smoke/README.md]
  pattern: SKILL.md section 12 (PR body Write step) and the `gh-retro.sh` / `detect-stack.sh` rows of settings template 1 (and 2 if it lists scripts); skills.bats' approved-command parsing
  depends_on: [3]
  test: `tests/run-script-tests.sh` (skills.bats must pass, and fail first if the new script is used in a skill but not listed); init simulated run in task 8
  ac: 3, 5
  notes: section 12: the body must open with `## In plain English`, init variant (what was set up and why, what to check: detected commands and permissions, what happens next), 100-250 words, then the technical list; run the check once before `gh-pr.sh open`; on a failure rewrite once, then open anyway and report a warning. Add `check-pr-intro.sh` to settings template 1 and any template 2 allow list, and `smoke_ship_allow` (README 9.2) for ship and init. If skills.bats needs a new entry, add it; do not weaken its rule.

- id: 7
  title: smoke fixtures and paid headless doc-writer re-run (manual)
  files: [tests/agent-smoke/README.md]
  pattern: README "951: doc-writer (E4)" (D1-D10 table, re-run blocks, spend ledger) and section 3 invocation
  depends_on: [3, 4, 6]
  test: the run itself; results written into README
  ac: 1
  notes: PAID, MANUAL, needs the developer's go-ahead; check the section 8.1 spend ledger first (cap 5 for this dispatch, expected cost about 0.3-0.5). Exact steps, from a script file, with `< /dev/null`: `smoke_use shop loop 951`; `O="$SMOKE/out-951-docs-intro"` (cleared first); restore the pre-run state with `cp -Rp "$SMOKE/snap-951-docs/." "$P"` (as the existing re-runs do); `state.sh stage docs`; `smoke_dispatch doc-writer "run_dir: $RUN"` with `ALLOW=()` and `CAP=5`, using the section 3 `claude -p` command unchanged. Then run D1-D10 unchanged plus: D11 `head -n 1 "$RUN/pr-body.md"` is `## In plain English` and `grep -c '^## In plain English$'` is 1; D12 `"$REPO/scripts/check-pr-intro.sh" "$RUN/pr-body.md"` exits 0 (single issue, so no `--issues`); D13 the section's text mentions the outstanding manual test (the AC-4 manual case) and the test outcome in plain words (read it; `grep -ciE 'manual|by hand'` and a pass count), and contains no AC-/TC-/backtick. If the check fails, fix `agents/doc-writer.md` and re-run from `snap-951-docs` (same loop as E4 re-run 1-2). Record each result row, the cost and any fix commit in a new "951 doc-writer, introduction (prompt 05b)" block after the E4 results; refresh the README fixture notes if the fixture's expected pr-body headings list is documented (add `In plain English` first).

- id: 8
  title: simulated ship --auto and resume runs (mocked gh), recorded in README section 9
  files: [tests/agent-smoke/README.md]
  pattern: README 9.4 (S1: `smoke_ship_project s1 shop`, `smoke_ship_issue 201`, `ship-run.sh` launcher, `smoke_norm`, `expected_s1`) and 9.6 (F1 kill during develop / R2 resume)
  depends_on: [5, 6, 7]
  test: the runs; recorded as new rows, one new subsection `9.10 Introduction on the PR (prompt 05b)` (next free number; check the file's tail first)
  ac: 3, 4
  notes: PAID, MANUAL, cap and ledger as 9.1 (stop at the section 9.1 remaining budget). Run A: S1 form, `"$SMOKE/ship-run.sh" "$REPO" "$W" S5b.1 25 "$W/allow-ship.txt" "/aew:ship 201 --auto"` (run_in_background). Checks: the captured `pr create` body file in `$GHM` (as 9.4) starts, after its first line, with `## In plain English` as the first `##`; `check-pr-intro.sh` exits 0 on it; the `calls.log` route list equals `expected_s1` (no new gh call); blocked-run untouched (no `aew:blocked` label). Run B (resume): reuse 9.6's kill-then-resume, but kill after `docs` so a PR exists; resume with `/aew:resume 201`; checks: `gh-pr.sh update` was called (not a second create), the final body has exactly one `## In plain English` (`grep -c`), and its text differs from run A's only as the final state requires. Run C (init): `smoke_ship_allow init`, `/aew:init`, check the init body file opens with the init-variant section and passes the check. Add one free failure-path test if possible: seed a doc-writer output that fails the check and confirm the PR is still opened and the Warning appears (can use a canned `pr-body.md` and the orchestrator steps by hand, no paid session; mark it as such).

- id: 9
  title: CHANGELOG and CLAUDE.md "Recent changes"
  files: [CHANGELOG.md, CLAUDE.md]
  pattern: CHANGELOG `## [Unreleased]` Added/Changed bullets (British English); CLAUDE.md "Recent changes" line format (`date · branch · summary · [spec] · [plan]`)
  depends_on: [1, 2, 3, 4, 5, 6, 7, 8]
  test: `claude plugin validate .` and `tests/run-script-tests.sh` full run green; `git diff --stat` shows no edit to blocked-path text, `gh-issue.sh` or issue templates (P-AC4)
  ac: 4
  notes: CHANGELOG Added: `scripts/check-pr-intro.sh` and tests; Changed: PR body template, doc-writer, ship PR step, init PR body, DESIGN 8.7/9/10. CLAUDE.md: one new line for `feature/orchestrator-and-entry-skills`' follow-up branch name (use the branch at commit time; build prompt 05b), linking this plan (no spec file exists: link the build prompt instead of a spec). Also append any new gotcha to `docs/superpowers/project-map.md` (e.g. awk comment-stripping on bash 3.2) if one turns up. Commit trailer: `Co-Authored-By: Claude <noreply@anthropic.com>` only (repo rule, overrides the session's attribution line). Do not commit this plan's own planning before human approval; commit order: 1-2, 3, 4, 5-6, 7-8 results, 9.

## Approval

- Senior architect: APPROVED WITH NOTES on 2026-10-26 (light-review)
- Plan format: LIGHT
- CTO: SKIPPED (light lane, no risk lines)
- Risk lines crossed: none
- Applied: task 7 now depends on task 6 (both edit tests/agent-smoke/README.md); task 5 note on retry without stage rewind; task 3 prose false-positive case.
- Human (developer): APPROVED on 2026-10-25T23:24:51Z
- Plan content hash at approval: 905dbf8838cc
- Paid smoke budget: separate 05b ledger, stop at $15 (tasks 7 and 8)
